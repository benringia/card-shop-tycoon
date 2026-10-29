--!strict
-- Where the pack opening's cards sit on screen (UI project 3 spec 4.6): the row of revealed cards along the bottom and
-- the results lineup in the middle, as screen rects; and how far from the camera a card must be to show a given
-- height. Pure, Lune-tested; numbers in Config/PackOpeningLayout.
export type Rect = { x: number, y: number, w: number, h: number }
export type View = { w: number, h: number }
export type Layout = {
	rowHeight: number, -- a row card's height, share of the screen height
	rowGap: number, -- px between row cards
	rowBottom: number, -- the row's gap to the screen's bottom, share of the screen height
	maxCard: number, -- px, the widest a lineup card gets
	gap: number, -- px between lineup cards
	side: number, -- px kept clear at each side
	lineupCentre: number, -- the lineup's middle, share of the height below the top bar
	lineupHeight: number, -- the tallest a lineup card gets, share of the height below the top bar
}

local ASPECT = 1.4 -- a card's height over its width

local OpeningLayout = {}

-- How far from a camera with this vertical field of view (degrees) a `studs`-tall card shows `pixels` tall
function OpeningLayout.depthFor(pixels: number, viewHeight: number, fov: number, studs: number): number
	return studs * viewHeight / (2 * pixels * math.tan(math.rad(fov) / 2))
end

-- `count` cards of width w in a centred line at height y
local function line(count: number, view: View, w: number, gap: number, y: number): { Rect }
	local total = count * w + math.max(0, count - 1) * gap
	local left = (view.w - total) / 2
	local rects = {}
	for index = 1, count do
		table.insert(rects, { x = left + (index - 1) * (w + gap), y = y, w = w, h = w * ASPECT })
	end
	return rects
end

-- The widest card width that fits `count` across the screen between the side margins
local function fitWidth(count: number, view: View, gap: number, side: number): number
	return (view.w - 2 * side - math.max(0, count - 1) * gap) / math.max(count, 1)
end

-- Small cards along the bottom, one per revealed card
function OpeningLayout.row(count: number, view: View, inset: number, look: Layout): { Rect }
	local w = math.min(look.rowHeight * view.h / ASPECT, fitWidth(count, view, look.rowGap, look.side))
	local y = view.h - look.rowBottom * view.h - w * ASPECT
	return line(count, view, w, look.rowGap, math.max(inset, y))
end

-- The results lineup: as big as fits (up to maxCard wide), centred under the top bar
function OpeningLayout.lineup(count: number, view: View, inset: number, look: Layout): { Rect }
	local below = view.h - inset
	local w = math.min(look.maxCard, fitWidth(count, view, look.gap, look.side), look.lineupHeight * below / ASPECT)
	local y = inset + look.lineupCentre * below - w * ASPECT / 2
	return line(count, view, w, look.gap, y)
end

return OpeningLayout
