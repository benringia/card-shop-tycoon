--!strict
-- The game's fonts (client only), rounded like the reference UI. Util/FontStyle applies them.
-- (Fredoka itself only draws in Studio's Edit mode, not in Play, so it isn't used.)
return {
	BOLD = Font.new("rbxasset://fonts/families/FredokaOne.json"), -- titles, buttons, names, numbers
	BODY = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold), -- descriptions, small text
}
