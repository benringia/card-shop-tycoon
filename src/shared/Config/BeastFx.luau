--!strict
-- The creatures' element auras, client only (Util/BeastAura): Legendaries, and grade S and A copies of other cards,
-- wear their element in the store packs' effects (owner 2026-11-13, "finalize all" the pet glows and auras, like the
-- weapons' Config/WeaponLooks ELEMENT_AURA): the Euphoric pack's fire (Ember) and water (Tide), the Yona pack's aura
-- (Bloom green, Shade violet over dark smoke, Volt bright yellow with its crackling bolts) on bones spread over the body
-- (so it moves with the animation), rising from the ground under Legendaries, with a flickering light and dust from the
-- feet. Grade S Legendaries (tier Divine) add a turning halo behind the head, small orbs circling it and embers left
-- where they walk. Plain data so Lune tests can load it; textures are Config/AttackFx TEXTURES keys.
export type Rgb = { number }
-- A Util/PackEmitter spec (Config/SwordFx IMPACT's fields) plus `rate`: particles a second over the whole body at
-- tier rate 1 (shared out between the burning bones; for the halo over its ring, for an orb each). Sizes and speeds
-- are for a creature of size 1 (3 studs tall) and grow with its size.
export type Layer = any
-- How much of the aura a creature gets: grade S Legendaries (Divine) more than all of it, other Legendaries all of
-- it; grade S and A copies of other cards a lighter touch. bones: how many carry it (their mirrors join them); rate,
-- size, light: times the look's own; ground: layers rising from the footprint; divine: the grade S Legendary extras.
export type Tier = { bones: number, rate: number, size: number, light: number, ground: boolean, dust: boolean, divine: boolean? }
export type Look = {
	layers: { Layer }, -- on the burning bones
	ground: { Layer }, -- from the footprint (Legendary and Divine)
	halo: { Layer }, -- the Divine halo's ring
	orb: { Layer }, -- each Divine orb
	light: { color: Rgb, brightness: number, range: number },
	-- Divine extras turned to the void: the orbs become little black holes in a glowing disc, the embers dark rifts
	void: boolean?,
}
-- What one budget cut leaves (BeastFxRules.budget): `rate` times the particles, and which extras stay
export type Cut = { rate: number, ground: boolean, light: boolean, dust: boolean, embers: boolean }

-- One soft glow puff (the Yona pack's Light), drawn big and faint around the bones
local function glow(color: Rgb, rate: number, size: number): Layer
	return { texture = "auraLight", rate = rate, lifetime = { 1.3, 1.3 }, speed = { 0.001, 0.001 },
		size = { { 0, size, 0 }, { 1, size, 0 } }, transparency = { { 0, 1 }, { 0.5, 0.78 }, { 1, 1 } }, color = color,
		emission = 0.6, brightness = 2, rotation = { -360, 360 } }
end
-- Tiny glowing specks drifting up off the body (the Yona pack's Ember)
local function specks(color: Rgb, rate: number): Layer
	return { texture = "auraEmber", rate = rate, lifetime = { 0.6, 1.2 }, speed = { 0.4, 1.2 }, spread = { 180, 180 },
		size = { { 0, 0, 0 }, { 0.5, 0.07, 0.03 }, { 1, 0, 0 } }, transparency = { { 0, 0 }, { 1, 0 } }, color = color,
		emission = 1, brightness = 3, accel = { 0, 2.5, 0 }, drag = 2 }
end
-- The Yona pack's aura smoke (an 8x8 flipbook): `color` black for the dark smoke under the colour. Far dimmer than on a
-- blade (brightness 10 there): a creature-sized cloud of it washed the body out white in Studio
local function smoke(color: Rgb, rate: number, size: number, brightness: number): Layer
	return { texture = "auraSmoke", rate = rate, lifetime = { 1, 1 }, speed = { 0, 0.8 }, spread = { 180, 180 },
		size = { { 0, size * 0.3, 0 }, { 1, size, 0 } }, transparency = { { 0, 1 }, { 0.486, 0 }, { 0.61, 0 }, { 1, 1 } },
		color = color, emission = if color[1] + color[2] + color[3] == 0 then 0.6 else 1, brightness = brightness,
		rotation = { -360, 360 }, rotSpeed = { -30, 30 }, accel = { 0, 1, 0 }, drag = 3, timeScale = 0.6,
		flipbook = { layout = "Grid8x8" } }
end
-- The Euphoric pack's fire or water (a 4x4 flipbook) licking up off the bones
local function flames(texture: string, color: Rgb, rate: number, size: number, brightness: number): Layer
	return { texture = texture, rate = rate, lifetime = { 0.8, 1 }, speed = { 0, 0.3 }, spread = { 180, 180 },
		size = { { 0, size, 0 }, { 1, size * 0.8, 0 } }, transparency = { { 0, 1 }, { 0.4, 0.1 }, { 1, 1 } }, color = color,
		emission = 0.6, brightness = brightness, rotation = { -20, 20 }, accel = { 0, 1.5, 0 }, flipbook = {} }
end
-- The Divine halo's ring: bright glow dots held on the turning ring (a soft disc of light behind the head from afar)
local function ring(color: Rgb): Layer
	return { texture = "auraLight", rate = 140, lifetime = { 0.5, 0.5 }, speed = { 0.001, 0.001 },
		size = { { 0, 0.38, 0 }, { 1, 0.38, 0 } }, transparency = { { 0, 1 }, { 0.3, 0.2 }, { 0.7, 0.2 }, { 1, 1 } },
		color = color, emission = 1, brightness = 3, rotation = { -360, 360 } }
end
-- Smoke and specks rising from the footprint (from all of it: the box's volume)
local function rising(layer: Layer): Layer
	local made = table.clone(layer)
	made.speed = { 1, 2 }
	made.spread = { 10, 10 }
	made.direction = "Top"
	return made
end

return {
	TIERS = {
		Divine = { bones = 11, rate = 1.1, size = 1.05, light = 1.15, ground = true, dust = true, divine = true },
		Legendary = { bones = 9, rate = 1, size = 1, light = 1, ground = true, dust = true },
		S = { bones = 6, rate = 0.75, size = 0.9, light = 0.6, ground = false, dust = false },
		A = { bones = 4, rate = 0.5, size = 0.8, light = 0.4, ground = false, dust = false },
	} :: { [string]: Tier },
	-- Which tier a copy wears by its card's rarity and grade (BeastFxRules.tier; owner 2026-11-13: "only for grade S
	-- commons and rares. grade A/S very rares too"); `any`: every grade (a Legendary always glows); none: no aura
	BY_RARITY = {
		Common = { S = "S" },
		Rare = { S = "S" },
		["Very Rare"] = { S = "S", A = "A" },
		Epic = { S = "S", A = "A" },
		Legendary = { S = "Divine", any = "Legendary" },
	} :: { [string]: { [string]: string } },
	-- The smallest a creature's aura is drawn, as a creature size (1: 3 studs tall): a grade S Common (0.7) drew its
	-- effects so small they barely showed, 0.85 still faint (BeastFxRules.scale)
	MIN_SCALE = 1,
	-- How much of its aura a creature shows on this screen (BeastFxRules.budget; owner 2026-11-13: "pets that glows alot
	-- on boss battles specially on full party I think will be heavy", "Light touch" for other players' effects, "make the
	-- performance better without affecting flexing too much"): another player's creature in your boss fight (`others`)
	-- and every creature with low graphics or a struggling frame rate (`low`, yours too) keep their look at `rate` times
	-- the particles; ground flames, light, dust and embers only where `true`. A Divine halo and orbs always stay.
	BUDGET = {
		others = { rate = 0.45, ground = false, light = false, dust = false, embers = false },
		low = { rate = 0.5, ground = false, light = true, dust = false, embers = false },
	} :: { others: Cut, low: Cut },
	-- The body's layers draw this share of the creature's footprint (its wider side) nearer the camera, so the bones deep
	-- inside a big body still show their aura (a ZOffset: their size on screen stays; Stormking's shell hid it at 0.45 of
	-- the narrower side; at 0.5 the aura veiled the whole body)
	DEPTH = 0.3,
	-- Grade S Legendary extras (tier Divine). Distances are times the creature's height; halo and orb sizes are for a
	-- creature of size 1 and grow with its size.
	DIVINE = {
		HALO = { count = 12, radius = 0.17, behind = 0.1, spin = 25 }, -- a ring behind its head; spin: degrees a second
		ORBS = { count = 3, radius = 0.5, height = 0.55, bob = 0.04, seconds = 7, size = 0.2 }, -- small orbs circling it; seconds: one lap
		-- A void orb's glowing disc: times the orb's size across, its tilt (degrees) and spin (degrees a second)
		VOID_DISC = { size = 2.6, tilt = 70, spin = 120 },
		EMBERS = { every = 0.28, seconds = 1.6, size = 0.5, max = 10 }, -- embers left behind while it walks (its ground layer, `size` times)
	},
	FAR = 120, -- no aura while the camera is further away than this (studs)
	FLICKER_SECONDS = 0.08,
	FLICKER = { 0.6, 1.2 }, -- light brightness times this, at random
	DUST = { PER_SPEED = 2.2, MAX = 40 }, -- footstep dust: particles a second per stud/s of speed

	ELEMENTS = {
		-- The first test drowned Solarion in fire: thin flames, the specks and glow carry the rest
		Ember = {
			layers = { flames("fireAura", { 255, 110, 30 }, 28, 0.45, 1.6), specks({ 255, 170, 60 }, 40), glow({ 255, 120, 40 }, 3, 1.3) },
			ground = { rising(flames("fireAura", { 255, 100, 25 }, 12, 0.7, 1.6)) },
			halo = { ring({ 255, 190, 90 }), flames("fireAura", { 255, 140, 40 }, 36, 0.4, 2) },
			orb = { flames("fireAura", { 255, 160, 60 }, 10, 0.4, 2), glow({ 255, 140, 50 }, 2, 1.1) },
			light = { color = { 255, 120, 40 }, brightness = 2, range = 14 },
		},
		Tide = {
			layers = { flames("waterAura", { 60, 170, 255 }, 30, 0.45, 1.4), specks({ 150, 225, 255 }, 40), glow({ 70, 170, 255 }, 3, 1.3) },
			ground = { rising(flames("waterAura", { 50, 150, 255 }, 12, 0.7, 1.1)) },
			halo = { ring({ 150, 220, 255 }), flames("waterAura", { 110, 200, 255 }, 36, 0.4, 1.4) },
			orb = { flames("waterAura", { 140, 215, 255 }, 10, 0.4, 1.4), glow({ 80, 180, 255 }, 2, 1.1) },
			light = { color = { 70, 170, 255 }, brightness = 2, range = 14 },
		},
		-- The first test read soft: a touch of dark smoke under the green for depth, the green dimmer than the blade's
		-- (brighter washed out cream, deeper vanished on green bodies)
		Bloom = {
			layers = { specks({ 150, 255, 170 }, 110), smoke({ 0, 0, 0 }, 10, 0.85, 1), smoke({ 140, 255, 160 }, 32, 1.05, 2.5), glow({ 123, 255, 163 }, 3, 1.3) },
			ground = { rising(smoke({ 140, 255, 160 }, 9, 1.05, 2.5)), rising(specks({ 150, 255, 170 }, 21)) },
			halo = { ring({ 170, 255, 190 }), smoke({ 140, 255, 160 }, 30, 0.6, 2.5) },
			orb = { smoke({ 140, 255, 160 }, 8, 0.6, 2.5), glow({ 123, 255, 163 }, 2, 1.1) },
			light = { color = { 110, 230, 120 }, brightness = 2, range = 14 },
		},
		-- Bright smoke and the pack's crackling bolts only: its dark smoke swallowed the yellow in the first test
		Volt = {
			layers = {
				specks({ 255, 240, 140 }, 110),
				smoke({ 255, 222, 74 }, 32, 1, 2.5),
				{ texture = "lightningGrow", rate = 10, lifetime = { 0.2, 0.35 }, speed = { 0.001, 0.001 },
					size = { { 0, 1.5, 0.4 }, { 1, 1.5, 0.4 } }, transparency = { { 0, 0 }, { 1, 0.4 } }, color = { 255, 244, 170 },
					emission = 1, brightness = 4, rotation = { -180, 180 }, flipbook = {} },
				glow({ 255, 230, 90 }, 4, 1.3),
			},
			ground = { rising(smoke({ 255, 222, 74 }, 9, 1, 2.5)), rising(specks({ 255, 240, 140 }, 21)) },
			halo = { ring({ 255, 240, 140 }), smoke({ 255, 235, 120 }, 30, 0.6, 3) },
			orb = { smoke({ 255, 235, 120 }, 8, 0.6, 3), glow({ 255, 230, 90 }, 2, 1.1) },
			light = { color = { 255, 230, 120 }, brightness = 2.5, range = 14 },
		},
		Shade = {
			layers = { specks({ 200, 150, 255 }, 100), smoke({ 0, 0, 0 }, 21, 0.85, 1), smoke({ 168, 102, 255 }, 28, 1.05, 2.5), glow({ 168, 102, 255 }, 3, 1.3) },
			ground = { rising(smoke({ 0, 0, 0 }, 7, 1.05, 1)), rising(smoke({ 150, 80, 240 }, 8, 1.05, 2.5)) },
			halo = { ring({ 200, 150, 255 }), smoke({ 190, 140, 255 }, 30, 0.6, 3) },
			orb = { smoke({ 0, 0, 0 }, 8, 0.7, 1), specks({ 200, 150, 255 }, 10) },
			light = { color = { 160, 70, 255 }, brightness = 2, range = 14 },
			void = true,
		},
	} :: { [string]: Look },
}
