--!strict
-- Shop rooms (spec docs/superpowers/specs/2026-11-23-shop-rooms-design.md; Config/ShopRooms): the one 50 x 60 shop's
-- hall, its two rooms and their locked doors in the cells and studs the server and the client agree on: what can be
-- placed, the doors and inner walls, the wall faces inside open space (where the shop's look and the windows go), the
-- caps and the unlock checks. Roblox-free (Lune-tested). Cells as Util/PlacementGrid counts them (x from the floor's
-- left edge, z from the street edge); studs floor-local (origin the floor's middle, x across, +z toward the back, the
-- street at -depth/2).
local ShopRooms = {}

export type Open = { [string]: boolean }
export type Rect = { x: number, z: number, w: number, d: number }
export type Grid = { cellsX: number, cellsZ: number, size: number }
export type Blocker = { name: string, room: string?, rect: Rect }
-- A gap in a wall along it, from the floor up to `top`
export type Hole = { from: number, to: number, top: number }
-- A wall running along `axis` from `from` to `to`, its middle plane at `at` on the other axis
export type Wall = { name: string, axis: "x" | "z", at: number, from: number, to: number, holes: { Hole } }
-- One face of a wall inside open floor: `at` is the face itself, `inward` the way into the room (+1 or -1 on the other
-- axis); `side`: "left" | "right" (the outer side walls), "back" (the hall's back wall), "inner", "outerBack"
export type Run = { side: string, axis: "x" | "z", at: number, from: number, to: number, inward: number, holes: { Hole } }
export type Door = { room: string, part: string, x: number, z: number, width: number, height: number, slide: number }
-- A stretch of wall a window or poster may use (Util/WindowRules): `posters` takes posters only; `room`, `name` and
-- `locked` mark a room's stretch (closed while the room is locked)
export type Span = { from: number, to: number, posters: boolean?, room: string?, name: string?, locked: boolean? }

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

-- The left edge of cell column `x` and the street-side edge of cell row `z`, in floor-local studs
local function edgeX(grid: Grid, x: number): number
	return -grid.cellsX * grid.size / 2 + x * grid.size
end

local function edgeZ(grid: Grid, z: number): number
	return -grid.cellsZ * grid.size / 2 + z * grid.size
end

-- The hall's back wall's middle plane, and the wall between the rooms'
local function wallZ(cfg: any, grid: Grid): number
	return edgeZ(grid, cfg.WALL_ROW) + grid.size / 2
end

local function splitX(cfg: any, grid: Grid): number
	return edgeX(grid, cfg.SPLIT_COLUMN) + grid.size / 2
end

-- Each door's gap in the hall's back wall, in ORDER
local function doorHoles(cfg: any, grid: Grid): { Hole }
	local holes: { Hole } = {}
	for _, id in cfg.ORDER do
		local room = cfg.ROOMS[id]
		table.insert(holes, { from = edgeX(grid, room.door), to = edgeX(grid, room.door + cfg.DOOR_CELLS), top = cfg.DOOR_HEIGHT })
	end
	return holes
end

-- The studs across a room between its outer side wall and the wall between the rooms, and which outer wall it has
local function roomAcross(cfg: any, grid: Grid, roomId: string): (number, number, string)
	local room = cfg.ROOMS[roomId]
	local halfWidth = grid.cellsX * grid.size / 2
	local half = cfg.WALL_THICK / 2
	if edgeX(grid, room.x) <= -halfWidth then
		return -halfWidth, splitX(cfg, grid) - half, "left"
	end
	return splitX(cfg, grid) + half, halfWidth, "right"
end

function ShopRooms.grid(width: number, depth: number, size: number): Grid
	return { cellsX = width // size, cellsZ = depth // size, size = size }
end

-- A saved list made safe: known rooms, once each, in ORDER
function ShopRooms.clean(cfg: any, saved: unknown): { string }
	local list: { string } = {}
	if typeof(saved) ~= "table" then
		return list
	end
	local present: { [string]: boolean } = {}
	for _, entry in saved :: { any } do
		if typeof(entry) == "string" and cfg.ROOMS[entry] then
			present[entry] = true
		end
	end
	for _, id in cfg.ORDER do
		if present[id] then
			table.insert(list, id)
		end
	end
	return list
end

function ShopRooms.openSet(list: { string }): Open
	local open: Open = {}
	for _, id in list do
		open[id] = true
	end
	return open
end

-- The open rooms as the plot model's OpenRooms attribute, and back
function ShopRooms.format(list: { string }): string
	return table.concat(list, ",")
end

function ShopRooms.parse(text: unknown): Open
	local open: Open = {}
	if typeof(text) ~= "string" then
		return open
	end
	for id in string.gmatch(text, "[^,]+") do
		open[id] = true
	end
	return open
end

local function openCount(cfg: any, open: Open): number
	local count = 0
	for _, id in cfg.ORDER do
		if open[id] then
			count += 1
		end
	end
	return count
end

function ShopRooms.customerCap(cfg: any, base: number, open: Open): number
	return base + openCount(cfg, open) * cfg.CUSTOMERS_PER_ROOM
end

function ShopRooms.shelfCap(cfg: any, base: number, open: Open): number
	return base + openCount(cfg, open) * cfg.SHELVES_PER_ROOM
end

-- Whether a shop at `level` with `cash` may open `roomId` now; why not
function ShopRooms.canUnlock(cfg: any, roomId: unknown, open: Open, level: number, cash: number): (boolean, string?)
	local room = if typeof(roomId) == "string" then cfg.ROOMS[roomId] else nil
	if not room then
		return false, "That room doesn't exist."
	end
	if open[roomId :: string] then
		return false, `The {room.name} is open already.`
	end
	if level < room.level then
		return false, `Reach shop level {room.level} to open the {room.name}.`
	end
	if cash < room.price then
		return false, `You need {money(room.price)} to open the {room.name}.`
	end
	return true, nil
end

function ShopRooms.hallRect(cfg: any, grid: Grid): Rect
	return { x = 0, z = 0, w = grid.cellsX, d = cfg.HALL_ROWS }
end

function ShopRooms.roomRect(cfg: any, grid: Grid, roomId: string): Rect
	local room = cfg.ROOMS[roomId]
	return { x = room.x, z = cfg.WALL_ROW + 1, w = room.w, d = grid.cellsZ - cfg.WALL_ROW - 1 }
end

-- A cell rect's middle (x, z) and size (width, depth) in floor-local studs
function ShopRooms.toLocal(grid: Grid, rect: Rect): (number, number, number, number)
	return edgeX(grid, rect.x + rect.w / 2), edgeZ(grid, rect.z + rect.d / 2), rect.w * grid.size, rect.d * grid.size
end

-- The hall's back edge (where its placeable floor ends), floor-local z
function ShopRooms.hallBack(cfg: any, grid: Grid): number
	return edgeZ(grid, cfg.HALL_ROWS)
end

-- The cell in the middle of the hall, where searches for a free spot start
function ShopRooms.hallMiddleCell(cfg: any, grid: Grid): (number, number)
	return grid.cellsX // 2, cfg.HALL_ROWS // 2
end

-- The cells nothing may be placed on: the inner walls' rows, each door's clear path on both sides (open or locked, so
-- a door is never blocked) and every locked room's floor
function ShopRooms.blockers(cfg: any, grid: Grid, open: Open): { Blocker }
	local list: { Blocker } = {
		{ name = "InnerWall", rect = { x = 0, z = cfg.WALL_ROW, w = grid.cellsX, d = 1 } },
		{ name = "RoomWall", rect = { x = cfg.SPLIT_COLUMN, z = cfg.WALL_ROW + 1, w = 1, d = grid.cellsZ - cfg.WALL_ROW - 1 } },
	}
	for _, id in cfg.ORDER do
		local room = cfg.ROOMS[id]
		table.insert(list, { name = "DoorPathHall", room = id, rect = { x = room.door, z = cfg.WALL_ROW - cfg.PATH_ROWS, w = cfg.DOOR_CELLS, d = cfg.PATH_ROWS } })
		table.insert(list, { name = "DoorPathRoom", room = id, rect = { x = room.door, z = cfg.WALL_ROW + 1, w = cfg.DOOR_CELLS, d = cfg.PATH_ROWS } })
		if not open[id] then
			table.insert(list, { name = "LockedRoom", room = id, rect = ShopRooms.roomRect(cfg, grid, id) })
		end
	end
	return list
end

-- Each room's door in the hall's back wall: its middle (floor-local, on the wall's middle plane) and size
function ShopRooms.doors(cfg: any, grid: Grid): { Door }
	local doors: { Door } = {}
	for index, id in cfg.ORDER do
		local room = cfg.ROOMS[id]
		local hole = doorHoles(cfg, grid)[index]
		table.insert(doors, {
			room = id,
			part = room.part,
			x = (hole.from + hole.to) / 2,
			z = wallZ(cfg, grid),
			width = hole.to - hole.from,
			height = cfg.DOOR_HEIGHT,
			slide = room.slide,
		})
	end
	return doors
end

-- The inner walls: the hall's back wall with a doorway into each room, and the wall between the rooms
function ShopRooms.innerWalls(cfg: any, grid: Grid): { Wall }
	local halfWidth, halfDepth = grid.cellsX * grid.size / 2, grid.cellsZ * grid.size / 2
	local back = wallZ(cfg, grid)
	return {
		{ name = "HallBackWall", axis = "x", at = back, from = -halfWidth, to = halfWidth, holes = doorHoles(cfg, grid) },
		{ name = "RoomWall", axis = "z", at = splitX(cfg, grid), from = back + cfg.WALL_THICK / 2, to = halfDepth, holes = {} },
	}
end

-- Every wall face inside open floor, where the shop's look goes: the hall's (its two side walls, its back wall with
-- the doorways), then each open room's (its outer side wall, the wall between the rooms, the outer back wall, the hall
-- wall's room face with its doorway)
function ShopRooms.runs(cfg: any, grid: Grid, open: Open): { Run }
	local halfWidth, halfDepth = grid.cellsX * grid.size / 2, grid.cellsZ * grid.size / 2
	local half = cfg.WALL_THICK / 2
	local hallFace, roomFace = wallZ(cfg, grid) - half, wallZ(cfg, grid) + half
	local holes = doorHoles(cfg, grid)
	local runs: { Run } = {
		{ side = "left", axis = "z", at = -halfWidth, from = -halfDepth, to = hallFace, inward = 1, holes = {} },
		{ side = "right", axis = "z", at = halfWidth, from = -halfDepth, to = hallFace, inward = -1, holes = {} },
		{ side = "back", axis = "x", at = hallFace, from = -halfWidth, to = halfWidth, inward = -1, holes = table.clone(holes) },
	}
	for index, id in cfg.ORDER do
		if open[id] then
			local from, to, side = roomAcross(cfg, grid, id)
			local onLeft = side == "left"
			table.insert(runs, { side = side, axis = "z", at = if onLeft then -halfWidth else halfWidth, from = roomFace, to = halfDepth, inward = if onLeft then 1 else -1, holes = {} })
			table.insert(runs, { side = "inner", axis = "z", at = if onLeft then to else from, from = roomFace, to = halfDepth, inward = if onLeft then -1 else 1, holes = {} })
			table.insert(runs, { side = "outerBack", axis = "x", at = halfDepth, from = from, to = to, inward = -1, holes = {} })
			table.insert(runs, { side = "inner", axis = "x", at = roomFace, from = from, to = to, inward = 1, holes = { holes[index] } })
		end
	end
	return runs
end

-- Where windows and posters may go: each side wall's hall stretch and its room's stretch (marked locked while the room
-- is), and the hall's back wall between the doorways for posters only
function ShopRooms.windowSpans(cfg: any, grid: Grid, open: Open): { [string]: { Span } }
	local halfWidth, halfDepth = grid.cellsX * grid.size / 2, grid.cellsZ * grid.size / 2
	local half = cfg.WALL_THICK / 2
	local hallFace, roomFace = wallZ(cfg, grid) - half, wallZ(cfg, grid) + half
	local spans: { [string]: { Span } } = {
		left = { { from = -halfDepth, to = hallFace } },
		right = { { from = -halfDepth, to = hallFace } },
		back = {},
	}
	for _, id in cfg.ORDER do
		local _, _, side = roomAcross(cfg, grid, id)
		table.insert(spans[side], { from = roomFace, to = halfDepth, room = id, name = cfg.ROOMS[id].name, locked = if open[id] then nil else true })
	end
	for _, gap in ShopRooms.gaps(-halfWidth, halfWidth, doorHoles(cfg, grid), 0, cfg.DOOR_HEIGHT) do
		table.insert(spans.back, { from = gap.from, to = gap.to, posters = true })
	end
	return spans
end

-- The stretches of [from, to] no hole covers between heights `low` and `high` (a strip along a wall is cut only where a
-- doorway reaches up to it)
function ShopRooms.gaps(from: number, to: number, holes: { Hole }, low: number, high: number): { { from: number, to: number } }
	local cuts = {}
	for _, hole in holes do
		if low < hole.top and high > 0 and hole.to > from and hole.from < to then
			table.insert(cuts, hole)
		end
	end
	table.sort(cuts, function(a, b)
		return a.from < b.from
	end)
	local list = {}
	local cursor = from
	for _, cut in cuts do
		if cut.from > cursor then
			table.insert(list, { from = cursor, to = math.min(cut.from, to) })
		end
		cursor = math.max(cursor, cut.to)
	end
	if cursor < to then
		table.insert(list, { from = cursor, to = to })
	end
	return list
end

return ShopRooms
