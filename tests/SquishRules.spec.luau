--!strict
local BabyColors = require("../src/shared/Config/BabyColors")
local SoftHud = require("../src/shared/Config/SoftHud")
local SquishRules = require("../src/shared/Util/SquishRules")
local expect = require("./lib/expect")

return {
	["the hover lasts about 0.45 s"] = function()
		expect.equal(math.abs(SquishRules.duration(SoftHud.SQUISH.steps) - 0.45) <= 0.05, true)
	end,

	["it squashes gently, stretches as it hops, and settles a little bigger (owner: a subtle bounce)"] = function()
		local steps = SoftHud.SQUISH.steps
		expect.equal(SquishRules.widest(SoftHud.SQUISH) <= 1.06, true, "never more than 6% wider, press included")
		expect.equal(steps[1].x > steps[1].y, true, "first a squash: wider than tall")
		expect.equal(steps[2].y > steps[2].x and steps[2].lift > steps[1].lift, true, "then a stretch as it hops up")
		for _, step in steps do
			expect.equal(step.lift <= 5 and math.abs(step.y - 1) <= 0.06, true, "small hops and stretches")
		end
		local last = steps[#steps]
		expect.near(last.x, 1.03, 0.01)
		expect.near(last.y, 1.03, 0.01)
		expect.equal(last.lift > 0, true, "it settles a little higher")
		local press = SoftHud.SQUISH.press
		expect.equal(press.x > 1 and press.y < 1, true, "a press squashes it flat")
	end,

	["the hovered tile, key chip and all, stays inside the gap to the next tile"] = function()
		expect.equal(SquishRules.fitsGap(SoftHud.TILE, SoftHud.SQUISH), true)
		expect.equal(SoftHud.TILE.gap >= 18, true, "tiles sit well apart (owner: too close together at 10 px)")
		local tight = table.clone(SoftHud.TILE)
		tight.gap = 2
		expect.equal(SquishRules.fitsGap(tight, SoftHud.SQUISH), false, "a gap of 2 px is too tight")
	end,

	["the tile row's top counts the popped-out icons and the hover, so the cushion can sit clear of it"] = function()
		local tile, squish = SoftHud.TILE, SoftHud.SQUISH
		local atRest = 16 + tile.size * (1 + tile.iconRise)
		local top = SquishRules.rowTop(tile, squish, 16, 1)
		expect.equal(top > atRest, true, "above a resting icon: a hovered tile reaches higher")
		local highest = 0
		for _, step in squish.steps do
			highest = math.max(highest, step.lift + tile.size * step.y * (1 + tile.iconRise))
		end
		expect.near(top, 16 + highest, 1e-6)
		expect.near(SquishRules.rowTop(tile, squish, 16, 0.7), 16 + highest * 0.7, 1e-6, "the HUD's scale shrinks all but the margin")
	end,

	["every tile and tray colour is a baby colour"] = function()
		for id, name in SoftHud.COLORS do
			expect.equal(BabyColors.COLORS[name] ~= nil, true, `{id} -> {name}`)
		end
		for index, name in SoftHud.FAN do
			expect.equal(BabyColors.COLORS[name] ~= nil, true, `tray tile {index} -> {name}`)
		end
		expect.equal(#SoftHud.FAN, 4)
	end,
}
