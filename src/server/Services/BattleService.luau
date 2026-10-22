--!strict
-- Wild fights (battles part 1). A player's summoned creature (rested) fights one wild monster; one more party
-- card may be called in during the first seconds. BattleSim (pure, seeded) decides every hit; this service
-- steps it at Combat.TICK_RATE, moves the markers (lunges, the fight ring), sends events to the player's client
-- and pays out: card XP split across the 3 party cards, cash, and sometimes a card. Fainted cards rest
-- (saved as resting = { [beastId] = Unix time }), faster near the plaza spring.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Announcements = require(Config:WaitForChild("Announcements"))
local Combat = require(Config:WaitForChild("Combat"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
-- The server wild map in the main game, the Frontier in the Frontier place (same shape, plus Frontier drops)
local Wild = Place.getWorld()
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CombatMath = require(Shared:WaitForChild("Util"):WaitForChild("CombatMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local BattleSim = require(Util:WaitForChild("BattleSim"))
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local WildService = require(Services:WaitForChild("WildService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData
type Monster = WildService.Monster
type Beast = CardService.Beast

type Fight = {
	player: Player,
	monster: Monster,
	sim: BattleSim.State,
	leaderId: string,
	extraId: string?,
	extraMarker: BasePart?,
	partyIds: { string }, -- all party cards: they share the XP
	spots: { [string]: CFrame }, -- where each fighter stands in the ring, by sim id ("a:<beastId>", "b:m")
	center: Vector3, -- the ring; the player may roam within Combat.LEASH_RADIUS of it
	leashWarnedAt: number,
	sinceSnapshot: number,
	died: RBXScriptConnection?,
	ended: boolean,
}

local BattleService = {}

local SNAPSHOT_SECONDS = 1 -- resend timers this often even when nothing happened
local LUNGE_SECONDS = 0.15

local fights: { [Player]: Fight } = {}
local resting: { [Player]: { [string]: number } } = {} -- beastId -> Unix time it can fight again
local nearSpring: { [Player]: boolean } = {}
-- One limiter per remote, so tapping two fighters' abilities quickly doesn't drop the second
local allowAbility = RateLimiter.new(Combat.ACTION_COOLDOWN / 2)
local allowCallIn = RateLimiter.new(Combat.ACTION_COOLDOWN)
local allowRun = RateLimiter.new(Combat.ACTION_COOLDOWN)
local allowStart = RateLimiter.new(1)
local rng = Random.new()
local startBlockers: { (player: Player) -> string? } = {} -- ArenaService: no wild fights mid-PvP

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- Resting -------------------------------------------------------------------------------------------------

local function isResting(player: Player, beastId: string): boolean
	local entries = resting[player]
	return entries ~= nil and entries[beastId] ~= nil and entries[beastId] > os.time()
end

function BattleService.IsResting(player: Player, beastId: string): boolean
	return isResting(player, beastId)
end

-- ArenaService refuses wild fights while a player has a challenge, a queued match or a PvP fight
function BattleService.AddStartBlocker(blocker: (player: Player) -> string?)
	table.insert(startBlockers, blocker)
end

function BattleService.IsFighting(player: Player): boolean
	return fights[player] ~= nil
end

-- Seconds left per resting card (the client counts down from these)
local function sendResting(player: Player)
	local entries = resting[player]
	if not entries then
		return
	end
	local now = os.time()
	local list = {}
	for beastId, untilTime in entries do
		if untilTime > now then
			table.insert(list, { beastId = beastId, seconds = untilTime - now })
		else
			entries[beastId] = nil
		end
	end
	Remotes.RestChanged:FireClient(player, { entries = list, nearSpring = nearSpring[player] == true })
end

function BattleService.ClearResting(player: Player)
	if resting[player] then
		resting[player] = {}
		sendResting(player)
	end
end

-- Fighters ------------------------------------------------------------------------------------------------

local function fighterInput(beast: Beast): BattleSim.FighterInput
	local card = Cards.ById[beast.cardId]
	local stats = BeastRules.getStats(card, beast.foil, beast.level, beast.stars, beast.grade)
	return {
		id = beast.id,
		element = card.element,
		hp = stats.hp,
		atk = stats.atk,
		spd = stats.spd,
		signature = if Combat.SIGNATURES[card.name] then card.name else nil,
	}
end

-- A card as a fighter: its stats now, and its signature ability if it has one (ArenaService uses it too)
function BattleService.FighterInput(beast: Beast): BattleSim.FighterInput
	return fighterInput(beast)
end

local function getPartyIds(player: Player): { string }
	local party = PartyService.GetParty(player)
	local ids = {}
	if party then
		for slot = 1, 3 do
			local beastId = party.slots[slot]
			if beastId and CardService.GetBeast(player, beastId) then
				table.insert(ids, beastId)
			end
		end
	end
	return ids
end

-- Sim ids: the party is side A ("a:<beastId>"), the monster side B ("b:m")
local MONSTER_ID = "b:m"

local function partyId(beastId: string): string
	return `a:{beastId}`
end

-- The sim's result as the player sees it
local function outcomeOf(result: string?): string
	return if result == "a" then "win" elseif result == "b" then "lose" else "run"
end

local function markerFor(fight: Fight, id: string): BasePart?
	if id == MONSTER_ID then
		return fight.monster.marker
	elseif id == partyId(fight.leaderId) then
		return PartyService.GetMarker(fight.player)
	elseif fight.extraId and id == partyId(fight.extraId) then
		return fight.extraMarker
	end
	return nil
end

local function place(fight: Fight, id: string, cframe: CFrame)
	if id == MONSTER_ID then
		WildService.SetFightPose(fight.monster, cframe)
	elseif id == partyId(fight.leaderId) then
		PartyService.SetHold(fight.player, cframe)
	elseif fight.extraId and id == partyId(fight.extraId) and fight.extraMarker then
		fight.extraMarker.CFrame = cframe
	end
end

-- A quick step toward the target and back, so attacks read in the world
local function lunge(fight: Fight, from: string, to: string)
	local home, targetSpot = fight.spots[from], fight.spots[to]
	if not home or not targetSpot then
		return
	end
	local direction = targetSpot.Position - home.Position
	if direction.Magnitude < 0.1 then
		return
	end
	place(fight, from, home + direction.Unit * Combat.LUNGE_STUDS)
	task.delay(LUNGE_SECONDS, function()
		if not fight.ended then
			place(fight, from, home)
		end
	end)
end

local function snapshot(fight: Fight): any
	return BattleSim.snapshot(fight.sim)
end

local function handleEvents(fight: Fight, events: { BattleSim.Event })
	for _, event in events do
		if event.type == "attack" and event.from and event.to then
			lunge(fight, event.from, event.to)
		elseif event.type == "faint" and event.to then
			local marker = markerFor(fight, event.to)
			if marker then
				marker:SetAttribute("Fainted", true)
			end
		end
	end
	if #events > 0 then
		fight.sinceSnapshot = 0
		Remotes.BattleEvent:FireClient(fight.player, { events = events, snapshot = snapshot(fight) })
	end
end

-- Rewards -------------------------------------------------------------------------------------------------

local function rollWeighted(weights: { [string]: number }): string?
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = rng:NextNumber() * total
	for key, weight in weights do
		roll -= weight
		if roll < 0 then
			return key
		end
	end
	return nil
end

-- A random card of the zone's elements: rarity by Wild.DROP_RARITY, any rarity if none of that rarity exists
local function rollDrop(monster: Monster): string?
	local zone: any = Wild.ZONES[monster.zone]
	local elements: { [string]: boolean } = {}
	if zone and zone.elements then
		for _, element in zone.elements do -- e.g. The Rift: all five
			elements[element] = true
		end
	else
		for _, species in (if zone then zone.species else { monster.species }) do
			local info = Wild.SPECIES[species]
			if info then
				elements[info.element] = true
			end
		end
	end
	local rarity = rollWeighted(Wild.DROP_RARITY)
	local ofRarity, ofElement = {}, {}
	for _, card in Cards.BySet["First Spark"] do -- Frontier cards only drop in the Frontier
		if elements[card.element] then
			table.insert(ofElement, card.id)
			if card.rarity == rarity then
				table.insert(ofRarity, card.id)
			end
		end
	end
	local pool = if #ofRarity > 0 then ofRarity else ofElement
	return if #pool > 0 then pool[rng:NextInteger(1, #pool)] else nil
end

local function payOut(fight: Fight): any
	local player, monster = fight.player, fight.monster
	local rewards = CombatMath.getRewards(Wild, monster.level, monster.elite)
	local each = CombatMath.splitXp(rewards.xp, #fight.partyIds)
	for _, beastId in fight.partyIds do
		CardService.AddXP(player, beastId, each)
	end
	EconomyService.AddCash(player, rewards.cash)
	local dropped = nil
	if rng:NextNumber() < rewards.dropChance then
		local cardId = rollDrop(monster)
		if cardId then
			dropped = { cardId = cardId, foil = false, grade = BeastRules.rollGrade(rng:NextNumber()) }
			CardService.AddFresh(player, { dropped })
		end
	end
	-- Frontier only: Star Shards and Frontier cards
	local world: any = Wild
	local shards = 0
	if world.SHARD_CHANCE and rng:NextNumber() < (if monster.elite then world.ELITE_SHARD_CHANCE else world.SHARD_CHANCE) then
		shards = ItemService.GiveItem(player, "starShard", 1)
	end
	local frontierCard = nil
	if world.CARD_CHANCE and rng:NextNumber() < (if monster.elite then world.ELITE_CARD_CHANCE else world.CARD_CHANCE) then
		local rarity = rollWeighted(world.CARD_RARITY)
		local pool = {}
		for _, card in Cards.BySet.Frontier do
			if card.rarity == rarity then
				table.insert(pool, card.id)
			end
		end
		if #pool > 0 then
			frontierCard = { cardId = pool[rng:NextInteger(1, #pool)], foil = false, grade = BeastRules.rollGrade(rng:NextNumber()) }
			CardService.AddFresh(player, { frontierCard })
			-- Epic and Legendary ones: the whole server hears, and the finder gets the big reveal
			if Announcements.FRONTIER_RARITIES[Cards.ById[frontierCard.cardId].rarity] then
				Remotes.PullAnnouncement:FireAllClients(player.DisplayName, frontierCard.cardId, false, "frontier", player.UserId)
			end
		end
	end
	return { xpEach = each, cash = rewards.cash, card = frontierCard or dropped, shards = shards }
end

-- Ending --------------------------------------------------------------------------------------------------

local function endFight(fight: Fight, result: string)
	if fight.ended then
		return
	end
	fight.ended = true
	local player = fight.player
	if fights[player] == fight then
		fights[player] = nil
	end
	if fight.died then
		fight.died:Disconnect()
	end

	if result == "win" then
		WildService.Defeat(fight.monster)
	else
		WildService.Unlock(fight.monster)
	end
	PartyService.SetHold(player, nil)
	PartyService.SetLocked(player, false)
	local leaderMarker = PartyService.GetMarker(player)
	if leaderMarker then
		leaderMarker:SetAttribute("Fainted", nil)
	end
	CardService.SetFighting(player, fight.leaderId, false)
	if fight.extraId then
		CardService.SetFighting(player, fight.extraId, false)
	end
	if fight.extraMarker then
		fight.extraMarker:Destroy()
	end

	-- Fainted fighters rest, whatever the result (a run or a win doesn't wake them)
	local rested = {}
	local entries = resting[player]
	if entries then
		for _, beastId in BattleSim.getFainted(fight.sim, "a") do
			entries[beastId] = os.time() + Combat.REST_SECONDS
			table.insert(rested, beastId)
		end
	end

	local summary: any = { result = result, rested = rested }
	if result == "win" and player.Parent then
		local paid = payOut(fight)
		summary.xpEach, summary.cash, summary.card, summary.shards = paid.xpEach, paid.cash, paid.card, paid.shards
		summary.partyIds = fight.partyIds
	end
	if player.Parent then
		Remotes.BattleEnded:FireClient(player, summary)
		sendResting(player)
	end
end

-- Starting ------------------------------------------------------------------------------------------------

-- Why this player can't start a fight now, or nil
local function whyNot(player: Player, monster: Monster?): string?
	if fights[player] or PartyService.IsLocked(player) then
		return "You're already in a fight."
	end
	for _, blocker in startBlockers do
		local reason = blocker(player)
		if reason then
			return reason
		end
	end
	if not monster or monster.fightingPlayer then
		return "Someone is already fighting that monster."
	end
	local party = PartyService.GetParty(player)
	local leaderId = if party and party.summoned then party.slots[party.summoned] else nil
	if not leaderId or not CardService.GetBeast(player, leaderId) then
		return "Summon a party creature to fight."
	elseif isResting(player, leaderId) then
		return `Your creature is resting. Summon a rested one or visit {if Place.isFrontier() then "the spring at the entrance" else "the plaza spring"}.`
	elseif not getRoot(player) or not PartyService.GetMarker(player) then
		return "You can't fight right now."
	end
	return nil
end

local function startFight(player: Player, monster: Monster)
	local party = PartyService.GetParty(player) :: { slots: { [number]: string }, summoned: number? }
	local leaderId = party.slots[party.summoned :: number]
	local leader = CardService.GetBeast(player, leaderId) :: Beast
	local root = getRoot(player) :: BasePart
	local partyIds = getPartyIds(player)
	local reserves = {}
	for _, beastId in partyIds do
		local beast = CardService.GetBeast(player, beastId)
		if beast and beastId ~= leaderId and not isResting(player, beastId) then
			table.insert(reserves, fighterInput(beast))
		end
	end
	local stats = CombatMath.getMonsterStats(Wild, monster.species, monster.level, monster.elite)
	if not stats then
		return
	end
	local sim = BattleSim.new(Combat, { fighters = { fighterInput(leader) }, reserves = reserves, abilities = true, canRun = true }, {
		fighters = { { id = "m", element = monster.element, hp = stats.hp, atk = stats.atk, spd = stats.spd, elite = monster.elite } },
		abilities = false,
		canRun = false,
	}, rng:NextInteger(1, 2 ^ 30))

	-- The ring: the monster where it stands, facing the player; the leader between them
	local center = monster.marker.Position
	local toPlayer = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
	local direction = if toPlayer.Magnitude > 0.1 then toPlayer.Unit else Vector3.new(0, 0, -1)
	local right = Vector3.new(-direction.Z, 0, direction.X)
	local leaderSpot = center + direction * Combat.RING_RADIUS
	local extraSpot = leaderSpot + right * 3
	local fight: Fight = {
		player = player,
		monster = monster,
		sim = sim,
		leaderId = leaderId,
		extraId = nil,
		extraMarker = nil,
		partyIds = partyIds,
		spots = {
			[MONSTER_ID] = CFrame.lookAt(center, center + direction),
			[partyId(leaderId)] = CFrame.lookAt(leaderSpot, leaderSpot - direction),
			extra = CFrame.lookAt(extraSpot, extraSpot - direction),
		},
		center = center,
		leashWarnedAt = 0,
		sinceSnapshot = 0,
		died = nil,
		ended = false,
	}
	fights[player] = fight
	WildService.Lock(monster, player)
	PartyService.SetLocked(player, true)
	PartyService.SetHold(player, fight.spots[partyId(leaderId)])
	WildService.SetFightPose(monster, fight.spots[MONSTER_ID])
	CardService.SetFighting(player, leaderId, true)
	local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid")
	if humanoid then
		fight.died = humanoid.Died:Connect(function()
			endFight(fight, "run")
		end)
	end

	local names: { [string]: string } = {}
	for _, beastId in partyIds do
		local beast = CardService.GetBeast(player, beastId)
		if beast then
			names[partyId(beastId)] = Cards.ById[beast.cardId].name
		end
	end
	Remotes.BattleStarted:FireClient(player, {
		monsterId = monster.id,
		species = monster.species,
		level = monster.level,
		elite = monster.elite,
		element = monster.element,
		names = names,
		side = "a",
		markers = { [partyId(leaderId)] = PartyService.GetMarker(player), [MONSTER_ID] = monster.marker },
		snapshot = snapshot(fight),
	})
end

local function tryStart(player: Player, monster: Monster?): boolean
	local reason = whyNot(player, monster)
	if reason then
		return false
	end
	startFight(player, monster :: Monster)
	return true
end

-- Remotes -------------------------------------------------------------------------------------------------

local function onStartFight(player: Player, monsterId: unknown)
	if not allowStart(player) or typeof(monsterId) ~= "string" then
		return
	end
	local monster = WildService.GetMonster(monsterId)
	local reason = whyNot(player, monster)
	if not reason and monster then
		local root = getRoot(player) :: BasePart
		if (root.Position - monster.marker.Position).Magnitude > Combat.FIGHT_RANGE then
			reason = "Get closer to fight."
		end
	end
	if reason then
		notify(player, reason, true)
		return
	end
	startFight(player, monster :: Monster)
end

local function onCallIn(player: Player, id: unknown)
	local fight = fights[player]
	if not allowCallIn(player) or not fight or typeof(id) ~= "string" or string.sub(id, 1, 2) ~= "a:" then
		return
	end
	local ok = BattleSim.callIn(fight.sim, id)
	if not ok then
		return
	end
	local beastId = string.sub(id, 3)
	fight.extraId = beastId
	fight.spots[id] = fight.spots.extra
	fight.extraMarker = PartyService.CreateMarker(player, beastId, fight.spots.extra)
	CardService.SetFighting(player, beastId, true)
	-- The new creature's marker, so the client can float numbers over it
	Remotes.BattleEvent:FireClient(player, { events = {}, markers = { [id] = fight.extraMarker }, snapshot = snapshot(fight) })
	handleEvents(fight, { { type = "callin", from = id } })
end

local function onUseAbility(player: Player, fighterId: unknown, which: unknown)
	local fight = fights[player]
	-- Only your own side's fighters (side A)
	if not allowAbility(player) or not fight or typeof(fighterId) ~= "string" or string.sub(fighterId, 1, 2) ~= "a:" then
		return
	end
	if which ~= "element" and which ~= "signature" then
		return
	end
	local events = BattleSim.useAbility(fight.sim, fighterId, which :: string)
	if events then
		handleEvents(fight, events)
		if fight.sim.result then
			endFight(fight, outcomeOf(fight.sim.result))
		end
	end
end

local function onRun(player: Player)
	local fight = fights[player]
	if not allowRun(player) or not fight then
		return
	end
	handleEvents(fight, BattleSim.tryRun(fight.sim, "a"))
	if fight.sim.result then
		endFight(fight, outcomeOf(fight.sim.result))
	end
end

-- Loop ----------------------------------------------------------------------------------------------------

-- Ends fights that can't go on: the player's character or summoned creature is gone
local function stillValid(fight: Fight): boolean
	local player = fight.player
	return player.Parent ~= nil
		and getRoot(player) ~= nil
		and PartyService.GetMarker(player) ~= nil
		and CardService.GetBeast(player, fight.leaderId) ~= nil
		and fight.monster.alive
end

-- Players may run around during a fight, but not away from it: past the leash they're put back at its edge
local function keepNear(fight: Fight)
	local root = getRoot(fight.player)
	if not root then
		return
	end
	local offset = Vector3.new(root.Position.X - fight.center.X, 0, root.Position.Z - fight.center.Z)
	if offset.Magnitude <= Combat.LEASH_RADIUS then
		return
	end
	local edge = fight.center + offset.Unit * (Combat.LEASH_RADIUS - 2)
	local back = Vector3.new(edge.X, root.Position.Y, edge.Z)
	root.AssemblyLinearVelocity = Vector3.zero
	;(fight.player.Character :: Model):PivotTo(CFrame.lookAt(back, Vector3.new(fight.center.X, back.Y, fight.center.Z)))
	if os.clock() - fight.leashWarnedAt > 3 then
		fight.leashWarnedAt = os.clock()
		notify(fight.player, "Stay near the fight! (Run to leave it)", true)
	end
end

local function stepFights(dt: number)
	for _, fight in fights do
		if not stillValid(fight) then
			endFight(fight, "run")
		else
			keepNear(fight)
			handleEvents(fight, BattleSim.step(fight.sim, dt))
			if fight.sim.result then
				endFight(fight, outcomeOf(fight.sim.result))
			else
				fight.sinceSnapshot += dt
				if fight.sinceSnapshot >= SNAPSHOT_SECONDS then
					fight.sinceSnapshot = 0
					Remotes.BattleEvent:FireClient(fight.player, { events = {}, snapshot = snapshot(fight) })
				end
			end
		end
	end
end

-- Each second near the spring takes SPRING_SPEED - 1 extra seconds off every resting card
local function tickSpring()
	local spring = WildService.GetSpringPosition()
	for player, entries in resting do
		local root = getRoot(player)
		local near = root ~= nil and (root.Position - spring).Magnitude <= Combat.SPRING_RADIUS
		local changed = near ~= (nearSpring[player] == true)
		nearSpring[player] = near or nil
		if near and next(entries) then
			for beastId, untilTime in entries do
				entries[beastId] = untilTime - (Combat.SPRING_SPEED - 1)
			end
			changed = true
		end
		if changed then
			sendResting(player)
		end
	end
end

-- Data ----------------------------------------------------------------------------------------------------

local function load(player: Player, data: PlayerData)
	local now = os.time()
	local entries: { [string]: number } = {}
	local saved: any = if typeof(data.resting) == "table" then data.resting else {}
	for beastId, untilTime in saved do
		local valid = typeof(beastId) == "string" and typeof(untilTime) == "number" and untilTime == untilTime and untilTime > now
			and CardService.GetBeast(player, beastId) ~= nil
		if valid then
			entries[beastId] = math.min(math.floor(untilTime), now + Combat.REST_SECONDS) -- never longer than one rest
		end
	end
	resting[player] = entries
	task.defer(sendResting, player)
end

local function save(player: Player, data: PlayerData)
	local entries = resting[player]
	if not entries then
		return
	end
	local now = os.time()
	local saved: { [string]: number } = {}
	for beastId, untilTime in entries do
		if untilTime > now then
			saved[beastId] = untilTime
		end
	end
	data.resting = saved
end

local function unload(player: Player)
	local fight = fights[player]
	if fight then
		endFight(fight, "run")
	end
	resting[player] = nil
	nearSpring[player] = nil
end

function BattleService.Start()
	DataService.Register({ name = "BattleService", load = load, save = save, unload = unload })
	-- End a fight before the leave save, so cards that fainted in it are saved as resting
	DataService.OnBeforeLeave(function(player)
		local fight = fights[player]
		if fight then
			endFight(fight, "run")
		end
	end)
	Remotes.StartFight.OnServerEvent:Connect(onStartFight)
	Remotes.CallIn.OnServerEvent:Connect(onCallIn)
	Remotes.UseAbility.OnServerEvent:Connect(onUseAbility)
	Remotes.RunFight.OnServerEvent:Connect(onRun)

	WildService.AddTravelBlocker(function(player)
		return if fights[player] then "You can't travel during a fight." else nil
	end)
	-- A chasing monster caught you: fight, if you can (otherwise it just gives up)
	WildService.OnContact(function(player, monster)
		tryStart(player, monster)
	end)

	local elapsed, sinceSpring = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		sinceSpring += dt
		local tick = 1 / Combat.TICK_RATE
		if elapsed >= tick then
			local step = elapsed
			elapsed = 0
			stepFights(step)
		end
		if sinceSpring >= 1 then
			sinceSpring = 0
			tickSpring()
		end
	end)
end

return BattleService
