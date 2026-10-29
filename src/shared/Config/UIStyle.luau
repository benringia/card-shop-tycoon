--!strict
-- Look E, "bold hybrid" (spec 2026-10-29-collection-screens-ui-design.md 3.1; DESIGN.md 10.6): a calm dark slate body
-- with a thick outline and a drop lip, a coloured header band per window, outlined titles and big numbers, candy
-- buttons and chunky bars. Util/UIKit builds with these; screens never hard-code colours or text sizes.
-- Rarity colours stay in Config/Rarities and element colours in Config/Cards (ELEMENTS).
local function band(top: Color3, bottom: Color3): { top: Color3, bottom: Color3 }
	return { top = top, bottom = bottom }
end

local TEAL = band(Color3.fromRGB(54, 209, 196), Color3.fromRGB(26, 143, 158))

return {
	PANEL = Color3.fromRGB(27, 34, 51), -- window body
	ROW = Color3.fromRGB(36, 45, 66), -- rows, tiles and stat cards on a window
	EDGE = Color3.fromRGB(11, 15, 26), -- outlines, text outlines, bar tracks, the drop lip
	EDGE_THICKNESS = 3, -- window and button outlines (px)
	LIP = 5, -- the drop lip under a window (px)

	-- The header band across the top of each window (UIKit.panel's `header`)
	HEADERS = {
		Party = TEAL,
		Cards = band(Color3.fromRGB(90, 169, 255), Color3.fromRGB(59, 123, 224)), -- binder, card detail
		Bosses = band(Color3.fromRGB(255, 122, 122), Color3.fromRGB(226, 59, 59)),
		Bag = band(Color3.fromRGB(255, 176, 102), Color3.fromRGB(230, 120, 40)),
		Default = TEAL,
	},

	-- Button and meaning colours
	GOLD = Color3.fromRGB(245, 180, 40), -- the main action; hints and the selected thing use HINT
	BLUE = Color3.fromRGB(70, 140, 235), -- other choices
	RED = Color3.fromRGB(226, 59, 59), -- remove, leave, close
	GREEN = Color3.fromRGB(36, 168, 90), -- summoned, the cash pill
	POWER = Color3.fromRGB(255, 176, 102),
	MONEY = Color3.fromRGB(69, 212, 131),
	GOOD = Color3.fromRGB(69, 212, 131), -- ready, enough, better
	BAD = Color3.fromRGB(255, 107, 107), -- locked, not enough, worse
	HINT = Color3.fromRGB(226, 178, 72),
	XP = Color3.fromRGB(90, 160, 255), -- XP bars
	GRADES = {
		S = Color3.fromRGB(255, 200, 40),
		A = Color3.fromRGB(70, 140, 255),
		B = Color3.fromRGB(69, 212, 131),
		C = Color3.fromRGB(160, 160, 160),
	},

	BAR = {
		height = 12,
		phoneHeight = 10,
		fillTop = Color3.fromRGB(143, 240, 181),
		fillBottom = Color3.fromRGB(47, 191, 106),
	},

	-- Text sizes (px); phones use PHONE_TEXT_SCALE of these (UIKit.textSize)
	TEXT = { body = 15, small = 13, name = 22, number = 23, title = 28 },
	PHONE_TEXT_SCALE = 0.85,

	KEY_TINT_PRISM = Color3.fromRGB(235, 235, 255), -- the Hydra's key fragments (the others take their boss's element colour)
	LONG_PRESS = 0.45, -- seconds a touch is held to show a tooltip
	MIN_TAP = 48, -- px: the smallest button a finger gets (desktop-only buttons may be smaller)
}
