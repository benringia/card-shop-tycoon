--!strict
-- Boss balance check: many seeded fights per boss with the real BattleSim, Config/Bosses and Config/Combat.
-- Usage: lune run tools/balance/bosses [fights] [players] [boss number: only that one]
-- With players > 1 every row is a group of that many players, each with the row's party, against the boss scaled
-- by BossRules.groupStats.
-- Every boss row is run twice, with the player in the fight (spec 2026-11-02-you-in-the-fight-design):
--   still  the player stands there: no sword, never dodges, every ring and quick hit lands
--   well   the player fights well: the starter combo, a cut landing SWORD_UPTIME of the time (it misses otherwise:
--          moving, dodging), the skill on cooldown, QUICK_DODGE of quick hits dodged, RING_ESCAPE of rings stepped out
--          of; each is drawn per fight from its { low, high } range, since players differ
-- Targets (solo): well 85% at x1 and 50% at x0.8; still 60% at x1 and 15% at x0.8; well wins in about half the time.
-- Parties (swaps on, abilities fired whenever ready, like an active player), averaged over the five elements:
--   rec x1   three Legendaries at about the boss's recommended Power
--   rec x0.8 three at 80% of it (under-powered)
--   rec x1.3 three at 130%
--   best+2   the best card at the recommended Power, two at 60% of it (a typical party the board calls "ready")
--   maxed+2  one maxed Legendary (Lv 30, 5 stars, Grade S) and two Lv 1 Commons (a typical "one carry" party)
--   3 maxed  (the Dungeon's boss only) three maxed Legendaries
-- The Dungeon's boss (Config/Dungeon.BOSS) is fought after its three rooms of elite packs, with the HP each creature
-- has left (fainted ones stay out), as in a real run; its rows also print the party's HP share left before the boss.
local process = require("@lune/process")
local BattleSim = require("../../src/server/Util/BattleSim")
local BeastMath = require("../../src/shared/Util/BeastMath")
local Beasts = require("../../src/shared/Config/Beasts")
local Bosses = require("../../src/shared/Config/Bosses")
local Combat = require("../../src/shared/Config/Combat")
local Dungeon = require("../../src/shared/Config/Dungeon")
local Frontier = require("../../src/shared/Config/Frontier")
local Swords = require("../../src/shared/Config/Swords")
local BossRules = require("../../src/shared/Util/BossRules")
local CombatMath = require("../../src/shared/Util/CombatMath")
local DungeonRules = require("../../src/shared/Util/DungeonRules")

local FIGHTS = tonumber(process.args[1] or "") or 200
local PLAYERS = tonumber(process.args[2] or "") or 1
local ONLY = tonumber(process.args[3] or "")
local ELEMENTS = { "Ember", "Tide", "Bloom", "Volt", "Shade" }
local DT = 0.1
local SWORD_UPTIME = { 0.55, 0.9 }
local QUICK_DODGE = { 0.4, 0.8 }
local RING_ESCAPE = { 0.8, 0.97 }
local SWORD = Swords.SWORDS[Swords.STARTER]

-- The tool's own dice (the player's choices), so the sim's seeded random stays the sim's
local dice = 1
local function roll(): number
	dice = (dice * 1103515245 + 12345) % 2147483648
	return dice / 2147483648
end

type Card = { rarity: string, level: number, stars: number, grade: string }

local function stats(card: Card, element: string): any
	return BeastMath.getStats(Beasts, card.rarity, element, false, card.level, card.stars, card.grade)
end

local function power(card: Card): number
	return BeastMath.getPower(Beasts, stats(card, "Ember"))
end

