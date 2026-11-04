--!strict
-- The HUD tiles' squishy hover (Config/SoftHud SQUISH, spec 2026-11-03-cotton-candy-ui-design): how long it lasts,
-- how wide it gets, and whether a tile at its widest stays clear of the next one. Pure, Lune-tested.
local SquishRules = {}

export type Step = { seconds: number, x: number, y: number, lift: number }
export type Squish = { steps: { Step }, release: number, press: { seconds: number, x: number, y: number } }
export type Tile = { size: number, gap: number, keySize: number, keyInset: number, iconRise: number? }

-- The hover's length in seconds
function SquishRules.duration(steps: { Step }): number
	local total = 0
	for _, step in steps do
		total += step.seconds
	end
	return total
end

-- The widest the tile gets, hover or press, as a share of its width
function SquishRules.widest(squish: Squish): number
	local widest = squish.press.x
	for _, step in squish.steps do
		widest = math.max(widest, step.x)
	end
	return widest
end

-- A tile grows from its middle, so half its extra width reaches into the gap on each side, where the next tile's key
-- chip (centred keyInset px in from its corner) already pokes out by keySize / 2 - keyInset. Both must fit.
function SquishRules.fitsGap(tile: Tile, squish: Squish): boolean
	local growth = (SquishRules.widest(squish) - 1) * tile.size / 2
	local chip = math.max(0, tile.keySize / 2 - tile.keyInset)
	return growth + chip < tile.gap
end

-- How far above the screen's bottom the tile row reaches (px), its popped-out icons included at their highest hover
-- pose: anything stacked over the row (the status corner on a narrow PC screen, the toast) sits above this. The row's
-- `bottomMargin` isn't scaled; the tiles are, by the HUD's `scale`.
function SquishRules.rowTop(tile: Tile, squish: Squish, bottomMargin: number, scale: number): number
	local rise = tile.iconRise or 0
	local highest = tile.size * (1 + rise)
	for _, step in squish.steps do
		highest = math.max(highest, step.lift + tile.size * step.y * (1 + rise))
	end
	return bottomMargin + highest * scale
end

return SquishRules
