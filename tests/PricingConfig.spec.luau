--!strict
-- The Prices window's tags (Config/Pricing, DESIGN 10.6): each row's tag sits under the name beside the market price,
-- so every band's tag stays short enough to fit there at any price (round 3: "Almost always buy" ran under the stepper).
local Pricing = require("../src/shared/Config/Pricing")
local expect = require("./lib/expect")

local MAX_TAG = 10

return {
	["every buy band has a short tag for the Prices window"] = function()
		for index, band in Pricing.BUY_BANDS do
			local tag = (band :: any).tag
			expect.equal(typeof(tag), "string", `band {index} has a tag`)
			expect.equal(#tag <= MAX_TAG, true, `band {index}'s tag "{tag}" is {#tag} characters`)
		end
		expect.equal(#Pricing.NEVER_TAG <= MAX_TAG, true, "the won't-buy tag")
	end,
}
