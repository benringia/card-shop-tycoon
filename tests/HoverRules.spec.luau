--!strict
-- Round 5 (spec 2026-11-04-round5-design section 1): soft glow hover, nothing grows, a press with no bounce.
local HoverRules = require("../src/shared/Util/HoverRules")
local BabyColors = require("../src/shared/Config/BabyColors")
local UIMotion = require("../src/shared/Config/UIMotion")
local ContrastRules = require("../src/shared/Util/ContrastRules")
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

	["a button that lays out its own children gets no hover pieces (they would join its layout)"] = function()
		expect.equal(HoverRules.kind(false, 0, false, true), "none")
		expect.equal(HoverRules.kind(true, 0, false, true), "none")
		expect.equal(HoverRules.kind(false, 0, false, false), "edge")
	end,

	["nothing grows on hover"] = function()
		expect.isNil((BabyColors.SOFT_BUTTON :: any).hoverScale)
		expect.isNil((BabyColors.SOFT_BUTTON :: any).rowHoverScale)
	end,

	["the glow spreads a few px, never by a scale (a scale pulled it away from wide buttons)"] = function()
		expect.isNil((BabyColors.HOVER :: any).glowScale)
		expect.equal(BabyColors.HOVER.glowGrow > 0 and BabyColors.HOVER.glowGrow <= 8, true)
	end,

	["a hover layer keeps the button's corner: round stays round, an inset layer a little tighter"] = function()
		local scale, offset = HoverRules.insetCorner(0.5, 0, 0)
		expect.equal(scale, 0.5, "the round close X")
		expect.equal(offset, 0)
		scale, offset = HoverRules.insetCorner(0, 16, 3)
		expect.equal(scale, 0)
		expect.equal(offset, 13)
		scale, offset = HoverRules.insetCorner(0, 2, 3)
		expect.equal(offset, 0, "never negative")
	end,

	-- Owner 2026-11-04 after round 5: "Hover effects are unnoticeable, the softglow on gray and white is unnoticeable"
	["the hover shows on white rows and pale slots"] = function()
		local white = { 255, 255, 255 }
		expect.equal(ContrastRules.ratio(BabyColors.HOVER.edge, white) >= 2.5, true, "the edge stands out from a white row")
		expect.equal(BabyColors.HOVER.edgeGlow <= 0.45, true, "the edge glow is strong enough to see")
		expect.equal(BabyColors.HOVER.tint <= 0.6, true, "the tint shows on white")
		expect.equal(ContrastRules.ratio(BabyColors.HOVER.tintColor, white) > 1.15, true, "the tint colour isn't near-white")
		expect.equal(BabyColors.HOVER.sheen >= 0.8, true, "the sheen stays soft (text keeps reading)")
	end,

	["a soft button's outline turns to its deep shade on hover (white outlines vanish on white rows)"] = function()
		expect.equal(BabyColors.HOVER.buttonOutline, "deep")
	end,

	["the motion: about 0.15 s in, a little faster out, a press with no bounce"] = function()
		expect.equal(UIMotion.HOVER_SECONDS >= 0.1 and UIMotion.HOVER_SECONDS <= 0.2, true)
		expect.equal(UIMotion.HOVER_OUT_SECONDS <= UIMotion.HOVER_SECONDS, true)
		expect.equal(UIMotion.SQUISH_PRESS >= 0.95 and UIMotion.SQUISH_PRESS < 1, true)
		expect.isNil((UIMotion :: any).RELEASE_OVERSHOOT)
	end,
}
