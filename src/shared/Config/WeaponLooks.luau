--!strict
-- How weapons glow (owner 2026-11-06: an aura like the reference picture, hybrid for performance; Util/WeaponLookRules,
-- client Util/WeaponLook). Element = the colours (each weapon's glow, deep and trail), rarity = the resting inner glow
-- (REST) and how early the aura starts, upgrades = the inner glow brightening and the aura thickening (LADDER), +10 =
-- streaming ribbons, grade S = more sparkles. The full aura (flames, core, smoke, sparks) is drawn on your own sword and
-- the nearest few (BUDGET); every other sword shows the cheap creature-style glow (inner glow, light, sparkles).
-- Colours { r, g, b }; portraits are uploaded image ids ("" until made): the model rendered on magenta, cut out
-- (assets/ui/weapon-portraits, docs/weapons.md), drawn on the card over its glow. Plain data so Lune tests can load it.

export type Look = {
	glow: { number }, -- the bright colour: the aura's tips and core, the inner glow's tint, the light, sparkles
	deep: { number }, -- the aura's deep colour (its flames start in it)
	trail: { number }, -- swing trail and hit sparks
	portrait: string,
}

local BY_ELEMENT: { [string]: { glow: { number }, deep: { number }, trail: { number } } } = {
	Ember = { glow = { 255, 150, 60 }, deep = { 255, 70, 20 }, trail = { 255, 120, 40 } },
	Tide = { glow = { 120, 210, 255 }, deep = { 40, 110, 255 }, trail = { 90, 180, 255 } },
	Bloom = { glow = { 140, 235, 120 }, deep = { 40, 220, 80 }, trail = { 110, 220, 110 } },
	Volt = { glow = { 255, 225, 90 }, deep = { 255, 200, 20 }, trail = { 255, 210, 70 } },
	Shade = { glow = { 185, 120, 255 }, deep = { 150, 40, 255 }, trail = { 160, 100, 240 } },
}

local function element(name: string, portrait: string): Look
	local look = BY_ELEMENT[name]
	return { glow = look.glow, deep = look.deep, trail = look.trail, portrait = portrait }
end

local WEAPONS: { [string]: Look } = {
	starterSword = { glow = { 207, 230, 255 }, deep = { 150, 180, 230 }, trail = { 207, 230, 255 }, portrait = "rbxassetid://92121287059017" },
	verdantBlade = { glow = { 150, 240, 120 }, deep = { 40, 220, 80 }, trail = { 120, 225, 110 }, portrait = "rbxassetid://136327582593705" },
	sunforgedBlade = { glow = { 255, 190, 80 }, deep = { 255, 120, 20 }, trail = { 255, 140, 40 }, portrait = "rbxassetid://123708775303650" },
	prismBlade = { glow = { 230, 200, 255 }, deep = { 150, 40, 255 }, trail = { 200, 170, 255 }, portrait = "rbxassetid://119112031121278" },
	-- Rounds 2 and 3 (their looks get tuned when they're built)
	forgeSpear = { glow = { 207, 230, 255 }, deep = { 150, 180, 230 }, trail = { 207, 230, 255 }, portrait = "" },
	magmaHalberd = element("Ember", ""),
	tidalTrident = element("Tide", ""),
	titansLance = element("Bloom", ""),
	forgeScythe = { glow = { 207, 230, 255 }, deep = { 150, 180, 230 }, trail = { 207, 230, 255 }, portrait = "" },
	widowsReaper = element("Shade", ""),
	stormReaper = element("Volt", ""),
	riftReaper = element("Shade", ""),
}
-- The Forge Sword's portrait per element (its model with that element's colour map)
local FORGE_PORTRAITS: { [string]: string } = {
	Ember = "rbxassetid://139776462314751",
	Tide = "rbxassetid://79239373113325",
	Bloom = "rbxassetid://136741091731329",
	Volt = "rbxassetid://101378627438832",
	Shade = "rbxassetid://81995315859743",
}
-- The five Forge Swords take their element's colours
for name in BY_ELEMENT do
	WEAPONS[`forgeSword_{name}`] = element(name, FORGE_PORTRAITS[name])
end

return {
	WEAPONS = WEAPONS,
	BY_ELEMENT = BY_ELEMENT,
	-- The resting inner glow by rarity (0-1), at +0
	REST = { Common = 0.1, Rare = 0.25, ["Very Rare"] = 0.3, Epic = 0.4, Legendary = 0.5 },
	-- Upgrades: the inner glow brightens ({ level, glow }: the highest reached counts, full at +10); the aura starts at
	-- auraFrom (Epic and Legendary earlier) and thickens each level until auraFull; from +7 a bigger trail (scale at
	-- +7/+8/+9, then kept) and a burst on every hit; +10 Awakened (the ribbons)
	LADDER = {
		edge = { { 1, 0.25 }, { 2, 0.4 }, { 3, 0.55 }, { 7, 0.8 }, { 10, 1 } },
		auraFrom = { default = 4, Epic = 2, Legendary = 2 },
		auraFull = 7,
		trailFrom = 7,
		trailScale = { 1.2, 1.35, 1.5 },
		awakenedAt = 10,
	},
	-- The Forge Sword's colour map per element (its gems tinted; tools/blender/build_weapon_forgeSword.py, uploaded):
	-- tools/weapons/forge_variants swaps them into the five copies of the imported ForgeSword model
	FORGE_COLOR_MAPS = {
		Ember = "rbxassetid://114763697571749",
		Tide = "rbxassetid://71880534733338",
		Bloom = "rbxassetid://91159934303024",
		Volt = "rbxassetid://80913028012621",
		Shade = "rbxassetid://117614328562391",
	},
	-- Each model's glow map (emissive mask: the runes, gems, crystal; tools/textures/make_glow_maps.py, uploaded),
	-- baked into its SurfaceAppearances by `lune run tools/weapons/add_glow_maps` (a game script can't set them).
	-- The Forge Sword's five copies share one (the same UVs). INNER: the emissive strength at full inner glow.
	GLOW_MAPS = {
		SunforgedBlade = "rbxassetid://140219127116399",
		VerdantBlade = "rbxassetid://104844593841366",
		PrismBlade = "rbxassetid://107028137030194",
		ForgeSword = "rbxassetid://87373640011460",
	},
	INNER = { strength = 4 },
	-- A PointLight on the weapon in hand (spec 5.1: Epic "a glowing gem and a light", Legendary too), as strong as its
	-- inner glow
	LIGHT = { Epic = true, Legendary = true },
	LIGHT_LOOK = { range = 7, brightness = 1 },
	-- On the back (in town and between fights): this share of the aura and no light, except an Awakened (+10) weapon,
	-- which keeps both (owner 2026-11-06)
	BACK = { auraShare = 0.5 },
	-- The cheap glow (every sword outside the budget, and under the aura on yours): sparkles a second by rarity, more
	-- per level, more for Grade S (like the creatures' Party.GLOW)
	SPARKLES = { byRarity = { Common = 1, Rare = 2, ["Very Rare"] = 3, Epic = 4, Legendary = 5 }, perLevel = 0.3, gradeS = 2 },
	-- The full aura: who gets it (your own sword and the nearest `nearest` others within `range` studs, checked every
	-- `every` seconds; Studio 2026-11-06: 20 full auras in view cost about 2 ms of render CPU at max graphics)
	BUDGET = { nearest = 3, range = 60, every = 0.5 },
	-- The aura's emitters at full density (studs, seconds; textures are Config/AttackFx TEXTURES keys). They fill the
	-- blade's box (the guard and grip get `otherParts` of each rate); flames rise from the deep colour to the bright,
	-- the core hugs the blade, smoke drifts, sparks fly; +10 adds ribbons streaming off the blade. Brightness over 1
	-- reaches the town's bloom. Tuned in Studio 2026-11-06 against the owner's reference picture (night and day).
	AURA = {
		otherParts = 0.55,
		flame = { texture = "flame", rate = 70, lifetime = { 0.45, 0.85 }, size = { 0.35, 0.8, 0.1 }, rise = 3, drag = 1.5, transparency = 0.35, brightness = 1.3 },
		core = { texture = "glow", rate = 22, lifetime = { 0.3, 0.5 }, size = { 0.55, 0.8 }, transparency = 0.6, brightness = 1.1 },
		smoke = { texture = "smoke", rate = 18, lifetime = { 0.9, 1.5 }, size = { 0.6, 1.5 }, rise = 1.8, transparency = 0.6, brightness = 1, emission = 0.5 },
		spark = { texture = "spark", rate = 14, lifetime = { 0.6, 1.1 }, size = 0.3, speed = { 0.4, 1.4 }, brightness = 4 },
		ribbon = { texture = "streak", rate = 10, lifetime = { 0.7, 1.1 }, size = { 0.25, 0.5 }, speed = { 2, 4 }, transparency = 0.2, brightness = 1.6 },
	},
	-- A new boss weapon drop seen by others nearby (spec 4.4): a column of light in the rarity's colour rising where the
	-- winner stands, for players within `range` studs (studs, seconds; the column's width grows by `swell`)
	BEACON = { range = 150, height = 40, width = 3, swell = 1.6, seconds = 4, fadeIn = 0.3, fadeOut = 1.2 },
	-- The cheap glow's sparkle look
	SPARKLE_LOOK = { texture = "spark", lifetime = { 0.8, 1.4 }, size = 0.3, speed = { 0.3, 0.9 }, brightness = 3 },
	-- The drop cinematic and the forge reveal (WeaponRevealController, on the pack opening's stage): the circle opens,
	-- a light column in the rarity's colour shoots up, the weapon rises out of it spinning, the banner and its grade
	-- pop, a line under it. Seconds from the start; studs on the stage (its camera is 8 studs from the middle).
	REVEAL = {
		seconds = 6, -- it closes by itself
		skipAfter = 2, -- a tap closes it from here
		beamAt = 0.35,
		riseAt = 0.7,
		riseSeconds = 0.9,
		bannerAt = 1.5,
		lineAt = 2,
		-- The weapon is scaled to `length` studs on the stage (the camera sees about 5.8 studs top to bottom, less the
		-- bars, the banner and the line; a real 5-stud sword at full size ran off the frame) and rises until its lowest
		-- point is `lift` under the middle; `riseFrom`: where that point starts
		length = 3.2,
		riseFrom = -6.5,
		lift = -1.65,
		spin = 70, -- degrees a second
		tilt = 12, -- degrees: leaning a little toward the camera
		bob = { studs = 0.12, seconds = 2.2 },
		circle = { size = 6, under = 2.6, spin = 0.8 }, -- the rune circle: width, studs under the middle, turns a second
		beam = { width = 2.6, core = 0.8, height = 14, after = 0.35 }, -- after: its width once the weapon is up (it hid the blade)
		dim = 0.6,
		-- A new drop's card beside the weapon (spec 4.4): screen spot, its height (a share of the screen's), the flip's
		-- seconds; it pops in face down once the weapon is up and turns over turnAfter seconds later
		card = { x = 0.77, y = 0.5, height = 0.42, flip = 0.36, turnAfter = 0.45 },
		-- The Forge's reveal: the anvil's glow builds up this long first (a fire's whoosh and hammer strikes, each a
		-- little higher), then the hit by the grade rolled (its sounds together) and its flash; an upgrade hits small
		-- (B), +10 big (S); the banner pops with a sword's ring. Sound names are Config/PackOpening SOUNDS (the stage's)
		forge = {
			buildUp = 1.5,
			disc = 4.5, -- the glow under the anvil (studs across)
			anvilTop = -1.85, -- the anvil's face this far under the middle, just below the weapon (its foot under the bars)
			sounds = { fire = "forgeFire", strike = "forgeStrike", ring = "forgeRing" },
			strikes = { 0.15, 0.6, 1.05 }, -- seconds into the build-up
			strikeRise = 0.08, -- each strike's pitch this much higher than the one before
			hit = {
				S = { "forgeClank", "forgeBurst", "forgeBoom" },
				A = { "forgeClank", "forgeBurst" },
				B = { "forgeClank" },
				C = { "forgeClank" },
			},
			flash = { S = 1, A = 0.8, B = 0.45, C = 0.35 },
		},
	},
}
