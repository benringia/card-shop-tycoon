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

-- The strongest party card's Power (bosses recommend a Power per card)
local function partyPower(player: Player, partyIds: { string }): number
	local best = 0
	for _, beastId in partyIds do
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
-- and the over-power penalty; the first clear and the day's first rewarded win add their chests.
local function onBossWin(player: Player, monster: WildService.Monster, fight: { seconds: number, partyIds: { string } }): any
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
	local result = { bossId = bossId, items = {}, firstClear = false, bonus = false, lootIn = 0, reduced = false, flagged = false }

	-- The first clear's chest always comes (it's the way up the ladder, however strong the party)
	if not record.cleared then
		record.cleared = true
		result.firstClear = true
		grant(player, boss.firstClear, result.items)
		Remotes.BossCleared:FireAllClients(player.DisplayName, bossId)
	end
	if fight.seconds < boss.minFightSeconds then
		warn(`[BossService] {player.Name} beat {bossId} in {fight.seconds}s (minimum {boss.minFightSeconds}): no drops`)
		result.flagged = true
	elseif BossRules.lootEligible(record, now) then
		local factor = BossRules.dropFactor(Bosses, record, partyPower(player, fight.partyIds), boss.recommended)
		result.reduced = factor < 1
		record.lootAt = now + Bosses.LOOT_COOLDOWN
		record.rewardedToday += 1
		local drops: { Grant } = {}
		for _, drop in boss.drops do
			if wanted(byBoss, drop.item) and rng:NextNumber() < drop.chance * factor then
				table.insert(drops, { item = drop.item, count = rng:NextInteger(drop.min, drop.max) })
			end
		end
		grant(player, drops, result.items)
		if record.bonusDay ~= today then
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

-- The gate's prompt: checks, the key (used once), then the boss for this player alone
local function onGate(player: Player, bossId: string)
	local boss = Bosses.BOSSES[bossId]
	local arena = arenas[bossId]
	local record = BossService.GetRecord(player, bossId)
	if not allowStart(player) or not boss or not arena or not record then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root then
		return
	end
	if (root.Position - arena.gatePosition).Magnitude > Bosses.GATE_DISTANCE then
		notify(player, "Get closer to the gate.", true)
		return
	end
	local unlock = boss.unlock
	local owned = if unlock then ItemService.GetCount(player, unlock.item) else 0
	if not BossRules.canStart(record, unlock, owned) and unlock then
		notify(player, `Needs {unlock.count} {describeItem(unlock.item)}s (you have {owned}). Beat the boss before it.`, true)
		return
	end
	local reason = BattleService.WhyNotFight(player)
	if reason then
		notify(player, reason, true)
		return
	end
	-- No yields from here: the key count and the fight start in one step
	local monster = WildService.SpawnAt(arena.spawn.Position, boss.name, boss.level, false, bossId)
	if not monster then
		return
	end
	monster.marker.CFrame = arena.spawn
	local started, why = BattleService.StartFight(player, monster)
	if not started then
		WildService.Defeat(monster)
		notify(player, why or "The boss couldn't start. Try again.", true)
		return
	end
	if not record.unlocked and unlock then
		ItemService.TakeItem(player, unlock.item, unlock.count)
		record.unlocked = true
		notify(player, `Used {unlock.count} {describeItem(unlock.item)}s: the {boss.name} is open for good.`, false)
		sendBosses(player)
	end
end

-- /boss <n> fight: the gate, as if its prompt was used (same checks)
function BossService.UseGate(player: Player, index: number)
	local bossId = Bosses.LADDER[index]
	if bossId then
		onGate(player, bossId)
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
	arenas = WildService.BuildBossArenas(onGate)
	BattleService.SetBossRewards(onBossWin)
	Remotes.RequestBosses.OnServerEvent:Connect(function(player)
		if allowRequest(player) then
			sendBosses(player)
		end
	end)
end

return BossService
