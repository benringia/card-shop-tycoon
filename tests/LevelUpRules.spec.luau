--!strict
-- Level-up rewards (spec 2026-11-04-round4-design section 8): $10 x the new level every level, a pack every 10th,
-- nothing past Lv 100; the effects held during a fight merge into one.
local LevelUpRules = require("../src/shared/Util/LevelUpRules")
local cfg = require("../src/shared/Config/Levels")
local expect = require("./lib/expect")

local function same(got: { cash: number, packs: number }, cash: number, packs: number, label: string)
	expect.equal(got.cash, cash, `{label} cash`)
	expect.equal(got.packs, packs, `{label} packs`)
end

return {
	["cash every level"] = function()
		same(LevelUpRules.rewards(cfg, 1, 2), 20, 0, "Lv 2")
		expect.equal(LevelUpRules.rewards(cfg, 6, 7).cash, 70, "Lv 7")
	end,

	["a pack on every 10th level"] = function()
		expect.equal(LevelUpRules.rewards(cfg, 9, 10).packs, 1, "Lv 10")
		expect.equal(LevelUpRules.rewards(cfg, 10, 11).packs, 0, "Lv 11")
		expect.equal(LevelUpRules.rewards(cfg, 1, 100).packs, 10, "all the way")
		expect.equal(LevelUpRules.isMilestone(cfg, 30), true, "Lv 30")
		expect.equal(LevelUpRules.isMilestone(cfg, 31), false, "Lv 31")
	end,

	["skipped levels each pay"] = function()
		same(LevelUpRules.rewards(cfg, 8, 11), 90 + 100 + 110, 1, "8 -> 11")
	end,

	["nothing past the cap or backwards"] = function()
		same(LevelUpRules.rewards(cfg, 99, 150), 1000, 1, "99 -> 150")
		same(LevelUpRules.rewards(cfg, 100, 101), 0, 0, "past the cap")
		same(LevelUpRules.rewards(cfg, 5, 5), 0, 0, "no change")
		same(LevelUpRules.rewards(cfg, 7, 3), 0, 0, "backwards")
	end,

	["reward text"] = function()
		expect.equal(LevelUpRules.rewardText(cfg, 7), "+$70", "Lv 7")
		expect.equal(LevelUpRules.rewardText(cfg, 10), "+$100 · +1 pack", "Lv 10")
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
