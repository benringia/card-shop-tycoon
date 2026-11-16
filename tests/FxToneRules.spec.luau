--!strict
-- The owner 2026-11-10: "the particles are too bright on a white map like this. is it posible to make the particles
-- dynamic? like when I cast my prism sword skill I only see white flashes instead of the animation/rays of different
-- colors": on bright ground effects blend their colours in instead of adding light (which turns white on white), white
-- cores fade, lights dim; on dark ground nothing changes
local FxToneRules = require("../src/shared/Util/FxToneRules")
local FxTone = require("../src/shared/Config/FxTone")
local expect = require("./lib/expect")

local SNOW = { 222, 230, 240 }
local GRASS = { 96, 140, 70 }
local BASALT = { 46, 38, 58 }

return {
	["snow is a bright scene, grass and dark rock aren't"] = function()
		local snow = FxToneRules.level(SNOW, { 200, 214, 230 }, FxTone)
		local grass = FxToneRules.level(GRASS, { 180, 200, 220 }, FxTone)
		local rift = FxToneRules.level(BASALT, { 60, 40, 90 }, FxTone)
		assert(snow >= 0.8, `snow {snow}`)
		expect.equal(grass, 0, "grass: as before")
		expect.equal(rift, 0, "the Rift: as before")
		local mid = FxToneRules.level({ 170, 175, 180 }, { 170, 175, 180 }, FxTone)
		assert(mid > 0 and mid < snow, "in between, in between")
	end,

	["on a dark scene an effect is untouched"] = function()
		local toned = FxToneRules.tone({ lightEmission = 1, brightness = 1.5, color = { 255, 120, 40 } }, 0, FxTone)
		expect.equal(toned.lightEmission, 1)
		expect.equal(toned.brightness, 1.5)
		expect.equal(toned.fade, 0)
	end,

	["on snow a coloured glow blends its colour in instead of adding light"] = function()
		local toned = FxToneRules.tone({ lightEmission = 1, brightness = 1.5, color = { 255, 120, 40 } }, 1, FxTone)
		assert(toned.lightEmission <= 0.3, `light emission {toned.lightEmission}`)
		assert(toned.brightness < 1.5 and toned.brightness >= 1, "a little less bright")
		expect.equal(toned.fade, 0, "a coloured layer stays")
	end,

	["on snow a glowing white core fades, a soft white puff stays"] = function()
		local core = FxToneRules.tone({ lightEmission = 1, brightness = 2.2, color = { 255, 255, 255 } }, 1, FxTone)
		assert(core.fade >= 0.5, "the white core fades out of the way of the colours")
		local smoke = FxToneRules.tone({ lightEmission = 0.3, brightness = 1, color = { 225, 240, 255 } }, 1, FxTone)
		expect.equal(smoke.fade, 0, "ice smoke is meant to be white")
	end,

	["a faded transparency keeps its shape, only less opaque"] = function()
		expect.near(FxToneRules.fadeValue(0, 0.6), 0.6, 1e-9)
		expect.near(FxToneRules.fadeValue(0.5, 0.6), 0.8, 1e-9)
		expect.near(FxToneRules.fadeValue(1, 0.6), 1, 1e-9)
		expect.near(FxToneRules.fadeValue(0.3, 0), 0.3, 1e-9)
	end,

	["lights dim on bright ground"] = function()
		expect.equal(FxToneRules.lightBrightness(6, 0, FxTone), 6)
		local dim = FxToneRules.lightBrightness(6, 1, FxTone)
		assert(dim < 6 and dim >= 2, `{dim}`)
	end,

	-- Owner 2026-11-17 (the Frontier): "the glows in this part of the map is not right. mistfins glow is black and also
	-- the fountain". A texture drawn on black (no transparency: the store pack's ember specks, the fountain's water and
	-- rune) only looks right fully additive: blended in, its black square shows. On snow it keeps its additive light
	-- and fades instead
	["a texture drawn on black keeps its additive light on snow, fading instead"] = function()
		local made = { lightEmission = 1, brightness = 3, color = { 150, 225, 255 }, additive = true }
		local snow = FxToneRules.tone(made, 1, FxTone)
		expect.equal(snow.lightEmission, 1, "still fully additive: no black square")
		expect.equal(snow.brightness, 3 * (1 - FxTone.brightness), "dimmer")
		expect.equal(snow.fade, FxTone.additiveFade, "and fainter")
		local dark = FxToneRules.tone(made, 0, FxTone)
		expect.equal(dark.lightEmission, 1)
		expect.equal(dark.fade, 0, "as made on dark ground")
		local half = FxToneRules.tone({ lightEmission = 0.6, brightness = 1, color = { 255, 255, 255 }, additive = true }, 1, FxTone)
		expect.equal(half.lightEmission, 0.6, "its made emission, never lowered")
	end,

	["the textures drawn on black are listed; the fountains and portals stay as made"] = function()
		for _, id in { "rbxassetid://1084996976", "rbxassetid://139671283074387", "rbxassetid://131308578602059" } do
			assert(table.find(FxTone.additive, id), `{id} is listed as drawn on black`)
		end
		assert(table.find(FxTone.skip, "Plaza"), "the plaza (its spring, portals) is scenery")
		assert(table.find(FxTone.skip, "FountainFx"), "the fountain's rune, light and orbs are scenery")
	end,
}
