--!strict
local BabyColors = require("../src/shared/Config/BabyColors")
local SoftHud = require("../src/shared/Config/SoftHud")
local SquishRules = require("../src/shared/Util/SquishRules")
local expect = require("./lib/expect")

return {
	["the hover lasts about 0.45 s"] = function()
		expect.equal(math.abs(SquishRules.duration(SoftHud.SQUISH.steps) - 0.45) <= 0.05, true)
	end,

	["it squashes at most 10% wider, stretches as it hops, and settles about 6% bigger"] = function()
		local steps = SoftHud.SQUISH.steps
		expect.equal(SquishRules.widest(SoftHud.SQUISH) <= 1.10, true, "never more than 10% wider, press included")
		expect.equal(steps[1].x > steps[1].y, true, "first a squash: wider than tall")
		expect.equal(steps[2].y > steps[2].x and steps[2].lift > steps[1].lift, true, "then a stretch as it hops up")
		local last = steps[#steps]
		expect.near(last.x, 1.06, 0.02)
		expect.near(last.y, 1.06, 0.02)
		expect.equal(last.lift > 0, true, "it settles a little higher")
		local press = SoftHud.SQUISH.press
		expect.equal(press.x > 1 and press.y < 1, true, "a press squashes it flat")
	end,

	["the hovered tile, key chip and all, stays inside the gap to the next tile"] = function()
		expect.equal(SquishRules.fitsGap(SoftHud.TILE, SoftHud.SQUISH), true)
		local tight = table.clone(SoftHud.TILE)
		tight.gap = 2
		expect.equal(SquishRules.fitsGap(tight, SoftHud.SQUISH), false, "a gap of 2 px is too tight")
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
