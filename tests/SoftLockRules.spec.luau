--!strict
-- The soft lock (owner 2026-11-15, look A: a gold ring under your target and an arrow over it; no camera lock): which
-- enemy Tab or the Target button picks next, which one a tap lands on, and when a lock lets go
local SoftLockRules = require("../src/shared/Util/SoftLockRules")
local SoftLock = require("../src/shared/Config/SoftLock")
local SwordFx = require("../src/shared/Config/SwordFx")
local expect = require("./lib/expect")

-- degrees round the colour wheel
local function hue(color: { number }): number
	local r, g, b = color[1] / 255, color[2] / 255, color[3] / 255
	local high, low = math.max(r, g, b), math.min(r, g, b)
	if high == low then
		return 0
	end
	local h
	if high == r then
		h = ((g - b) / (high - low)) % 6
	elseif high == g then
		h = (b - r) / (high - low) + 2
	else
		h = (r - g) / (high - low) + 4
	end
	return h * 60
end

-- the player at (0, 0); the boss far, two adds nearer
local TARGETS = {
	{ id = "b:m", x = 0, z = 30, radius = 8 }, -- edge 22
	{ id = "b:x", x = 10, z = 0, radius = 2 }, -- edge 8
	{ id = "b:y", x = -15, z = 0, radius = 2 }, -- edge 13
}

return {
	-- Owner 2026-11-16 (pick A): "lock target color could easily be mistaken for a boss attack ring": nothing of the
	-- marker lies on the ground (the ground is for danger only) and its colour is far round the wheel from the boss
	-- warning's orange
	["the target marker can never pass for a boss's warning ring"] = function()
		expect.isNil((SoftLock :: any).RING_MIN, "no ring on the ground")
		expect.isNil((SoftLock :: any).SEGMENTS, "no ring pieces")
		local gap = math.abs(hue(SoftLock.LOCKED.outline) - hue(SwordFx.RING_COLOR))
		gap = math.min(gap, 360 - gap)
		assert(gap >= 120, `its colour sits far from the warning's orange ({math.floor(gap)} degrees)`)
	end,

	["Tab picks the nearest first, then on outward, then round again"] = function()
		expect.equal(SoftLockRules.cycle(TARGETS, nil, 0, 0), "b:x")
		expect.equal(SoftLockRules.cycle(TARGETS, "b:x", 0, 0), "b:y")
		expect.equal(SoftLockRules.cycle(TARGETS, "b:y", 0, 0), "b:m")
		expect.equal(SoftLockRules.cycle(TARGETS, "b:m", 0, 0), "b:x", "round again")
		expect.equal(SoftLockRules.cycle(TARGETS, "b:gone", 0, 0), "b:x", "a lock that's gone starts over")
		expect.isNil(SoftLockRules.cycle({}, nil, 0, 0))
	end,

	["a lock holds while its enemy stands"] = function()
		expect.equal(SoftLockRules.has(TARGETS, "b:y"), true)
		expect.equal(SoftLockRules.has(TARGETS, "b:gone"), false)
		expect.equal(SoftLockRules.has(TARGETS, nil), false)
	end,

	["a tap lands on the enemy under it, the nearest middle when two overlap"] = function()
		local onScreen = {
			{ id = "b:m", x = 500, y = 300, r = 120 },
			{ id = "b:x", x = 640, y = 360, r = 40 },
		}
		expect.equal(SoftLockRules.pick(onScreen, 650, 365, SoftLock.PICK_SLACK), "b:x", "inside both: the nearer middle")
		expect.equal(SoftLockRules.pick(onScreen, 420, 300, SoftLock.PICK_SLACK), "b:m")
		expect.equal(SoftLockRules.pick(onScreen, 640 + 40 + SoftLock.PICK_SLACK - 1, 360, SoftLock.PICK_SLACK), "b:x", "a little slack round small ones")
		expect.isNil(SoftLockRules.pick({ onScreen[2] }, 640 + 40 + SoftLock.PICK_SLACK + 1, 360, SoftLock.PICK_SLACK), "past the slack")
		expect.isNil(SoftLockRules.pick(onScreen, 100, 100, SoftLock.PICK_SLACK), "empty ground")
	end,

	["a tap is short and still; a drag turns the camera"] = function()
		expect.equal(SoftLockRules.isTap(4, 3, 0.15, SoftLock), true)
		expect.equal(SoftLockRules.isTap(40, 0, 0.15, SoftLock), false, "dragged")
		expect.equal(SoftLockRules.isTap(2, 2, 0.8, SoftLock), false, "held")
	end,

	["tapping your target again lets go; another one moves the lock"] = function()
		expect.isNil(SoftLockRules.afterTap("b:x", "b:x"))
		expect.equal(SoftLockRules.afterTap("b:x", "b:y"), "b:y")
		expect.equal(SoftLockRules.afterTap(nil, "b:m"), "b:m")
		expect.equal(SoftLockRules.afterTap("b:x", nil), "b:x", "empty ground keeps it")
	end,
}
