--!strict
-- Paid random items (content questionnaire 2026-11-16): luck boosts raise the odds of rare pulls and Turts' restock is a
-- paid re-roll, so both are chance-based purchases; where Roblox restricts those (PolicyService
-- ArePaidRandomItemsRestricted) neither is sold, and a policy that can't be read counts as restricted
local PaidRandomRules = require("../src/shared/Util/PaidRandomRules")
local expect = require("./lib/expect")

return {
	["sold only where the policy says chance-based purchases are allowed"] = function()
		expect.equal(PaidRandomRules.restricted(true, { ArePaidRandomItemsRestricted = false }), false)
		expect.equal(PaidRandomRules.restricted(true, { ArePaidRandomItemsRestricted = true }), true)
	end,

	["a policy that can't be read counts as restricted"] = function()
		expect.equal(PaidRandomRules.restricted(false, "HTTP 500"), true, "the call failed")
		expect.equal(PaidRandomRules.restricted(true, nil), true, "no answer")
		expect.equal(PaidRandomRules.restricted(true, {}), true, "no flag in it")
	end,
}
