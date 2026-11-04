--!strict
-- The game's fonts (client only). Util/FontStyle applies them. Round, cute titles and buttons in FredokaOne; a crisp,
-- premium body in Montserrat (owner 2026-11-03, pick 4 of 4; it was Nunito). Both are Roblox's own fonts, so they draw
-- everywhere. (Fredoka, the newer one, only draws in Studio's Edit mode, not in Play, so it isn't used.)
return {
	BOLD = Font.new("rbxasset://fonts/families/FredokaOne.json"), -- titles, buttons, names, numbers
	BODY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold), -- descriptions, small text
}
