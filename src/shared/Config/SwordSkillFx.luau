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
	-- Forge Sword (storyboard 2026-11-07, all five elements; built big): each look in the sword's element (ELEMENTS).
	-- Element trail: its element's particles streaming off the blade for `seconds`, `size` studs, `count` a second
	elementTrail = { kind = "slash", textures = { "flame", "raindrop", "shard", "spark", "smoke", "glow" }, seconds = 0.3, size = 1.5, count = 120 },
	-- Element burst: where the finisher slams, a blast of its element `size` studs across (a fire spurt, a splash geyser,
	-- leaves and roots, a lightning strike, a shadow eruption), a shockwave, `count` particles
	elementBurst = { kind = "finisher", textures = { "flame", "raindrop", "shard", "spark", "smoke", "impact" }, seconds = 1, size = 7, count = 30 },
	-- Elemental Spin (option B): a ring of the element opens under you as you wind up; from `spinFrom` the two turns whip
	-- up a tornado of it round you (`tornado` studs round, `tornadoHeight` tall) and the blade leaves a blazing disc; at
	-- `release` (the Hit marker) a wall of it (`wall` jets, `wallHeight` tall) races out along the ground to `ring` studs
	-- (the shape's radius) over `grow` seconds, cracks splitting out with it, its element's extra (lightning bolts out to
	-- the ring, a pillar of fire, a splash eruption, vines, a smoke ring)
	elementalSpin = {
		kind = "skill",
		textures = { "flame", "raindrop", "shard", "spark", "smoke", "ring", "glow" },
		seconds = 1.2,
		size = 18,
		count = 40,
		form = "around",
		beats = { spinFrom = 0.25, release = 0.8, tornado = 3, tornadoHeight = 7, ring = 9, wall = 16, wallHeight = 6, grow = 0.25 },
	},
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
	-- The spear (weapons round 2, the owner's storyboard OK and "more exaggerated, with particles and all", 2026-11-07),
	-- shared by the four spears in each one's colours and element. Spear streak: the head's element streaming off every
	-- cut; the thrust a straight light streak `streak` studs ahead (its reach) with a star flash and sparks at the tip;
	-- the sweep a glowing crescent `arc` studs round (its reach) over `arcAngle` degrees, sparks flying off it; `flash`
	-- seconds the streak and crescent shine, `sparks` at each end
	spearStreak = {
		kind = "slash",
		textures = { "glow", "streak", "spark", "star", "shard" },
		seconds = 0.35,
		size = 1.6,
		count = 160,
		beats = { streak = 12, arc = 11, arcAngle = 120, flash = 0.25, sparks = 40 },
	},
	-- Sky Pierce: where the plunge's line ends (`ahead` studs, its `burst` across): the element blasting up, `rings`
	-- shockwave rings out to `ring` studs, `cracks` glowing fissures `crackLength` long, `rocks` thrown up at `rockSpeed`,
	-- a dust cloud of `dust`, a white flash for `flash` seconds
	skyPierce = {
		kind = "finisher",
		textures = { "crack", "glow", "spark", "smoke", "impact", "shard" },
		seconds = 1.4,
		size = 9,
		count = 70,
		beats = { ahead = 8, burst = 4, rings = 2, ring = 13, cracks = 6, crackLength = 7, rocks = 10, rockSpeed = 26, dust = 30, flash = 0.18 },
	},
	-- Piercing Rush: from `charge` light gathers on the head (a `glow`-stud orb, a `swirl` of the element round it, dust
	-- at your feet); from `leave` to `arrive` the rush (its dash) leaves `afterimages` of you and a light trail; at `hit` a
	-- flash runs the whole `length` x `width` line for `flashSeconds` with `bursts` bursts along it; then a skid of dust
	-- for `skid` seconds
	piercingRush = {
		kind = "skill",
		textures = { "glow", "streak", "spark", "star", "smoke", "ring" },
		seconds = 1.2,
		size = 3,
		count = 120,
		form = "ahead",
		beats = { charge = 0.05, leave = 0.28, arrive = 0.42, hit = 0.45, length = 12, width = 3, afterimages = 4, glow = 1.6, swirl = 2.2, flashSeconds = 0.35, bursts = 6, skid = 0.4 },
	},
	-- Titan's Wrath (the Titan's Lance; owner 2026-11-08: the storyboard, exaggerated). From `charge` gold and green light
	-- spirals into the tip (an orb growing to `glow` studs, sparks streaming in from `inflow` studs round it, two spirals of
	-- sparks and leaves `swirl` studs round you), `cracks` glowing cracks creep out from your feet to `crackReach` studs and
	-- the screen rumbles harder and harder (SHAKE.titansRumble, a pulse every `rumbleEvery` s); at `peak` the tip flashes
	-- white, a shockwave ring `ring` studs round bursts at your feet and `rocks` rocks lift off the ground; at `hit` one
	-- huge thrust: a lance-shaped beam `beam` studs thick shoots the whole `length` ahead with a gold shockwave, the lifted
	-- rocks fly with it, and a fissure tears along the `length` x `width` line in `tear` seconds, green light and `thorns`
	-- thorns (`thornHeight` studs) bursting out of it (SHAKE.titansWrath and its burstSound); it glows on until `close`,
	-- closing over `fade`, `petals` petals drifting down. Your own plays the camera moment: the side shot of your stance
	-- (looking `camFocus` studs above your root) through the charge, the wide shot of the whole line from `camAt` (looking
	-- `camLookUp` studs up), held `camHold`.
	titansWrath = {
		kind = "skill",
		textures = { "glow", "spark", "star", "shard", "smoke", "ring", "crack" },
		seconds = 2.2,
		size = 14,
		count = 120,
		form = "ahead",
		cinematic = true,
		burstSound = "wrathFissure",
		beats = {
			charge = 0.1,
			peak = 1.22,
			hit = 1.35,
			close = 2.7,
			fade = 0.7,
			tear = 0.22,
			length = 14,
			width = 4,
			glow = 2.4,
			inflow = 4,
			swirl = 3.2,
			cracks = 7,
			crackReach = 6,
			rumbleEvery = 0.12,
			ring = 11,
			rocks = 12,
			beam = 2.2,
			thorns = 9,
			thornHeight = 4.5,
			petals = 45,
			camAt = 1.35,
			camHold = 0.9,
			camFocus = 0.5, -- the hero shot looks at your stance (CINEMATIC.lookUp is for a jump)
			camLookUp = 1.2, -- the wide shot looks low, along the fissure
		},
	},
	-- Magma Cleave (the Magma Halberd; spec 2026-11-09-halberd-and-trident-skills-design 3: "one big swipe. with flaming
	-- horizontal slash effects"). From `windup` the blade's glow brightens and embers gather on it; at `hit` a big fire
	-- crescent `radius` studs round your front over `angle` degrees and `crescent` studs thick (orange-red, a white-hot
	-- core, `embers` flames and embers shedding along it), a thinner flame slash a beat behind (SHAKE.magmaCleave); then
	-- smoke and falling embers over `smoke` seconds. No camera moment.
	magmaCleave = {
		kind = "skill",
		textures = { "flame", "spark", "smoke", "glow", "crescent", "fireAura" },
		seconds = 1.2,
		size = 22,
		count = 120,
		form = "around",
		beats = { windup = 0.1, hit = 0.6, radius = 11, angle = 180, crescent = 2.2, embers = 40, smoke = 0.8 },
	},
	-- Torrent Strike (the Tidal Trident; spec 4: "strike the ground with the trident, while the trident is stuck to the
	-- ground, torrents of water appears from the ground"). From `raise` water swirls round the prongs; at `slam` a splash
	-- ring and `cracks` glowing blue cracks spread from the prongs (SHAKE.torrentSlam); at `hit` `columns` columns burst
	-- up on a ring `inner` studs round you (`columnHeight` tall: spray, falling droplets, mist, a splash ring at each
	-- foot) and a big one under every foe in reach (SHAKE.torrentStrike; at its near edge, larger for a bigger foe:
	-- SwordSkillFxRules.torrentFoes); at `second` a wider ring at `radius` studs (`outerHeight` tall), only for show;
	-- from `fall` they fall back as rain and mist. The rings are turned by `ringOffset` so no column stands at your sides,
	-- where the camera shoots from. Your own plays the camera pull-back from `camAt`, held `camHold`, framed on you (the
	-- hero shot `camFocus` above your root, the wide one `camLookUp` up from `camUp` high).
	torrentStrike = {
		kind = "skill",
		textures = { "raindrop", "ring", "glow", "smoke", "crack" },
		seconds = 1.9,
		size = 24,
		count = 120,
		form = "around",
		cinematic = true,
		beats = {
			raise = 0.05,
			slam = 0.55,
			hit = 0.75,
			second = 1.0,
			fall = 1.5,
			radius = 12,
			inner = 6,
			columns = 8,
			columnHeight = 9,
			outerHeight = 11,
			cracks = 6,
			ringOffset = 0.25, -- the inner ring a quarter step round, the outer three quarters: none at your sides
			foeEdge = 0.8, -- a foe's column at its near edge, this share of its radius in from its centre
			foeSizeStuds = 3, -- ...one size larger per this many studs of its radius,
			foeSizeMax = 3, -- up to this
			camAt = 0.75,
			camHold = 0.7,
			camFocus = 0.5,
			camLookUp = 2,
			camUp = 12, -- the wide shot above the tallest columns
		},
	},
}

return {
	LOOKS = LOOKS,
	-- Titan's Wrath's colours beside the Lance's greens: its gold light, the thorns' bark and pale spikes, pink petals
	TITAN = { gold = { 255, 206, 84 }, bark = { 92, 64, 36 }, thorn = { 240, 232, 214 }, petal = { 255, 179, 209 } },
	-- The Verdant's colours beside its weapon's greens: bark for roots and vine stems, pale thorns, pink petals
	VERDANT = { bark = { 104, 72, 40 }, thorn = { 236, 232, 222 }, petal = { 255, 179, 209 } },
	-- The Prism Blade's colours: the elements in its ghost blades' order (their colours: WeaponLooks.BY_ELEMENT)
	PRISM = { order = { "Ember", "Tide", "Bloom", "Volt", "Shade" } },
	-- Each element's particle for the Forge Sword's looks (a texture key of the four TEXTURES tables)
	ELEMENTS = {
		Ember = { particle = "flame" },
		Tide = { particle = "raindrop" },
		Bloom = { particle = "shard" },
		Volt = { particle = "spark" },
		Shade = { particle = "smoke" },
	} :: { [string]: { particle: string } },
	-- Your own skill's screen shakes (ScreenFx.shake amounts; a boss slam is 0.75): on the cleave and on the burst
	-- Titan's Wrath: each rumble pulse through the charge grows to titansRumble (they decay between pulses: it throbs and
	-- builds), the fissure's shake is titansWrath (the peak's flash shakes `release`); Magma Cleave's swipe magmaCleave;
	-- Torrent Strike's slam shakes `release`, its torrents torrentStrike
	SHAKE = { release = 0.5, impact = 0.95, thornline = 0.55, prismStrike = 0.4, prismJudgment = 1.1, elementalSpin = 0.7, finisher = 0.35, titansRumble = 0.28, titansWrath = 1, magmaCleave = 0.8, torrentStrike = 0.9 },
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
		-- the spears (weapons round 2)
		spear = "forgeSpear_Ember",
		halberd = "magmaHalberd",
		trident = "tidalTrident",
		lance = "titansLance",
	} :: { [string]: string },
}
