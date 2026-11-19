--!strict
local AmbienceRules = require("../src/shared/Util/AmbienceRules")
local expect = require("./lib/expect")

return {
	["nextAt: inside its range from now"] = function()
		expect.equal(AmbienceRules.nextAt(100, { 50, 80 }, 0), 150, "low end")
		expect.equal(AmbienceRules.nextAt(100, { 50, 80 }, 1), 180, "high end")
	end,

	["roarVolume: grows room by room"] = function()
		expect.equal(AmbienceRules.roarVolume(0, 6, { 0.15, 0.5 }), 0.15, "start")
		expect.equal(AmbienceRules.roarVolume(6, 6, { 0.15, 0.5 }), 0.5, "the end")
		expect.equal(AmbienceRules.roarVolume(3, 6, { 0.15, 0.5 }) > 0.15, true, "louder midway")
		expect.equal(AmbienceRules.roarVolume(9, 6, { 0.15, 0.5 }), 0.5, "capped")
	end,

	-- Owner 2026-11-19 ("do you have any suggestions on making frontier and dungeon better?", then "do 1 and 2 now"):
	-- the Dungeon's music climbs with the run. It starts quiet, low and muffled; every step done makes it louder,
	-- higher and clearer, full at the Hydra's door
	["the music climbs with the run: quiet, low and muffled at the start, full at the chamber"] = function()
		local Dungeon = require("../src/shared/Config/Dungeon")
		local climb = Dungeon.AMBIENCE.climb
		local steps = #Dungeon.STEPS
		local v0, p0, m0 = AmbienceRules.climb(0, steps, climb)
		expect.equal(v0, climb.volume[1])
		expect.equal(p0, climb.pitch[1])
		expect.equal(m0, climb.muffle[1])
		local v1, p1, m1 = AmbienceRules.climb(steps, steps, climb)
		expect.equal(v1, climb.volume[2])
		expect.equal(p1, climb.pitch[2])
		expect.equal(m1, climb.muffle[2])
		local last = v0
		for done = 1, steps do
			local volume = AmbienceRules.climb(done, steps, climb)
			assert(volume > last, `step {done}: louder than the one before`)
			last = volume
		end
		local over = AmbienceRules.climb(steps + 3, steps, climb)
		expect.equal(over, climb.volume[2], "never past full")
		assert(climb.volume[1] < 1 and climb.volume[2] > 1, "under the old level at the start, over it at the end")
		assert(climb.volume[2] <= 2, "the owner lowered this music twice: the top stays modest")
		assert(climb.pitch[1] >= 0.9 and climb.pitch[2] == 1, "a small rise to its own pitch, never a chipmunk")
		assert(climb.muffle[1] < 0 and climb.muffle[2] == 0, "muffled first, clear at the end")
		-- the cave: every sound in the Dungeon echoes (SoundService.AmbientReverb)
		expect.equal(Dungeon.AMBIENCE.reverb, "Cave")
	end,

	["heartbeat: silent early, full at the chamber"] = function()
		expect.equal(AmbienceRules.heartbeat(2, 4, 6), 0, "early")
		expect.equal(AmbienceRules.heartbeat(6, 4, 6), 1, "at the chamber")
		local mid = AmbienceRules.heartbeat(5, 4, 6)
		expect.equal(mid > 0 and mid < 1, true, "rising")
	end,

	["heartbeat: heard already at the `from` step (the lock), full after it"] = function()
		expect.equal(AmbienceRules.heartbeat(4, 5, 6), 0, "before the lock")
		expect.equal(AmbienceRules.heartbeat(5, 5, 6), 0.5, "at the lock")
		expect.equal(AmbienceRules.heartbeat(6, 5, 6), 1, "the chamber")
	end,
}
