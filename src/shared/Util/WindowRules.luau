--!strict
-- Shop windows (spec docs/superpowers/specs/2026-11-14-shop-windows-design.md; Config/Windows): where a window may go
-- on a wall, what a shop may buy, a saved list cleaned on load, and a wall cut into pieces round the windows' holes.
-- Roblox-free (Lune-tested). A window is { style, side ("left" | "right" | "back"), at: studs from the wall's middle };
-- a wall's coordinates run x along it (-length/2 to length/2) and y up from the floor.
local WindowRules = {}

export type Window = { style: string, side: string, at: number }
export type Rect = { x0: number, x1: number, y0: number, y1: number }

local function money(amount: number): string
	local text = tostring(math.floor(amount))
	while true do
		local spaced, count = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		text = spaced
		if count == 0 then
			return `${text}`
		end
	end
end

-- The nearest place on the grid to `at`
function WindowRules.snap(cfg: any, at: number): number
	return math.floor(at / cfg.GRID + 0.5) * cfg.GRID
end

-- Whether a style is a poster (Config/Windows: a `poster` picture): hung on a wall or the front glass, no hole
function WindowRules.isPoster(cfg: any, styleId: string): boolean
	local style = cfg.STYLES[styleId]
	return style ~= nil and style.poster ~= nil
end

-- Whether a placed piece cuts a hole in its wall: a window does, a poster hangs on it
function WindowRules.cuts(cfg: any, window: Window): boolean
	return cfg.STYLES[window.style] ~= nil and not WindowRules.isPoster(cfg, window.style)
end

-- The front glass's poster spots, from the front's middle: the two outer panes each side of the door (the inner pane
-- each side is where a door leaf rests when open)
function WindowRules.frontSpots(cfg: any): { number }
	local front = cfg.FRONT
	local doorHalf = front.doorWidth / 2
	local paneWidth = (front.outerWidth / 2 - doorHalf) / front.panes
	local outer, inner = doorHalf + (front.panes - 0.5) * paneWidth, doorHalf + (front.panes - 1.5) * paneWidth
	return { -outer, -inner, inner, outer }
end

-- The pointer's spot along a side becomes a place to hang: the grid on a wall, the nearest outer pane on the front
function WindowRules.snapOn(cfg: any, side: string, at: number): number
	if side ~= "front" then
		return WindowRules.snap(cfg, at)
	end
	local best, nearest = at, math.huge
	for _, spot in WindowRules.frontSpots(cfg) do
		if math.abs(spot - at) < nearest then
			best, nearest = spot, math.abs(spot - at)
		end
	end
	return best
end

-- How many of `windows` are the same kind as `styleId` (posters or windows): each kind has its own cap
function WindowRules.count(cfg: any, windows: { Window }, styleId: string): number
	local poster = WindowRules.isPoster(cfg, styleId)
	local count = 0
	for _, window in windows do
		if cfg.STYLES[window.style] and WindowRules.isPoster(cfg, window.style) == poster then
			count += 1
		end
	end
	return count
end

-- How far from the wall's middle plane a piece sits, along the way out of the shop (`thick`: the wall's thickness): a
-- window in the wall (0), a poster on the wall's inside face past the look's liner, or just outside the front glass
function WindowRules.depth(cfg: any, window: Window, thick: number): number
	if not WindowRules.isPoster(cfg, window.style) then
		return 0
	end
	return if window.side == "front" then cfg.POSTER.glass else -(thick / 2 + cfg.POSTER.inset)
end

-- A window's hole on its wall
function WindowRules.hole(cfg: any, window: Window): Rect
	local style = cfg.STYLES[window.style]
	return {
		x0 = window.at - style.width / 2,
		x1 = window.at + style.width / 2,
		y0 = cfg.SILL,
		y1 = cfg.SILL + style.height,
	}
end

