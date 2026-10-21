--!strict
-- Plot layout config. See DESIGN.md section 3 and 4.1.
-- Two rows of plots face each other across a street centred on the origin.
return {
	COUNT = 6,
	PER_ROW = 3,

	-- Plot footprint in studs
	WIDTH = 40,
	DEPTH = 40,
	FLOOR_THICKNESS = 1,
	GAP = 24, -- space between neighbouring plots in a row (rows span x -84..84)
	STREET_WIDTH = 60, -- distance between the two rows (the plaza and room for events sit in it)

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
	COMPUTER_SIZE = Vector3.new(4, 3, 2),
	COMPUTER_GRID_X = 17,
	COMPUTER_GRID_Z = 18,
	COMPUTER_COLOR = Color3.fromRGB(60, 65, 80),
	COMPUTER_TEXT = "ORDER STOCK",

	-- Delivery pad sits in a front corner, where ordered boxes appear
	DELIVERY_PAD_SIZE = Vector3.new(6, 0.2, 6),
	DELIVERY_INSET = 5, -- from the front and side walls
	DELIVERY_COLOR = Color3.fromRGB(240, 200, 60),

	-- Register counter on the left side near the back. Customers queue in front of it toward the street;
	-- the owner stands behind it.
	REGISTER_SIZE = Vector3.new(6, 3.5, 2),
	REGISTER_SIDE_INSET = 5, -- from the side wall to the counter centre
	REGISTER_BACK_INSET = 6, -- from the back wall to the counter centre
	REGISTER_TEXT = "REGISTER",

	-- Invisible strip in front of the register that shelves can't be placed on.
	-- Keep QUEUE_ZONE_LENGTH >= Customers.MAX_PER_PLOT * Customers.QUEUE_SPACING.
	QUEUE_ZONE_LENGTH = 14,
	QUEUE_ZONE_WIDTH = 4,
}
