--!strict
-- Boss balance check: many seeded fights per boss with the real BattleSim, Config/Bosses and Config/Combat.
-- Usage: lune run tools/balance/bosses [fights] [players]
-- With players > 1 every row is a group of that many players, each with the row's party, against the boss scaled
-- by BossRules.groupStats.
-- Parties (swaps on, abilities fired whenever ready, like an active player), averaged over the five elements:
--   rec x1   three Legendaries at about the boss's recommended Power
--   rec x0.8 three at 80% of it (under-powered)
--   rec x1.3 three at 130%
--   best+2   the best card at the recommended Power, two at 60% of it (a typical party the board calls "ready")
--   maxed+2  one maxed Legendary (Lv 30, 5 stars, Grade S) and two Lv 1 Commons (a typical "one carry" party)
local process = require("@lune/process")
local BattleSim = require("../../src/server/Util/BattleSim")
local BeastMath = require("../../src/shared/Util/BeastMath")
local Beasts = require("../../src/shared/Config/Beasts")
local Bosses = require("../../src/shared/Config/Bosses")
local Combat = require("../../src/shared/Config/Combat")
local BossRules = require("../../src/shared/Util/BossRules")

local FIGHTS = tonumber(process.args[1] or "") or 200
local PLAYERS = tonumber(process.args[2] or "") or 1
local ELEMENTS = { "Ember", "Tide", "Bloom", "Volt", "Shade" }
local DT = 0.1

type Card = { rarity: string, level: number, stars: number, grade: string }

local function stats(card: Card, element: string): any
	return BeastMath.getStats(Beasts, card.rarity, element, false, card.level, card.stars, card.grade)
end

local function power(card: Card): number
	return BeastMath.getPower(Beasts, stats(card, "Ember"))
end

-- The Legendary (level, stars, grade) whose Power is closest to `target`
local function legendaryAt(target: number): Card
	local best: Card = { rarity = "Legendary", level = 1, stars = 0, grade = "C" }
	for level = 1, Beasts.MAX_LEVEL do
		for stars = 0, Beasts.MAX_STARS do
			for _, grade in Beasts.GRADES do
				local card = { rarity = "Legendary", level = level, stars = stars, grade = grade }
				if math.abs(power(card) - target) < math.abs(power(best) - target) then
					best = card
				end
			end
		end
	end
	return best
end

local function fighter(id: string, card: Card, element: string, owner: string): any
	local s = stats(card, element)
	return { id = id, element = element, hp = s.hp, atk = s.atk, spd = s.spd, owner = owner }
end

local function fight(boss: any, party: { Card }, element: string, seed: number): (boolean, number)
	-- Every player brings the same party; the leader has the tested element (shifted per player), the others the next two
	local leaders, reserves = {}, {}
	for player = 1, PLAYERS do
		local owner = tostring(player)
		for index, card in party do
			local own = ELEMENTS[(table.find(ELEMENTS, element) :: number + player + index - 3) % #ELEMENTS + 1]
			local input = fighter(`p{player}c{index}`, card, own, owner)
			table.insert(if index == 1 then leaders else reserves, input)
		end
	end
	local hp, atk, swings = BossRules.groupStats(Bosses, boss.hp, boss.atk, PLAYERS, boss.groupAtkStep)
	local state = BattleSim.new(Combat, { fighters = leaders, reserves = reserves, abilities = true, canRun = true, swapSeconds = Combat.BOSS_SWAP_SECONDS }, {
		fighters = { { id = "m", element = boss.element, hp = hp, atk = atk, spd = boss.spd, boss = true, mechanics = boss.mechanics, swings = swings } },
		abilities = false,
		canRun = false,
	}, seed)
	state.maxSeconds = Combat.BOSS_MAX_FIGHT_SECONDS
	local calledIn: { [string]: boolean } = {}
	while not state.result do
		BattleSim.step(state, DT)
		local side = state.sides.a
		if state.time > 1 then
			for _, reserve in side.reserves do
				local owner = reserve.owner :: string
				if not calledIn[owner] then
					calledIn[owner] = true
					BattleSim.swap(state, reserve.id, owner) -- each player's call-in
				end
			end
		end
		for _, own in side.fighters do
			if not own.fainted and not own.benched then
				BattleSim.useAbility(state, own.id, "element", own.owner)
			end
		end
	end
	return state.result == "a", state.time
end

local function run(boss: any, party: { Card }): (number, number)
	local wins, seconds, count = 0, 0, 0
	for seed = 1, FIGHTS do
		local element = ELEMENTS[(seed - 1) % #ELEMENTS + 1]
		local won, time = fight(boss, party, element, seed * 7919)
		count += 1
		if won then
			wins += 1
			seconds += time
		end
	end
	return wins / count, if wins > 0 then seconds / wins else 0
end

local maxed: Card = { rarity = "Legendary", level = Beasts.MAX_LEVEL, stars = Beasts.MAX_STARS, grade = Beasts.GRADES[#Beasts.GRADES] }
local junk: Card = { rarity = "Common", level = 1, stars = 0, grade = "C" }
print(`{FIGHTS} fights per row, {PLAYERS} player(s) each with the row's party; maxed Legendary Power {math.round(power(maxed))}`)
for index, id in Bosses.LADDER do
	local boss = Bosses.BOSSES[id]
	local hp, atk = BossRules.groupStats(Bosses, boss.hp, boss.atk, PLAYERS, boss.groupAtkStep)
	print(`\n{index}. {boss.name}  HP {hp}  ATK {atk}  SPD {boss.spd}  recommended {boss.recommended}`)
	for _, row in { { "rec x0.8", 0.8 }, { "rec x1  ", 1 }, { "rec x1.3", 1.3 } } do
		local card = legendaryAt(boss.recommended * row[2])
		local rate, seconds = run(boss, { card, card, card })
		print(string.format("  %s  (3 x Power %4d)  win %3d%%  avg win %3ds", row[1], math.round(power(card)), math.round(rate * 100), math.round(seconds)))
	end
	local best, weak = legendaryAt(boss.recommended), legendaryAt(boss.recommended * 0.6)
	local typical, typicalSeconds = run(boss, { best, weak, weak })
	print(string.format("  best+2    (%4d + 2 x %4d) win %3d%%  avg win %3ds", math.round(power(best)), math.round(power(weak)), math.round(typical * 100), math.round(typicalSeconds)))
	local rate, seconds = run(boss, { maxed, junk, junk })
	print(string.format("  maxed+2   (%4d + 2 Lv 1)   win %3d%%  avg win %3ds", math.round(power(maxed)), math.round(rate * 100), math.round(seconds)))
end
