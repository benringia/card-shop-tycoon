--!strict
-- The HUD layout (client only): blue icon tiles on the left (Manage, with its tray) and bottom centre (Cards,
-- Bag, and contextual tiles like Rip a pack), pills at the top centre. Pixels. See DESIGN.md (UI) and Util/Hud.
return {
	TILE_SIZE = Vector2.new(84, 84),
	SIDE_X = 12, -- left edge of the side column
	BOTTOM_MARGIN = 16, -- the bottom row sits this far above the screen's bottom
	GAP = 10,
	TRAY = { PADDING = 8, TRANSPARENCY = 0.35 }, -- the bar the Manage tiles slide out in
	TILE = Color3.fromRGB(38, 110, 245),
	TILE_DARK = Color3.fromRGB(22, 70, 200), -- tile gradient bottom
	CONTEXT = Color3.fromRGB(245, 140, 40), -- contextual tiles (Rip a pack, Drop box)
	KEY_CHIP = Color3.fromRGB(20, 28, 60),
	TOP_Y = 8, -- the top pill bar, from the top of the screen (below Roblox's own top bar)
}
