--!strict
local CompareRules = require("../src/shared/Util/CompareRules")
local expect = require("./lib/expect")

return {
	["share: against the strongest card's stat, never an empty bar"] = function()
		expect.near(CompareRules.share(50, 200), 0.25, 1e-9, "a quarter")
		expect.equal(CompareRules.share(300, 200), 1, "capped")
		expect.equal(CompareRules.share(0, 200), CompareRules.MIN_SHARE, "a sliver")
		expect.equal(CompareRules.share(10, 0), 1, "no reference")
	end,
	["pair: the bigger stat fills its bar and wins"] = function()
		local a, b, winner = CompareRules.pair(120, 80)
		expect.equal(a, 1, "incoming full")
		expect.near(b, 0.667, 0.001, "outgoing two thirds")
		expect.equal(winner, "in", "incoming wins")
		local _, _, other = CompareRules.pair(5, 9)
		expect.equal(other, "out", "outgoing wins")
		local c, d, tie = CompareRules.pair(0, 0)
		expect.equal(c, CompareRules.MIN_SHARE, "empty in")
		expect.equal(d, CompareRules.MIN_SHARE, "empty out")
		expect.equal(tie, "tie", "a tie")
	end,
	["verdict: stronger, weaker or the same, by rounded Power"] = function()
		local kind, delta = CompareRules.verdict(212.4, 190.2)
		expect.equal(kind, "stronger", "stronger")
		expect.equal(delta, 22, "rounded")
		expect.equal(CompareRules.verdictText(212.4, 190.2), "STRONGER +22", "badge")
		expect.equal(CompareRules.verdictText(202, 2614), "WEAKER -2412", "badge")
		expect.equal(CompareRules.verdictText(150, 150), "SAME POWER", "badge")
		expect.equal((CompareRules.verdict(300, nil)), "stronger", "an empty slot")
	end,
	["swapText: the line on each party slot"] = function()
		expect.equal(CompareRules.swapText(212, 190), "+22 if swapped", "gain")
		expect.equal(CompareRules.swapText(190, 212), "-22 if swapped", "loss")
		expect.equal(CompareRules.swapText(190, nil), "Empty: adds it", "empty slot")
	end,
	["reference: the highest of each stat"] = function()
		local ref = CompareRules.reference({ { hp = 10, atk = 5, spd = 7 }, { hp = 8, atk = 9, spd = 7 } })
		expect.equal(ref.hp, 10, "hp")
		expect.equal(ref.atk, 9, "atk")
		expect.equal(ref.spd, 7, "spd")
		expect.equal(CompareRules.reference({}).hp, 0, "no cards")
	end,
}
