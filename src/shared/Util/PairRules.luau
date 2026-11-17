--!strict
-- The phone's creature and weapon pair (owner 2026-11-17: "make the party swipeable. move the party down beside the
-- weapon and add a swipe up/down o both. when a player long presses. it should display her pets/weapons at the top and
-- bottom so that player can choose", placement 2 of artifact GtT4bM87otu1aayFVANr7z): what a swipe means, which party
-- creature comes next, the count on its corner, where the pair sits and the hold column's rows. Config/Party BAR.PAIR;
-- client PartyBarController, WeaponSwitchController and Util/PickWheel. Pure, Lune-tested.
local PairRules = {}

export type Rect = { x: number, y: number, w: number, h: number }
export type Row = { offset: number, index: number }

-- Whether the pair shows: on a phone, never in a fight (owner 2026-11-17 playthrough: buttons overlapping in the jump
-- button's corner; the fight's own buttons hold that corner and its portraits swap creatures)
function PairRules.shown(compact: boolean, fighting: boolean): boolean
	return compact and not fighting
end

-- A swipe's step: up (the finger's y falling) the next one, down the one before; 0 when it's shorter than `threshold`
-- or more sideways than up and down (a tap, or the camera)
function PairRules.swipeStep(dx: number, dy: number, threshold: number): number
	if math.abs(dy) < threshold or math.abs(dy) < math.abs(dx) then
		return 0
	end
	return if dy < 0 then 1 else -1
end

local function filled(slots: { [number]: string }, size: number): { number }
	local list = {}
	for slot = 1, size do
		if slots[slot] then
			table.insert(list, slot)
		end
	end
	return list
end

-- The party slot `delta` steps on from `from` among the filled ones, wrapping round; the first filled one from an
-- empty slot; nil for an empty party
function PairRules.cycle(slots: { [number]: string }, from: number?, delta: number, size: number): number?
	local list = filled(slots, size)
	if #list == 0 then
		return nil
	end
	local index = if from then table.find(list, from) else nil
	if not index then
		return list[1]
	end
	return list[(index - 1 + delta) % #list + 1]
end

-- "2/3": `slot`'s place among the filled slots; nothing with one creature or none
function PairRules.count(slots: { [number]: string }, slot: number, size: number): string
	local list = filled(slots, size)
	local index = table.find(list, slot)
	if #list < 2 or not index then
		return ""
	end
	return `{index}/{#list}`
end

-- Where the pair sits (`height` px tall): on the right margin, `gap` px above Roblox's jump button, where the right
-- thumb rests. Its top and its offset from the right edge.
function PairRules.spot(jump: Rect, height: number, margin: number, gap: number): (number, number)
	return jump.y - gap - height, margin
end

-- The hold column's rows round the current one (offset 0, on the button): the ones before it above (negative), the
-- ones after below, wrapping round like a swipe; `visible` rows at most (the rest roll in from the ends)
function PairRules.wheel(count: number, current: number, visible: number): { Row }
	local shown = math.min(count, visible)
	local above = (shown - 1) // 2
	local below = shown - 1 - above
	local rows: { Row } = {}
	for offset = 0 - above, below do -- (0 - above: never a negative zero)
		table.insert(rows, { offset = offset, index = (current - 1 + offset) % count + 1 })
	end
	return rows
end

-- The row a finger `dy` px from the button's middle is on (`step` px apart, `above` rows over it and `below` under it),
-- kept inside the column, and whether it's past an end (-1 over the top, 1 under the bottom, 0 inside)
function PairRules.rowAt(dy: number, step: number, above: number, below: number): (number, number)
	local row = math.floor(dy / step + 0.5)
	if row < -above then
		return -above, -1
	elseif row > below then
		return below, 1
	end
	return row, 0
end

return PairRules
