--!strict
-- Register checkout. See DESIGN.md section 4.6.
return {
	REACH = 12, -- studs; how far the owner can be from the register to scan and charge
	SCAN_COOLDOWN = 0.15, -- seconds between scans per player
	CHARGE_COOLDOWN = 0.5,

	ITEM_SIZE = Vector3.new(1, 0.3, 1.4), -- a pack lying on the counter
	ITEM_SPACING = 1.3,
	ITEM_COLOR = Color3.fromRGB(255, 170, 60),

	SCAN_SOUND_ID = "", -- paste a beep sound asset ID (e.g. "rbxassetid://123") to play on each scan
	MIN_XP_PER_SALE = 1, -- XP per sale = sale total rounded, at least this
}
