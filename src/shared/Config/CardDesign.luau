--!strict
-- The look of a card face (client only): full-art cards with a thin rarity-coloured rim, built in code.
-- The art fills the card; name and grade sit on the top, the value on the bottom, in outlined text.
-- Layout is in fractions of the card. See DESIGN.md section 5.7.
export type Box = { x: number, y: number, w: number, h: number }

return {
	IMAGES = {
		-- "Glow Circle / Radial Glow" (Creator Store 88881587400917), tinted per rarity
		GLOW = "rbxassetid://118302663239247",
	},

	-- Card art. A card's own picture (by card name) wins; otherwise its element's scene with the element
	-- emoji standing in for the creature; with no scene either, an element-coloured gradient.
	-- These will be replaced by renders of the creature models later.
	ART_IMAGES = {} :: { [string]: string },
	-- By element. Painted with Figma's image generator; the JPEGs are kept in assets/ui/card-scenes.
	SCENES = {
		Ember = "rbxassetid://131233630668123", -- fireplace
		Tide = "rbxassetid://97300154620727", -- coral reef
		Bloom = "rbxassetid://71240095691398", -- forest clearing
		Volt = "rbxassetid://102167319370921", -- stormy peak
		Shade = "rbxassetid://136974770450599", -- moonlit graveyard
	} :: { [string]: string },

	RIM_WIDTH = 0.035, -- of the card's width: the rim around the art
	CORNER = 0.07, -- of the card's shorter side
	ART_CORNER = 0.05,
	EMOJI_CENTER = 0.48, -- placeholder creature: centre height within the art
	EMOJI_SIZE = 0.5, -- of the art's width
	-- Rim colours: light at the top, darker at the bottom
	RIMS = {
		Common = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 196, 212) },
		Rare = { Color3.fromRGB(130, 190, 255), Color3.fromRGB(40, 95, 225) },
		["Very Rare"] = { Color3.fromRGB(130, 245, 235), Color3.fromRGB(20, 150, 165) },
		Epic = { Color3.fromRGB(215, 150, 255), Color3.fromRGB(125, 50, 215) },
		Legendary = { Color3.fromRGB(255, 240, 150), Color3.fromRGB(230, 150, 20) },
	} :: { [string]: { Color3 } },
	FOIL_RIM_SECONDS = 3, -- one turn of the rainbow round a foil card's rim
	FOIL_RIM = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 200)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 220, 110)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(130, 255, 160)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(110, 220, 255)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(190, 140, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 200)),
	}),

	-- Where things sit (fractions of the whole card). Stars, level and the foil tag show on detailed faces only.
	TEXT = {
		NAME = { x = 0.07, y = 0.035, w = 0.64, h = 0.085 } :: Box, -- element emoji and name, top left
		GRADE = { x = 0.75, y = 0.035, w = 0.18, h = 0.075 } :: Box, -- grade letter pill, top right
		STARS = { x = 0.07, y = 0.125, w = 0.4, h = 0.05 } :: Box, -- under the name
		LEVEL = { x = 0.73, y = 0.12, w = 0.22, h = 0.06 } :: Box, -- under the grade
		FOIL = { x = 0.07, y = 0.765, w = 0.3, h = 0.055 } :: Box, -- above the value
		VALUE = { x = 0.06, y = 0.83, w = 0.88, h = 0.115 } :: Box, -- bottom centre
	},
	OUTLINE = 0.09, -- text outline thickness, of the text box's height
	OUTLINE_COLOR = Color3.fromRGB(25, 18, 40),
	SHADE = 0.45, -- how dark the soft bands behind the top and bottom text get (0 none, 1 black)
	EMPTY_STAR_TRANSPARENCY = 0.7,
	GRADE_COLORS = {
		C = Color3.fromRGB(130, 130, 145),
		B = Color3.fromRGB(60, 170, 85),
		A = Color3.fromRGB(60, 125, 240),
		S = Color3.fromRGB(235, 165, 25),
	},
	LEVEL_CHIP = Color3.fromRGB(25, 18, 40),
	LEVEL_CHIP_TRANSPARENCY = 0.3,

	-- The face-down card: a deep blue card with the shop's name
	BACK = {
		RIM = { Color3.fromRGB(120, 170, 255), Color3.fromRGB(40, 70, 200) },
		INSIDE = { Color3.fromRGB(70, 110, 245), Color3.fromRGB(25, 35, 120) },
		TITLE = "CARD\nSHOP",
		EMBLEM = "🃏",
	},
	MISSING = {
		RIM = { Color3.fromRGB(150, 155, 170), Color3.fromRGB(95, 100, 115) },
		INSIDE = Color3.fromRGB(45, 47, 60),
	},

	EMOJI = { Ember = "🔥", Tide = "💧", Bloom = "🌿", Volt = "⚡", Shade = "🌙" },
	VALUE_TEXT = Color3.fromRGB(255, 255, 255),
	PRICE_TEXT = Color3.fromRGB(255, 215, 90), -- a case's asking price

	SHINE_FROM = "Epic", -- this rarity and up get a white shine sweeping across the art now and then
	SHINE_SECONDS = 1.1, -- one sweep
	SHINE_PAUSE = 2.5, -- between sweeps
	FOIL_TRANSPARENCY = 0.55, -- the rainbow holo over foil art
	-- Grade S Legendaries: an electric gold rim spinning round the art (cases add lightning: Config/CardEffects)
	SUPREME_RIM = {
		THICKNESS = 4,
		SECONDS = 1.6, -- one full turn
		COLORS = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 40)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 255, 230)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 170, 20)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 255, 230)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 40)),
		}),
	},
}