-- Whether `window` may go where it says, among `windows` (`ignore`: the index of the one being moved); why not
function WindowRules.canPlace(cfg: any, windows: { Window }, window: Window, ignore: number?): (boolean, string?)
	local style = cfg.STYLES[window.style]
	if not style then
		return false, "That window doesn't exist."
	end
	if window.side == "front" then
		-- the front glass: posters only, on an outer pane, one a pane
		if not style.poster then
			return false, "Windows go on the side and back walls."
		end
		local onPane = false
		for _, spot in WindowRules.frontSpots(cfg) do
			onPane = onPane or (typeof(window.at) == "number" and math.abs(window.at - spot) < 1e-3)
		end
		if not onPane then
			return false, "Posters go on the outer glass panes, not the doors."
		end
		for index, other in windows do
			if index ~= ignore and other.side == "front" and math.abs(other.at - window.at) < 1e-3 then
				return false, "That pane has a poster already."
			end
		end
		return true, nil
	end
	local length = cfg.WALLS[window.side]
	if not length then
		return false, if style.poster then "Posters go on a wall or the front glass." else "Windows go on the side and back walls."
	end
	if typeof(window.at) ~= "number" or window.at ~= WindowRules.snap(cfg, window.at) then
		return false, "That spot isn't on the wall's grid."
	end
	if math.abs(window.at) + style.width / 2 > length / 2 - cfg.CORNER then
		return false, "Too close to the corner."
	end
	for index, other in windows do
		local otherStyle = cfg.STYLES[other.style]
		if index ~= ignore and other.side == window.side and otherStyle then
			if math.abs(other.at - window.at) < (style.width + otherStyle.width) / 2 + cfg.GAP then
				return false, if style.poster or otherStyle.poster then "Too close to something else on this wall." else "Too close to another window."
			end
		end
	end
	return true, nil
end

-- Whether a shop at `level` with `cash`, `count` pieces of the style's kind (WindowRules.count) and the style's
-- achievement `met` may buy it; why not
function WindowRules.canBuy(cfg: any, styleId: string, level: number, cash: number, met: boolean, count: number): (boolean, string?)
	local style = cfg.STYLES[styleId]
	if not style then
		return false, "That window doesn't exist."
	end
	if style.poster then
		if count >= cfg.MAX_POSTERS then
			return false, `Your shop has room for {cfg.MAX_POSTERS} posters. Take one down to make space.`
		end
	elseif count >= cfg.MAX then
		return false, `Your shop has room for {cfg.MAX} windows. Sell one to make space.`
	end
	if style.needs and not met then
		return false, `{style.name}: {style.how}.`
	end
	if level < style.level then
		return false, `{style.name} unlocks at shop level {style.level}.`
	end
	if cash < style.price then
		return false, `You need {money(style.price)} for {style.name}.`
	end
	return true, nil
end

-- A saved list made safe: every entry well formed and fitting among the ones before it, at most MAX; the price of each
-- known style dropped is paid back (never silently lost); unknown styles can't be priced
function WindowRules.clean(cfg: any, saved: unknown): ({ Window }, number)
	local kept: { Window } = {}
	local refunded = 0
	if typeof(saved) ~= "table" then
		return kept, refunded
	end
	for _, entry in saved :: { any } do
		if typeof(entry) ~= "table" then
			continue
		end
		local style = if typeof(entry.style) == "string" then cfg.STYLES[entry.style] else nil
		if not style then
			continue
		end
		local window = { style = entry.style, side = entry.side, at = entry.at }
		local cap = if style.poster then cfg.MAX_POSTERS else cfg.MAX
		local fits = typeof(entry.side) == "string" and typeof(entry.at) == "number"
			and WindowRules.count(cfg, kept, entry.style) < cap and WindowRules.canPlace(cfg, kept, window)
		if fits then
			table.insert(kept, window)
		else
			refunded += style.price
		end
	end
	return kept, refunded
end

-- A wall `length` x `height` less `holes` (not overlapping), as rectangles: full-height strips between the holes and,
-- over each hole's width, the wall under it and over it
function WindowRules.pieces(length: number, height: number, holes: { Rect }): { Rect }
	local sorted = table.clone(holes)
	table.sort(sorted, function(a, b)
		return a.x0 < b.x0
	end)
	local pieces: { Rect } = {}
	local cursor = -length / 2
	for _, hole in sorted do
		if hole.x0 > cursor then
			table.insert(pieces, { x0 = cursor, x1 = hole.x0, y0 = 0, y1 = height })
		end
		if hole.y0 > 0 then
			table.insert(pieces, { x0 = hole.x0, x1 = hole.x1, y0 = 0, y1 = hole.y0 })
		end
		if hole.y1 < height then
			table.insert(pieces, { x0 = hole.x0, x1 = hole.x1, y0 = hole.y1, y1 = height })
		end
		cursor = math.max(cursor, hole.x1)
	end
	if cursor < length / 2 then
		table.insert(pieces, { x0 = cursor, x1 = length / 2, y0 = 0, y1 = height })
	end
	return pieces
end

return WindowRules
