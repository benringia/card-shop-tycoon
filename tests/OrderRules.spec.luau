--!strict
-- Order Stock's buttons (spec 2026-11-04-round4-design section 4): the box price to order, "Need $48" when you can't
-- afford it, "Lv 11" while locked; and the small "sells ~$3.00" tag.
local OrderRules = require("../src/shared/Util/OrderRules")
local expect = require("./lib/expect")

local function same(got: { text: string, state: string }, text: string, state: string, label: string)
	expect.equal(got.text, text, `{label} text`)
	expect.equal(got.state, state, `{label} state`)
end

return {
	["locked below its level"] = function()
		same(OrderRules.button(1, 11, 500, 90), "Lv 11", "locked", "Booster Box at Lv 1")
	end,

	["short of cash shows what it costs"] = function()
		same(OrderRules.button(20, 1, 20, 48), "Need $48", "short", "packs with $20")
		same(OrderRules.button(20, 1, 1, 2.5), "Need $2.50", "short", "cents kept")
	end,

	["ready shows the box price"] = function()
		same(OrderRules.button(20, 1, 48, 48), "$48.00", "ready", "exactly enough")
	end,

	["what each unit sells for"] = function()
		expect.equal(OrderRules.sells(3), "sells ~$3.00", "a pack")
		expect.equal(OrderRules.sells(120), "sells ~$120", "a booster box")
	end,
}
