--!strict
-- A beaten monster's knockout flight (owner 2026-11-18, pick A "make it smooth"; Config/MonsterKO): launched away from
-- the winner, bouncing on the ground, settling on its back, the same at any frame rate, done before the server lets
-- it go.
local MonsterKOMotion = require("../src/shared/Util/MonsterKOMotion")
local MonsterKO = require("../src/shared/Config/MonsterKO")
local expect = require("./lib/expect")

local GROUND = 10
local HEIGHT, DEPTH = 3, 2.4 -- a Mossling-ish body: taller than long

-- Flies a knockout over flat ground at `fps` frames a second; the frames' states, the events and when it settled
local function fly(fps: number, power: number?, dirX: number?, dirZ: number?): ({ MonsterKOMotion.State }, { string }, number)
	local state = MonsterKOMotion.launch(0, GROUND + HEIGHT / 2, 0, dirX or 1, dirZ or 0, MonsterKO, power or 1)
	local frames, events = { state }, {}
	local dt = 1 / fps
	local clock = 0
	while not state.settled and clock < 5 do
		local event
		state, event = MonsterKOMotion.step(state, dt, GROUND, HEIGHT, DEPTH, MonsterKO)
		clock += dt
		table.insert(frames, state)
		if event then
			table.insert(events, event)
		end
	end
	return frames, events, clock
end

return {
	["it's launched away from the winner, up first"] = function()
		local state = MonsterKOMotion.launch(0, 5, 0, 3, 4, MonsterKO, 1)
		expect.near(state.vx, 0.6 * MonsterKO.speed, 1e-9, "along the way from the winner")
		expect.near(state.vz, 0.8 * MonsterKO.speed, 1e-9)
		expect.equal(state.vy, MonsterKO.up, "up")
		local still = MonsterKOMotion.launch(0, 5, 0, 0, 0, MonsterKO, 1)
		expect.equal(still.vx, 0, "no way given: straight up")
		expect.equal(still.vz, 0)
		local elite = MonsterKOMotion.launch(0, 5, 0, 1, 0, MonsterKO, MonsterKO.elite.power)
		assert(elite.vx > MonsterKO.speed and elite.vy > MonsterKO.up, "an elite is hit harder")
	end,

	["it never sinks into the ground, bounces, then settles within its longest flight"] = function()
		local frames, events, clock = fly(60)
		for index, state in frames do
			local radius = MonsterKOMotion.halfHeight(state.angle, HEIGHT, DEPTH)
			assert(state.y >= GROUND + radius - 1e-6 or index == 1, `frame {index} stays above the ground`)
		end
		expect.equal(events[1], "bounce", "it bounces first")
		expect.equal(events[#events], "settle", "then settles")
		assert(clock <= MonsterKO.maxFlight + 1e-6, `settled within {MonsterKO.maxFlight} s (took {clock})`)
		local last = frames[#frames]
		assert(last.x > 5 and last.x < 25, `it lands a few studs away (x = {last.x})`)
		expect.equal(last.vx, 0, "still once settled")
	end,

	["the same flight at any frame rate (smooth on a slow phone too)"] = function()
		local fast = fly(120)
		local slow = fly(20)
		local a, b = fast[#fast], slow[#slow]
		expect.near(a.x, b.x, 0.6, "lands in the same place")
		expect.near(a.angle, b.angle, 25, "turned about as far")
	end,

	["an elite flies further"] = function()
		local normal = fly(60)
		local elite = fly(60, MonsterKO.elite.power)
		assert(elite[#elite].x > normal[#normal].x + 1, "further")
	end,

	["a wall bounces it back, losing speed; one it moves away from doesn't"] = function()
		local state = MonsterKOMotion.launch(0, 5, 0, 1, 0, MonsterKO, 1)
		local bumped = MonsterKOMotion.bump(state, -1, 0, MonsterKO)
		assert(bumped.vx < 0, "back the way it came")
		expect.near(math.abs(bumped.vx), MonsterKO.speed * MonsterKO.bump, 1e-9, "slower")
		local away = MonsterKOMotion.bump(state, 1, 0, MonsterKO)
		expect.equal(away.vx, state.vx, "a wall behind it changes nothing")
	end,

	["it settles on its back: a tall body on its back or face, a long one feet up; never standing"] = function()
		for _, angle in { 0, 10, 80, 95, 170, 200, 260, 300, 350, 400, 620, 700 } do
			local tallRest = MonsterKOMotion.rest(angle, 3, 2)
			assert(tallRest % 180 == 90, `a tall body lies on its back or face (from {angle}: {tallRest})`)
			assert(math.abs(tallRest - angle) <= 135, `close to where it landed (from {angle}: {tallRest})`)
			local longRest = MonsterKOMotion.rest(angle, 1.5, 3.5)
			assert(longRest % 360 == 180, `a long body lies feet up (from {angle}: {longRest})`)
			assert(math.abs(longRest - angle) <= 225, `close to where it landed (from {angle}: {longRest})`)
		end
	end,

	["its height over the ground as it turns: its height upright, its length on its back"] = function()
		expect.near(MonsterKOMotion.halfHeight(0, 3, 2), 1.5, 1e-9)
		expect.near(MonsterKOMotion.halfHeight(90, 3, 2), 1, 1e-9)
		expect.near(MonsterKOMotion.halfHeight(180, 3, 2), 1.5, 1e-9)
		assert(MonsterKOMotion.halfHeight(45, 3, 2) > 1.5, "a corner down: higher")
	end,

	["the whole knockout is over before the server lets the monster go"] = function()
		local longest = MonsterKO.hitStop + MonsterKO.maxFlight + MonsterKO.settleSeconds + MonsterKO.holdSeconds + MonsterKO.poofSeconds
		assert(longest < MonsterKO.SERVER_SECONDS, `{longest} s < {MonsterKO.SERVER_SECONDS} s`)
		assert(MonsterKO.hitStop <= 0.1, "a beat, not a stall")
	end,
}
