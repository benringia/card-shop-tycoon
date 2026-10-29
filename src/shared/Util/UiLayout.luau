--!strict
-- Where screen pieces go: tooltips beside or above what they describe (never over it, always on screen) and the
-- card inspector's 3D card, sized by the camera, with its right edge on the info panel. Screen pixels, origin top
-- left. Pure (no requires, no Roblox APIs), so tests/ can run it in Lune.
local UiLayout = {}

export type Rect = { x: number, y: number, w: number, h: number }
export type Size = { w: number, h: number }
export type Point = { x: number, y: number }

local function clamp(value: number, low: number, high: number): number
	return math.clamp(value, low, math.max(low, high))
end

-- Centred over the anchor, or under it when there's no room above (never over it), kept on screen
function UiLayout.above(anchor: Rect, tip: Size, screen: Size, gap: number): Point
	local y = anchor.y - gap - tip.h
	if y < 0 then
		y = anchor.y + anchor.h + gap
	end
	return {
		x = clamp(anchor.x + anchor.w / 2 - tip.w / 2, 0, screen.w - tip.w),
		y = clamp(y, 0, screen.h - tip.h),
	}
end

-- Right of the anchor, else left of it, else above (or under) `around` (the anchor when not given: the binder passes
-- the hovered pocket while the anchor is the whole book); level with the anchor's top, kept on screen
function UiLayout.beside(anchor: Rect, tip: Size, screen: Size, gap: number, around: Rect?): Point
	local right = anchor.x + anchor.w + gap
	local left = anchor.x - gap - tip.w
	local x
	if right + tip.w <= screen.w then
		x = right
	elseif left >= 0 then
		x = left
	else
		return UiLayout.above(around or anchor, tip, screen, gap)
	end
	return { x = x, y = clamp(anchor.y, 0, screen.h - tip.h) }
end

-- The inspector's card: how far sideways (studs, + right) to put it so its right edge lands on cardRightPx (but its
-- left edge never closer than marginPx to the screen's), and where it shows. fovDeg is the camera's vertical field
-- of view; offsetY lifts the card (studs).
function UiLayout.inspectorCard(view: Size, fovDeg: number, distance: number, card: Size, offsetY: number, cardRightPx: number, marginPx: number): (number, Rect)
	local pixelsPerStud = view.h / (2 * distance * math.tan(math.rad(fovDeg / 2)))
	local width = card.w * pixelsPerStud
	local height = card.h * pixelsPerStud
	local left = math.max(cardRightPx - width, marginPx)
	local offset = (left + width / 2 - view.w / 2) / pixelsPerStud
	return offset, { x = left, y = view.h / 2 - offsetY * pixelsPerStud - height / 2, w = width, h = height }
end

-- The card view: the 3D card (cardW) and its info panel (panelW) side by side, centred on the screen as a pair, the
-- card never closer than margin to the left edge; when the pair doesn't fit, the panel keeps margin from the right
-- edge first. Returns the panel's left edge.
function UiLayout.detailPanelLeft(viewW: number, cardW: number, gap: number, panelW: number, margin: number): number
	local centred = (viewW - (cardW + gap + panelW)) / 2 + cardW + gap
	return math.min(math.max(centred, margin + cardW + gap), viewW - margin - panelW)
end

return UiLayout
