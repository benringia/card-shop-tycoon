--!strict
local BattleSim = require("../src/server/Util/BattleSim")
local combat = require("../src/shared/Config/Combat")
local Bosses = require("../src/shared/Config/Bosses")
local expect = require("./lib/expect")
-- Bosses go for pets first (the owner 2026-11-10: no normal hit at a player while a creature stands,
-- Combat.PLAYER_TARGET_SHARE 0); the quick hits' own timing and dodge tests keep the old one in three with a creature up
local mixedCombat = table.clone(combat)
mixedCombat.PLAYER_TARGET_SHARE = 1 / 3
local CombatMath = require("../src/shared/Util/CombatMath")

local function CombatMathInterval(spd: number): number
	return CombatMath.getAttackInterval(combat, spd)
end

local function fighter(id: string, element: string, hp: number, atk: number, spd: number, signature: string?)
	return { id = id, element = element, hp = hp, atk = atk, spd = spd, signature = signature }
end

local function monster(element: string, hp: number, atk: number, spd: number, elite: boolean?)
	return { id = "m", element = element, hp = hp, atk = atk, spd = spd, elite = elite == true }
end

-- A wild fight: side A is the party (leader + call-in reserves), side B one monster with no abilities
local function wild(leader: any, reserves: { any }, foe: any, seed: number): any
	return BattleSim.new(combat, { fighters = { leader }, reserves = reserves, abilities = true, canRun = true }, { fighters = { foe }, abilities = false, canRun = false }, seed)
end

local function side(list: { any }, canRun: boolean?): any
	return { fighters = list, abilities = true, canRun = canRun == true }
end

-- Every owner's super meter full on both sides (a super needs a full meter: owner 2026-11-06, option A)
local function charge(state: any)
	for _, side in { state.sides.a, state.sides.b } do
		for _, list in { side.fighters, side.reserves } do
			for _, fighter in list do
				side.meters[fighter.owner or ""] = combat.SUPER_METER.full
			end
		end
	end
end

