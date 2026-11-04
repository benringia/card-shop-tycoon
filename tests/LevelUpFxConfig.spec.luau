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

	["three sound sets, each a licensed sound and a sting"] = function()
		expect.equal(#LevelUpFx.SOUNDS.sets, 3)
		for index, set in LevelUpFx.SOUNDS.sets do
			assert(typeof(set.name) == "string" and set.name ~= "", `set {index} name`)
			assert(isAsset(set.sound.id), `set {index} sound`)
			assert(isAsset(set.sting.id), `set {index} sting`)
		end
	end,

	["quiet: every sound under the cap, the normal one at most 0.1"] = function()
		for index, set in LevelUpFx.SOUNDS.sets do
			assert(set.sound.volume > 0 and set.sound.volume <= 0.1, `set {index} sound volume`)
			assert(set.sting.volume > 0 and set.sting.volume <= LevelUpFx.SOUNDS.maxVolume, `set {index} sting volume`)
		end
		assert(LevelUpFx.SOUNDS.maxVolume <= 0.15, "cap about half of round 4's loudest (0.25)")
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
