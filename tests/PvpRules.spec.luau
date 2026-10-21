--!strict
local PvpRules = require("../src/shared/Util/PvpRules")
local config = require("../src/shared/Config/Pvp")
local expect = require("./lib/expect")

return {
	["bet cap: lower cash, lower shop level x CAP_PER_LEVEL, floored to the step"] = function()
		expect.equal(PvpRules.getBetCap(config, 1000, 300, 4, 9), 200, "50 x level 4")
		expect.equal(PvpRules.getBetCap(config, 1000, 133, 9, 9), 130, "cash, floored to 5")
		expect.equal(PvpRules.getBetCap(config, 0, 500, 5, 5), 0, "no cash")
		expect.equal(PvpRules.getBetCap(config, -20, 500, 5, 5), 0, "never negative")
	end,

	["valid bets: whole steps from Friendly up to the cap"] = function()
		expect.equal(PvpRules.isValidBet(config, 0, 30), true, "friendly")
		expect.equal(PvpRules.isValidBet(config, 25, 30), true, "in steps")
		expect.equal(PvpRules.isValidBet(config, 27, 30), false, "off step")
		expect.equal(PvpRules.isValidBet(config, 35, 30), false, "over cap")
		for _, bad in { -5, 2.5, "10", nil, 0 / 0, math.huge } do
			expect.equal(PvpRules.isValidBet(config, bad, 1000), false, `bad {tostring(bad)}`)
		end
	end,

	["payout: win doubles, draw refunds, loss nothing"] = function()
		expect.equal(PvpRules.getPayout("win", 40), 80, "win")
		expect.equal(PvpRules.getPayout("draw", 40), 40, "draw")
		expect.equal(PvpRules.getPayout("lose", 40), 0, "lose")
		expect.equal(PvpRules.getPayout("win", 0), 0, "friendly")
	end,

	["record: sanitised and updated without mutating"] = function()
		local record = PvpRules.sanitizeRecord({ wins = 3, losses = -2, draws = 1.7 })
		expect.equal(record.wins, 3, "wins")
		expect.equal(record.losses, 0, "losses")
		expect.equal(record.draws, 1, "draws")
		local empty = PvpRules.sanitizeRecord("x")
		expect.equal(empty.wins + empty.losses + empty.draws, 0, "junk -> zeros")
		local after = PvpRules.addResult(record, "lose")
		expect.equal(after.losses, 1, "loss added")
		expect.equal(record.losses, 0, "input untouched")
		expect.equal(PvpRules.addResult(record, "win").wins, 4, "win added")
		expect.equal(PvpRules.addResult(record, "draw").draws, 2, "draw added")
	end,
}
