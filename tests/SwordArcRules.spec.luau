--!strict
-- The sword swing arcs' maths (Util/SwordArcRules; spec 2026-11-04-sword-moves-design, "Candy sparkle arc")
local SwordArcRules = require("../src/shared/Util/SwordArcRules")
local expect = require("./lib/expect")

-- A transparency NumberSequence's rules: starts at 0, ends at 1, times rising, values 0-1, at most 20 points
local function validSequence(points: { { number } }, label: string)
	expect.equal(#points >= 2 and #points <= 20, true, `{label}: point count {#points}`)
	expect.equal(points[1][1], 0, `{label}: starts at 0`)
	expect.equal(points[#points][1], 1, `{label}: ends at 1`)
	for index, point in points do
		expect.equal(point[2] >= 0 and point[2] <= 1, true, `{label}: value {point[2]} at {index}`)
		if index > 1 then
			expect.equal(point[1] > points[index - 1][1], true, `{label}: times rise at {index}`)
		end
	end
end

local function valueAt(points: { { number } }, time: number): number
	for index = 2, #points do
		local a, b = points[index - 1], points[index]
		if time <= b[1] then
			local t = (time - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * t
		end
	end
	return points[#points][2]
end

return {
	["a Beam's curve size bends it into a circular arc: 4/3 r tan(sweep / 4)"] = function()
		expect.near(SwordArcRules.curveSize(3, 90), 4 / 3 * 3 * math.tan(math.rad(22.5)), 1e-9)
		expect.near(SwordArcRules.curveSize(3, -90), SwordArcRules.curveSize(3, 90), 1e-9, "either way round")
		expect.near(SwordArcRules.curveSize(2, 180), 4 / 3 * 2, 1e-9, "a half circle")
	end,

	["an arc's points and tangents run round its circle from its start angle"] = function()
		local x, y = SwordArcRules.point(2, 0, 90, 0)
		expect.near(x, 2, 1e-9)
		expect.near(y, 0, 1e-9)
		x, y = SwordArcRules.point(2, 0, 90, 1)
		expect.near(x, 0, 1e-9, "a quarter turn on")
		expect.near(y, 2, 1e-9)
		local tx, ty = SwordArcRules.tangent(0, 90, 0)
		expect.near(tx, 0, 1e-9, "going the sweep's way")
		expect.near(ty, 1, 1e-9)
		tx, ty = SwordArcRules.tangent(0, -90, 0)
		expect.near(ty, -1, 1e-9, "a backward sweep goes the other way")
	end,

	["the wipe lights the arc up to its head, brightest at the head, dark ahead of it"] = function()
		local points = SwordArcRules.wipe(0.5, 0.6, 0.04, 0)
		validSequence(points, "half way")
		expect.near(valueAt(points, 0.5), 0, 1e-9, "the head is bright")
		expect.near(valueAt(points, 0.8), 1, 1e-9, "nothing ahead of the head")
		expect.equal(valueAt(points, 0.2) > 0 and valueAt(points, 0.2) < 1, true, "fading behind it")
		points = SwordArcRules.wipe(0.9, 0.3, 0.04, 0)
		validSequence(points, "a short trail")
		expect.near(valueAt(points, 0.3), 1, 1e-9, "past the trail's end it's dark")
	end,

	["the wipe's edges: not started, finished, and fading out"] = function()
		local none = SwordArcRules.wipe(0, 0.6, 0.04, 0)
		validSequence(none, "not started")
		expect.near(valueAt(none, 0.5), 1, 1e-9, "nothing shows yet")
		local done = SwordArcRules.wipe(1, 0.6, 0.04, 0)
		validSequence(done, "finished")
		expect.near(valueAt(done, 1), 0, 1e-9, "the head at the end")
		local fading = SwordArcRules.wipe(1, 0.6, 0.04, 0.5)
		validSequence(fading, "fading")
		expect.near(valueAt(fading, 1), 0.5, 1e-9, "half faded")
		local gone = SwordArcRules.wipe(1, 0.6, 0.04, 1)
		validSequence(gone, "faded out")
		expect.near(valueAt(gone, 1), 1, 1e-9)
		validSequence(SwordArcRules.wipe(0.98, 0.6, 0.04, 0), "the head's soft edge past the end")
	end,

	["a hit's burst sits on the foe's side facing the attacker, never past the attacker"] = function()
		local x, z = SwordArcRules.hitPoint(0, 0, 10, 20, 0, 0.7)
		expect.near(x, 7, 1e-9)
		expect.near(z, 0, 1e-9)
		x, z = SwordArcRules.hitPoint(0, 0, 10, 3, 0, 0.7)
		expect.near(x, 3, 1e-9, "the attacker inside that: at the attacker")
		x, z = SwordArcRules.hitPoint(5, 5, 10, 5, 5, 0.7)
		expect.near(x, 5, 1e-9, "on top of it: its centre")
		expect.near(z, 5, 1e-9)
	end,
}
