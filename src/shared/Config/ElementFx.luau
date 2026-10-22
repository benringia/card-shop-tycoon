--!strict
-- Element effects (client only): the aura on displayed Legendaries (and later, summoned creatures).
-- Ember burns, Tide bubbles, Bloom sheds petals, Volt crackles with lightning, Shade smokes. How strong it is
-- comes from the copy's grade and stars (Util/ElementFxRules): every { low, high } pair below is the value at
-- intensity 0 and at intensity 1. Plain data (colours as { r, g, b }) so Lune tests can load it.
-- Textures are Roblox's built-in particle images, so nothing has to be uploaded.
export type Range = { number }
export type Rgb = { number }
export type Emitter = {
	texture: string,
	colors: { Rgb }, -- over the particle's life
	rate: Range, -- particles per second
	size: Range, -- studs at birth (shrinks to 0)
	speed: Range,
	lifetime: { number }, -- seconds, min and max
	acceleration: { number }, -- x, y, z studs/s²
	spread: number, -- degrees
	lightEmission: number,
	transparency: number, -- at birth (fades to 1)
	rotation: number?, -- spin speed, degrees per second either way
}
export type Light = { color: Rgb, brightness: Range, range: Range, flicker: boolean }
export type Bolts = {
	color: Rgb,
	every: Range, -- seconds between bolts (slower at low intensity)
	length: Range,
	segments: number,
	jitter: number,
	width: number,
	seconds: number,
	flash: number,
	maxDistance: number,
}
export type ElementFx = { emitters: { Emitter }, light: Light, bolts: Bolts? }

local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

return {
	-- intensity = BASE + GRADE[grade] + PER_STAR * stars, kept within 0..1 (Grade C, 0 stars = BASE; S, 5 stars = 1)
	INTENSITY = { BASE = 0.25, GRADE = { C = 0, B = 0.12, A = 0.25, S = 0.45 }, PER_STAR = 0.06, MAX_STARS = 5 },

	ELEMENTS = {
		Ember = {
			emitters = {
				{ texture = FIRE, colors = { { 255, 220, 110 }, { 255, 90, 30 } }, rate = { 4, 28 }, size = { 0.3, 0.75 },
					speed = { 0.4, 1.3 }, lifetime = { 0.5, 0.9 }, acceleration = { 0, 2.5, 0 }, spread = 25,
					lightEmission = 1, transparency = 0.15 },
				{ texture = SPARKLE, colors = { { 255, 170, 60 }, { 255, 80, 20 } }, rate = { 2, 14 }, size = { 0.07, 0.14 },
					speed = { 1, 2.6 }, lifetime = { 1, 1.8 }, acceleration = { 0, 1.5, 0 }, spread = 60,
					lightEmission = 1, transparency = 0 },
			},
			light = { color = { 255, 130, 40 }, brightness = { 1, 4 }, range = { 5, 10 }, flicker = true },
		},
		Tide = {
			emitters = {
				{ texture = SPARKLE, colors = { { 190, 235, 255 }, { 80, 170, 255 } }, rate = { 3, 18 }, size = { 0.1, 0.24 },
					speed = { 0.3, 0.9 }, lifetime = { 1.2, 2.2 }, acceleration = { 0, 1.2, 0 }, spread = 40,
					lightEmission = 0.6, transparency = 0.1 },
				{ texture = SMOKE, colors = { { 120, 200, 255 }, { 60, 130, 230 } }, rate = { 1, 7 }, size = { 0.4, 0.9 },
					speed = { 0.1, 0.4 }, lifetime = { 1.5, 2.5 }, acceleration = { 0, 0.3, 0 }, spread = 60,
					lightEmission = 0.3, transparency = 0.6 },
			},
			light = { color = { 60, 150, 255 }, brightness = { 1, 3.5 }, range = { 5, 9 }, flicker = false },
		},
		Bloom = {
			emitters = {
				{ texture = SPARKLE, colors = { { 150, 240, 110 }, { 70, 180, 80 } }, rate = { 2, 12 }, size = { 0.12, 0.24 },
					speed = { 0.2, 0.6 }, lifetime = { 2, 3.2 }, acceleration = { 0, -0.25, 0 }, spread = 180,
					lightEmission = 0.4, transparency = 0, rotation = 90 },
				{ texture = SPARKLE, colors = { { 255, 190, 220 }, { 255, 130, 180 } }, rate = { 1, 8 }, size = { 0.1, 0.2 },
					speed = { 0.2, 0.5 }, lifetime = { 2, 3 }, acceleration = { 0, -0.2, 0 }, spread = 180,
					lightEmission = 0.4, transparency = 0, rotation = 120 },
			},
			light = { color = { 100, 225, 110 }, brightness = { 1, 3 }, range = { 5, 9 }, flicker = false },
		},
		Volt = {
			emitters = {
				{ texture = SPARKLE, colors = { { 255, 245, 140 }, { 160, 220, 255 } }, rate = { 3, 20 }, size = { 0.08, 0.18 },
					speed = { 2, 4.5 }, lifetime = { 0.25, 0.55 }, acceleration = { 0, 0, 0 }, spread = 180,
					lightEmission = 1, transparency = 0 },
			},
			light = { color = { 200, 230, 255 }, brightness = { 1, 3.5 }, range = { 5, 9 }, flicker = true },
			bolts = {
				color = { 190, 225, 255 },
				every = { 1.8, 0.35 },
				length = { 0.5, 1.3 },
				segments = 5,
				jitter = 0.14,
				width = 0.06,
				seconds = 0.25,
				flash = 3,
				maxDistance = 70, -- no bolts while the camera is further away than this (saves work)
			},
		},
		Shade = {
			emitters = {
				{ texture = SMOKE, colors = { { 110, 50, 170 }, { 30, 10, 50 } }, rate = { 2, 12 }, size = { 0.45, 1 },
					speed = { 0.2, 0.6 }, lifetime = { 1.5, 2.6 }, acceleration = { 0, 0.7, 0 }, spread = 40,
					lightEmission = 0.2, transparency = 0.35 },
				{ texture = SPARKLE, colors = { { 210, 140, 255 }, { 120, 50, 200 } }, rate = { 2, 12 }, size = { 0.07, 0.15 },
					speed = { 0.4, 1.2 }, lifetime = { 1.2, 2 }, acceleration = { 0, 0.8, 0 }, spread = 70,
					lightEmission = 1, transparency = 0 },
			},
			light = { color = { 150, 70, 230 }, brightness = { 0.8, 2.8 }, range = { 5, 9 }, flicker = false },
		},
	} :: { [string]: ElementFx },

	FLICKER_SECONDS = 0.12, -- a flickering light changes this often
}
