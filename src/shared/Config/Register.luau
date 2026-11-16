--!strict
-- Register checkout. See DESIGN.md section 4.6.
return {
	REACH = 12, -- studs; how far the owner can be from the register to scan and charge
	SCAN_COOLDOWN = 0.15, -- seconds between scans per player
	CHARGE_COOLDOWN = 0.5,

	ITEM_SIZE = Vector3.new(1, 0.3, 1.4), -- a pack lying on the counter
	ITEM_SPACING = 1.3,
	ITEM_COLOR = Color3.fromRGB(255, 170, 60),

	-- Played at the register (heard nearby; the owner's taps and a cashier's alike). Licensed Pro Sound Effects
	-- (owner 2026-11-16: "add sound effects when a player sold something and when a player clicked on the card")
	SCAN_SOUND_ID = "rbxassetid://9118777639", -- Scanner Beeps 12 (a store checkout beep, 0.7 s)
	SCAN_VOLUME = 0.5,
	-- a sale: the drawer opening under a bright ding
	SALE_SOUNDS = {
		{ id = "rbxassetid://9113728042", volume = 0.5 }, -- Cash Register 1 (electronic drawer, 2.1 s)
		{ id = "rbxassetid://9126074485", volume = 0.35 }, -- Synth Sparkle Tone High Pitch Tone Burst Ding (0.8 s)
	} :: { { id: string, volume: number } },
	MIN_XP_PER_SALE = 1, -- XP per sale = sale total rounded, at least this
}
