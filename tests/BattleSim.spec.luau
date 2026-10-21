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
	return { element = element, hp = hp, atk = atk, spd = spd, elite = elite == true }
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

return {
	["strong party beats a weak monster"] = function()
		local state = BattleSim.new(combat, fighter("a", "Ember", 200, 30, 15), {}, monster("Bloom", 100, 2, 5), 1)
		local result, events = runToEnd(state)
		expect.equal(result, "win", "result")
		assert(count(events, function(e)
			return e.type == "end" and e.result == "win"
		end) == 1, "one end event")
	end,

	["weak party loses and faints"] = function()
		local state = BattleSim.new(combat, fighter("a", "Bloom", 30, 2, 5), {}, monster("Ember", 900, 20, 12), 2)
		local result, events = runToEnd(state)
		expect.equal(result, "lose", "result")
		assert(count(events, function(e)
			return e.type == "faint" and e.to == "a"
		end) == 1, "leader fainted")
	end,

	["same seed, same fight"] = function()
		local function play(seed: number): string
			local state = BattleSim.new(combat, fighter("a", "Tide", 120, 12, 10), {}, monster("Volt", 300, 8, 10), seed)
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
		local strong = BattleSim.new(combat, fighter("a", "Ember", 500, 20, 10), {}, monster("Bloom", 5000, 1, 1), 3)
		local weak = BattleSim.new(combat, fighter("a", "Bloom", 500, 20, 10), {}, monster("Ember", 5000, 1, 1), 3)
		local _, se = runToEnd(strong, 10)
		local _, we = runToEnd(weak, 10)
		local function firstHit(events: { any }): any
			for _, e in events do
				if e.type == "attack" and e.from == "a" then
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
		local state = BattleSim.new(combat, fighter("a", "Ember", 100, 10, 10), { fighter("b", "Tide", 100, 10, 10), fighter("c", "Volt", 100, 10, 10) }, monster("Shade", 5000, 1, 1), 4)
		expect.equal((BattleSim.callIn(state, "zzz")), false, "not a reserve")
		expect.equal((BattleSim.callIn(state, "b")), true, "first call-in")
		expect.equal((BattleSim.callIn(state, "c")), false, "only one")
		local late = BattleSim.new(combat, fighter("a", "Ember", 100, 10, 10), { fighter("b", "Tide", 100, 10, 10) }, monster("Shade", 5000, 1, 1), 4)
		for _ = 1, combat.CALL_IN_SECONDS * 10 + 1 do
			BattleSim.step(late, 0.1)
		end
		expect.equal((BattleSim.callIn(late, "b")), false, "window closed")
	end,

	["abilities: cooldown, Fireball hits hard, Wave heals"] = function()
		local state = BattleSim.new(combat, fighter("a", "Ember", 100, 10, 10), { fighter("b", "Tide", 100, 10, 10) }, monster("Volt", 5000, 30, 10), 5)
		BattleSim.callIn(state, "b")
		local events = BattleSim.useAbility(state, "a", "element") :: { any }
		assert(events and events[1].damage >= 22, "Fireball ~2.5x ATK")
		local again, reason = BattleSim.useAbility(state, "a", "element")
		expect.isNil(again, "cooldown")
		expect.equal(reason, "cooldown", "reason")
		for _ = 1, 30 do
			BattleSim.step(state, 0.1)
		end
		local healEvents = BattleSim.useAbility(state, "b", "element") :: { any }
		assert(healEvents and (healEvents[1].heal or 0) > 0, "Wave heals")
		local none, why = BattleSim.useAbility(state, "a", "signature")
		expect.isNil(none, "no signature")
		expect.equal(why, "none", "reason none")
	end,

	["Curse weakens and Vine Snare slows the monster"] = function()
		local function monsterDamageIn(element: string, seconds: number): number
			local state = BattleSim.new(combat, fighter("a", element, 100000, 1, 10), {}, monster("Tide", 100000, 50, 10), 6)
			BattleSim.useAbility(state, "a", "element")
			local total = 0
			for _ = 1, seconds * 10 do
				for _, e in BattleSim.step(state, 0.1) do
					if e.type == "attack" and e.from == "monster" then
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
		local stunned = BattleSim.new(combat, fighter("a", "Volt", 100000, 1, 10, "Thunderhorn"), {}, monster("Tide", 100000, 50, 20), 7)
		BattleSim.useAbility(stunned, "a", "signature")
		local hits = 0
		for _ = 1, 15 do
			for _, e in BattleSim.step(stunned, 0.1) do
				if e.type == "attack" and e.from == "monster" then
					hits += 1
				end
			end
		end
		expect.equal(hits, 0, "stunned 1.5 s")

		local dodger = BattleSim.new(combat, fighter("a", "Shade", 1000, 1, 10, "Eclipse Fox"), {}, monster("Tide", 100000, 50, 20), 8)
		BattleSim.useAbility(dodger, "a", "signature")
		local damage = 0
		for _ = 1, 25 do
			for _, e in BattleSim.step(dodger, 0.1) do
				if e.type == "attack" and e.from == "monster" then
					damage += e.damage
				end
			end
		end
		expect.equal(damage, 0, "dodged for 2.5 s")
	end,

	["failed run gives the monster a free hit and waits"] = function()
		-- Very slow leader vs fast monster: run chance at the floor (20%); seed chosen so the first roll fails
		local state = BattleSim.new(combat, fighter("a", "Ember", 1000, 1, 1), {}, monster("Tide", 100000, 20, 100), 9)
		local events = BattleSim.tryRun(state)
		local ran = false
		local freeHit = false
		for _, e in events do
			if e.type == "run" then
				ran = e.ok
			elseif e.type == "attack" and e.from == "monster" then
				freeHit = true
			end
		end
		if not ran then
			assert(freeHit, "free hit on failure")
			local retry = BattleSim.tryRun(state)
			expect.equal(retry[1].type, "run", "run event")
			expect.equal(retry[1].ok, false, "must wait")
			expect.equal(retry[1].kind, "wait", "wait reason")
		else
			expect.equal(state.result, "run", "ran away")
		end
	end,

	["fight times out as a run"] = function()
		local state = BattleSim.new(combat, fighter("a", "Ember", 1e9, 0, 1), {}, monster("Ember", 1e9, 0, 1), 10)
		local result = runToEnd(state, combat.MAX_FIGHT_SECONDS + 5)
		expect.equal(result, "run", "timeout")
	end,

	["Inferno burns for every second, even with uneven frames"] = function()
		local state = BattleSim.new(combat, fighter("a", "Ember", 1e6, 10, 1, "Infernox"), {}, monster("Tide", 1e6, 0, 1), 12)
		BattleSim.useAbility(state, "a", "signature")
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
		local state = BattleSim.new(combat, fighter("a", "Volt", 1e6, 1, spd), {}, monster("Tide", 1e9, 0, 1), 13)
		-- Let the first normal attack land, then overcharge
		local times = {}
		local t = 0
		local charged = false
		while #times < 7 and t < 60 do
			for _, e in BattleSim.step(state, 0.01) do
				if e.type == "attack" and e.from == "a" then
					table.insert(times, state.time)
				end
			end
			t += 0.01
			if #times == 1 and not charged then
				charged = true
				BattleSim.useAbility(state, "a", "element")
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

	["nothing happens after the end"] = function()
		local state = BattleSim.new(combat, fighter("a", "Ember", 200, 30, 15), {}, monster("Bloom", 10, 1, 1), 11)
		runToEnd(state)
		expect.equal(#BattleSim.step(state, 0.1), 0, "no events")
		local none, reason = BattleSim.useAbility(state, "a", "element")
		expect.isNil(none, "no ability")
		expect.equal(reason, "ended", "reason")
	end,
}
