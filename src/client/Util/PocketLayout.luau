--!strict
-- How many card pockets a binder page shows, and how big, for the page's size on screen.
-- Keeps the real-binder 3 x 3 when the cards are big enough; on short screens (landscape phones) it
-- picks fewer, larger pockets instead. Pure (no Roblox APIs) so tests/ can run it in Lune.
local PocketLayout = {}

export type Options = {
	aspect: number, -- card width / height
	gap: number, -- pixels between pockets and around the edge
	preferredColumns: number,
	preferredRows: number,
	minWidth: number, -- keep the preferred layout while its pockets are at least this wide
	maxColumns: number,
	maxRows: number,
	minPockets: number, -- never fewer pockets per page than this
}
export type Layout = { columns: number, rows: number, width: number, height: number }

local function fit(pageWidth: number, pageHeight: number, columns: number, rows: number, options: Options): number
	local byHeight = (pageHeight - options.gap * (rows + 1)) / rows * options.aspect
	local byWidth = (pageWidth - options.gap * (columns + 1)) / columns
	return math.max(1, math.floor(math.min(byHeight, byWidth)))
end

local function make(columns: number, rows: number, width: number, options: Options): Layout
	return { columns = columns, rows = rows, width = width, height = math.max(1, math.floor(width / options.aspect)) }
end

function PocketLayout.choose(pageWidth: number, pageHeight: number, options: Options): Layout
	local preferredWidth = fit(pageWidth, pageHeight, options.preferredColumns, options.preferredRows, options)
	if preferredWidth >= options.minWidth then
		return make(options.preferredColumns, options.preferredRows, preferredWidth, options)
	end
	-- Biggest pockets that still show enough cards; on a tie, the layout with more pockets
	local best: Layout? = nil
	for columns = 1, options.maxColumns do
		for rows = 1, options.maxRows do
			if columns * rows >= options.minPockets then
				local width = fit(pageWidth, pageHeight, columns, rows, options)
				local current = best
				if not current or width > current.width or (width == current.width and columns * rows > current.columns * current.rows) then
					best = make(columns, rows, width, options)
				end
			end
		end
	end
	return best or make(options.preferredColumns, options.preferredRows, preferredWidth, options)
end

return PocketLayout
