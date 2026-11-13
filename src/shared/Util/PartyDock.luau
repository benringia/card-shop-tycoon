--!strict
-- The party dock (owner 2026-11-13: "lets make the party UI like this in palworld. pets carousel, then under it is the
-- character menu model then beside it is health. Both mobile and Desktop", no box; PartyBarController): your team as a
-- carousel, the creature that's out big in the middle and the other two smaller either side, and you under it with
-- your level and XP (its health bar went, owner 2026-11-13: a fight shows your health). Pure, Lune-tested.
local PartyDock = {}

export type Carousel = { center: number, left: number, right: number }

-- Which slot sits where: the summoned one in the middle, else `focus` (the one last in the middle) while it holds a
-- card, else the first card in the party, else slot 1 (empty: its tap picks a card); its neighbours either side,
-- wrapping round
function PartyDock.carousel(slots: { [number]: string }, summoned: number?, focus: number?, size: number): Carousel
	local center: number? = nil
	if summoned and slots[summoned] then
		center = summoned
	elseif focus and slots[focus] then
		center = focus
	else
		for slot = 1, size do
			if slots[slot] then
				center = slot
				break
			end
		end
	end
	local middle = center or 1
	return { center = middle, left = (middle - 2) % size + 1, right = middle % size + 1 }
end

-- A number short: 850, 1.2K, 99.8K, 226K, 1.25M (up to 3 figures, no trailing zeros)
local function short(n: number): string
	local value, suffix = math.floor(n), ""
	if value >= 1000000 then
		value, suffix = value / 1000000, "M"
	elseif value >= 1000 then
		value, suffix = value / 1000, "K"
	end
	if suffix == "" then
		return tostring(value)
	end
	local decimals = if value >= 100 then 0 elseif value >= 10 then 1 else 2
	local text = string.format(`%.{decimals}f`, value)
	if decimals > 0 then
		text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	end
	return text .. suffix
end

-- Your XP bar's words: the XP into the level over the level's total, short ("99.8K / 226K"); "MAX" at the last level
function PartyDock.xpText(into: number, span: number): string
	if span <= 0 then
		return "MAX"
	end
	return `{short(into)} / {short(span)}`
end

return PartyDock
