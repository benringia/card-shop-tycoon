--!strict
-- The worlds' soundscape (the owner 2026-11-11: "make it more immersive"; Util/SoundscapeRules, Config/Soundscape):
-- the night share of the town's clock, when the next sound comes and from where, how loud a day or night group is
-- now, and a gust's swell
local SoundscapeRules = require("../src/shared/Util/SoundscapeRules")
local Soundscape = require("../src/shared/Config/Soundscape")
local expect = require("./lib/expect")

local NIGHT = Soundscape.NIGHT

local function each(fn: (any, string) -> ())
	for _, spot in Soundscape.TOWN.day do
		fn(spot, "town day")
	end
	for _, spot in Soundscape.TOWN.night do
		fn(spot, "town night")
	end
	for zone, list in Soundscape.WILD do
		for _, spot in list do
			fn(spot, `wild {zone}`)
		end
	end
	for zone, list in Soundscape.FRONTIER do
		for _, spot in list do
			fn(spot, `frontier {zone}`)
		end
	end
end

return {
	["night share: none by day, in at dusk, full at night, out by morning"] = function()
		expect.equal(SoundscapeRules.nightShare(12, NIGHT), 0, "noon")
		expect.equal(SoundscapeRules.nightShare(NIGHT.from - 0.1, NIGHT), 0, "before dusk")
		expect.near(SoundscapeRules.nightShare((NIGHT.from + NIGHT.full) / 2, NIGHT), 0.5, 1e-9, "half way in")
		expect.equal(SoundscapeRules.nightShare(23, NIGHT), 1, "late night")
		expect.equal(SoundscapeRules.nightShare(1, NIGHT), 1, "after midnight")
		expect.near(SoundscapeRules.nightShare((NIGHT.fade + NIGHT.gone) / 2, NIGHT), 0.5, 1e-9, "half way out")
		expect.equal(SoundscapeRules.nightShare(7, NIGHT), 0, "morning")
	end,

	["the next sound: somewhere in its every range"] = function()
		expect.equal(SoundscapeRules.nextAt(100, { 3, 7 }, 0), 103)
		expect.equal(SoundscapeRules.nextAt(100, { 3, 7 }, 1), 107)
		expect.equal(SoundscapeRules.nextAt(100, { 3, 7 }, 0.5), 105)
	end,

	["where it comes from: any direction, within its distance and height"] = function()
		local spot = Soundscape.TOWN.day[1]
		for _, rolls in { { 0, 0, 0 }, { 0.25, 1, 1 }, { 0.6, 0.4, 0.5 }, { 0.99, 0.01, 0.9 } } do
			local offset = SoundscapeRules.spotOffset(rolls[1], rolls[2], rolls[3], spot)
			local flat = math.sqrt(offset.x * offset.x + offset.z * offset.z)
			assert(flat >= spot.distance[1] - 1e-9 and flat <= spot.distance[2] + 1e-9, `distance {flat}`)
			assert(offset.y >= spot.height[1] - 1e-9 and offset.y <= spot.height[2] + 1e-9, `height {offset.y}`)
		end
		local east = SoundscapeRules.spotOffset(0, 0, 0, spot)
		local west = SoundscapeRules.spotOffset(0.5, 0, 0, spot)
		assert(east.x > 0 and west.x < 0, "the angle roll turns it round you")
	end,

	["day sounds fade out with the night, night sounds in; the valleys' don't care"] = function()
		expect.equal(SoundscapeRules.weight("day", 0), 1)
		expect.equal(SoundscapeRules.weight("day", 1), 0)
		expect.equal(SoundscapeRules.weight("night", 0), 0)
		expect.equal(SoundscapeRules.weight("night", 1), 1)
		expect.near(SoundscapeRules.weight("day", 0.25), 0.75, 1e-9)
		expect.equal(SoundscapeRules.weight("zone", 1), 1)
		expect.equal(SoundscapeRules.weight("zone", 0), 1)
	end,

	["a gust swells in, holds and dies away"] = function()
		local gust = Soundscape.GUST
		expect.equal(SoundscapeRules.gustShape(-1, gust), 0, "before it")
		expect.equal(SoundscapeRules.gustShape(0, gust), 0, "starting")
		expect.near(SoundscapeRules.gustShape(gust.rise / 2, gust), 0.5, 1e-9, "rising")
		expect.equal(SoundscapeRules.gustShape(gust.rise + 0.01, gust), 1, "full")
		expect.near(SoundscapeRules.gustShape(gust.seconds - gust.fall / 2, gust), 0.5, 1e-9, "dying")
		expect.equal(SoundscapeRules.gustShape(gust.seconds + 0.1, gust), 0, "gone")
		assert(gust.rise + gust.fall < gust.seconds, "it holds a moment")
	end,

	["every spot is quiet, varied and from round you"] = function()
		each(function(spot, label)
			assert(#spot.ids >= 1, `{label}: sounds`)
			for _, id in spot.ids do
				assert(string.match(id, "^rbxassetid://%d+$"), `{label}: {id}`)
			end
			assert(spot.every[1] > 1 and spot.every[1] < spot.every[2], `{label}: now and then`)
			assert(spot.volume > 0 and spot.volume <= 0.25, `{label}: quiet ({spot.volume})`)
			assert(spot.distance[1] >= 8 and spot.distance[1] < spot.distance[2], `{label}: not in your ear`)
			assert(spot.distance[2] <= spot.range, `{label}: heard where it plays`)
			assert(spot.pitch[1] > 0 and spot.pitch[1] <= spot.pitch[2], `{label}: pitch`)
		end)
		expect.equal(#Soundscape.WILD, 3, "the Wild's three biomes")
		expect.equal(#Soundscape.FRONTIER, 3, "the Frontier's three biomes")
	end,
}
