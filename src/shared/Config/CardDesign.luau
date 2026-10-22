--!strict
-- The look of a card face (client only): image ids, layout as fractions of the card, colours.
-- Frame images are drawn by tools/card-frames/make_frames.py (600x840, saved in assets/ui/card-frames) and
-- uploaded to the game owner's account; the boxes below are measured from that 600x840 layout.
-- A missing frame id falls back to a plain rarity-coloured card. See DESIGN.md section 5.7.
export type Box = { x: number, y: number, w: number, h: number }

return {
	IMAGES = {
		-- One full-art frame per rarity (transparent art window), keyed by rarity name, plus Frontier
		FRAMES = {
			Common = "rbxassetid://75093670445013",
			Rare = "rbxassetid://70681193815131",
			["Very Rare"] = "rbxassetid://81299306585658",
			Epic = "rbxassetid://111780676111166",
			Legendary = "rbxassetid://76146349903815",
			Frontier = "rbxassetid://87019213393421",
		} :: { [string]: string },
		-- "Glow Circle / Radial Glow" (Creator Store 88881587400917), tinted per rarity
		GLOW = "rbxassetid://118302663239247",
		-- "Glowing neon card frame" (Creator Store 93396924861432), the face-down card
		BACK = "rbxassetid://88901535925819",
	},

	-- The art window inside the border; the art (and the shine, holo and aurora) is drawn here
	ART = { x = 0.05, y = 0.0357, w = 0.9, h = 0.9286 } :: Box,
	ART_CORNER = 0.045,
	EMOJI_CENTER = 0.25, -- placeholder emoji: centre height within the art, above the info panel
	EMOJI_SIZE = 0.36, -- of the art's width

	-- Where the text sits on the frame (fractions of the whole card). The info panel (y 420-796 of 840) holds
	-- one row each; the frame's divider line is at y 598, between LEVEL and STATS, so no text crosses it.
	TEXT = {
		RIBBON = { x = 0.057, y = 0.026, w = 0.393, h = 0.05 } :: Box, -- rarity, in the top-left ribbon
		HEX = { x = 0.833, y = 0.045, w = 0.1, h = 0.062 } :: Box, -- level, in the top-right hex
		NAME = { x = 0.107, y = 0.514, w = 0.68, h = 0.074 } :: Box, -- y 432-494
		SOCKET = { x = 0.817, y = 0.523, w = 0.08, h = 0.057 } :: Box, -- element emoji, in the panel's socket
		STARS = { x = 0.107, y = 0.598, w = 0.5, h = 0.048 } :: Box, -- y 502-542: one star per slot, empty ones faint
		GRADE = { x = 0.66, y = 0.598, w = 0.24, h = 0.048 } :: Box, -- a pill in the grade's colour
		LEVEL = { x = 0.107, y = 0.652, w = 0.79, h = 0.043 } :: Box, -- y 548-584: level and element
		STATS = { x = 0.093, y = 0.726, w = 0.813, h = 0.067 } :: Box, -- y 610-666: below the divider
		VALUE = { x = 0.093, y = 0.805, w = 0.813, h = 0.07 } :: Box, -- y 676-735
		FOIL = { x = 0.04, y = 0.07, w = 0.4, h = 0.05 } :: Box, -- within the art, under the ribbon
	},
	EMPTY_STAR_TRANSPARENCY = 0.75,
	LOADING_BORDER = 4, -- pixels: the rarity-coloured border shown while a frame image is still downloading
	GRADE_COLORS = {
		C = Color3.fromRGB(130, 130, 145),
		B = Color3.fromRGB(60, 170, 85),
		A = Color3.fromRGB(60, 125, 240),
		S = Color3.fromRGB(235, 165, 25),
	},

	EMOJI = { Ember = "🔥", Tide = "💧", Bloom = "🌿", Volt = "⚡", Shade = "🌙" },
	HEX_TEXT = Color3.fromRGB(255, 225, 120),
	SUBTEXT = Color3.fromRGB(210, 205, 225),
	VALUE_TEXT = Color3.fromRGB(120, 230, 140),
	PRICE_TEXT = Color3.fromRGB(255, 215, 90), -- a case's asking price

	SHINE_FROM = "Epic", -- this rarity and up get a white shine sweeping across the art now and then
	SHINE_SECONDS = 1.1, -- one sweep
	SHINE_PAUSE = 2.5, -- between sweeps
	FOIL_TRANSPARENCY = 0.5, -- the rainbow holo over foil art
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
