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
	GAP = 8, -- space between neighbouring plots in a row
	STREET_WIDTH = 30, -- distance between the two rows

	FREE_COLOR = Color3.fromRGB(120, 120, 120),
	OWNED_COLOR = Color3.fromRGB(205, 185, 150),

	-- Sign floats above the front edge, facing the street
	SIGN_SIZE = Vector3.new(16, 4, 1),
	SIGN_HEIGHT = 8,
	SIGN_COLOR = Color3.fromRGB(40, 40, 50),
	SIGN_TEXT_COLOR = Color3.fromRGB(255, 255, 255),
	FREE_SIGN_TEXT = "For Rent",
	OWNED_SIGN_FORMAT = "%s's Card Shop",

	-- Owner's spawn pad: this far in from the front edge, facing into the shop
	SPAWN_INSET = 6,
	SPAWN_PAD_SIZE = Vector3.new(4, 1, 4),

	-- Order computer sits in a back corner, screen facing the shop front
	COMPUTER_SIZE = Vector3.new(4, 3, 2),
	COMPUTER_INSET = 4, -- from the back and side walls
	COMPUTER_COLOR = Color3.fromRGB(60, 65, 80),
	COMPUTER_TEXT = "ORDER STOCK",

	-- Delivery pad sits in a front corner, where ordered boxes appear
	DELIVERY_PAD_SIZE = Vector3.new(6, 0.2, 6),
	DELIVERY_INSET = 5, -- from the front and side walls
	DELIVERY_COLOR = Color3.fromRGB(240, 200, 60),
}
