--!strict
-- The boss ladder (Config/Bosses, spec 2026-10-28-boss-ladder-design.md): each player's progress on every boss
-- (saved: data.bosses), the arenas' gates, the fights and their rewards. Rules (unlock, loot cooldown, soft cap,
-- over-power) are in Util/BossRules. A boss is spawned for the one player who starts it at the gate and fought on the
-- usual combat core (BattleService); a win's XP and cash come from there, its items from here.
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local WildConfig = require(Config:WaitForChild("Wild")) -- the main game's: a remote arena copy streams in within its STREAM_TIMEOUT
local Cards = require(Config:WaitForChild("Cards"))
local Items = require(Config:WaitForChild("Items"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local BossRules = require(Shared:WaitForChild("Util"):WaitForChild("BossRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local BattleService = require(Services:WaitForChild("BattleService"))
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local WildService = require(Services:WaitForChild("WildService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type Grant = { item: string, count: number }

local BossService = {}

local records: { [Player]: { [string]: BossRules.Record } } = {} -- loaded players only
local arenas: { [string]: WildService.BossArena } = {}
local occupants: { [string]: { [number]: WildService.Monster } } = {} -- the boss being fought in each arena copy
local fighters: { [string]: { [number]: { Player } } } = {} -- who fought in each remote copy (they hold it until they leave)
local reserved: { [string]: { [number]: boolean } } = {} -- remote copies being loaded for a fight about to start
local entering: { [Player]: boolean } = {} -- players whose fight is being set up
local lobbies: { [string]: { members: { Player } } } = {} -- a group forming at each gate (the first member leads)
local allowStart = RateLimiter.new(Bosses.START_COOLDOWN)
local allowPickUp = RateLimiter.new(Bosses.LOOT_PICKUP_COOLDOWN)
local allowGroup = RateLimiter.new(Bosses.START_COOLDOWN) -- its own, so Fight then F right after both work
local allowRequest = RateLimiter.new(1)
local allowTravel = RateLimiter.new(Bosses.TRAVEL_COOLDOWN)
local rng = Random.new()
local runGate: ((player: Player, bossId: string) -> ())? = nil -- the Dungeon: its run starts the chamber's boss

-- The boss a fragment opens (its unlock item), by fragment id
local opensBoss: { [string]: string } = {}
for bossId, boss in Bosses.BOSSES do
	if boss.unlock then
		opensBoss[boss.unlock.item] = bossId
	end
end

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

function BossService.GetRecord(player: Player, bossId: string): BossRules.Record?
	local byBoss = records[player]
	return if byBoss then byBoss[bossId] else nil
end

-- Where boss n's gate is (/boss)
function BossService.GetGate(index: number): CFrame?
	local bossId = Bosses.LADDER[index]
	local arena = if bossId then arenas[bossId] else nil
	return if arena then arena.gate else nil
end

local function sendBosses(player: Player)
	local byBoss = records[player]
	if not byBoss then
		return
	end
	local now = os.time()
	local today = BossRules.dayNumber(now)
	local payload = {}
	for bossId, record in byBoss do
		local unlock = Bosses.BOSSES[bossId].unlock
		payload[bossId] = {
			unlocked = record.unlocked,
			cleared = record.cleared,
			lootIn = math.max(0, record.lootAt - now),
			rewardedToday = BossRules.dayCounts(record, today).rewardedToday,
			bonusReady = record.bonusDay ~= today, -- the day's first rewarded win still adds its daily chest
			fragments = if unlock then ItemService.GetCount(player, unlock.item) else 0,
		}
	end
	Remotes.BossesChanged:FireClient(player, payload)
end

-- The strongest fighter's Power (bosses recommend a Power per card)
local function partyPower(player: Player, fighterIds: { string }): number
	local best = 0
	for _, beastId in fighterIds do
		local beast = CardService.GetBeast(player, beastId)
		local card = if beast then Cards.ById[beast.cardId] else nil
		if beast and card then
			best = math.max(best, BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade))
		end
	end
	return best
end

-- Adds the grants to `got` (merged by item): the loot that will scatter on the ground
local function grant(_player: Player, grants: { Grant }, got: { Grant })
	for _, entry in grants do
		local given = entry.count
		if given > 0 then
			local merged = false
			for _, existing in got do
				if existing.item == entry.item then
					existing.count += given
					merged = true
				end
			end
			if not merged then
				table.insert(got, { item = entry.item, count = given })
			end
		end
	end
end

-- Fragments are never dropped for a boss that's already open
local function wanted(byBoss: { [string]: BossRules.Record }, item: string): boolean
	local opens = opensBoss[item]
	local record = if opens then byBoss[opens] else nil
	return not (record and record.unlocked)
end

-- A boss win's items (BattleService calls this; the XP and cash are already paid). Farm protection (spec section 7):
-- too fast a win gives no drops; full loot once per LOOT_COOLDOWN per boss, its chances shrunk by the daily soft cap
-- and the over-power penalty; the first clear and the day's first rewarded win add their chests. A group member who
-- helped too little (fight.contributed false) gets only the carried roll: a quarter of the chances, no fragments, no
-- chests.
-- Loot on the ground --------------------------------------------------------------------------------------

type Drop = { item: string, count: number, position: Vector3 }
local pending: { [Player]: { [string]: Drop } } = {}

-- One drop into the Bag (picked up: nothing is collected by itself)
local function collect(player: Player, id: string)
	local drops = pending[player]
	local drop = if drops then drops[id] else nil
	if not drops or not drop then
		return
	end
	drops[id] = nil
	ItemService.GiveItem(player, drop.item, drop.count)
	Remotes.BossLoot:FireClient(player, { taken = id })
end

-- Everything still lying for a player goes into their Bag (before they're sent out of an arena copy)
local function collectAll(player: Player)
	local ids = {}
	for id in pending[player] or {} do
		table.insert(ids, id)
	end
	for _, id in ids do
		collect(player, id)
	end
end

-- The arena copy a boss is (or was) fought in, and its index
local function copyOf(monster: WildService.Monster): (WildService.ArenaCopy?, number?)
	local bossId = monster.boss
	local arena = if bossId then arenas[bossId] else nil
	if not arena or not bossId then
		return nil, nil
	end
	for index, copy in arena.copies do
		if (occupants[bossId] or {})[index] == monster then
			return copy, index
		end
	end
	return nil, nil
end

-- A win's items scatter round the boss for this player only (the server keeps them until they're collected)
local function dropLoot(player: Player, monster: WildService.Monster, items: { Grant })
	local copy = copyOf(monster)
	if not copy or #items == 0 then
		return
	end
	local center = copy.spawn.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- Only the ground: never a creature, a monster or a player standing there
	local ignore: { Instance } = { workspace:FindFirstChild("Creatures") or workspace, workspace:FindFirstChild("Monsters") or workspace }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local drops = pending[player] or {}
	pending[player] = drops
	local list = {}
	local spots = BossRules.scatter(#items, Bosses.LOOT_SCATTER.min, Bosses.LOOT_SCATTER.max, rng:NextNumber() * 2 * math.pi)
	for index, entry in items do
		local flat = center + Vector3.new(spots[index].x, 0, spots[index].z)
		local hit = workspace:Raycast(flat + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
		local position = if hit then hit.Position else flat
		local id = HttpService:GenerateGUID(false)
		drops[id] = { item = entry.item, count = entry.count, position = position }
		table.insert(list, { id = id, item = entry.item, count = entry.count, x = position.X, y = position.Y, z = position.Z })
	end
	Remotes.BossLoot:FireClient(player, { drops = list, from = { x = center.X, y = center.Y, z = center.Z } })
end

-- A pickup: only your own drops, only those close by (one request may name several)
local function onPickUp(player: Player, raw: unknown)
	local ids = BossRules.readIds(raw, Bosses.LOOT_PICKUP_BATCH)
	if not ids or not allowPickUp(player) then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root then
		return
	end
	for _, id in ids do
		local drop = (pending[player] or {})[id]
		if drop and (root.Position - drop.position).Magnitude <= Bosses.LOOT_PICKUP_DISTANCE then
			collect(player, id)
		end
	end
end

-- The title over this player's name: the last cleared boss on the ladder that gives one (Dungeon Conqueror)
local function setTitle(player: Player)
	local byBoss = records[player]
	local title = nil
	for _, bossId in Bosses.LADDER do
		local record = if byBoss then byBoss[bossId] else nil
		local clearTitle = Bosses.BOSSES[bossId].clearTitle
		if record and record.cleared and clearTitle then
			title = clearTitle
		end
	end
	player:SetAttribute("Title", title)
end

-- A first clear the whole experience hears about: every other server shows it too (BossService.Start subscribes)
local function announceEverywhere(player: Player, bossId: string)
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:PublishAsync(Bosses.CLEARED_TOPIC, { name = player.DisplayName, bossId = bossId, jobId = game.JobId })
		end)
		if not ok then
			warn(`[BossService] couldn't announce the clear to other servers: {err}`)
		end
	end)
end

local function onBossWin(player: Player, monster: WildService.Monster, fight: { seconds: number, fighterIds: { string }, contributed: boolean }): any
	local bossId = monster.boss :: string
	local boss = Bosses.BOSSES[bossId]
	local byBoss = records[player]
	if not boss or not byBoss or not byBoss[bossId] then
		return nil
	end
	local now = os.time()
	local today = BossRules.dayNumber(now)
	local record = BossRules.dayCounts(byBoss[bossId], today)
	byBoss[bossId] = record
	local carried = not fight.contributed
	local result = { bossId = bossId, items = {}, firstClear = false, bonus = false, lootIn = 0, reduced = false, flagged = false, carried = carried }

	-- The first clear's chest always comes to those who helped (it's the way up the ladder, however strong the party)
	if not record.cleared and not carried then
		record.cleared = true
		result.firstClear = true
		-- One-time and saved as cleared at once, so it goes straight into the Bag (only repeatable loot scatters)
		for _, entry in boss.firstClear do
			ItemService.GiveItem(player, entry.item, entry.count)
		end
		result.chest = boss.firstClear
		Remotes.BossCleared:FireAllClients(player.DisplayName, bossId)
		setTitle(player)
		if boss.announceEverywhere then
			announceEverywhere(player, bossId)
		end
	end
	if fight.seconds < boss.minFightSeconds then
		result.flagged = true
	elseif BossRules.lootEligible(record, now) then
		local factor = BossRules.dropFactor(Bosses, record, partyPower(player, fight.fighterIds), boss.recommended)
		result.reduced = factor < 1
		record.lootAt = now + Bosses.LOOT_COOLDOWN
		record.rewardedToday += 1
		local drops: { Grant } = {}
		for _, drop in boss.drops do
			local chance = drop.chance * factor
			if carried then
				chance = BossRules.carriedDrop(Bosses, drop.item, chance, opensBoss[drop.item] ~= nil)
			end
			if wanted(byBoss, drop.item) and rng:NextNumber() < chance then
				table.insert(drops, { item = drop.item, count = rng:NextInteger(drop.min, drop.max) })
			end
		end
		grant(player, drops, result.items)
		if record.bonusDay ~= today and not carried then
			record.bonusDay = today
			result.bonus = true
			grant(player, boss.dailyBonus, result.items)
		end
	end
	result.lootIn = math.max(0, record.lootAt - now)
	dropLoot(player, monster, result.items)
	sendBosses(player)
	return result
end

local function describeItem(id: string): string
	local item = Items.ITEMS[id]
	return if item then item.name else id
end

-- Gates ----------------------------------------------------------------------------------------------------

-- Why this player can't take part in this boss now (record, distance from the gate, shop level, key, able to fight), or nil
local function whyNotMember(player: Player, bossId: string, reach: number): string?
	local boss = Bosses.BOSSES[bossId]
	local arena = arenas[bossId]
	local record = BossService.GetRecord(player, bossId)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not boss or not arena or not record or not root or not player.Parent then
		return "You can't fight right now."
	end
	if (root.Position - arena.gatePosition).Magnitude > reach then
		return "Get closer to the gate."
	end
	if not BossRules.levelReady(boss.shopLevel, EconomyService.GetLevel(player)) then
		return `The {boss.name} opens at shop level {boss.shopLevel}.`
	end
	local unlock = boss.unlock
	local owned = if unlock then ItemService.GetCount(player, unlock.item) else 0
	if not BossRules.canStart(record, unlock, owned) and unlock then
		return `Needs {unlock.count} {describeItem(unlock.item)}s (you have {owned}). Beat the boss before it.`
	end
	return BattleService.WhyNotFight(player)
end

-- Who still holds a remote arena copy: its fighters still in the game and near it (one who respawned at their shop
-- or left no longer does)
local function copyFighters(bossId: string, index: number): { Player }
	local copy = arenas[bossId].copies[index]
	local held = {}
	for _, player in (fighters[bossId] or {})[index] or {} do
		local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		local distance = if root then (root.Position - copy.center).Magnitude else math.huge
		if BossRules.stillInCopy(player.Parent ~= nil, distance, Bosses.ARENA_RADIUS) then
			table.insert(held, player)
		end
	end
	fighters[bossId] = fighters[bossId] or {}
	fighters[bossId][index] = held
	return held
end

-- Which of a boss's arena copies can take a new fight
local function freeCopies(bossId: string): { boolean }
	local free = {}
	for index, copy in arenas[bossId].copies do
		local loading = (reserved[bossId] or {})[index] == true
		local held = if copy.remote then #copyFighters(bossId, index) else 0
		free[index] = not loading and BossRules.copyFree((occupants[bossId] or {})[index], held)
	end
	return free
end

-- Why the arena can't take this player now: every copy busy, or a group forming that they're not in (only where the
-- boss has a single arena)
local function whyArenaBusy(player: Player, bossId: string): string?
	local boss = Bosses.BOSSES[bossId]
	local copies = #arenas[bossId].copies
	if not BossRules.pickCopy(freeCopies(bossId)) then
		return if copies > 1 then `All the {boss.name}'s arenas are busy. Try again in a moment.` else `Someone is fighting the {boss.name}. Wait for them to finish.`
	end
	local lobby = lobbies[bossId]
	if lobby and not table.find(lobby.members, player) and BossRules.soloBlockedByLobby(copies) then
		return `A group is forming at the {boss.name}: join it (F) or wait.`
	end
	return nil
end

-- Out of an arena copy: through the ring's gate, or (a remote copy) back to the boss's portal in the valley, its spot
-- streamed in first. A player who isn't (or is no longer) in the fight never stays behind the sealed wall.
local function moveOut(player: Player, copy: WildService.ArenaCopy)
	if copy.remote then
		task.spawn(WildService.MoveInWild, player, copy.exit)
		return
	end
	local character = player.Character
	if character then
		character:PivotTo(copy.exit)
	end
end

-- Everyone inside the ring who isn't one of `members` (someone waiting at the gate) goes out before it seals
local function clearRing(copy: WildService.ArenaCopy, members: { Player })
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		local offset = if root then root.Position - copy.center else nil
		if offset and not table.find(members, player) and BossRules.insideRing(offset.X, offset.Z, Bosses.ARENA_RADIUS) then
			moveOut(player, copy)
		end
	end
end

local function setBarrier(copy: WildService.ArenaCopy, up: boolean)
	for _, wall in copy.barrier do
		wall.CanCollide = up
		wall.Transparency = if up then Bosses.BARRIER_TRANSPARENCY else 1
	end
end

-- One boss for these players (the first leads) in arena copy `index`, scaled to the group; keys are taken only once
-- it really starts. No yields: the key counts and the fight start in one step.
local function startBoss(bossId: string, players: { Player }, index: number, options: BattleService.RunOptions?): (boolean, string?)
	local boss = Bosses.BOSSES[bossId]
	local copy = arenas[bossId].copies[index]
	local monster = WildService.SpawnAt(copy.spawn.Position, boss.name, boss.level, false, bossId, boss.zone)
	if not monster then
		return false, "The boss couldn't start. Try again."
	end
	monster.marker.CFrame = copy.spawn
	local started, why = BattleService.StartGroupFight(players, monster, options)
	if not started then
		WildService.Defeat(monster)
		return false, why or "The boss couldn't start. Try again."
	end
	occupants[bossId] = occupants[bossId] or {}
	occupants[bossId][index] = monster -- free again once it's beaten or gone (alive = false) and its fighters have left
	if copy.remote then
		fighters[bossId] = fighters[bossId] or {}
		fighters[bossId][index] = table.clone(players)
	end
	-- Everyone in, then the ring seals until the fight ends (BattleService.OnFightEnded)
	for slot, player in players do
		local character = player.Character
		if character then
			local sideways = (slot - (#players + 1) / 2) * Bosses.INSIDE_STEP
			character:PivotTo(copy.inside * CFrame.new(sideways, 0, 0))
		end
	end
	clearRing(copy, players)
	setBarrier(copy, true)
	local unlock = boss.unlock
	for _, player in players do
		local record = BossService.GetRecord(player, bossId)
		if record and not record.unlocked and unlock then
			ItemService.TakeItem(player, unlock.item, unlock.count)
			record.unlocked = true
			notify(player, `Used {unlock.count} {describeItem(unlock.item)}s: the {boss.name} is open for good.`, false)
			sendBosses(player)
		end
	end
	return true, nil
end

-- A free arena copy for these players: a remote one is held for them and streamed in on their devices first (they
-- wait at the portal, WildConfig.STREAM_TIMEOUT at most), then each is checked again (within `reach` of the gate) and
-- the fight starts in one step. Nobody is moved if nobody is left.
local function enterCopy(bossId: string, players: { Player }, reach: number, options: BattleService.RunOptions?): (boolean, string?)
	local index = BossRules.pickCopy(freeCopies(bossId))
	if not index then
		return false, whyArenaBusy(players[1], bossId)
	end
	local copy = arenas[bossId].copies[index]
	if copy.remote then
		reserved[bossId] = reserved[bossId] or {}
		reserved[bossId][index] = true
		local waiting = #players
		for _, player in players do
			entering[player] = true
			task.spawn(function()
				WildService.Prestream(player, copy.inside.Position)
				waiting -= 1
			end)
		end
		local deadline = os.clock() + WildConfig.STREAM_TIMEOUT
		while waiting > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
		reserved[bossId][index] = nil
		for _, player in players do
			entering[player] = nil
		end
	end
	local ready: { Player } = {}
	for _, player in players do
		local reason = whyNotMember(player, bossId, reach)
		if not reason then
			table.insert(ready, player)
		elseif player.Parent then
			notify(player, reason, true)
		end
	end
	if #ready == 0 then
		return false, nil
	end
	return startBoss(bossId, ready, index, options)
end

-- The Fight prompt: the boss for this player alone (the Dungeon: its run decides who fights)
local function onGate(player: Player, bossId: string)
	if runGate then
		runGate(player, bossId)
		return
	end
	if not allowStart(player) or not Bosses.BOSSES[bossId] or not arenas[bossId] or entering[player] then
		return
	end
	local lobby = lobbies[bossId]
	if lobby and table.find(lobby.members, player) then
		notify(player, "You're in the group forming here: it starts soon (the leader can start it now with F).", true)
		return
	end
	local reason = whyArenaBusy(player, bossId) or whyNotMember(player, bossId, Bosses.GATE_DISTANCE)
	if reason then
		notify(player, reason, true)
		return
	end
	local started, why = enterCopy(bossId, { player }, Bosses.GATE_DISTANCE)
	if not started and why then
		notify(player, why, true)
	end
end

-- Out of a remote arena copy and back to the boss's portal, whatever loot is still lying going into the Bag first
local function sendBack(player: Player, bossId: string, index: number)
	local held = (fighters[bossId] or {})[index]
	local at = if held then table.find(held, player) else nil
	if at then
		table.remove(held :: { Player }, at)
	end
	collectAll(player)
	WildService.MoveInWild(player, arenas[bossId].copies[index].exit)
end

-- A remote copy's Return portal: home to the boss's portal once the fight there is over
local function onReturn(player: Player, bossId: string, index: number)
	if not allowTravel(player) or not arenas[bossId] or not arenas[bossId].copies[index] then
		return
	end
	local occupant = (occupants[bossId] or {})[index]
	if occupant and occupant.alive and table.find((fighters[bossId] or {})[index] or {}, player) then
		notify(player, "Finish the fight first.", true)
		return
	end
	sendBack(player, bossId, index)
end

-- Players who left the game are dropped from a forming group (the next member leads); an empty group closes
local function pruneLobby(bossId: string)
	local lobby = lobbies[bossId]
	if not lobby then
		return
	end
	local present = {}
	for _, member in lobby.members do
		if member.Parent then
			table.insert(present, member)
		end
	end
	lobby.members = present
	if #present == 0 then
		lobbies[bossId] = nil
	end
end

local function updateGroupPrompt(bossId: string)
	local lobby = lobbies[bossId]
	local prompt = arenas[bossId].groupPrompt
	local members = if lobby then #lobby.members else 0
	prompt.ActionText = BossRules.groupPromptText(Bosses, members, false)
	prompt:SetAttribute("Members", members)
	prompt:SetAttribute("LeaderId", if lobby then lobby.members[1].UserId else nil)
end

-- The lobby closes (time up, full, or the leader starts it): members who can still fight go in, the first one leads
local function closeLobby(bossId: string)
	local lobby = lobbies[bossId]
	if not lobby then
		return
	end
	lobbies[bossId] = nil
	updateGroupPrompt(bossId)
	local boss = Bosses.BOSSES[bossId]
	local ready: { Player } = {}
	for _, player in lobby.members do
		local reason = whyNotMember(player, bossId, Bosses.GATE_DISTANCE * 2)
		if reason then
			if player.Parent then
				notify(player, `You weren't let into the {boss.name} fight: {reason}`, true)
			end
		else
			table.insert(ready, player)
		end
	end
	if #ready == 0 then
		return
	end
	local started, why = enterCopy(bossId, ready, Bosses.GATE_DISTANCE * 2)
	if not started and why then
		for _, player in ready do
			notify(player, why, true)
		end
	end
end

-- The group prompt: open a group (the leader), join one, or (the leader again) start it now
local function onGroup(player: Player, bossId: string)
	if runGate then
		runGate(player, bossId)
		return
	end
	local boss = Bosses.BOSSES[bossId]
	if not allowGroup(player) or not boss or not arenas[bossId] then
		return
	end
	pruneLobby(bossId)
	updateGroupPrompt(bossId)
	local lobby = lobbies[bossId]
	if lobby then
		if lobby.members[1] == player then
			closeLobby(bossId)
			return
		elseif table.find(lobby.members, player) then
			notify(player, `Waiting for {lobby.members[1].DisplayName} to start ({#lobby.members}/{Bosses.GROUP_MAX}).`, false)
			return
		elseif #lobby.members >= Bosses.GROUP_MAX then
			notify(player, "That group is full.", true)
			return
		end
		local reason = whyNotMember(player, bossId, Bosses.GATE_DISTANCE)
		if reason then
			notify(player, reason, true)
			return
		end
		table.insert(lobby.members, player)
		updateGroupPrompt(bossId)
		for _, member in lobby.members do
			notify(member, `{player.DisplayName} joined the {boss.name} group ({#lobby.members}/{Bosses.GROUP_MAX}).`, false)
		end
		if #lobby.members >= Bosses.GROUP_MAX then
			closeLobby(bossId)
		end
		return
	end
	local reason = whyArenaBusy(player, bossId) or whyNotMember(player, bossId, Bosses.GATE_DISTANCE)
	if reason then
		notify(player, reason, true)
		return
	end
	local opened = { members = { player } }
	lobbies[bossId] = opened
	updateGroupPrompt(bossId)
	notify(player, `Group open: others have {Bosses.JOIN_SECONDS} s to join at the gate (F). Press F again to start now.`, false)
	task.delay(Bosses.JOIN_SECONDS, function()
		if lobbies[bossId] == opened then
			closeLobby(bossId)
		end
	end)
end

-- /boss <n> fight and /boss <n> group: the gate's prompts, as if used (same checks)
-- The Dungeon: its run's players fight this boss together with the HP they have left. Each must pass the gate's checks
-- (shop level, key) wherever they stand; the key is taken on the first start as at any gate.
function BossService.StartRun(bossId: string, players: { Player }, hpLeft: { [Player]: { [string]: number } }): (boolean, string?)
	if not Bosses.BOSSES[bossId] or not arenas[bossId] or #players == 0 then
		return false, "The boss couldn't start. Try again."
	end
	for _, player in players do
		local reason = whyArenaBusy(player, bossId) or whyNotMember(player, bossId, math.huge)
		if reason then
			return false, if #players > 1 then `{player.DisplayName}: {reason}` else reason
		end
	end
	return startBoss(bossId, players, BossRules.pickCopy(freeCopies(bossId)) or 1, { hpLeft = hpLeft, run = true })
end

-- The Dungeon: its arena's prompts go to the run (DungeonService) instead of starting a fight here
function BossService.SetRunGate(handler: (player: Player, bossId: string) -> ())
	runGate = handler
end

function BossService.UseGate(player: Player, index: number, group: boolean?)
	local bossId = Bosses.LADDER[index]
	if bossId then
		if group then
			onGroup(player, bossId)
		else
			onGate(player, bossId)
		end
	end
end

local function load(player: Player, data: DataService.PlayerData)
	local saved = if typeof(data.bosses) == "table" then data.bosses else {}
	local byBoss: { [string]: BossRules.Record } = {}
	for _, bossId in Bosses.LADDER do
		byBoss[bossId] = BossRules.read(saved[bossId], Bosses.BOSSES[bossId].unlock == nil)
	end
	records[player] = byBoss
	setTitle(player)
	task.defer(sendBosses, player) -- after the other services load (fragment counts)
end

local function save(player: Player, data: DataService.PlayerData)
	local byBoss = records[player]
	if not byBoss then
		return -- never loaded: keep what's saved
	end
	data.bosses = BossRules.write(data.bosses, byBoss)
end

local function unload(player: Player)
	records[player] = nil
	pending[player] = nil -- loot left on the ground is gone
	-- Out of any group forming: the next member leads, the prompt shows the new count
	for bossId, lobby in lobbies do
		if table.find(lobby.members, player) then
			local index = table.find(lobby.members, player) :: number
			table.remove(lobby.members, index)
			if #lobby.members == 0 then
				lobbies[bossId] = nil
			end
			updateGroupPrompt(bossId)
		end
	end
end

-- The board's Take me there: only to a gate in this place (BossRules.travelChoice); the Wild's travel checks (in a
-- fight, a run, ...) still apply. Other places use their own travel (the Frontier portal), started by the client.
local function onTravel(player: Player, raw: unknown)
	if typeof(raw) ~= "number" or raw ~= math.floor(raw) or raw < 1 or raw > #Bosses.LADDER or not allowTravel(player) then
		return
	end
	local boss = Bosses.BOSSES[Bosses.LADDER[raw]]
	local here = if Place.isDungeon() then "Dungeon" elseif Place.isFrontier() then "Frontier" else "Main"
	local gate = BossService.GetGate(raw)
	if BossRules.travelChoice(boss.place, here) ~= "gate" or not gate then
		notify(player, `The {boss.name} isn't in this place.`, true)
		return
	end
	WildService.TravelToWild(player, gate)
end

function BossService.Start()
	DataService.Register({ name = "BossService", load = load, save = save, unload = unload })
	arenas = WildService.BuildBossArenas(onGate, onGroup, onReturn)
	BattleService.SetBossRewards(onBossWin)
	BattleService.OnMemberLeft(function(player, monster)
		local copy, index = copyOf(monster)
		if copy and index then
			if copy.remote then
				sendBack(player, monster.boss :: string, index)
			else
				moveOut(player, copy)
			end
		end
	end)
	BattleService.OnFightEnded(function(monster)
		local copy, index = copyOf(monster)
		local bossId = monster.boss :: string
		if not copy or not index or not BossRules.shouldUnseal(monster, (occupants[bossId] or {})[index]) then
			return
		end
		setBarrier(copy, false)
		if copy.remote then
			-- time to pick up the loot, then whoever is still there goes back to the portal (loot into the Bag)
			task.delay(Bosses.ARENA_LINGER, function()
				if (occupants[bossId] or {})[index] ~= monster then
					return -- another fight has the copy now
				end
				for _, player in copyFighters(bossId, index) do
					sendBack(player, bossId, index)
				end
			end)
		end
	end)
	Remotes.RequestBosses.OnServerEvent:Connect(function(player)
		if allowRequest(player) then
			sendBosses(player)
		end
	end)
	Remotes.PickUpLoot.OnServerEvent:Connect(onPickUp)
	Remotes.BossTravel.OnServerEvent:Connect(onTravel)
	if Place.isDungeon() then
		for _, arena in arenas do
			arena.groupPrompt.Enabled = false -- the run is the group
		end
	end
	-- Other servers' first clears of the bosses everyone hears about
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(Bosses.CLEARED_TOPIC, function(message)
				local data = message.Data
				if typeof(data) ~= "table" or data.jobId == game.JobId then
					return -- junk, or this server's own (already shown)
				end
				local name, bossId = data.name, data.bossId
				if typeof(name) == "string" and #name <= 40 and typeof(bossId) == "string" and Bosses.BOSSES[bossId] then
					Remotes.BossCleared:FireAllClients(name, bossId)
				end
			end)
		end)
		if not ok then
			warn(`[BossService] cross-server clears unavailable: {err}`)
		end
	end)
end

return BossService
