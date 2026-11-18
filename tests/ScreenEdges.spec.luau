--!strict
-- Covers reach the very edges of the screen (owner 2026-11-18, a phone's cinema bars stopping short of its sides: "fix
-- this black thing on the screen. check other cinematics for this problem too"). Numbers from Studio's phone simulator:
-- the whole screen 874 x 401 at (-62, -78), the safe area (IgnoreGuiInset guis) 750 x 381 at (0, -58), the HUD's space
-- (CoreUISafeInsets) 750 x 323 at (0, 0).
local ScreenEdges = require("../src/shared/Util/ScreenEdges")
local expect = require("./lib/expect")

local FULL = { x = -62, y = -78, w = 874, h = 401 }

local function area(rect: ScreenEdges.Rect): number
	return rect.w * rect.h
end

return {
	["the whole screen in a gui's own space: past the notch's bands, the top bar and the corners"] = function()
		local safe = ScreenEdges.rect(FULL, 0, -58)
		expect.equal(safe.x, -62, "62 px left of a safe gui's edge (the notch's band)")
		expect.equal(safe.y, -20, "20 px above its top")
		expect.equal(safe.w, 874, "the whole width")
		expect.equal(safe.h, 401, "the whole height")
		local hud = ScreenEdges.rect(FULL, 0, 0)
		expect.equal(hud.y, -78, "the HUD's space starts under the top bar: the screen's top is 78 px above it")
		local computer = ScreenEdges.rect({ x = 0, y = -58, w = 1280, h = 720 }, 0, -58)
		expect.equal(computer.x, 0, "a computer's safe gui is the whole screen already")
		expect.equal(computer.y, 0, "no band above it")
	end,

	["the spotlight's four dims cover the whole screen but the button"] = function()
		local screen = ScreenEdges.rect(FULL, 0, 0)
		local hole = { x = 100, y = 200, w = 50, h = 40 }
		local dims = ScreenEdges.around(screen, hole)
		expect.equal(#dims, 4, "top, bottom, left, right")
		local top, bottom, left, right = dims[1], dims[2], dims[3], dims[4]
		expect.equal(top.x, -62, "the top dim starts at the screen's left edge, past the safe area")
		expect.equal(top.y, -78, "and at its very top, over the top bar")
		expect.equal(top.w, 874, "the whole width")
		expect.equal(top.y + top.h, 200, "down to the button")
		expect.equal(bottom.y, 240, "the bottom dim from the button's bottom")
		expect.equal(bottom.y + bottom.h, 323, "to the screen's bottom")
		expect.equal(left.x, -62, "the left dim from the screen's left edge")
		expect.equal(left.x + left.w, 100, "to the button")
		expect.equal(right.x, 150, "the right dim from the button's right")
		expect.equal(right.x + right.w, 812, "to the screen's right edge")
		local covered = 0
		for _, dim in dims do
			covered += area(dim)
		end
		expect.equal(covered, area(screen) - area(hole), "every pixel but the button's, none twice")
	end,

	["whole pixels, and a button past an edge leaves that side's dim empty, never negative"] = function()
		local screen = ScreenEdges.rect(FULL, 0, 0)
		local dims = ScreenEdges.around(screen, { x = 10.4, y = 20.6, w = 5.2, h = 5.1 })
		expect.equal(dims[1].h, 20 - -78, "the top dim to the button's top, floored")
		expect.equal(dims[2].y, 26, "the bottom dim from its bottom, rounded up (no bright seam)")
		expect.equal(dims[4].x, 16, "the right dim from its right, rounded up")
		local off = ScreenEdges.around(screen, { x = -100, y = 50, w = 30, h = 30 })
		expect.equal(off[3].w, 0, "a button past the left edge: no left dim")
		local below = ScreenEdges.around(screen, { x = 100, y = 400, w = 30, h = 30 })
		expect.equal(below[2].h, 0, "a button past the bottom: no bottom dim")
	end,
}
