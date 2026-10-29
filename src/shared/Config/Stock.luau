--!strict
-- Ordering, delivery and carrying. See DESIGN.md section 4.2.
return {
	DELIVERY_SECONDS = 10,
	MAX_CARRY = 1, -- Carry Cart upgrade raises this later
	MAX_BOXES_PER_PLOT = 12, -- incoming + waiting + carried, stops order spam filling the shop

	ORDER_COOLDOWN = 0.3, -- seconds between order requests per player
	STOCK_COOLDOWN = 0.3, -- seconds between shelf stocking requests per player
	DROP_COOLDOWN = 0.3,
	PROMPT_DISTANCE = 8, -- ProximityPrompt range
	INTERACT_DISTANCE = 14, -- server-side distance check, a little looser than the prompt

	BOX_SIZE = Vector3.new(2.5, 1.5, 2),
	BOX_COLOR = Color3.fromRGB(190, 145, 95),
	-- Boxes without their own model (Products boxProp) are a branded case (the user's pick, 2026-10-30): printed in the
	-- product's colour with darker bands top and bottom; on the front and back its art (Config/Packs, else its UI icon)
	-- in a gold frame, its name and a dark pill with the count; hand holes on the sides; its name on the lid
	CASE = {
		PIXELS_PER_STUD = 100,
		BAND = 0.11, -- the darker bands, share of a side's height
		DARKEN = 0.3, -- how much darker the bands are
		ART = { 0.05, 0.16, 0.32, 0.68 }, -- the art's x, y, width, height, shares of the front
		FRAME = { 232, 186, 70 }, -- gold
		PILL = { 24, 26, 34 },
		HANDLE = { 30, 22, 16 },
	},
	BOXES_PER_LAYER = 4, -- 2x2 grid on the delivery pad, then stack upward
	CARRY_OFFSET = CFrame.new(0, 0, -2), -- in front of the HumanoidRootPart
}
