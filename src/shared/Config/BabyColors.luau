--!strict
-- The cotton candy look's baby colours (owner 2026-11-03, look A; spec 2026-11-03-cotton-candy-ui-design): six bright
-- pastels that pop, each with a light shade (gradient tops, glows) and a deep shade (the outline round white labels,
-- a portrait rim's underside). Plain data (Lune-tested: tests/SoftColors); UIStyle.BABY turns them into Color3s.
return {
	COLORS = {
		pink = { fill = { 255, 127, 184 }, light = { 255, 196, 223 }, deep = { 212, 60, 130 } }, -- bubblegum
		mint = { fill = { 63, 214, 160 }, light = { 169, 242, 213 }, deep = { 24, 140, 100 } },
		sky = { fill = { 79, 180, 255 }, light = { 180, 224, 255 }, deep = { 28, 120, 200 } },
		lilac = { fill = { 162, 116, 255 }, light = { 220, 203, 255 }, deep = { 118, 70, 217 } },
		butter = { fill = { 255, 201, 63 }, light = { 255, 231, 163 }, deep = { 176, 118, 0 } },
		peach = { fill = { 255, 148, 104 }, light = { 255, 208, 187 }, deep = { 205, 84, 46 } },
		greyLilac = { fill = { 185, 169, 207 }, light = { 222, 213, 234 }, deep = { 112, 94, 138 } }, -- disabled, Admin
		white = { fill = { 255, 255, 255 }, light = { 255, 255, 255 }, deep = { 217, 200, 230 } }, -- neutral buttons
	},
	INK = { 91, 61, 110 }, -- plum: text on light buttons
	LIGHT_LUMA = 0.75, -- fills brighter than this (butter, white) take plum text; the rest white with a deep outline
	-- The kit's named colours (UIKit.Colors) and the baby colour each becomes in the soft look
	ROLES = {
		Accent = "butter", -- the main action
		Secondary = "sky", -- other choices
		Danger = "pink", -- remove or leave
		Success = "mint", -- summoned, confirm
		Locked = "greyLilac", -- can't be used now
		Row = "white", -- neutral
		Panel = "white",
	},
	-- Each element's colour on a party portrait's rim
	ELEMENTS = { Ember = "peach", Tide = "sky", Bloom = "mint", Volt = "butter", Shade = "lilac" },
}
