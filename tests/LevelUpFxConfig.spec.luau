--!strict
-- The level-up pillar's config (spec 2026-11-04-round4-design section 9): Blender-rendered textures uploaded as images,
-- the timing in order, the rainbow in baby colours; round 5 (spec 2026-11-04-round5-design section 7): one soft sound
-- per level-up from three licensed sets, a sting on 10th levels, all quiet.
local LevelUpFx = require("../src/shared/Config/LevelUpFx")
local BabyColors = require("../src/shared/Config/BabyColors")
local expect = require("./lib/expect")

local function isAsset(id: any): boolean
	return typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
end

return {
	["images are uploaded ids"] = function()
		for _, name in { "rune", "beam", "mote" } do
			assert(isAsset(LevelUpFx.IMAGES[name]), `{name} is an uploaded image`)
		end
	end,

	["four sound sets, each a licensed sound and a sting; the default layers a rise, a pop and a shimmer"] = function()
		expect.equal(#LevelUpFx.SOUNDS.sets, 4)
		for index, set in LevelUpFx.SOUNDS.sets do
			assert(typeof(set.name) == "string" and set.name ~= "", `set {index} name`)
			assert(isAsset(set.sound.id), `set {index} sound`)
			assert(isAsset(set.sting.id), `set {index} sting`)
			for layerIndex, layer in set.layers or {} do
				assert(isAsset(layer.id), `set {index} layer {layerIndex}`)
				assert(typeof(layer.at) == "number" and layer.at >= -1.5 and layer.at <= 1.5, `set {index} layer {layerIndex} timing`)
			end
		end
		-- owner 2026-11-16: "add a satisfying immersive sound effect" on a shop level up
		local fanfare = LevelUpFx.SOUNDS.sets[LevelUpFx.SOUNDS.default]
		assert(fanfare.layers and #fanfare.layers >= 2, "the default is layered")
		local rises = false
		for _, layer in fanfare.layers do
			rises = rises or layer.at < 0
		end
		assert(rises, "its rise starts before the badge pops")
	end,

	["every sound under the cap"] = function()
		for index, set in LevelUpFx.SOUNDS.sets do
			assert(set.sound.volume > 0 and set.sound.volume <= LevelUpFx.SOUNDS.maxVolume, `set {index} sound volume`)
			assert(set.sting.volume > 0 and set.sting.volume <= LevelUpFx.SOUNDS.maxVolume, `set {index} sting volume`)
			for _, layer in set.layers or {} do
				assert(layer.volume > 0 and layer.volume <= LevelUpFx.SOUNDS.maxVolume, `set {index} layer volume`)
			end
		end
		-- round 5 asked for soft (0.15 cap); the owner's 2026-11-16 "satisfying immersive" lets it fill out, still under 0.35
		assert(LevelUpFx.SOUNDS.maxVolume <= 0.35, "a cap")
	end,

	-- Owner 2026-11-16: "if pets leveled up. it should be noticeable. pets should glow for some time and sound effects"
	["a creature's level-up: a glow for a few seconds and a fuller sound"] = function()
		local glow = LevelUpFx.CREATURE_GLOW
		assert(glow.seconds >= 2.5, "a while")
		assert(glow.low < glow.high and glow.high < 1, "a visible pulse")
		assert(LevelUpFx.SOUNDS.creature.volumeScale >= 0.8, "loud enough to notice")
	end,

	["the default set is one of them"] = function()
		assert(LevelUpFx.SOUNDS.sets[LevelUpFx.SOUNDS.default], "default set exists")
	end,

	["timing runs in order"] = function()
		local t = LevelUpFx.TIMING
		assert(t.beam < t.badge and t.badge < t.fade and t.fade < t.done, "beam < badge < fade < done")
	end,

	["the rainbow uses baby colours"] = function()
		for _, name in LevelUpFx.COLORS.rainbow do
			assert(BabyColors.COLORS[name], `{name} is a baby colour`)
		end
	end,
}
