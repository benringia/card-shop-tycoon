--!strict
-- Level-up rewards (spec 2026-11-04-round4-design section 8): $10 x the new level every level, a gift every 5th
-- (owner 2026-11-16), nothing past Lv 100; the effects held during a fight merge into one.
local LevelUpRules = require("../src/shared/Util/LevelUpRules")
local cfg = require("../src/shared/Config/Levels")
local expect = require("./lib/expect")

local function count(items: { [string]: number }, id: string): number
	return items[id] or 0
end

local function anyItems(items: { [string]: number }): boolean
	return next(items) ~= nil
end

return {
	-- Small cash every level: $3 x the new level since levels came 4x faster (owner 2026-11-17; $10 x before, $4 x at 2.7x)
	["small cash every level"] = function()
		expect.equal(LevelUpRules.rewards(cfg, 1, 2).cash, 6, "Lv 2")
		expect.equal(LevelUpRules.rewards(cfg, 6, 7).cash, 21, "Lv 7")
		expect.equal(LevelUpRules.rewards(cfg, 8, 11).cash, 27 + 30 + 33, "8 -> 11: each level pays")
	end,

	-- Owner 2026-11-16: "small cash every level. only give gift every 5 levels (wild ores and etc) make sure its not
	-- economy breaking"
	["a gift only on every 5th level: ore and a tonic on the 5s, the pack on the 10s, a Gold Seal every 25th"] = function()
		for level = 2, 100 do
			local items = LevelUpRules.rewards(cfg, level - 1, level).items
			expect.equal(anyItems(items), level % 5 == 0, `Lv {level}: a gift only every 5th level`)
		end
		local five = LevelUpRules.rewards(cfg, 4, 5).items
		expect.equal(count(five, "wildOre"), 3, "Lv 5: Wild Ore")
		expect.equal(count(five, "xpTonic"), 1, "Lv 5: an XP Tonic")
		local ten = LevelUpRules.rewards(cfg, 9, 10).items
		expect.equal(count(ten, "sparkPack"), 1, "Lv 10: the pack, as before")
		expect.equal(count(ten, "wildOre"), 0, "Lv 10: no ore")
		local twentyFive = LevelUpRules.rewards(cfg, 24, 25).items
		expect.equal(count(twentyFive, "goldSeal"), 1, "Lv 25: a Gold Seal too")
		expect.equal(count(twentyFive, "wildOre"), 3, "and its 5s gift")
		expect.equal(LevelUpRules.isMilestone(cfg, 30), true, "Lv 30: the rainbow pillar")
		expect.equal(LevelUpRules.isMilestone(cfg, 35), false, "Lv 35: a gift, not a milestone")
	end,

	["not economy breaking: everything all 100 levels give"] = function()
		local all = LevelUpRules.rewards(cfg, 1, 100)
		expect.equal(count(all.items, "wildOre"), 30, "30 Wild Ore (the Forge Sword alone needs 20; monsters drop it)")
		expect.equal(count(all.items, "xpTonic"), 10, "10 XP Tonics")
		expect.equal(count(all.items, "sparkPack"), 10, "10 packs, as before")
		expect.equal(count(all.items, "goldSeal"), 4, "4 Gold Seals")
		local kinds = 0
		for _ in all.items do
			kinds += 1
		end
		expect.equal(kinds, 4, "nothing else")
		expect.equal(all.cash, 3 * (100 * 101 / 2 - 1), "$3 x each level: $15,147 in all")
	end,

	["skipped levels each give theirs"] = function()
		local got = LevelUpRules.rewards(cfg, 8, 11)
		expect.equal(count(got.items, "sparkPack"), 1, "Lv 10's pack")
		local wide = LevelUpRules.rewards(cfg, 3, 26)
		expect.equal(count(wide.items, "wildOre"), 9, "Lv 5, 15 and 25")
		expect.equal(count(wide.items, "goldSeal"), 1, "Lv 25")
	end,

	["nothing past the cap or backwards"] = function()
		local top = LevelUpRules.rewards(cfg, 99, 150)
		expect.equal(top.cash, 300, "only Lv 100 pays")
		expect.equal(count(top.items, "sparkPack"), 1, "Lv 100's pack")
		expect.equal(count(top.items, "goldSeal"), 1, "and seal")
		for _, case in { { 100, 101 }, { 5, 5 }, { 7, 3 } } do
			local none = LevelUpRules.rewards(cfg, case[1], case[2])
			expect.equal(none.cash, 0, `{case[1]} -> {case[2]}: no cash`)
			expect.equal(anyItems(none.items), false, `{case[1]} -> {case[2]}: no items`)
		end
	end,

	-- The middle card says which titles a level-up earned (Config/Titles "level" checks)
	["the titles a level-up reaches, in their order"] = function()
		local titles = require("../src/shared/Config/Titles")
		local function names(from: number, to: number): string
			return table.concat(LevelUpRules.titlesReached(titles, from, to), ",")
		end
		expect.equal(names(9, 10), "Shopkeeper", "Lv 10")
		expect.equal(names(10, 11), "", "Lv 11: none")
		expect.equal(names(8, 31), "Tycoon,Shopkeeper", "skipping past two (in the titles' order)")
		expect.equal(names(49, 50), "Card Mogul", "Lv 50")
	end,

	["merge keeps the first from and the last to"] = function()
		local first = LevelUpRules.merge(nil, 4, 5)
		expect.equal(first.from, 4, "first from")
		expect.equal(first.to, 5, "first to")
		local both = LevelUpRules.merge({ from = 4, to = 5 }, 5, 7)
		expect.equal(both.from, 4, "merged from")
		expect.equal(both.to, 7, "merged to")
	end,

	["a held level-up waits out the boss fight's end screen"] = function()
		local fx = require("../src/shared/Config/LevelUpFx")
		expect.equal(LevelUpRules.freeAt(fx, 100, true, "win"), 100 + fx.AFTER_BOSS.win, "victory screen")
		expect.equal(LevelUpRules.freeAt(fx, 100, true, "lose"), 100 + fx.AFTER_BOSS.lose, "defeat countdown and the trip home")
		expect.equal(LevelUpRules.freeAt(fx, 100, false, "win"), 100, "a wild fight: at once")
		expect.equal(LevelUpRules.freeAt(fx, 100, true, "run"), 100, "a boss fight that ran: no end screen")
		expect.equal(LevelUpRules.freeAt(fx, 100, true, "timeout"), 100 + fx.AFTER_BOSS.lose, "a timed-out boss fight ends on the defeat screen")
	end,

	["the picked sound set, else the default"] = function()
		local sounds = { sets = { {}, {}, {} }, default = 1 }
		expect.equal(LevelUpRules.soundSet(sounds, 2), 2)
		expect.equal(LevelUpRules.soundSet(sounds, nil), 1)
		expect.equal(LevelUpRules.soundSet(sounds, 7), 1)
		expect.equal(LevelUpRules.soundSet(sounds, 1.5), 1)
		expect.equal(LevelUpRules.soundSet(sounds, "2"), 1)
	end,

	["Bag packs don't open in any fight"] = function()
		expect.equal(LevelUpRules.openBlocked(true, false), "Open it after the fight.", "a monster or boss fight")
		expect.equal(LevelUpRules.openBlocked(false, true), "Open it after the fight.", "PvP in the arena")
		expect.isNil(LevelUpRules.openBlocked(false, false), "free")
	end,
}
