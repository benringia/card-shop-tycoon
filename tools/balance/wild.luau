--!strict
-- Wild monster balance (owner 2026-11-03: the player fights normal monsters too, beside one creature): win rate and
-- fight length per species at its zone's lowest, middle and highest level, for normal monsters and elites. The
-- creature is the card at the monster's level (capped at the max level) whose Power is closest to its zone's boss's
-- recommended Power (the zones run alongside the boss ladder). Each row plays the fight three ways: a player with no
-- sword yet (the creature alone), one who stands still (takes the quick hits, never swings), and one who fights well
-- (the starter combo landing 55-90% of the time, the skill on cooldown, 40-80% of quick hits dodged). Targets: normal
-- monsters about 10-15 s, won about 90% fighting well and 75% standing still; elites about 25-35 s, about 65% fighting
-- well. The creature uses its Pet button on cooldown; no call-ins.
-- Usage: lune run tools/balance/wild [fights] [world: wild | frontier | both]
local process = require("@lune/process")
local BattleSim = require("../../src/server/Util/BattleSim")
local BeastMath = require("../../src/shared/Util/BeastMath")
local Beasts = require("../../src/shared/Config/Beasts")
local Bosses = require("../../src/shared/Config/Bosses")
local Combat = require("../../src/shared/Config/Combat")
local Frontier = require("../../src/shared/Config/Frontier")
local Party = require("../../src/shared/Config/Party")
local Swords = require("../../src/shared/Config/Swords")
local Wild = require("../../src/shared/Config/Wild")
local CombatMath = require("../../src/shared/Util/CombatMath")
local PartyRules = require("../../src/shared/Util/PartyRules")

local FIGHTS = tonumber(process.args[1] or "") or 200
local WORLD = process.args[2] or "both"
local ELEMENTS = { "Ember", "Tide", "Bloom", "Volt", "Shade" }
local DT = 0.1
local SWORD_UPTIME = { 0.55, 0.9 }
local QUICK_DODGE = { 0.4, 0.8 }
local SWORD = Swords.SWORDS[Swords.STARTER]
local LIMIT = 120 -- seconds: a wild fight longer than this counts as lost (Combat.MAX_FIGHT_SECONDS runs it out)

local dice = 1
local function roll(): number
	dice = (dice * 1103515245 + 12345) % 2147483648
	return dice / 2147483648
end

type Card = { rarity: string, level: number, stars: number, grade: string }

local function stats(card: Card, element: string): any
	return BeastMath.getStats(Beasts, card.rarity, element, false, card.level, card.stars, card.grade)
end

-- The card at `level` whose Power is closest to `target`
local function cardAt(level: number, target: number): Card
	local best: Card = { rarity = "Common", level = level, stars = 0, grade = "C" }
	local function gap(card: Card): number
		return math.abs(BeastMath.getPower(Beasts, stats(card, "Ember")) - target)
	end
	for rarity in Beasts.BASE_STATS do
		for stars = 0, Beasts.MAX_STARS do
			for _, grade in Beasts.GRADES do
				local card = { rarity = rarity, level = level, stars = stars, grade = grade }
				if gap(card) < gap(best) then
					best = card
				end
			end
		end
	end
	return best
end

