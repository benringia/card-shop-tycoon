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
		Rare = { glow = 1, glowRange = 5, sparkleRate = 0, burst = 18, pop = false, flash = false, pulse = false },
		Epic = { glow = 1.5, glowRange = 7, sparkleRate = 2, burst = 30, pop = true, flash = false, pulse = false },
		Legendary = { glow = 2.5, glowRange = 10, sparkleRate = 5, burst = 50, pop = true, flash = true, pulse = true },
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
}
