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
	BOXES_PER_LAYER = 4, -- 2x2 grid on the delivery pad, then stack upward
	CARRY_OFFSET = CFrame.new(0, 0, -2), -- in front of the HumanoidRootPart
}
