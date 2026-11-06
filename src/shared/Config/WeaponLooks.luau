--!strict
-- How weapons glow (spec 2026-11-06-weapons-round1-design 5.1; Util/WeaponLookRules, client Util/WeaponLook): one
-- job per thing, not piled up. Element = the colours (each weapon's glow and trail), rarity = the resting glow (REST),
-- upgrades = layers over time (LADDER), grade S = the card-style twinkle. One particle aura per weapon; on the back in
-- town fewer particles and no light (BACK). Colours { r, g, b }; portraits are uploaded image ids ("" until made).
-- Plain data so Lune tests can load it.

export type Look = {
	glow: { number }, -- edges, gem and aura
	trail: { number }, -- swing trail and hit sparks
	aura: string, -- "embers" | "frost" | "petals" | "sparks" | "wisps" | "prism" | "none"
	awakened: string, -- the +10 effect: "sunHalo" | "vineCrown" | "prismWings" | "elementRunes"
	portrait: string,
}

local BY_ELEMENT: { [string]: { glow: { number }, trail: { number }, aura: string } } = {
	Ember = { glow = { 255, 150, 60 }, trail = { 255, 120, 40 }, aura = "embers" },
	Tide = { glow = { 120, 210, 255 }, trail = { 90, 180, 255 }, aura = "frost" },
	Bloom = { glow = { 140, 235, 120 }, trail = { 110, 220, 110 }, aura = "petals" },
	Volt = { glow = { 255, 225, 90 }, trail = { 255, 210, 70 }, aura = "sparks" },
	Shade = { glow = { 185, 120, 255 }, trail = { 160, 100, 240 }, aura = "wisps" },
}

local WEAPONS: { [string]: Look } = {
	starterSword = { glow = { 207, 230, 255 }, trail = { 207, 230, 255 }, aura = "none", awakened = "elementRunes", portrait = "" },
	verdantBlade = { glow = { 150, 240, 120 }, trail = { 120, 225, 110 }, aura = "petals", awakened = "vineCrown", portrait = "" },
	sunforgedBlade = { glow = { 255, 190, 80 }, trail = { 255, 140, 40 }, aura = "embers", awakened = "sunHalo", portrait = "" },
	prismBlade = { glow = { 230, 200, 255 }, trail = { 200, 170, 255 }, aura = "prism", awakened = "prismWings", portrait = "" },
	-- Rounds 2 and 3 (their looks get tuned when they're built)
	forgeSpear = { glow = { 207, 230, 255 }, trail = { 207, 230, 255 }, aura = "none", awakened = "elementRunes", portrait = "" },
	magmaHalberd = { glow = BY_ELEMENT.Ember.glow, trail = BY_ELEMENT.Ember.trail, aura = "embers", awakened = "elementRunes", portrait = "" },
	tidalTrident = { glow = BY_ELEMENT.Tide.glow, trail = BY_ELEMENT.Tide.trail, aura = "frost", awakened = "elementRunes", portrait = "" },
	titansLance = { glow = BY_ELEMENT.Bloom.glow, trail = BY_ELEMENT.Bloom.trail, aura = "petals", awakened = "elementRunes", portrait = "" },
	forgeScythe = { glow = { 207, 230, 255 }, trail = { 207, 230, 255 }, aura = "none", awakened = "elementRunes", portrait = "" },
	widowsReaper = { glow = BY_ELEMENT.Shade.glow, trail = BY_ELEMENT.Shade.trail, aura = "wisps", awakened = "elementRunes", portrait = "" },
	stormReaper = { glow = BY_ELEMENT.Volt.glow, trail = BY_ELEMENT.Volt.trail, aura = "sparks", awakened = "elementRunes", portrait = "" },
	riftReaper = { glow = BY_ELEMENT.Shade.glow, trail = BY_ELEMENT.Shade.trail, aura = "wisps", awakened = "elementRunes", portrait = "" },
}
-- The five Forge Swords take their element's colours
for element, look in BY_ELEMENT do
	WEAPONS[`forgeSword_{element}`] = { glow = look.glow, trail = look.trail, aura = look.aura, awakened = "elementRunes", portrait = "" }
end

return {
	WEAPONS = WEAPONS,
	BY_ELEMENT = BY_ELEMENT,
	-- The resting glow by rarity (0-1: how strongly the edges glow at +0)
	REST = { Common = 0.1, Rare = 0.25, ["Very Rare"] = 0.3, Epic = 0.4, Legendary = 0.5 },
	-- Upgrades: +1..+3 the edges glow brighter (edge at that level), from +4 its aura (particles a second at +4/+5/+6,
	-- the last kept after), from +7 a bigger trail (scale at +7/+8/+9, then kept) and a burst on every hit, +10 Awakened
	LADDER = {
		edge = { [1] = 0.25, [2] = 0.4, [3] = 0.55 },
		auraFrom = 4,
		auraRate = { 6, 10, 14 }, -- Studio's automatic quality thins these a lot: tuned so +4 still reads there
		trailFrom = 7,
		trailScale = { 1.2, 1.35, 1.5 },
		awakenedAt = 10,
	},
	-- A PointLight on the weapon in hand (spec 5.1: Epic "a glowing gem and a light", Legendary too)
	LIGHT = { Epic = true, Legendary = true },
	-- On the back (in town and between fights): this share of the aura's particles and no light
	BACK = { auraShare = 0.35, light = false },
	-- Drawing it (client Util/WeaponLook). The glow shell: each glowing part's copy this much bigger, in Neon. Particle
	-- textures are Config/AttackFx or Config/MoveFx TEXTURES keys (square, white: tinted the weapon's glow; prism
	-- runs through every element's colour). Sizes in studs at their biggest (a particle grows to it, then shrinks
	-- away; the textures are mostly clear round a small shape), lifetimes in seconds, speeds in studs a second.
	-- Checked in Studio 2026-11-06: smaller ones vanished against the sky.
	SHELL_SCALE = 1.03,
	LIGHT_LOOK = { range = 7, brightness = 0.8 },
	AURA = {
		embers = { texture = "flame", size = 1.2, lifetime = { 0.6, 1.1 }, speed = { 0.4, 1.2 }, rise = 2.5 },
		frost = { texture = "shard", size = 0.9, lifetime = { 0.8, 1.4 }, speed = { 0.1, 0.4 }, rise = -0.6 },
		petals = { texture = "glow", size = 0.9, lifetime = { 1, 1.6 }, speed = { 0.2, 0.6 }, rise = -0.8 },
		sparks = { texture = "spark", size = 0.8, lifetime = { 0.3, 0.6 }, speed = { 1, 2.5 }, rise = 0 },
		wisps = { texture = "smoke", size = 1.4, lifetime = { 1, 1.8 }, speed = { 0.2, 0.5 }, rise = 0.8 },
		prism = { texture = "shard", size = 0.9, lifetime = { 0.8, 1.3 }, speed = { 0.2, 0.6 }, rise = 0.4 },
	},
	-- Grade S: the card-style twinkle, a few star glints a second along the blade
	TWINKLE = { texture = "flare", rate = 3, size = 1.6, lifetime = 0.5 },
	-- +10 Awakened: a ring of its effect circling the blade (round 1: one emitter each; owner to judge in Studio)
	AWAKENED = {
		sunHalo = { texture = "ring", rate = 3, size = 2.6, lifetime = 1.2, spin = 40 },
		vineCrown = { texture = "vine", rate = 4, size = 1.8, lifetime = 1.4, spin = 60 },
		prismWings = { texture = "shard", rate = 10, size = 1, lifetime = 1, spin = 120 },
		elementRunes = { texture = "rune", rate = 3, size = 1.6, lifetime = 1.6, spin = 90 },
	},
}