-- The card (any rarity, level, stars, grade) whose Power is closest to `target`; Legendaries win ties (the low bosses'
-- recommended Power is under any Legendary's)
local function legendaryAt(target: number): Card
	local best: Card = { rarity = "Legendary", level = 1, stars = 0, grade = "C" }
	for rarity in Beasts.BASE_STATS do
		for level = 1, Beasts.MAX_LEVEL do
			for stars = 0, Beasts.MAX_STARS do
				for _, grade in Beasts.GRADES do
					local card = { rarity = rarity, level = level, stars = stars, grade = grade }
					if math.abs(power(card) - target) < math.abs(power(best) - target) then
						best = card
					end
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

-- Every player brings the same party; the leader has the tested element (shifted per player), the others the next two.
-- One list per player, leader first.
local function parties(party: { Card }, element: string): { { any } }
	local out = {}
	for player = 1, PLAYERS do
		local own = {}
		for index, card in party do
			local elementOf = ELEMENTS[(table.find(ELEMENTS, element) :: number + player + index - 3) % #ELEMENTS + 1]
			table.insert(own, fighter(`p{player}c{index}`, card, elementOf, tostring(player)))
		end
		table.insert(out, own)
	end
	return out
end

-- One fight of these players (their cards with HP carried in `hpLeft`) against `foes`; returns the win, its length
-- and hpLeft after it
-- mode: nil (creatures only: Dungeon rooms; each player's call-in), "still" or "well" (a boss: the player fights beside
-- one creature, no call-in)
local function battle(players: { { any } }, foes: { any }, hpLeft: { [string]: number }, seed: number, mode: string?): (boolean, number, { [string]: number })
	local leaders, reserves = {}, {}
	for _, own in players do
		local led = false
		for _, input in own do
			if DungeonRules.canFight(hpLeft, input.id) then
				local copy = table.clone(input)
				copy.hpNow = hpLeft[input.id]
				table.insert(if led then reserves else leaders, copy)
				led = true
			end
		end
	end
	if #leaders == 0 then
		return false, 0, hpLeft
	end
	local owners = {}
	if mode then
		for index = 1, #players do
			local owner = tostring(index)
			table.insert(owners, owner)
			table.insert(leaders, { id = `@{owner}`, player = true, owner = owner, element = "None", hp = Combat.PLAYER_HP, atk = 0, spd = 10 })
		end
	end
	local state = BattleSim.new(Combat, { fighters = leaders, reserves = reserves, abilities = true, canRun = true, swapSeconds = Combat.BOSS_SWAP_SECONDS, callIn = mode == nil }, {
		fighters = foes,
		abilities = false,
		canRun = false,
	}, seed)
	state.maxSeconds = Combat.BOSS_MAX_FIGHT_SECONDS
	dice = seed
	local function skill(range: { number }): number
		return range[1] + (range[2] - range[1]) * roll()
	end
	local uptime, quickDodge, ringEscape = skill(SWORD_UPTIME), skill(QUICK_DODGE), skill(RING_ESCAPE)
	if mode == "well" then
		state.ringCheck = function()
			return roll() >= ringEscape
		end
	end
	local nextCut: { [string]: number } = {}
	local cutIndex: { [string]: number } = {}
	local skillReady: { [string]: number } = {}
	local dodgeAt: { [string]: number } = {}
	local calledIn: { [string]: boolean } = {}
	while not state.result do
		local events = BattleSim.step(state, DT)
		local side = state.sides.a
		if mode == "well" then
			for _, event in events do
				local owner = if event.type == "telegraph" and event.to then string.sub(event.to, 4) else nil
				if owner and roll() < quickDodge then
					dodgeAt[owner] = state.time + Combat.QUICK_WARNING - 0.05
				end
			end
			for _, owner in owners do
				local target = nil
				for _, foe in state.sides.b.fighters do
					if not foe.fainted then
						target = if target == nil or not foe.boss then foe else target -- adds first
					end
				end
				if dodgeAt[owner] and state.time >= dodgeAt[owner] then
					dodgeAt[owner] = nil
					BattleSim.dodge(state, owner)
				end
				if not target or state.result then
					continue
				end
				if state.time >= (skillReady[owner] or 0) then
					if BattleSim.swordHit(state, owner, target.id, SWORD.skill.power * SWORD.power, "Skill") then
						skillReady[owner] = state.time + SWORD.skill.cooldown
						nextCut[owner] = math.max(nextCut[owner] or 0, state.time + SWORD.skill.length)
					end
				elseif state.time >= (nextCut[owner] or 0) then
					local index = cutIndex[owner] or 1
					local cut = SWORD.combo[index]
					if roll() < uptime then
						BattleSim.swordHit(state, owner, target.id, cut.power * SWORD.power, "Sword")
					end
					nextCut[owner] = state.time + cut.length
					cutIndex[owner] = index % #SWORD.combo + 1
				end
			end
		end
		if not mode and state.time > 1 then
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
	return state.result == "a", state.time, DungeonRules.merge(hpLeft, BattleSim.hpLeft(state, "a"))
end

-- The share of the party's total HP left
local function hpShare(players: { { any } }, hpLeft: { [string]: number }): number
	local left, total = 0, 0
	for _, own in players do
		for _, input in own do
			total += input.hp
			left += hpLeft[input.id] or input.hp
		end
	end
	return if total > 0 then left / total else 0
end

-- The Dungeon's rooms before its boss: (cleared them all, HP left after)
local function runRooms(players: { { any } }, seed: number): (boolean, { [string]: number })
	local hpLeft: { [string]: number } = {}
	for index, room in Dungeon.ROOMS do
		local foes = {}
		for slot, species in DungeonRules.pack(room, seed + index) do
			local base = CombatMath.getMonsterStats(Frontier, species, room.level, true) :: any
			local hp, atk, swings = BossRules.groupStats(Bosses, base.hp * Dungeon.PACK_SCALE.hp, base.atk * Dungeon.PACK_SCALE.atk, PLAYERS)
			table.insert(foes, { id = `p{slot}`, element = Frontier.SPECIES[species].element, hp = hp, atk = atk, spd = base.spd, elite = true, swings = swings })
		end
		local won, _seconds, after = battle(players, foes, hpLeft, seed * 31 + index)
		hpLeft = after
		if not won then
			return false, hpLeft
		end
	end
	return true, hpLeft
end

-- (won, seconds, HP share left before the boss)
local function fight(bossId: string, party: { Card }, element: string, seed: number, mode: string): (boolean, number, number)
	local boss = Bosses.BOSSES[bossId]
	local players = parties(party, element)
	local hpLeft: { [string]: number } = {}
	if bossId == Dungeon.BOSS then
		local cleared
		cleared, hpLeft = runRooms(players, seed)
		if not cleared then
			return false, 0, 0
		end
	end
	local share = hpShare(players, hpLeft)
	local hp, atk, swings = BossRules.groupStats(Bosses, boss.hp, boss.atk, PLAYERS, boss.groupAtkStep)
	local won, time = battle(players, {
		{ id = "m", element = boss.element, hp = hp, atk = atk, spd = boss.spd, boss = true, mechanics = boss.mechanics, phases = boss.phases, swings = swings, playerAttacks = boss.playerAttacks },
	}, hpLeft, seed, mode)
	return won, time, share
end

-- (win rate, average win seconds, average HP share before the boss over the runs that reached it, share that reached it)
local function run(bossId: string, party: { Card }, mode: string): (number, number, number, number)
	local wins, seconds, reached, shares = 0, 0, 0, 0
	for seed = 1, FIGHTS do
		local element = ELEMENTS[(seed - 1) % #ELEMENTS + 1]
		local won, time, share = fight(bossId, party, element, seed * 7919, mode)
		if share > 0 then
			reached += 1
			shares += share
		end
		if won then
			wins += 1
			seconds += time
		end
	end
	return wins / FIGHTS, if wins > 0 then seconds / wins else 0, if reached > 0 then shares / reached else 0, reached / FIGHTS
end

local function row(bossId: string, label: string, party: { Card })
	local still, stillSeconds, share, reached = run(bossId, party, "still")
	local well, wellSeconds = run(bossId, party, "well")
	local before = if bossId == Dungeon.BOSS then string.format("  reached it %3d%%, HP left %3d%%", math.round(reached * 100), math.round(share * 100)) else ""
	print(string.format("  %-30s still %3d%% %3ds   well %3d%% %3ds%s", label, math.round(still * 100), math.round(stillSeconds), math.round(well * 100), math.round(wellSeconds), before))
end

local maxed: Card = { rarity = "Legendary", level = Beasts.MAX_LEVEL, stars = Beasts.MAX_STARS, grade = Beasts.GRADES[#Beasts.GRADES] }
local junk: Card = { rarity = "Common", level = 1, stars = 0, grade = "C" }
print(`{FIGHTS} fights per row, {PLAYERS} player(s) each with the row's party; maxed Legendary Power {math.round(power(maxed))}`)
for index, id in Bosses.LADDER do
	if ONLY and index ~= ONLY then
		continue
	end
	local boss = Bosses.BOSSES[id]
	local hp, atk = BossRules.groupStats(Bosses, boss.hp, boss.atk, PLAYERS, boss.groupAtkStep)
	print(`\n{index}. {boss.name}  HP {hp}  ATK {atk}  SPD {boss.spd}  recommended {boss.recommended}{if id == Dungeon.BOSS then "  (after the 3 rooms)" else ""}`)
	for _, scale in { { "rec x0.8", 0.8 }, { "rec x1  ", 1 }, { "rec x1.3", 1.3 } } do
		local card = legendaryAt(boss.recommended * scale[2])
		row(id, string.format("%s (3 x %4d %s)", scale[1], math.round(power(card)), string.sub(card.rarity, 1, 4)), { card, card, card })
	end
	local best, weak = legendaryAt(boss.recommended), legendaryAt(boss.recommended * 0.6)
	row(id, string.format("best+2   (%4d + 2 x %4d)", math.round(power(best)), math.round(power(weak))), { best, weak, weak })
	row(id, string.format("maxed+2  (%4d + 2 Lv 1)", math.round(power(maxed))), { maxed, junk, junk })
	if id == Dungeon.BOSS then
		row(id, string.format("3 maxed  (3 x %4d)", math.round(power(maxed))), { maxed, maxed, maxed })
	end
end
