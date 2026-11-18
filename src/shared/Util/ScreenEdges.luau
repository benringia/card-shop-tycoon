--!strict
-- Covers reach the very edges of the screen (owner 2026-11-18: a phone's cinema bars stopped short of its sides, "fix
-- this black thing on the screen. check other cinematics for this problem too"). A gui keeping a phone's safe area
-- (clear of the notch, the rounded corners and the home bar) starts inside it, so a cover drawn there needs the whole
-- screen in the gui's own space: `rect`. The tutorial's spotlight dims all of it but one button: `around`. Client
-- Util/ScreenCover measures the screen. Pure, Lune-tested.
local ScreenEdges = {}

export type Rect = { x: number, y: number, w: number, h: number }

-- The whole screen in a gui's own space: `full` is a full-screen gui's (ScreenInsets None) absolute rect, the gui's
-- absolute top-left is (`originX`, `originY`)
function ScreenEdges.rect(full: Rect, originX: number, originY: number): Rect
	return { x = full.x - originX, y = full.y - originY, w = full.w, h = full.h }
end

-- The spotlight's four dims (top, bottom, left, right) over `screen` but `hole` (the same space), in whole pixels so
-- they meet without a bright seam; a hole past an edge leaves that side's dim empty, never negative
function ScreenEdges.around(screen: Rect, hole: Rect): { Rect }
	local left, top = math.floor(hole.x), math.floor(hole.y)
	local right, bottom = math.ceil(hole.x + hole.w), math.ceil(hole.y + hole.h)
	local startX, startY = math.floor(screen.x), math.floor(screen.y)
	local endX, endY = math.ceil(screen.x + screen.w), math.ceil(screen.y + screen.h)
	local tall = math.max(0, bottom - top)
	return {
		{ x = startX, y = startY, w = endX - startX, h = math.max(0, top - startY) },
		{ x = startX, y = bottom, w = endX - startX, h = math.max(0, endY - bottom) },
		{ x = startX, y = top, w = math.max(0, left - startX), h = tall },
		{ x = right, y = top, w = math.max(0, endX - right), h = tall },
	}
end

return ScreenEdges
