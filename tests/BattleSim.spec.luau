--!strict
local BattleSim = require("../src/server/Util/BattleSim")
local combat = require("../src/shared/Config/Combat")
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

local function group(seed: number): any
	return BattleSim.new(combat, {
		fighters = { owned("p1", "1"), owned("p2", "2") },
		reserves = { owned("r1", "1"), owned("r1b", "1"), owned("r2", "2") },
		abilities = true,
		canRun = true,
	}, { fighters = { monster("Bloom", 100000, 10, 10) }, abilities = false, canRun = false }, seed)
end

return {
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

	["abilities: cooldown, Fireball hits hard, Wave heals"] = function()
		local state = wild(fighter("a", "Ember", 100, 10, 10), { fighter("b", "Tide", 100, 10, 10) }, monster("Volt", 5000, 30, 10), 5)
		BattleSim.callIn(state, "a:b")
		local events = BattleSim.useAbility(state, "a:a", "element") :: { any }
		assert(events and events[1].damage >= 22, "Fireball ~2.5x ATK")
		local again, reason = BattleSim.useAbility(state, "a:a", "element")
		expect.isNil(again, "cooldown")
		expect.equal(reason, "cooldown", "reason")
		for _ = 1, 30 do
			BattleSim.step(state, 0.1)
		end
		local healEvents = BattleSim.useAbility(state, "a:b", "element") :: { any }
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
		-- Let the first normal attack land, then overcharge
		local times = {}
		local t = 0
		local charged = false
		while #times < 7 and t < 60 do
			for _, e in BattleSim.step(state, 0.01) do
				if e.type == "attack" and e.from == "a:a" then
					table.insert(times, state.time)
				end
			end
			t += 0.01
			if #times == 1 and not charged then
				charged = true
				BattleSim.useAbility(state, "a:a", "element")
			end
		end
		local fast = 0
		for i = 2, #times do
			if times[i] - times[i - 1] < normal * 0.75 then
				fast += 1
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
		BattleSim.useAbility(state, "a:t", "element")
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
}
