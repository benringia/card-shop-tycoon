--!strict
-- The round 1 swords' own effects (sword skills round, spec 2026-11-06-sword-skills-design 2 and 4), drawn by the
-- client's Util/SwordSkillFx: each sword's slash (on cuts 1-3), finisher (cut 3's slam) and skill, named by its
-- Config/Swords moveset's `fx`. Textures are keys of AttackFx, MoveFx, SuperFx or SwordFx TEXTURES (reused where they
-- fit, spec 4). Placeholder numbers until each sword's round tunes its looks (Tasks 5-8): `seconds` the effect lasts,
-- `size` studs across at full scale, `count` particles; a skill's `form`: around you, ahead of you toward your aim, or
-- on the aimed foe; `beats`: a look's own timings and sizes (seconds from the move's start, studs). Plain data so Lune
-- tests read it.
export type Kind = "slash" | "finisher" | "skill"
export type Form = "around" | "ahead" | "on"
-- `burstSound`: the sword's sound (Config/Swords sounds key) played where the skill bursts
export type Look = {
	kind: Kind,
	textures: { string },
	seconds: number,
	size: number,
	count: number,
	form: Form?,
	beats: { [string]: number }?,
	cinematic: boolean?,
	burstSound: string?,
}

local LOOKS: { [string]: Look } = {
	-- Forge Sword: its element's trail, a burst of its element, the Elemental Spin's ring wave
	elementTrail = { kind = "slash", textures = { "spark", "glow" }, seconds = 0.5, size = 4, count = 8 },
	elementBurst = { kind = "finisher", textures = { "impact", "spark" }, seconds = 0.8, size = 6, count = 14 },
	elementalSpin = { kind = "skill", textures = { "ring", "spark" }, seconds = 1, size = 18, count = 24, form = "around" },
	-- Verdant Blade: leaves off each swing, roots and thorns under the foe, Thornline's vines
	-- Verdant Blade (storyboard 2026-11-07). Leaves: leaves (`size` studs) and a few pink petals peel off the blade for
	-- `seconds` of each swing, `count` a second, tumbling down
	leafShed = { kind = "slash", textures = { "shard", "glow" }, seconds = 0.3, size = 1.2, count = 70 },
	-- Roots: thorny bark roots (beats: `roots` of them, `height` studs tall) spike up in a ring `size` studs across where
	-- the finisher slams down, a puff of dirt and leaves, and sink back over `seconds`
	rootBurst = {
		kind = "finisher",
		textures = { "shard", "smoke" },
		seconds = 1.1,
		size = 7,
		count = 26,
		beats = { roots = 8, height = 5, thick = 0.9 },
	},
	-- Thornline (owner 2026-11-07: the vines racing out from the blade, "make the vines noticeable", the blade held in the
	-- ground until they reach the enemy): at `release` (the Hit marker) thick thorny vines burst up in rows `spacing` studs
	-- apart, a pair `side` studs either side of your aim line, `height` studs tall and `thick` thick, racing out at `speed`
	-- studs a second (the shape's) to the first foe (else the end of the run, `size` studs); there they snap shut over the
	-- line and a ring of `trapVines` vines `trapTall` times as tall clamps the foe (`trap` studs round, the catch `blast`,
	-- the shape's); they wither over `wither` seconds after `linger`. Exaggerated (owner 2026-11-07): green energy
	-- gathering (`gather` studs) and leaves swirling `swirl` studs round you through the hop, a glowing fissure `fissure`
	-- studs wide tearing toward the foe, glowing buds on the vines, eruptions and leaf storms
	thornline = {
		kind = "skill",
		textures = { "shard", "glow", "smoke" },
		seconds = 1.2,
		size = 18,
		count = 24,
		form = "ahead",
		burstSound = "vineSnap",
		beats = { release = 0.45, speed = 20, blast = 4, spacing = 1.6, side = 1.8, height = 8, thick = 1.4, trap = 3.2, trapVines = 8, trapTall = 1.6, linger = 0.4, wither = 0.5, gather = 4, swirl = 2.6, fissure = 2.6 },
	},
	-- Sunforged Blade (storyboard 2026-11-07). Fire trail: flames stream off the blade for `seconds` of each swing, `size`
	-- studs, `count` a second
	fireTrail = { kind = "slash", textures = { "flame", "spark" }, seconds = 0.3, size = 1.7, count = 140 },
	-- Lava crack: glowing cracks `size` studs across where the finisher slams down, embers and smoke, cooling over `seconds`
	lavaCrack = { kind = "finisher", textures = { "crack", "flame", "spark", "smoke" }, seconds = 1.2, size = 10, count = 36 },
	-- Sunfall Cleave (owner 2026-11-07): sunlight gathers at the blade's tip from `charge` to `charged` (a glow `glow`
	-- studs, motes pulled in from `gather` studs); at `release` (the cleave's Hit, Config/Swords hitAt) an upright fire
	-- crescent `height` studs tall (its beams `width` across, flames `flame` studs; owner 2026-11-07: "make the crescent
	-- bigger") leaves the cleave `launch` studs above you and `ahead` in front, and glides down toward
	-- the aim at `speed` studs a second (the shape's
	-- `length` at most); on contact it bursts: flames `blast` studs round (the shape's blast) and a lava crack. Your own
	-- plays the camera moment (CINEMATIC). Exaggerated (owner 2026-11-07:
	-- "exaggerate everything"): a heat ring `heat` studs round and cracks under you as you leap, fire swirling `swirl`
	-- studs round you through the charge, a burning fissure `fissure` studs wide along the crescent's path, and at the
	-- burst a pillar of fire `pillar` studs tall and flashes `boom` times a plain burst
	sunfallCleave = {
		kind = "skill",
		textures = { "glow", "spark", "moon", "flame", "crack", "impact", "smoke" },
		seconds = 0.8,
		size = 24,
		count = 40,
		form = "ahead",
		cinematic = true,
		burstSound = "fireBurst",
		beats = { charge = 0.42, charged = 1.65, release = 1.78, glow = 4.5, gather = 7, launch = 5.5, ahead = 2.5, speed = 14, height = 10, width = 3.8, flame = 2.2, blast = 6, heat = 5, swirl = 3.5, fissure = 3.5, pillar = 16, boom = 1.8 },
	},
	-- Prism Blade: rainbow arcs, prism shards, Prism Judgment's ghost blades and pillar
	rainbowArc = { kind = "slash", textures = { "star", "glow" }, seconds = 0.5, size = 4, count = 8 },
	prismShatter = { kind = "finisher", textures = { "shard", "star" }, seconds = 0.9, size = 7, count = 16 },
	prismJudgment = { kind = "skill", textures = { "star", "glow" }, seconds = 1.6, size = 10, count = 30, form = "on" },
}

return {
	LOOKS = LOOKS,
	-- The Verdant's colours beside its weapon's greens: bark for roots and vine stems, pale thorns, pink petals
	VERDANT = { bark = { 104, 72, 40 }, thorn = { 236, 232, 222 }, petal = { 255, 179, 209 } },
	-- Your own skill's screen shakes (ScreenFx.shake amounts; a boss slam is 0.75): on the cleave and on the burst
	SHAKE = { release = 0.5, impact = 0.95, thornline = 0.55 },
	-- Your own skill's camera moment (owner 2026-11-07, camera only: the fight runs on and you can still be hit), seconds
	-- and studs: eased over `rise` to a low angle beside and behind you (`low`) looking up `lookUp` studs above your root,
	-- drifting closer (`close`) through the charge; at the cleave it chases the crescent from `chase` behind and above it,
	-- holds `hold` on the burst and eases back to your view over `back`. `fov` while it plays.
	CINEMATIC = {
		rise = 0.42,
		hold = 0.4,
		back = 0.45,
		low = { side = 9, back = 7, up = 0.8 },
		close = { side = 6.5, back = 5, up = 1.6 },
		lookUp = 6.2,
		chase = { back = 11, up = 5.5, ahead = 3 },
		fov = 62,
	},
	-- Other players' effects (spec 4 "Everyone sees them"): drawn within `range` studs of your camera, at most `full`
	-- at once in full; past that only their light version (Util/SwordSkillFxRules.drawsOthers)
	OTHERS = { range = 90, full = 3 },
	-- `/skillfx <sword> [cut1|cut2|cut3|skill] [level]` (DevService, the admin panel's "Sword skills"): the weapon each
	-- name previews, an element name for that element's Forge Sword
	PREVIEW = {
		sunforged = "sunforgedBlade",
		verdant = "verdantBlade",
		prism = "prismBlade",
		forge = "forgeSword_Ember",
		ember = "forgeSword_Ember",
		tide = "forgeSword_Tide",
		bloom = "forgeSword_Bloom",
		volt = "forgeSword_Volt",
		shade = "forgeSword_Shade",
	} :: { [string]: string },
}