-- A special move pressed and its wind-up waited out (its cast's own seconds: combat.ABILITY_WINDUP for a Pet button
-- move, the super's own wind-up for a super): the move's events, or nil and why not
local function castNow(state: any, id: string, which: string, owner: string?): ({ any }?, string?)
	if which == "signature" then
		charge(state)
	end
	local pressed, why = BattleSim.useAbility(state, id, which, owner)
	if not pressed then
		return nil, why
	end
	local windup = combat.ABILITY_WINDUP
	for _, event in pressed do
		if event.type == "cast" then
			windup = event.seconds
		end
	end
	local out = {}
	for _, event in BattleSim.step(state, windup) do
		if event.type == "ability" then
			table.insert(out, event)
		end
	end
	return out, nil
end

-- Runs until the fight ends (or max seconds); returns the result and every event
local function runToEnd(state: any, maxSeconds: number?): (string?, { any })
	local all = {}
	local t = 0
	while not state.result and t < (maxSeconds or 300) do
		for _, event in BattleSim.step(state, 0.1) do
			table.insert(all, event)
		end
		t += 0.1
	end
	return state.result, all
end

-- Steps the fight for this long (0.1 s steps); every event with the fight time it came at
local function timedEvents(state: any, seconds: number): { { time: number, event: any } }
	local all = {}
	for _ = 1, math.round(seconds / 0.1) do
		for _, event in BattleSim.step(state, 0.1) do
			table.insert(all, { time = state.time, event = event })
		end
	end
	return all
end

local function count(events: { any }, predicate: (any) -> boolean): number
	local n = 0
	for _, event in events do
		if predicate(event) then
			n += 1
		end
	end
	return n
end

-- A group fight: two players' leaders on side A, each with their own reserves, one big boss on side B
local function owned(id: string, owner: string, hp: number?)
	local input: any = fighter(id, "Ember", hp or 500, 20, 10)
	input.owner = owner
	return input
end

-- An owner's creature with a fight perk
local function perked(kind: string, value: number): any
	local input = owned("p1", "1")
	input.perk = { kind = kind, value = value }
	return input
end

local function group(seed: number): any
	return BattleSim.new(combat, {
		fighters = { owned("p1", "1"), owned("p2", "2") },
		reserves = { owned("r1", "1"), owned("r1b", "1"), owned("r2", "2") },
		abilities = true,
		canRun = true,
	}, { fighters = { monster("Bloom", 100000, 10, 10) }, abilities = false, canRun = false }, seed)
end

-- A boss fight with swaps: one player's leader and two reserves against a monster of the given ATK
local function swapFight(seed: number, foeAtk: number): any
	return BattleSim.new(combat, {
		fighters = { owned("p1", "1") },
		reserves = { owned("r1", "1"), owned("r1b", "1", 300) },
		abilities = true,
		canRun = true,
		swapSeconds = 10,
	}, { fighters = { monster("Bloom", 100000, foeAtk, 10) }, abilities = false, canRun = false }, seed)
end

local function ids(list: { any }): { [string]: any }
	local byId = {}
	for _, fighter in list do
		byId[fighter.id] = fighter
	end
	return byId
end

-- A boss with these mechanics (10000 HP, SPD 14) against the given fighters (default one Tide fighter with abilities)
local function bossWith(mechanics: any, seed: number, fighters: { any }?): any
	return BattleSim.new(combat, {
		fighters = fighters or { fighter("a", "Tide", 100000, 20, 10) },
		abilities = true,
		canRun = true,
	}, { fighters = { { id = "m", element = "Shade", hp = 10000, atk = 1, spd = 14, boss = true, mechanics = mechanics } }, abilities = false, canRun = false }, seed)
end

local SHIELD = { shield = { every = 20, fraction = 0.06, breakStun = 3 } }
local ADDS = { adds = { at = { 0.7, 0.35 }, count = 2, hpShare = 0.06, atkShare = 0.4, guard = 0.5, species = "Rift Horror" } }

-- A boss with phases (the final boss): Tide shield, then Volt thunderclap below 60%, then Ember enrage below 30%
local PHASES = {
	{ below = 1, element = "Tide", mechanics = { shield = { every = 1, fraction = 0.05, breakStun = 1 } } },
	{ below = 0.6, element = "Volt", mechanics = { thunderclap = { every = 12, seconds = 1, minFactor = 0.3, maxFactor = 1.5 } } },
	{ below = 0.3, element = "Ember", mechanics = { enrage = { below = 0.2, atkMultiplier = 2 } } },
}

local function phasedBoss(phases: any, seed: number): any
	return BattleSim.new(combat, { fighters = { fighter("a", "Tide", 100000, 20, 10) }, abilities = true, canRun = true }, {
		fighters = { { id = "m", element = "Shade", hp = 10000, atk = 1, spd = 14, boss = true, mechanics = {}, phases = phases } },
		abilities = false,
		canRun = false,
	}, seed)
end

local function firstOf(events: { any }, kind: string): any
	for _, event in events do
		if event.type == kind then
			return event
		end
	end
	return nil
end

-- The player in boss fights (spec 2026-11-02-you-in-the-fight-design): an owner's player fighter beside their creature
local function playerInput(owner: string): any
	return { id = `@{owner}`, player = true, owner = owner, element = "None", hp = combat.PLAYER_HP, atk = 0, spd = 10 }
end

-- One player's creature and player fighter, a reserve, swaps on and no call-in, against a huge boss of this ATK
local function bossFightWithPlayer(seed: number, foeAtk: number, mechanics: any?, playerAttacks: any?, fighters: { any }?, reserves: { any }?, useCombat: any?): any
	return BattleSim.new(useCombat or combat, {
		fighters = fighters or { owned("p1", "1"), playerInput("1") },
		reserves = reserves or { owned("r1", "1") },
		abilities = true,
		canRun = true,
		swapSeconds = 10,
		callIn = false,
	}, {
		fighters = { { id = "m", element = "Bloom", hp = 100000, atk = foeAtk, spd = 10, boss = true, mechanics = mechanics or {}, playerAttacks = playerAttacks } },
		abilities = false,
		canRun = false,
	}, seed)
end

-- Steps the fight for this long (0.1 s steps); returns every event
local function runFor(state: any, seconds: number): { any }
	local all = {}
	for _ = 1, math.round(seconds / 0.1) do
		for _, event in BattleSim.step(state, 0.1) do
			table.insert(all, event)
		end
	end
	return all
end

local function viewOf(state: any, id: string): any
	for _, view in BattleSim.snapshot(state).sides.a.fighters do
		if view.id == id then
			return view
		end
	end
	return nil
end

-- The sim's own record of a fighter (for fields the snapshot leaves out: burnUntil, protectedUntil...)
local function raw(state: any, id: string): any
	for _, s in { state.sides.a, state.sides.b } do
		for _, f in s.fighters do
			if f.id == id then
				return f
			end
		end
	end
	return nil
end

-- Steps one 0.1 s step at a time until `predicate(event)` matches; returns the time of that step (nil after `limit` s)
local function stepUntil(state: any, predicate: (any) -> boolean, limit: number): number?
	for _ = 1, math.round(limit / 0.1) do
		for _, event in BattleSim.step(state, 0.1) do
			if predicate(event) then
				return state.time
			end
		end
	end
	return nil
end

return {
	["hpNow: a fighter starts hurt but keeps its max HP"] = function()
		local state = BattleSim.new(combat, { fighters = { { id = "x", element = "Ember", hp = 100, atk = 5, spd = 10, hpNow = 40 } }, abilities = false, canRun = false },
			{ fighters = { monster("Tide", 50, 1, 1) }, abilities = false, canRun = false }, 1)
		local x = BattleSim.getFighter(state, "a:x") :: any
		expect.equal(x.hp, 40, "starts at 40")
		expect.equal(x.maxHp, 100, "max stays 100")
	end,

	["hpLeft: an owner's fighters and reserves, fainted at 0"] = function()
		local state = group(21)
		state.sides.a.fighters[1].hp = 123
		local left = BattleSim.hpLeft(state, "a", "1")
		expect.equal(left.p1, 123, "the hurt leader")
		expect.equal(left.r1, 500, "a reserve that never fought")
		expect.isNil(left.p2, "not player 2's")
		state.sides.a.fighters[1].fainted = true
		expect.equal(BattleSim.hpLeft(state, "a", "1").p1, 0, "fainted counts as 0")
		expect.equal(BattleSim.hpLeft(state, "a").p2, 500, "no owner: the whole side")
	end,

	["the time limit ends the fight as a run and marks it timed out"] = function()
		local state = BattleSim.new(combat, { fighters = { fighter("a", "Ember", 100000, 1, 10) }, abilities = false, canRun = true },
			{ fighters = { monster("Tide", 100000, 1, 10) }, abilities = false, canRun = false }, 3)
		state.maxSeconds = 5
		runToEnd(state, 10)
		expect.equal(state.result, "run", "result")
		expect.equal(state.timedOut, true, "timed out")
		local ran = wild(fighter("b", "Ember", 100, 1, 10), {}, monster("Tide", 100000, 1, 1), 4)
		BattleSim.tryRun(ran, "a")
		expect.equal(ran.timedOut == true, false, "a real run is not a timeout")
	end,

	["phases: the boss starts as phase 1"] = function()
		local state = phasedBoss(PHASES, 11)
		expect.equal(state.sides.b.fighters[1].element, "Tide", "phase 1's element")
		local _, events = runToEnd(state, 1.05)
		expect.equal(firstOf(events, "shield") ~= nil, true, "phase 1's shield")
	end,

	["phases: crossing a threshold switches element and mechanics once"] = function()
		local state = phasedBoss(PHASES, 12)
		local boss = state.sides.b.fighters[1]
		runToEnd(state, 1.05)
		boss.hp = 5900
		local events = BattleSim.step(state, 0.1)
		expect.equal(count(events, function(e)
			return e.type == "phase"
		end), 1, "one phase event")
		local phase = firstOf(events, "phase")
		expect.equal(phase and phase.kind, "Volt", "into Volt")
		expect.equal(phase and phase.damage, 2, "phase 2")
		expect.equal(boss.element, "Volt", "the boss is Volt now")
		expect.equal(state.sides.b.shield, 0, "phase 1's shield is gone")
		local _, later = runToEnd(state, 3)
		expect.isNil(firstOf(later, "shield"), "no more shields")
	end,

	["phases never go back after a heal"] = function()
		local state = phasedBoss(PHASES, 13)
		local boss = state.sides.b.fighters[1]
		boss.hp = 5900
		BattleSim.step(state, 0.1)
		boss.hp = 9000
		local events = BattleSim.step(state, 0.1)
		expect.isNil(firstOf(events, "phase"), "no phase change back")
		expect.equal(boss.element, "Volt", "still Volt")
	end,

	["phases: a Shade adds phase spawns its adds as it starts"] = function()
		local state = phasedBoss({
			{ below = 1, element = "Tide", mechanics = {} },
			{ below = 0.6, element = "Shade", mechanics = { adds = { at = { 0.6 }, count = 2, hpShare = 0.04, atkShare = 0.35, guard = 0.5, species = "Rift Horror" } } },
		}, 14)
		state.sides.b.fighters[1].hp = 5900
		local events = BattleSim.step(state, 0.1)
		expect.equal(count(events, function(e)
			return e.type == "spawn"
		end), 2, "two adds")
		expect.equal(state.sides.b.fighters[2].element, "Shade", "the add is the phase's element")
	end,

	["heal: never more than its uses in a fight"] = function()
		local state = bossWith({ heal = { below = 0.5, fraction = 0.05, cooldown = 1, uses = 2 } }, 31)
		local boss = state.sides.b.fighters[1]
		local heals = 0
		for _ = 1, 300 do
			boss.hp = 3000
			for _, event in BattleSim.step(state, 0.1) do
				if event.type == "heal" then
					heals += 1
				end
			end
		end
		expect.equal(heals, 2, "two heals in 30 s, not one a second")
	end,

	["boss skills keep a gap: a shield and a thunderclap due together come apart"] = function()
		local state = bossWith({ shield = { every = 5, fraction = 0.01, breakStun = 1 }, thunderclap = { every = 5, seconds = 1, minFactor = 0.3, maxFactor = 1.5 } }, 32)
		local times = {}
		for _ = 1, 150 do
			for _, event in BattleSim.step(state, 0.1) do
				if event.type == "shield" or event.type == "thunderclap" then
					table.insert(times, state.time)
				end
			end
		end
		table.sort(times)
		expect.equal(#times >= 2, true, "both fired")
		for index = 2, #times do
			expect.equal(times[index] - times[index - 1] >= combat.BOSS_SKILL_GAP - 1e-6, true, `skill {index} waited the gap`)
		end
	end,

	["shield: goes up every 20 s and absorbs damage first"] = function()
		local state = bossWith(SHIELD, 1)
		local _, early = runToEnd(state, 19.9)
		expect.isNil(firstOf(early, "shield"), "not before 20 s")
		local _, events = runToEnd(state, 0.3)
		local shield = firstOf(events, "shield")
		expect.equal(shield and shield.heal, 600, "6% of 10000")
		local boss = state.sides.b.fighters[1]
		local hp = boss.hp
		runToEnd(state, 1.5)
		expect.equal(boss.hp, hp, "the hits land on the shield")
	end,

	["shield: breaking it stuns the boss for 3 s"] = function()
		local state = bossWith(SHIELD, 2)
		runToEnd(state, 20.2)
		state.sides.b.shield = 1
		local _, events = runToEnd(state, 2)
		expect.equal(firstOf(events, "shieldBreak") ~= nil, true, "it broke")
		local boss = state.sides.b.fighters[1]
		expect.equal(boss.stunUntil - state.time > 1, true, "longer than the usual 1 s cap on boss stuns")
	end,

	["thunderclap: slower creatures stay stunned longer"] = function()
		local state = bossWith({ thunderclap = { every = 12, seconds = 3, minFactor = 0.3, maxFactor = 1.5 } }, 3, {
			fighter("slow", "Tide", 100000, 5, 5),
			fighter("fast", "Tide", 100000, 5, 30),
		})
		local _, events = runToEnd(state, 12.1)
		expect.equal(firstOf(events, "thunderclap") ~= nil, true, "it clapped")
		local stuns = {}
		for _, event in events do
			if event.type == "stun" then
				stuns[event.to] = event.damage
			end
		end
		expect.equal(stuns["a:slow"], 4.5, "3 s x 1.5 (capped)")
		expect.equal(math.abs(stuns["a:fast"] - 1.4) < 1e-9, true, "3 s x 14/30")
	end,

	-- The owner 2026-11-11: the Storm Sovereign's thunderclap is warned (a storm circle round it while it rears up) and
	-- leaves a player inside it Electrocuted; its pets are stunned as before, at the clap
	["a warned thunderclap: a storm circle round the boss, then the clap"] = function()
		local clap = { every = 2, seconds = 1, minFactor = 0.3, maxFactor = 1.5, warning = 1, radius = 20, debuff = "Electrocuted" }
		local state = bossFightWithPlayer(41, 1, { thunderclap = clap }, nil, { owned("p1", "1", 1e9), playerInput("1") })
		local early = runFor(state, 2.05)
		local windup = firstOf(early, "thunderclap")
		assert(windup, "it rears up")
		expect.equal(windup.kind, "windup")
		expect.equal(windup.seconds, 1)
		expect.equal(windup.radius, 20)
		local circle = firstOf(early, "ring")
		assert(circle and circle.kind == "clap" and circle.to == "a:@1", "the storm circle on the player")
		expect.equal(circle.radius, 20)
		expect.equal(firstOf(early, "stun"), nil, "nobody stunned before the clap")
		local landed = runFor(state, clap.warning + combat.HIT_GRACE + 0.1)
		local boom = firstOf(landed, "thunderclap")
		assert(boom and boom.kind == "clap", "then it claps")
		local stun = firstOf(landed, "stun")
		assert(stun and stun.to == "a:p1", "its pet is stunned at the clap")
		local debuff = firstOf(landed, "debuff")
		assert(debuff and debuff.to == "a:@1" and debuff.kind == "Electrocuted", "the player inside is Electrocuted")
		expect.equal(debuff.seconds, Bosses.DEBUFFS.Electrocuted.seconds)
		expect.equal(count(landed, function(e)
			return e.type == "attack" and e.to == "a:@1"
		end), 0, "no damage: the jolts are the hit")
	end,

	["out of the storm circle or dodging: no Electrocuted, pets stunned all the same"] = function()
		local clap = { every = 2, seconds = 1, minFactor = 0.3, maxFactor = 1.5, warning = 1, radius = 20, debuff = "Electrocuted" }
		local state = bossFightWithPlayer(41, 1, { thunderclap = clap }, nil, { owned("p1", "1", 1e9), playerInput("1") })
		state.ringCheck = function(info: any)
			expect.equal(info.shape, "clap")
			return false -- ran out
		end
		local events = runFor(state, 2.05 + clap.warning + combat.HIT_GRACE + 0.1)
		expect.equal(firstOf(events, "debuff"), nil, "ran out")
		assert(firstOf(events, "stun"), "the pet can't run")
		local missed = nil
		for _, e in events do
			if e.type == "attack" and e.kind == "Thunderclap" then
				missed = e
			end
		end
		assert(missed and missed.to == "a:@1" and missed.dodged == true, "a miss clients show")

		local dodger = bossFightWithPlayer(41, 1, { thunderclap = clap }, nil, { owned("p1", "1", 1e9), playerInput("1") })
		runFor(dodger, 2.05 + clap.warning)
		BattleSim.dodge(dodger, "1")
		local after = runFor(dodger, combat.HIT_GRACE + 0.1)
		expect.equal(firstOf(after, "debuff"), nil, "dodged through it")
	end,

	["Electrocuted: sword and dodge stopped in each 1 s jolt, free between"] = function()
		local clap = { every = 2, seconds = 1, minFactor = 0.3, maxFactor = 1.5, warning = 1, radius = 20, debuff = "Electrocuted" }
		local state = bossFightWithPlayer(41, 1, { thunderclap = clap }, nil, { owned("p1", "1", 1e9), playerInput("1") })
		stepUntil(state, function(e)
			return e.type == "debuff" and e.kind == "Electrocuted"
		end, 10)
		state.sides.b.fighters[1].clapReady = math.huge -- one clap only
		local function stunned(): boolean
			return select(2, BattleSim.swordHit(state, "1", "b:m", 0.1, "Sword")) == "stunned"
		end
		expect.equal(stunned(), true, "the first jolt at once")
		expect.equal(select(2, BattleSim.dodge(state, "1")), "stunned", "no dodge in a jolt")
		runFor(state, 1.2)
		expect.equal(stunned(), false, "free after 1 s")
		runFor(state, 1.9) -- 3.1 s in
		expect.equal(stunned(), true, "the second jolt")
		runFor(state, 1.1) -- 4.2 s in
		expect.equal(stunned(), false)
		runFor(state, 2) -- 6.2 s in
		expect.equal(stunned(), true, "the third jolt")
		expect.equal(BattleSim.playerDebuff(state, "1"), "Electrocuted")
		runFor(state, 1)
		expect.isNil(BattleSim.playerDebuff(state, "1"), "over after 7 s")
		expect.equal(stunned(), false)
	end,

	["no big attack comes while a thunderclap winds up"] = function()
		local clap = { every = 2, seconds = 1, minFactor = 0.3, maxFactor = 1.5, warning = 1.5, radius = 20, debuff = "Electrocuted" }
		local attacks = { every = 2.5, warning = 1, big = 0.01, quick = 0, shape = "slam", debuff = "Shocked" }
		local state = bossFightWithPlayer(41, 1, { thunderclap = clap }, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		local clapAt, slamAt = nil, nil
		for _, timed in timedEvents(state, 6) do
			local e = timed.event
			if e.type == "thunderclap" and e.kind == "clap" and not clapAt then
				clapAt = timed.time
			elseif e.type == "ring" and e.kind == "slam" and not slamAt then
				slamAt = timed.time
			end
		end
		assert(clapAt and slamAt, "both came")
		assert(slamAt > clapAt, `the slam waits for the clap ({slamAt} after {clapAt})`)
	end,

	["adds: two Spawn at 70% and two more at 35%"] = function()
		local state = bossWith(ADDS, 4)
		local boss = state.sides.b.fighters[1]
		boss.hp = 6900
		local events = BattleSim.step(state, 0.1)
		expect.equal(count(events, function(e)
			return e.type == "spawn"
		end), 2, "two Spawn")
		expect.equal(#state.sides.b.fighters, 3, "boss and two Spawn")
		expect.equal(state.sides.b.fighters[2].maxHp, 600, "6% of the boss's max HP")
		boss.hp = 3400
		BattleSim.step(state, 0.1)
		expect.equal(#state.sides.b.fighters, 5, "two more")
	end,

	["adds: auto-attacks hit the Spawn first, abilities hit the boss at half damage"] = function()
		local function fireballAfter(mechanics: any): (number, string?)
			local state = bossWith(mechanics, 5, { fighter("a", "Ember", 100000, 20, 10) })
			state.sides.b.fighters[1].hp = 6900
			local _, events = runToEnd(state, 3)
			local attack = nil
			for _, event in events do
				if event.type == "attack" and event.from == "a:a" then
					attack = attack or event
				end
			end
			local used = castNow(state, "a:a", "element") :: any
			local blast = firstOf(used, "ability")
			return blast.damage, attack and attack.to
		end
		local guarded, firstTarget = fireballAfter(ADDS)
		local plain = fireballAfter({})
		expect.equal(string.sub(firstTarget or "", 1, 5), "b:add", "the first attack goes to a Spawn")
		expect.equal(math.abs(guarded - math.round(plain * 0.5)) <= 1, true, `half damage ({guarded} vs {plain})`)
	end,

	["adds: the boss falling ends the fight with Spawn alive"] = function()
		local state = bossWith(ADDS, 6, { fighter("a", "Ember", 100000, 20, 10) })
		state.sides.b.fighters[1].hp = 6900
		BattleSim.step(state, 0.1)
		state.sides.b.fighters[1].hp = 1
		castNow(state, "a:a", "element")
		expect.equal(state.result, "a", "the boss is down: win")
	end,

	["group: Healing Rain heals only its owner's creatures"] = function()
		local state = BattleSim.new(combat, {
			fighters = { { id = "p1", element = "Tide", hp = 1000, atk = 1, spd = 1, owner = "1" }, { id = "p2", element = "Ember", hp = 1000, atk = 1, spd = 1, owner = "2" } },
			abilities = true,
			canRun = true,
		}, { fighters = { monster("Bloom", 100000, 1, 1) }, abilities = false, canRun = false }, 1)
		state.sides.a.fighters[1].hp = 500
		state.sides.a.fighters[2].hp = 500
		castNow(state, "a:p1", "element", "1")
		local healed = { ["a:p1"] = 0, ["a:p2"] = 0 }
		for _, entry in timedEvents(state, 6) do
			if entry.event.type == "regen" then
				healed[entry.event.to] = (healed[entry.event.to] or 0) + entry.event.heal
			end
		end
		expect.equal(healed["a:p1"], 250, "the Tide owner's creature is healed 25% over time")
		expect.equal(healed["a:p2"], 0, "the other player's is not")
	end,

	["boss swings: a boss with 2 swings hits two different creatures per attack"] = function()
		local state = BattleSim.new(combat, {
			fighters = { owned("p1", "1", 100000), owned("p2", "2", 100000), owned("p3", "3", 100000) },
			abilities = false,
			canRun = true,
		}, { fighters = { { id = "m", element = "Bloom", hp = 100000, atk = 10, spd = 10, boss = true, swings = 2 } }, abilities = false, canRun = false }, 11)
		local _, events = runToEnd(state, 3)
		local count = 0
		for _, event in events do
			if event.type == "attack" and event.from == "b:m" then
				count += 1
			end
		end
		-- the boss attacks once per interval; with 2 swings each attack lands on 2 targets
		expect.equal(count >= 2 and count % 2 == 0, true, `hits come in pairs ({count})`)
		local targets = {}
		for _, event in events do
			if event.type == "attack" and event.from == "b:m" then
				targets[event.to] = (targets[event.to] or 0) + 1
			end
		end
		local distinct = 0
		for _ in targets do
			distinct += 1
		end
		expect.equal(distinct >= 2, true, "spread over different creatures")
	end,

	["swap: a reserve comes in and the hurt one goes back with its HP"] = function()
		local state = swapFight(1, 1)
		runToEnd(state, combat.CALL_IN_SECONDS + 1)
		state.sides.a.fighters[1].hp = 100
		local events = BattleSim.swap(state, "a:r1", "1")
		expect.equal(events and events[1].type, "swap", "a swap event")
		expect.equal(events and events[1].to, "a:p1", "the leader went out")
		local field, bench = ids(state.sides.a.fighters), ids(state.sides.a.reserves)
		expect.equal(field["a:r1"] ~= nil and field["a:p1"] == nil, true, "r1 in, p1 out")
		expect.equal(bench["a:p1"] and bench["a:p1"].hp, 100, "p1 waits with its HP")
	end,

	["swap: a cooldown between swaps"] = function()
		local state = swapFight(2, 1)
		runToEnd(state, combat.CALL_IN_SECONDS + 1)
		BattleSim.swap(state, "a:r1", "1")
		local events, reason = BattleSim.swap(state, "a:p1", "1")
		expect.isNil(events, "refused")
		expect.equal(reason, "cooldown", "reason")
		runToEnd(state, 10.5)
		expect.equal(BattleSim.swap(state, "a:p1", "1") ~= nil, true, "fine after the cooldown")
	end,

	["swap: in the call-in window it adds a second creature instead"] = function()
		local state = swapFight(3, 1)
		local events = BattleSim.swap(state, "a:r1", "1")
		expect.equal(events and events[1].type, "callin", "a call-in")
		expect.equal(#state.sides.a.fighters, 2, "both on the field")
	end,

	["swap: when all yours faint the healthiest reserve comes in by itself"] = function()
		local state = swapFight(4, 1)
		runToEnd(state, combat.CALL_IN_SECONDS + 1)
		state.sides.a.fighters[1].hp = 1
		state.sides.a.fighters[1].dodgeUntil = 0
		state.sides.b.fighters[1].atk = 50
		local _, events = runToEnd(state, 3)
		expect.isNil(state.result, "the fight goes on")
		local swap = nil
		for _, event in events do
			if event.type == "swap" then
				swap = swap or event
			end
		end
		expect.equal(swap and swap.from, "a:r1", "the healthiest reserve (500 HP over 300)")
		expect.equal(swap and swap.to, "a:p1", "it takes the fainted one's place")
		expect.equal(table.find(BattleSim.getFainted(state, "a"), "p1") ~= nil, true, "the fainted one still rests afterwards")
	end,

	["swap: the fight is lost only when nobody can come in"] = function()
		local state = swapFight(5, 400)
		local result = runToEnd(state, 60)
		expect.equal(result, "b", "all three fainted")
		expect.equal(#BattleSim.getFainted(state, "a"), 3, "every one of them")
	end,

	["swap: not in fights without swaps, and only your own"] = function()
		local plain = group(9)
		runToEnd(plain, combat.CALL_IN_SECONDS + 1)
		local _, reason = BattleSim.swap(plain, "a:r1", "1")
		expect.equal(reason, "none", "wild and PvP have no swaps")
		local state = swapFight(6, 1)
		runToEnd(state, combat.CALL_IN_SECONDS + 1)
		local _, other = BattleSim.swap(state, "a:r1", "2")
		expect.equal(other, "missing", "someone else's reserve")
	end,

	["strong party beats a weak monster"] = function()
		local state = wild(fighter("a", "Ember", 200, 30, 15), {}, monster("Bloom", 100, 2, 5), 1)
		local result, events = runToEnd(state)
		expect.equal(result, "a", "result")
		assert(count(events, function(e)
			return e.type == "end" and e.result == "a"
		end) == 1, "one end event")
	end,

	["weak party loses and faints"] = function()
		local state = wild(fighter("a", "Bloom", 30, 2, 5), {}, monster("Ember", 900, 20, 12), 2)
		local result, events = runToEnd(state)
		expect.equal(result, "b", "result")
		assert(count(events, function(e)
			return e.type == "faint" and e.to == "a:a"
		end) == 1, "leader fainted")
	end,

	["same seed, same fight"] = function()
		local function play(seed: number): string
			local state = wild(fighter("a", "Tide", 120, 12, 10), {}, monster("Volt", 300, 8, 10), seed)
			local _, events = runToEnd(state)
			local parts = {}
			for _, e in events do
				table.insert(parts, `{e.type}:{e.damage or 0}`)
			end
			return table.concat(parts, ",")
		end
		expect.equal(play(7), play(7), "deterministic")
	end,

	["element multiplier applies to attacks"] = function()
		local strong = wild(fighter("a", "Ember", 500, 20, 10), {}, monster("Bloom", 5000, 1, 1), 3)
		local weak = wild(fighter("a", "Bloom", 500, 20, 10), {}, monster("Ember", 5000, 1, 1), 3)
		local _, se = runToEnd(strong, 10)
		local _, we = runToEnd(weak, 10)
		local function firstHit(events: { any }): any
			for _, e in events do
				if e.type == "attack" and e.from == "a:a" then
					return e
				end
			end
			return nil
		end
		local s, w = firstHit(se), firstHit(we)
		expect.equal(s.strength, "strong", "strong tag")
		expect.equal(w.strength, "weak", "weak tag")
		assert(s.damage > w.damage * 1.7, `strong {s.damage} vs weak {w.damage}`)
	end,

	["call in: only within the window, only once, only a reserve"] = function()
		local state = wild(fighter("a", "Ember", 100, 10, 10), { fighter("b", "Tide", 100, 10, 10), fighter("c", "Volt", 100, 10, 10) }, monster("Shade", 5000, 1, 1), 4)
		expect.equal((BattleSim.callIn(state, "zzz")), false, "not a reserve")
		expect.equal((BattleSim.callIn(state, "a:b")), true, "first call-in")
		expect.equal((BattleSim.callIn(state, "a:c")), false, "only one")
		local late = wild(fighter("a", "Ember", 100, 10, 10), { fighter("b", "Tide", 100, 10, 10) }, monster("Shade", 5000, 1, 1), 4)
		for _ = 1, combat.CALL_IN_SECONDS * 10 + 1 do
			BattleSim.step(late, 0.1)
		end
		expect.equal((BattleSim.callIn(late, "a:b")), false, "window closed")
	end,

	-- A Pet button move or super move winds up first (owner 2026-11-04): everyone sees it coming
	-- The defeat screen's numbers (owner 2026-11-04): what each of the player's fighters dealt
	["damageBy: each of an owner's fighters' damage, its sword under its player id, swapped-out ones too"] = function()
		local state = bossFightWithPlayer(25, 1, nil, { every = 1000, warning = 1, big = 0, quick = 0 }, { owned("p1", "1", 1e9), playerInput("1") })
		runFor(state, 4)
		BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword")
		local dealt = BattleSim.damageBy(state, "1")
		expect.equal((dealt["a:p1"] or 0) > 0, true, "the creature's attacks")
		expect.equal((dealt["a:@1"] or 0) > 0, true, "the sword's hits")
		expect.equal(next(BattleSim.damageBy(state, "2")), nil, "nobody else's")
	end,

	["a special move winds up first: a cast now, the move after the wind-up"] = function()
		local state = wild(fighter("a", "Ember", 100, 10, 10), {}, monster("Volt", 5000, 1, 1), 5)
		local events = BattleSim.useAbility(state, "a:a", "element") :: { any }
		expect.equal(#events, 1)
		expect.equal(events[1].type, "cast")
		expect.equal(events[1].from, "a:a")
		expect.equal(events[1].kind, "Fireball")
		expect.equal(events[1].seconds, combat.ABILITY_WINDUP)
		local early = BattleSim.step(state, combat.ABILITY_WINDUP - 0.1)
		for _, e in early do
			expect.equal(e.type == "ability", false, "not before the wind-up")
		end
		local fired = false
		for _ = 1, 3 do
			for _, e in BattleSim.step(state, 0.1) do
				fired = fired or (e.type == "ability" and e.kind == "Fireball" and e.from == "a:a")
			end
		end
		expect.equal(fired, true, "fires when the wind-up ends")
		local _, why = BattleSim.useAbility(state, "a:a", "element")
		expect.equal(why, "cooldown", "the cooldown started at the press")
	end,

	["a second press during the wind-up is refused, and a caster that faints never fires"] = function()
		local state = wild(fighter("a", "Ember", 100, 10, 10), {}, monster("Volt", 5000, 1, 1), 5)
		charge(state)
		BattleSim.useAbility(state, "a:a", "signature")
		BattleSim.useAbility(state, "a:a", "element")
		local _, why = BattleSim.useAbility(state, "a:a", "element")
		expect.equal(why, "cooldown")
		local fainting = wild(fighter("a", "Ember", 1, 10, 10), {}, monster("Volt", 5000, 500, 40), 5)
		local pressed = BattleSim.useAbility(fainting, "a:a", "element") :: { any }
		expect.equal(pressed[1].type, "cast", "the press only starts the wind-up")
		fainting.sides.a.fighters[1].fainted = true -- knocked out mid wind-up
		local fired = false
		for _ = 1, 20 do
			for _, e in BattleSim.step(fainting, 0.1) do
				fired = fired or (e.type == "ability" and e.from == "a:a")
			end
		end
		expect.equal(fired, false, "fainted during the wind-up")
	end,

	["abilities: cooldown, Fireball hits hard, Healing Rain heals"] = function()
		local state = wild(fighter("a", "Ember", 100, 10, 10), { fighter("b", "Tide", 100, 10, 10) }, monster("Volt", 5000, 30, 10), 5)
		BattleSim.callIn(state, "a:b")
		local events = castNow(state, "a:a", "element") :: { any }
		assert(events and events[1].damage >= 22, "Fireball ~2.5x ATK")
		local again, reason = BattleSim.useAbility(state, "a:a", "element")
		expect.isNil(again, "cooldown")
		expect.equal(reason, "cooldown", "reason")
		for _ = 1, 30 do
			BattleSim.step(state, 0.1)
		end
		local rainEvents = castNow(state, "a:b", "element") :: { any }
		expect.equal(rainEvents and rainEvents[1].kind, "Rain", "Healing Rain lands")
		expect.isNil(rainEvents and rainEvents[1].heal, "no heal at once")
		local ticked = false
		for _ = 1, 11 do
			for _, e in BattleSim.step(state, 0.1) do
				ticked = ticked or (e.type == "regen" and (e.heal or 0) > 0)
			end
		end
		expect.equal(ticked, true, "Healing Rain heals a second later")
		charge(state)
		local none, why = BattleSim.useAbility(state, "a:a", "signature")
		expect.isNil(none, "no signature")
		expect.equal(why, "none", "reason none")
	end,

	["Curse weakens and Vine Snare slows the monster"] = function()
		local function monsterDamageIn(element: string, seconds: number): number
			local state = wild(fighter("a", element, 100000, 1, 10), {}, monster("Tide", 100000, 50, 10), 6)
			BattleSim.useAbility(state, "a:a", "element")
			local total = 0
			for _ = 1, seconds * 10 do
				for _, e in BattleSim.step(state, 0.1) do
					if e.type == "attack" and e.from == "b:m" then
						total += e.damage
					end
				end
			end
			return total
		end
		local plain = monsterDamageIn("Ember", 4) -- Fireball: no effect on the monster
		assert(monsterDamageIn("Shade", 4) < plain, "Curse")
		assert(monsterDamageIn("Bloom", 4) < plain, "Snare")
	end,

	-- Overcharge's orbs (owner 2026-11-05: "3 electric orbs, while active each attack cost one"): the fast attacks carry
	-- how many orbs are left after them, so clients spend one each
	["Overcharge: its three fast attacks each spend an orb"] = function()
		local state = wild(fighter("a", "Volt", 100000, 10, 10), {}, monster("Tide", 1e6, 1, 1), 31)
		castNow(state, "a:a", "element")
		local orbs = {}
		for _, e in runFor(state, 6) do
			if e.type == "attack" and e.from == "a:a" then
				table.insert(orbs, e.orb or -1)
			end
		end
		expect.equal(orbs[1], 2, "first fast attack: 2 left")
		expect.equal(orbs[2], 1, "second: 1 left")
		expect.equal(orbs[3], 0, "third: none left")
		expect.equal(orbs[4], -1, "the next normal attack spends nothing")
	end,

	["Overcharge: a fast attack missed while stunned fizzles its orb"] = function()
		local state = wild(fighter("a", "Volt", 100000, 10, 10), {}, monster("Tide", 1e6, 1, 1), 32)
		castNow(state, "a:a", "element")
		state.sides.a.fighters[1].stunUntil = state.time + 1.2 -- through the first fast attack
		local fizzled: any = nil
		local orbs = {}
		for _, e in runFor(state, 6) do
			if e.type == "orbs" and e.from == "a:a" then
				fizzled = e
			elseif e.type == "attack" and e.from == "a:a" then
				table.insert(orbs, e.orb or -1)
			end
		end
		expect.equal(fizzled and fizzled.left, 2, "the stunned slot's orb fizzles, 2 left")
		expect.equal(orbs[1], 1, "then 1 left")
		expect.equal(orbs[2], 0, "then none")
		expect.equal(orbs[3], -1, "a normal attack after")
	end,

	["Stampede stun skips monster attacks; Eclipse dodges"] = function()
		local stunned = wild(fighter("a", "Volt", 100000, 1, 10, "Thunderhorn"), {}, monster("Tide", 100000, 50, 20), 7)
		charge(stunned)
		BattleSim.useAbility(stunned, "a:a", "signature")
		BattleSim.step(stunned, combat.SIGNATURES.Thunderhorn.windup) -- counted from its landing (supers wind up first)
		local hits = 0
		for _ = 1, 15 do
			for _, e in BattleSim.step(stunned, 0.1) do
				if e.type == "attack" and e.from == "b:m" then
					hits += 1
				end
			end
		end
		expect.equal(hits, 0, "stunned 1.5 s")

		local dodger = wild(fighter("a", "Shade", 1000, 1, 10, "Eclipse Fox"), {}, monster("Tide", 100000, 50, 20), 8)
		charge(dodger)
		BattleSim.useAbility(dodger, "a:a", "signature")
		BattleSim.step(dodger, combat.SIGNATURES["Eclipse Fox"].windup)
		local damage = 0
		for _ = 1, 25 do
			for _, e in BattleSim.step(dodger, 0.1) do
				if e.type == "attack" and e.from == "b:m" then
					damage += e.damage
				end
			end
		end
		expect.equal(damage, 0, "dodged for 2.5 s")
	end,

	-- The owner (2026-11-05): Eclipse's mirror image evades everything "for 5 seconds" (Rift Step keeps its 3 until its
	-- own rework is picked)
	["Eclipse Fox evades everything for 5 s, then gets hit again"] = function()
		expect.equal(combat.SIGNATURES["Eclipse Fox"].seconds, 5)
		local dodger = wild(fighter("a", "Shade", 1e6, 1, 10, "Eclipse Fox"), {}, monster("Tide", 100000, 50, 20), 46)
		charge(dodger)
		BattleSim.useAbility(dodger, "a:a", "signature")
		BattleSim.step(dodger, combat.SIGNATURES["Eclipse Fox"].windup)
		local during, after = 0, 0
		for _, entry in timedEvents(dodger, 7) do
			local e = entry.event
			if e.type == "attack" and e.from == "b:m" and e.damage > 0 then
				if entry.time - combat.SIGNATURES["Eclipse Fox"].windup < 4.95 then
					during += 1
				else
					after += 1
				end
			end
		end
		expect.equal(during, 0, "nothing lands for 5 s")
		expect.equal(after > 0, true, "hits land again after")
	end,

	["failed run gives the monster a free hit and waits"] = function()
		-- Very slow leader vs fast monster: run chance at the floor (20%); seed chosen so the first roll fails
		local state = wild(fighter("a", "Ember", 1000, 1, 1), {}, monster("Tide", 100000, 20, 100), 9)
		local events = BattleSim.tryRun(state, "a")
		local ran = false
		local freeHit = false
		for _, e in events do
			if e.type == "run" then
				ran = e.ok
			elseif e.type == "attack" and e.from == "b:m" then
				freeHit = true
			end
		end
		if not ran then
			assert(freeHit, "free hit on failure")
			local retry = BattleSim.tryRun(state, "a")
			expect.equal(retry[1].type, "run", "run event")
			expect.equal(retry[1].ok, false, "must wait")
			expect.equal(retry[1].kind, "wait", "wait reason")
			-- the seconds still to wait, for the fight's "Not yet" banner (owner 2026-11-09: tell me when getting away fails)
			expect.near(retry[1].left :: number, combat.RUN_RETRY_SECONDS, 1e-9, "the whole retry wait is still left")
		else
			expect.equal(state.result, "run", "ran away")
		end
	end,

	["fight times out as a run"] = function()
		local state = wild(fighter("a", "Ember", 1e9, 0, 1), {}, monster("Ember", 1e9, 0, 1), 10)
		local result = runToEnd(state, combat.MAX_FIGHT_SECONDS + 5)
		expect.equal(result, "run", "timeout")
	end,

	["Inferno burns for every second, even with uneven frames"] = function()
		local state = wild(fighter("a", "Ember", 1e6, 10, 1, "Infernox"), {}, monster("Tide", 1e6, 0, 1), 12)
		charge(state)
		BattleSim.useAbility(state, "a:a", "signature")
		local burns = 0
		local steps = { 0.033, 0.017, 0.05, 0.1, 0.25, 0.033 }
		local t = 0
		local index = 0
		while t < combat.SIGNATURES.Infernox.seconds + 2 do
			index = index % #steps + 1
			for _, e in BattleSim.step(state, steps[index]) do
				if e.type == "ability" and e.kind == "Burn" then
					burns += 1
				end
			end
			t += steps[index]
		end
		expect.equal(burns, combat.SIGNATURES.Infernox.seconds, "one burn per second")
	end,

	["Overcharge speeds up exactly the next 3 attacks"] = function()
		local spd = 10
		local normal = CombatMathInterval(spd)
		local state = wild(fighter("a", "Volt", 1e6, 1, spd), {}, monster("Tide", 1e9, 0, 1), 13)
		-- Let the first normal attack land, then overcharge; count from the moment it fires (after its wind-up)
		local times = {}
		local firedAt: number? = nil
		local t = 0
		local charged = false
		while #times < 7 and t < 60 do
			for _, e in BattleSim.step(state, 0.01) do
				if e.type == "attack" and e.from == "a:a" then
					table.insert(times, state.time)
				elseif e.type == "ability" and e.kind == "Overcharge" then
					firedAt = state.time
				end
			end
			t += 0.01
			if #times == 1 and not charged then
				charged = true
				BattleSim.useAbility(state, "a:a", "element")
			end
		end
		assert(firedAt, "it fired")
		local fast = 0
		local previous = firedAt :: number
		for _, time in times do
			if time > (firedAt :: number) then
				if time - previous < normal * 0.75 then
					fast += 1
				end
				previous = time
			end
		end
		expect.equal(fast, combat.ABILITIES.Volt.attacks, "fast attacks")
	end,

	["3v3 even parties end with a winner and replay by seed"] = function()
		local function party(prefix: string)
			return {
				fighter(prefix .. "1", "Ember", 200, 12, 10),
				fighter(prefix .. "2", "Tide", 200, 12, 10),
				fighter(prefix .. "3", "Bloom", 200, 12, 10),
			}
		end
		local function play(seed: number): (string?, string)
			local state = BattleSim.new(combat, side(party("x")), side(party("y")), seed)
			local result, events = runToEnd(state)
			local parts = {}
			for _, e in events do
				table.insert(parts, `{e.type}:{e.from or ""}>{e.to or ""}:{e.damage or 0}`)
			end
			return result, table.concat(parts, ",")
		end
		local result, log = play(21)
		assert(result == "a" or result == "b", `winner, got {result}`)
		local _, again = play(21)
		expect.equal(again, log, "deterministic")
	end,

	-- The owner (2026-11-05): Healing Rain heals 25% over time, not at once
	["Healing Rain heals 25% over 5 ticks, one a second, only its own side"] = function()
		local state = BattleSim.new(combat, side({ fighter("t", "Tide", 1000, 1, 1), fighter("x", "Ember", 1000, 1, 1) }), side({ fighter("e", "Volt", 1e6, 0, 1) }), 22)
		state.sides.a.fighters[2].hp = 500
		state.sides.b.fighters[1].hp = 500
		castNow(state, "a:t", "element")
		expect.equal(BattleSim.getFighter(state, "a:x").hp, 500, "nothing at once")
		local ticks = {}
		local enemyHealed = false
		for _, entry in timedEvents(state, 6) do
			if entry.event.type == "regen" and entry.event.to == "a:x" then
				table.insert(ticks, entry)
			end
			enemyHealed = enemyHealed or (entry.event.type == "regen" and entry.event.to == "b:e")
		end
		expect.equal(#ticks, 5, "five ticks")
		expect.equal(ticks[1].event.heal, 50, "5% of 1000 a tick")
		expect.equal(ticks[1].event.from, "a:t", "from the caster")
		expect.near(ticks[1].time - 0.5, 1, 0.11, "the first a second after it lands")
		expect.near(ticks[2].time - ticks[1].time, 1, 0.11, "one a second")
		expect.equal(enemyHealed, false, "enemy not healed")
	end,

	["Healing Rain cast again restarts its ticks, never stacks"] = function()
		local state = BattleSim.new(combat, side({ fighter("t", "Tide", 1000, 0, 1) }), side({ fighter("e", "Volt", 1e6, 0, 1) }), 24)
		state.sides.a.fighters[1].hp = 100
		castNow(state, "a:t", "element")
		timedEvents(state, 2.5)
		state.sides.a.fighters[1].abilityReady = 0
		BattleSim.useAbility(state, "a:t", "element")
		local after, landed = 0, false
		for _, entry in timedEvents(state, 8) do
			if entry.event.type == "ability" and entry.event.kind == "Rain" then
				landed = true
			elseif landed and entry.event.type == "regen" then
				after += 1
				expect.equal(entry.event.heal, 50, "each tick 5%")
			end
		end
		expect.equal(landed, true, "the second Rain lands")
		expect.equal(after, 5, "five fresh ticks after the recast, not more")
	end,

	["Healing Rain stops when its creature is swapped out or faints"] = function()
		local leader: any = owned("p1", "1", 1000)
		leader.element = "Tide"
		local state = BattleSim.new(combat, {
			fighters = { leader },
			reserves = { owned("r1", "1", 1000) },
			abilities = true,
			canRun = true,
			swapSeconds = 10,
			callIn = false,
		}, { fighters = { monster("Bloom", 1e6, 0, 1) }, abilities = false, canRun = false }, 25)
		state.sides.a.fighters[1].hp = 100
		castNow(state, "a:p1", "element", "1")
		local before = 0
		for _, entry in timedEvents(state, 2.05) do
			if entry.event.type == "regen" and entry.event.to == "a:p1" then
				before += 1
			end
		end
		expect.equal(before, 2, "two ticks before the swap")
		BattleSim.swap(state, "a:r1", "1")
		local afterSwap = 0
		for _, entry in timedEvents(state, 12) do
			if entry.event.type == "regen" and entry.event.to == "a:p1" then
				afterSwap += 1
			end
		end
		state.sides.a.swapReadyAt["1"] = 0
		BattleSim.swap(state, "a:p1", "1")
		for _, entry in timedEvents(state, 6) do
			if entry.event.type == "regen" and entry.event.to == "a:p1" then
				afterSwap += 1
			end
		end
		expect.equal(afterSwap, 0, "no ticks once swapped out, nor after coming back")

		local fainting = BattleSim.new(combat, side({ fighter("t", "Tide", 1000, 0, 1) }), side({ fighter("e", "Volt", 1e6, 0, 1) }), 26)
		castNow(fainting, "a:t", "element")
		fainting.sides.a.fighters[1].hp = 1
		fainting.sides.a.fighters[1].fainted = true
		local ticksAfterFaint = 0
		for _, entry in timedEvents(fainting, 6) do
			if entry.event.type == "regen" then
				ticksAfterFaint += 1
			end
		end
		expect.equal(ticksAfterFaint, 0, "a fainted creature gets no ticks")
	end,

	["Curse hits the enemy the fighter targets"] = function()
		local function damageBy(cursed: boolean): (number, number)
			local state = BattleSim.new(combat, side({ fighter("s", "Shade", 1e6, 1, 1) }), side({ fighter("weak", "Tide", 1000, 40, 10), fighter("full", "Tide", 1000, 40, 10) }), 23)
			state.sides.b.fighters[1].hp = 100 -- lowest HP share: the target
			if cursed then
				BattleSim.useAbility(state, "a:s", "element")
			end
			local fromWeak, fromFull = 0, 0
			for _ = 1, 30 do
				for _, e in BattleSim.step(state, 0.1) do
					if e.type == "attack" and e.from == "b:weak" then
						fromWeak += e.damage
					elseif e.type == "attack" and e.from == "b:full" then
						fromFull += e.damage
					end
				end
			end
			return fromWeak, fromFull
		end
		local plainWeak, plainFull = damageBy(false)
		local cursedWeak, cursedFull = damageBy(true)
		assert(cursedWeak < plainWeak, `target weakened: {cursedWeak} vs {plainWeak}`)
		expect.equal(cursedFull, plainFull, "other enemy unchanged")
	end,

	["timeout is a draw when neither side can run"] = function()
		local state = BattleSim.new(combat, side({ fighter("a", "Ember", 1e9, 0, 1) }), side({ fighter("b", "Ember", 1e9, 0, 1) }), 24)
		local result = runToEnd(state, combat.MAX_FIGHT_SECONDS + 5)
		expect.equal(result, "draw", "draw")
	end,

	["forfeit ends the fight for the other side"] = function()
		local state = BattleSim.new(combat, side({ fighter("a", "Ember", 100, 10, 10) }), side({ fighter("b", "Tide", 100, 10, 10) }), 25)
		local events = BattleSim.forfeit(state, "a")
		expect.equal(state.result, "b", "other side wins")
		expect.equal(count(events, function(e)
			return e.type == "end"
		end), 1, "one end event")
		expect.equal(#BattleSim.step(state, 0.1), 0, "nothing after")
	end,

	["nothing happens after the end"] = function()
		local state = wild(fighter("a", "Ember", 200, 30, 15), {}, monster("Bloom", 10, 1, 1), 11)
		runToEnd(state)
		expect.equal(#BattleSim.step(state, 0.1), 0, "no events")
		local none, reason = BattleSim.useAbility(state, "a:a", "element")
		expect.isNil(none, "no ability")
		expect.equal(reason, "ended", "reason")
	end,
	["a boss heals once under half HP, then waits its cooldown"] = function()
		local boss = monster("Bloom", 1000, 1, 1)
		boss.mechanics = { heal = { below = 0.5, fraction = 0.15, cooldown = 12 } }
		boss.boss = true
		local state = wild(fighter("x", "Ember", 100000, 1, 1), {}, boss, 7)
		local bossFighter = state.sides.b.fighters[1]
		local function heals(seconds: number): { any }
			local found = {}
			local t = 0
			while t < seconds - 1e-9 do
				for _, event in BattleSim.step(state, 0.1) do
					if event.type == "heal" then
						table.insert(found, event)
					end
				end
				t += 0.1
			end
			return found
		end
		expect.equal(#heals(1), 0, "no heal above half HP")
		bossFighter.hp = 400
		local first = heals(0.1)
		expect.equal(#first, 1, "heals once under half")
		expect.equal(first[1].heal, 150, "15% of max HP")
		expect.equal(bossFighter.hp, 550, "healed")
		bossFighter.hp = 400
		expect.equal(#heals(5), 0, "waits its cooldown")
		expect.equal(#heals(8), 1, "heals again after 12 s")
	end,

	["a boss enrages once under half HP and hits harder"] = function()
		local boss = monster("Ember", 1000, 20, 30)
		boss.mechanics = { enrage = { below = 0.5, atkMultiplier = 1.5 } }
		boss.boss = true
		local state = wild(fighter("x", "Ember", 100000, 1, 1), {}, boss, 7)
		local bossFighter = state.sides.b.fighters[1]
		local before = bossFighter.atk
		local enrages = 0
		local function run(seconds: number)
			local t = 0
			while t < seconds - 1e-9 do
				for _, event in BattleSim.step(state, 0.1) do
					if event.type == "enrage" then
						enrages += 1
					end
				end
				t += 0.1
			end
		end
		run(1)
		expect.equal(enrages, 0, "calm above half HP")
		bossFighter.hp = 400
		run(3)
		expect.equal(enrages, 1, "enrages once")
		expect.near(bossFighter.atk, before * 1.5, 1e-9, "ATK x1.5")
	end,

	["fighters without mechanics never heal or enrage"] = function()
		local state = wild(fighter("x", "Ember", 300, 30, 15), {}, monster("Bloom", 400, 8, 8), 3)
		local _, events = runToEnd(state)
		for _, event in events do
			assert(event.type ~= "heal" and event.type ~= "enrage", "a plain monster used a boss mechanic")
		end
	end,
	["a fight can be given a longer time limit, like a boss's"] = function()
		local state = wild(fighter("x", "Ember", 100000, 1, 1), {}, monster("Bloom", 100000, 1, 1), 5)
		state.maxSeconds = combat.MAX_FIGHT_SECONDS + 60
		runToEnd(state, combat.MAX_FIGHT_SECONDS + 10)
		expect.isNil(state.result, "still going past the usual limit")
		runToEnd(state, 120)
		expect.equal(state.result, "run", "ends at its own limit")
	end,

	["group: each owner calls in one reserve of their own"] = function()
		local state = group(3)
		expect.equal((BattleSim.callIn(state, "a:r2", "1")), false, "not your reserve")
		expect.equal((BattleSim.callIn(state, "a:r1", "1")), true, "your reserve")
		expect.equal((BattleSim.callIn(state, "a:r1b", "1")), false, "one call-in each")
		expect.equal((BattleSim.callIn(state, "a:r2", "2")), true, "the other player still can")
	end,

	["group: abilities only on your own fighters"] = function()
		local state = group(4)
		local events, why = BattleSim.useAbility(state, "a:p2", "element", "1")
		expect.isNil(events, "someone else's fighter")
		expect.equal(why, "missing", "reason")
		expect.equal(BattleSim.useAbility(state, "a:p2", "element", "2") ~= nil, true, "your own fighter")
	end,

	["group: a player leaving takes only their fighters out"] = function()
		local state = group(5)
		BattleSim.withdraw(state, "1")
		local _, events = runToEnd(state, 10)
		local p1 = BattleSim.getFighter(state, "a:p1") :: any
		expect.equal(p1.fainted, false, "left, not fainted")
		expect.equal(count(events, function(e)
			return e.to == "a:p1"
		end), 0, "never targeted after leaving")
		expect.isNil(state.result, "the other player fights on")
		BattleSim.withdraw(state, "2")
		expect.equal(state.result, "run", "nobody left: the fight ends")
	end,

	["group: damage dealt and taken are tallied per owner"] = function()
		local state = group(6)
		runToEnd(state, 5)
		local one, two = BattleSim.contribution(state, "1"), BattleSim.contribution(state, "2")
		expect.equal(one.totalDealt > 0 and one.totalTaken > 0, true, "something happened")
		expect.equal(one.dealt + two.dealt, one.totalDealt, "dealt adds up")
		expect.equal(one.taken + two.taken, one.totalTaken, "taken adds up")
	end,

	["group: the last one leaving while the others fainted is a loss, not a run"] = function()
		local state = group(7)
		state.sides.a.fighters[2].fainted = true -- p2 (getFighter hands back a copy)
		BattleSim.withdraw(state, "1")
		expect.equal(state.result, "b", "a fainted member stayed: the side lost")
	end,

	["group: a player who left drops out of the loot shares"] = function()
		local state = group(8)
		runToEnd(state, 5)
		BattleSim.withdraw(state, "2")
		local one = BattleSim.contribution(state, "1")
		expect.equal(one.totalDealt, one.dealt, "only those still in count toward the total dealt")
		expect.equal(one.totalTaken, one.taken, "only those still in count toward the total taken")
	end,
	-- The player fighter (Task 3 of the you-in-the-fight plan)
	["boss auto-attacks never pick the player"] = function()
		local state = bossFightWithPlayer(1, 30)
		local events = runFor(state, 20)
		expect.equal(count(events, function(e)
			return e.type == "attack" and e.to == "a:@1"
		end), 0)
		expect.equal(viewOf(state, "a:@1").player, true)
	end,

	["no call-in when callIn is false"] = function()
		local state = bossFightWithPlayer(2, 1)
		expect.equal(BattleSim.callIn(state, "a:r1", "1"), false)
		local events = BattleSim.swap(state, "a:r1", "1") :: { any }
		expect.equal(events[1].type, "swap", "a swap, never a call-in")
		expect.equal(events[1].to, "a:p1", "the creature goes out, never the player")
	end,

	["sword hits use the creature's ATK and count as the player's damage"] = function()
		local state = bossFightWithPlayer(3, 1)
		local events = BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword") :: { any }
		expect.equal(events[1].type, "attack")
		expect.equal(events[1].kind, "Sword")
		expect.equal(events[1].from, "a:@1")
		expect.near(events[1].damage, 10, 1.01) -- owned() ATK 20 x 0.5, +-10% spread, no element
		expect.equal(BattleSim.contribution(state, "1").dealt, events[1].damage)
		local _, why = BattleSim.swordHit(state, "1", "b:nobody", 0.5, "Sword")
		expect.equal(why, "target")
		local _, missing = BattleSim.swordHit(state, "9", "b:m", 0.5, "Sword")
		expect.equal(missing, "missing")
	end,

	["a down player gets up at half HP while a creature stands"] = function()
		local state = bossFightWithPlayer(4, 1)
		local events = BattleSim._hurtPlayer(state, "a:@1", 100)
		expect.equal(count(events, function(e)
			return e.type == "down" and e.to == "a:@1"
		end), 1)
		expect.equal(viewOf(state, "a:@1").down, true)
		expect.near(viewOf(state, "a:@1").downIn, 5, 1e-9)
		local _, why = BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword")
		expect.equal(why, "down", "no sword while down")
		local later = runFor(state, 5.1)
		local view = viewOf(state, "a:@1")
		expect.equal(view.down, false)
		expect.equal(view.hp, 50)
		expect.equal(count(later, function(e)
			return e.type == "getUp" and e.to == "a:@1"
		end), 1)
	end,

	["down with no creature left ends the fight"] = function()
		local state = bossFightWithPlayer(5, 100000) -- each creature faints on the boss's first hit on it
		BattleSim._hurtPlayer(state, "a:@1", 100)
		runFor(state, 6) -- p1 faints at 2 s, r1 swaps in and faints at 4 s: nobody standing
		expect.equal(state.result, "b")
	end,

	["a player alone keeps fighting"] = function()
		local state = bossFightWithPlayer(6, 100000)
		runFor(state, 6)
		expect.isNil(state.result)
		expect.equal(viewOf(state, "a:@1").down, false)
	end,

	["a player out in a group stays out while the others fight on"] = function()
		local state = bossFightWithPlayer(7, 50, nil, nil, { owned("p1", "1", 1), playerInput("1"), owned("p2", "2", 1000000), playerInput("2") }, {})
		BattleSim._hurtPlayer(state, "a:@1", 100)
		local events = runFor(state, 7)
		expect.isNil(state.result)
		expect.equal(count(events, function(e)
			return e.type == "out" and e.to == "a:@1"
		end), 1)
		expect.equal(viewOf(state, "a:@1").out, true)
		expect.equal(viewOf(state, "a:@1").down, true)
	end,

	["withdraw takes the player fighter out too"] = function()
		local state = bossFightWithPlayer(8, 1, nil, nil, { owned("p1", "1"), playerInput("1"), owned("p2", "2"), playerInput("2") }, {})
		local events = BattleSim.withdraw(state, "1")
		expect.equal(count(events, function(e)
			return e.type == "leave" and e.from == "a:@1"
		end), 1)
		expect.equal(viewOf(state, "a:@1").left, true)
		expect.isNil(state.result)
	end,

	["hpLeft and getFainted ignore the player"] = function()
		local state = bossFightWithPlayer(9, 100000, nil, nil, nil, {})
		BattleSim._hurtPlayer(state, "a:@1", 100)
		runFor(state, 2.1)
		expect.isNil(BattleSim.hpLeft(state, "a", "1")["@1"])
		local fainted = BattleSim.getFainted(state, "a")
		expect.equal(#fainted, 1)
		expect.equal(fainted[1], "p1")
	end,

	["dodge has a cooldown and fails while down"] = function()
		local state = bossFightWithPlayer(10, 1)
		local events = BattleSim.dodge(state, "1") :: { any }
		expect.equal(events[1].type, "dodge")
		expect.equal(events[1].from, "a:@1")
		local _, again = BattleSim.dodge(state, "1")
		expect.equal(again, "cooldown")
		runFor(state, 2.3)
		local _, early = BattleSim.dodge(state, "1")
		expect.equal(early, "cooldown", "still waiting at 2.3 s (owner 2026-11-04: a 2.5 s cooldown, so mashing Shift stops working)")
		runFor(state, 0.3)
		expect.equal(BattleSim.dodge(state, "1") ~= nil, true, "ready again after the cooldown")
		BattleSim._hurtPlayer(state, "a:@1", 100)
		runFor(state, combat.DODGE_COOLDOWN + 0.1)
		local _, down = BattleSim.dodge(state, "1")
		expect.equal(down, "down")
	end,

	-- The owner (2026-11-05): "S healing rain also heal player": a Grade S caster's rain heals its owner's player too,
	-- 15% over the same ticks; lower grades leave the player alone, and never another player
	["Grade S Healing Rain also heals its owner's player 15% over its ticks"] = function()
		local function playerHealed(grade: string?, owner: string): number
			local tide: any = fighter("p1", "Tide", 500, 20, 10)
			tide.owner = owner
			tide.grade = grade
			local state = bossFightWithPlayer(14, 1, nil, nil, { tide, playerInput("1"), playerInput("2") })
			BattleSim._hurtPlayer(state, "a:@1", 30)
			BattleSim._hurtPlayer(state, "a:@2", 30)
			castNow(state, "a:p1", "element", owner)
			local healed = { ["a:@1"] = 0, ["a:@2"] = 0 }
			for _, e in runFor(state, 6) do
				if e.type == "regen" and healed[e.to] then
					healed[e.to] += e.heal
				end
			end
			expect.equal(healed["a:@2"], 0, "never another player")
			return healed["a:@1"]
		end
		expect.equal(playerHealed("S", "1"), 15, "Grade S: 15% of the player's 100 HP")
		expect.equal(playerHealed("A", "1"), 0, "Grade A: creatures only")
		expect.equal(playerHealed(nil, "1"), 0, "no grade: creatures only")
	end,

	["thunderclap, Healing Rain and Tidal Shield leave the player alone"] = function()
		local clap = bossFightWithPlayer(11, 1, { thunderclap = { every = 2, seconds = 1, minFactor = 0.3, maxFactor = 1.5 } })
		local events = runFor(clap, 5)
		expect.equal(count(events, function(e)
			return e.type == "stun" and e.to == "a:@1"
		end), 0)
		expect.equal(count(events, function(e)
			return e.type == "stun"
		end) > 0, true, "the creature is still stunned")

		local tide: any = fighter("p1", "Tide", 500, 20, 10)
		tide.owner = "1"
		local wave = bossFightWithPlayer(12, 1, nil, nil, { tide, playerInput("1") })
		BattleSim._hurtPlayer(wave, "a:@1", 30)
		BattleSim.useAbility(wave, "a:p1", "element", "1")
		local playerTicks = 0
		for _, e in runFor(wave, 6) do
			if e.type == "regen" and e.to == "a:@1" then
				playerTicks += 1
			end
		end
		expect.equal(playerTicks, 0, "Healing Rain heals creatures only")

		local shielded = bossFightWithPlayer(13, 1)
		shielded.sides.a.shield = 1000
		BattleSim._hurtPlayer(shielded, "a:@1", 30)
		expect.equal(viewOf(shielded, "a:@1").hp, 70, "the side's shield doesn't cover the player")
		expect.equal(shielded.sides.a.shield, 1000)
	end,
	-- Boss attacks on players (Task 4 of the you-in-the-fight plan)
	["while a creature stands, a boss's normal hits all go at creatures"] = function()
		local state = bossFightWithPlayer(21, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0.001 }, { owned("p1", "1", 1e9), playerInput("1") })
		local events = runFor(state, 600)
		expect.equal(count(events, function(e)
			return e.type == "telegraph" and e.to == "a:@1"
		end), 0, "no normal hit at the player")
		assert(count(events, function(e)
			return e.type == "attack" and e.from == "b:m" and e.to == "a:p1"
		end) > 20, "the creature takes them")
	end,

	["a boss with player attacks swings BOSS_PACE times slower, so pets take the hits they took before"] = function()
		expect.near(combat.BOSS_PACE, 1 / (1 - 1 / 3), 1e-9, "one in three swings used to go at the player")
		local function swings(playerAttacks: any?): number
			local state = bossFightWithPlayer(21, 1, nil, playerAttacks, { owned("p1", "1", 1e9), playerInput("1") })
			return count(runFor(state, 60), function(e)
				return e.type == "attack" and e.from == "b:m"
			end)
		end
		local paced = swings({ every = 1e9, warning = 1, big = 0, quick = 0 })
		local plain = swings(nil)
		expect.near(plain / paced, combat.BOSS_PACE, 0.15)
	end,

	["with no creature standing, the boss's normal hits go at the player"] = function()
		local state = bossFightWithPlayer(28, 100, nil, { every = 1e9, warning = 1, big = 0, quick = 0.001 }, { owned("p1", "1", 1), playerInput("1") }, {})
		local events = runFor(state, 30)
		assert(count(events, function(e)
			return e.type == "telegraph" and e.to == "a:@1"
		end) > 3, "the player is the target now")
	end,

	-- The Frost Tyrant's ice spikes (the owner 2026-11-10): a warned spike over each player and one random pet; a hit
	-- freezes a player (Frozen: no walking, sword or dodge) and a pet (stunned petFreeze seconds)
	["a spike attack also falls on a pet, freezing it"] = function()
		local attacks = { every = 3, warning = 1, big = 0.1, quick = 0, shape = "spikes", debuff = "Frozen", pets = 1, petFreeze = 2 }
		local state = bossFightWithPlayer(31, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		local events = runFor(state, 3.1)
		local onPet, onPlayer = nil, nil
		for _, e in events do
			if e.type == "ring" and e.to == "a:p1" then
				onPet = e
			elseif e.type == "ring" and e.to == "a:@1" then
				onPlayer = e
			end
		end
		assert(onPet and onPlayer, "a spike over the player and one over the pet")
		expect.equal(onPet.kind, "spikes")
		local landed = runFor(state, attacks.warning + combat.HIT_GRACE + 0.2)
		local frozen = firstOf(landed, "frozen")
		assert(frozen, "the pet freezes")
		expect.equal(frozen.to, "a:p1")
		expect.equal(frozen.seconds, 2)
		local pet = state.sides.a.fighters[1]
		assert(pet.stunUntil - state.time > 1.5, "it can't attack while frozen")
		local debuff = firstOf(landed, "debuff")
		assert(debuff and debuff.kind == "Frozen" and debuff.to == "a:@1", "the player is frozen too")
	end,

	["a pet can't step out of its spike"] = function()
		local attacks = { every = 3, warning = 1, big = 0.1, quick = 0, shape = "spikes", debuff = "Frozen", pets = 1, petFreeze = 2 }
		local state = bossFightWithPlayer(31, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		state.ringCheck = function()
			return false -- every player stepped out
		end
		local events = runFor(state, 3.1 + attacks.warning + combat.HIT_GRACE + 0.2)
		assert(firstOf(events, "frozen"), "the pet is frozen all the same")
		expect.equal(firstOf(events, "debuff"), nil, "the player stepped out")
	end,

	["Frozen stops the sword and the dodge"] = function()
		local attacks = { every = 3, warning = 1, big = 0.01, quick = 0, shape = "spikes", debuff = "Frozen" }
		local state = bossFightWithPlayer(31, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		stepUntil(state, function(e)
			return e.type == "debuff" and e.kind == "Frozen"
		end, 10)
		local _, sword = BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword")
		expect.equal(sword, "stunned")
		local _, dodge = BattleSim.dodge(state, "1")
		expect.equal(dodge, "stunned")
		runFor(state, Bosses.DEBUFFS.Frozen.seconds + 0.2)
		expect.equal(select(2, BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword")), nil, "free again")
	end,

	["the Frost Tyrant's big attack is ice spikes that freeze"] = function()
		local attacks = Bosses.BOSSES.frostTyrant.playerAttacks
		expect.equal(attacks.shape, "spikes")
		expect.equal(attacks.debuff, "Frozen")
		expect.equal(attacks.pets, 1)
		expect.equal(attacks.petFreeze, 2)
		local frozen = Bosses.DEBUFFS.Frozen
		expect.equal(frozen.seconds, 1.5)
		expect.equal(frozen.slow, 1, "no walking")
		expect.equal(frozen.stun, true)
		expect.equal(Bosses.DEBUFFS.Shocked.stun, true, "Shocked stuns as before")
	end,

	["a quick hit lands after the warning and grace"] = function()
		local state = bossFightWithPlayer(22, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0.1 }, { owned("p1", "1", 1e9), playerInput("1") }, nil, mixedCombat)
		local warned = stepUntil(state, function(e)
			return e.type == "telegraph" and e.to == "a:@1"
		end, 60) :: number
		local landed = stepUntil(state, function(e)
			return e.type == "attack" and e.kind == "Quick" and e.to == "a:@1"
		end, 5) :: number
		expect.near(landed - warned, combat.QUICK_WARNING + combat.HIT_GRACE, 0.1)
		expect.equal(viewOf(state, "a:@1").hp, 90)
	end,

	["a dodge inside the grace still avoids the hit"] = function()
		local state = bossFightWithPlayer(23, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0.1 }, { owned("p1", "1", 1e9), playerInput("1") }, nil, mixedCombat)
		local warned = stepUntil(state, function(e)
			return e.type == "telegraph" and e.to == "a:@1"
		end, 60) :: number
		while state.time < warned + combat.QUICK_WARNING + 0.05 do
			BattleSim.step(state, 0.1)
		end
		expect.equal(BattleSim.dodge(state, "1") ~= nil, true)
		local dodged = false
		for _, event in runFor(state, 0.5) do
			if event.type == "attack" and event.kind == "Quick" and event.to == "a:@1" then
				dodged = event.dodged == true
			end
		end
		expect.equal(dodged, true)
		expect.equal(viewOf(state, "a:@1").hp, 100)
	end,

	["a dodge 0.2 s into the warning avoids the hit (its dash covers the moment the hit shows)"] = function()
		local state = bossFightWithPlayer(23, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0.1 }, { owned("p1", "1", 1e9), playerInput("1") }, nil, mixedCombat)
		local warned = stepUntil(state, function(e)
			return e.type == "telegraph" and e.to == "a:@1"
		end, 60) :: number
		while state.time < warned + 0.2 - 1e-9 do
			BattleSim.step(state, 0.1)
		end
		expect.equal(BattleSim.dodge(state, "1") ~= nil, true)
		local dodged = false
		for _, event in runFor(state, 0.8) do
			if event.type == "attack" and event.kind == "Quick" and event.to == "a:@1" then
				dodged = event.dodged == true
			end
		end
		expect.equal(dodged, true)
	end,

	["a dodge whose dash ends well before the hit shows doesn't count"] = function()
		local state = bossFightWithPlayer(23, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0.1 }, { owned("p1", "1", 1e9), playerInput("1") }, nil, mixedCombat)
		stepUntil(state, function(e)
			return e.type == "telegraph" and e.to == "a:@1"
		end, 60)
		expect.equal(BattleSim.dodge(state, "1") ~= nil, true)
		local dodged = nil
		for _, event in runFor(state, 0.8) do
			if event.type == "attack" and event.kind == "Quick" and event.to == "a:@1" then
				dodged = event.dodged == true
			end
		end
		expect.equal(dodged, false)
	end,

	["a dodge a second after the last is accepted whatever the step phase"] = function()
		local state = bossFightWithPlayer(23, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0 }, { owned("p1", "1", 1e9), playerInput("1") })
		runFor(state, 7)
		expect.equal(BattleSim.dodge(state, "1") ~= nil, true)
		-- The next request arrives a real second later, but the server's last step can be one tick behind it
		local start = state.time
		while state.time < start + combat.DODGE_COOLDOWN - 1 / combat.TICK_RATE - 1e-9 do
			BattleSim.step(state, 0.1)
		end
		local events, why = BattleSim.dodge(state, "1")
		expect.equal(events ~= nil, true, `one tick early still counts ({why}, at {state.time - start})`)
	end,

	["big attacks come every interval with one ring per up player"] = function()
		local attacks = { every = 10, warning = 1, big = 0.01, quick = 0 }
		local state = bossFightWithPlayer(24, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1"), owned("p2", "2", 1e9), playerInput("2") }, {})
		local function rings(events: { any }): number
			return count(events, function(e)
				return e.type == "ring"
			end)
		end
		expect.equal(rings(runFor(state, 9.8)), 0, "nothing before the first interval")
		local first = runFor(state, 0.5)
		expect.equal(rings(first), 2, "one ring per player")
		expect.equal(count(first, function(e)
			return e.type == "ring" and e.to == "a:@1"
		end), 1)
		expect.equal(rings(runFor(state, 10)), 2, "again one interval later")
	end,

	["ringCheck false means the ring misses"] = function()
		local attacks = { every = 2, warning = 1, big = 0.5, quick = 0 }
		local missed = bossFightWithPlayer(25, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		missed.ringCheck = function()
			return false
		end
		local events = runFor(missed, 3.4)
		expect.equal(count(events, function(e)
			return (e.kind == "Slam" or e.kind == "Swipe") and e.dodged == true
		end), 1)
		expect.equal(viewOf(missed, "a:@1").hp, 100)

		local hit = bossFightWithPlayer(25, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		runFor(hit, 3.4)
		expect.equal(viewOf(hit, "a:@1").hp, 50, "no ringCheck: always inside")
	end,

	["the Hydra's double chance adds a second ring sometimes"] = function()
		local attacks = { every = 1, warning = 0.5, big = 0, quick = 0, doubleChance = 0.35 }
		local state = bossFightWithPlayer(26, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1"), owned("p2", "2", 1e9), playerInput("2") }, {})
		state.maxSeconds = 3000 -- enough attacks for a steady share (the default limit ends it at 120 s)
		local twos, threes = 0, 0
		for _ = 1, 20000 do
			local n = count(BattleSim.step(state, 0.1), function(e)
				return e.type == "ring"
			end)
			if n == 2 then
				twos += 1
			elseif n == 3 then
				threes += 1
			end
		end
		expect.equal(twos > 0 and threes > 0, true, `{twos} attacks of 2 rings, {threes} of 3`)
		local share = threes / (twos + threes)
		expect.equal(share > 0.2 and share < 0.5, true, `double share {share}`)
	end,

	["pending hits never land after the end"] = function()
		local state = bossFightWithPlayer(27, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0.5 }, { owned("p1", "1", 1e9), playerInput("1") }, nil, mixedCombat)
		state.sides.b.fighters[1].hp = 1
		stepUntil(state, function(e)
			return e.type == "telegraph" and e.to == "a:@1"
		end, 60)
		BattleSim.swordHit(state, "1", "b:m", 1, "Sword")
		expect.equal(state.result, "a")
		local events = runFor(state, 2)
		expect.equal(count(events, function(e)
			return e.to == "a:@1"
		end), 0)
		expect.equal(viewOf(state, "a:@1").hp, 100)
	end,

	["every swing goes at players when no creature stands"] = function()
		local state = bossFightWithPlayer(28, 100, nil, { every = 1e9, warning = 1, big = 0, quick = 0.001 }, { owned("p1", "1", 1), playerInput("1") }, {})
		stepUntil(state, function(e)
			return e.type == "faint" and e.to == "a:p1"
		end, 10)
		local events = runFor(state, 20)
		expect.equal(count(events, function(e)
			return e.type == "attack" and e.from == "b:m" and e.to ~= "a:@1"
		end), 0)
		expect.equal(count(events, function(e)
			return e.type == "telegraph"
		end) >= 5, true, "a swing every 3 s (BOSS_PACE) all at the player")
		expect.isNil(state.result, "the player fights on alone")
	end,

	["a boss without playerAttacks never rings"] = function()
		local state = bossFightWithPlayer(29, 1)
		local events = runFor(state, 30)
		expect.equal(count(events, function(e)
			return e.type == "ring" or e.type == "telegraph"
		end), 0)
	end,

	-- Fight perks (Config/Party FIGHT_PERKS): the creature fighting for an owner gives its perk to it and its player
	["Hype: the sword and the creature hit harder"] = function()
		local plain = bossFightWithPlayer(3, 1)
		local hyped = bossFightWithPlayer(3, 1, nil, nil, { perked("Hype", 0.5), playerInput("1") })
		local a = (BattleSim.swordHit(plain, "1", "b:m", 0.5, "Sword") :: { any })[1].damage
		local b = (BattleSim.swordHit(hyped, "1", "b:m", 0.5, "Sword") :: { any })[1].damage
		expect.near(b, a * 1.5, 1)
		local function firstCreatureHit(state: any): number
			for _ = 1, 100 do
				for _, e in BattleSim.step(state, 0.1) do
					if e.type == "attack" and e.from == "a:p1" then
						return e.damage
					end
				end
			end
			return -1
		end
		expect.near(firstCreatureHit(hyped), firstCreatureHit(plain) * 1.5, 1.01)
	end,

	["Calm: you and your creature take less damage"] = function()
		local quick = { every = 1e9, warning = 1, big = 0, quick = 0.1 }
		local creature = perked("Calm", 0.5)
		creature.hp = 1e9
		local state = bossFightWithPlayer(22, 1, nil, quick, { creature, playerInput("1") }, nil, mixedCombat)
		stepUntil(state, function(e)
			return e.type == "attack" and e.kind == "Quick" and e.to == "a:@1"
		end, 60)
		expect.equal(viewOf(state, "a:@1").hp, 95, "a 10 HP quick hit lands as 5")
		local function firstHitOnCreature(input: any): number
			local fight = bossFightWithPlayer(5, 50, nil, nil, { input, playerInput("1") })
			for _ = 1, 200 do
				for _, e in BattleSim.step(fight, 0.1) do
					if e.type == "attack" and e.to == "a:p1" and not e.kind then
						return e.damage
					end
				end
			end
			return -1
		end
		expect.near(firstHitOnCreature(perked("Calm", 0.5)), firstHitOnCreature(owned("p1", "1")) * 0.5, 1.01)
	end,

	["Haggle: a crit doubles the damage and says so"] = function()
		local plain = bossFightWithPlayer(3, 1)
		local lucky = bossFightWithPlayer(3, 1, nil, nil, { perked("Haggle", 1), playerInput("1") })
		local a = (BattleSim.swordHit(plain, "1", "b:m", 0.5, "Sword") :: { any })[1]
		local b = (BattleSim.swordHit(lucky, "1", "b:m", 0.5, "Sword") :: { any })[1]
		expect.near(b.damage, a.damage * 2, 1)
		expect.equal(b.crit, true)
		expect.isNil(a.crit, "no perk, no crit")
	end,

	["Hustle: the creature attacks faster"] = function()
		local function attacks(input: any): number
			local state = bossFightWithPlayer(7, 0, nil, nil, { input, playerInput("1") })
			return count(runFor(state, 20), function(e)
				return e.type == "attack" and e.from == "a:p1"
			end)
		end
		local plain, fast = attacks(owned("p1", "1")), attacks(perked("Hustle", 1))
		expect.equal(fast >= plain * 2 - 1 and fast <= plain * 2 + 1, true, `{plain} -> {fast}`)
	end,

	["Express: the creature's ability recharges faster"] = function()
		local state = bossFightWithPlayer(9, 0, nil, nil, { perked("Express", 0.5), playerInput("1") })
		BattleSim.useAbility(state, "a:p1", "element", "1")
		expect.near(viewOf(state, "a:p1").abilityIn, combat.ABILITY_COOLDOWN * 0.5, 0.01)
	end,

	["the player's perk is their creature on the field's"] = function()
		local state = bossFightWithPlayer(11, 0, nil, nil, { perked("Express", 0.3), playerInput("1") })
		expect.near(BattleSim.perkOf(state, "1", "Express"), 0.3, 1e-9)
		expect.equal(BattleSim.perkOf(state, "1", "Hype"), 0, "another kind")
		expect.equal(BattleSim.perkOf(state, "9", "Express"), 0, "nobody")
		BattleSim.swap(state, "a:r1", "1")
		expect.equal(BattleSim.perkOf(state, "1", "Express"), 0, "the reserve swapped in has none")
	end,

	-- Charges (attack animations spec): a charge event a moment before each auto-attack, changing nothing else
	["every auto-attack is charged first, once"] = function()
		local state = wild(fighter("a", "Ember", 100000, 10, 10), {}, monster("Bloom", 100000, 1, 10), 41)
		local timed = timedEvents(state, 20)
		local lastCharge: { [string]: number } = {}
		local attacks = 0
		for _, entry in timed do
			local e = entry.event
			if e.type == "charge" then
				expect.equal(lastCharge[e.from], nil, `{e.from} charged twice before attacking`)
				lastCharge[e.from] = entry.time
			elseif e.type == "attack" and not e.kind and e.from then
				local at = lastCharge[e.from]
				expect.equal(at ~= nil, true, `{e.from} attacked uncharged at {entry.time}`)
				expect.equal(entry.time - (at :: number) <= combat.CHARGE_LEAD + 0.1 + 1e-6, true, "charged too early")
				lastCharge[e.from] = nil
				attacks += 1
			end
		end
		expect.equal(attacks > 10, true, "both sides attacked")
	end,

	["charges change nothing: same results and damage as with charges off"] = function()
		local function run(cfg: any): { string }
			local state = BattleSim.new(cfg, side({ fighter("a", "Ember", 400, 30, 12) }), side({ monster("Tide", 400, 25, 9) }), 77)
			local _, events = runToEnd(state, 120)
			local list = {}
			for _, e in events do
				if e.type ~= "charge" then
					table.insert(list, `{e.type}|{e.from}|{e.to}|{e.damage}|{e.result}`)
				end
			end
			return list
		end
		local off = table.clone(combat) :: any
		off.CHARGE_LEAD = nil
		local with, without = run(combat), run(off)
		expect.equal(#with, #without)
		expect.equal(table.concat(with, ";"), table.concat(without, ";"))
	end,

	["overcharge's short gaps still charge, with the time left"] = function()
		local state = wild(fighter("a", "Volt", 100000, 10, 31), {}, monster("Shade", 100000, 1, 10), 42) -- 1 s apart, 0.5 overcharged
		runFor(state, 1)
		BattleSim.useAbility(state, "a:a", "element")
		local timed = timedEvents(state, 4)
		local charges, attacks = 0, 0
		for _, entry in timed do
			local e = entry.event
			if e.from == "a:a" and e.type == "charge" then
				charges += 1
				expect.equal(e.seconds >= 0 and e.seconds <= combat.CHARGE_LEAD + 1e-9, true, `seconds {e.seconds}`)
			elseif e.from == "a:a" and e.type == "attack" and not e.kind then
				attacks += 1
			end
		end
		expect.equal(attacks >= 5, true, `overcharged attacks: {attacks}`)
		expect.equal(math.abs(charges - attacks) <= 1, true, `{charges} charges for {attacks} attacks`)
	end,

	["a charge is always followed by its attack (a stunned fighter isn't charged)"] = function()
		local state = wild(fighter("a", "Ember", 100000, 10, 10), {}, monster("Bloom", 100000, 1, 10), 43)
		state.sides.a.fighters[1].stunUntil = 5
		local timed = timedEvents(state, 12)
		for index, entry in timed do
			local e = entry.event
			if e.type == "charge" and e.from == "a:a" and entry.time + e.seconds + 0.15 <= 12 then -- its attack is in the window
				local found = false
				for later = index + 1, #timed do
					local next = timed[later]
					if next.time > entry.time + e.seconds + 0.15 then
						break
					end
					if next.event.type == "attack" and next.event.from == "a:a" and not next.event.kind then
						found = true
						break
					end
				end
				expect.equal(found, true, `orphan charge at {entry.time}`)
			end
		end
	end,

	-- One ring shape per boss (attack animations spec)
	["a boss's rings all take its shape"] = function()
		local attacks = { every = 3, warning = 1, big = 0.05, quick = 0.02, shape = "swipe" }
		local state = bossFightWithPlayer(31, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		local events = runFor(state, 30)
		local rings = 0
		for _, e in events do
			if e.type == "ring" then
				rings += 1
				expect.equal(e.kind, "swipe")
			end
		end
		expect.equal(rings >= 5, true, `rings {rings}`)
	end,

	["a fixed shape draws the same randoms"] = function()
		local function run(shape: string?): string
			local attacks = { every = 3, warning = 1, big = 0.05, quick = 0.02, shape = shape }
			local state = bossFightWithPlayer(32, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
			local list = {}
			for _, e in runFor(state, 30) do
				local kind = if e.type == "ring" or e.kind == "Slam" or e.kind == "Swipe" then "ring" else tostring(e.kind)
				table.insert(list, `{e.type}|{kind}|{e.from}|{e.to}|{e.damage}`)
			end
			return table.concat(list, ";")
		end
		expect.equal(run("slam"), run(nil))
		expect.equal(run("swipe"), run(nil))
	end,

	-- Boss debuffs (spec 2026-11-02-attack-animations-design): a ring hit leaves the boss's debuff on the player
	["a ring hit gives the boss's debuff, a miss doesn't"] = function()
		local attacks = { every = 2, warning = 1, big = 0.1, quick = 0, debuff = "Poison" }
		local hit = bossFightWithPlayer(25, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		local debuff = firstOf(runFor(hit, 3.4), "debuff")
		assert(debuff, "a debuff event")
		expect.equal(debuff.kind, "Poison")
		expect.equal(debuff.to, "a:@1")
		expect.equal(debuff.seconds, Bosses.DEBUFFS.Poison.seconds)

		local missed = bossFightWithPlayer(25, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		missed.ringCheck = function()
			return false
		end
		expect.equal(firstOf(runFor(missed, 3.4), "debuff"), nil, "stepped out of the ring")

		local quick = bossFightWithPlayer(25, 1, nil, { every = 1000, warning = 1, big = 0, quick = 0.05, debuff = "Poison" }, { owned("p1", "1", 1e9), playerInput("1") }, nil, mixedCombat)
		local events = runFor(quick, 20)
		expect.equal(count(events, function(e)
			return e.kind == "Quick" and not e.dodged
		end) > 0, true, "quick hits landed")
		expect.equal(firstOf(events, "debuff"), nil, "quick hits never debuff")
	end,

	["a swipe ring gives its debuff like a slam"] = function()
		for _, shape in { "swipe", "slam" } do
			local attacks = { every = 2, warning = 1, big = 0.1, quick = 0, shape = shape, debuff = "Poison" }
			local state = bossFightWithPlayer(25, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
			local debuff = firstOf(runFor(state, 3.4), "debuff")
			expect.equal(debuff ~= nil and debuff.kind, "Poison", shape)
		end
	end,

	["poison ticks then ends"] = function()
		local attacks = { every = 2, warning = 1, big = 0.1, quick = 0, debuff = "Poison" }
		local state = bossFightWithPlayer(25, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		runFor(state, 3.4)
		state.sides.b.fighters[1].bigReady = math.huge -- just the one ring
		local events = runFor(state, 6)
		local ticks = count(events, function(e)
			return e.type == "attack" and e.kind == "Poison" and e.to == "a:@1"
		end)
		expect.equal(ticks, Bosses.DEBUFFS.Poison.seconds, "one a second")
		local each = math.max(1, math.round(Bosses.DEBUFFS.Poison.perSecond * combat.PLAYER_HP))
		expect.equal(viewOf(state, "a:@1").hp, combat.PLAYER_HP - 10 - ticks * each)
	end,

	["a new hit refreshes, doesn't stack"] = function()
		local attacks = { every = 2, warning = 1, big = 0.05, quick = 0, debuff = "Burn" }
		local state = bossFightWithPlayer(27, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		local timed = timedEvents(state, 12)
		local last = -math.huge
		local burns, debuffs = 0, 0
		for _, entry in timed do
			if entry.event.type == "attack" and entry.event.kind == "Burn" then
				burns += 1
				expect.equal(entry.time - last > 0.95, true, "at most one burn a second")
				last = entry.time
			elseif entry.event.type == "debuff" then
				debuffs += 1
			end
		end
		expect.equal(debuffs >= 4, true, "every ring hit sends it again")
		expect.equal(burns >= 7, true, "kept burning while refreshed")
	end,

	["playerDebuff says the player's debuff and its seconds left, nothing once it ends"] = function()
		local attacks = { every = 2, warning = 1, big = 0.05, quick = 0, debuff = "Entangled" }
		local state = bossFightWithPlayer(25, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		expect.isNil(BattleSim.playerDebuff(state, "1"), "none before a ring lands")
		stepUntil(state, function(e)
			return e.type == "debuff"
		end, 5)
		state.sides.b.fighters[1].bigReady = math.huge -- just the one ring
		local kind, left = BattleSim.playerDebuff(state, "1")
		expect.equal(kind, "Entangled")
		expect.near(left :: number, Bosses.DEBUFFS.Entangled.seconds, 0.15, "the full time just after it lands")
		runFor(state, 1)
		local _, later = BattleSim.playerDebuff(state, "1")
		expect.near(later :: number, Bosses.DEBUFFS.Entangled.seconds - 1, 0.15, "counts down")
		runFor(state, Bosses.DEBUFFS.Entangled.seconds)
		expect.isNil(BattleSim.playerDebuff(state, "1"), "gone once it ends")
		expect.isNil(BattleSim.playerDebuff(state, "2"), "a player not in the fight has none")
	end,

	["Shocked blocks sword and dodge for its seconds"] = function()
		local attacks = { every = 2, warning = 1, big = 0.05, quick = 0, debuff = "Shocked" }
		local state = bossFightWithPlayer(25, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		stepUntil(state, function(e)
			return e.type == "debuff"
		end, 5)
		local _, sword = BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword")
		expect.equal(sword, "stunned")
		local _, dodge = BattleSim.dodge(state, "1")
		expect.equal(dodge, "stunned")
		runFor(state, Bosses.DEBUFFS.Shocked.seconds + 0.1)
		expect.equal(BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword") ~= nil, true, "free again")
		expect.equal(BattleSim.dodge(state, "1") ~= nil, true)
	end,

	["Weakened sword hits do less"] = function()
		local function swordAfterHit(debuff: string?): number
			local attacks = { every = 2, warning = 1, big = 0.05, quick = 0, debuff = debuff }
			local state = bossFightWithPlayer(25, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
			runFor(state, 3.4)
			return (BattleSim.swordHit(state, "1", "b:m", 1, "Sword") :: { any })[1].damage
		end
		local plain, weak = swordAfterHit(nil), swordAfterHit("Weakened")
		expect.near(weak, plain * Bosses.DEBUFFS.Weakened.sword, 1)
	end,

	["Chilled slows the dodge recharge"] = function()
		local attacks = { every = 2, warning = 1, big = 0.05, quick = 0, debuff = "Chilled" }
		local state = bossFightWithPlayer(25, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		stepUntil(state, function(e)
			return e.type == "debuff"
		end, 5)
		expect.equal(BattleSim.dodge(state, "1") ~= nil, true)
		runFor(state, combat.DODGE_COOLDOWN + 0.1)
		local _, why = BattleSim.dodge(state, "1")
		expect.equal(why, "cooldown", "not ready at the usual cooldown")
		runFor(state, combat.DODGE_COOLDOWN * (Bosses.DEBUFFS.Chilled.dodgeCooldown - 1))
		expect.equal(BattleSim.dodge(state, "1") ~= nil, true, "ready after the longer one")
	end,

	["a boss with byPhase gives its current element's debuff"] = function()
		local function kindFor(element: string): string?
			local state = BattleSim.new(combat, { fighters = { owned("p1", "1", 1e9), playerInput("1") }, reserves = {}, abilities = true, canRun = true, swapSeconds = 10, callIn = false }, {
				fighters = { { id = "m", element = element, hp = 100000, atk = 1, spd = 10, boss = true, mechanics = {}, playerAttacks = { every = 2, warning = 1, big = 0.05, quick = 0, debuff = "byPhase" } } },
				abilities = false,
				canRun = false,
			}, 25)
			local debuff = firstOf(runFor(state, 3.4), "debuff")
			return if debuff then debuff.kind else nil
		end
		expect.equal(kindFor("Shade"), Bosses.DEBUFF_BY_ELEMENT.Shade)
		expect.equal(kindFor("Ember"), "Burn")
		expect.equal(kindFor("Bloom"), "Entangled")
	end,

	["going down or leaving clears it"] = function()
		local attacks = { every = 2, warning = 1, big = 0.05, quick = 0, debuff = "Poison" }
		local down = bossFightWithPlayer(25, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		runFor(down, 3.4)
		down.sides.b.fighters[1].bigReady = math.huge
		BattleSim._hurtPlayer(down, "a:@1", 1000)
		expect.equal(count(runFor(down, 4), function(e)
			return e.kind == "Poison"
		end), 0, "no poison on a downed player")

		local group = bossFightWithPlayer(25, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1"), owned("p2", "2", 1e9), playerInput("2") }, {})
		runFor(group, 3.4)
		group.sides.b.fighters[1].bigReady = math.huge
		BattleSim.withdraw(group, "1")
		expect.equal(count(runFor(group, 4), function(e)
			return e.kind == "Poison" and e.to == "a:@1"
		end), 0, "none on a player who left")
	end,

	["no debuff config: no debuff"] = function()
		local attacks = { every = 2, warning = 1, big = 0.1, quick = 0 }
		local state = bossFightWithPlayer(25, 1, nil, attacks, { owned("p1", "1", 1e9), playerInput("1") })
		expect.equal(firstOf(runFor(state, 8), "debuff"), nil)
	end,

	["every boss's debuff is known and every stun lasts at most 1 s"] = function()
		expect.equal(Bosses.DEBUFFS.Shocked.seconds <= 1, true)
		for id, boss in Bosses.BOSSES do
			local kind = boss.playerAttacks.debuff
			expect.equal(kind == "byPhase" or Bosses.DEBUFFS[kind] ~= nil, true, id)
		end
		for element, kind in Bosses.DEBUFF_BY_ELEMENT do
			expect.equal(Bosses.DEBUFFS[kind] ~= nil, true, element)
		end
		expect.equal(Bosses.BOSSES.meadowWarden.playerAttacks.debuff, "Entangled")
		expect.equal(Bosses.BOSSES.prismHydra.playerAttacks.debuff, "byPhase")
	end,
	["a fast attacker charges for part of its gap, not the whole lead"] = function()
		local state = wild(fighter("a", "Volt", 100000, 10, 69), {}, monster("Shade", 100000, 1, 10), 44)
		local gap = CombatMathInterval(69)
		local charges = 0
		for _, entry in timedEvents(state, 6) do
			local e = entry.event
			if e.from == "a:a" and e.type == "charge" then
				charges += 1
				expect.equal(e.seconds <= gap * combat.CHARGE_SHARE + 0.1 + 1e-9, true, `seconds {e.seconds} for a {gap} s gap`)
			end
		end
		expect.equal(charges >= 8, true, `charges {charges}`)
	end,
	["creaturesDecide: the side loses once its creatures faint, even with its player up"] = function()
		local function play(decide: boolean?): string?
			local state = BattleSim.new(combat, {
				fighters = { owned("p1", "1", 20), playerInput("1") },
				abilities = false,
				canRun = false,
				creaturesDecide = decide,
			}, { fighters = { monster("Bloom", 100000, 50, 10) }, abilities = false, canRun = false }, 5)
			runFor(state, 10)
			return state.result
		end
		expect.equal(play(true), "b", "lost when the creature fainted")
		expect.equal(play(nil), nil, "a boss fight goes on with the player up")
	end,
	-- Super moves (spec 2026-11-05-super-moves-design): their own wind-up, the caster's player protected while their
	-- camera is away, a fizzle when the caster faints, no swapping it out mid wind-up
	["a super winds up its own time and lands at the end"] = function()
		local state = wild(fighter("a", "Ember", 1e6, 10, 1, "Infernox"), {}, monster("Tide", 1e6, 0, 1), 12)
		charge(state)
		local pressed = BattleSim.useAbility(state, "a:a", "signature") :: { any }
		expect.equal(pressed[1].type, "cast")
		expect.equal(pressed[1].look, "Inferno")
		expect.near(pressed[1].seconds, 1.5, 1e-9)
		expect.near(pressed[1].protect, 1.5 + combat.SUPER_PROTECT_TAIL, 1e-9)
		expect.equal(state.sides.a.meters[""], 0, "the press empties the meter")
		runFor(state, 1.4)
		expect.equal(raw(state, "b:m").burnUntil, 0, "not landed during the wind-up")
		runFor(state, 0.2)
		expect.equal(raw(state, "b:m").burnUntil > 0, true, "landed at the end")
	end,

	["a Legendary super winds up 2 s and its landing carries its look"] = function()
		local state = wild(fighter("a", "Volt", 1e6, 10, 1, "Stormking"), {}, monster("Bloom", 1e6, 0, 1), 13)
		charge(state)
		local pressed = BattleSim.useAbility(state, "a:a", "signature") :: { any }
		expect.near(pressed[1].seconds, 2, 1e-9)
		local landed = nil
		for _, entry in timedEvents(state, 2.5) do
			if entry.event.type == "ability" and entry.event.kind == "Supernova" then
				landed = entry
			end
		end
		assert(landed, "the 4x hit landed")
		expect.equal(landed.time >= 1.9 and landed.time <= 2.1 + 1e-9, true, `landed at {landed.time}`)
		expect.equal(landed.event.look, "Thunderstorm")
	end,

	["the caster's player can't be hit until control returns"] = function()
		local caster = owned("p1", "1", 1e9)
		caster.signature = "Infernox"
		local state = bossFightWithPlayer(31, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0 }, { caster, playerInput("1") })
		local player, boss = raw(state, "a:@1"), raw(state, "b:m")
		local start = state.time
		charge(state)
		BattleSim.useAbility(state, "a:p1", "signature", "1")
		table.insert(state.pending, { kind = "Quick", at = start + 1.0, target = player, from = boss, damage = 10 })
		table.insert(state.pending, { kind = "Quick", at = start + 2.3, target = player, from = boss, damage = 10 })
		local dodged, landed = 0, 0
		for _, e in runFor(state, 2.6) do
			if e.type == "attack" and e.kind == "Quick" and e.to == "a:@1" then
				if e.dodged then
					dodged += 1
				else
					landed += 1
				end
			end
		end
		expect.equal(dodged, 1, "the hit due inside the window misses")
		expect.equal(landed, 1, "the hit due after it (1.5 + 0.6 s) lands")
		expect.equal(viewOf(state, "a:@1").hp, combat.PLAYER_HP - 10)
	end,

	["no new quick hits or rings at the caster's player while protected"] = function()
		local caster = owned("p1", "1", 1e9)
		caster.signature = "Infernox"
		local state = bossFightWithPlayer(32, 1, nil, { every = 0.4, warning = 1, big = 0.01, quick = 0.001 }, {
			caster,
			playerInput("1"),
			owned("p2", "2", 1e9),
			playerInput("2"),
		}, {})
		charge(state)
		BattleSim.useAbility(state, "a:p1", "signature", "1")
		local atCaster, atOther = 0, 0
		for _, e in runFor(state, 2.0) do
			if (e.type == "ring" or e.type == "telegraph") and e.to == "a:@1" then
				atCaster += 1
			elseif (e.type == "ring" or e.type == "telegraph") and e.to == "a:@2" then
				atOther += 1
			end
		end
		expect.equal(atCaster, 0, "nothing new aimed at the caster's player")
		expect.equal(atOther > 0, true, "the other player still gets them")
		local after = 0
		for _, e in runFor(state, 1.5) do
			if e.type == "ring" and e.to == "a:@1" then
				after += 1
			end
		end
		expect.equal(after > 0, true, "rings on the caster's player again once control is back")
	end,

	["a super whose caster faints fizzles and ends the protection"] = function()
		local caster = owned("p1", "1", 1e9)
		caster.signature = "Infernox"
		local state = bossFightWithPlayer(33, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0 }, { caster, playerInput("1") })
		charge(state)
		BattleSim.useAbility(state, "a:p1", "signature", "1")
		runFor(state, 0.5)
		raw(state, "a:p1").fainted = true -- knocked out mid wind-up
		local fizzled, fired = nil, false
		for _, e in runFor(state, 1.5) do
			if e.type == "fizzle" then
				fizzled = e
			elseif e.type == "ability" and e.kind == "Inferno" then
				fired = true
			end
		end
		assert(fizzled, "a fizzle event")
		expect.equal(fizzled.from, "a:p1")
		expect.equal(fizzled.look, "Inferno")
		expect.equal(fired, false, "never lands")
		expect.equal(raw(state, "a:@1").protectedUntil <= state.time, true, "the protection ended with it")
	end,

	["a creature winding up its super can't be swapped out"] = function()
		local caster = owned("p1", "1", 1e9)
		caster.signature = "Infernox"
		local state = bossFightWithPlayer(34, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0 }, { caster, playerInput("1") })
		charge(state)
		BattleSim.useAbility(state, "a:p1", "signature", "1")
		local none, why = BattleSim.swap(state, "a:r1", "1")
		expect.isNil(none)
		expect.equal(why, "casting")
		runFor(state, 1.6)
		local swapped = BattleSim.swap(state, "a:r1", "1")
		expect.equal(swapped ~= nil, true, "fine once it has landed")
	end,

	["pet moves still wind up 0.5 s, with no protection"] = function()
		local state = wild(fighter("a", "Ember", 1e6, 10, 1, "Infernox"), {}, monster("Tide", 1e6, 0, 1), 14)
		local pressed = BattleSim.useAbility(state, "a:a", "element") :: { any }
		expect.near(pressed[1].seconds, combat.ABILITY_WINDUP, 1e-9)
		expect.isNil(pressed[1].protect)
		expect.isNil(pressed[1].look)
	end,
	-- Tidal Shield's dome ripples with each hit it soaks and bursts when it's used up (super moves Task 7)
	["a hit the side's shield soaks says how much it absorbed"] = function()
		local state = wild(fighter("a", "Tide", 1e6, 10, 1, "Abyssal Koi"), {}, monster("Ember", 1e6, 50, 20), 41)
		castNow(state, "a:a", "signature")
		local soaked = 0
		for _, e in runFor(state, 2) do
			if e.to == "a:a" and typeof(e.absorbed) == "number" then
				soaked += e.absorbed
			end
		end
		expect.equal(soaked > 0, true, "hits report what the shield took")
	end,

	["a ward broken by hits says whose it was"] = function()
		local state = wild(fighter("a", "Tide", 1000, 10, 1, "Abyssal Koi"), {}, monster("Ember", 1e6, 200, 20), 42)
		castNow(state, "a:a", "signature")
		local gone = nil
		for _, e in runFor(state, 6) do
			if e.type == "shieldGone" then
				gone = e
			end
		end
		assert(gone, "a shieldGone event")
		expect.equal(gone.to, "a:a")
	end,
	-- The owner (2026-11-05): "Tidal Shield should give you and your whole party a shield that lasts for some time".
	-- Every ally on the caster's side gets its own ward (its share of its own max HP) for the move's seconds; before,
	-- one shared pool covered the creatures only and never ran out.
	["Tidal Shield wards every ally on its side, the player too"] = function()
		local koi: any = fighter("k", "Tide", 1e6, 10, 1, "Abyssal Koi")
		koi.owner = "1"
		local state = bossFightWithPlayer(45, 30, nil, { every = 1e9, warning = 1, big = 0, quick = 0.5 }, { koi, playerInput("1") }, nil, mixedCombat)
		local landed = castNow(state, "a:k", "signature", "1") :: { any }
		local spec = combat.SIGNATURES["Abyssal Koi"]
		local cast = landed[1]
		expect.equal(cast.kind, "TidalShield")
		expect.equal(cast.seconds, spec.seconds, "it says how long")
		local wards = {}
		for _, id in cast.shielded do
			wards[id] = true
		end
		expect.equal(wards["a:k"] and wards["a:@1"], true, "the creature and its player")
		local soaked = 0
		for _, e in runFor(state, spec.seconds - 0.5) do
			if e.to == "a:@1" and typeof(e.absorbed) == "number" then
				soaked += e.absorbed
			end
		end
		expect.equal(soaked > 0, true, "the boss's hits on the player hit its ward first")
		expect.equal(soaked <= math.round(combat.PLAYER_HP * spec.shield), true, "no more than its ward")
	end,

	["a ward runs out after its seconds, hit or not"] = function()
		local koi: any = fighter("k", "Tide", 1e6, 10, 1, "Abyssal Koi")
		koi.owner = "1"
		local state = bossFightWithPlayer(45, 0, nil, nil, { koi, playerInput("1") })
		castNow(state, "a:k", "signature", "1")
		local castAt = state.time
		local seconds = combat.SIGNATURES["Abyssal Koi"].seconds
		local gone = {}
		for _, entry in timedEvents(state, seconds + 1) do
			if entry.event.type == "shieldGone" then
				gone[entry.event.to] = entry.time - castAt
			end
		end
		for _, id in { "a:k", "a:@1" } do
			assert(gone[id], `{id}: its ward ran out`)
			expect.near(gone[id], seconds, 0.15, `{id}: after its seconds`)
		end
		BattleSim._hurtPlayer(state, "a:@1", 10)
		expect.equal(viewOf(state, "a:@1").hp, combat.PLAYER_HP - 10, "no ward left")
	end,

	["Tidal Shield's numbers: a third of each ally's HP or so, for some seconds"] = function()
		for _, card in { "Abyssal Koi" } do
			local spec = combat.SIGNATURES[card]
			expect.equal(spec.shield >= 0.2 and spec.shield <= 0.5, true, `{card}: shield share`)
			expect.equal(spec.seconds >= 5 and spec.seconds <= 10, true, `{card}: lasts a while, not always up`)
		end
	end,
	-- The owner (2026-11-05): "if Super spells are clicked, the creature should stop attacking and perform the windup"
	["a creature winding up its super doesn't auto-attack until it lands"] = function()
		local state = wild(fighter("a", "Volt", 1e6, 10, 40, "Thunderhorn"), {}, monster("Tide", 1e6, 0, 1), 43)
		runFor(state, 0.3)
		charge(state)
		BattleSim.useAbility(state, "a:a", "signature")
		local during, after = 0, 0
		for _, entry in timedEvents(state, 3) do
			local e = entry.event
			if e.type == "attack" and e.from == "a:a" then
				if entry.time < 0.3 + combat.SIGNATURES.Thunderhorn.windup then
					during += 1
				else
					after += 1
				end
			end
		end
		expect.equal(during, 0, "no auto-attacks during the wind-up")
		expect.equal(after > 0, true, "attacking again once it lands")
	end,
	-- The owner (2026-11-05, option B "Rebirth Spring"): Tidal Blessing stands its caster's fainted creatures back up
	-- at a share of their HP (once a fight) and heals the rest of its owner's party a share of theirs
	["Tidal Blessing revives its owner's fainted creatures into the reserves and heals the rest"] = function()
		local spec = combat.SIGNATURES["Tideborne Kirin"]
		expect.equal(spec.kind, "Rebirth")
		local kirin: any = fighter("k", "Tide", 1e6, 10, 1, "Tideborne Kirin")
		kirin.owner = "1"
		local state = bossFightWithPlayer(47, 60, nil, nil, { owned("p1", "1", 50), playerInput("1") }, { kirin })
		runFor(state, 8)
		expect.equal((BattleSim.getFighter(state, "a:p1") :: any).fainted, true, "p1 fainted first")
		BattleSim._hurtPlayer(state, "a:@1", 50)
		local landed = castNow(state, "a:k", "signature", "1") :: { any }
		local cast = landed[1]
		expect.equal(cast.kind, "Rebirth")
		expect.equal(cast.revived and cast.revived[1], "a:p1", "says who stood back up")
		expect.equal(BattleSim.hpLeft(state, "a").p1, math.round(50 * spec.revive), "standing again at its share of its HP")
		expect.equal(table.find(BattleSim.snapshot(state).sides.a.reserves, "a:p1") ~= nil, true, "back in the reserves")
		expect.equal(viewOf(state, "a:@1").hp, 50 + math.round(combat.PLAYER_HP * spec.heal), "its player healed")
		expect.equal(table.find(BattleSim.getFainted(state, "a"), "p1"), nil, "it won't rest after the fight")
	end,

	["Tidal Blessing's revive is spent once, only when it stands someone up"] = function()
		local kirin: any = fighter("k", "Tide", 1e6, 10, 1, "Tideborne Kirin")
		kirin.owner = "1"
		local state = bossFightWithPlayer(48, 60, nil, nil, { kirin, playerInput("1") }, { owned("r1", "1", 50) })
		local first = (castNow(state, "a:k", "signature", "1") :: { any })[1]
		expect.equal(first.revived, nil, "nobody to stand up: not spent")
		-- r1 comes in and faints; the second blessing stands it up
		runFor(state, 15)
		BattleSim.swap(state, "a:r1", "1")
		runFor(state, 8)
		expect.equal((BattleSim.getFighter(state, "a:r1") :: any).fainted, true, "r1 fainted")
		local second = (castNow(state, "a:k", "signature", "1") :: { any })[1]
		expect.equal(second.revived and second.revived[1], "a:r1", "stood up")
		-- once a fight: it faints again and the third blessing only heals
		runFor(state, 15)
		BattleSim.swap(state, "a:r1", "1")
		runFor(state, 8)
		expect.equal((BattleSim.getFighter(state, "a:r1") :: any).fainted, true, "r1 fainted again")
		local third = (castNow(state, "a:k", "signature", "1") :: { any })[1]
		expect.equal(third.revived, nil, "once a fight")
		expect.equal((BattleSim.getFighter(state, "a:r1") :: any).fainted, true, "still down")
	end,

	-- The owner (2026-11-05): "make sure bosses are not too easy now that we have heals". Devour's heal was half its hit
	-- with no limit (tools/balance/bosses: Voidmaw alone took the Prism Hydra's still-player wins from 68% to 100%)
	["Devour heals a share of its hit, never more than its cap of max HP"] = function()
		local spec = combat.SIGNATURES.Voidmaw
		expect.equal(spec.healCap > 0 and spec.healCap <= 0.15, true, "a modest cap")
		local state = wild(fighter("v", "Shade", 1000, 400, 1, "Voidmaw"), {}, monster("Shade", 1e6, 0, 1), 51)
		local raw = state.sides.a.fighters[1]
		raw.hp = 100
		local landed = (castNow(state, "a:v", "signature") :: { any })[1]
		expect.equal(landed.kind, "Devour")
		local healed = raw.hp - 100
		expect.equal(healed, math.min(math.round(landed.damage * spec.lifesteal), math.round(1000 * spec.healCap)), "the smaller of the two")
		expect.equal(healed <= 1000 * spec.healCap, true, "capped")
	end,

	-- The owner (2026-11-06, option A "Super meter"): supers are earned, not pressed every 15 s. One meter per player
	-- fills from the fighting; a super needs it full and empties it
	["a super needs a full meter, and the press empties it"] = function()
		local state = wild(fighter("a", "Volt", 1e6, 10, 1, "Thunderhorn"), {}, monster("Tide", 1e6, 0, 1), 60)
		expect.equal(state.sides.a.meters[""], 0, "empty at the start")
		local none, why = BattleSim.useAbility(state, "a:a", "signature")
		expect.isNil(none)
		expect.equal(why, "charging")
		state.sides.a.meters[""] = combat.SUPER_METER.full - 1
		expect.equal(select(2, BattleSim.useAbility(state, "a:a", "signature")), "charging", "one short")
		state.sides.a.meters[""] = combat.SUPER_METER.full
		expect.equal(BattleSim.useAbility(state, "a:a", "signature") ~= nil, true, "full: it goes")
		expect.equal(state.sides.a.meters[""], 0, "and the meter's empty")
		expect.equal(select(2, BattleSim.useAbility(state, "a:a", "signature")), "charging", "no second press right after")
	end,

	["the meter fills from its creature's hits and from damage taken, never past full"] = function()
		local spec = combat.SUPER_METER
		local state = wild(fighter("a", "Volt", 1000, 10, 20, "Thunderhorn"), {}, monster("Volt", 1e9, 50, 5), 61)
		local hits, hurt = 0, 0
		for _, e in runFor(state, 6) do
			if e.type == "attack" and e.from == "a:a" and not e.dodged then
				hits += 1
			elseif e.type == "attack" and e.to == "a:a" then
				hurt += e.damage
			end
		end
		expect.equal(hits > 0 and hurt > 0, true, "both happened")
		expect.near(state.sides.a.meters[""], hits * spec.hit + spec.hurt * hurt / 1000, 1e-6, "a share a hit, a share of the HP lost")
		state.sides.a.meters[""] = spec.full - 0.5
		runFor(state, 4)
		expect.equal(state.sides.a.meters[""], spec.full, "capped at full")
	end,

	["the sword's hits and dodged boss hits fill the player's meter"] = function()
		local spec = combat.SUPER_METER
		local state = bossFightWithPlayer(62, 0, nil, { every = 1e9, warning = 1, big = 0, quick = 0.5 }, nil, nil, mixedCombat)
		state.sides.a.meters["1"] = 0
		BattleSim.swordHit(state, "1", "b:m", 1, "Sword")
		expect.near(state.sides.a.meters["1"], spec.sword, 1e-6, "a sword hit")
		-- a quick hit dodged: wait for its warning, dodge, let it land
		local dodged, dodgeAt = false, nil
		for _ = 1, 400 do
			local events = BattleSim.step(state, 0.05)
			if dodgeAt and state.time >= dodgeAt then
				dodgeAt = nil
				BattleSim.dodge(state, "1")
			end
			for _, e in events do
				if e.type == "telegraph" and e.to == "a:@1" then
					dodgeAt = state.time + combat.QUICK_WARNING - 0.1 -- just before it lands, as a player would
				elseif e.type == "attack" and e.to == "a:@1" and e.dodged then
					dodged = true
				end
			end
			if dodged then
				break
			end
		end
		expect.equal(dodged, true, "a quick hit was dodged")
		expect.equal(state.sides.a.meters["1"] >= spec.sword + spec.dodge, true, "a dodge fills more than a hit")
	end,

	-- Sword skills round: Prism Judgment lands as five strikes a fifth each; together they fill the meter as one hit
	-- (spec 3: same strength as today's skill), with or without a weapon
	["a skill's split strikes fill the meter as one hit together"] = function()
		local spec = combat.SUPER_METER
		local state = bossFightWithPlayer(62, 0, nil, { every = 1e9, warning = 1, big = 0, quick = 0.5 })
		state.sides.a.meters["1"] = 0
		for _ = 1, 5 do
			BattleSim.swordHit(state, "1", "b:m", 0.2, "Skill", nil, 0.2)
		end
		expect.near(state.sides.a.meters["1"], spec.sword, 1e-6, "five fifths: one hit's meter")
		state.sides.a.meters["1"] = 0
		local weapon = { element = "Ember", prism = false, bond = 1, meter = 1.5 }
		for _ = 1, 5 do
			BattleSim.swordHit(state, "1", "b:m", 0.2, "Skill", weapon, 0.2)
		end
		expect.near(state.sides.a.meters["1"], spec.sword * 1.5, 1e-6, "with a weapon's meter bonus")
	end,

	["a skill's split strikes deal one hit's damage together (within rounding)"] = function()
		local spread = combat.DAMAGE_SPREAD
		combat.DAMAGE_SPREAD = 0
		local function lost(strikes: number): number
			local state = bossFightWithPlayer(64, 0, nil, { every = 1e9, warning = 1, big = 0, quick = 0.5 })
			local before = BattleSim.getFighter(state, "b:m").hp
			for _ = 1, strikes do
				BattleSim.swordHit(state, "1", "b:m", 1 / strikes, "Skill", nil, 1 / strikes)
			end
			return before - BattleSim.getFighter(state, "b:m").hp
		end
		local one, five = lost(1), lost(5)
		combat.DAMAGE_SPREAD = spread
		expect.equal(one > 0, true, "the skill landed")
		expect.equal(math.abs(one - five) <= 2.5, true, `one hit {one}, five fifths {five}`)
	end,

	["a super's own hits don't fill the meter"] = function()
		local state = wild(fighter("a", "Ember", 1e6, 100, 1, "Solarion"), {}, monster("Bloom", 1e6, 0, 1), 63)
		castNow(state, "a:a", "signature")
		expect.equal(state.sides.a.meters[""] < combat.SUPER_METER.hit, true, "its 4x hit added nothing (a scratch taken at most)")
	end,

	["each player in a group has their own meter, and the snapshot shows each fighter its owner's share"] = function()
		local state = group(64)
		state.sides.a.meters["1"] = combat.SUPER_METER.full / 2
		state.sides.a.meters["2"] = 0
		local shares = {}
		for _, view in BattleSim.snapshot(state).sides.a.fighters do
			shares[view.owner] = view.superMeter
		end
		expect.near(shares["1"], 0.5, 1e-9)
		expect.near(shares["2"], 0, 1e-9)
	end,

	["Express fills the meter faster"] = function()
		local spec = combat.SUPER_METER
		local quick: any = fighter("a", "Volt", 1e6, 10, 20, "Thunderhorn")
		quick.perk = { kind = "Express", value = 0.2 }
		local state = wild(quick, {}, monster("Volt", 1e9, 0, 1), 65)
		local hits, hurt = 0, 0
		for _, e in runFor(state, 4) do
			if e.type == "attack" and e.from == "a:a" and not e.dodged then
				hits += 1
			elseif e.type == "attack" and e.to == "a:a" then
				hurt += e.damage
			end
		end
		expect.equal(hits > 0, true, "it hit")
		expect.near(state.sides.a.meters[""], (hits * spec.hit + spec.hurt * hurt / 1e6) * 1.2, 1e-6, "20% more a hit")
	end,

	-- The owner (2026-11-05, option C "Blink Barrage"): Rift Step blinks round the foe for quick hits from every side
	["Rift Step lands its hits one after another, each a share of ATK"] = function()
		local spec = combat.SIGNATURES.Riftwalker
		expect.equal(spec.kind, "Barrage")
		local state = wild(fighter("r", "Shade", 1e6, 100, 1, "Riftwalker"), {}, monster("Shade", 1e6, 0, 1), 49)
		charge(state)
		BattleSim.useAbility(state, "a:r", "signature")
		local hits = {}
		for _, entry in timedEvents(state, spec.windup + spec.gap * spec.hits + 0.5) do
			local e = entry.event
			if e.type == "ability" and e.kind == "Barrage" then
				table.insert(hits, { time = entry.time, event = e })
			end
		end
		expect.equal(#hits, spec.hits, "every hit lands")
		for index, entry in hits do
			expect.equal(entry.event.blink, index, "numbered")
			expect.equal(entry.event.look, if index == 1 then "RiftStep" else nil, "the first carries the look")
			expect.equal(entry.event.damage > 0 and entry.event.damage < 100 * spec.power * 2, true, "a share of ATK")
		end
		expect.near(hits[#hits].time - hits[1].time, spec.gap * (spec.hits - 1), 0.15, "spaced by its gap")
		expect.equal(spec.hits * spec.power > 2.5 and spec.hits * spec.power < 4, true, "more than Stampede's 2x in all")
	end,

	["Rift Step's last hits stop if the caster faints"] = function()
		local spec = combat.SIGNATURES.Riftwalker
		local state = wild(fighter("r", "Shade", 1e6, 100, 1, "Riftwalker"), {}, monster("Shade", 1e6, 0, 1), 50)
		castNow(state, "a:r", "signature")
		state.sides.a.fighters[1].fainted = true
		local later = 0
		for _, e in runFor(state, spec.gap * spec.hits + 0.5) do
			if e.type == "ability" and e.kind == "Barrage" then
				later += 1
			end
		end
		expect.equal(later, 0, "no hits from a fainted caster")
	end,

	-- Weapons round 1: the equipped weapon's element, bond and perk on sword hits
	["a weapon of the strong element hits x1.5, bonded another x1.15"] = function()
		local plain = bossFightWithPlayer(3, 1)
		local strong = bossFightWithPlayer(3, 1)
		local bonded = bossFightWithPlayer(3, 1)
		local weak = bossFightWithPlayer(3, 1)
		local a = (BattleSim.swordHit(plain, "1", "b:m", 5, "Sword") :: { any })[1]
		local b = (BattleSim.swordHit(strong, "1", "b:m", 5, "Sword", { element = "Ember", prism = false, bond = 1, meter = 1 }) :: { any })[1]
		local c = (BattleSim.swordHit(bonded, "1", "b:m", 5, "Sword", { element = "Ember", prism = false, bond = 1.15, meter = 1.5 }) :: { any })[1]
		local d = (BattleSim.swordHit(weak, "1", "b:m", 5, "Sword", { element = "Tide", prism = false, bond = 1, meter = 1 }) :: { any })[1]
		expect.near(b.damage, a.damage * 1.5, 2)
		expect.equal(b.strength, "strong")
		expect.near(c.damage, a.damage * 1.5 * 1.15, 2)
		expect.near(d.damage, a.damage * 0.75, 2)
		expect.equal(d.strength, "weak")
		local start = combat.SUPER_METER.start
		local plainGain = plain.sides.a.meters["1"] - start
		expect.near(plainGain, combat.SUPER_METER.sword, 1e-9)
		expect.near(bonded.sides.a.meters["1"] - start, plainGain * 1.5, 1e-9, "a bonded weapon fills the meter faster")
	end,

	["the Prism Blade always counts as strong"] = function()
		local prism = { prism = true, bond = 1, meter = 1 }
		local plain = bossFightWithPlayer(4, 1)
		local bloom = bossFightWithPlayer(4, 1)
		local a = (BattleSim.swordHit(plain, "1", "b:m", 5, "Sword") :: { any })[1]
		local b = (BattleSim.swordHit(bloom, "1", "b:m", 5, "Sword", prism) :: { any })[1]
		expect.equal(b.strength, "strong")
		expect.near(b.damage, a.damage * 1.5, 2)
		local volt = bossFightWithPlayer(4, 1)
		raw(volt, "b:m").element = "Volt" -- a boss that changes element (a phase) is still beaten
		local c = (BattleSim.swordHit(volt, "1", "b:m", 5, "Sword", prism) :: { any })[1]
		expect.equal(c.strength, "strong")
	end,

	["Verdant Blade heals the creature 2% on every 4th hit"] = function()
		local state = bossFightWithPlayer(5, 1)
		local creature = raw(state, "a:p1")
		creature.hp = 100
		local weapon = { element = "Bloom", prism = false, bond = 1, meter = 1, perk = { kind = "heal", every = 4, share = 0.02 } }
		local heals = {}
		for i = 1, 8 do
			for _, e in BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword", weapon) :: { any } do
				if e.type == "swordHeal" then
					table.insert(heals, { at = i, event = e })
				end
			end
		end
		expect.equal(#heals, 2)
		expect.equal(heals[1].at, 4)
		expect.equal(heals[2].at, 8)
		expect.equal(heals[1].event.to, "a:p1")
		expect.equal(heals[1].event.from, "a:@1")
		expect.equal(heals[1].event.heal, 10, "2% of 500")
		expect.equal(creature.hp, 120)
	end,

	-- Weapons round 2 (spec 2026-11-07-weapons-round2-design 4): the spears' perks
	["Magma Halberd erupts on every 5th hit for 60% more"] = function()
		local state = bossFightWithPlayer(5, 1)
		local weapon = { element = "Ember", prism = false, bond = 1, meter = 1, perk = { kind = "erupt", every = 5, share = 0.6 } }
		local erupts, fifth = 0, {}
		for i = 1, 10 do
			local damage = {}
			for _, e in BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword", weapon) :: { any } do
				if e.type == "swordErupt" then
					erupts += 1
				end
				if e.damage and e.to == "b:m" then
					table.insert(damage, e.damage)
				end
			end
			if i == 5 then
				fifth = damage
			end
		end
		expect.equal(erupts, 2)
		expect.equal(#fifth, 2, "the hit and its eruption")
		expect.near(fifth[2], fifth[1] * 0.6, 2)
	end,

	["Tidal Trident chills the foe 10% for 3 s and never weakens a stronger slow"] = function()
		local state = bossFightWithPlayer(6, 1)
		local weapon = { element = "Tide", prism = false, bond = 1, meter = 1, perk = { kind = "chill", share = 0.1, seconds = 3 } }
		BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword", weapon)
		local boss = raw(state, "b:m")
		expect.near(boss.slow, 0.1, 1e-9)
		expect.near(boss.slowUntil, state.time + 3, 1e-6)
		boss.slow, boss.slowUntil = 0.3, state.time + 10 -- a Snare
		BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword", weapon)
		expect.near(boss.slow, 0.3, 1e-9, "the Snare's 30% stays")
		expect.near(boss.slowUntil, state.time + 10, 1e-6, "and its end")
	end,

	["Titan's Lance heals the creature 1% on every hit"] = function()
		local state = bossFightWithPlayer(5, 1)
		raw(state, "a:p1").hp = 100
		local weapon = { element = "Bloom", prism = false, bond = 1, meter = 1, perk = { kind = "heal", every = 1, share = 0.01 } }
		local heals = 0
		for _ = 1, 3 do
			for _, e in BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword", weapon) :: { any } do
				if e.type == "swordHeal" then
					heals += 1
					expect.equal(e.heal, 5, "1% of 500")
				end
			end
		end
		expect.equal(heals, 3)
	end,

	["Sunforged Blade's burn refreshes, never stacks"] = function()
		local state = bossFightWithPlayer(6, 1)
		local weapon = { element = "Ember", prism = false, bond = 1, meter = 1, perk = { kind = "burn", share = 0.5, seconds = 3 } }
		local all = {}
		for _, e in BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword", weapon) :: { any } do
			table.insert(all, e)
		end
		for _, e in runFor(state, 1.5) do
			table.insert(all, e)
		end
		for _, e in BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword", weapon) :: { any } do
			table.insert(all, e)
		end
		for _, e in runFor(state, 3.5) do
			table.insert(all, e)
		end
		local ticks = 0
		for _, e in all do
			if e.type == "ability" and e.kind == "Burn" and e.to == "b:m" then
				ticks += 1
				expect.equal(e.damage, 10, "half the creature's ATK of 20 a second")
			end
		end
		expect.equal(ticks, 4, "ticks at 1, 2, 3 and 4 s: the second hit pushed the end to 4.5 s")
	end,

	["the bond follows the creature fighting for the owner"] = function()
		local state = bossFightWithPlayer(8, 1)
		expect.equal(BattleSim.creatureElement(state, "1"), "Ember")
		expect.isNil(BattleSim.creatureElement(state, "9"))
	end,

	["no weapon: the same damage as before"] = function()
		local a = bossFightWithPlayer(7, 1)
		local b = bossFightWithPlayer(7, 1)
		local x = (BattleSim.swordHit(a, "1", "b:m", 0.5, "Sword") :: { any })[1]
		local y = (BattleSim.swordHit(b, "1", "b:m", 0.5, "Sword", { prism = false, bond = 1, meter = 1 }) :: { any })[1]
		expect.equal(y.damage, x.damage)
		expect.equal(y.strength, x.strength)
		expect.equal(b.sides.a.meters["1"], a.sides.a.meters["1"])
	end,

	-- Weapons round 3 (spec 2026-11-09-weapons-round3-scythes-design 4): the scythes' perks
	["Storm Reaper's every 4th hit strikes the target for 40% more, and arcs to the other foes for 30%"] = function()
		local state = BattleSim.new(combat, {
			fighters = { owned("p1", "1"), playerInput("1") },
			reserves = { owned("r1", "1") },
			abilities = true,
			canRun = true,
			swapSeconds = 10,
			callIn = false,
		}, {
			fighters = {
				{ id = "m", element = "Bloom", hp = 100000, atk = 1, spd = 10 },
				{ id = "x", element = "Bloom", hp = 100000, atk = 1, spd = 10 },
				{ id = "y", element = "Bloom", hp = 100000, atk = 1, spd = 10 },
			},
			abilities = false,
			canRun = false,
		}, 7)
		raw(state, "b:y").fainted = true
		local weapon = { element = "Volt", prism = false, bond = 1, meter = 1, perk = { kind = "chain", every = 4, share = 0.4, spread = 0.3 } }
		local chains = 0
		local function within(value: number, of: number, share: number): boolean
			return value >= of * share * 0.75 and value <= of * share * 1.3
		end
		for i = 1, 4 do
			local onTarget, onAdd, onFainted = {}, {}, 0
			for _, e in BattleSim.swordHit(state, "1", "b:m", 2, "Sword", weapon) :: { any } do
				if e.type == "swordChain" then
					chains += 1
					expect.equal(table.find(e.arcs, "b:x") ~= nil, true, "it arcs to the other foe")
					expect.isNil(table.find(e.arcs, "b:y"), "never to a fainted one")
				end
				if e.damage and e.to == "b:m" then
					table.insert(onTarget, e.damage)
				elseif e.damage and e.to == "b:x" then
					table.insert(onAdd, e.damage)
				elseif e.damage and e.to == "b:y" then
					onFainted += 1
				end
			end
			if i == 4 then
				expect.equal(#onTarget, 2, "the hit and its bolt")
				expect.equal(within(onTarget[2], onTarget[1], 0.4), true, `40% more ({onTarget[2]} after {onTarget[1]})`)
				expect.equal(#onAdd, 1, "the arc")
				expect.equal(within(onAdd[1], onTarget[1], 0.3), true, `30% to the other foe ({onAdd[1]})`)
			else
				expect.equal(#onTarget, 1, `hit {i}: plain`)
				expect.equal(#onAdd, 0)
			end
			expect.equal(onFainted, 0)
		end
		expect.equal(chains, 1)
		-- against a lone boss the bolt still lands
		local lone = bossFightWithPlayer(7, 1)
		local bolts = 0
		for _ = 1, 4 do
			local hits = 0
			for _, e in BattleSim.swordHit(lone, "1", "b:m", 2, "Sword", weapon) :: { any } do
				if e.damage and e.to == "b:m" then
					hits += 1
				end
			end
			bolts = hits
		end
		expect.equal(bolts, 2, "the 4th hit and its bolt on a lone boss")
	end,

	["Rift Reaper's hits deal 30% more to a foe under 30% of its HP, and only then"] = function()
		local weapon = { element = "Shade", prism = false, bond = 1, meter = 1, perk = { kind = "execute", below = 0.3, share = 0.3 } }
		local function strike(share: number): (number, number)
			local state = bossFightWithPlayer(9, 1)
			local boss = raw(state, "b:m")
			boss.hp = math.floor(boss.maxHp * share)
			local damage, executes = 0, 0
			for _, e in BattleSim.swordHit(state, "1", "b:m", 2, "Sword", weapon) :: { any } do
				if e.type == "swordExecute" then
					executes += 1
				end
				if e.damage and e.to == "b:m" then
					damage = e.damage
				end
			end
			return damage, executes
		end
		local above, none = strike(0.31)
		local below, one = strike(0.29)
		expect.equal(none, 0, "at 31%: plain")
		expect.equal(one, 1, "at 29%: reaped")
		expect.near(below, above * 1.3, 1, "the same roll, 30% more")
		local state = bossFightWithPlayer(9, 1)
		raw(state, "b:m").fainted = true
		local events = BattleSim.swordHit(state, "1", "b:m", 2, "Sword", weapon)
		expect.isNil(events, "a fainted foe takes no hit")
	end,

	["Widow's Reaper's venom is the burn as poison: refreshed, never stacked"] = function()
		local state = bossFightWithPlayer(6, 1)
		local weapon = { element = "Shade", prism = false, bond = 1, meter = 1, perk = { kind = "burn", share = 0.5, seconds = 3, look = "venom" } }
		local all = {}
		for _, e in BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword", weapon) :: { any } do
			table.insert(all, e)
		end
		for _, e in runFor(state, 1.5) do
			table.insert(all, e)
		end
		for _, e in BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword", weapon) :: { any } do
			table.insert(all, e)
		end
		for _, e in runFor(state, 3.5) do
			table.insert(all, e)
		end
		local ticks = 0
		for _, e in all do
			if e.type == "ability" and e.to == "b:m" and (e.kind == "Poison" or e.kind == "Burn") then
				expect.equal(e.kind, "Poison", "venom ticks as poison")
				ticks += 1
			end
		end
		expect.equal(ticks, 4, "refreshed by the second hit, never stacked")
	end,
}
