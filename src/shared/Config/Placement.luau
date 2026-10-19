--!strict
-- Shelf placement rules. See DESIGN.md section 4.3.
return {
	GRID_SIZE = 2, -- studs per grid cell; plot WIDTH and DEPTH must divide by this
	ROTATION_STEPS = 4, -- 90° turns
	SELL_REFUND = 0.5, -- fraction of the price paid you get back
	MAX_SHELVES_PER_PLOT = 30,
	RESERVED_MARGIN = 1, -- free cells kept around the computer, delivery pad and spawn

	ACTION_COOLDOWN = 0.3, -- seconds between place/move/sell requests per player
	MAX_EDIT_DISTANCE = 40, -- player must be this close to their plot centre to edit it

	-- Every new shop starts with these, free. Grid cells count from the front-left corner.
	STARTER_SHELVES = {
		{ shelfId = "SmallPackRack", gridX = 9, gridZ = 9, rotation = 0 },
	},

	GHOST_VALID_COLOR = Color3.fromRGB(80, 220, 120),
	GHOST_INVALID_COLOR = Color3.fromRGB(230, 70, 70),
	GHOST_TRANSPARENCY = 0.5,
}
