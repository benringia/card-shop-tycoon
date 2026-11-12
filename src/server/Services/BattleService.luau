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
-- Boss fights put the players in the fight too (spec 2026-11-02-you-in-the-fight-design): each member gets a player
-- fighter ("a:@<UserId>") beside their one summoned creature (no call-in), swings their sword (SwordAttack, SwordSkill:
-- timing and reach checked with SwordRules, hits through BattleSim.swordHit), dodges (Dodge) and is hit by the boss's
-- quick hits and closing rings (each ring's shape is placed here and checked with RingRules as it lands). A player
-- at 0 HP kneels (character attribute Downed) until they get back up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Announcements = require(Config:WaitForChild("Announcements"))
local AttackFx = require(Config:WaitForChild("AttackFx"))
local Bosses = require(Config:WaitForChild("Bosses"))
local Combat = require(Config:WaitForChild("Combat"))
local Chikin = require(Config:WaitForChild("Chikin"))
local Dungeon = require(Config:WaitForChild("Dungeon"))
local Defeat = require(Config:WaitForChild("Defeat"))
local Party = require(Config:WaitForChild("Party"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
-- The server wild map in the main game, the Frontier in the Frontier place (same shape, plus Frontier drops)
local Wild = Place.getWorld()
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local BossRules = require(Shared:WaitForChild("Util"):WaitForChild("BossRules"))
local CombatMath = require(Shared:WaitForChild("Util"):WaitForChild("CombatMath"))
local DebuffRules = require(Shared:WaitForChild("Util"):WaitForChild("DebuffRules"))
local DefeatRules = require(Shared:WaitForChild("Util"):WaitForChild("DefeatRules"))
local DungeonRules = require(Shared:WaitForChild("Util"):WaitForChild("DungeonRules"))
local FightFxRules = require(Shared:WaitForChild("Util"):WaitForChild("FightFxRules"))
local MarkerNames = require(Shared:WaitForChild("Util"):WaitForChild("MarkerNames"))
local PartyRules = require(Shared:WaitForChild("Util"):WaitForChild("PartyRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Swords = require(Config:WaitForChild("Swords"))
local Weapons = require(Config:WaitForChild("Weapons"))
local RingRules = require(Shared:WaitForChild("Util"):WaitForChild("RingRules"))
local SwordRules = require(Shared:WaitForChild("Util"):WaitForChild("SwordRules"))
local SummonRules = require(Shared:WaitForChild("Util"):WaitForChild("SummonRules"))
local MonsterLooks = require(Shared:WaitForChild("Util"):WaitForChild("MonsterLooks"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local BattleSim = require(Util:WaitForChild("BattleSim"))
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local SwordService = require(Services:WaitForChild("SwordService"))
local WeaponService = require(Services:WaitForChild("WeaponService"))
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
	lastCut: SwordRules.LastCut?, -- boss fights: their sword's last cut (os.clock times)
	swappedAt: number?, -- when they last switched weapon in this fight (no cut or skill for Weapons.SWAP_SECONDS)
	skillReady: number, -- boss fights: os.clock when their sword skill is ready again
	dodgedAt: number?, -- boss fights: os.clock of their last dodge (one before a skill's hit cancels it)
	down: boolean, -- their player fighter is down (can't walk or jump)
	rings: number, -- big attacks aimed at them (the defeat screen)
	dodged: number, -- of those, dodged or stepped out of
	slow: number?, -- a boss's debuff slows their walking by this share (Config/Bosses DEBUFFS slow)
}

-- A big attack's ring as placed when it started (studs on the ground plane): a slam's centre, or a swipe's origin
-- (the boss), direction and length
type Ring = { shape: string, x: number, y: number, z: number, dirX: number, dirZ: number, radius: number, length: number, halfAngle: number }

type Fight = {
	members: { [Player]: Member }, -- still in the fight
	size: number, -- members at the start (a boss is scaled to it)
	monster: Monster,
	sim: BattleSim.State,
	spots: { [string]: CFrame }, -- where each fighter stands in the ring, by sim id ("a:<beastId>", "b:m")
	-- Each creature's place on the ring ("a:<beastId>"; "extra:<owner>" for a call-in), which a swap takes over: a
	-- ranged creature stands further back from it (standSpot)
	ringSpots: { [string]: CFrame },
	center: Vector3, -- the ring; players may roam within the leash of it
	sinceSnapshot: number,
	ended: boolean,
	startsAt: number, -- os.clock(): boss fights hold still through the intro until then
	adds: { [string]: Monster }, -- a boss's adds and a room's pack, by sim id ("b:add1"..., "b:p1"...)
	run: boolean, -- a Dungeon run fight: rewards without items, Run leaves the run
	endHp: { [Player]: { [string]: number } }, -- each member's creatures' HP when they left the fight (its end or earlier)
	rings: { [number]: Ring }, -- boss fights: rings still to land, by id
	-- A boss's summons (adds.run, the Rift Devourer's): each one running to its pet (out of its rift first), the pet each
	-- is after, and the corners the current wave comes out at
	runs: { [string]: SummonRun },
	summonFocus: { [string]: string },
	waveCorners: { number }?,
	pylons: { [string]: BasePart }, -- the Dungeon's room 3: its pylons by sim id ("b:Pylon1"...), none elsewhere
	onPylon: ((kind: string, pylon: BasePart?) -> ())?, -- RunOptions.onPylon
	leashCenter: Vector3?, -- RunOptions.leashCenter: the leash from here instead of `center`
}

-- One summon on its way: to `to` (a bite's reach from its pet at `face`) at `speed` studs a second, from `startAt`
-- (os.clock(): once it's out of its rift)
type SummonRun = { to: Vector3, face: Vector3, speed: number, startAt: number }

-- The Dungeon: a room's pack (`monster` is its first, `pack` the others) and the HP left from earlier rooms
-- (spec 2026-11-11-dungeon-puzzles) `swords`: players fight in this room with their swords (room 3); `pylons`: the
-- crystal pylons shielding its pack (BattleSim pylons, broken by swords); `onPylon`: told "pylonBroken" (with the part)
-- and "shieldDown" so the run can show them
export type RunOptions = { pack: { Monster }?, hpLeft: { [Player]: { [string]: number } }?, run: boolean?, swords: boolean?, pylons: { { part: BasePart, hp: number } }?, onPylon: ((kind: string, pylon: BasePart?) -> ())?, packAtk: number?, leashCenter: Vector3? }

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
local allowSwordAttack = RateLimiter.new(Combat.SWORD_ACTION_COOLDOWN)
local allowPetPylon = RateLimiter.new(Combat.PET_PYLON_COOLDOWN)
local allowSwordSkill = RateLimiter.new(Combat.SWORD_ACTION_COOLDOWN)
local allowDodge = RateLimiter.new(Combat.SWORD_ACTION_COOLDOWN)
local rng = Random.new()
local startBlockers: { (player: Player) -> string? } = {} -- ArenaService: no wild fights mid-PvP
-- BossService: a boss win's items (the loot rules live there); its result goes to the client as summary.boss
local fightEndedHandlers: { (monster: Monster, result: string, hpLeft: { [Player]: { [string]: number } }, stillIn: { Player }) -> () } = {}
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
-- After a fight ends (deferred): its monster, the result ("win", "lose", "run", or "timeout" when it hit the time
-- limit), every member's creatures' HP then (members who left earlier included) and the players still in it at the end
function BattleService.OnFightEnded(handler: (monster: Monster, result: string, hpLeft: { [Player]: { [string]: number } }, stillIn: { Player }) -> ())
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

-- DevService's /tire: every party card but the summoned one rests, so a boss fight can be lost in Studio
function BattleService.TireParty(player: Player)
	local entries = resting[player]
	local party = PartyService.GetParty(player)
	if not entries or not party then
		return
	end
	for slot, beastId in party.slots do
		if slot ~= party.summoned then
			entries[beastId] = os.time() + Combat.REST_SECONDS
		end
	end
	sendResting(player)
end

-- Fighters ------------------------------------------------------------------------------------------------

-- withPerk: its fight perk too (monster and boss fights; PvP fights without)
local function fighterInput(beast: Beast, withPerk: boolean?): BattleSim.FighterInput
	local card = Cards.ById[beast.cardId]
	local stats = BeastRules.getStats(card, beast.foil, beast.level, beast.stars, beast.grade)
	return {
		id = beast.id,
		element = card.element,
		hp = stats.hp,
		atk = stats.atk,
		spd = stats.spd,
		signature = if Combat.SIGNATURES[card.name] then card.name else nil,
		grade = beast.grade,
		perk = if withPerk then PartyRules.getFightPerk(Party, card.element, card.rarity, beast.stars) else nil,
	}
end

-- A card as a fighter: its stats now, and its signature ability if it has one (ArenaService uses it too: no perk)
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

-- The member a player fighter ("a:@<owner>") belongs to
local function memberByOwner(fight: Fight, owner: string): Member?
	for _, member in fight.members do
		if member.owner == owner then
			return member
		end
	end
	return nil
end

local function markerFor(fight: Fight, id: string): BasePart?
	if id == MONSTER_ID then
		return fight.monster.marker
	elseif string.sub(id, 1, 3) == "a:@" then
		local member = memberByOwner(fight, string.sub(id, 4))
		return if member then getRoot(member.player) else nil
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

-- Where a creature stands for its ring spot: further back when it attacks from range (a projectile or a bolt,
-- FightFxRules.isRanged; owner 2026-11-03), so its shots fly across the gap. A ring spot faces the foe, so back is +Z.
local function standSpot(ringSpot: CFrame, player: Player, beastId: string): CFrame
	local beast = CardService.GetBeast(player, beastId)
	local card = if beast then Cards.ById[beast.cardId] else nil
	if card and FightFxRules.isRanged(card.element, AttackFx) then
		return ringSpot * CFrame.new(0, 0, Combat.RANGED_BACK)
	end
	return ringSpot
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
		PartyService.Dismiss(marker) -- shrinks away back into its owner
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
	local ringSpot = (if event.to then fight.ringSpots[event.to] else nil) or fight.ringSpots[`extra:{member.owner}`]
	if event.to then
		leaveField(member, string.sub(event.to, 3))
	end
	local spot = standSpot(ringSpot, player, beastId)
	fight.ringSpots[id] = ringSpot
	fight.spots[id] = spot
	member.fought[beastId] = true
	CardService.SetFighting(player, beastId, true)
	local marker: BasePart?
	if beastId == member.leaderId then
		marker = PartyService.GetMarker(player)
		if marker then
			marker:SetAttribute("SummonedAt", workspace:GetServerTimeNow()) -- back in: clients pop it in again
			marker:SetAttribute("Benched", nil)
			marker:SetAttribute("Fainted", nil) -- a fainted leader Tidal Blessing stood back up
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

-- Where a pet stands (its spot in the ring, else its marker), nil if it's gone
local function petPosition(fight: Fight, id: string?): Vector3?
	if not id then
		return nil
	end
	local spot = fight.spots[id]
	if spot then
		return spot.Position
	end
	local marker = markerFor(fight, id)
	return if marker then marker.Position else nil
end

-- A summon sets off for its pet: a bite's reach short of it (its own size plus Bosses.SUMMON.meleeGap), fast enough to
-- get there in `seconds` (0: retargeting, at SUMMON.retargetSpeed), after `wait` seconds (coming out of its rift)
local function runTo(fight: Fight, id: string, add: WildService.Monster, petId: string, seconds: number, wait: number)
	local pet = petPosition(fight, petId)
	if not pet then
		return
	end
	local from = add.marker.Position
	local size = tonumber(add.marker:GetAttribute("Size")) or 1
	local gap = Bosses.SUMMON.meleeGap + MonsterLooks.height(Wild, add.species, false, nil, nil, size) / 2
	local stop = SummonRules.meleeSpot({ x = pet.X, z = pet.Z }, { x = from.X, z = from.Z }, gap)
	local to = Vector3.new(stop.x, from.Y, stop.z)
	local cfg = Bosses.SUMMON
	local speed = if seconds > 0 then SummonRules.runSpeed((to - from).Magnitude, seconds, cfg.minSpeed, cfg.maxSpeed) else cfg.retargetSpeed
	fight.runs[id] = { to = to, face = pet, speed = speed, startAt = os.clock() + wait }
	fight.summonFocus[id] = petId
end

-- Each step: summons out of their rifts run on toward their pets, facing the way they go, and turn to bite on arrival
local function moveSummons(fight: Fight, dt: number)
	local now = os.clock()
	for id, run in fight.runs do
		local add = fight.adds[id]
		if not add or not add.alive then
			fight.runs[id] = nil
			continue
		end
		if now < run.startAt then
			continue
		end
		local at = add.marker.Position
		local flat = Vector3.new(run.to.X - at.X, 0, run.to.Z - at.Z)
		local step = run.speed * dt
		local cframe: CFrame
		if flat.Magnitude <= step then
			cframe = CFrame.lookAt(run.to, Vector3.new(run.face.X, run.to.Y, run.face.Z))
			fight.runs[id] = nil
		else
			local ahead = at + flat.Unit * step
			cframe = CFrame.lookAt(ahead, ahead + flat.Unit)
		end
		fight.spots[id] = cframe
		WildService.SetFightPose(add, cframe)
	end
end

-- A boss summoned through rifts (adds.run): out at a random corner of the arena (different ones in a wave), facing
-- its pet, rising out of its rift and then running to it; the event gets where it came out for clients' rift
local function spawnSummon(fight: Fight, id: string, event: BattleSim.Event, boss: any, adds: any, leader: Player): WildService.Monster?
	local slot = event.slot or 1
	if slot == 1 or not fight.waveCorners then
		local rolls = {}
		for index = 1, adds.count do
			rolls[index] = rng:NextNumber()
		end
		fight.waveCorners = SummonRules.pickCorners(adds.count, rolls)
	end
	local bossSpot = fight.spots[MONSTER_ID]
	-- the arena's own frame: every arena (WildService) has its boss BOSS_SPOT past the centre along +X, the gate on -X,
	-- whichever way the boss turned since
	local arena = CFrame.lookAt(bossSpot.Position, bossSpot.Position - Vector3.xAxis)
	local corners = fight.waveCorners :: { number }
	local corner = SummonRules.corner(corners[slot] or slot, BossRules.arenaRadius(boss, Bosses), Bosses.BOSS_SPOT, Bosses.SUMMON.cornerShare)
	local at = (arena * CFrame.new(corner.x, 0, corner.z)).Position
	local face = petPosition(fight, event.focus) or bossSpot.Position
	local monster = WildService.SpawnAt(at, adds.species, boss.level, false, nil, nil, { size = adds.size or 1, emerge = adds.emerge or 0 })
	if not monster then
		return nil
	end
	local ground = monster.marker.Position
	local spot = CFrame.lookAt(ground, Vector3.new(face.X, ground.Y, face.Z))
	WildService.Lock(monster, leader)
	WildService.SetFightPose(monster, spot)
	fight.adds[id] = monster
	fight.spots[id] = spot
	if event.focus then
		runTo(fight, id, monster, event.focus, adds.run, adds.emerge or 0)
	end
	local view = event :: any
	view.x, view.y, view.z = ground.X, ground.Y, ground.Z
	view.size = adds.size
	view.emerge = adds.emerge
	view.height = MonsterLooks.height(Wild, adds.species, false, nil, nil, adds.size)
	return monster
end

-- A boss summoned an add: a real wild monster of its species, held still beside the boss (left, right, further out);
-- summoned through rifts (adds.run), at a corner of the arena, running to its pet (spawnSummon)
local function spawnAdd(fight: Fight, id: string, event: BattleSim.Event, markers: { [string]: BasePart }, addMonsters: { [string]: string })
	local boss = Bosses.BOSSES[fight.monster.boss or ""]
	local adds = if boss then boss.mechanics.adds else nil
	for _, phase in (if boss then boss.phases else nil) or {} do
		adds = adds or phase.mechanics.adds -- the final boss's adds come with a phase
	end
	local leader = next(fight.members)
	if not boss or not adds or not leader then
		return
	end
	if adds.run then
		local summon = spawnSummon(fight, id, event, boss, adds, leader)
		if summon then
			markers[id] = summon.marker
			addMonsters[id] = summon.id
		end
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

-- A big attack started: where its ring is (a slam or the Frost Tyrant's spikes under its target, a player or a pet; a
-- swipe from the boss toward them; a thunderclap's storm circle round the boss, the sim's radius); the event is sent
-- with the shape so clients draw the same ring
local function recordRing(fight: Fight, event: BattleSim.Event)
	local target = markerFor(fight, event.to or "")
	local boss = Bosses.BOSSES[fight.monster.boss or ""]
	local from = fight.monster.marker.Position
	local clap = event.kind == "clap"
	local at = if target and not clap then target.Position else from
	local radius = if clap then tonumber((event :: any).radius) or Bosses.RING_SLAM_RADIUS else Bosses.RING_SLAM_RADIUS
	local ring: Ring = { shape = event.kind or "slam", x = at.X, y = at.Y, z = at.Z, dirX = 0, dirZ = -1, radius = radius, length = 0, halfAngle = 0 }
	if ring.shape == "swipe" then
		local look = fight.monster.marker.CFrame.LookVector
		local toward = Vector3.new(at.X - from.X, 0, at.Z - from.Z)
		local direction = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(look.X, 0, look.Z).Unit
		ring.x, ring.y, ring.z = from.X, at.Y, from.Z
		ring.dirX, ring.dirZ = direction.X, direction.Z
		-- Sometimes huge (a boss's hugeSwipe): the warning, the effect and the hit check all use this size
		local length = (if boss then boss.ringRadius or Bosses.RING_RADIUS else Bosses.RING_RADIUS) + Bosses.RING_SWIPE_EXTRA
		ring.length, ring.halfAngle = RingRules.swipeSize(length, Bosses.RING_SWIPE_HALF_ANGLE, if boss then boss.hugeSwipe else nil, rng:NextNumber())
	end
	fight.rings[event.ring :: number] = ring
	local view = event :: any
	for key, value in ring do
		view[key] = value
	end
end

-- BattleSim asks as a ring lands: is its target inside it now? (No character: they can't have stepped out.)
local function ringInside(fight: Fight, info: BattleSim.RingInfo): boolean
	local ring = fight.rings[info.id]
	fight.rings[info.id] = nil
	local member = memberByOwner(fight, string.sub(info.target, 4))
	local root = if member then getRoot(member.player) else nil
	if not ring or not root then
		return true
	end
	local at = root.Position
	if ring.shape == "slam" or ring.shape == "spikes" or ring.shape == "clap" then
		return RingRules.inSlam(ring.x, ring.z, ring.radius, at.X, at.Z)
	end
	return RingRules.inSwipe(ring.x, ring.z, ring.dirX, ring.dirZ, ring.length, ring.halfAngle, at.X, at.Z)
end

-- The boss winds up (kind "quick" or "big"): every client poses it for `seconds` (MonsterController)
local function windUp(fight: Fight, seconds: number?, kind: string)
	local marker = fight.monster.marker
	marker:SetAttribute("WindUp", seconds or 0)
	marker:SetAttribute("WindUpKind", kind)
	marker:SetAttribute("WindUps", (tonumber(marker:GetAttribute("WindUps")) or 0) + 1)
end

-- A member's walking from member.down and member.slow: kneeling with no walking or jumping while down, slowed while a
-- boss's debuff slows them (Util/DebuffRules), else back to the speed and jump they had before (kept in WalkSpeedBefore
-- and JumpHeightBefore while either holds)
local function updateMovement(member: Member)
	local character = member.player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not character or not humanoid then
		return
	end
	character:SetAttribute("Downed", if member.down then true else nil)
	local held = member.down or member.slow ~= nil
	local before = humanoid:GetAttribute("WalkSpeedBefore")
	if held then
		if typeof(before) ~= "number" then
			before = humanoid.WalkSpeed
			humanoid:SetAttribute("WalkSpeedBefore", humanoid.WalkSpeed)
			humanoid:SetAttribute("JumpHeightBefore", humanoid.JumpHeight)
		end
		humanoid.WalkSpeed = DebuffRules.walkSpeed(before :: number, member.down, member.slow)
		humanoid.JumpHeight = DebuffRules.jumpHeight(tonumber(humanoid:GetAttribute("JumpHeightBefore")) or humanoid.JumpHeight, member.down, member.slow)
	elseif typeof(before) == "number" then
		humanoid.WalkSpeed = before
		humanoid.JumpHeight = tonumber(humanoid:GetAttribute("JumpHeightBefore")) or humanoid.JumpHeight
		humanoid:SetAttribute("WalkSpeedBefore", nil)
		humanoid:SetAttribute("JumpHeightBefore", nil)
	end
end

-- Each step: a boss's debuff that slows (Tangled, Chilled; Frozen and Electrocuted's jolts hold them still) slows the
-- member's walking while the sim says it holds, so a refresh, a different debuff, going down and running out all
-- follow the sim
local function followDebuff(fight: Fight, member: Member)
	local kind, left = BattleSim.playerDebuff(fight.sim, member.owner)
	local spec = if kind then Bosses.DEBUFFS[kind] else nil
	local slow = nil
	if spec and left then
		local _, now = DebuffRules.effectAt(spec, spec.seconds - left)
		slow = now
	end
	if slow ~= member.slow then
		member.slow = slow
		updateMovement(member)
	end
end

-- Each step: Town Chikin's Courage on the member's creatures while their ChikinCourageUntil (os.time, set by
-- TownChikinService) holds, gone the step it runs out
local function followCourage(fight: Fight, member: Member)
	local untilTime = member.player:GetAttribute("ChikinCourageUntil")
	local share = if typeof(untilTime) == "number" and untilTime > os.time() then Chikin.COURAGE.share else 0
	if BattleSim.boostOf(fight.sim, member.owner) ~= share then
		BattleSim.setBoost(fight.sim, member.owner, share)
	end
end

local function handleEvents(fight: Fight, events: { BattleSim.Event })
	local markers: { [string]: BasePart } = {}
	local allies: { [string]: string } = {}
	local addMonsters: { [string]: string } = {}
	for _, event in events do
		-- Room 3: a broken pylon and the fallen shield are the run's to show (DungeonService)
		if (event.type == "pylonBroken" or event.type == "shieldDown") and fight.onPylon then
			fight.onPylon(event.type, if event.to then fight.pylons[event.to] else nil)
		end
		if event.type == "attack" and event.from and event.to then
			-- A summon whose pet fell (or swapped out) runs to the one it bites now; it doesn't lunge while it runs
			local summon = fight.adds[event.from]
			local focus = fight.summonFocus[event.from]
			if summon and focus and focus ~= event.to and string.sub(event.to, 1, 3) ~= "a:@" then
				runTo(fight, event.from, summon, event.to, 0, 0)
			end
			if not fight.runs[event.from] then
				lunge(fight, event.from, event.to)
			end
			if event.dodged and (event.kind == "Slam" or event.kind == "Swipe") then
				local member = memberByOwner(fight, string.sub(event.to, 4))
				if member then
					member.dodged += 1
				end
			end
		elseif event.type == "faint" and event.to then
			local marker = markerFor(fight, event.to)
			if marker then
				marker:SetAttribute("Fainted", true)
			end
			local add = fight.adds[event.to]
			if add then
				fight.runs[event.to] = nil
				task.delay(Bosses.ADD_FADE_SECONDS, WildService.Defeat, add)
			end
		elseif event.type == "ability" and event.kind == "Rebirth" and typeof(event.revived) == "table" then
			-- Tidal Blessing stood fainted creatures up: one still on the field gets up where it lay (clients play
			-- SummonFx.revive); a benched one went back to the reserves and clears its flag when it comes back in
			for _, id in event.revived do
				local marker = if BattleSim.getFighter(fight.sim, id) then markerFor(fight, id) else nil
				if marker then
					marker:SetAttribute("Fainted", nil)
				end
			end
		elseif event.type == "spawn" and event.to then
			spawnAdd(fight, event.to, event, markers, addMonsters)
		elseif event.type == "phase" and event.kind then
			fight.monster.marker:SetAttribute("Phase", event.kind) -- everyone near sees that head light up
		elseif event.type == "heal" and event.to == MONSTER_ID then
			-- The boss's heal count and its enrage, for the moments on its model (Config/Bosses moments)
			local marker = fight.monster.marker
			marker:SetAttribute("Heals", (tonumber(marker:GetAttribute("Heals")) or 0) + 1)
		elseif event.type == "enrage" then
			fight.monster.marker:SetAttribute("Enraged", true)
		elseif (event.type == "callin" or event.type == "swap") and event.from then
			enterField(fight, event, markers, allies)
		elseif event.type == "ring" and event.ring then
			recordRing(fight, event)
			local member = memberByOwner(fight, string.sub(event.to or "", 4))
			if member then
				member.rings += 1
			end
			if event.kind ~= "clap" then
				windUp(fight, event.seconds, "big")
			end
		elseif event.type == "thunderclap" and event.kind == "windup" then
			-- A warned thunderclap rears up: clients draw its storm circle round the boss where it stands now
			local at = fight.monster.marker.Position
			local view = event :: any
			view.x, view.y, view.z = at.X, at.Y, at.Z
			windUp(fight, event.seconds, "clap")
		elseif event.type == "telegraph" then
			windUp(fight, event.seconds, "quick")
		elseif (event.type == "down" or event.type == "getUp") and event.to then
			local member = memberByOwner(fight, string.sub(event.to, 4))
			if member then
				member.down = event.type == "down"
				updateMovement(member)
			end
		end
	end
	if #events > 0 then
		fight.sinceSnapshot = 0
		-- New creatures' markers, so clients can float numbers over them; the others see whose they are
		-- A marker made this moment arrives as nil: its name lets the client find it (Util/MarkerNames)
		broadcast(fight, { events = events, markers = markers, markerNames = MarkerNames.of(markers), allies = allies, addMonsters = addMonsters, snapshot = snapshot(fight) })
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

-- `each` XP to every party card; for the victory screen, each card's way to its next level before and after
local function giveXp(player: Player, partyIds: { string }, each: number): { any }
	local party = {}
	for _, beastId in partyIds do
		local before = CardService.GetBeast(player, beastId)
		local level, from = if before then before.level else 1, if before then BeastRules.levelProgress(before.level, before.xp) else 0
		local after = CardService.AddXP(player, beastId, each, "fight")
		if after then
			table.insert(party, {
				id = beastId,
				cardId = after.cardId,
				level = after.level,
				fromLevel = level, -- the portrait's level chip rolls from this one as the sparks land
				levelUp = after.level > level,
				from = from,
				to = BeastRules.levelProgress(after.level, after.xp),
			})
		end
	end
	return party
end

-- One member's win: their own party's XP and cash; a boss's items through BossService (their contribution decides)
local function payOut(fight: Fight, member: Member): any
	local player, monster = member.player, fight.monster
	local bossId = monster.boss
	if bossId then
		-- Bosses: their own XP and cash, every win; items only through BossService's farm-protected rules
		local boss = Bosses.BOSSES[bossId]
		local xpEach = CombatMath.splitXp(boss.xp, #member.partyIds)
		local party = giveXp(player, member.partyIds, xpEach)
		EconomyService.AddCash(player, boss.cash)
		-- The cards that really fought (resting ones in the party never did): the over-power check weighs these
		local fighterIds = {}
		for beastId in member.fought do
			table.insert(fighterIds, beastId)
		end
		local share = BattleSim.contribution(fight.sim, member.owner)
		local contributed = BossRules.contributed(Bosses, share.dealt, share.taken, share.totalDealt, share.totalTaken)
		local loot = if bossRewards then bossRewards(player, monster, { seconds = fight.sim.time, fighterIds = fighterIds, contributed = contributed }) else nil
		return { xpEach = xpEach, cash = boss.cash, shards = 0, boss = loot, party = party }
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
		local party = giveXp(player, member.partyIds, xpEach)
		EconomyService.AddCash(player, cash)
		return { xpEach = xpEach, cash = cash, shards = 0, party = party }
	end
	local rewards = CombatMath.getRewards(Wild, monster.level, monster.elite)
	local each = CombatMath.splitXp(rewards.xp, #member.partyIds)
	local party = giveXp(player, member.partyIds, each)
	EconomyService.AddCash(player, rewards.cash)
	local dropped = nil
	if rng:NextNumber() < rewards.dropChance then
		local cardId = rollDrop(monster)
		if cardId then
			dropped = { cardId = cardId, foil = false, grade = BeastRules.rollGrade(rng:NextNumber(), Cards.ById[cardId].rarity) }
			CardService.AddFresh(player, { dropped })
		end
	end
	-- Wild Ore for the Forge weapons (the Wild valley and the Frontier)
	local ore = 0
	if rng:NextNumber() < rewards.oreChance then
		ore = ItemService.GiveItem(player, Weapons.WILD_ORE, 1)
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
	return { xpEach = each, cash = rewards.cash, card = frontierCard or dropped, shards = shards, ore = ore, party = party }
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
	member.down, member.slow = false, nil
	updateMovement(member)
	SwordService.SetBackHidden(player, false)
	local leaderMarker = PartyService.GetMarker(player)
	if leaderMarker then
		leaderMarker:SetAttribute("Fainted", nil)
		leaderMarker:SetAttribute("Benched", nil)
	end
	for beastId in member.fought do
		CardService.SetFighting(player, beastId, false)
	end
	for _, marker in member.markers do
		PartyService.Dismiss(marker)
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

-- A lost boss fight's numbers for the defeat screen (Util/DefeatRules, owner 2026-11-04): the member's sword and each
-- creature's damage, the boss's HP left, the big attacks aimed at them and dodged, the fight's length and a tip
local function defeatStats(fight: Fight, member: Member): any
	local playerId = `a:@{member.owner}`
	local sword = if BattleSim.getFighter(fight.sim, playerId) then 0 else nil
	local creatures = {}
	for id, damage in BattleSim.damageBy(fight.sim, member.owner) do
		if id == playerId then
			sword = damage
		else
			local beast = CardService.GetBeast(member.player, string.sub(id, 3))
			if beast then
				table.insert(creatures, { cardId = beast.cardId, damage = damage })
			end
		end
	end
	local foe = BattleSim.getFighter(fight.sim, MONSTER_ID)
	local boss = Bosses.BOSSES[fight.monster.boss or ""]
	return {
		stats = {
			sword = sword,
			creatures = creatures,
			hpShare = if foe and foe.maxHp > 0 then foe.hp / foe.maxHp else 0,
			rings = member.rings,
			dodged = member.dodged,
		},
		foe = if boss then boss.name else fight.monster.species,
		seconds = fight.sim.time,
		tip = DefeatRules.tip(fight.monster.boss, rng:NextNumber(), Defeat),
	}
end

local function endFight(fight: Fight, result: string)
	if fight.ended then
		return
	end
	local reported = if fight.sim.timedOut then "timeout" else result
	local stillIn = {}
	for player in fight.members do
		table.insert(stillIn, player)
	end
	task.defer(function() -- after every member is released below, so endHp is complete
		for _, handler in fightEndedHandlers do
			handler(fight.monster, reported, fight.endHp, stillIn)
		end
	end)
	fight.ended = true
	running[fight] = nil
	for _, add in fight.adds do
		WildService.Defeat(add) -- a boss's adds go with it
	end
	if result == "win" and fight.monster.boss then
		-- A beaten boss lies there a moment (its death scene on clients), then goes
		local fallen = fight.monster
		fallen.marker:SetAttribute("Fainted", true)
		task.delay(Bosses.DEATH_SECONDS, WildService.Defeat, fallen)
	elseif result == "win" or fight.monster.boss or fight.run then
		WildService.Defeat(fight.monster) -- a boss (or a Dungeon room's pack) always goes when its fight ends
	else
		WildService.Unlock(fight.monster)
	end
	for player, member in table.clone(fight.members) do
		local summary: any = { result = result, rested = release(fight, member) }
		if result == "lose" and fight.monster.boss then
			summary.countdown = Combat.LOSS_COUNTDOWN -- the defeat screen's countdown to town (BossService moves them)
			summary.defeat = defeatStats(fight, member)
		end
		if result == "win" and player.Parent then
			local paid = payOut(fight, member)
			summary.xpEach, summary.cash, summary.card, summary.shards, summary.boss = paid.xpEach, paid.cash, paid.card, paid.shards, paid.boss
			summary.ore = paid.ore
			summary.partyIds = member.partyIds
			summary.party = paid.party -- each card's XP bar before and after (the victory screen)
			summary.seconds = fight.sim.time
			local boss = Bosses.BOSSES[fight.monster.boss or ""]
			summary.foe = if boss then boss.name else fight.monster.species
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

-- Takes a player out of their fight as if they ran (the Dungeon's fall: out of the run, never pulled back to the ring)
function BattleService.Withdraw(player: Player)
	local fight = fights[player]
	local member = if fight then fight.members[player] else nil
	if fight and member then
		leave(fight, member)
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
		return if Place.isDungeon() then "Your creature is resting. Summon a rested one."
			else `Your creature is resting. Summon a rested one or visit {if Place.isFrontier() then "the spring at the entrance" else "the plaza spring"}.`
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

-- Room 3's pylons for the clients' sword aim (sim id, part, hit radius), or nil in any other fight
local function pylonList(fight: Fight): { { id: string, part: BasePart, radius: number } }?
	local list = {}
	for id, part in fight.pylons do
		table.insert(list, { id = id, part = part, radius = Dungeon.PUZZLE.PYLON_HIT_RADIUS })
	end
	return if #list > 0 then list else nil
end

-- A Dungeon room's monster as a fighter: its elite stats x Dungeon.PACK_SCALE, scaled to the group like a boss
-- (`atkScale`: the room's own softening, Config/Dungeon ROOMS[n].atk)
local function packInput(id: string, monster: Monster, size: number, atkScale: number?): BattleSim.FighterInput?
	local stats = CombatMath.getMonsterStats(Wild, monster.species, monster.level, monster.elite)
	if not stats then
		return nil
	end
	local hp, atk, swings = BossRules.groupStats(Bosses, stats.hp * Dungeon.PACK_SCALE.hp, stats.atk * Dungeon.PACK_SCALE.atk * (atkScale or 1), size)
	return { id = id, element = monster.element, hp = hp, atk = atk, spd = stats.spd, elite = monster.elite, swings = swings }
end

-- Whether a player fights beside their creature: always against a boss, and against a wild monster once they have
-- a sword (owner 2026-11-03; a Dungeon room's pack stays the creatures' fight, but for room 3's pylons: `swords`)
local function fightsWithSword(player: Player, boss: boolean, run: boolean, swords: boolean): boolean
	return boss or ((swords or not run) and SwordService.GetSword(player) ~= nil)
end

-- Players (the first leads) against one monster (and a Dungeon room's pack). Every check is done by the caller.
local function startFight(players: { Player }, monster: Monster, options: RunOptions?): boolean
	local boss = if monster.boss then Bosses.BOSSES[monster.boss] else nil
	local run = options ~= nil and options.run == true
	local swords = options ~= nil and options.swords == true
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
		local first = packInput("m", monster, #players, if options then options.packAtk else nil)
		if not first then
			return false
		end
		if swords then
			first.playerAttacks = CombatMath.getMonsterAttacks(Wild, true) -- quick hits on the players fighting in it
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
			-- A wild monster's quick hits on a player who fights with a sword (no rings outside boss fights)
			playerAttacks = if boss then boss.playerAttacks else CombatMath.getMonsterAttacks(Wild, monster.elite),
		})
	end
	local pack = if options and options.pack then options.pack else {}
	for index, extra in pack do
		local input = packInput(`p{index}`, extra, #players, if options then options.packAtk else nil)
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
		local leaderInput = fighterInput(CardService.GetBeast(player, leaderId) :: Beast, true)
		leaderInput.owner = owner
		leaderInput.hpNow = left[leaderId]
		table.insert(leaders, leaderInput)
		if fightsWithSword(player, boss ~= nil, run, swords) then
			-- The player fights beside their creature (never a creature's target; down instead of fainting)
			table.insert(leaders, { id = `@{owner}`, player = true, owner = owner, element = "None", hp = Combat.PLAYER_HP, atk = 0, spd = 10 })
		end
		for _, beastId in partyIds do
			local beast = CardService.GetBeast(player, beastId)
			-- In a run, a card that fainted in an earlier room stays out even once it has rested
			if beast and beastId ~= leaderId and not isResting(player, beastId) and DungeonRules.canFight(left, beastId) then
				local input = fighterInput(beast, true)
				input.owner = owner
				input.hpNow = left[beastId]
				table.insert(reserves, input)
			end
		end
		-- the sword skill opens on its full cooldown (owner 2026-11-09), as the client's does (SwordController.SetCombat)
		local swordId = SwordService.GetSword(player)
		local sword = if swordId then Swords.SWORDS[swordId] else nil
		local skillReady = if sword then SwordRules.openingSkillReady(os.clock(), sword.skill) else 0
		table.insert(members, { player = player, owner = owner, leaderId = leaderId, markers = {}, fought = { [leaderId] = true }, partyIds = partyIds, died = nil, leashWarnedAt = 0, lastCut = nil, skillReady = skillReady, down = false, slow = nil, rings = 0, dodged = 0 })
	end
	-- Boss fights and Dungeon rooms allow swaps (and are tuned for them); in boss fights only one creature of yours fights
	local sideA = { fighters = leaders, reserves = reserves, abilities = true, canRun = true, swapSeconds = if boss or run then Combat.BOSS_SWAP_SECONDS else nil, callIn = if boss then false else nil, creaturesDecide = not boss and (not run or swords) }
	-- Room 3's pylons: the sim's by their part's name ("b:Pylon1"...)
	local pylonInputs: { { id: string, hp: number } } = {}
	local pylonParts: { [string]: BasePart } = {}
	for _, pylon in if options and options.pylons then options.pylons else {} do
		table.insert(pylonInputs, { id = pylon.part.Name, hp = pylon.hp })
		pylonParts[`b:{pylon.part.Name}`] = pylon.part
	end
	local sim = BattleSim.new(Combat, sideA, { fighters = foes, abilities = false, canRun = false, pylons = pylonInputs }, rng:NextInteger(1, 2 ^ 30))
	if boss or run then
		sim.maxSeconds = Combat.BOSS_MAX_FIGHT_SECONDS
	end

	-- The ring: the monster where it stands, facing the leader; the leaders on an arc between, each extra beside its own
	local center = monster.marker.Position
	local root = getRoot(players[1]) :: BasePart
	local toPlayer = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
	local direction = if toPlayer.Magnitude > 0.1 then toPlayer.Unit else Vector3.new(0, 0, -1)
	local radius = if boss then boss.ringRadius or Bosses.RING_RADIUS else Combat.RING_RADIUS
	local spots: { [string]: CFrame } = { [MONSTER_ID] = CFrame.lookAt(center, center + direction) }
	local ringSpots: { [string]: CFrame } = {}
	local step = Bosses.GROUP_SPACING / radius
	for index, member in members do
		local angle = (index - (#members + 1) / 2) * step
		local facing = CFrame.Angles(0, angle, 0):VectorToWorldSpace(direction)
		local spot = center + facing * radius
		local right = Vector3.new(-facing.Z, 0, facing.X)
		local extra = spot + right * Combat.EXTRA_SIDE
		local leader = partyId(member.leaderId)
		ringSpots[leader] = CFrame.lookAt(spot, spot - facing)
		ringSpots[`extra:{member.owner}`] = CFrame.lookAt(extra, extra - facing)
		spots[leader] = standSpot(ringSpots[leader], member.player, member.leaderId)
	end
	local fight: Fight = {
		members = {},
		size = #members,
		monster = monster,
		sim = sim,
		spots = spots,
		ringSpots = ringSpots,
		center = center,
		sinceSnapshot = 0,
		ended = false,
		startsAt = if boss then os.clock() + Bosses.INTRO_SECONDS else 0,
		adds = {},
		run = run,
		endHp = {},
		rings = {},
		runs = {},
		summonFocus = {},
		pylons = pylonParts,
		onPylon = if options then options.onPylon else nil,
		leashCenter = if options then options.leashCenter else nil,
	}
	if boss then
		sim.ringCheck = function(info: BattleSim.RingInfo): boolean
			return ringInside(fight, info)
		end
	end
	running[fight] = true
	if boss and boss.phases then
		monster.marker:SetAttribute("Phase", boss.phases[1].element)
	end
	WildService.Lock(monster, players[1])
	WildService.SetFightPose(monster, spots[MONSTER_ID])
	-- A room's pack holds where it rose (spread round the arena: DungeonRules.packSpots; owner 2026-11-12: "separate
	-- them"), facing the creatures (the middle of their spots; owner: "they face the wrong way when attacking"), held
	-- still like a boss's adds
	local sum, count = Vector3.zero, 0
	for id, spot in spots do
		if string.sub(id, 1, 2) == "a:" then
			sum += spot.Position
			count += 1
		end
	end
	local fightAt = if count > 0 then sum / count else spots[MONSTER_ID].Position + spots[MONSTER_ID].LookVector * 10
	for index, extra in pack do
		local id = `b:p{index}`
		local at = extra.marker.Position
		local spot = CFrame.lookAt(at, Vector3.new(fightAt.X, at.Y, fightAt.Z))
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
		if boss then
			SwordService.SetBackHidden(player, true)
			SwordService.CountFight(player)
		end
		local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid")
		if humanoid then
			member.died = humanoid.Died:Connect(function()
				leave(fight, member)
			end)
		end
	end

	local markers: { [string]: BasePart } = { [MONSTER_ID] = monster.marker }
	local foes: { [string]: string } = { [MONSTER_ID] = monster.species } -- a room's monsters by name (its HP bars)
	-- Each foe's monster id: a marker made just before this message (a Dungeon room's pack) arrives as nil under
	-- streaming, so clients find it by its name (Monster_<id>) instead
	local monsterIds: { [string]: string } = { [MONSTER_ID] = monster.id }
	for id, extra in fight.adds do
		markers[id] = extra.marker
		foes[id] = extra.species
		monsterIds[id] = extra.id
	end
	for _, member in members do
		local marker = PartyService.GetMarker(member.player)
		if marker then
			markers[partyId(member.leaderId)] = marker
		end
		local playerRoot = if boss then getRoot(member.player) else nil
		if playerRoot then
			markers[`a:@{member.owner}`] = playerRoot -- damage numbers over the player
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
			buttonNames = SwordService.ShowButtonNames(player), -- the HUD names its buttons (first boss fights)
			sword = fightsWithSword(player, boss ~= nil, run, swords), -- the player is in the fight: the HUD's sword buttons
			pylons = pylonList(fight), -- room 3: the pylons to aim at while they stand
			allies = allies,
			group = #members > 1,
			foes = foes,
			side = "a",
			markers = markers,
			markerNames = MarkerNames.of(markers),
			addMonsters = monsterIds,
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

-- DevService's /bosshp: the boss of this player's fight down to `share` of its HP (Studio only), to reach a boss's
-- summons, phases and heals without fighting there
function BattleService.SetBossHpShare(player: Player, share: number): boolean
	local fight = fights[player]
	if not RunService:IsStudio() or not fight or not fight.monster.boss then
		return false
	end
	return BattleSim.setHpShare(fight.sim, MONSTER_ID, share)
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

-- A member's fight they can swing in now (they fight in it: a boss, or a wild monster with a sword; past the intro,
-- still in it), or nil
local function swordFight(player: Player): (Fight?, Member?)
	local fight = fights[player]
	local member = if fight then fight.members[player] else nil
	if not fight or not member or fight.ended or inIntro(fight) or not BattleSim.getFighter(fight.sim, `a:@{member.owner}`) then
		return nil, nil
	end
	return fight, member
end

-- Who a sword can hit: the boss and its adds (or a wild monster) still standing, with their sizes on the ground plane;
-- in room 3 only its standing pylons while any stands
local function swordTargets(fight: Fight): { SwordRules.Target }
	local list: { SwordRules.Target } = {}
	if BattleSim.pylonsLeft(fight.sim, "b") > 0 then
		for id, pylon in fight.pylons do
			if pylon:GetAttribute("Broken") ~= true then
				table.insert(list, { id = id, x = pylon.Position.X, z = pylon.Position.Z, radius = Dungeon.PUZZLE.PYLON_HIT_RADIUS })
			end
		end
		return list
	end
	local boss = Bosses.BOSSES[fight.monster.boss or ""]
	local function add(id: string, marker: BasePart, radius: number)
		local fighter = BattleSim.getFighter(fight.sim, id)
		if fighter and not fighter.fainted then
			table.insert(list, { id = id, x = marker.Position.X, z = marker.Position.Z, radius = radius })
		end
	end
	local radius = if boss then (boss.ringRadius or Bosses.RING_RADIUS) * Bosses.HIT_RADIUS_SHARE
		else Bosses.ADD_HIT_RADIUS * (if fight.monster.elite then Wild.ELITE_SIZE else 1)
	add(MONSTER_ID, fight.monster.marker, radius)
	for id, monster in fight.adds do
		add(id, monster.marker, Bosses.ADD_HIT_RADIUS * (tonumber(monster.marker:GetAttribute("Size")) or 1))
	end
	return list
end

-- A cut or the skill lands: every target `reaches` says is hit (from where the player stands and faces now) takes it.
-- `share` (default 1): this strike's part of one hit (BattleSim.swordHit), for a skill split into strikes
-- `weaponId`: the weapon the cut or skill started with (its element, bond and perk, even if switched since)
local function strike(fight: Fight, member: Member, power: number, kind: string, reaches: (px: number, pz: number, lookX: number, lookZ: number, target: SwordRules.Target) -> boolean, share: number?, weaponId: string?)
	local root = getRoot(member.player)
	if fight.ended or fight.members[member.player] ~= member or not root then
		return
	end
	local look = root.CFrame.LookVector
	local events: { BattleSim.Event } = {}
	for _, target in swordTargets(fight) do
		if reaches(root.Position.X, root.Position.Z, look.X, look.Z, target) then
			local weapon = WeaponService.HitInfo(member.player, BattleSim.creatureElement(fight.sim, member.owner), weaponId)
			for _, event in BattleSim.swordHit(fight.sim, member.owner, target.id, power, kind, weapon, share) or {} do
				table.insert(events, event)
			end
		end
	end
	if #events > 0 then
		handleEvents(fight, events)
		if fight.sim.result then
			endFight(fight, outcomeOf(fight.sim.result))
		end
	end
end

-- A round 1 sword's cut or skill starting: every client draws its effects on that player's character (spec
-- 2026-11-06-sword-skills-design 4 "Everyone sees them"; each client checks its distance and budget). The Steel Sword
-- has none.
local function swordCast(player: Player, sword: Swords.Sword, move: string)
	local root = getRoot(player)
	if sword.fx and root then
		Remotes.SwordCast:FireAllClients(player.UserId, move, root.Position.X, root.Position.Z)
	end
end

-- Still in a weapon switch's lock (the quick switch, spec 2026-11-07-weapons-round2-design 6): no cut or skill
local function swapping(member: Member, now: number): boolean
	return member.swappedAt ~= nil and now < member.swappedAt + Weapons.SWAP_SECONDS
end

-- A player in a fight switched weapon (WeaponService): the lock starts, the combo starts again, and a cut or skill
-- of the old weapon still on its way is cancelled (each checks swappedAt when it lands)
local function onSwap(player: Player)
	local fight = fights[player]
	local member = if fight then fight.members[player] else nil
	if member then
		member.swappedAt = os.clock()
		member.lastCut = nil
	end
end

-- An Attack tap: the next cut of the combo (SwordRules.nextCut), landing at its strike frame
local function onSwordAttack(player: Player)
	local fight, member = swordFight(player)
	local swordId = SwordService.GetSword(player)
	if not allowSwordAttack(player) or not fight or not member or not swordId then
		return
	end
	local sword = Swords.SWORDS[swordId]
	local now = os.clock()
	if swapping(member, now) then
		return
	end
	local index, startAt = SwordRules.nextCut(sword.combo, member.lastCut, now, Swords.COMBO_RESET)
	if not index or not startAt then
		return
	end
	member.lastCut = { index = index, startedAt = startAt }
	SwordService.Touch(player)
	local cut = sword.combo[index]
	task.delay(startAt - now, swordCast, player, sword, `cut{index}`)
	local power = cut.power * WeaponService.Power(player)
	local weaponId = WeaponService.GetEquipped(player)
	task.delay(startAt - now + cut.hitAt, function()
		-- a switch after the tap, before the hit, cancels the old weapon's cut
		if SwordRules.skillDodged(now, startAt - now + cut.hitAt, member.swappedAt) then
			return
		end
		strike(fight, member, power, "Sword", function(px, pz, lookX, lookZ, target)
			return SwordRules.cutReaches(cut, px, pz, lookX, lookZ, target)
		end, nil, weaponId)
	end)
end

-- The sword skill, on its own cooldown, each sword's own shape (SwordRules.skillHits, spec 2026-11-06-sword-skills-design
-- 3): the Steel Sword's dash slash (the client dashes you; every foe along the path from where you started to where you
-- are when the cut lines appear, clamped to the dash's longest: the server doesn't take the client's word for how far it
-- went), a spin around you, a line or a travelling wave ahead, or strikes on your aimed foe. Where you stand and face
-- comes from the server's own record of your character; each hit lands `after` the hit moment with its share of the power.
local function onSwordSkill(player: Player)
	local fight, member = swordFight(player)
	local swordId = SwordService.GetSword(player)
	local root = getRoot(player)
	if not allowSwordSkill(player) or not fight or not member or not swordId or not root or os.clock() < member.skillReady then
		return
	elseif swapping(member, os.clock()) then
		return
	end
	local sword = Swords.SWORDS[swordId]
	local skill = sword.skill
	member.skillReady = os.clock() + skill.cooldown * (1 - BattleSim.perkOf(fight.sim, member.owner, "Express"))
	SwordService.Touch(player)
	swordCast(player, sword, "skill")
	local sx, sz = root.Position.X, root.Position.Z
	local power = skill.power * WeaponService.Power(player)
	local weaponId = WeaponService.GetEquipped(player) -- its later hits keep this weapon's element, bond and perk
	local castAt = os.clock()
	task.delay(skill.hitAt, function()
		local now = getRoot(player)
		if fight.ended or fight.members[player] ~= member or not now then
			return
		end
		-- a dodge before the hit cancelled the move (owner 2026-11-07), as does a weapon switch
		if SwordRules.skillDodged(castAt, skill.hitAt, member.dodgedAt) or SwordRules.skillDodged(castAt, skill.hitAt, member.swappedAt) then
			return
		end
		local look = now.CFrame.LookVector
		local hits = SwordRules.skillHits(skill.shape, sx, sz, now.Position.X, now.Position.Z, look.X, look.Z, swordTargets(fight))
		for _, hit in hits do
			task.delay(hit.after, strike, fight, member, power * hit.share, "Skill", function(_px, _pz, _lookX, _lookZ, target)
				return target.id == hit.id
			end, hit.share, weaponId)
		end
	end)
end

-- A dodge: untouchable for a moment (the sim decides; the dash itself is the client's)
local function onDodge(player: Player)
	local fight, member = swordFight(player)
	if not allowDodge(player) or not fight or not member then
		return
	end
	local events = BattleSim.dodge(fight.sim, member.owner)
	if events then
		member.dodgedAt = os.clock()
		handleEvents(fight, events)
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
	local boss = Bosses.BOSSES[fight.monster.boss or ""]
	-- big rings: a boss's own (BossRules.leashRadius; the Frontier's are wider), a Dungeon run's the whole ring
	local leash = if boss then BossRules.leashRadius(boss, Bosses) elseif fight.run then Dungeon.ROOM_LEASH else Combat.LEASH_RADIUS
	local middle = fight.leashCenter or fight.center
	local offset = Vector3.new(root.Position.X - middle.X, 0, root.Position.Z - middle.Z)
	if offset.Magnitude <= leash then
		return
	end
	local edge = middle + offset.Unit * (leash - 2)
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
		moveSummons(fight, dt)
		for _, member in fight.members do
			followDebuff(fight, member)
			followCourage(fight, member)
		end
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
	WeaponService.SetFightCheck(BattleService.IsFighting)
	WeaponService.SetSwapHook(onSwap)
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
	Remotes.SwordAttack.OnServerEvent:Connect(onSwordAttack)
	-- The Dungeon's room 3: your creature sent at one crystal pylon (its prompt, within reach), or back to the fight
	-- (false); owner 2026-11-12
	Remotes.PetPylon.OnServerEvent:Connect(function(player: Player, target: unknown)
		local fight = fights[player]
		local member = if fight then fight.members[player] else nil
		if not allowPetPylon(player) or not fight or not member or fight.ended or next(fight.pylons) == nil then
			return
		end
		if target == false then
			BattleSim.setPylonFocus(fight.sim, member.owner, nil)
			return
		end
		local part = if typeof(target) == "string" then fight.pylons[target] else nil
		local root = getRoot(player)
		local reach = Dungeon.PUZZLE.PYLON_PROMPT
		if not part or not root or (root.Position - part.Position).Magnitude > reach.distance + reach.slack then
			return -- not a pylon of this fight, or out of the prompt's reach: only a tampered client sends these
		end
		BattleSim.setPylonFocus(fight.sim, member.owner, target :: string)
	end)
	Remotes.SwordSkill.OnServerEvent:Connect(onSwordSkill)
	Remotes.Dodge.OnServerEvent:Connect(onDodge)

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
