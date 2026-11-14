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
	local length = cfg.WALLS[window.side]
	if not length then
		return false, "Windows go on the side and back walls."
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
				return false, "Too close to another window."
			end
		end
	end
	return true, nil
end

-- Whether a shop at `level` with `cash`, `count` windows and the style's achievement `met` may buy it; why not
function WindowRules.canBuy(cfg: any, styleId: string, level: number, cash: number, met: boolean, count: number): (boolean, string?)
	local style = cfg.STYLES[styleId]
	if not style then
		return false, "That window doesn't exist."
	end
	if count >= cfg.MAX then
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
		local fits = typeof(entry.side) == "string" and typeof(entry.at) == "number"
			and #kept < cfg.MAX and WindowRules.canPlace(cfg, kept, window)
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
