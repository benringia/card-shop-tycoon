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
-- thumbstick (bottom-left). Sizes follow the screen's height; every button is at least 48 px. With a mouse
-- (`noAttack`: a click attacks, owner 2026-11-03) there's no Attack button: the Pet button takes its corner and Dodge
-- and Skill move up beside it.
export type CombatButtons = { attack: Rect, dodge: Rect, skill: Rect, pet: Rect, signature: Rect, swap: Rect, run: Rect }
function UiLayout.combatButtons(view: Size, noAttack: boolean?): CombatButtons
	local u = math.clamp(view.h * 0.17, 52, 110)
	local function dim(k: number): number
		return math.max(48, k * u)
	end
	local margin = 0.35 * u
	local gap = 0.25 * u
	local attack = { w = dim(1.7), h = dim(1.45), x = 0, y = 0 }
	attack.x, attack.y = view.w - margin - attack.w, view.h - margin * 1.2 - attack.h
	local pet = { w = dim(1.1), h = dim(1), x = 0, y = 0 }
	pet.x = view.w - margin - pet.w
	pet.y = if noAttack then view.h - margin - pet.h else attack.y - 0.3 * u - pet.h
	local column = if noAttack then pet.x else attack.x -- Dodge and Skill stand left of this
	local dodge = { w = dim(1.05), h = dim(0.95), x = 0, y = 0 }
	dodge.x, dodge.y = column - gap - dodge.w, view.h - margin - dodge.h
	local skill = { w = dim(1.1), h = dim(1), x = 0, y = 0 }
	skill.x, skill.y = column - gap - skill.w, dodge.y - gap - skill.h
	local signature = { w = dim(0.85), h = dim(0.8), x = 0, y = 0 }
	signature.x, signature.y = pet.x + (pet.w - signature.w) / 2, pet.y - gap - signature.h
	local run = { w = dim(0.75), h = dim(0.75), x = 0, y = 0 }
	run.x, run.y = dodge.x - 0.4 * u - run.w, view.h - margin - run.h
	local swap = { w = run.w, h = run.h, x = run.x - 0.2 * u - run.w, y = run.y }
	return { attack = attack, dodge = dodge, skill = skill, pet = pet, signature = signature, swap = swap, run = run }
end

-- A wild monster fight's controls (owner 2026-11-03, layout A: the boss HUD's look without the sword): the Pet button
-- big in Attack's place, the Signature above it, Run left of it and Call in (the Swap button) left of Run, sized like
-- the boss buttons
export type WildButtons = { pet: Rect, signature: Rect, swap: Rect, run: Rect }

function UiLayout.wildButtons(view: Size): WildButtons
	local boss = UiLayout.combatButtons(view)
	local u = math.clamp(view.h * 0.17, 52, 110)
	local gap = 0.25 * u
	local pet = boss.attack
	local signature = { w = boss.pet.w, h = boss.pet.h, x = pet.x + (pet.w - boss.pet.w) / 2, y = boss.pet.y }
	local run = { w = boss.dodge.w, h = boss.dodge.h, x = pet.x - gap - boss.dodge.w, y = boss.dodge.y }
	local swap = { w = boss.dodge.w, h = boss.dodge.h, x = run.x - gap - boss.dodge.w, y = run.y }
	return { pet = pet, signature = signature, swap = swap, run = run }
end

export type FiltersLook = {
	top: number,
	bottom: number,
	shortTop: number,
	shortBottom: number,
	header: number,
	inset: number,
	footer: number,
	edge: number,
	gap: number,
	search: number,
	headingRow: number,
	rarityRows: number,
}

-- The Filters body's content height (Config/FiltersLayout): the search box, the SHOW / SORT BY / RARITY headings,
-- the two segmented switches (`segmentHit` px tap rows) and the rarity tags' rows (`tagHit` px each, wrapping with a
-- gap between them), a gap between each piece and the edge room above and below
function UiLayout.filtersBody(look: FiltersLook, segmentHit: number, tagHit: number): number
	local rows = tagHit * look.rarityRows + look.gap * (look.rarityRows - 1)
	local pieces = look.search + look.headingRow * 3 + segmentHit * 2 + rows
	return pieces + look.gap * 6 + look.edge * 2
end

-- The binder's Filters window on a screen `height` px tall: its top and height, as tall as its content (`body`, from
-- filtersBody, plus the header and footer). Under the binder's corner buttons, above the set progress card, where it
-- fits there; else from near the top (over those buttons), as much of it as the screen holds (the body scrolls).
function UiLayout.filtersFrame(height: number, look: FiltersLook, body: number): (number, number)
	local want = body + look.header + look.inset * 2 + look.footer
	if height - look.top - look.bottom >= want then
		return look.top, want
	end
	return look.shortTop, math.min(want, height - look.shortTop - look.shortBottom)
end

return UiLayout
