--!strict
-- HUD pieces that grow on a desktop (owner 2026-11-21, launch day: the quest strip "increase font size. its small on
-- the laptops", the party dock "also make this bigger on desktop"). The HUD's own scale (Config/HudLayout SCALE) only
-- shrinks: 1 at 560 px tall and up. On a mouse-and-keyboard screen the HUD's pieces (the tiles, the cash, the toasts,
-- the dock, the quest strip) also grow with the screen's height: 1 at REFERENCE px, up to MAX (Util/HudGrow; client
-- Util/Hud.scaleWith `grow`). Touch screens keep their own sizes.
-- Plain data (Lune-tested).
return {
	REFERENCE = 560,
	MAX = 1.35,
	-- Every window too (owner 2026-11-21: "increase overall font sizes for desktop. fontsizes are too small for
	-- laptops"): a UIKit.panel grows by the same share, as far as it still fits WINDOW_FIT of the screen each way
	-- (Util/HudGrow.window; the growth is the panel's rest scale, Util/Motion). WINDOWS false turns it off.
	WINDOWS = true,
	WINDOW_FIT = 0.94,
	-- A scaled HUD piece carries its scale at rest in this attribute (Hud.scaleWith), so an animation on the same
	-- UIScale (the quest strip's fold bump) starts and ends there, not at 1 (Util/HudGrow.rest, bump)
	ATTRIBUTE = "HudScale",
}
