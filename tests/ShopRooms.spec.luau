--!strict
-- Shop rooms (spec 2026-11-23-shop-rooms-design): one 50 x 60 building for everyone, the hall open, two rooms behind
-- locked doors; the cells, doors, walls, caps and unlock checks both sides use
local ShopRooms = require("../src/shared/Util/ShopRooms")
local cfg = require("../src/shared/Config/ShopRooms")
local expect = require("./lib/expect")

-- Config/Plots WIDTH 50, DEPTH 60 and Config/Placement GRID_SIZE 2 (Lune can't load Plots: it holds Vector3s)
local GRID = ShopRooms.grid(50, 60, 2)

local function find(list: { ShopRooms.Blocker }, name: string, room: string?): ShopRooms.Rect?
	for _, blocker in list do
		if blocker.name == name and blocker.room == room then
			return blocker.rect
		end
	end
	return nil
end

return {
	["the grid, the hall and the rooms in cells"] = function()
		expect.equal(GRID.cellsX, 25)
		expect.equal(GRID.cellsZ, 30)
		local hall = ShopRooms.hallRect(cfg, GRID)
		local back = ShopRooms.roomRect(cfg, GRID, "backRoom")
		local gallery = ShopRooms.roomRect(cfg, GRID, "gallery")
		expect.equal(hall.x, 0)
		expect.equal(hall.z, 0)
		expect.equal(hall.w, 25)
		expect.equal(hall.d, 20)
		expect.equal(back.x, 0)
		expect.equal(back.z, 21)
		expect.equal(back.w, 12)
		expect.equal(back.d, 9)
		expect.equal(gallery.x, 13)
		expect.equal(gallery.z, 21)
		local x, z, w, d = ShopRooms.toLocal(GRID, back)
		expect.equal(x, -13)
		expect.equal(z, 21)
		expect.equal(w, 24)
		expect.equal(d, 18)
		expect.equal(select(2, ShopRooms.toLocal(GRID, hall)), -10)
		expect.equal(ShopRooms.hallBack(cfg, GRID), 10)
		local mx, mz = ShopRooms.hallMiddleCell(cfg, GRID)
		expect.equal(mx, 12)
		expect.equal(mz, 10)
	end,

	["saved rooms cleaned: known, once each, in order"] = function()
		local list = ShopRooms.clean(cfg, { "gallery", "backRoom", "gallery", "attic", 5 })
		expect.equal(#list, 2)
		expect.equal(list[1], "backRoom")
		expect.equal(list[2], "gallery")
		expect.equal(#ShopRooms.clean(cfg, nil), 0)
		expect.equal(#ShopRooms.clean(cfg, "backRoom"), 0)
	end,

	["the open rooms as a plot attribute and back"] = function()
		expect.equal(ShopRooms.format({ "backRoom", "gallery" }), "backRoom,gallery")
		expect.equal(ShopRooms.format({}), "")
		local open = ShopRooms.parse("backRoom,gallery")
		expect.equal(open.backRoom, true)
		expect.equal(open.gallery, true)
		expect.isNil(next(ShopRooms.parse(nil)))
		expect.isNil(next(ShopRooms.parse("")))
		local set = ShopRooms.openSet({ "gallery" })
		expect.equal(set.gallery, true)
		expect.isNil(set.backRoom)
	end,

	["each open room adds a customer and 5 shelves"] = function()
		expect.equal(ShopRooms.customerCap(cfg, 4, {}), 4)
		expect.equal(ShopRooms.customerCap(cfg, 4, { backRoom = true }), 5)
		expect.equal(ShopRooms.customerCap(cfg, 4, { backRoom = true, gallery = true }), 6)
		expect.equal(ShopRooms.customerCap(cfg, 4, { attic = true }), 4, "unknown rooms count for nothing")
		expect.equal(ShopRooms.shelfCap(cfg, 30, { gallery = true }), 35)
		expect.equal(ShopRooms.shelfCap(cfg, 30, { backRoom = true, gallery = true }), 40)
	end,

	["unlocking: the room, then open already, the level, then the cash"] = function()
		expect.equal((ShopRooms.canUnlock(cfg, "backRoom", {}, 15, 5000)), true)
		expect.equal(select(2, ShopRooms.canUnlock(cfg, "attic", {}, 99, 1e9)), "That room doesn't exist.")
		expect.equal(select(2, ShopRooms.canUnlock(cfg, 7, {}, 99, 1e9)), "That room doesn't exist.")
		expect.equal(select(2, ShopRooms.canUnlock(cfg, "backRoom", { backRoom = true }, 99, 1e9)), "The Back Room is open already.")
		expect.equal(select(2, ShopRooms.canUnlock(cfg, "backRoom", {}, 14, 1e9)), "Reach shop level 15 to open the Back Room.")
		expect.equal(select(2, ShopRooms.canUnlock(cfg, "gallery", {}, 30, 19999)), "You need $20,000 to open the Gallery.")
	end,

	["walls, door paths and locked rooms are never placeable; an open room's floor is"] = function()
		local closed = ShopRooms.blockers(cfg, GRID, {})
		local wall = find(closed, "InnerWall", nil) :: ShopRooms.Rect
		expect.equal(wall.x, 0)
		expect.equal(wall.z, 20)
		expect.equal(wall.w, 25)
		expect.equal(wall.d, 1)
		local split = find(closed, "RoomWall", nil) :: ShopRooms.Rect
		expect.equal(split.x, 12)
		expect.equal(split.z, 21)
		expect.equal(split.w, 1)
		expect.equal(split.d, 9)
		local hallPath = find(closed, "DoorPathHall", "backRoom") :: ShopRooms.Rect
		expect.equal(hallPath.x, 6)
		expect.equal(hallPath.z, 18)
		expect.equal(hallPath.w, 4)
		expect.equal(hallPath.d, 2)
		local roomPath = find(closed, "DoorPathRoom", "gallery") :: ShopRooms.Rect
		expect.equal(roomPath.x, 15)
		expect.equal(roomPath.z, 21)
		expect.equal((find(closed, "LockedRoom", "backRoom") :: ShopRooms.Rect).w, 12)
		local open = ShopRooms.blockers(cfg, GRID, { backRoom = true })
		expect.isNil(find(open, "LockedRoom", "backRoom"), "an open room's floor is free")
		expect.equal(find(open, "LockedRoom", "gallery") ~= nil, true)
		expect.equal(find(open, "DoorPathRoom", "backRoom") ~= nil, true, "its door path stays clear")
	end,

	["the doors: 8 wide, 10 high, in the hall's back wall, sliding into the wall beside them"] = function()
		local doors = ShopRooms.doors(cfg, GRID)
		expect.equal(#doors, 2)
		expect.equal(doors[1].room, "backRoom")
		expect.equal(doors[1].part, "BackRoomDoor")
		expect.equal(doors[1].x, -9)
		expect.equal(doors[1].z, 11)
		expect.equal(doors[1].width, 8)
		expect.equal(doors[1].height, 10)
		expect.equal(doors[1].slide, -1)
		expect.equal(doors[2].x, 9)
		expect.equal(doors[2].slide, 1)
		-- each door's slide side has at least a door's width of wall to hide in
		expect.equal((doors[1].x - 4) - -25 >= 8, true)
		expect.equal(25 - (doors[2].x + 4) >= 8, true)
	end,

	["the inner walls: the hall's back wall with two doorways and the wall between the rooms"] = function()
		local walls = ShopRooms.innerWalls(cfg, GRID)
		expect.equal(#walls, 2)
		local back, split = walls[1], walls[2]
		expect.equal(back.axis, "x")
		expect.equal(back.at, 11)
		expect.equal(back.from, -25)
		expect.equal(back.to, 25)
		expect.equal(#back.holes, 2)
		expect.equal(back.holes[1].from, -13)
		expect.equal(back.holes[1].to, -5)
		expect.equal(back.holes[1].top, 10)
		expect.equal(split.axis, "z")
		expect.equal(split.at, 0)
		expect.equal(split.from, 11.5)
		expect.equal(split.to, 30)
	end,

	["the walls inside open space: the hall's, then each open room's"] = function()
		local hall = ShopRooms.runs(cfg, GRID, {})
		expect.equal(#hall, 3)
		expect.equal(hall[1].side, "left")
		expect.equal(hall[1].at, -25)
		expect.equal(hall[1].from, -30)
		expect.equal(hall[1].to, 10.5)
		expect.equal(hall[1].inward, 1)
		expect.equal(hall[2].side, "right")
		expect.equal(hall[2].inward, -1)
		expect.equal(hall[3].side, "back")
		expect.equal(hall[3].at, 10.5)
		expect.equal(#hall[3].holes, 2)
		expect.equal(hall[3].inward, -1)
		local both = ShopRooms.runs(cfg, GRID, { backRoom = true, gallery = true })
		expect.equal(#both, 11, "3 + 4 a room")
		local backRoom = ShopRooms.runs(cfg, GRID, { backRoom = true })
		-- the Back Room: its left wall, the wall between the rooms, the outer back wall, the hall wall's room face
		expect.equal(backRoom[4].side, "left")
		expect.equal(backRoom[4].from, 11.5)
		expect.equal(backRoom[4].to, 30)
		expect.equal(backRoom[5].side, "inner")
		expect.equal(backRoom[5].at, -0.5)
		expect.equal(backRoom[5].inward, -1)
		expect.equal(backRoom[6].side, "outerBack")
		expect.equal(backRoom[6].at, 30)
		expect.equal(backRoom[6].to, -0.5)
		expect.equal(backRoom[7].side, "inner")
		expect.equal(backRoom[7].at, 11.5)
		expect.equal(#backRoom[7].holes, 1)
		expect.equal(backRoom[7].inward, 1)
	end,

	["windows go on the side walls' open stretches, posters also between the doors"] = function()
		local spans = ShopRooms.windowSpans(cfg, GRID, {})
		expect.equal(#spans.left, 2)
		expect.equal(spans.left[1].from, -30)
		expect.equal(spans.left[1].to, 10.5)
		expect.isNil(spans.left[1].locked)
		expect.equal(spans.left[2].from, 11.5)
		expect.equal(spans.left[2].to, 30)
		expect.equal(spans.left[2].room, "backRoom")
		expect.equal(spans.left[2].locked, true)
		expect.equal(spans.left[2].name, "Back Room")
		expect.equal(spans.right[2].room, "gallery")
		expect.equal(#spans.back, 3)
		expect.equal(spans.back[2].from, -5)
		expect.equal(spans.back[2].to, 5)
		expect.equal(spans.back[2].posters, true)
		expect.isNil(ShopRooms.windowSpans(cfg, GRID, { backRoom = true }).left[2].locked)
	end,

	["a strip along a wall is cut where a doorway reaches it"] = function()
		local holes = ShopRooms.innerWalls(cfg, GRID)[1].holes
		local band = ShopRooms.gaps(-25, 25, holes, 0, 3.4)
		expect.equal(#band, 3)
		expect.equal(band[1].to, -13)
		expect.equal(band[2].from, -5)
		expect.equal(band[3].from, 13)
		expect.equal(#ShopRooms.gaps(-25, 25, holes, 15.5, 15.8), 1, "over the doors it runs on")
	end,

	["the inner walls leave room for the look's band and the wall gap"] = function()
		local shell = require("../src/shared/Config/Decor").SHELL
		local spare = (2 - cfg.WALL_THICK) / 2 -- a wall in the middle of its 2-stud cell row
		expect.equal(spare >= shell.LINER + shell.BAND_DEEP + shell.WALL_GAP, true)
	end,

	["Pish's room lessons come at the rooms' levels"] = function()
		local pish = require("../src/shared/Config/Pish")
		for _, id in cfg.ORDER do
			local found: any = nil
			for _, lesson in pish.LESSONS do
				if lesson.id == id then
					found = lesson
				end
			end
			expect.equal(found ~= nil and found.level == cfg.ROOMS[id].level and found.late == true, true, id)
		end
	end,
}
