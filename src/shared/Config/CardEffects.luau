--!strict
-- Visual effects on cards displayed in Glass Showcases and Collector Cases (client only).
-- "Always on" effects run while a card is on display; the burst plays when a card is listed.
-- Colours come from Rarities; Common bursts use white.
export type RarityEffect = {
	glow: number, -- PointLight brightness, 0 = no light
	glowRange: number,
	sparkleRate: number, -- ambient sparkles per second, 0 = none
	burst: number, -- particles when the card is listed
	pop: boolean, -- card scales up briefly when listed
	flash: boolean, -- bright light flash when listed
	pulse: boolean, -- glow breathes in and out
}

return {
	-- Roblox's built-in sparkle texture, so nothing has to be uploaded
	PARTICLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds",

	BY_RARITY = {
		Common = { glow = 0, glowRange = 0, sparkleRate = 0, burst = 8, pop = false, flash = false, pulse = false },
		-- Glows are kept soft: a full case of six still lights the case, not the whole floor
		Rare = { glow = 0.5, glowRange = 3.5, sparkleRate = 0, burst = 18, pop = false, flash = false, pulse = false },
		["Very Rare"] = { glow = 0.6, glowRange = 4, sparkleRate = 1, burst = 24, pop = false, flash = false, pulse = false },
		Epic = { glow = 0.75, glowRange = 5, sparkleRate = 2, burst = 30, pop = true, flash = false, pulse = false },
		Legendary = { glow = 1.25, glowRange = 7, sparkleRate = 5, burst = 50, pop = true, flash = true, pulse = true },
	} :: { [string]: RarityEffect },

	FOIL_GLINT_RATE = 3, -- extra white glints per second on foil cards
	FOIL_BURST = 12, -- extra white glints added to a foil's listing burst
	SHIMMER_SECONDS = 1.6, -- one sweep of the rainbow band across a foil card

	PULSE_SECONDS = 1.2, -- half a breath of the legendary glow
	POP_SCALE = 1.3,
	POP_SECONDS = 0.18, -- each half of the pop
	FLASH_BRIGHTNESS = 10,
	FLASH_SECONDS = 0.5,

	JOIN_GRACE_SECONDS = 4, -- cards appearing this soon after joining were already on display: no burst

	-- Frontier cards: an aurora look everywhere (card faces, cases, the drop reveal)
	FRONTIER = {
		AURORA = { Color3.fromRGB(70, 230, 210), Color3.fromRGB(150, 90, 255), Color3.fromRGB(255, 205, 80) },
		AURORA_SECONDS = 4, -- one full turn of the aurora border
		BACKGROUND_DARKEN = 0.45, -- the element colour, this much darker
		CASE_EFFECT = { glow = 1.1, glowRange = 6, sparkleRate = 4, burst = 45, pop = true, flash = true, pulse = true },
		REVEAL_SECONDS = 4.5, -- the drop reveal closes itself after this long
	},
}
