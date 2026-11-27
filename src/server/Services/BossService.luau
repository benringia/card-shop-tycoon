--!strict
-- The boss ladder (Config/Bosses, spec 2026-10-28-boss-ladder-design.md): each player's progress on every boss
-- (saved: data.bosses), the arenas' gates, the fights and their rewards. Rules (unlock, loot cooldown, soft cap) are in
-- Util/BossRules. A boss is spawned for the one player who starts it at the gate and fought on the
-- usual combat core (BattleService); a win's XP and cash come from there, its items from here.
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Dungeon = require(Config:WaitForChild("Dungeon"))
local DungeonRules = require(Shared:WaitForChild("Util"):WaitForChild("DungeonRules"))
local WildConfig = require(Config:WaitForChild("Wild")) -- the main game's: a remote arena copy streams in within its STREAM_TIMEOUT
local Items = require(Config:WaitForChild("Items"))
local Weapons = require(Config:WaitForChild("Weapons"))
local Victory = require(Config:WaitForChild("Victory"))
local Announcements = require(Config:WaitForChild("Announcements"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local Cards = require(Config:WaitForChild("Cards"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local BossRules = require(Shared:WaitForChild("Util"):WaitForChild("BossRules"))
local EventNow = require(Shared:WaitForChild("Util"):WaitForChild("EventNow"))
local EventRules = require(Shared:WaitForChild("Util"):WaitForChild("EventRules"))
local PaidRandomRules = require(Shared:WaitForChild("Util"):WaitForChild("PaidRandomRules"))
local WeaponRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponRules"))
local MutationRules = require(Shared:WaitForChild("Util"):WaitForChild("MutationRules"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Blocked = require((script.Parent :: Instance).Parent:WaitForChild("Util"):WaitForChild("Blocked"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local ValleyConfig = Place.getValley() -- ARENA_HOLD: how far from a remote copy's middle its fighters hold it (remote copies are a valley's)
local Combat = require(Config:WaitForChild("Combat"))
local Teams = require(Config:WaitForChild("Teams"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local DevAccess = require(Util:WaitForChild("DevAccess"))
local BattleService = require(Services:WaitForChild("BattleService"))
local BossChestService = require(Services:WaitForChild("BossChestService"))
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local PurchaseService = require(Services:WaitForChild("PurchaseService"))
local WeaponService = require(Services:WaitForChild("WeaponService"))
local WildService = require(Services:WaitForChild("WildService"))
local TeamService = require(Services:WaitForChild("TeamService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type Grant = { item: string, count: number }

local BossService = {}

local records: { [Player]: { [string]: BossRules.Record } } = {} -- loaded players only
local secretFound: { [Player]: boolean } = {} -- found the Dungeon's secret chest once (saved data.dungeon.secretFound)
-- told whenever a player's boss clears or secret change (TitleService: the titles they've earned)
local progressHooks: { (player: Player, progress: { cleared: { [string]: boolean }, secret: boolean }) -> () } = {}
local seenIntro: { [Player]: boolean } = {} -- saw the Hydra's full welcome (saved data.dungeon.seenIntro)
-- The loot timers this server tells the player about when they run out (Bosses.LOOT_READY, owner 2026-11-27): ones
-- started here and ones still running when they came
local watched: { [Player]: { [string]: boolean } } = {}
local arenas: { [string]: WildService.BossArena } = {}
local occupants: { [string]: { [number]: WildService.Monster } } = {} -- the boss being fought in each arena copy
local fighters: { [string]: { [number]: { Player } } } = {} -- who fought in each remote copy (they hold it until they leave)
local reserved: { [string]: { [number]: boolean } } = {} -- remote copies being loaded for a fight about to start
local entering: { [Player]: boolean } = {} -- players whose fight is being set up
local lobbies: { [string]: { members: { Player }, closesAt: number } } = {} -- a group forming at each gate (the first member leads)
local traveling: { [Player]: boolean } = {} -- teammates on their way to a group's gate (it waits for them as it starts)
local allowTeamJoin = RateLimiter.new(1)
local allowStart = RateLimiter.new(Bosses.START_COOLDOWN)
local allowPickUp = RateLimiter.new(Bosses.LOOT_PICKUP_COOLDOWN)
local allowGroup = RateLimiter.new(Bosses.START_COOLDOWN) -- its own, so Fight then F right after both work
local allowReset = RateLimiter.new(1)
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
	if isError then
		Blocked.tell(player, message) -- a refusal: the big locked card with why (owner 2026-11-12), never just a toast
		return
	end
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
			bonusReady = record.bonusDay ~= today, -- the day's first loot win still adds its daily chest
			fragments = if unlock then ItemService.GetCount(player, unlock.item) else 0,
			weaponPity = record.weaponPity, -- loot wins since its weapon last dropped (the board's drop chance)
		}
	end
	Remotes.BossesChanged:FireClient(player, payload)
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
-- full loot once per LOOT_COOLDOWN per boss, its chances shrunk by the daily soft cap (the owner 2026-11-19 removed the
-- minimum fight time and the over-power shrink: strong players farm the early bosses' weapons and materials); the
-- first clear and the day's first rewarded win add their chests. A group member who helped too little
-- (fight.contributed false) gets only the carried roll: a quarter of the chances, no fragments, no chests.
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

-- What a player has done that titles come from: the bosses they've cleared and the Dungeon's secret
local function progressOf(player: Player): { cleared: { [string]: boolean }, secret: boolean }
	local cleared = {}
	for bossId, record in records[player] or {} do
		if record.cleared then
			cleared[bossId] = true
		end
	end
	return { cleared = cleared, secret = secretFound[player] == true }
end

-- Tells TitleService (the title over the name is its: Config/Titles; owner 2026-11-12) what changed, and the player's
-- clients which bosses they've beaten (attribute BossesCleared, "frostTyrant,meadowWarden": the order computer's
-- Frontier Pack opens with the Frost Tyrant, Config/Products unlockBoss)
local function setTitle(player: Player)
	local progress = progressOf(player)
	local ids = {}
	for bossId in progress.cleared do
		table.insert(ids, bossId)
	end
	table.sort(ids)
	player:SetAttribute("BossesCleared", table.concat(ids, ","))
	for _, hook in progressHooks do
		task.spawn(hook, player, progress)
	end
end

-- A player's boss clears and secret, for their titles (TitleService)
function BossService.Progress(player: Player): { cleared: { [string]: boolean }, secret: boolean }
	return progressOf(player)
end

-- Told whenever a player's progress changes (TitleService)
function BossService.OnProgress(callback: (player: Player, progress: { cleared: { [string]: boolean }, secret: boolean }) -> ())
	table.insert(progressHooks, callback)
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

-- Each boss's own weapon (Config/Weapons, built ones only): bossId -> weapon id
local weaponOf: { [string]: string } = {}
for _, weapon in Weapons.WEAPONS do
	if weapon.ready and weapon.source.kind == "boss" and weapon.source.boss then
		weaponOf[weapon.source.boss] = weapon.id
	end
end

-- offer: a weapon you had already: its mutation roll (WeaponService.Offer), shown by its reveal with the choice
-- `gradeUp`: a duplicate drop at a better grade upgraded the one you had (owner 2026-11-27: "upgrade and tell them")
type WeaponPayload = {
	weaponId: string,
	grade: string,
	refund: number,
	material: string?,
	offer: WeaponService.Offer?,
	gradeUp: { from: string, to: string, level: number }?,
}

-- The Dungeon's secret chest found (DungeonPuzzleService): true the first time ever (saved; the title Crystal Seeker
-- shows unless Dungeon Conqueror outranks it), false after or for a player whose data isn't loaded
function BossService.MarkSecretFound(player: Player): boolean
	if not records[player] or secretFound[player] then
		return false
	end
	secretFound[player] = true
	setTitle(player)
	return true
end

-- Which welcome the Dungeon gives this player as its run opens (spec 2026-11-12-dungeon-atmosphere): the full one the
-- first time ever, then short ones; marks it seen (saved)
function BossService.IntroKind(player: Player): "full" | "short"
	return DungeonRules.introKind(seenIntro[player] == true)
end

-- The player's client started the Hydra's welcome (DungeonService, on its ack): the full one is seen
function BossService.MarkIntroSeen(player: Player)
	if records[player] then
		seenIntro[player] = true
	end
end

-- Whether this player found the Dungeon's secret chest before
function BossService.HasFoundSecret(player: Player): boolean
	return secretFound[player] == true
end

-- A boss's weapon is given to this player (weapons round 1): its grade rolled like a card's. One you have already is a
-- mutation roll instead (weapons round 4 part 2: on at once when it has none, else Take new or Keep mine), and when its
-- rolled grade is better it upgrades yours, level and mutation kept (`gradeUp`, owner 2026-11-27). Nothing shows yet:
-- AnnounceWeapon does that. nil: it couldn't be given.
function BossService.GiveWeapon(player: Player, weaponId: string): WeaponPayload?
	local weapon = Weapons.ById[weaponId]
	if not weapon or not WeaponService.IsLoaded(player) then
		return nil
	end
	local before = WeaponService.GetAll(player)[weaponId]
	local had = before ~= nil
	local fromGrade = if before then before.grade else nil
	local grade = BeastRules.rollGrade(rng:NextNumber(), weapon.rarity)
	local record, refund = WeaponService.Give(player, weaponId, grade, "drop")
	local gradeUp = if had and record and fromGrade then { from = fromGrade, to = record.grade, level = record.level } else nil
	local offer = if had then WeaponService.Offer(player, weaponId, MutationRules.roll(Mutations, rng:NextNumber(), rng:NextNumber()), "drop") else nil
	return {
		weaponId = weaponId,
		grade = grade,
		refund = refund,
		material = WeaponRules.material(Weapons, weaponId),
		offer = offer,
		gradeUp = gradeUp,
	}
end

-- A given weapon's moment: the drop cinematic on their screen (a mutation's reveal for one they had), a new one's light
-- column for everyone near (each client checks the distance, WeaponLookRules.seesBeacon) and, for a new Epic or
-- Legendary, the whole server hears (even when they've just left: `here` false)
function BossService.AnnounceWeapon(player: Player, payload: WeaponPayload, here: boolean?)
	local fresh = payload.offer == nil and payload.refund <= 0
	if here ~= false and player.Parent then
		Remotes.WeaponDropped:FireClient(player, payload)
		local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
		if fresh and root and root:IsA("BasePart") then
			Remotes.WeaponBeacon:FireAllClients(player.UserId, payload.weaponId, root.Position)
		end
	end
	if fresh and WeaponRules.announces(Weapons, payload.weaponId, payload.refund) then
		Remotes.WeaponAnnouncement:FireAllClients(player.DisplayName, payload.weaponId, payload.grade, player.UserId)
	end
end

-- A boss's weapon drops for this player now, shown after `delay` seconds (Studio's /weapondrop)
function BossService.DropWeapon(player: Player, weaponId: string, delay: number?): WeaponPayload?
	local payload = BossService.GiveWeapon(player, weaponId)
	if payload then
		task.delay(delay or 0, BossService.AnnounceWeapon, player, payload)
	end
	return payload
end

-- A boss's Frontier card (Config/Bosses card; owner 2026-11-21: "Make the boss drop frontier cards and make it
-- noticeable"): on a loot win, for those who helped, a card of the rolled rarity goes into the binder at once. Its
-- big moment (FrontierRevealController's "FRONTIER CARD!") follows the victory screen, where its tile already shows
-- in gold; the chests wait for it. An Epic or Legendary one is told to the whole server, like a monster's
local forcedCards: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local FALLBACK_CARD = { chance = 1, rarity = { Rare = 60, Epic = 30, Legendary = 10 } } -- Studio's /bosscard on a Wild boss

local function revealCard(player: Player, cardId: string, grade: string)
	if not player.Parent then
		return
	end
	local card = Cards.ById[cardId]
	if card and Announcements.FRONTIER_RARITIES[card.rarity] then
		Remotes.PullAnnouncement:FireAllClients(player.DisplayName, cardId, false, "frontier", player.UserId, grade)
	else
		Remotes.PullAnnouncement:FireClient(player, player.DisplayName, cardId, false, "frontier", player.UserId, grade)
	end
end

local function rollCard(player: Player, boss: Bosses.Boss): { cardId: string, foil: boolean, grade: string }?
	local forced = forcedCards[player]
	forcedCards[player] = nil
	local rarity = if forced
		then BossRules.cardRarity(boss.card or FALLBACK_CARD, 0, rng:NextNumber())
		else BossRules.cardRarity(boss.card, rng:NextNumber(), rng:NextNumber())
	if not rarity then
		return nil
	end
	local pool = {}
	for _, card in Cards.BySet.Frontier do
		if card.rarity == rarity then
			table.insert(pool, card.id)
		end
	end
	if #pool == 0 then
		return nil
	end
	local dropped = { cardId = pool[rng:NextInteger(1, #pool)], foil = false, grade = BeastRules.rollGrade(rng:NextNumber(), rarity) }
	CardService.AddFresh(player, { dropped })
	task.delay(Victory.SECONDS, revealCard, player, dropped.cardId, dropped.grade)
	return dropped
end

-- Studio's /bosscard: this player's next boss loot win drops a Frontier card
-- Studio (/bossbeaten <n> on|off): boss n counts as beaten and opened (to try a beaten boss's Take me there), and off
-- puts back what it was before the on (with no on before: never beaten, never opened); the board told at once. False
-- when it can't (not Studio, an unknown boss, not loaded)
local beatenBefore: { [Player]: { [string]: { cleared: boolean, unlocked: boolean } } } = {}
function BossService.DevSetBeaten(player: Player, index: number, beaten: boolean): boolean
	if not DevAccess.can(player) then
		return false
	end
	local bossId = Bosses.LADDER[index]
	local mine = records[player]
	local record = if bossId and mine then mine[bossId] else nil
	if not record then
		return false
	end
	local kept = beatenBefore[player] or {}
	beatenBefore[player] = kept
	if beaten then
		kept[bossId] = kept[bossId] or { cleared = record.cleared, unlocked = record.unlocked }
		record.cleared = true
		record.unlocked = true
	else
		local before = kept[bossId]
		kept[bossId] = nil
		record.cleared = if before then before.cleared else false
		record.unlocked = if before then before.unlocked else Bosses.BOSSES[bossId].unlock == nil
	end
	sendBosses(player)
	setTitle(player) -- (BossesCleared: what it opens, the Frontier Pack, follows)
	return true
end

function BossService.ForceCardForTest(player: Player)
	forcedCards[player] = true
end

-- On a loot win (BossRules.rollsWeapon): the boss's weapon at WeaponRules.dropChance of its pity, given at once
-- (its chest shows it, BossChestService); a drop given resets the pity, anything else adds one (BossRules.nextWeaponPity)
local function rollWeapon(player: Player, bossId: string, record: BossRules.Record): WeaponPayload?
	local weaponId = weaponOf[bossId]
	if not weaponId then
		return nil
	end
	local rolled = rng:NextNumber() < WeaponRules.dropChance(Weapons, weaponId, record.weaponPity)
	local payload = if rolled then BossService.GiveWeapon(player, weaponId) else nil
	record.weaponPity = BossRules.nextWeaponPity(record.weaponPity, rolled, payload ~= nil)
	return payload
end

function BossService.WeaponOf(bossId: string): string?
	return weaponOf[bossId]
end

local function onBossWin(player: Player, monster: WildService.Monster, fight: { contributed: boolean }): any
	local bossId = monster.boss :: string
	local boss = Bosses.BOSSES[bossId]
	local byBoss = records[player]
	if not boss or not byBoss or not byBoss[bossId] then
		return nil
	end
	local now = os.time()
	local today = BossRules.dayNumber(now)
	local record = byBoss[bossId]
	local carried = not fight.contributed
	-- every boss win counts for the plaza's boss kills list (owner 2026-11-21: "Every win"; LeaderboardService)
	DataService.AddStat(player, "bossKills", 1)
	-- fullPay: a loot win (or the first clear), paid in full; otherwise BattleService pays `payShare` of the cash
	local result: { [string]: any } = { bossId = bossId, items = {}, firstClear = false, bonus = false, lootIn = 0, carried = carried, fullPay = false, payShare = Bosses.REPEAT_PAY }

	-- The first clear's chest always comes to those who helped (it's the way up the ladder, however strong the party)
	if not record.cleared and not carried then
		record.cleared = true
		result.firstClear = true
		result.fullPay = true
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
	if BossRules.lootEligible(record, now) then
		result.fullPay = true
		-- the weekly event on now (Config/Events): Boss Rush halves the wait and says so on the victory screen
		local event = EventNow.today()
		record.lootAt = now + EventRules.lootCooldown(event, Bosses.LOOT_COOLDOWN)
		local mine = watched[player]
		if mine then
			mine[bossId] = true -- told when it runs out (Bosses.LOOT_READY)
		end
		result.event = if event then event.note else nil
		-- Its chests (BossChestService) after every loot win of those who helped (the owner 2026-11-11: "chests every
		-- win"); they hold the weapon or its material, so the material's own roll is skipped here
		local weaponId = weaponOf[bossId]
		local material = Weapons.MATERIALS[bossId]
		local chests = weaponId ~= nil and material ~= nil and not carried
		local drops: { Grant } = {}
		for _, drop in boss.drops do
			if chests and drop.item == material then
				continue
			end
			-- a key's fragments catch up once the player is at the level of the boss it opens (Bosses.KEY_CATCH_UP)
			local opens = opensBoss[drop.item]
			local opensLevel = if opens then Bosses.BOSSES[opens].shopLevel else nil
			local chance, min, max = BossRules.keyDrop(Bosses, drop, opensLevel, EconomyService.GetLevel(player))
			if carried then
				chance = BossRules.carriedDrop(Bosses, drop.item, chance, opens ~= nil)
			end
			if wanted(byBoss, drop.item) and rng:NextNumber() < chance then
				table.insert(drops, { item = drop.item, count = rng:NextInteger(min, max) })
			end
		end
		grant(player, drops, result.items)
		-- Its weapon: those who helped only (carried members never roll it, like key fragments)
		if BossRules.rollsWeapon(carried) then
			result.weapon = rollWeapon(player, bossId, record)
		end
		-- Its Frontier card: those who helped only; the chests come after its reveal
		local cardWait = 0
		if not carried then
			result.card = rollCard(player, boss)
			if result.card then
				cardWait = CardEffects.FRONTIER.REVEAL_SECONDS
			end
		end
		if chests and weaponId then
			BossChestService.Prepare(player, bossId, weaponId, result.weapon, function(payload, here)
				BossService.AnnounceWeapon(player, payload, here)
			end, cardWait)
		elseif result.weapon then
			-- No chests to show it in (a config gap): its moment after the victory screen, as before the chests
			task.delay(Victory.SECONDS, BossService.AnnounceWeapon, player, result.weapon)
		end
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

-- Who still holds a remote arena copy: its fighters still in the game and on its clearing. One who left it any other
-- way (respawned at their shop, the Shop button, a fall) no longer does, and the loot they left lying goes into their
-- Bag (they can't get back to it)
local function copyFighters(bossId: string, index: number): { Player }
	local copy = arenas[bossId].copies[index]
	local held = {}
	for _, player in (fighters[bossId] or {})[index] or {} do
		local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		local distance = if root then (root.Position - copy.center).Magnitude else math.huge
		if BossRules.stillInCopy(player.Parent ~= nil, distance, ValleyConfig.ARENA_HOLD) then
			table.insert(held, player)
		elseif player.Parent then
			collectAll(player)
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

-- Everyone inside the ring (`radius`, the boss's: BossRules.arenaRadius) who isn't one of `members` (someone waiting at
-- the gate) goes out before it seals
local function clearRing(copy: WildService.ArenaCopy, members: { Player }, radius: number)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		local offset = if root then root.Position - copy.center else nil
		if offset and not table.find(members, player) and BossRules.insideRing(offset.X, offset.Z, radius) then
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
			local spot = copy.inside * CFrame.new(sideways, 0, 0)
			if (character:GetPivot().Position - spot.Position).Magnitude > Bosses.FAR_MOVE then
				-- far off (the Dungeon's lair is 2000 studs from its ledge): its floor streamed in first, or they'd fall
				task.spawn(function()
					WildService.Prestream(player, spot.Position)
					if player.Character == character then
						character:PivotTo(spot)
					end
				end)
			else
				character:PivotTo(spot)
			end
		end
	end
	clearRing(copy, players, BossRules.arenaRadius(boss, Bosses))
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

-- Out of a remote arena copy and back to the boss's portal, whatever loot is still lying going into the Bag first.
-- Never yields (it runs inside a fight's leave): the move, which streams the portal in first, has its own thread, and
-- nobody dead or gone is moved (a dead player respawns at their shop)
local function sendBack(player: Player, bossId: string, index: number)
	local held = (fighters[bossId] or {})[index]
	local at = if held then table.find(held, player) else nil
	if at then
		table.remove(held :: { Player }, at)
	end
	if not player.Parent then
		return
	end
	collectAll(player)
	local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.Health > 0 then
		task.spawn(WildService.MoveInWild, player, arenas[bossId].copies[index].exit)
	end
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
	-- teammates still on their way to the gate (spec 2026-11-15-teams-design) get a few seconds to arrive
	local deadline = os.clock() + Teams.TRAVEL_WAIT
	while os.clock() < deadline do
		local onTheWay = false
		for _, member in lobby.members do
			onTheWay = onTheWay or traveling[member] == true
		end
		if not onTheWay then
			break
		end
		task.wait(0.2)
	end
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

-- The leader's teammates anywhere in this world hear of a forming group (spec 2026-11-15-teams-design): who's in and
-- the seconds left, on a "Join the fight?" card (TeamController); those in it or in a fight already aren't asked
local function callTeam(bossId: string)
	local lobby = lobbies[bossId]
	if not lobby then
		return
	end
	local leader = lobby.members[1]
	local joined = {}
	for _, member in lobby.members do
		table.insert(joined, member.UserId)
	end
	local left = math.max(0, lobby.closesAt - os.clock())
	for _, mate in TeamService.MatesOf(leader) do
		if not table.find(lobby.members, mate) and not BattleService.IsFighting(mate) then
			Remotes.TeamFight:FireClient(mate, bossId, leader.UserId, joined, left)
		end
	end
end

-- A group opens at the gate with `player` leading: it starts by itself after JOIN_SECONDS (or when full)
local function openLobby(player: Player, bossId: string)
	local opened = { members = { player }, closesAt = os.clock() + Bosses.JOIN_SECONDS }
	lobbies[bossId] = opened
	updateGroupPrompt(bossId)
	task.delay(Bosses.JOIN_SECONDS, function()
		if lobbies[bossId] == opened then
			closeLobby(bossId)
		end
	end)
	callTeam(bossId)
end

-- A teammate answers a "Join the fight?" card from anywhere in this world: into the group, then to its gate (the
-- loading screen covers the trip); the group waits a few seconds for them as it starts
local function onTeamJoin(player: Player, bossId: unknown)
	if typeof(bossId) ~= "string" or not allowTeamJoin(player) or runGate then
		return
	end
	local boss = Bosses.BOSSES[bossId]
	local lobby = lobbies[bossId]
	if not boss or not arenas[bossId] then
		return
	end
	if not lobby then
		Blocked.tell(player, "That fight has already started.", { title = "Team" })
		return
	end
	local leader = lobby.members[1]
	if not TeamService.AreMates(player, leader) or table.find(lobby.members, player) then
		return
	end
	if #lobby.members >= Bosses.GROUP_MAX then
		Blocked.tell(player, "That group is full.", { title = "Team" })
		return
	end
	local reason = whyNotMember(player, bossId, math.huge)
	if reason then
		Blocked.tell(player, reason, { title = boss.name })
		return
	end
	table.insert(lobby.members, player)
	updateGroupPrompt(bossId)
	for _, member in lobby.members do
		notify(member, `{player.DisplayName} joined the {boss.name} group ({#lobby.members}/{Bosses.GROUP_MAX}).`, false)
	end
	callTeam(bossId) -- the others' cards show who's in now
	traveling[player] = true
	WildService.TravelToWild(player, arenas[bossId].gate)
	traveling[player] = nil
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
	openLobby(player, bossId)
	notify(player, `Group open: others have {Bosses.JOIN_SECONDS} s to join at the gate (F). Press F again to start now.`, false)
end

-- The Fight prompt: the boss for this player alone; with teammates in this world, a group they're called to (spec
-- 2026-11-15-teams-design), which the leader can start at once with Fight again (the Dungeon: its run decides)
local function onGate(player: Player, bossId: string)
	if runGate then
		runGate(player, bossId)
		return
	end
	if not allowStart(player) or not Bosses.BOSSES[bossId] or not arenas[bossId] or entering[player] then
		return
	end
	local lobby = lobbies[bossId]
	if lobby and lobby.members[1] == player then
		closeLobby(bossId)
		return
	elseif lobby and table.find(lobby.members, player) then
		notify(player, "You're in the group forming here: it starts soon (the leader can start it now with F).", true)
		return
	end
	local reason = whyArenaBusy(player, bossId) or whyNotMember(player, bossId, Bosses.GATE_DISTANCE)
	if reason then
		notify(player, reason, true)
		return
	end
	if not lobby and #TeamService.MatesOf(player) > 0 then
		openLobby(player, bossId)
		notify(player, `Your team has {Bosses.JOIN_SECONDS} s to join. Press Fight again to start now.`, false)
		return
	end
	local started, why = enterCopy(bossId, { player }, Bosses.GATE_DISTANCE)
	if not started and why then
		notify(player, why, true)
	end
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

-- Arriving in the Frontier from a beaten boss's teleport (FrontierService.ToBoss: its data names the boss): once the
-- character stands, off to that boss's gate. Checked against the save (BossRules.teleportTarget): the data passes
-- through the client
local ARRIVE_WAIT = 20 -- seconds for the character to appear
local ARRIVE_SETTLE = 1.5 -- seconds after it appears, before the trip (the place's own arrival runs first)
local function arriveAtBoss(player: Player)
	local ok, data = pcall(function()
		return player:GetJoinData().TeleportData
	end)
	local bossId = BossRules.teleportTarget(if ok then data else nil, "Frontier", Bosses, function(id: string): boolean
		local mine = records[player]
		local record = if mine then mine[id] else nil
		return record ~= nil and record.cleared
	end)
	local index = if bossId then table.find(Bosses.LADDER, bossId) else nil
	if not index then
		return
	end
	task.spawn(function()
		local deadline = os.clock() + ARRIVE_WAIT
		while player.Parent and not (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) and os.clock() < deadline do
			task.wait(0.25)
		end
		task.wait(ARRIVE_SETTLE)
		local gate = BossService.GetGate(index :: number)
		if player.Parent and player.Character and gate then
			WildService.TravelToWild(player, gate)
		end
	end)
end

local function load(player: Player, data: DataService.PlayerData)
	local saved = if typeof(data.bosses) == "table" then data.bosses else {}
	local byBoss: { [string]: BossRules.Record } = {}
	for _, bossId in Bosses.LADDER do
		byBoss[bossId] = BossRules.read(saved[bossId], Bosses.BOSSES[bossId].unlock == nil)
	end
	records[player] = byBoss
	local running = {}
	for bossId, record in byBoss do
		if record.lootAt > os.time() then
			running[bossId] = true -- still running from before: told when it runs out here
		end
	end
	watched[player] = running
	secretFound[player] = typeof(data.dungeon) == "table" and data.dungeon.secretFound == true
	seenIntro[player] = typeof(data.dungeon) == "table" and data.dungeon.seenIntro == true
	setTitle(player)
	task.defer(sendBosses, player) -- after the other services load (fragment counts)
	if Place.isFrontier() then
		arriveAtBoss(player) -- a beaten boss's teleport lands at its gate
	end
end

local function save(player: Player, data: DataService.PlayerData)
	local byBoss = records[player]
	if not byBoss then
		return -- never loaded: keep what's saved
	end
	data.bosses = BossRules.write(data.bosses, byBoss)
	data.dungeon = { secretFound = secretFound[player] == true, seenIntro = seenIntro[player] == true }
end

local function unload(player: Player)
	records[player] = nil
	watched[player] = nil
	secretFound[player] = nil
	seenIntro[player] = nil
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
	local bossId = Bosses.LADDER[raw]
	local boss = Bosses.BOSSES[bossId]
	local here = if Place.isDungeon() then "Dungeon" elseif Place.isFrontier() then "Frontier" else "Main"
	local record = if records[player] then records[player][bossId] else nil
	local choice = BossRules.travelChoice(boss.place, here, record ~= nil and record.cleared)
	-- a beaten Frontier or Dungeon boss from another place: a teleport straight there (owner 2026-11-21). Refused
	-- mid-fight; the Hydra's run needs a creature that can fight (it would put you out at once)
	if choice == "teleport" then
		if BattleService.IsFighting(player) then
			notify(player, "Finish your fight first.", true)
			return
		elseif not BossRules.levelReady(boss.shopLevel, EconomyService.GetLevel(player)) then
			notify(player, `The {boss.name} needs shop level {boss.shopLevel}.`, true)
			return
		end
		local why = if boss.place == "Dungeon" then BattleService.WhyNotFight(player) else nil
		if why then
			notify(player, why, true)
			return
		end
		-- (required here: FrontierService starts after this service in every place)
		local FrontierService = require(Services:WaitForChild("FrontierService")) :: any
		FrontierService.ToBoss(player, bossId)
		return
	end
	-- never beaten: walk to its portal first (testers 2026-11-26: "Players should only be able to teleport to bosses
	-- they have already beaten once"); the board shows the way and no button, so this is an old or edited client
	if choice == "walk" then
		Blocked.tell(player, `Beat the {boss.name} once to teleport to it. Walk to its portal for your first fight.`, { title = "Not beaten yet", icon = "Lock" })
		return
	end
	local gate = BossService.GetGate(raw)
	if choice ~= "gate" or not gate then
		notify(player, `The {boss.name} isn't in this place.`, true)
		return
	end
	WildService.TravelToWild(player, gate)
end


-- A lost boss fight: after LOSS_COUNTDOWN ("Teleporting back to town in 3, 2, 1") everyone who was still in it goes
-- home (BossRules.lossHome); they no longer hold a remote copy, so its loot linger doesn't move them back. Members who
-- left earlier already went back to the gate and are left alone. The Dungeon's run handles its own losers. The defeat
-- screen can't be skipped (owner 2026-11-04): everyone sees the whole countdown.
local function sendHome(player: Player)
	local humanoid = if player.Parent and player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.Health > 0 then
		WildService.SendToSpring(player)
	end
end

local function sendLosersHome(monster: WildService.Monster, losers: { Player })
	local home = BossRules.lossHome(if Place.isDungeon() then "Dungeon" elseif Place.isFrontier() then "Frontier" else "Main")
	if home == "dungeon" then
		return
	end
	local _, index = copyOf(monster)
	local held = if index then (fighters[monster.boss :: string] or {})[index] else nil
	for _, player in losers do
		local at = if held then table.find(held, player) else nil
		if at then
			table.remove(held :: { Player }, at)
		end
		task.delay(Combat.LOSS_COUNTDOWN, sendHome, player)
	end
end

-- The Robux reset (Bosses.RESET; owner 2026-11-19, pick A): the purchase opens only when its product is made, Roblox
-- allows paid random items here (it buys another roll at random loot: Util/PaidRandomRules) and some boss timer has
-- RESET.minLeft to go; otherwise the player hears why (Util/Blocked)
local function onResetBuy(player: Player)
	if not allowReset(player) then
		return
	end
	local productId = PurchaseService.ProductId(Bosses.RESET.product)
	local byBoss = records[player]
	if productId == 0 or not byBoss then
		return -- not created yet (its button says "Coming soon"), or the save isn't loaded
	end
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if PaidRandomRules.restricted(ok, info) then
		Blocked.tell(player, Bosses.RESET.restricted, { title = "Boss reset" })
		return
	end
	local now = os.time()
	local lootIns = {}
	for _, record in byBoss do
		table.insert(lootIns, record.lootAt - now)
	end
	if not BossRules.resetOffered(lootIns, Bosses.RESET.minLeft) then
		Blocked.tell(player, Bosses.RESET.nothing, { title = "Boss reset" })
		return
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end

-- A bought reset: every running boss loot timer ends now, and the player is told all of them did (Studio's /bossreset
-- too, DevService); false while their save isn't loaded here, so Roblox asks again
function BossService.ResetTimers(player: Player): boolean
	local byBoss = records[player]
	if not byBoss then
		return false
	end
	BossRules.resetTimers(byBoss, os.time())
	watched[player] = {} -- the reset says it itself (Bosses.RESET.done): no "ready again" for each
	sendBosses(player)
	Remotes.Notify:FireClient(player, Bosses.RESET.done)
	return true
end

-- Every watched loot timer that ran out: one toast for all of them (BossRules.readyWords) and the client's count on the
-- Bosses tile with a Phone ping (Remotes.BossLootReady); owner 2026-11-27
local function tellLootReady()
	local now = os.time()
	for player, mine in watched do
		local byBoss = records[player]
		local due = if byBoss then BossRules.dueLoot(Bosses.LADDER, byBoss, mine, now) else {}
		if #due > 0 then
			local names = {}
			for _, bossId in due do
				mine[bossId] = nil
				table.insert(names, Bosses.BOSSES[bossId].name)
			end
			Remotes.Notify:FireClient(player, BossRules.readyWords(Bosses.LOOT_READY, names))
			Remotes.BossLootReady:FireClient(player, due)
		end
	end
end

-- Studio's /bosstimer <n> <seconds> (and the admin panel): boss n's loot timer runs out in `seconds`, watched, to see
-- its notice
function BossService.DevSetLootIn(player: Player, index: number, seconds: number): boolean
	if not DevAccess.can(player) then
		return false
	end
	local bossId = Bosses.LADDER[index]
	local byBoss, mine = records[player], watched[player]
	local record = if bossId and byBoss then byBoss[bossId] else nil
	if not record or not mine then
		return false
	end
	record.lootAt = os.time() + math.max(0, math.floor(seconds))
	mine[bossId] = true
	sendBosses(player)
	return true
end

function BossService.Start()
	DataService.Register({ name = "BossService", load = load, save = save, unload = unload })
	task.spawn(function()
		while true do
			task.wait(Bosses.LOOT_READY.checkEvery)
			tellLootReady()
		end
	end)
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
	BattleService.OnFightEnded(function(monster, result, _, stillIn)
		if result == "lose" and monster.boss then
			sendLosersHome(monster, stillIn)
		end
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
				BossRules.forEachOf(copyFighters(bossId, index), function(player: Player)
					sendBack(player, bossId, index)
				end)
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
	Remotes.BossResetBuy.OnServerEvent:Connect(onResetBuy)
	PurchaseService.OnProduct(Bosses.RESET.product, BossService.ResetTimers)
	Remotes.TeamFight.OnServerEvent:Connect(onTeamJoin) -- a teammate's boss group (spec 2026-11-15-teams-design)
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
