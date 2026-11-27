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
-- A computer's (owner 2026-11-20: "DESKTOP ONLY. make the icons more compact", no Dodge button, Target gone, Run
-- smaller): Shift dodges and Tab targets (the fight locks one by itself), so it draws four, smaller: Skill and the Pet
-- button in a row in the corner, Super over the Pet button (Swap, never shown, left of Skill). Run sits in the top bar
-- there (Config/CombatHud MOUSE_RUN). No attack, dodge, target or run rect.
export type CombatButtons = { attack: Rect, dodge: Rect, skill: Rect, pet: Rect, signature: Rect, swap: Rect, run: Rect, target: Rect }
local function mouseButtons(view: Size): any
	local u = math.clamp(view.h * 0.11, 44, 76)
	local margin = 0.3 * u
	local gap = 0.2 * u
	local pet = { w = 1.1 * u, h = u, x = 0, y = 0 }
	pet.x, pet.y = view.w - margin - pet.w, view.h - margin - pet.h
	local skill = { w = pet.w, h = pet.h, x = pet.x - gap - pet.w, y = pet.y }
	local signature = { w = 0.85 * u, h = 0.8 * u, x = 0, y = 0 }
	-- room between them for Super's name or its lock's pill
	signature.x, signature.y = pet.x + (pet.w - signature.w) / 2, pet.y - 0.32 * u - signature.h
	local small = math.max(32, 0.5 * u)
	local swap = { w = small, h = small, x = skill.x - gap - small, y = view.h - margin - small }
	return { skill = skill, pet = pet, signature = signature, swap = swap }
end

function UiLayout.combatButtons(view: Size, noAttack: boolean?): CombatButtons
	if noAttack then
		return mouseButtons(view)
	end
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
	-- the soft lock's Target (owner 2026-11-15): small, above the skill
	local target = { w = dim(0.75), h = dim(0.75), x = 0, y = 0 }
	target.x, target.y = skill.x + (skill.w - target.w) / 2, skill.y - gap - target.h
	return { attack = attack, dodge = dodge, skill = skill, pet = pet, signature = signature, swap = swap, run = run, target = target }
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

