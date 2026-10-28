--!strict
-- Wild fights (battles part 1). A player's summoned creature (rested) fights one wild monster; one more party
-- card may be called in during the first seconds. BattleSim (pure, seeded) decides every hit; this service
-- steps it at Combat.TICK_RATE, moves the markers (lunges, the fight ring), sends events to the player's client
-- and pays out: card XP split across the 3 party cards, cash, and sometimes a card. Fainted cards rest
-- (saved as resting = { [beastId] = Unix time }), faster near the plaza spring. A fight has members: a Wild fight or a
-- solo boss is a group of one; boss groups (BossService) put 2-4 players on side A against one scaled boss, each
-- calling in and using abilities only on their own creatures, leaving on their own, and paid on their own.
-- The Dungeon (DungeonService, BossService.StartRun) starts run fights: RunOptions bring a room's pack of monsters and
-- the HP each creature has left from earlier rooms; every fight reports each member's HP when it ends.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Announcements = require(Config:WaitForChild("Announcements"))
local Bosses = require(Config:WaitForChild("Bosses"))
local Combat = require(Config:WaitForChild("Combat"))
local Dungeon = require(Config:WaitForChild("Dungeon"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
-- The server wild map in the main game, the Frontier in the Frontier place (same shape, plus Frontier drops)
local Wild = Place.getWorld()
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local BossRules = require(Shared:WaitForChild("Util"):WaitForChild("BossRules"))
local CombatMath = require(Shared:WaitForChild("Util"):WaitForChild("CombatMath"))
local DungeonRules = require(Shared:WaitForChild("Util"):WaitForChild("DungeonRules"))
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

-- One player in a fight: their own creatures on side A
type Member = {
	player: Player,
	owner: string, -- BattleSim owner: the player's UserId
	leaderId: string, -- the summoned card: its marker is the one that follows the player
	markers: { [string]: BasePart }, -- their other creatures on the field (call-in, swaps), by beast id
	fought: { [string]: boolean }, -- every card of theirs that has been on the field
	partyIds: { string }, -- all their party cards: they share the XP
	died: RBXScriptConnection?,
	leashWarnedAt: number,
}

type Fight = {
	members: { [Player]: Member }, -- still in the fight
	size: number, -- members at the start (a boss is scaled to it)
	monster: Monster,
	sim: BattleSim.State,
	spots: { [string]: CFrame }, -- where each fighter stands in the ring, by sim id ("a:<beastId>", "b:m"; "extra:<owner>")
	center: Vector3, -- the ring; players may roam within the leash of it
	sinceSnapshot: number,
	ended: boolean,
	startsAt: number, -- os.clock(): boss fights hold still through the intro until then
	adds: { [string]: Monster }, -- a boss's adds and a room's pack, by sim id ("b:add1"..., "b:p1"...)
	run: boolean, -- a Dungeon run fight: rewards without items, Run leaves the run
	endHp: { [Player]: { [string]: number } }, -- each member's creatures' HP when they left the fight (its end or earlier)
}

-- The Dungeon: a room's pack (`monster` is its first, `pack` the others) and the HP left from earlier rooms
export type RunOptions = { pack: { Monster }?, hpLeft: { [Player]: { [string]: number } }?, run: boolean? }

local BattleService = {}

local SNAPSHOT_SECONDS = 1 -- resend timers this often even when nothing happened
local LUNGE_SECONDS = 0.15

local fights: { [Player]: Fight } = {} -- every member points at their fight
local running: { [Fight]: boolean } = {} -- each fight once, for the loop
local resting: { [Player]: { [string]: number } } = {} -- beastId -> Unix time it can fight again
local nearSpring: { [Player]: boolean } = {}
-- One limiter per remote, so tapping two fighters' abilities quickly doesn't drop the second
local allowAbility = RateLimiter.new(Combat.ACTION_COOLDOWN / 2)
local allowCallIn = RateLimiter.new(Combat.ACTION_COOLDOWN)
local allowRun = RateLimiter.new(Combat.ACTION_COOLDOWN)
local allowStart = RateLimiter.new(1)
local rng = Random.new()
local startBlockers: { (player: Player) -> string? } = {} -- ArenaService: no wild fights mid-PvP
-- BossService: a boss win's items (the loot rules live there); its result goes to the client as summary.boss
local fightEndedHandlers: { (monster: Monster, result: string, hpLeft: { [Player]: { [string]: number } }) -> () } = {}
local memberLeftHandlers: { (player: Player, monster: Monster) -> () } = {}
local bossRewards: ((player: Player, monster: Monster, fight: { seconds: number, fighterIds: { string }, contributed: boolean }) -> any)? = nil

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
-- BossService: a player left a fight that goes on without them (it moves them out of a sealed arena)
function BattleService.OnMemberLeft(handler: (player: Player, monster: Monster) -> ())
	table.insert(memberLeftHandlers, handler)
end

-- BossService: every fight's end, whatever the result (it unseals the arena)
-- After a fight ends (deferred): its monster, the result ("win", "lose", "run") and every member's creatures' HP then
function BattleService.OnFightEnded(handler: (monster: Monster, result: string, hpLeft: { [Player]: { [string]: number } }) -> ())
	table.insert(fightEndedHandlers, handler)
end

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

-- The member a side-A fighter belongs to
local function memberOf(fight: Fight, id: string): Member?
	for _, member in fight.members do
		if table.find(member.partyIds, string.sub(id, 3)) then
			return member
		end
	end
	return nil
end

local function markerFor(fight: Fight, id: string): BasePart?
	if id == MONSTER_ID then
		return fight.monster.marker
	end
	local add = fight.adds[id]
	if add then
		return add.marker
	end
	local member = memberOf(fight, id)
	if not member then
		return nil
	end
	return if id == partyId(member.leaderId) then PartyService.GetMarker(member.player) else member.markers[string.sub(id, 3)]
end

local function place(fight: Fight, id: string, cframe: CFrame)
	if id == MONSTER_ID then
		WildService.SetFightPose(fight.monster, cframe)
		return
	end
	local add = fight.adds[id]
	if add then
		WildService.SetFightPose(add, cframe)
		return
	end
	local member = memberOf(fight, id)
	if not member then
		return
	end
	local marker = member.markers[string.sub(id, 3)]
	if id == partyId(member.leaderId) then
		PartyService.SetHold(member.player, cframe)
	elseif marker then
		marker.CFrame = cframe
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

-- To every member still in the fight
local function broadcast(fight: Fight, payload: any)
	for player in fight.members do
		Remotes.BattleEvent:FireClient(player, payload)
	end
end

-- One of a member's creatures leaves the field (swapped out): the summoned one hides, the others' markers go
local function leaveField(member: Member, beastId: string)
	if beastId == member.leaderId then
		local marker = PartyService.GetMarker(member.player)
		if marker then
			marker:SetAttribute("Benched", true)
		end
		return
	end
	local marker = member.markers[beastId]
	if marker then
		marker:Destroy()
	end
	member.markers[beastId] = nil
end

-- A creature joins the field (a call-in or a swap) where the one it replaced stood, else at its owner's extra spot.
-- Fills in its marker and, for the other players, whose it is.
local function enterField(fight: Fight, event: BattleSim.Event, markers: { [string]: BasePart }, allies: { [string]: string })
	local id = event.from :: string
	local member = memberOf(fight, id)
	if not member then
		return
	end
	local player = member.player
	local beastId = string.sub(id, 3)
	local spot = (if event.to then fight.spots[event.to] else nil) or fight.spots[`extra:{member.owner}`]
	if event.to then
		leaveField(member, string.sub(event.to, 3))
	end
	fight.spots[id] = spot
	member.fought[beastId] = true
	CardService.SetFighting(player, beastId, true)
	local marker: BasePart?
	if beastId == member.leaderId then
		marker = PartyService.GetMarker(player)
		if marker then
			marker:SetAttribute("Benched", nil)
		end
		PartyService.SetHold(player, spot)
	else
		marker = PartyService.CreateMarker(player, beastId, spot)
		member.markers[beastId] = marker
	end
	if marker then
		markers[id] = marker
	end
	local beast = CardService.GetBeast(player, beastId)
	allies[id] = if beast then `{player.DisplayName} · {Cards.ById[beast.cardId].name}` else player.DisplayName
end

-- A boss summoned an add: a real wild monster of its species, held still beside the boss (left, right, further out)
local function spawnAdd(fight: Fight, id: string, markers: { [string]: BasePart }, addMonsters: { [string]: string })
	local boss = Bosses.BOSSES[fight.monster.boss or ""]
	local adds = if boss then boss.mechanics.adds else nil
	for _, phase in (if boss then boss.phases else nil) or {} do
		adds = adds or phase.mechanics.adds -- the final boss's adds come with a phase
	end
	local leader = next(fight.members)
	if not boss or not adds or not leader then
		return
	end
	local count = 0
	for _ in fight.adds do
		count += 1
	end
	local sideways = (if count % 2 == 0 then 1 else -1) * Bosses.ADD_SPACING * (count // 2 + 1)
	local spot = fight.spots[MONSTER_ID] * CFrame.new(sideways, 0, 0)
	local monster = WildService.SpawnAt(spot.Position, adds.species, boss.level, false)
	if not monster then
		return
	end
	WildService.Lock(monster, leader)
	WildService.SetFightPose(monster, spot)
	fight.adds[id] = monster
	fight.spots[id] = spot
	markers[id] = monster.marker
	addMonsters[id] = monster.id -- clients find the marker by name when it arrives after this message
end

local function handleEvents(fight: Fight, events: { BattleSim.Event })
	local markers: { [string]: BasePart } = {}
	local allies: { [string]: string } = {}
	local addMonsters: { [string]: string } = {}
	for _, event in events do
		if event.type == "attack" and event.from and event.to then
			lunge(fight, event.from, event.to)
		elseif event.type == "faint" and event.to then
			local marker = markerFor(fight, event.to)
			if marker then
				marker:SetAttribute("Fainted", true)
			end
			local add = fight.adds[event.to]
			if add then
				task.delay(Bosses.ADD_FADE_SECONDS, WildService.Defeat, add)
			end
		elseif event.type == "spawn" and event.to then
			spawnAdd(fight, event.to, markers, addMonsters)
		elseif event.type == "phase" and event.kind then
			fight.monster.marker:SetAttribute("Phase", event.kind) -- everyone near sees that head light up
		elseif (event.type == "callin" or event.type == "swap") and event.from then
			enterField(fight, event, markers, allies)
		end
	end
	if #events > 0 then
		fight.sinceSnapshot = 0
		-- New creatures' markers, so clients can float numbers over them; the others see whose they are
		broadcast(fight, { events = events, markers = markers, allies = allies, addMonsters = addMonsters, snapshot = snapshot(fight) })
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

-- A room's pack besides its first monster
local function packOf(fight: Fight): { Monster }
	local pack = {}
	for id, monster in fight.adds do
		if string.sub(id, 1, 3) == "b:p" then
			table.insert(pack, monster)
		end
	end
	return pack
end

-- One member's win: their own party's XP and cash; a boss's items through BossService (their contribution decides)
local function payOut(fight: Fight, member: Member): any
	local player, monster = member.player, fight.monster
	local bossId = monster.boss
	if bossId then
		-- Bosses: their own XP and cash, every win; items only through BossService's farm-protected rules
		local boss = Bosses.BOSSES[bossId]
		local xpEach = CombatMath.splitXp(boss.xp, #member.partyIds)
		for _, beastId in member.partyIds do
			CardService.AddXP(player, beastId, xpEach)
		end
		EconomyService.AddCash(player, boss.cash)
		-- The cards that really fought (resting ones in the party never did): the over-power check weighs these
		local fighterIds = {}
		for beastId in member.fought do
			table.insert(fighterIds, beastId)
		end
		local share = BattleSim.contribution(fight.sim, member.owner)
		local contributed = BossRules.contributed(Bosses, share.dealt, share.taken, share.totalDealt, share.totalTaken)
		local loot = if bossRewards then bossRewards(player, monster, { seconds = fight.sim.time, fighterIds = fighterIds, contributed = contributed }) else nil
		return { xpEach = xpEach, cash = boss.cash, shards = 0, boss = loot }
	end
	if fight.run then
		-- A Dungeon room: the elite XP and cash of every monster in the pack, no cards or items
		local xp, cash = 0, 0
		for _, foe in { monster, table.unpack(packOf(fight)) } do
			local paid = CombatMath.getRewards(Wild, foe.level, foe.elite)
			xp += paid.xp
			cash += paid.cash
		end
		local xpEach = CombatMath.splitXp(xp, #member.partyIds)
		for _, beastId in member.partyIds do
			CardService.AddXP(player, beastId, xpEach)
		end
		EconomyService.AddCash(player, cash)
		return { xpEach = xpEach, cash = cash, shards = 0 }
	end
	local rewards = CombatMath.getRewards(Wild, monster.level, monster.elite)
	local each = CombatMath.splitXp(rewards.xp, #member.partyIds)
	for _, beastId in member.partyIds do
		CardService.AddXP(player, beastId, each)
	end
	EconomyService.AddCash(player, rewards.cash)
	local dropped = nil
	if rng:NextNumber() < rewards.dropChance then
		local cardId = rollDrop(monster)
		if cardId then
			dropped = { cardId = cardId, foil = false, grade = BeastRules.rollGrade(rng:NextNumber(), Cards.ById[cardId].rarity) }
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
			frontierCard = { cardId = pool[rng:NextInteger(1, #pool)], foil = false, grade = BeastRules.rollGrade(rng:NextNumber(), rarity) }
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

-- A member is out of the fight: their creatures are released, fainted ones rest. Returns the ones that rest.
local function release(fight: Fight, member: Member): { string }
	local player = member.player
	fight.endHp[player] = BattleSim.hpLeft(fight.sim, "a", member.owner)
	fight.members[player] = nil
	if fights[player] == fight then
		fights[player] = nil
	end
	if member.died then
		member.died:Disconnect()
	end
	PartyService.SetHold(player, nil)
	PartyService.SetLocked(player, false)
	local leaderMarker = PartyService.GetMarker(player)
	if leaderMarker then
		leaderMarker:SetAttribute("Fainted", nil)
		leaderMarker:SetAttribute("Benched", nil)
	end
	for beastId in member.fought do
		CardService.SetFighting(player, beastId, false)
	end
	for _, marker in member.markers do
		marker:Destroy()
	end
	-- Fainted fighters rest, whatever the result (a run or a win doesn't wake them)
	local rested = {}
	local entries = resting[player]
	if entries then
		for _, beastId in BattleSim.getFainted(fight.sim, "a") do
			if table.find(member.partyIds, beastId) then
				entries[beastId] = os.time() + Combat.REST_SECONDS
				table.insert(rested, beastId)
			end
		end
	end
	return rested
end

local function endFight(fight: Fight, result: string)
	if fight.ended then
		return
	end
	task.defer(function() -- after every member is released below, so endHp is complete
		for _, handler in fightEndedHandlers do
			handler(fight.monster, result, fight.endHp)
		end
	end)
	fight.ended = true
	running[fight] = nil
	for _, add in fight.adds do
		WildService.Defeat(add) -- a boss's adds go with it
	end
	if result == "win" or fight.monster.boss or fight.run then
		WildService.Defeat(fight.monster) -- a boss (or a Dungeon room's pack) always goes when its fight ends
	else
		WildService.Unlock(fight.monster)
	end
	for player, member in table.clone(fight.members) do
		local summary: any = { result = result, rested = release(fight, member) }
		if result == "win" and player.Parent then
			local paid = payOut(fight, member)
			summary.xpEach, summary.cash, summary.card, summary.shards, summary.boss = paid.xpEach, paid.cash, paid.card, paid.shards, paid.boss
			summary.partyIds = member.partyIds
		end
		if player.Parent then
			Remotes.BattleEnded:FireClient(player, summary)
			sendResting(player)
		end
	end
end

-- A member leaves (ran, died, left the game, lost their creature): in a group the others fight on; the last one out
-- ends the fight as a run
local function leave(fight: Fight, member: Member)
	if fight.ended or not fight.members[member.player] then
		return
	end
	local others = 0
	for player in fight.members do
		if player ~= member.player then
			others += 1
		end
	end
	if others == 0 then
		endFight(fight, "run")
		return
	end
	local events = BattleSim.withdraw(fight.sim, member.owner)
	local player = member.player
	local rested = release(fight, member)
	for _, handler in memberLeftHandlers do
		handler(player, fight.monster)
	end
	if player.Parent then
		Remotes.BattleEnded:FireClient(player, { result = "run", rested = rested })
		sendResting(player)
	end
	handleEvents(fight, events)
	if fight.sim.result then
		endFight(fight, outcomeOf(fight.sim.result))
	end
end

-- Starting ------------------------------------------------------------------------------------------------

-- Why this player can't start any fight now, or nil
local function whyNotPlayer(player: Player): string?
	if fights[player] or PartyService.IsLocked(player) then
		return "You're already in a fight."
	end
	for _, blocker in startBlockers do
		local reason = blocker(player)
		if reason then
			return reason
		end
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

-- Why this player can't fight this monster now, or nil
local function whyNot(player: Player, monster: Monster?): string?
	local reason = whyNotPlayer(player)
	if reason then
		return reason
	end
	if not monster or monster.fightingPlayer then
		return "Someone is already fighting that monster."
	end
	return nil
end

-- BossService asks before it spawns a boss
function BattleService.WhyNotFight(player: Player): string?
	return whyNotPlayer(player)
end

-- A Dungeon room's monster as a fighter: its elite stats x Dungeon.PACK_SCALE, scaled to the group like a boss
local function packInput(id: string, monster: Monster, size: number): BattleSim.FighterInput?
	local stats = CombatMath.getMonsterStats(Wild, monster.species, monster.level, monster.elite)
	if not stats then
		return nil
	end
	local hp, atk, swings = BossRules.groupStats(Bosses, stats.hp * Dungeon.PACK_SCALE.hp, stats.atk * Dungeon.PACK_SCALE.atk, size)
	return { id = id, element = monster.element, hp = hp, atk = atk, spd = stats.spd, elite = monster.elite, swings = swings }
end

-- Players (the first leads) against one monster (and a Dungeon room's pack). Every check is done by the caller.
local function startFight(players: { Player }, monster: Monster, options: RunOptions?): boolean
	local boss = if monster.boss then Bosses.BOSSES[monster.boss] else nil
	local run = options ~= nil and options.run == true
	local hpLeft = if options then options.hpLeft else nil
	local stats = if boss then { hp = boss.hp, atk = boss.atk, spd = boss.spd } else CombatMath.getMonsterStats(Wild, monster.species, monster.level, monster.elite)
	if not stats or #players == 0 then
		return false
	end
	local swings = 1
	if boss then
		stats.hp, stats.atk, swings = BossRules.groupStats(Bosses, stats.hp, stats.atk, #players, boss.groupAtkStep)
	end
	local foes: { BattleSim.FighterInput } = {}
	if run and not boss then
		local first = packInput("m", monster, #players)
		if not first then
			return false
		end
		table.insert(foes, first)
	else
		table.insert(foes, {
			id = "m",
			element = monster.element,
			hp = stats.hp,
			atk = stats.atk,
			spd = stats.spd,
			elite = monster.elite,
			mechanics = if boss then boss.mechanics else nil,
			phases = if boss then boss.phases else nil,
			boss = boss ~= nil,
			swings = swings,
		})
	end
	local pack = if options and options.pack then options.pack else {}
	for index, extra in pack do
		local input = packInput(`p{index}`, extra, #players)
		if input then
			table.insert(foes, input)
		end
	end

	local members: { Member } = {}
	local leaders, reserves = {}, {}
	for _, player in players do
		local party = PartyService.GetParty(player) :: { slots: { [number]: string }, summoned: number? }
		local leaderId = party.slots[party.summoned :: number]
		local owner = tostring(player.UserId)
		local partyIds = getPartyIds(player)
		local left = if hpLeft then hpLeft[player] or {} else {}
		local leaderInput = fighterInput(CardService.GetBeast(player, leaderId) :: Beast)
		leaderInput.owner = owner
		leaderInput.hpNow = left[leaderId]
		table.insert(leaders, leaderInput)
		for _, beastId in partyIds do
			local beast = CardService.GetBeast(player, beastId)
			-- In a run, a card that fainted in an earlier room stays out even once it has rested
			if beast and beastId ~= leaderId and not isResting(player, beastId) and DungeonRules.canFight(left, beastId) then
				local input = fighterInput(beast)
				input.owner = owner
				input.hpNow = left[beastId]
				table.insert(reserves, input)
			end
		end
		table.insert(members, { player = player, owner = owner, leaderId = leaderId, markers = {}, fought = { [leaderId] = true }, partyIds = partyIds, died = nil, leashWarnedAt = 0 })
	end
	-- Boss fights and Dungeon rooms allow swaps (and are tuned for them)
	local sideA = { fighters = leaders, reserves = reserves, abilities = true, canRun = true, swapSeconds = if boss or run then Combat.BOSS_SWAP_SECONDS else nil }
	local sim = BattleSim.new(Combat, sideA, { fighters = foes, abilities = false, canRun = false }, rng:NextInteger(1, 2 ^ 30))
	if boss or run then
		sim.maxSeconds = Combat.BOSS_MAX_FIGHT_SECONDS
	end

	-- The ring: the monster where it stands, facing the leader; the leaders on an arc between, each extra beside its own
	local center = monster.marker.Position
	local root = getRoot(players[1]) :: BasePart
	local toPlayer = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
	local direction = if toPlayer.Magnitude > 0.1 then toPlayer.Unit else Vector3.new(0, 0, -1)
	local radius = if boss then Bosses.RING_RADIUS else Combat.RING_RADIUS
	local spots: { [string]: CFrame } = { [MONSTER_ID] = CFrame.lookAt(center, center + direction) }
	local step = Bosses.GROUP_SPACING / radius
	for index, member in members do
		local angle = (index - (#members + 1) / 2) * step
		local facing = CFrame.Angles(0, angle, 0):VectorToWorldSpace(direction)
		local spot = center + facing * radius
		local right = Vector3.new(-facing.Z, 0, facing.X)
		local extra = spot + right * Combat.EXTRA_SIDE
		spots[partyId(member.leaderId)] = CFrame.lookAt(spot, spot - facing)
		spots[`extra:{member.owner}`] = CFrame.lookAt(extra, extra - facing)
	end
	local fight: Fight = {
		members = {},
		size = #members,
		monster = monster,
		sim = sim,
		spots = spots,
		center = center,
		sinceSnapshot = 0,
		ended = false,
		startsAt = if boss then os.clock() + Bosses.INTRO_SECONDS else 0,
		adds = {},
		run = run,
		endHp = {},
	}
	running[fight] = true
	if boss and boss.phases then
		monster.marker:SetAttribute("Phase", boss.phases[1].element)
	end
	WildService.Lock(monster, players[1])
	WildService.SetFightPose(monster, spots[MONSTER_ID])
	-- A room's pack stands beside its first monster (left, right, further out), held still like a boss's adds
	for index, extra in pack do
		local id = `b:p{index}`
		local sideways = (if index % 2 == 1 then 1 else -1) * Bosses.ADD_SPACING * ((index + 1) // 2)
		local spot = spots[MONSTER_ID] * CFrame.new(sideways, 0, 0)
		WildService.Lock(extra, players[1])
		WildService.SetFightPose(extra, spot)
		fight.adds[id] = extra
		fight.spots[id] = spot
	end
	for _, member in members do
		local player = member.player
		fight.members[player] = member
		fights[player] = fight
		PartyService.SetLocked(player, true)
		PartyService.SetHold(player, spots[partyId(member.leaderId)])
		CardService.SetFighting(player, member.leaderId, true)
		local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid")
		if humanoid then
			member.died = humanoid.Died:Connect(function()
				leave(fight, member)
			end)
		end
	end

	local markers: { [string]: BasePart } = { [MONSTER_ID] = monster.marker }
	local foes: { [string]: string } = { [MONSTER_ID] = monster.species } -- a room's monsters by name (its HP bars)
	for id, extra in fight.adds do
		markers[id] = extra.marker
		foes[id] = extra.species
	end
	for _, member in members do
		local marker = PartyService.GetMarker(member.player)
		if marker then
			markers[partyId(member.leaderId)] = marker
		end
	end
	for _, member in members do
		local player = member.player
		local names: { [string]: string } = {}
		for _, beastId in member.partyIds do
			local beast = CardService.GetBeast(player, beastId)
			if beast then
				names[partyId(beastId)] = Cards.ById[beast.cardId].name
			end
		end
		local allies: { [string]: string } = {}
		for _, other in members do
			local beast = CardService.GetBeast(other.player, other.leaderId)
			if other ~= member and beast then
				allies[partyId(other.leaderId)] = `{other.player.DisplayName} · {Cards.ById[beast.cardId].name}`
			end
		end
		Remotes.BattleStarted:FireClient(player, {
			monsterId = monster.id,
			species = monster.species,
			level = monster.level,
			elite = monster.elite,
			element = monster.element,
			boss = monster.boss,
			intro = if boss then Bosses.INTRO_SECONDS else nil,
			names = names,
			allies = allies,
			group = #members > 1,
			foes = foes,
			side = "a",
			markers = markers,
			snapshot = snapshot(fight),
		})
	end
	return true
end

local function tryStart(player: Player, monster: Monster?): boolean
	local reason = whyNot(player, monster)
	if reason then
		return false
	end
	return startFight({ player }, monster :: Monster)
end

-- BossService: these players (the first leads) fight this monster together now (false and the first reason if any
-- of them can't)
-- options: a Dungeon run fight (DungeonService, BossService.StartRun)
function BattleService.StartGroupFight(players: { Player }, monster: Monster, options: RunOptions?): (boolean, string?)
	for _, player in players do
		local reason = whyNot(player, monster)
		if reason then
			return false, reason
		end
		local left = if options and options.hpLeft then options.hpLeft[player] else nil
		local party = PartyService.GetParty(player)
		local leaderId = if party and party.summoned then party.slots[party.summoned] else nil
		if left and leaderId and not DungeonRules.canFight(left, leaderId) then
			return false, "That creature is out for this run. Summon another."
		end
	end
	return startFight(players, monster, options), nil
end

-- BossService: the player fights this monster alone now
function BattleService.StartFight(player: Player, monster: Monster): (boolean, string?)
	return BattleService.StartGroupFight({ player }, monster)
end

function BattleService.SetBossRewards(handler: (player: Player, monster: Monster, fight: { seconds: number, fighterIds: { string }, contributed: boolean }) -> any)
	bossRewards = handler
end

-- Remotes -------------------------------------------------------------------------------------------------

local function onStartFight(player: Player, monsterId: unknown)
	if not allowStart(player) or typeof(monsterId) ~= "string" then
		return
	end
	local monster = WildService.GetMonster(monsterId)
	if monster and monster.boss then
		return -- bosses start only at their gate (BossService)
	end
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
	startFight({ player }, monster :: Monster)
end

-- Buttons pressed during a boss intro do nothing: the fight hasn't started
local function inIntro(fight: Fight): boolean
	return os.clock() < fight.startsAt
end

local function onCallIn(player: Player, id: unknown)
	local fight = fights[player]
	local member = if fight then fight.members[player] else nil
	if not allowCallIn(player) or not fight or not member or inIntro(fight) or typeof(id) ~= "string" or string.sub(id, 1, 2) ~= "a:" then
		return
	end
	-- Only one of your own reserves (the sim checks the owner). Boss fights: a swap (a call-in early on).
	local events: { BattleSim.Event }? = nil
	if (fight.sim.sides.a :: any).swapSeconds then
		events = BattleSim.swap(fight.sim, id, member.owner)
	elseif BattleSim.callIn(fight.sim, id, member.owner) then
		events = { { type = "callin", from = id } }
	end
	if events then
		handleEvents(fight, events)
	end
end

local function onUseAbility(player: Player, fighterId: unknown, which: unknown)
	local fight = fights[player]
	local member = if fight then fight.members[player] else nil
	-- Only your own fighters (the sim checks the owner)
	if not allowAbility(player) or not fight or not member or inIntro(fight) or typeof(fighterId) ~= "string" or string.sub(fighterId, 1, 2) ~= "a:" then
		return
	end
	if which ~= "element" and which ~= "signature" then
		return
	end
	local events = BattleSim.useAbility(fight.sim, fighterId, which :: string, member.owner)
	if events then
		handleEvents(fight, events)
		if fight.sim.result then
			endFight(fight, outcomeOf(fight.sim.result))
		end
	end
end

local function onRun(player: Player)
	local fight = fights[player]
	local member = if fight then fight.members[player] else nil
	if not allowRun(player) or not fight or not member or inIntro(fight) then
		return
	end
	-- In a group fight, Run is leaving (the others fight on), even for the last one still in it: never a run roll
	if fight.size > 1 then
		leave(fight, member)
		return
	end
	handleEvents(fight, BattleSim.tryRun(fight.sim, "a"))
	if fight.sim.result then
		endFight(fight, outcomeOf(fight.sim.result))
	end
end

-- Loop ----------------------------------------------------------------------------------------------------

-- A member who can't go on: their character or summoned creature is gone
local function memberValid(member: Member): boolean
	local player = member.player
	return player.Parent ~= nil
		and getRoot(player) ~= nil
		and PartyService.GetMarker(player) ~= nil
		and CardService.GetBeast(player, member.leaderId) ~= nil
end

-- Players may run around during a fight, but not away from it: past the leash they're put back at its edge
local function keepNear(fight: Fight, member: Member)
	local player = member.player
	local root = getRoot(player)
	if not root then
		return
	end
	local leash = if fight.monster.boss then Bosses.LEASH_RADIUS else Combat.LEASH_RADIUS
	local offset = Vector3.new(root.Position.X - fight.center.X, 0, root.Position.Z - fight.center.Z)
	if offset.Magnitude <= leash then
		return
	end
	local edge = fight.center + offset.Unit * (leash - 2)
	local back = Vector3.new(edge.X, root.Position.Y, edge.Z)
	root.AssemblyLinearVelocity = Vector3.zero
	;(player.Character :: Model):PivotTo(CFrame.lookAt(back, Vector3.new(fight.center.X, back.Y, fight.center.Z)))
	if os.clock() - member.leashWarnedAt > 3 then
		member.leashWarnedAt = os.clock()
		notify(player, "Stay near the fight! (Run to leave it)", true)
	end
end

local function stepFights(dt: number)
	for fight in table.clone(running) do
		if not fight.monster.alive then
			endFight(fight, "run")
			continue
		end
		for _, member in table.clone(fight.members) do
			if not memberValid(member) then
				leave(fight, member)
			else
				keepNear(fight, member)
			end
		end
		if fight.ended or os.clock() < fight.startsAt then
			continue -- the intro: nothing moves yet
		end
		handleEvents(fight, BattleSim.step(fight.sim, dt))
		if fight.sim.result then
			endFight(fight, outcomeOf(fight.sim.result))
		else
			fight.sinceSnapshot += dt
			if fight.sinceSnapshot >= SNAPSHOT_SECONDS then
				fight.sinceSnapshot = 0
				broadcast(fight, { events = {}, snapshot = snapshot(fight) })
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
	local member = if fight then fight.members[player] else nil
	if fight and member then
		leave(fight, member)
	end
	resting[player] = nil
	nearSpring[player] = nil
end

function BattleService.Start()
	DataService.Register({ name = "BattleService", load = load, save = save, unload = unload })
	WildService.SetFightCheck(BattleService.IsFighting)
	-- End a fight before the leave save, so cards that fainted in it are saved as resting
	DataService.OnBeforeLeave(function(player)
		local fight = fights[player]
		local member = if fight then fight.members[player] else nil
		if fight and member then
			leave(fight, member)
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
