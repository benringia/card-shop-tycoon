--!strict
local MusicRules = require("../src/shared/Util/MusicRules")
local Music = require("../src/shared/Config/Music")
local Town = require("../src/shared/Config/Town")
local expect = require("./lib/expect")

local BOUNDS = { HALF_X = 130, HALF_Z = 110 }

return {
	["the town is the island inside the hedge, plus a margin to fade in and out"] = function()
		expect.equal(MusicRules.inTown(0, 0, BOUNDS, 40), true, "the plaza")
		expect.equal(MusicRules.inTown(-165, 140, BOUNDS, 40), true, "just past the hedge")
		expect.equal(MusicRules.inTown(171, 0, BOUNDS, 40), false, "past the margin east")
		expect.equal(MusicRules.inTown(0, -151, BOUNDS, 40), false, "past the margin south")
		expect.equal(MusicRules.inTown(900, 400, BOUNDS, 40), false, "the Wild valley")
	end,

	["the tracks take turns and wrap round"] = function()
		expect.equal(MusicRules.nextTrack(0, 2), 1, "nothing played yet: the first")
		expect.equal(MusicRules.nextTrack(1, 2), 2)
		expect.equal(MusicRules.nextTrack(2, 2), 1)
		expect.equal(MusicRules.nextTrack(1, 1), 1, "one track: it repeats")
	end,

	["the town music is quiet, licensed and fades gently"] = function()
		local town = Music.TOWN
		expect.equal(#town.tracks >= 1, true)
		for _, id in town.tracks do
			expect.equal(string.match(id, "^rbxassetid://%d+$") ~= nil, true, id)
		end
		expect.equal(town.volume > 0 and town.volume <= 0.2, true, "under the birds and the wind")
		expect.equal(town.fade >= 1, true)
		expect.equal(town.margin > 0, true)
		expect.equal(MusicRules.inTown(0, 0, Town.BOUNDS, town.margin), true, "the plaza is in town with the real numbers")
	end,
}
