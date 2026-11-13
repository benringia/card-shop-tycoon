--!strict
-- The phone HUD, slimmed (owner 2026-11-13, pick A): the cash as the pill shows it on a phone, and where each HUD
-- button sits (Util/Hud). Pure, Lune-tested.
local CompactHud = {}

-- Cash on a phone: whole dollars with commas ("$53,661"), millions short ("$1.25M")
function CompactHud.money(cash: number): string
	local whole = math.max(0, math.floor(cash))
	if whole >= 1000000 then
		local millions = string.format("%.2f", whole / 1000000)
		millions = string.gsub(string.gsub(millions, "0+$", ""), "%.$", "")
		return `${millions}M`
	end
	local text = tostring(whole)
	local done = text
	repeat
		text = done
		done = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
	until done == text
	return `${done}`
end

-- Round 2 (owner 2026-11-13, pick A plus "move the admin tile inside phone and move binder tile under phone"):
-- where a HUD button sits. `app`: a Phone app (Shop, Prices, Jobs, Reviews: town only; `everywhere`: Party); a tile
-- with `phone` becomes a Phone app on a phone screen (Bag, Bosses, Admin), one with `side` moves to the side column
-- under the Phone (Cards); with `always` too (Bosses, Admin: owner 2026-11-13 "only cards and bag should be left at
-- the center") a tile is a Phone app on a computer as well. "hidden": a town app away from town.
export type Spot = "tile" | "side" | "phone" | "hidden"

function CompactHud.spot(button: { app: boolean?, everywhere: boolean?, phone: boolean?, side: boolean?, always: boolean? }, compact: boolean, inTown: boolean): Spot
	if button.app then
		return if inTown or button.everywhere then "phone" else "hidden"
	end
	if button.phone and (compact or button.always) then
		return "phone"
	end
	if compact and button.side then
		return "side"
	end
	return "tile"
end

-- Whether the Phone tile shows, given every button's spot: wherever it holds an app (Party and Support are
-- everywhere; Pish peeks over it)
function CompactHud.phoneTile(spots: { Spot }): boolean
	return table.find(spots, "phone") ~= nil
end

-- A ring at `share` full (a timed buff's on a phone): how far its right half and then its left half turn (each a half
-- circle clipped, its stroke's gradient turned 0-180 degrees), the right half first
function CompactHud.ring(share: number): (number, number)
	local degrees = math.clamp(share, 0, 1) * 360
	return math.clamp(degrees, 0, 180), math.clamp(degrees - 180, 0, 180)
end

-- The phone's weapon chip count (owner 2026-11-13, declutter pick A: its dots became a small "1/6" on the chip's
-- corner): the one in hand (the first while none is) of how many; nothing with one weapon or none
function CompactHud.weaponCount(list: { string }, id: string?): string
	if #list < 2 then
		return ""
	end
	return `{if id then table.find(list, id) or 1 else 1}/{#list}`
end

return CompactHud