-- One fight; mode "creature" (no sword yet), "still" or "well". Returns (won, seconds)
local function fight(world: any, species: string, level: number, elite: boolean, card: Card, element: string, seed: number, mode: string): (boolean, number)
	local s = stats(card, element)
	local perk = PartyRules.getFightPerk(Party, element, card.rarity, card.stars)
	local leaders: { any } = { { id = "c", element = element, hp = s.hp, atk = s.atk, spd = s.spd, owner = "1", perk = perk } }
	if mode ~= "creature" then
		table.insert(leaders, { id = "@1", player = true, owner = "1", element = "None", hp = Combat.PLAYER_HP, atk = 0, spd = 10 })
	end
	local m = CombatMath.getMonsterStats(world, species, level, elite) :: any
	local foe = {
		id = "m",
		element = world.SPECIES[species].element,
		hp = m.hp,
		atk = m.atk,
		spd = m.spd,
		elite = elite,
		playerAttacks = if mode ~= "creature" then CombatMath.getMonsterAttacks(world, elite) else nil,
	}
	local state = BattleSim.new(Combat, { fighters = leaders, abilities = true, canRun = true, creaturesDecide = true }, { fighters = { foe }, abilities = false, canRun = false }, seed)
	dice = seed
	local uptime = SWORD_UPTIME[1] + (SWORD_UPTIME[2] - SWORD_UPTIME[1]) * roll()
	local quickDodge = QUICK_DODGE[1] + (QUICK_DODGE[2] - QUICK_DODGE[1]) * roll()
	local nextCut, cutIndex, skillReady, dodgeAt = 0, 1, 0, nil :: number?
	while not state.result and state.time < LIMIT do
		local events = BattleSim.step(state, DT)
		if mode == "well" then
			for _, event in events do
				if event.type == "telegraph" and event.to == "a:@1" and roll() < quickDodge then
					dodgeAt = state.time + Combat.QUICK_WARNING - 0.05
				end
			end
			if dodgeAt and state.time >= dodgeAt then
				dodgeAt = nil
				BattleSim.dodge(state, "1")
			end
			if not state.result then
				if state.time >= skillReady then
					if BattleSim.swordHit(state, "1", "b:m", SWORD.skill.power * SWORD.power, "Skill") then
						skillReady = state.time + SWORD.skill.cooldown * (1 - BattleSim.perkOf(state, "1", "Express"))
						nextCut = math.max(nextCut, state.time + SWORD.skill.length)
					end
				elseif state.time >= nextCut then
					local cut = SWORD.combo[cutIndex]
					if roll() < uptime then
						BattleSim.swordHit(state, "1", "b:m", cut.power * SWORD.power, "Sword")
					end
					-- chained: the next cut starts at this one's cancel point (the last cut runs to its end)
					nextCut = state.time + (if cutIndex < #SWORD.combo then cut.cancelAt or cut.length else cut.length)
					cutIndex = cutIndex % #SWORD.combo + 1
				end
			end
		end
		if not state.result then
			BattleSim.useAbility(state, "a:c", "element", "1")
		end
	end
	return state.result == "a", state.time
end

local function run(world: any, species: string, level: number, elite: boolean, card: Card, mode: string): (number, number)
	local wins, seconds = 0, 0
	for index = 1, FIGHTS do
		local won, time = fight(world, species, level, elite, card, ELEMENTS[index % #ELEMENTS + 1], index * 7919 + level, mode)
		if won then
			wins += 1
			seconds += time
		end
	end
	return wins / FIGHTS, if wins > 0 then seconds / wins else 0
end

local function cell(share: number, seconds: number): string
	return string.format("%3d%% %5.1fs", math.round(share * 100), seconds)
end

local function report(name: string, world: any, firstBoss: number)
	print(`\n== {name} ({FIGHTS} fights per cell; no sword | still | well)`)
	for index, zone in world.ZONES do
		local boss = Bosses.BOSSES[Bosses.LADDER[firstBoss + index - 1]]
		print(`{zone.name} (Lv {zone.minLevel}-{zone.maxLevel}, cards near Power {boss.recommended})`)
		for _, species in zone.species do
			for _, level in { zone.minLevel, math.round((zone.minLevel + zone.maxLevel) / 2), zone.maxLevel } do
				local card = cardAt(math.min(level, Beasts.MAX_LEVEL), boss.recommended)
				local line = string.format("  %-12s Lv%-2d vs %-9s L%-2d %d* %s ", species, level, card.rarity, card.level, card.stars, card.grade)
				for _, elite in { false, true } do
					local parts = {}
					for _, mode in { "creature", "still", "well" } do
						local share, seconds = run(world, species, level, elite, card, mode)
						table.insert(parts, cell(share, seconds))
					end
					line ..= (if elite then "  ELITE " else " normal ") .. table.concat(parts, " | ")
				end
				print(line)
			end
		end
	end
end

if WORLD == "wild" or WORLD == "both" then
	report("Wild valley", Wild, 1)
end
if WORLD == "frontier" or WORLD == "both" then
	report("Frontier", Frontier, 4)
end
