--!strict
-- Plot layout config. See DESIGN.md section 3 and 4.1.
-- Two rows of plots face each other across a street centred on the origin.
return {
	COUNT = 6,
	PER_ROW = 3,

	-- Plot footprint in studs: one building for everyone, a 50 x 40 hall and two rooms behind it (Config/ShopRooms; spec
	-- 2026-11-23-shop-rooms-design; 40 x 40 until then). Plot centres stay put (WIDTH + GAP 64) and so do the fronts
	-- (z +-48); the backs reach z +-108
	WIDTH = 50,
	DEPTH = 60,
	FLOOR_THICKNESS = 1,
	GAP = 14, -- space between neighbouring plots in a row (rows span x -89..89)
	STREET_WIDTH = 96, -- distance between the two rows: the plaza, sidewalks and open room for event NPCs

	FREE_COLOR = Color3.fromRGB(120, 120, 120), -- floor while for rent; owned plots use their theme (Config/Town)

	-- Sign hangs on the front wall above the awning, facing the street
	SIGN_SIZE = Vector3.new(16, 4, 1),
	SIGN_COLOR = Color3.fromRGB(40, 40, 50),
	SIGN_TEXT_COLOR = Color3.fromRGB(255, 255, 255),
	FREE_SIGN_TEXT = "For Rent",
	OWNED_SIGN_FORMAT = "%s's Card Shop",

	-- Owner's spawn pad: this far in from the front edge, facing into the shop
	SPAWN_INSET = 6,
	SPAWN_PAD_SIZE = Vector3.new(4, 1, 4),

	-- Order computer starts in a back corner, screen facing the shop front. The owner can move it;
	-- it returns here when the plot is released. Grid cells count from the front-left corner.
	COMPUTER_SIZE = Vector3.new(10, 5.5, 6), -- a desk with the computer and a chair
	COMPUTER_GRID_X = 20, -- the hall's back-right corner (15 in the 40-wide shop)
	COMPUTER_GRID_Z = 17,
	COMPUTER_COLOR = Color3.fromRGB(60, 65, 80),
	COMPUTER_TEXT = "📦 Order Stock", -- the owner's hover tooltip over it (ShelfInfoController)


	-- Register counter on the left side near the back. Customers queue in front of it toward the street;
	-- the owner stands behind it.
	REGISTER_SIZE = Vector3.new(6, 2.5, 2), -- low, so small cashier pets behind it still show
	REGISTER_SIDE_INSET = 5, -- from the side wall to the counter centre
	REGISTER_BACK_INSET = 6, -- from the back wall to the counter centre
	REGISTER_TEXT = "💰 Register", -- the owner's hover tooltip over the checkout (ShelfInfoController)

	-- Invisible strip in front of the register that shelves can't be placed on.
	-- Keep QUEUE_ZONE_LENGTH >= (Customers.MAX_PER_PLOT + both rooms open) * Customers.QUEUE_SPACING: (4 + 2) * 3
	QUEUE_ZONE_LENGTH = 18,
	QUEUE_ZONE_WIDTH = 4,
}
