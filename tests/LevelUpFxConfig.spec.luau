--!strict
-- The level-up pillar's config (spec 2026-11-04-round4-design section 9): Blender-rendered textures uploaded as images,
-- four sound moments with three licensed options each, the timing in order, the rainbow in baby colours.
local LevelUpFx = require("../src/shared/Config/LevelUpFx")
local BabyColors = require("../src/shared/Config/BabyColors")
local expect = require("./lib/expect")

local MOMENTS = { "rise", "beam", "chime", "fanfare" }

local function isAsset(id: any): boolean
	return typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
end

return {
	["images are uploaded ids"] = function()
		for _, name in { "rune", "beam", "mote" } do
			assert(isAsset(LevelUpFx.IMAGES[name]), `{name} is an uploaded image`)
		end
	end,

	["each moment has three licensed options"] = function()
		for _, moment in MOMENTS do
			local options = LevelUpFx.SOUNDS.options[moment]
			expect.equal(#options, 3, `{moment} options`)
			for index, option in options do
				assert(isAsset(option.id), `{moment} {index} id`)
				assert(option.volume > 0 and option.volume <= 1, `{moment} {index} volume`)
				assert(typeof(option.name) == "string" and option.name ~= "", `{moment} {index} name`)
			end
		end
	end,

	["the current sound is one of its options"] = function()
		for _, moment in MOMENTS do
			local found = false
			for _, option in LevelUpFx.SOUNDS.options[moment] do
				found = found or option.id == LevelUpFx.SOUNDS[moment].id
			end
			assert(found, `{moment} plays one of its options`)
		end
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
