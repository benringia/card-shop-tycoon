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

-- The boss-fight controls (spec 2026-11-02-you-in-the-fight-design, layout A): a big Attack bottom-right (where the
-- jump button was: there's no jumping in boss fights), Dodge left of it, the sword Skill above Dodge, Pet skill above
-- Attack with the creature's Signature above it, and small Swap and Run buttons along the bottom, all clear of the
-- thumbstick (bottom-left). Sizes follow the screen's height; every button is at least 48 px.
export type CombatButtons = { attack: Rect, dodge: Rect, skill: Rect, pet: Rect, signature: Rect, swap: Rect, run: Rect }
function UiLayout.combatButtons(view: Size): CombatButtons
	local u = math.clamp(view.h * 0.17, 52, 110)
	local function dim(k: number): number
		return math.max(48, k * u)
	end
	local margin = 0.35 * u
	local gap = 0.25 * u
	local attack = { w = dim(1.7), h = dim(1.45), x = 0, y = 0 }
	attack.x, attack.y = view.w - margin - attack.w, view.h - margin * 1.2 - attack.h
	local dodge = { w = dim(1.05), h = dim(0.95), x = 0, y = 0 }
	dodge.x, dodge.y = attack.x - gap - dodge.w, view.h - margin - dodge.h
	local skill = { w = dim(1.1), h = dim(1), x = 0, y = 0 }
	skill.x, skill.y = attack.x - gap - skill.w, dodge.y - gap - skill.h
	local pet = { w = dim(1.1), h = dim(1), x = 0, y = 0 }
	pet.x, pet.y = view.w - margin - pet.w, attack.y - 0.3 * u - pet.h
	local signature = { w = dim(0.85), h = dim(0.8), x = 0, y = 0 }
	signature.x, signature.y = pet.x + (pet.w - signature.w) / 2, pet.y - gap - signature.h
	local run = { w = dim(0.75), h = dim(0.75), x = 0, y = 0 }
	run.x, run.y = dodge.x - 0.4 * u - run.w, view.h - margin - run.h
	local swap = { w = run.w, h = run.h, x = run.x - 0.2 * u - run.w, y = run.y }
	return { attack = attack, dodge = dodge, skill = skill, pet = pet, signature = signature, swap = swap, run = run }
end

return UiLayout
