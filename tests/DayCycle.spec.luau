--!strict
-- The town's day cycle (Portal Worlds spec): morning to sunset with a short night, the same for everyone in town;
-- the Wild, the Arena and the boss arenas keep the afternoon look. Pure maths in Util/DayCycle, numbers in Config/DayCycle.
local cycle = require("../src/shared/Config/DayCycle")
local town = require("../src/shared/Config/Town")
local DayCycle = require("../src/shared/Util/DayCycle")
local expect = require("./lib/expect")

local function phaseStart(name: string): number
	local at = 0
	for _, phase in cycle.PHASES do
		if phase.name == name then
			return at
		end
		at += phase.seconds
	end
	error(`no phase {name}`)
end

local function look(name: string): any
	for _, phase in cycle.PHASES do
		if phase.name == name then
			return phase.look
		end
	end
	error(`no phase {name}`)
end

return {
	["a loop is about 20 minutes and morning is the longest phase"] = function()
		expect.equal(DayCycle.loopSeconds(cycle), 1170, "loop")
		local longest = 0
		for _, phase in cycle.PHASES do
			longest = math.max(longest, phase.seconds)
		end
		expect.equal(cycle.PHASES[1].name, "morning", "starts in the morning")
		expect.equal(cycle.PHASES[1].seconds, longest, "morning is the longest")
		local night = 0
		for _, phase in cycle.PHASES do
			if phase.name == "night" then
				night = phase.seconds
			end
		end
		expect.equal(night, 120, "a short night, about 2 minutes")
	end,

	["the sun never runs backwards, even past midnight"] = function()
		local last = DayCycle.lookAt(cycle, 0).clockTime
		for s = 1, DayCycle.loopSeconds(cycle) + 30 do
			local now = DayCycle.lookAt(cycle, s).clockTime
			local step = (now - last) % 24
			assert(step < 6, `the clock jumped back at {s}s: {last} -> {now}`)
			last = now
		end
	end,

	["the sun keeps moving through a phase while its colours hold"] = function()
		local morning = look("morning")
		local early, later = DayCycle.lookAt(cycle, 10), DayCycle.lookAt(cycle, 200)
		expect.equal(early.brightness, morning.brightness, "morning's light holds")
		expect.equal(later.brightness, morning.brightness, "still morning's light")
		assert(later.clockTime > early.clockTime, "the sun moved on")
		expect.near(DayCycle.lookAt(cycle, 0).clockTime, morning.clockTime, 1e-9, "the morning starts at its own time")
	end,

	["sunset holds its look before blending into the night"] = function()
		local sunset = look("sunset")
		local at = DayCycle.lookAt(cycle, phaseStart("sunset") + 10)
		expect.equal(at.brightness, sunset.brightness, "sunset's light")
		expect.equal(at.atmosphere.glare, sunset.atmosphere.glare, "sunset's glare")
		local blending = DayCycle.lookAt(cycle, phaseStart("night") - cycle.BLEND_SECONDS / 2)
		assert(blending.brightness < sunset.brightness and blending.brightness > look("night").brightness, "half way into the night")
	end,

	["the phase at a time wraps round the loop"] = function()
		local name, progress = DayCycle.phaseAt(cycle, 0)
		expect.equal(name, "morning", "start")
		expect.equal(progress, 0, "at its start")
		name = DayCycle.phaseAt(cycle, DayCycle.loopSeconds(cycle) + phaseStart("night") + 5)
		expect.equal(name, "night", "a loop later")
		name = DayCycle.phaseAt(cycle, -5)
		expect.equal(name, "dawn", "just before the start")
	end,

	["colours blend channel by channel and the clock runs forward through midnight"] = function()
		local a, b = look("night"), look("dawn")
		local half = DayCycle.blend(a, b, 0.5)
		expect.near(half.ambient[1], (a.ambient[1] + b.ambient[1]) / 2, 1e-9, "ambient red")
		expect.near(half.atmosphere.density, (a.atmosphere.density + b.atmosphere.density) / 2, 1e-9, "haze density")
		local clock = (a.clockTime + ((b.clockTime + 24 - a.clockTime) % 24) / 2) % 24
		expect.near(half.clockTime, clock, 1e-9, "forward through midnight")
	end,

	["the Wild and the Arena are outside the town; every portal area is inside"] = function()
		expect.equal(DayCycle.inTown(cycle, 0, 1200), false, "the Wild")
		expect.equal(DayCycle.inTown(cycle, 0, -1200), false, "the Arena")
		for _, p in town.WALK_EDGE do
			expect.equal(DayCycle.inTown(cycle, p.x, p.z), true, `walk edge {p.x}, {p.z}`)
		end
	end,

	["/time puts now at the start of that phase"] = function()
		for _, phase in cycle.PHASES do
			local start = DayCycle.startFor(cycle, phase.name, 5000)
			local name, progress = DayCycle.phaseAt(cycle, 5000 - start)
			expect.equal(name, phase.name, "phase")
			expect.near(progress, 0, 1e-9, `{phase.name} at its start`)
		end
	end,

	["the time-lapse runs morning to sunset"] = function()
		expect.near(DayCycle.timelapse(cycle, 0).clockTime, look("morning").clockTime, 1e-9, "starts in the morning")
		expect.near(DayCycle.timelapse(cycle, 1).clockTime, look("sunset").clockTime, 1e-9, "ends at sunset")
		expect.near(DayCycle.timelapse(cycle, 1.5).clockTime, look("sunset").clockTime, 1e-9, "clamps")
		local middle = DayCycle.timelapse(cycle, 0.5).clockTime
		assert(middle > look("morning").clockTime and middle < look("sunset").clockTime, "through the afternoon")
	end,

	["outside the town the look is today's afternoon"] = function()
		expect.equal(DayCycle.fixedLook(cycle).clockTime, 15.5, "afternoon")
		expect.equal(cycle.FIXED, "afternoon", "fixed phase")
	end,
}
