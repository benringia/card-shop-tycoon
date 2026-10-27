--!strict
-- The boss ladder (Config/Bosses, spec 2026-10-28-boss-ladder-design.md): each player's progress on every boss
-- (saved: data.bosses), the arenas' gates, the fights and their rewards. Rules (unlock, loot cooldown, soft cap,
-- over-power) are in Util/BossRules. A boss is spawned for the one player who starts it at the gate and fought on the
-- usual combat core (BattleService); a win's XP and cash come from there, its items from here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Cards = require(Config:WaitForChild("Cards"))
local Items = require(Config:WaitForChild("Items"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local BossRules = require(Shared:WaitForChild("Util"):WaitForChild("BossRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local BattleService = require(Services:WaitForChild("BattleService"))
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local WildService = require(Services:WaitForChild("WildService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type Grant = { item: string, count: number }

local BossService = {}

local records: { [Player]: { [string]: BossRules.Record } } = {} -- loaded players only
local arenas: { [string]: WildService.BossArena } = {}
local occupants: { [string]: WildService.Monster } = {} -- the boss being fought in each arena (one fight at a time)
local lobbies: { [string]: { members: { Player } } } = {} -- a group forming at each gate (the first member leads)
local allowStart = RateLimiter.new(Bosses.START_COOLDOWN)
local allowRequest = RateLimiter.new(1)
local rng = Random.new()

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

-- Gives the grants and adds what was really given to `got` (merged by item)
local function grant(player: Player, grants: { Grant }, got: { Grant })
	for _, entry in grants do
		local given = ItemService.GiveItem(player, entry.item, entry.count)
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
		grant(player, boss.firstClear, result.items)
		Remotes.BossCleared:FireAllClients(player.DisplayName, bossId)
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
	sendBosses(player)
	return result
end

local function describeItem(id: string): string
	local item = Items.ITEMS[id]
	return if item then item.name else id
end

-- Gates ----------------------------------------------------------------------------------------------------

-- Why this player can't take part in this boss now (record, distance from the gate, key, able to fight), or nil
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
	local unlock = boss.unlock
	local owned = if unlock then ItemService.GetCount(player, unlock.item) else 0
	if not BossRules.canStart(record, unlock, owned) and unlock then
		return `Needs {unlock.count} {describeItem(unlock.item)}s (you have {owned}). Beat the boss before it.`
	end
	return BattleService.WhyNotFight(player)
end

-- Why the arena can't take this player now: someone else's fight, or a group forming that they're not in
local function whyArenaBusy(player: Player, bossId: string): string?
	local boss = Bosses.BOSSES[bossId]
	local occupant = occupants[bossId]
	if occupant and occupant.alive and occupant.fightingPlayer ~= player then
		return `Someone is fighting the {boss.name}. Wait for them to finish.`
	end
	local lobby = lobbies[bossId]
	if lobby and not table.find(lobby.members, player) then
		return `A group is forming at the {boss.name}: join it (F) or wait.`
	end
	return nil
end

-- One boss for these players (the first leads), scaled to the group; keys are taken only once it really starts.
-- No yields: the key counts and the fight start in one step.
local function startBoss(bossId: string, players: { Player }): (boolean, string?)
	local boss = Bosses.BOSSES[bossId]
	local arena = arenas[bossId]
	local monster = WildService.SpawnAt(arena.spawn.Position, boss.name, boss.level, false, bossId)
	if not monster then
		return false, "The boss couldn't start. Try again."
	end
	monster.marker.CFrame = arena.spawn
	local started, why = BattleService.StartGroupFight(players, monster)
	if not started then
		WildService.Defeat(monster)
		return false, why or "The boss couldn't start. Try again."
	end
	occupants[bossId] = monster -- free again once it's defeated or despawned (alive = false)
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

-- The Fight prompt: the boss for this player alone
local function onGate(player: Player, bossId: string)
	if not allowStart(player) or not Bosses.BOSSES[bossId] or not arenas[bossId] then
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
	local started, why = startBoss(bossId, { player })
	if not started then
		notify(player, why or "The boss couldn't start. Try again.", true)
	end
end

local function updateGroupPrompt(bossId: string)
	local lobby = lobbies[bossId]
	arenas[bossId].groupPrompt.ActionText = if lobby then `Join group ({#lobby.members}/{Bosses.GROUP_MAX})` else "Start group"
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
	local started, why = startBoss(bossId, ready)
	if not started then
		for _, player in ready do
			notify(player, why or "The boss couldn't start. Try again.", true)
		end
	end
end

-- The group prompt: open a group (the leader), join one, or (the leader again) start it now
local function onGroup(player: Player, bossId: string)
	local boss = Bosses.BOSSES[bossId]
	if not allowStart(player) or not boss or not arenas[bossId] then
		return
	end
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
end

function BossService.Start()
	DataService.Register({ name = "BossService", load = load, save = save, unload = unload })
	arenas = WildService.BuildBossArenas(onGate, onGroup)
	BattleService.SetBossRewards(onBossWin)
	Remotes.RequestBosses.OnServerEvent:Connect(function(player)
		if allowRequest(player) then
			sendBosses(player)
		end
	end)
end

return BossService
