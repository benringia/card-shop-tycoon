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
	-- the spears (weapons round 2; portraits rendered and uploaded 2026-11-07)
	magmaHalberd = element("Ember", "rbxassetid://120186001087571"),
	tidalTrident = element("Tide", "rbxassetid://128008717184531"),
	titansLance = element("Bloom", "rbxassetid://132598528291002"),
	-- the scythes (weapons round 3; portraits uploaded 2026-11-09)
	widowsReaper = element("Shade", "rbxassetid://108309018722542"),
	stormReaper = element("Volt", "rbxassetid://110426856864549"),
	riftReaper = element("Shade", "rbxassetid://92170879649035"),
}
-- The Forge Sword's portrait per element (its model with that element's colour map)
local FORGE_PORTRAITS: { [string]: string } = {
	Ember = "rbxassetid://139776462314751",
	Tide = "rbxassetid://79239373113325",
	Bloom = "rbxassetid://136741091731329",
	Volt = "rbxassetid://101378627438832",
	Shade = "rbxassetid://81995315859743",
}
-- The Forge Spear's portrait per element (weapons round 2)
local FORGE_SPEAR_PORTRAITS: { [string]: string } = {
	Ember = "rbxassetid://84746132640429",
	Tide = "rbxassetid://90908019364928",
	Bloom = "rbxassetid://128007924995183",
	Volt = "rbxassetid://110373205086963",
	Shade = "rbxassetid://135950698141778",
}
-- The Forge Scythe's portrait per element (weapons round 3, uploaded 2026-11-09)
local FORGE_SCYTHE_PORTRAITS: { [string]: string } = {
	Ember = "rbxassetid://122519222347000",
	Tide = "rbxassetid://92420585219211",
	Bloom = "rbxassetid://86345664305774",
	Volt = "rbxassetid://116575737704287",
	Shade = "rbxassetid://128846294072177",
}
-- The five Forge Swords take their element's colours; the five Forge Spears and Scythes too
for name in BY_ELEMENT do
	WEAPONS[`forgeSword_{name}`] = element(name, FORGE_PORTRAITS[name])
	WEAPONS[`forgeSpear_{name}`] = element(name, FORGE_SPEAR_PORTRAITS[name])
	WEAPONS[`forgeScythe_{name}`] = element(name, FORGE_SCYTHE_PORTRAITS[name])
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
	-- Each Forge weapon's colour map per element, by model (its gems tinted; tools/blender/build_weapon_forgeSword.py /
	-- build_weapon_forgeSpear.py, uploaded): `lune run tools/weapons/forge_variants <model>` swaps them into the five
	-- copies of the imported model
	FORGE_COLOR_MAPS = {
		ForgeSword = {
			Ember = "rbxassetid://114763697571749",
			Tide = "rbxassetid://71880534733338",
			Bloom = "rbxassetid://91159934303024",
			Volt = "rbxassetid://80913028012621",
			Shade = "rbxassetid://117614328562391",
		},
		ForgeSpear = { -- weapons round 2 (tools/blender/build_weapon_forgeSpear.py, uploaded 2026-11-07)
			Ember = "rbxassetid://127102602536831",
			Tide = "rbxassetid://90518898718880",
			Bloom = "rbxassetid://84660632595110",
			Volt = "rbxassetid://122146092260533",
			Shade = "rbxassetid://74237076352651",
		},
		ForgeScythe = { -- weapons round 3 (tools/blender/build_weapon_forgeScythe.py, uploaded 2026-11-09)
			Ember = "rbxassetid://74294427925403",
			Tide = "rbxassetid://140328124517186",
			Bloom = "rbxassetid://110918663246279",
			Volt = "rbxassetid://125025825762225",
			Shade = "rbxassetid://137995788929621",
		},
	},
	-- Each model's glow map (emissive mask: the runes, gems, crystal; tools/textures/make_glow_maps.py, uploaded),
	-- baked into its SurfaceAppearances by `lune run tools/weapons/add_glow_maps` (a game script can't set them).
	-- The Forge Sword's five copies share one (the same UVs). INNER: the emissive strength at full inner glow.
	GLOW_MAPS = {
		SunforgedBlade = "rbxassetid://140219127116399",
		VerdantBlade = "rbxassetid://104844593841366",
		PrismBlade = "rbxassetid://107028137030194",
		ForgeSword = "rbxassetid://87373640011460",
		-- the spears (weapons round 2, uploaded 2026-11-07)
		ForgeSpear = "rbxassetid://112194653990987",
		MagmaHalberd = "rbxassetid://99891722202960",
		TidalTrident = "rbxassetid://80363641113517",
		TitansLance = "rbxassetid://122751631291942",
		-- the scythes (weapons round 3, uploaded 2026-11-09)
		ForgeScythe = "rbxassetid://98008666468059",
		WidowsReaper = "rbxassetid://125281661466225",
		StormReaper = "rbxassetid://126587973899441",
		RiftReaper = "rbxassetid://121478494910404",
	},
	INNER = { strength = 4 },
	-- A PointLight on the weapon in hand (spec 5.1: Epic "a glowing gem and a light", Legendary too), as strong as its
	-- inner glow
	LIGHT = { Epic = true, Legendary = true },
	LIGHT_LOOK = { range = 7, brightness = 1 },
	-- On the back (in town and between fights): this share of the aura and no light, except an Awakened (+10) weapon,
	-- which keeps its light and `awakenedShare` of the aura (owner 2026-11-06); its flames drawn `sizeShare` of their
	-- size so the blade shows through (owner 2026-11-11: "the actual sword on my back is hard to see due to the thickness
	-- of the flames. reduce it a little bit")
	BACK = { auraShare = 0.4, awakenedShare = 0.7, sizeShare = 0.7 },
	-- The cheap glow (every sword outside the budget, and under the aura on yours): sparkles a second by rarity, more
	-- per level, more for Grade S (like the creatures' Party.GLOW)
	SPARKLES = { byRarity = { Common = 1, Rare = 2, ["Very Rare"] = 3, Epic = 4, Legendary = 5 }, perLevel = 0.3, gradeS = 2 },
	-- The full aura: who gets it (your own sword and the nearest `nearest` others within `range` studs, checked every
	-- `every` seconds; Studio 2026-11-06: 20 full auras in view cost about 2 ms of render CPU at max graphics); in your
	-- boss fight another player's full aura draws `othersInFight` of its particles (owner 2026-11-13: on, for the flex,
	-- but lighter), and on low graphics or a struggling frame rate every aura `low` of them (WeaponLookRules.auraShare)
	BUDGET = { nearest = 3, range = 60, every = 0.5, othersInFight = 0.5, low = 0.6 },
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
	-- Pack auras by element (owner 2026-11-08, picked in game from free Creator Store packs; WeaponLookRules.auraStyle),
	-- in place of our flames, core and smoke; the ribbons and the upgrade ladder stay:
	-- - Ember and Tide: the Euphoric Games VFX Pack's (112672322113504) fire or water flipbook in the weapon's deep
	--   colour, our sparks kept;
	-- - Bloom ("apply this glow to all green weapons"): the Yona VFX Pack's (18170940328) Aura as the owner saw it on the
	--   Titan's Lance: embers, a dark smoke under a bright one and a soft light, recoloured green (the test's tint), no
	--   sparks of ours; toned down by grade (`byGrade`, WeaponLookRules.auraGrade: "tone it down for low grades, then
	--   gradually to its max glow").
	-- Emitters as Util/PackEmitter reads them (Config/SwordFx IMPACT's fields, plus `rate` a second at full density, the
	-- guard and grip getting AURA.otherParts of it; `color` "deep": the weapon's deep colour; `inOut`: from the part's
	-- surface both ways; `timeScale`). Sizes are the test's: the pack's times 0.75 on the blade, `otherScale` more on
	-- the other parts. The six identical limb emitters the packs put on a body are one emitter here at six times the rate.
	-- `zOffset` from 0, not the packs' -1 (behind the body they wrapped): a sword on the back sat a fifth of a stud off
	-- it, and the fire sank into the torso (owner 2026-11-08: "the glow is blocked by the body"); the order kept.
	ELEMENT_AURA = {
		Ember = {
			sparks = true,
			emitters = {
				{ texture = "fireAura", rate = 120, lifetime = { 1, 1 }, size = { { 0, 0.8, 0 }, { 1, 0.8, 0 } }, transparency = { { 0, 1 }, { 0.5, 0 }, { 1, 1 } }, color = "deep", emission = 0.5, brightness = 2, zOffset = 0, rotation = { -360, 360 }, flipbook = {} },
			},
		},
		Tide = {
			sparks = true,
			emitters = {
				{ texture = "waterAura", rate = 120, lifetime = { 1, 1 }, size = { { 0, 0.8, 0 }, { 1, 0.8, 0 } }, transparency = { { 0, 1 }, { 0.5, 0 }, { 1, 1 } }, color = "deep", emission = 0.5, brightness = 1, zOffset = 0, rotation = { -360, 360 }, flipbook = {} },
			},
		},
		Bloom = {
			byGrade = { C = 0.3, B = 0.5, A = 0.75, S = 1 }, -- 0.4 at C looked too close to S in Studio
			otherScale = 0.8,
			emitters = {
				{ texture = "auraEmber", rate = 552, lifetime = { 0.45, 0.9 }, speed = { 0.001, 0.001 }, size = { { 0, 0, 0 }, { 0.508, 0.0375, 0.0375 }, { 1, 0, 0 } }, transparency = { { 0, 0 }, { 1, 0 } }, color = { 123, 255, 163 }, emission = 1, brightness = 3, zOffset = 4, drag = 5, direction = "Bottom", squash = { { 0, -0.1, 0 }, { 1, -0.1, 0 } } },
				{ texture = "auraSmoke", rate = 120, lifetime = { 1, 1 }, speed = { 0, 2 }, spread = { 5, 5 }, size = { { 0, 0.235, 0 }, { 1, 0.797, 0 } }, transparency = { { 0, 1 }, { 0.486, 0 }, { 0.615, 0 }, { 1, 1 } }, color = { 0, 0, 0 }, emission = 0.6, brightness = 10, zOffset = 0, rotation = { -360, 360 }, rotSpeed = { -30, 30 }, drag = 5, inOut = true, timeScale = 0.6, flipbook = { layout = "Grid8x8" } },
				{ texture = "auraSmoke", rate = 66, lifetime = { 1, 1 }, speed = { 0, 1 }, spread = { 5, 5 }, size = { { 0, 0.235, 0 }, { 1, 1.079, 0 } }, transparency = { { 0, 1 }, { 0.486, 0 }, { 0.605, 0 }, { 1, 1 } }, color = { 123, 255, 163 }, emission = 1, brightness = 10, zOffset = 0.05, rotation = { -360, 360 }, rotSpeed = { -30, 30 }, drag = 5, inOut = true, timeScale = 0.6, flipbook = { layout = "Grid8x8" } },
				{ texture = "auraLight", rate = 2, lifetime = { 1.3, 1.3 }, speed = { 0.001, 0.001 }, size = { { 0, 3.375, 0 }, { 1, 3.375, 0 } }, transparency = { { 0, 1 }, { 0.499, 0.736 }, { 1, 1 } }, color = { 123, 255, 163 }, emission = 0.6, brightness = 5, zOffset = 0.05, rotation = { -360, 360 }, direction = "Front" },
			},
		},
		-- Owner 2026-11-13 ("make sure no old effects on weapons"): Volt and Shade weapons in the same Yona aura, in their
		-- colours (Volt's electric yellow with the pack's crackling bolts, Shade's violet)
		Volt = {
			byGrade = { C = 0.3, B = 0.5, A = 0.75, S = 1 },
			otherScale = 0.8,
			emitters = {
				{ texture = "auraEmber", rate = 552, lifetime = { 0.45, 0.9 }, speed = { 0.001, 0.001 }, size = { { 0, 0, 0 }, { 0.508, 0.0375, 0.0375 }, { 1, 0, 0 } }, transparency = { { 0, 0 }, { 1, 0 } }, color = { 255, 222, 74 }, emission = 1, brightness = 3, zOffset = 4, drag = 5, direction = "Bottom", squash = { { 0, -0.1, 0 }, { 1, -0.1, 0 } } },
				{ texture = "auraSmoke", rate = 120, lifetime = { 1, 1 }, speed = { 0, 2 }, spread = { 5, 5 }, size = { { 0, 0.235, 0 }, { 1, 0.797, 0 } }, transparency = { { 0, 1 }, { 0.486, 0 }, { 0.615, 0 }, { 1, 1 } }, color = { 0, 0, 0 }, emission = 0.6, brightness = 10, zOffset = 0, rotation = { -360, 360 }, rotSpeed = { -30, 30 }, drag = 5, inOut = true, timeScale = 0.6, flipbook = { layout = "Grid8x8" } },
				{ texture = "auraSmoke", rate = 66, lifetime = { 1, 1 }, speed = { 0, 1 }, spread = { 5, 5 }, size = { { 0, 0.235, 0 }, { 1, 1.079, 0 } }, transparency = { { 0, 1 }, { 0.486, 0 }, { 0.605, 0 }, { 1, 1 } }, color = { 255, 222, 74 }, emission = 1, brightness = 10, zOffset = 0.05, rotation = { -360, 360 }, rotSpeed = { -30, 30 }, drag = 5, inOut = true, timeScale = 0.6, flipbook = { layout = "Grid8x8" } },
				{ texture = "auraLight", rate = 2, lifetime = { 1.3, 1.3 }, speed = { 0.001, 0.001 }, size = { { 0, 3.375, 0 }, { 1, 3.375, 0 } }, transparency = { { 0, 1 }, { 0.499, 0.736 }, { 1, 1 } }, color = { 255, 222, 74 }, emission = 0.6, brightness = 5, zOffset = 0.05, rotation = { -360, 360 }, direction = "Front" },
				-- Yona's Electricity Impact's crackling bolts, small, flickering along the blade
				{ texture = "lightningGrow", rate = 9, lifetime = { 0.2, 0.35 }, speed = { 0.001, 0.001 }, size = { { 0, 0.9, 0.3 }, { 1, 0.9, 0.3 } }, transparency = { { 0, 0 }, { 1, 0.4 } }, color = { 255, 244, 170 }, emission = 1, brightness = 4, zOffset = 0.1, rotation = { -180, 180 }, flipbook = {} },
			},
		},
		Shade = {
			byGrade = { C = 0.3, B = 0.5, A = 0.75, S = 1 },
			otherScale = 0.8,
			emitters = {
				{ texture = "auraEmber", rate = 552, lifetime = { 0.45, 0.9 }, speed = { 0.001, 0.001 }, size = { { 0, 0, 0 }, { 0.508, 0.0375, 0.0375 }, { 1, 0, 0 } }, transparency = { { 0, 0 }, { 1, 0 } }, color = { 168, 102, 255 }, emission = 1, brightness = 3, zOffset = 4, drag = 5, direction = "Bottom", squash = { { 0, -0.1, 0 }, { 1, -0.1, 0 } } },
				{ texture = "auraSmoke", rate = 120, lifetime = { 1, 1 }, speed = { 0, 2 }, spread = { 5, 5 }, size = { { 0, 0.235, 0 }, { 1, 0.797, 0 } }, transparency = { { 0, 1 }, { 0.486, 0 }, { 0.615, 0 }, { 1, 1 } }, color = { 0, 0, 0 }, emission = 0.6, brightness = 10, zOffset = 0, rotation = { -360, 360 }, rotSpeed = { -30, 30 }, drag = 5, inOut = true, timeScale = 0.6, flipbook = { layout = "Grid8x8" } },
				{ texture = "auraSmoke", rate = 66, lifetime = { 1, 1 }, speed = { 0, 1 }, spread = { 5, 5 }, size = { { 0, 0.235, 0 }, { 1, 1.079, 0 } }, transparency = { { 0, 1 }, { 0.486, 0 }, { 0.605, 0 }, { 1, 1 } }, color = { 168, 102, 255 }, emission = 1, brightness = 10, zOffset = 0.05, rotation = { -360, 360 }, rotSpeed = { -30, 30 }, drag = 5, inOut = true, timeScale = 0.6, flipbook = { layout = "Grid8x8" } },
				{ texture = "auraLight", rate = 2, lifetime = { 1.3, 1.3 }, speed = { 0.001, 0.001 }, size = { { 0, 3.375, 0 }, { 1, 3.375, 0 } }, transparency = { { 0, 1 }, { 0.499, 0.736 }, { 1, 1 } }, color = { 168, 102, 255 }, emission = 0.6, brightness = 5, zOffset = 0.05, rotation = { -360, 360 }, direction = "Front" },
			},
		},
	},
	-- The pack auras' layers draw `shift` studs nearer the camera while the wearer's body hides their part (a sword on
	-- the back seen from the front; WeaponLook.drawPastBody): the fire then spills over the shoulders and hat; more
	-- buries the face (1.5 studs in front of the part did in Studio)
	BEHIND_BODY = { shift = 1 },
	-- A new boss weapon drop seen by others nearby (spec 4.4): a column of light in the rarity's colour rising where the
	-- winner stands, for players within `range` studs (studs, seconds; the column's width grows by `swell`)
	BEACON = { range = 150, height = 40, width = 3, swell = 1.6, seconds = 4, fadeIn = 0.3, fadeOut = 1.2 },
	-- The cheap glow's sparkle look
	SPARKLE_LOOK = { texture = "spark", lifetime = { 0.8, 1.4 }, size = 0.3, speed = { 0.3, 0.9 }, brightness = 3 },
	-- The weapon cards (Armory UI, owner's picks 2026-11-09: 1B, 2B). Owned: the Armory cover painting (Config/
	-- BinderCovers) dimmed to `backdrop`, soft rays and the weapon's glow colour behind its portrait. Not owned: the
	-- same painting under a slate veil (a tint alone keeps its colours), the portrait as a black shadow, a lock.
	-- Transparencies 0-1; RGB tints.
	CARD = {
		backdrop = { 125, 120, 135 },
		rays = 0.45,
		raysSize = 1.7, -- of the art's width
		glow = 0.05,
		glowSize = 1.3, -- of the art's width
		lockedBackdrop = { 160, 160, 175 },
		veil = { 46, 50, 68 },
		veilTransparency = 0.35,
		shadow = 0.2,
		lockSize = 0.26, -- of the art's width
		lockedName = { 201, 207, 230 },
		lockedText = { 213, 219, 240 },
	},
	-- The weapon window's icons (Config/UIIcons names; WeaponLookRules.familyIcon / perkIcon): a family's, a perk's by
	-- kind (a venom burn by its look)
	ICONS = {
		family = { sword = "Sword", spear = "Spear", scythe = "Scythe" },
		perk = {
			heal = "Heal",
			erupt = "MoveInferno",
			chill = "FrostHeart",
			burn = "Ember",
			venom = "MoveCurse",
			chain = "Bolt",
			execute = "Target",
			prism = "PrismScale",
		},
		unknownFamily = "Sword",
		unknownPerk = "Sparkle",
	},
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
		-- The drop cinematic's own sounds (owner 2026-11-06: not the pack pulls'; Config/PackOpening SOUNDS names): a rise
		-- as the column opens, the weapon's arrival by rarity (a magic burst and a long ringing blade, a cymbal swell for
		-- Epic and Legendary) as it flashes into view, the card's turn; the ring fades as the cinematic ends
		drop = {
			rise = "dropRise",
			ring = "dropRing",
			ringFade = 0.8,
			arrive = {
				Rare = { "dropBurst" },
				["Very Rare"] = { "dropBurst" },
				Epic = { "dropBurst", "dropSting" },
				Legendary = { "dropBurst", "dropSting", "dropBoom" },
			},
			card = "dropFlip",
		},
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
