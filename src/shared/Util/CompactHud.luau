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
-- `bottom` (owner 2026-11-17, "make sure nothing is cutoff/overlapping on all devices"): on a phone the tile joins the
-- bottom-centre row (the Gift tile: third in the side column it sat on the thumbstick's resting spot on every phone)
export type Spot = "tile" | "side" | "phone" | "hidden" | "bottom"

function CompactHud.spot(button: { app: boolean?, everywhere: boolean?, phone: boolean?, side: boolean?, always: boolean?, bottom: boolean? }, compact: boolean, inTown: boolean): Spot
	if button.app then
		return if inTown or button.everywhere then "phone" else "hidden"
	end
	if button.phone and (compact or button.always) then
		return "phone"
	end
	if compact and button.bottom then
		return "bottom"
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

-- Roblox's own jump button on a touch screen (its TouchJump): 70 px, 95 from the right and 90 from the bottom when the
-- screen's short side is 500 px or less, else 120 px, 170 and 210. Not ours to tune: it's where Roblox draws it.
local JUMP = { smallScreen = 500, small = { size = 70, right = 95, bottom = 90 }, big = { size = 120, right = 170, bottom = 210 } }

-- The Phone's form on a screen `height` px tall (under Roblox's top bar; Config/PhoneForm): standing up while its app
-- tiles (`tile` px at full size) stay `minTile` px, else lying on its side. Returns whether it's on its side and its
-- scale (never over 1)
function CompactHud.phoneForm(
	height: number,
	form: { tall: { w: number, h: number }, wide: { w: number, h: number }, fit: number, wideFit: number, minTile: number },
	tile: number
): (boolean, number)
	local tallScale = math.min(1, height * form.fit / form.tall.h)
	if tallScale * tile >= form.minTile then
		return false, tallScale
	end
	return true, math.min(1, height * form.wideFit / form.wide.h)
end

export type Rect = { x: number, y: number, w: number, h: number }

-- The jump button's box in the HUD's space (`w` x `h`, under Roblox's top bar; anchored to the bottom, so the same
-- whether a gui counts the top bar or not)
function CompactHud.jumpRect(w: number, h: number): Rect
	local spec = if math.min(w, h) <= JUMP.smallScreen then JUMP.small else JUMP.big
	return { x = w - spec.right, y = h - spec.bottom, w = spec.size, h = spec.size }
end

-- Where the phone's quest strip goes (owner 2026-11-17: it sat on the jump button): `gap` under the top-right
-- column's last piece (`below`: its real bottom, not the column frame's), `margin` from the right edge; one that would
-- still reach the jump button moves left of the button's column. Returns its top and its offset from the right edge.
function CompactHud.questSpot(below: number, size: { w: number, h: number }, screen: { w: number, h: number }, jump: Rect, margin: number, gap: number): (number, number)
	local top = below + gap
	local left = screen.w - margin - size.w
	local overX = left < jump.x + jump.w and screen.w - margin > jump.x
	local overY = top + size.h + gap > jump.y
	if overX and overY then
		return top, screen.w - jump.x + gap
	end
	return top, margin
end

-- What a phone shows (owner 2026-11-17: "mobile version screen now too crowded ... lets just display the important
-- stuffs on mobile", "go A" of artifact GtT4bM87otu1aayFVANr7z): the essentials always (the Phone, Cards, your avatar
-- and shop level, the cash, your creature and your weapon side by side above the jump button: Util/PairRules, its round
-- 2); the next-unlock line, the quick Party button, the creature's name, empty party slots and the rest of the party
-- never (they're a swipe or a hold away); the gift tile once a gift is ready; Turts' chip just after he restocks; the
-- quests as a chip by the cash instead of the strip (the main quest's row folded into it: the chip shows the main quest
-- once the day's quests are done, owner 2026-11-18). A computer shows everything as before. Each piece still follows
-- its own rules too (the gift tile counting or ready, Turts' chip in town after the tour...).
export type PhonePieces = {
	nextUnlock: boolean,
	quickParty: boolean,
	partyName: boolean,
	emptySlots: boolean,
	sideSlots: boolean,
	weaponChip: boolean,
	giftTile: boolean,
	turtsChip: boolean,
	questChip: boolean,
	mainRow: boolean, -- the main quest's row under the quest strip (Util/QuestStrip)
}

function CompactHud.phonePieces(compact: boolean, inTown: boolean, giftReady: boolean, turtsFresh: boolean): PhonePieces
	if not compact then
		return {
			nextUnlock = true,
			quickParty = true,
			partyName = true,
			emptySlots = true,
			sideSlots = true,
			weaponChip = true,
			giftTile = true,
			turtsChip = true,
			questChip = false,
			mainRow = true,
		}
	end
	return {
		nextUnlock = false,
		quickParty = false,
		partyName = false,
		emptySlots = false,
		sideSlots = false,
		weaponChip = true,
		giftTile = giftReady,
		turtsChip = turtsFresh,
		questChip = true,
		mainRow = false,
	}
end

return CompactHud
