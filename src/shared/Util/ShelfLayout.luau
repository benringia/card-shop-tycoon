--!strict
-- The parts of a code-built product shelf (Util/ShelfLooks draws them): where each post, plate, price rail, back
-- panel, base, header and hook goes, so every plate sits exactly under a stock level (Util/ShelfStock) whatever
-- the shelf's size. Pure, Lune-tested. Box centres and sizes in studs, bottom of the shelf at y = 0, centred on
-- x and z, front at -Z.
--   Rack:       one-sided gondola: plates reaching out from a back panel between two posts
--   DoubleRack: two-sided: plates through a middle divider, a price rail on each face
--   Pegboard:   a pegboard back with wire shelves and a row of hooks above each level
export type Vec = { x: number, y: number, z: number }
-- The parts of ShelfStock.StockConfig the layout needs
export type Stock = { LEVELS: { number }, PER_LEVEL: number, BOX_HEIGHT: number }
export type Kind = "Rack" | "DoubleRack" | "Pegboard"
export type Box = { role: string, x: number, y: number, z: number, sx: number, sy: number, sz: number }
export type Look = { POST: number, PLATE: number, RAIL: number, BACK: number, BASE: number, HEADER: number, HOOK: number }

local ShelfLayout = {}

local RAIL_DEPTH = 0.06
local HEADER_DEPTH = 0.3
local HOOK_SIZE = 0.06
local HOOK_GAP = 0.25 -- a hook row sits this far above the stock under it

function ShelfLayout.build(kind: Kind, size: Vec, config: Stock, look: Look): { Box }
	local boxes: { Box } = {}
	local function add(role: string, x: number, y: number, z: number, sx: number, sy: number, sz: number)
		table.insert(boxes, { role = role, x = x, y = y, z = z, sx = sx, sy = sy, sz = sz })
	end
	local inner = size.x - 2 * look.POST -- between the posts
	local postX = size.x / 2 - look.POST / 2
	local panelHeight = size.y - look.BASE - look.HEADER
	local panelY = look.BASE + panelHeight / 2
	add("base", 0, look.BASE / 2, 0, size.x, look.BASE, size.z)

	if kind == "DoubleRack" then
		for _, side in { -1, 1 } do
			add("post", side * postX, size.y / 2, 0, look.POST, size.y, look.POST * 2)
		end
		add("back", 0, panelY, 0, inner, panelHeight, look.BACK)
		for _, level in config.LEVELS do
			local top = level * size.y
			add("plate", 0, top - look.PLATE / 2, 0, inner, look.PLATE, size.z)
			for _, side in { -1, 1 } do
				add("rail", 0, top - look.RAIL / 2, side * (size.z / 2 - RAIL_DEPTH / 2), inner, look.RAIL, RAIL_DEPTH)
			end
		end
		add("header", 0, size.y - look.HEADER / 2, 0, size.x, look.HEADER, HEADER_DEPTH)
		return boxes
	end

	-- One-sided: the back panel along the back, the posts just in front of it, plates out to the front edge
	local backZ = size.z / 2 - look.BACK / 2
	local backFront = size.z / 2 - look.BACK
	add("back", 0, panelY, backZ, size.x, panelHeight, look.BACK)
	for _, side in { -1, 1 } do
		add("post", side * postX, size.y / 2, backFront - look.POST / 2, look.POST, size.y, look.POST)
	end
	local plateDepth = backFront - look.POST + size.z / 2
	for _, level in config.LEVELS do
		local top = level * size.y
		add("plate", 0, top - look.PLATE / 2, -size.z / 2 + plateDepth / 2, inner, look.PLATE, plateDepth)
		if kind == "Rack" then
			add("rail", 0, top - look.RAIL / 2, -size.z / 2 + RAIL_DEPTH / 2, inner, look.RAIL, RAIL_DEPTH)
		end
	end
	if kind == "Pegboard" then
		-- A row of hooks over each level's stock, wherever it fits under the next level (or the header)
		local cell = size.x / config.PER_LEVEL
		for index, level in config.LEVELS do
			local y = level * size.y + config.BOX_HEIGHT + HOOK_GAP
			local ceiling = if config.LEVELS[index + 1] then config.LEVELS[index + 1] * size.y - look.PLATE else size.y - look.HEADER
			if y + HOOK_SIZE / 2 <= ceiling then
				for slot = 1, config.PER_LEVEL do
					local x = -size.x / 2 + (slot - 0.5) * cell
					add("hook", x, y, backFront - look.HOOK / 2, HOOK_SIZE, HOOK_SIZE, look.HOOK)
				end
			end
		end
	end
	add("header", 0, size.y - look.HEADER / 2, backFront - HEADER_DEPTH / 2, size.x, look.HEADER, HEADER_DEPTH)
	return boxes
end

return ShelfLayout
