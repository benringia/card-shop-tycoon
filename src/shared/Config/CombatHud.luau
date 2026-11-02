--!strict
-- The boss-fight HUD (spec 2026-11-02-you-in-the-fight-design): style 3 "anime slash" buttons in layout A
-- (UiLayout.combatButtons places them). Each button is a slanted dark panel with neon edges in its colour
-- (tools/textures/make_slant_buttons.py, uploaded), an icon (Config/UIIcons sheet 5; `emoji` if one is missing), a
-- cooldown that drains top-down with the seconds left, and on PC its key on a corner chip. Plain data.
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

return {
	SLANT_FILL = "rbxassetid://98874676446555",
	SLANT_EDGE = "rbxassetid://112893972215694",
	PANEL_COLOR = rgb(20, 16, 30), -- the dark face of every button
	PANEL_TRANSPARENCY = 0.15,
	BUTTONS = {
		attack = { color = rgb(255, 179, 71), icon = "Attack", emoji = "⚔️", key = "Click" },
		dodge = { color = rgb(77, 163, 255), icon = "Dodge", emoji = "💨", key = "Shift" },
		skill = { color = rgb(167, 139, 250), icon = "SpinSkill", emoji = "🌀", key = "E" },
		pet = { color = rgb(74, 222, 128), icon = "Paw", emoji = "🐾", key = "R" },
		signature = { color = rgb(250, 204, 21), icon = "Sparkle", emoji = "✨", key = nil },
		swap = { color = rgb(200, 205, 220), icon = "Swap", emoji = "🔄", key = "1-3" },
		run = { color = rgb(248, 113, 113), icon = "Run", emoji = "🏃", key = nil },
	},
	COOLDOWN_SHADE = 0.45, -- transparency of the dark drain over a button cooling down
	READY_FLASH = 0.25, -- seconds a button glows when it's ready again
	-- Top-left: your HP and your creature's
	STATUS_WIDTH = 0.27, -- of the screen's width
	STATUS_MAX_WIDTH = 300,
	PLAYER_HP_COLOR = rgb(62, 224, 138),
	CREATURE_HP_COLOR = rgb(34, 197, 94),
	DOWN_COLOR = rgb(248, 113, 113),
}
