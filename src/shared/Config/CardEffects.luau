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
	pulse: boolean, -- glow (and halo) breathes in and out
	halo: number, -- transparency of the neon halo behind the card, 1 = none
}

return {
	-- Roblox's built-in sparkle texture, so nothing has to be uploaded
	PARTICLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds",

	-- Cards on display should make visitors want to buy: every card face glows (it ignores the room's lighting),
	-- a neon halo in the rarity colour sits behind it, and rarer cards light up the case and sparkle more.
	BY_RARITY = {
		Common = { glow = 0.3, glowRange = 3, sparkleRate = 0, burst = 8, pop = false, flash = false, pulse = false, halo = 0.75 },
		Rare = { glow = 1, glowRange = 5, sparkleRate = 1.5, burst = 18, pop = false, flash = false, pulse = false, halo = 0.45 },
		["Very Rare"] = { glow = 1.3, glowRange = 6, sparkleRate = 3, burst = 24, pop = true, flash = false, pulse = false, halo = 0.35 },
		Epic = { glow = 1.8, glowRange = 7, sparkleRate = 5, burst = 32, pop = true, flash = true, pulse = true, halo = 0.25 },
		Legendary = { glow = 2.6, glowRange = 9, sparkleRate = 3, burst = 55, pop = true, flash = true, pulse = true, halo = 0.1 },
	} :: { [string]: RarityEffect },

	-- Grade S copies shine brighter than the same card in a lower grade
	GRADE_S = { GLOW_MULTIPLIER = 1.35, SPARKLE_MULTIPLIER = 1.5 },

	-- Grade S Legendaries (and Grade S Frontier cards): the best a card can be. A brighter glow and a solid
	-- pulsing halo, on top of their element aura (Config/ElementFx).
	SUPREME = {
		GLOW_MULTIPLIER = 1.2, -- on top of GRADE_S (a stronger light floods the whole shop)
		RANGE_MULTIPLIER = 1.1,
		HALO = 0, -- halo transparency
	},

	FACE_BRIGHTNESS = 1.6, -- the card face on display: brighter than a lit surface, so it glows
	FACE_PIXELS_PER_STUD = 200, -- sharpness of the card face on display
	HALO_MARGIN = 0.06, -- studs the halo sticks out round the card
	HALO_PULSE_TRANSPARENCY = 0.55, -- a pulsing halo fades to this and back

	FOIL_GLINT_RATE = 3, -- extra white glints per second on foil cards
	FOIL_BURST = 12, -- extra white glints added to a foil's listing burst

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
		CASE_EFFECT = { glow = 2.4, glowRange = 9, sparkleRate = 8, burst = 50, pop = true, flash = true, pulse = true, halo = 0.15 },
		REVEAL_SECONDS = 4.5, -- the drop reveal closes itself after this long
	},
}
