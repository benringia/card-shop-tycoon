--!strict
-- The Prices window's tags (Config/Pricing, DESIGN 10.6): each row's tag sits under the name beside the market price,
-- so every band's tag stays short enough to fit there at any price (round 3: "Almost always buy" ran under the stepper).
local Pricing = require("../src/shared/Config/Pricing")
local BabyColors = require("../src/shared/Config/BabyColors")
local expect = require("./lib/expect")

local MAX_TAG = 10

return {
	-- Owner 2026-11-04: "fix cut off edges". The list clips what draws past it: each row's outside outline and its soft
	-- button's glow (spread past the button by GLOW.margin, scaled to the button's corner; dropped GLOW down)
	["Order Stock and Prices rows and their buttons' glow fit inside the list"] = function()
		local rows = Pricing.ROWS
		local pad = rows.LIST_PAD
		local spread = BabyColors.GLOW.margin * BabyColors.SOFT_BUTTON.corner / BabyColors.GLOW.corner
		expect.equal(pad.side >= 2, true, "the row's 2 px outline on the left")
		expect.equal(rows.BUTTON_INSET + pad.right >= spread, true, "the button's glow on the right")
		local tallest = math.max(rows.STEPPER_HEIGHT, rows.BUTTON_HEIGHT) -- Order Stock's price button, the Prices stepper
		local above = spread - BabyColors.SOFT_BUTTON.glowDrop - (rows.ROW_HEIGHT - tallest) / 2
		expect.equal(pad.top >= math.max(2, above), true, "the first row's glow and outline on top")
		local below = spread + BabyColors.SOFT_BUTTON.glowDrop - (rows.ROW_HEIGHT - tallest) / 2
		expect.equal(pad.bottom >= math.max(2, below), true, "the last row's glow underneath")
	end,

	["every buy band has a short tag for the Prices window"] = function()
		for index, band in Pricing.BUY_BANDS do
			local tag = (band :: any).tag
			expect.equal(typeof(tag), "string", `band {index} has a tag`)
			expect.equal(#tag <= MAX_TAG, true, `band {index}'s tag "{tag}" is {#tag} characters`)
		end
		expect.equal(#Pricing.NEVER_TAG <= MAX_TAG, true, "the won't-buy tag")
	end,
}
