--!strict
local BattleSim = require("../src/server/Util/BattleSim")
local combat = require("../src/shared/Config/Combat")
local Bosses = require("../src/shared/Config/Bosses")
local expect = require("./lib/expect")
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

-- A special move pressed and its wind-up waited out (combat.ABILITY_WINDUP): the move's events, or nil and why not
local function castNow(state: any, id: string, which: string, owner: string?): ({ any }?, string?)
	local pressed, why = BattleSim.useAbility(state, id, which, owner)
	if not pressed then
		return nil, why
	end
	local out = {}
	for _, event in BattleSim.step(state, combat.ABILITY_WINDUP) do
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
local function bossFightWithPlayer(seed: number, foeAtk: number, mechanics: any?, playerAttacks: any?, fighters: { any }?, reserves: { any }?): any
	return BattleSim.new(combat, {
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

	["group: Wave heals only its owner's creatures"] = function()
		local state = BattleSim.new(combat, {
			fighters = { { id = "p1", element = "Tide", hp = 1000, atk = 1, spd = 1, owner = "1" }, { id = "p2", element = "Ember", hp = 1000, atk = 1, spd = 1, owner = "2" } },
			abilities = true,
			canRun = true,
		}, { fighters = { monster("Bloom", 100000, 1, 1) }, abilities = false, canRun = false }, 1)
		state.sides.a.fighters[1].hp = 500
		state.sides.a.fighters[2].hp = 500
		castNow(state, "a:p1", "element", "1")
		expect.equal(state.sides.a.fighters[1].hp, 750, "the Tide owner's creature is healed")
		expect.equal(state.sides.a.fighters[2].hp, 500, "the other player's is not")
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

	["abilities: cooldown, Fireball hits hard, Wave heals"] = function()
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
		local healEvents = castNow(state, "a:b", "element") :: { any }
		assert(healEvents and (healEvents[1].heal or 0) > 0, "Wave heals")
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

	["Stampede stun skips monster attacks; Eclipse dodges"] = function()
		local stunned = wild(fighter("a", "Volt", 100000, 1, 10, "Thunderhorn"), {}, monster("Tide", 100000, 50, 20), 7)
		BattleSim.useAbility(stunned, "a:a", "signature")
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
		BattleSim.useAbility(dodger, "a:a", "signature")
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

	["Wave heals only its own side"] = function()
		local state = BattleSim.new(combat, side({ fighter("t", "Tide", 1000, 1, 1), fighter("x", "Ember", 1000, 1, 1) }), side({ fighter("e", "Volt", 1000, 1, 1) }), 22)
		state.sides.a.fighters[2].hp = 500
		state.sides.b.fighters[1].hp = 500
		castNow(state, "a:t", "element")
		expect.equal(BattleSim.getFighter(state, "a:x").hp, 750, "ally healed 25%")
		expect.equal(BattleSim.getFighter(state, "b:e").hp, 500, "enemy not healed")
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

	["thunderclap, Wave and Tidal Shield leave the player alone"] = function()
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
		expect.equal(viewOf(wave, "a:@1").hp, 70, "Wave heals creatures only")

		local shielded = bossFightWithPlayer(13, 1)
		shielded.sides.a.shield = 1000
		BattleSim._hurtPlayer(shielded, "a:@1", 30)
		expect.equal(viewOf(shielded, "a:@1").hp, 70, "the side's shield doesn't cover the player")
		expect.equal(shielded.sides.a.shield, 1000)
	end,
	-- Boss attacks on players (Task 4 of the you-in-the-fight plan)
	["about a third of boss swings go at the player"] = function()
		local state = bossFightWithPlayer(21, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0.001 }, { owned("p1", "1", 1e9), playerInput("1") })
		local events = runFor(state, 2000)
		local atPlayer = count(events, function(e)
			return e.type == "telegraph" and e.to == "a:@1"
		end)
		local atCreature = count(events, function(e)
			return e.type == "attack" and e.from == "b:m" and e.to == "a:p1"
		end)
		local share = atPlayer / (atPlayer + atCreature)
		expect.equal(share >= 0.28 and share <= 0.39, true, `share {share}`)
		expect.equal(viewOf(state, "a:@1").hp, 100, "quick hits this small round to 0")
	end,

	["a quick hit lands after the warning and grace"] = function()
		local state = bossFightWithPlayer(22, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0.1 }, { owned("p1", "1", 1e9), playerInput("1") })
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
		local state = bossFightWithPlayer(23, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0.1 }, { owned("p1", "1", 1e9), playerInput("1") })
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
		local state = bossFightWithPlayer(23, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0.1 }, { owned("p1", "1", 1e9), playerInput("1") })
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
		local state = bossFightWithPlayer(23, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0.1 }, { owned("p1", "1", 1e9), playerInput("1") })
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
		local state = bossFightWithPlayer(27, 1, nil, { every = 1e9, warning = 1, big = 0, quick = 0.5 }, { owned("p1", "1", 1e9), playerInput("1") })
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
		end) >= 8, true)
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
		local state = bossFightWithPlayer(22, 1, nil, quick, { creature, playerInput("1") })
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

		local quick = bossFightWithPlayer(25, 1, nil, { every = 1000, warning = 1, big = 0, quick = 0.05, debuff = "Poison" }, { owned("p1", "1", 1e9), playerInput("1") })
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
}
