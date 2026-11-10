--!strict
-- Pish's arrival shot (owner 2026-11-10: "the camera be first close to pish's feet while running then slowly panning to
-- his face then zoom out when he's already near you. you can make the cinematic longer")
local ArrivalShot = require("../src/shared/Util/ArrivalShot")
local Pish = require("../src/shared/Config/Pish")
local expect = require("./lib/expect")

local CFG = Pish.ARRIVAL

return {
	["it starts low on his paws"] = function()
		local shot = ArrivalShot.at(0, CFG)
		expect.near(shot.lookUp, CFG.feet.lookUp, 1e-6, "looking at his paws")
		expect.near(shot.up, CFG.feet.up, 1e-6, "the camera near the ground")
		expect.equal(shot.wide, 0, "close on him")
		assert(CFG.feet.lookUp < 0.6 and CFG.feet.up < 1, "paw height (he's 2.6 studs tall)")
	end,

	["it pans slowly up to his face while he runs"] = function()
		expect.near(ArrivalShot.at(CFG.panFrom, CFG).lookUp, CFG.feet.lookUp, 1e-6, "still on his paws")
		expect.near(ArrivalShot.at(CFG.panTo, CFG).lookUp, CFG.face.lookUp, 1e-6, "on his face")
		assert(CFG.face.lookUp > 1.5, "face height")
		local last = -math.huge
		for i = 0, 20 do
			local lookUp = ArrivalShot.at(i / 20, CFG).lookUp
			assert(lookUp >= last - 1e-9, "the pan only goes up")
			last = lookUp
		end
		assert(CFG.panTo - CFG.panFrom >= 0.3, "slowly: over a good part of the run")
	end,

	["it zooms out to the two of you once he's near"] = function()
		expect.equal(ArrivalShot.at(CFG.wideFrom, CFG).wide, 0, "not before he's near")
		expect.near(ArrivalShot.at(1, CFG).wide, 1, 1e-6, "the wide shot when he stops")
		assert(CFG.wideFrom >= CFG.panTo, "after the pan reaches his face")
		local last = -1
		for i = 0, 20 do
			local wide = ArrivalShot.at(i / 20, CFG).wide
			assert(wide >= last, "the zoom only goes out")
			last = wide
		end
		expect.equal(ArrivalShot.at(1.5, CFG).wide, 1, "past the end: held")
		expect.equal(ArrivalShot.at(-1, CFG).wide, 0, "before the start: held")
	end,

	["the cinematic is longer: a run of a few seconds"] = function()
		local seconds = CFG.from / CFG.speed
		assert(seconds >= 4 and seconds <= 7, `the run takes {seconds} s`)
	end,

	["his run comes from the first clear way, else the longest (he never runs through a shelf or a wall)"] = function()
		local want, least = CFG.from, CFG.minRun
		local index, length = ArrivalShot.pickRun({ 8, want + 5, want }, CFG)
		expect.equal(index, 2, "in front is blocked at 8: the next way that's clear all the way")
		expect.equal(length, want)
		index, length = ArrivalShot.pickRun({ 8, 20, 14 }, CFG)
		expect.equal(index, 2, "none clear all the way: the longest")
		expect.equal(length, 20 - CFG.wallGap, "stopping short of what's there")
		index, length = ArrivalShot.pickRun({ 2, 3 }, CFG)
		expect.equal(length, least, "boxed in: a short run all the same")
		assert(least >= 8, "long enough to see him run")
	end,

	["the camera rides on the clearer side of his run"] = function()
		expect.equal(ArrivalShot.pickSide(0, 3), 1, "nothing in the way on the first side")
		expect.equal(ArrivalShot.pickSide(4, 1), -1, "the other side is clearer")
		expect.equal(ArrivalShot.pickSide(2, 2), 1, "a tie: the first side")
	end,
	["the wide shot uses the first angle with a clear view, else the clearest"] = function()
		assert(#CFG.wideAngles >= 3, "a few angles to try")
		expect.equal(ArrivalShot.pickWide({ 1, 0.2, 1 }, CFG), 1, "the first one is clear")
		expect.equal(ArrivalShot.pickWide({ 0.3, 0.95, 1 }, CFG), 2, "the first clear enough")
		expect.equal(ArrivalShot.pickWide({ 0.3, 0.5, 0.4 }, CFG), 2, "none clear: the clearest")
		assert(CFG.wideClear > 0.7 and CFG.wideClear < 1, "nearly the whole way")
	end,
}
