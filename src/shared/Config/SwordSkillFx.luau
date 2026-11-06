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
	-- Prism Blade (storyboard 2026-11-07; owner: "make everything exaggerated/big/particles everywhere/screen shake/
	-- flashy"). Rainbow arcs: five bands of the elements' colours (PRISM.order) streaming off the blade for `seconds` of
	-- each swing, `size` studs, `count` a second, with white sparkles
	rainbowArc = { kind = "slash", textures = { "glow", "star" }, seconds = 0.3, size = 1.3, count = 150 },
	-- Prism shatter: `crystals` crystal spikes (`height` studs, `thick` thick) in the five colours burst up in a ring
	-- `size` studs across where the finisher slams, rainbow shockwaves, shards and sparkles; they shatter over `seconds`
	prismShatter = {
		kind = "finisher",
		textures = { "shard", "star", "ring" },
		seconds = 1.1,
		size = 9,
		count = 40,
		beats = { crystals = 9, height = 6, thick = 1.1 },
	},
	-- Prism Judgment: from `summon` the blade's tip blazes, beams of each colour shoot up to a ring of five ghost Forge
	-- Swords (`blade` studs long) forming `ringHeight` studs above the foe, `ringRadius` round, spinning from `spin` up to
	-- `spinUp` turns a second, over a spinning rune circle `rune` studs round on the ground; from `release` (the Hit
	-- marker) one blade every `gap` seconds (the shape's, `strikes` of them) peels off and dives in a streak of its
	-- colour (`dive` seconds) to burst on the foe in its element; at `pillar` a rainbow pillar `pillarHeight` studs tall
	-- and `pillarWidth` wide blasts up for `pillarSeconds`, shards everywhere; the blades shatter. Your own plays the camera
	-- moment (CINEMATIC: the wide shot from the command, `camAt`, held `camHold`, looking `camLookUp` studs up from
	-- `camUp` higher, so the ring and the pillar show) and shakes on each strike
	-- (SHAKE.prismStrike) and the pillar (SHAKE.prismJudgment, its burstSound)
	prismJudgment = {
		kind = "skill",
		textures = { "glow", "star", "shard", "sigil", "rune", "ring" },
		seconds = 2,
		size = 24,
		count = 60,
		form = "on",
		cinematic = true,
		burstSound = "prismBoom",
		beats = {
			summon = 0.12,
			command = 0.55,
			release = 0.6,
			gap = 0.15,
			strikes = 5,
			pillar = 1.28,
			ringRadius = 6,
			ringHeight = 14,
			blade = 8,
			spin = 1,
			spinUp = 5,
			dive = 0.18,
			rune = 10,
			pillarHeight = 70,
			pillarWidth = 3,
			pillarSeconds = 0.9,
			camAt = 0.55,
			camHold = 1.6,
			camLookUp = 7,
			camUp = 10,
		},
	},
}

return {
	LOOKS = LOOKS,
	-- The Verdant's colours beside its weapon's greens: bark for roots and vine stems, pale thorns, pink petals
	VERDANT = { bark = { 104, 72, 40 }, thorn = { 236, 232, 222 }, petal = { 255, 179, 209 } },
	-- The Prism Blade's colours: the elements in its ghost blades' order (their colours: WeaponLooks.BY_ELEMENT)
	PRISM = { order = { "Ember", "Tide", "Bloom", "Volt", "Shade" } },
	-- Your own skill's screen shakes (ScreenFx.shake amounts; a boss slam is 0.75): on the cleave and on the burst
	SHAKE = { release = 0.5, impact = 0.95, thornline = 0.55, prismStrike = 0.4, prismJudgment = 1.1 },
	-- Your own skill's camera moment (owner 2026-11-07, camera only: the fight runs on and you can still be hit; then
	-- "the camera ... is at the back so the crescent is hard to see ... make sure it shows the full animation without
	-- being blocked"), seconds and studs, all from the side (your left or right, whichever has a clear view): eased over
	-- `rise` to a side shot of you (`hero`: out to the side, a little ahead, up) looking `lookUp` studs above your root,
	-- drifting `push` of the way closer through the charge; at the cleave it swings out over `latch` to a wide side shot
	-- (`wide`) framing you, the crescent's whole flight and the burst (SwordSkillFxRules.wideDistance: `margin` studs
	-- spare either side, never nearer than `least`), holds `hold` on the burst and eases back to your view over `back`.
	-- `fov` while it plays.
	CINEMATIC = {
		rise = 0.42,
		hold = 0.5,
		back = 0.45,
		latch = 0.35,
		hero = { side = 11, ahead = 2, up = 2.5 },
		push = 0.15,
		lookUp = 5.5,
		wide = { margin = 6, least = 14, up = 6, lookUp = 3.5 },
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
