--!strict
-- Round 5 (spec 2026-11-04-round5-design section 1): soft glow hover, nothing grows, a press with no bounce.
local HoverRules = require("../src/shared/Util/HoverRules")
local BabyColors = require("../src/shared/Config/BabyColors")
local UIMotion = require("../src/shared/Config/UIMotion")
local expect = require("./lib/expect")

return {
	["soft buttons glow, rows and tiles get the lilac edge"] = function()
		expect.equal(HoverRules.kind(true, 0, false), "glow")
		expect.equal(HoverRules.kind(false, 0, false), "edge")
		expect.equal(HoverRules.kind(false, 0.5, false), "edge", "a half see-through empty slot still lights")
	end,

	["invisible click areas and greyed-out buttons don't light up"] = function()
		expect.equal(HoverRules.kind(false, 1, false), "none")
		expect.equal(HoverRules.kind(true, 0, true), "none")
		expect.equal(HoverRules.kind(false, 0, true), "none")
	end,

	["nothing grows on hover"] = function()
		expect.isNil((BabyColors.SOFT_BUTTON :: any).hoverScale)
		expect.isNil((BabyColors.SOFT_BUTTON :: any).rowHoverScale)
	end,

	["the hover look"] = function()
		expect.equal(table.concat(BabyColors.HOVER.edge, ","), "217,194,242", "soft lilac edge")
		expect.equal(BabyColors.HOVER.sheen >= 0.9, true, "the sheen is at most 10% white")
		expect.equal(BabyColors.HOVER.tint >= 0.9, true, "a very light tint")
	end,

	["the motion: about 0.15 s in, a little faster out, a press with no bounce"] = function()
		expect.equal(UIMotion.HOVER_SECONDS >= 0.1 and UIMotion.HOVER_SECONDS <= 0.2, true)
		expect.equal(UIMotion.HOVER_OUT_SECONDS <= UIMotion.HOVER_SECONDS, true)
		expect.equal(UIMotion.SQUISH_PRESS >= 0.95 and UIMotion.SQUISH_PRESS < 1, true)
		expect.isNil((UIMotion :: any).RELEASE_OVERSHOOT)
	end,
}