-- A fight's party strip on a touch screen (owner 2026-11-17: "make sure nothing is cutoff/overlapping on all devices"):
-- it stays under the status (`under`, its rect there) unless it would end within `clear` of Roblox's thumbstick ring
-- (`ring`: its right edge from the screen's left, its top from the bottom). Then it goes to the bottom row, right-aligned
-- beside the fight buttons (`buttons`, their rects) and on their bottom line, shrunk (`scale`) if the room between the
-- ring and the buttons needs it. Nil: it stays under the status (nothing to move, or no room with tiles of `minTile` px;
-- `tile` is their width now).
export type StripSpot = { x: number, y: number, scale: number }

function UiLayout.partyStripSpot(view: Size, under: Rect, buttons: { Rect }, ring: { right: number, top: number }, clear: number, tile: number, minTile: number): StripSpot?
	local ringTop = view.h - ring.top
	if under.y + under.h <= ringTop - clear or under.x >= ring.right + clear or #buttons == 0 then
		return nil
	end
	-- the bottom row's line: the leftmost button's foot (Swap / Call in, or Run)
	local first = buttons[1]
	for _, b in buttons do
		if b.x < first.x then
			first = b
		end
	end
	local floor = first.y + first.h
	local right = view.w
	for _, b in buttons do
		if b.y < floor and b.y + b.h > floor - under.h then
			right = math.min(right, b.x)
		end
	end
	local left = ring.right + clear
	local room = right - clear - left
	local scale = math.min(1, room / under.w)
	if scale * tile < minTile then
		return nil
	end
	return { x = right - clear - under.w * scale, y = floor - under.h * scale, scale = scale }
end

-- The Forge window's pane on a phone (Config/ForgeLayout): its height on a screen `viewH` px tall, and the height of
-- what it shows first: its sentence over the recipe (the card as tall as the spots, its pill under it); a Forge
-- weapon: its element buttons over the recipe
export type ForgeLook = {
	HEADER: number,
	INSET: number,
	PANEL: number,
	LIST_GAP: number,
	ACTION: number,
	ACTION_ROOM: number,
	PAD: number,
	GAP: number,
	CARD: { w: number, h: number },
	SAY: number,
	UNDER: number,
	ELEMENT: number,
	MUTATION_ROW: { phone: number }?,
}
function UiLayout.forgePhonePane(look: ForgeLook, viewH: number): number
	return (viewH - look.INSET) * look.PANEL - (look.HEADER + look.LIST_GAP) - (look.ACTION + look.ACTION_ROOM)
end

function UiLayout.forgePhoneContent(look: ForgeLook, tab: string): number
	local plain = look.SAY + look.GAP + look.CARD.h + look.UNDER
	local family = look.ELEMENT + look.GAP + look.CARD.h -- a Forge weapon (the Forge tab's first rows)
	-- the Mutate tab: the slim mutation row first, over the recipe (no pill; its sentence goes under the fold)
	local mutate = (if look.MUTATION_ROW then look.MUTATION_ROW.phone else look.SAY) + look.GAP + look.CARD.h
	return look.PAD * 2 + (if tab == "Forge" then math.max(plain, family) elseif tab == "Mutate" then mutate else plain)
end

-- The quick weapon switch (Config/HudLayout WEAPON_SWITCH) on the right edge at mid height. Its HUD scale never shrinks
-- a tap area under 48 px. In a fight it moves up above any fight button in its way (boss buttons by touch or mouse,
-- wild buttons), so it never covers the Pet or Signature buttons.
-- The row (owner 2026-11-27 pick B; the medallion dial of 2026-11-14 before it): its box is UiLayout.switchBox
-- `fightScale`: its size in a computer's fight (layout "mouse"), of its size out of one (owner 2026-11-20: it was the
-- biggest thing over the compact buttons)
export type SwitchLook = { chip: number, side: number, hit: number, row: number, drop: number, rise: number, name: number, gap: number, right: number, compactChip: number?, fightScale: number? }
export type SwitchRect = { x: number, y: number, w: number, h: number, scale: number }

-- The weapon switch's box before its scale (owner 2026-11-27 pick B, the twin of the party dock): the weapon in hand
-- (`chip`) between the one before and the next (`side`, `row` px off it, each with a `hit`-sized tap area), its level
-- pill `rise` px over it and its name's line (`name`) under it
function UiLayout.switchBox(look: { chip: number, side: number, hit: number, row: number, rise: number, name: number }): (number, number)
	return look.chip + 2 * look.row + look.side + look.hit, look.rise + look.chip + look.name
end
-- `clear`: boxes it keeps out of (a phone's top-right column with the party bar under it, owner 2026-11-13): it
-- moves just under one it would sit on, kept on screen. `compact` (phones, owner 2026-11-13 pick A): only the weapon in
-- hand, a bigger chip (`compactChip`), its count on its corner. `above` (a computer, owner 2026-11-13: "move weapon
-- lower to close the gap"): the cash column; out of a fight it sits beside it, its foot with the column's (Pish's toasts
-- rise over the column), or just above it when that would reach the screen's middle (the bottom tiles).
-- In a fight (owner 2026-11-20, the combat HUD tidy: "weapon dial joins the skills") it sits right over the fight
-- buttons in its column, for the layout on screen (`layout`: "touch", "mouse" or "wild"; not told: clear of all three)
function UiLayout.weaponSwitch(view: Size, look: SwitchLook, scale: number, fight: boolean, clear: { Rect }?, compact: boolean?, above: Rect?, layout: string?): SwitchRect
	local s = math.max(scale, 48 / look.hit)
	if fight and layout == "mouse" and look.fightScale then
		s *= look.fightScale -- a pointer needs less than a finger
	end
	local chip = if compact then look.compactChip or look.chip else look.chip
	local rowW, rowH = UiLayout.switchBox(look)
	local w = (if compact then chip else rowW) * s
	local h = (if compact then chip else rowH) * s
	local x = view.w - look.right - w
	local y = view.h / 2 - h / 2
	if above and not fight then
		local besideX = above.x - look.gap - w
		if besideX >= view.w * 0.6 then
			x, y = besideX, above.y + above.h - h
		else
			y = above.y - look.gap - h
		end
	end
	for _, b in clear or {} do
		if x < b.x + b.w and b.x < x + w and y < b.y + b.h and b.y < y + h then
			y = math.min(b.y + b.h + look.gap, view.h - h)
		end
	end
	if fight then
		local sets: { any } = if layout == "touch" then { UiLayout.combatButtons(view) }
			elseif layout == "mouse" then { UiLayout.combatButtons(view, true) }
			elseif layout == "wild" then { UiLayout.wildButtons(view) }
			else { UiLayout.combatButtons(view), UiLayout.combatButtons(view, true), UiLayout.wildButtons(view) }
		local avoid: { Rect } = {}
		y = view.h - h -- from the screen's foot up: it comes to rest on the top button in its column
		for _, rects in sets do
			for _, rect in rects do
				table.insert(avoid, rect)
			end
		end
		local moved = true
		while moved do
			moved = false
			for _, b in avoid do
				if x < b.x + b.w and b.x < x + w and y < b.y + b.h and b.y < y + h then
					y = b.y - look.gap - h
					moved = true
				end
			end
		end
	end
	return { x = x, y = math.max(0, y), w = w, h = h, scale = s }
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

-- How much to shrink content `needed` px tall to fit `available` px (1: it fits, or nothing's measured yet), never below
-- `minimum`
function UiLayout.fitScale(needed: number, available: number, minimum: number): number
	if needed <= 0 or available <= 0 or needed <= available then
		return 1
	end
	return math.max(minimum, available / needed)
end

return UiLayout
