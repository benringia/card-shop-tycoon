--!strict
-- Shop rooms (spec docs/superpowers/specs/2026-11-23-shop-rooms-design.md; owner 2026-11-23: "a big shop with rooms,
-- the rooms then become the extension. so all the players have same sized shops"): every shop is one 50 x 60 building,
-- its main hall open from the start and two rooms at the back behind locked doors. Unlocking one opens its door for
-- good, frees its floor and lets one more customer in (Util/ShopRooms; RoomService, PlotService.SetRooms).
-- Cells as Util/PlacementGrid counts them (Config/Placement GRID_SIZE 2): x from the floor's left edge, z from the street
-- edge. Plain data, so Lune tests load it.
return {
	HALL_ROWS = 20, -- the hall: every column, cell rows 0..19 (the front 40 studs)
	WALL_ROW = 20, -- the hall's back wall stands in the middle of this cell row (studs 40..42 from the street)
	SPLIT_COLUMN = 12, -- the wall between the rooms stands in the middle of this cell column (studs 24..26)
	WALL_THICK = 1, -- the inner walls, as Town.WALL_THICKNESS
	DOOR_HEIGHT = 10, -- studs over the floor, as the front doors (Town.SHOP DOOR_HEIGHT)
	DOOR_CELLS = 4, -- a doorway's width in cells (8 studs)
	PATH_ROWS = 2, -- clear cell rows in front of each door and just inside it, open or locked, so a door is never blocked
	OPEN_SECONDS = 1.2, -- the door sliding into the wall beside it
	DOOR_REACH = 14, -- studs from the door the owner must stand within to unlock it
	CUSTOMERS_PER_ROOM = 1, -- each open room lets one more customer in at a time (Customers.MAX_PER_PLOT is the base)
	SHELVES_PER_ROOM = 5, -- and adds this many to the shelf cap (Placement.MAX_SHELVES_PER_PLOT), a full shop's reason to grow
	PANEL_OFFSETS = { -6, 6 }, -- a room's ceiling panels: studs across it from its middle, one row
	ORDER = { "backRoom", "gallery" },
	-- `x`, `w`: the room's cell columns (its rows run from WALL_ROW + 1 to the back); `door`: its doorway's first column;
	-- `slide`: the way the door slides into the wall when it opens (-1 toward the left wall); `part`: the locked door's
	-- name (Pish's lesson points at it). Levels and prices are placeholders until table card battles (owner 2026-11-23:
	-- "we'll figure out the prices later").
	ROOMS = {
		backRoom = { name = "Back Room", sign = "BACK ROOM", part = "BackRoomDoor", x = 0, w = 12, door = 6, slide = -1, level = 15, price = 5000 },
		gallery = { name = "Gallery", sign = "GALLERY", part = "GalleryDoor", x = 13, w = 12, door = 15, slide = 1, level = 30, price = 20000 },
	},
	UNLOCKED = "%s unlocked! More floor and one more customer.",
	-- the name plate over a doorway: dark while locked, lit in the shop's accent colour (Neon) once open
	SIGN = { unlit = { 75, 58, 92 }, unlitText = { 233, 223, 239 }, litText = { 90, 52, 16 } },
	UNLOCK_SOUND = "rbxassetid://9116418035", -- Magic Tone Falling Shimmer (Config/Luck WIN.SOUND, licensed)
}
