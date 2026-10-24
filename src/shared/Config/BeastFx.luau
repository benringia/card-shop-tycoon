--!strict
-- Effects on the big saved-animation beasts (the Crystal Titan Legendaries), client only (Util/BeastAura):
-- element fire burning on bones spread over the body (it moves with the animation), lightning arcing between
-- them, flames licking up from the ground, a flickering light and dust from the feet. Sizes and speeds are for a
-- creature of size 1 and grow with its size. Plain data (colours as { r, g, b }) so Lune tests can load it.
-- Textures are Roblox's built-in particle images, so nothing has to be uploaded.
export type Rgb = { number }
export type Flame = {
	texture: string,
	colors: { Rgb }, -- over the particle's life
	rate: number, -- particles a second, per emitter
	size: number, -- studs at its widest
	lifetime: { number },
	rise: number, -- studs/s² upward
	speed: number,
	lightEmission: number,
	brightness: number, -- above 1 glows past the daylight
	transparency: number, -- at birth (fades to 1)
	spin: number?, -- degrees a second either way
}
export type Arcs = { color: Rgb, every: { number }, segments: number, jitter: number, width: number, seconds: number }
export type Look = {
	flames: { Flame }, -- on every chosen bone
	ground: { Flame }, -- from the footprint
	light: { color: Rgb, brightness: number, range: number },
	arcs: Arcs,
}

local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- A flame set in two colours: the fire itself and sparks thrown off it
local function fire(core: Rgb, edge: Rgb, glow: number): Flame
	return { texture = FIRE, colors = { core, edge }, rate = 40, size = 1, lifetime = { 0.45, 0.8 }, rise = 5,
		speed = 0.6, lightEmission = glow, brightness = 4, transparency = 0 }
end
local function sparks(core: Rgb, edge: Rgb): Flame
	return { texture = SPARKLE, colors = { core, edge }, rate = 12, size = 0.2, lifetime = { 0.8, 1.4 }, rise = 3,
		speed = 2, lightEmission = 1, brightness = 4, transparency = 0 }
end
local function groundFire(core: Rgb, edge: Rgb, glow: number): Flame
	return { texture = FIRE, colors = { core, edge }, rate = 60, size = 1, lifetime = { 0.4, 0.7 }, rise = 4,
		speed = 0.3, lightEmission = glow, brightness = 3, transparency = 0.1 }
end
local function arcs(color: Rgb, every: { number }): Arcs
	return { color = color, every = every, segments = 6, jitter = 0.18, width = 0.05, seconds = 0.18 }
end

return {
	BONES = 9, -- bones the fire burns on, picked spread over the body (Util/BeastFxRules)
	FAR = 120, -- no fire or lightning while the camera is further away than this (studs)
	FLICKER_SECONDS = 0.08,
	FLICKER = { 0.6, 1.2 }, -- light brightness times this, at random
	DUST = { PER_SPEED = 2.2, MAX = 40 }, -- footstep dust: particles a second per stud/s of speed

	ELEMENTS = {
		Ember = {
			flames = { fire({ 255, 230, 120 }, { 255, 70, 20 }, 1), sparks({ 255, 200, 90 }, { 255, 80, 20 }) },
			ground = { groundFire({ 255, 200, 90 }, { 230, 50, 10 }, 1) },
			light = { color = { 255, 120, 40 }, brightness = 2, range = 14 },
			arcs = arcs({ 255, 170, 70 }, { 0.7, 1.6 }),
		},
		Shade = {
			flames = {
				fire({ 170, 70, 255 }, { 60, 0, 120 }, 0.85),
				{ texture = SMOKE, colors = { { 60, 20, 90 }, { 10, 0, 20 } }, rate = 6, size = 1.1, lifetime = { 1, 1.6 },
					rise = 2, speed = 0.4, lightEmission = 0, brightness = 1, transparency = 0.45, spin = 40 },
				sparks({ 230, 170, 255 }, { 140, 60, 230 }),
			},
			ground = { groundFire({ 150, 50, 240 }, { 40, 0, 90 }, 0.6) },
			light = { color = { 160, 70, 255 }, brightness = 2, range = 14 },
			arcs = arcs({ 200, 130, 255 }, { 0.5, 1.3 }),
		},
		Tide = {
			flames = { fire({ 60, 190, 255 }, { 0, 50, 200 }, 0.7), sparks({ 150, 230, 255 }, { 40, 140, 255 }) },
			ground = { groundFire({ 50, 170, 255 }, { 0, 40, 180 }, 0.7) },
			light = { color = { 70, 170, 255 }, brightness = 2, range = 14 },
			arcs = arcs({ 160, 230, 255 }, { 0.6, 1.5 }),
		},
		Volt = {
			flames = {
				fire({ 255, 255, 220 }, { 255, 200, 40 }, 1),
				{ texture = SPARKLE, colors = { { 255, 250, 180 }, { 150, 210, 255 } }, rate = 24, size = 0.2,
					lifetime = { 0.2, 0.45 }, rise = 0, speed = 6, lightEmission = 1, brightness = 5, transparency = 0 },
			},
			ground = { groundFire({ 255, 245, 170 }, { 230, 170, 20 }, 1) },
			light = { color = { 220, 230, 255 }, brightness = 2.5, range = 14 },
			arcs = arcs({ 220, 235, 255 }, { 0.12, 0.45 }),
		},
		Bloom = {
			flames = { fire({ 220, 255, 170 }, { 40, 170, 60 }, 1), sparks({ 255, 190, 220 }, { 255, 120, 180 }) },
			ground = { groundFire({ 190, 255, 150 }, { 30, 140, 50 }, 1) },
			light = { color = { 110, 230, 120 }, brightness = 2, range = 14 },
			arcs = arcs({ 190, 255, 170 }, { 0.8, 1.8 }),
		},
	} :: { [string]: Look },
}
