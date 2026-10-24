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

	GHOST_VALID_COLOR = Color3.fromRGB(80, 220, 120),
	GHOST_INVALID_COLOR = Color3.fromRGB(230, 70, 70),
	GHOST_TRANSPARENCY = 0.5, -- the plain box ghost (things without a prop model)
	GHOST_MODEL_TRANSPARENCY = 0.35, -- the see-through copy of the real model
	GHOST_FILL_TRANSPARENCY = 0.7, -- its green/red tint
	GHOST_GLIDE = 18, -- how fast the ghost glides to its snapped cell (higher = snappier)
	FOOTPRINT_TRANSPARENCY = 0.55, -- the cells it covers, drawn on the floor
	GHOST_LABEL_HEIGHT = 1.5, -- the name label floats this far above the ghost
	INVALID_TEXT = "Can't place here",

	-- Your own shelves and order computer (ShelfInfoController): point at one (or tap it) and it lights up, with a
	-- tooltip saying what it holds; an empty
	-- product shelf shows a floating "Empty" badge. Studs.
	SHELF_INFO = { REACH = 30, TAP_SECONDS = 2.5, EMPTY_GAP = 0.8, EMPTY_FORWARD = 1.5, EMPTY_MAX_DISTANCE = 60 },
}
