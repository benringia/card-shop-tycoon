--!strict
-- The movesets the player fights bosses with (spec 2026-11-02-you-in-the-fight-design): each weapon in Config/Weapons
-- names the moveset it swings (weapons round 1's swords all swing the starter's; spears and scythes get their own in
-- rounds 2-3). Plain data so Lune tests can load it.
-- A cut's damage: the summoned creature's ATK x the cut's power x the equipped weapon's Power (WeaponRules.power via
-- WeaponService.Power; BattleSim.swordHit); a moveset's own `power` is no longer part of it. Times are
-- seconds from the cut's start: `hitAt` is the strike frame of its animation (its Hit marker), `cancelAt` the end of
-- its follow-through (the next cut may start there; SwordRules.nextCut), `length` the whole cut. `reach` counts from
-- the target's edge; `arc` is the cone in front of you it hits (degrees). `lunge`: how far the cut carries you forward
-- for real, and when (the animations are exported in place; SwordController moves you, stopping short of a foe).
export type Lunge = { studs: number, from: number, to: number }
-- `hang`: the slow-motion stretch at the top of a jump (in the animation's keys), when your camera eases in
-- (SwordFx.HANG_ZOOM)
export type Hang = { from: number, to: number }
-- `line`: a line-shaped cut (the spear's Sky Pierce): everything within `width` / 2 of the line from you to `length`
-- ahead and within `burst` of its end (SwordRules.cutReaches; `reach` and `arc` unused then)
export type Line = { length: number, width: number, burst: number }
export type Cut = { power: number, hitAt: number, cancelAt: number?, length: number, reach: number, arc: number, line: Line?, lunge: Lunge?, hang: Hang? }
-- The skill (the dash slash, sword-moves round): `dash` moves you `studs` forward from `from` to `to` (through foes
-- like the dodge, never past `maxStuds`); at `hitAt` the cut lines appear and every foe whose edge is within `width` / 2
-- of the path is hit (the server clamps the path to maxStuds + slack)
export type Dash = { studs: number, maxStuds: number, margin: number, width: number, from: number, to: number, slack: number }
-- What a skill hits (sword skills round, spec 2026-11-06-sword-skills-design 3; the same fields as
-- Util/SwordRules.SkillShape, which decides it): the dash's path, a spin around you, a line or a travelling wave ahead,
-- strikes on the foe you aim at, or an arc in front of you. Only a dash-shaped skill has a `dash` (it moves you).
export type SkillShape = {
	kind: "dash" | "spin" | "line" | "wave" | "judgment" | "arc",
	radius: number?,
	length: number?,
	width: number?,
	speed: number?,
	range: number?,
	angle: number?,
	strikes: number?,
	gap: number?,
	maxStuds: number?,
	slack: number?,
	blast: number?,
}
-- A skill whose animation holds its pose until it reaches its foe (Thornline: the blade in the ground until the vines
-- arrive): frozen at track time `at`, its `snap` key playing as they arrive (SwordRules.holdFor)
export type Hold = { at: number, snap: number }
-- When the skill frees you to attack and move again (owner 2026-11-07, "free after the hit"): `at` seconds in, plus the
-- skill's travel to its foe with `reach` (SwordRules.skillFreeAt); none: its length
export type Free = { at: number, reach: boolean? }
export type Skill = { power: number, hitAt: number, length: number, cooldown: number, shape: SkillShape, dash: Dash?, hold: Hold?, free: Free? }
-- A sword's effects (Config/SwordSkillFx looks): on its slashes, its finisher (cut 3) and its skill
export type SwordFx = { slash: string, finisher: string, skill: string }
-- animations: published asset ids by move ("" until published: Studio plays ReplicatedStorage.SwordAnimations);
-- sounds: asset ids by moment ("" plays nothing); cues: each move's sounds layered at set moments, seconds from its
-- start (SwordController; a dodge stops the ones still to come; `stopAfter`: a long sound faded out that many seconds
-- after it starts); slash: its swing arcs' and hits' colour ({ r, g, b }) and size (Config/SwordFx, Util/HitFx),
-- plain on the starter, bolder on the Forge's swords
export type Cue = { key: string, at: number, stopAfter: number? }
export type Sword = {
	name: string,
	power: number, -- kept for old data; damage uses the weapon's Power (Config/Weapons) instead
	element: string?,
	model: string, -- ReplicatedStorage.WeaponModels child
	combo: { Cut },
	skill: Skill,
	animations: { [string]: string },
	sounds: { [string]: string },
	cues: { [string]: { Cue } },
	fx: SwordFx?, -- the round 1 swords' own effects (the Steel Sword has none: today's look)
	slash: { color: { number }, scale: number },
}

-- Every weapon's skill cooldown, seconds (owner 2026-11-09: "increase the weapon skill cooldown and make the weapons
-- share cooldowns", up from 8): one timer per fighter whatever weapon is in hand (BattleService), started full as a fight
-- opens (SwordRules.openingSkillReady)
local SKILL_COOLDOWN = 12

local SWORDS: { [string]: Sword } = {
	starterSword = {
		name = "Steel Sword",
		power = 1,
		element = nil,
		model = "StarterSword",
		slash = { color = { 207, 230, 255 }, scale = 1 }, -- pale steel
		-- Sword-moves round (spec 2026-11-04-sword-moves-design): powers scaled so the chained combo's damage a second is
		-- what it was (tests/SwordsConfig), the Hit markers of the new animations
		combo = {
			-- the forehand: coiled high, a snapped diagonal cut down across while lunging in
			{ power = 0.298, hitAt = 0.217, cancelAt = 0.34, length = 0.60, reach = 9, arc = 80, lunge = { studs = 1.1, from = 0.167, to = 0.25 } },
			-- the backhand: from low on the left, a rising sweep out to the right
			{ power = 0.298, hitAt = 0.183, cancelAt = 0.32, length = 0.58, reach = 9, arc = 100, lunge = { studs = 0.8, from = 0.133, to = 0.22 } },
			-- the finisher: both hands, a big spinning leap (about 5 studs up) that hangs in slow motion at the top, a
			-- slam that stabs the sword into the ground, then kneeling over it head bowed (owner 2026-11-04); slower,
			-- so it hits harder (the damage a second stays)
			{
				power = 0.776,
				hitAt = 0.70,
				length = 1.25,
				reach = 10,
				arc = 70,
				lunge = { studs = 3.0, from = 0.17, to = 0.66 },
				hang = { from = 0.31, to = 0.56 },
			},
		},
		-- the dash slash: a draw stance, a 9-stud dash, the cut lines (and the damage) at 0.62 s
		skill = {
			power = 0.9,
			hitAt = 0.62,
			length = 1.0,
			cooldown = SKILL_COOLDOWN,
			dash = { studs = 9, maxStuds = 20, margin = 1.5, width = 4, from = 0.30, to = 0.42, slack = 3 },
			shape = { kind = "dash", width = 4, maxStuds = 20, slack = 3 }, -- the dash's path (SwordRules.skillHits)
		},
		animations = {
			draw = "rbxassetid://94917864223617",
			sheath = "rbxassetid://96323080543778",
			-- The sword-moves round (spec 2026-11-04-sword-moves-design), saved to Roblox by the owner
			cut1 = "rbxassetid://134918938054012",
			cut2 = "rbxassetid://113721218431899",
			cut3 = "rbxassetid://101353745325846", -- the big jump version (1.25 s, Hit 0.70)
			skill = "rbxassetid://103074431845414", -- the dash slash
			dodge = "rbxassetid://110055662976350",
			flinch = "rbxassetid://91049639458737",
			down = "rbxassetid://117813163577525",
			getUp = "rbxassetid://124246174866336",
			ready = "rbxassetid://106912114526036",
			run = "rbxassetid://130791965340714",
		},
		-- Pro Sound Effects (Roblox's licensed library). Owner 2026-11-04: a whoosh as the finisher jumps and
		-- fuller slashes: each swish gets an air layer, the finisher a jump, slam and ground hit, the dash slash
		-- a draw, a dash and its cut lines, every hit a thud under the blade and big hits a beefy burst
		sounds = {
			swing1 = "rbxassetid://9119750447", -- Sword Swishes 9: fast airy swipe
			swing2 = "rbxassetid://9119749812", -- Sword Swishes 4: sharp swipe
			swing3 = "rbxassetid://9119749263", -- Sword Swish 5: swing with a metal shing (the finisher's fall)
			air1 = "rbxassetid://9120704978", -- Whooshes Fast Wipes Quick Airy Slices 3: the forehand's air
			air2 = "rbxassetid://9120704940", -- Whooshes Fast Wipes Quick Airy Slices 1: the backhand's air
			jump = "rbxassetid://9125805579", -- Rising Whoosh Hissing Build Up Ascending Swoosh: the finisher's leap
			slam = "rbxassetid://9120730138", -- Whoosh Impact 4: thick swish, hard reverberant impact
			ground = "rbxassetid://9118678952", -- Rocks Dirt Impacts In Ground 29: the sword stabbing into the earth
			dashDraw = "rbxassetid://9119749145", -- Sword Swish 102: a metal shing, drawing the sword
			dash = "rbxassetid://9126229255", -- Whoosh By Fast Airy Swooshing Whipping Thuds: the dash
			cutLines = "rbxassetid://9119384855", -- Soul Slice 15: searing, sharp, airy decay (the cut lines)
			hit = "rbxassetid://9119746598", -- Sword Hit 1: a slice with a metal ring
			hitThud = "rbxassetid://9113487341", -- Body Hit 1 (Sneaker Kicks): weight under the blade
			hitBig = "rbxassetid://9116385079", -- Magic Burst 4: big beefy impact, glowing decay (finisher, dash slash)
			draw = "rbxassetid://9119744642", -- Sword Draw Clang 29: unsheathing
			dodge = "rbxassetid://9126013644", -- Swish Sharp 13: the dash
			ring = "rbxassetid://9116394545", -- Magic Glows Chiming Hits 1: a ring appears under you
			down = "rbxassetid://9113473249", -- Body Fall 31: knocked down
			getUp = "rbxassetid://9126013811", -- Swish Sharp 17: back up
		},
		-- With the swing (the snap, not the tap), the finisher's launch, fall, slam and stab, the dash slash's draw,
		-- dash and cut lines
		cues = {
			cut1 = { { key = "swing1", at = 0.12 }, { key = "air1", at = 0.13 } },
			cut2 = { { key = "swing2", at = 0.10 }, { key = "air2", at = 0.11 } },
			cut3 = { { key = "jump", at = 0.15 }, { key = "swing3", at = 0.56 }, { key = "slam", at = 0.66 }, { key = "ground", at = 0.68 } },
			skill = { { key = "dashDraw", at = 0.26 }, { key = "dash", at = 0.30 }, { key = "cutLines", at = 0.60 } },
		},
	},
}

-- The round 1 swords (sword skills round, spec 2026-11-06-sword-skills-design): the Steel Sword's cuts, animations and
-- sounds (the same tables, not copies), each its own skill (today's damage and cooldown, its own shape; timings
-- matched to its animation's Hit marker), skill animation (from ReplicatedStorage.SwordAnimations.<model> until
-- published), skill cues and effects (`fx`, Config/SwordSkillFx)
local starter = SWORDS.starterSword
-- `own`: a sword's own sounds (added to the starter's) and cues added to its cuts' (the starter's kept). `skillAnimation`:
-- its published skill move (the owner's Save to Roblox id; "" plays its KeyframeSequence in Studio only)
type Own = { sounds: { [string]: string }?, cutCues: { [string]: { Cue } }? }
local function withSkill(name: string, model: string, skillAnimation: string, skill: Skill, fx: SwordFx, skillCues: { Cue }, own: Own?): Sword
	local animations = table.clone(starter.animations)
	animations.skill = skillAnimation
	local cues = table.clone(starter.cues)
	cues.skill = skillCues
	local sounds = starter.sounds
	if own and own.sounds then
		sounds = table.clone(starter.sounds)
		for key, id in own.sounds do
			sounds[key] = id
		end
	end
	for move, extra in (if own then own.cutCues else nil) or {} do
		local list = table.clone(starter.cues[move])
		table.move(extra, 1, #extra, #list + 1, list)
		cues[move] = list
	end
	return {
		name = name,
		power = starter.power,
		element = nil,
		model = model,
		slash = starter.slash,
		combo = starter.combo,
		skill = skill,
		animations = animations,
		sounds = sounds,
		cues = cues,
		fx = fx,
	}
end

-- Elemental Spin (owner 2026-11-07: option B, a double spin whipping up an element tornado): two fast turns with the
-- blade out, then a ring wave of its element blasts out along the ground (its Hit marker,
-- tools/blender/anim_forge_sword.py); every foe within 9 studs. The five Forge Swords share it, each in its element:
-- a sound key with an `_<Element>` version plays that one for that element's sword (SwordController.PlaySound)
SWORDS.forgeSword = withSkill("Forge Sword", "ForgeSword", "rbxassetid://87540825929374", {
	power = 0.9,
	hitAt = 0.8,
	length = 1.1,
	cooldown = SKILL_COOLDOWN,
	shape = { kind = "spin", radius = 9 },
	free = { at = 0.8 }, -- the wave
}, { slash = "elementTrail", finisher = "elementBurst", skill = "elementalSpin" }, {
	{ key = "dash", at = 0.25 }, -- the first turn
	{ key = "dodge", at = 0.5 }, -- the second
	{ key = "elementBlast", at = 0.8 }, -- the ring wave
}, {
	-- Pro Sound Effects, kept quiet (SOUND_VOLUMES; levelled by Config/SoundLevels): per element a layer under each
	-- cut's swish and a blast for the finisher and the ring wave (the plain keys: Ember's, for a sword with none)
	sounds = {
		elementLayer = "rbxassetid://9114446852",
		elementBlast = "rbxassetid://9117985933",
		elementLayer_Ember = "rbxassetid://9114446852", -- Fire Whoosh 15
		elementBlast_Ember = "rbxassetid://9117985933", -- Pyro Fire Ball Burst 7
		elementLayer_Tide = "rbxassetid://9118859146", -- Seahorse Splash Fast 402
		elementBlast_Tide = "rbxassetid://9120585252", -- Water Splash Big Water Splash Dive In 1
		elementLayer_Bloom = "rbxassetid://9114518070", -- Foliage Movement 2
		elementBlast_Bloom = "rbxassetid://9120258724", -- Tree Branches Breaking Snapping Cracking 1
		elementLayer_Volt = "rbxassetid://9114277757", -- Electric Zaps 12
		elementBlast_Volt = "rbxassetid://9114277402", -- Electric Zaps 6
		elementLayer_Shade = "rbxassetid://9125404581", -- Boom Pass By Subtle Low End
		elementBlast_Shade = "rbxassetid://9113551598", -- Boom Pass By Low End Multiple Variations 2
	},
	cutCues = {
		cut1 = { { key = "elementLayer", at = 0.12 } },
		cut2 = { { key = "elementLayer", at = 0.10 } },
		cut3 = { { key = "elementLayer", at = 0.56 }, { key = "elementBlast", at = 0.68 } },
	},
})
-- Thornline (owner 2026-11-07): a short hop, the blade plunged point-down into the ground (its Hit marker: the vines
-- leave, tools/blender/anim_verdant_blade.py) and held there until thorny vines racing along the ground toward your aim
-- (18 x 4 studs, 20 studs a second) reach the first foe and snap shut on it, catching every foe within 4 studs
SWORDS.verdantBlade = withSkill("Verdant Blade", "VerdantBlade", "rbxassetid://101505841745641", {
	power = 0.9,
	hitAt = 0.45,
	length = 0.95,
	cooldown = SKILL_COOLDOWN,
	shape = { kind = "wave", length = 18, width = 4, speed = 20, blast = 4 },
	hold = { at = 0.5, snap = 0.58 },
	free = { at = 0.45, reach = true }, -- the vines snapping shut on the foe
}, { slash = "leafShed", finisher = "rootBurst", skill = "thornline" }, {
	{ key = "air1", at = 0.12 }, -- the hop
	{ key = "ground", at = 0.42 }, -- the blade plunging into the earth
	{ key = "vinesTear", at = 0.45 }, -- the vines tearing up (their snap plays vineSnap where they close)
}, {
	-- Pro Sound Effects, kept quiet (SOUND_VOLUMES; levelled by Config/SoundLevels)
	sounds = {
		leafRustle = "rbxassetid://9114518070", -- Foliage Movement 2: a leafy rustle under every cut's swish
		rootCrack = "rbxassetid://9120258724", -- Tree Branches Breaking Snapping Cracking 1: the finisher's roots
		vinesTear = "rbxassetid://9118676043", -- Rocks Dirt Debris Pouring Bursts 13: the vines tearing up the ground
		vineSnap = "rbxassetid://9113582284", -- Branch Snap Wood Stick Crack Various Sizes 7: the vines snapping shut
	},
	cutCues = {
		cut1 = { { key = "leafRustle", at = 0.12 } },
		cut2 = { { key = "leafRustle", at = 0.10 } },
		cut3 = { { key = "leafRustle", at = 0.56 }, { key = "rootCrack", at = 0.68 } },
	},
})
-- Sunfall Cleave (owner 2026-11-07): a high jump, a long charge hanging at the top, one cleave in the air (its Hit
-- marker: tools/blender/anim_sunforged_blade.py) launching a fiery crescent that glides down toward your aim at 14 studs
-- a second (24 x 6 studs) and bursts on the first foe it touches, hitting every foe within 6 studs of the burst
SWORDS.sunforgedBlade = withSkill("Sunforged Blade", "SunforgedBlade", "rbxassetid://135525152609348", {
	power = 0.9,
	hitAt = 1.78,
	length = 2.45,
	cooldown = SKILL_COOLDOWN,
	shape = { kind = "wave", length = 24, width = 6, speed = 14, blast = 6 },
	free = { at = 1.78 }, -- the crescent launched (it flies on by itself)
}, { slash = "fireTrail", finisher = "lavaCrack", skill = "sunfallCleave" }, {
	{ key = "jump", at = 0.15 }, -- the leap
	{ key = "flameLicks", at = 0.42 }, -- sunlight gathering as you hang
	{ key = "fireSwing", at = 1.7 }, -- the cleave (the crescent's burst plays fireBurst where it lands)
}, {
	-- Pro Sound Effects, kept quiet (SOUND_VOLUMES; levelled by Config/SoundLevels)
	sounds = {
		fireWhoosh = "rbxassetid://9114446852", -- Fire Whoosh 15: a fire layer under every cut's swish
		lavaBurst = "rbxassetid://9125615451", -- Kerosene Explosion Whooshing Poofs Crackling: the finisher's lava crack
		flameLicks = "rbxassetid://9114463410", -- Flame Licks 10: sunlight gathering into the blade
		fireSwing = "rbxassetid://9114446277", -- Fire Whoosh 6: the cleave launching the crescent
		fireBurst = "rbxassetid://9117985933", -- Pyro Fire Ball Burst 7: the crescent bursting
	},
	cutCues = {
		cut1 = { { key = "fireWhoosh", at = 0.12 } },
		cut2 = { { key = "fireWhoosh", at = 0.10 } },
		cut3 = { { key = "fireWhoosh", at = 0.56 }, { key = "lavaBurst", at = 0.68 } },
	},
})
-- Prism Judgment (owner 2026-11-07: the spinning ring, each blade diving in turn; everything exaggerated): the blade
-- swept to the sky summoning five ghost blades in a ring above the boss, then pointed at it; they dive one by one 0.15 s
-- apart (the first at its Hit marker, tools/blender/anim_prism_blade.py), a fifth of the damage each, on the foe you aim
-- at within 24 studs; a rainbow pillar after
SWORDS.prismBlade = withSkill("Prism Blade", "PrismBlade", "rbxassetid://136391900364573", {
	power = 0.9,
	hitAt = 0.6,
	length = 1.75,
	cooldown = SKILL_COOLDOWN,
	shape = { kind = "judgment", range = 24, angle = 60, strikes = 5, gap = 0.15 },
	free = { at = 1.2 }, -- the last strike
}, { slash = "rainbowArc", finisher = "prismShatter", skill = "prismJudgment" }, {
	{ key = "prismSummon", at = 0.12 }, -- the summon (each strike plays prismStrike, the pillar prismBoom)
	{ key = "dashDraw", at = 0.5 }, -- the blade snapped down to point at the boss
}, {
	-- Pro Sound Effects, kept quiet (SOUND_VOLUMES; levelled by Config/SoundLevels)
	sounds = {
		crystalChime = "rbxassetid://9116394876", -- Magic Glows Soft Clusters Of Chiming Hits 2: a chime under every cut
		prismShatter = "rbxassetid://9114591515", -- Glass Breaks 2: the finisher's crystals shattering
		prismSummon = "rbxassetid://9120747619", -- Whooshy Magic Sucks Somewhat Phasey 8: the ghost blades summoned
		prismStrike = "rbxassetid://9116393976", -- Magic Glow Short Pulsing Bursts 9: each ghost blade striking
		prismBoom = "rbxassetid://9114224721", -- Earthquake Explosion 1: the rainbow pillar
	},
	cutCues = {
		cut1 = { { key = "crystalChime", at = 0.12 } },
		cut2 = { { key = "crystalChime", at = 0.10 } },
		cut3 = { { key = "crystalChime", at = 0.56 }, { key = "prismShatter", at = 0.68 } },
	},
})

-- The spear moveset (weapons round 2, spec 2026-11-07-weapons-round2-design 5.2; the owner's storyboard 2026-11-07):
-- shared by all four spears. Held upright at your side between moves; every attack swings it down into both hands
-- first. Long and narrow where the sword is wide: the thrust 12 studs in 30 degrees, the sweep 11 in 120, Sky Pierce a
-- leap and a plunge 8 studs ahead with a 4-stud burst there; nothing reaches past 12 (a boss's swipe still reaches you).
-- The same damage a second as the sword combo (tests/SwordsConfig). Timings are its animations' (tools/blender/
-- anim_spear.py, exaggerated on the owner's ask 2026-11-07: a deep lunge, a spinning sweep, a big spinning leap); its
-- moves were published by the owner (2026-11-07). Piercing Rush: a 12-stud rush tip-first,
-- every foe along a 3-stud-wide line as it arrives.
do
	-- its own moves (published by the owner 2026-11-07); dodge, flinch, down and get up stay the Steel Sword's
	local animations = table.clone(starter.animations)
	animations.ready = "rbxassetid://108741829282686"
	animations.draw = "rbxassetid://137638158886237"
	animations.sheath = "rbxassetid://75538804804480"
	animations.run = "rbxassetid://83298416937626"
	animations.cut1 = "rbxassetid://132162880960663"
	animations.cut2 = "rbxassetid://129170104368589"
	animations.cut3 = "rbxassetid://100993680318049"
	animations.skill = "rbxassetid://97504016219341"
	-- Its own sounds on top of the sword's (Pro Sound Effects, measured into Config/SoundLevels): the thrust's air, the
	-- sweep's spin, rocks bursting on the plunge, the rush's charge, dash and skid
	local sounds = table.clone(starter.sounds)
	sounds.thrustAir = "rbxassetid://9114326590" -- Energy Cloud Whooshing By Very Fast 3
	sounds.spinWhoosh = "rbxassetid://9119226861" -- Slow Whoosh Airy Rumble Slicing Spinning 2
	sounds.rockBurst = "rbxassetid://9118631275" -- Rock Impacts 12
	sounds.rushCharge = "rbxassetid://9118159097" -- Reverse Suck 3
	sounds.rushDash = "rbxassetid://9120629528" -- Web Whoosh Fast Heavy Swooshes 3
	sounds.skid = "rbxassetid://9114658416" -- Gravel Slide 1
	SWORDS.spear = {
		name = "Spear",
		power = starter.power,
		element = nil,
		model = "Spear",
		slash = starter.slash,
		combo = {
			-- Thrust: swung down into both hands, coiled far back, a straight stab in a deep lunge
			{ power = 0.304, hitAt = 0.22, cancelAt = 0.36, length = 0.62, reach = 12, arc = 30, lunge = { studs = 2.0, from = 0.16, to = 0.22 } },
			-- Sweep: pulled back low, a full spin on the spot, the head slicing across the front (for groups)
			{ power = 0.304, hitAt = 0.20, cancelAt = 0.34, length = 0.62, reach = 11, arc = 120, lunge = { studs = 0.4, from = 0.12, to = 0.36 } },
			-- Sky Pierce: a big spinning leap with it raised, a plunge tip-first into the ground ahead, a shockwave there
			{
				power = 0.792,
				hitAt = 0.70,
				length = 1.25,
				reach = 12,
				arc = 30,
				line = { length = 8, width = 3, burst = 4 },
				lunge = { studs = 3.0, from = 0.17, to = 0.70 },
				hang = { from = 0.31, to = 0.56 },
			},
		},
		skill = {
			power = 0.9,
			hitAt = 0.45,
			length = 1.0,
			cooldown = SKILL_COOLDOWN,
			dash = { studs = 12, maxStuds = 20, margin = 1.5, width = 3, from = 0.28, to = 0.42, slack = 3 },
			shape = { kind = "dash", width = 3, maxStuds = 20, slack = 3 },
			free = { at = 0.45 },
		},
		animations = animations,
		sounds = sounds,
		-- with the swing, the thrust's stab, the sweep's spin, the leap, the plunge's slam and rocks, the rush
		cues = {
			cut1 = { { key = "swing1", at = 0.16 }, { key = "thrustAir", at = 0.18 } },
			cut2 = { { key = "swing2", at = 0.12 }, { key = "spinWhoosh", at = 0.14 } },
			cut3 = { { key = "jump", at = 0.17 }, { key = "swing3", at = 0.56 }, { key = "slam", at = 0.68 }, { key = "ground", at = 0.70 }, { key = "rockBurst", at = 0.70 } },
			skill = { { key = "rushCharge", at = 0.05 }, { key = "rushDash", at = 0.28 }, { key = "cutLines", at = 0.45 }, { key = "skid", at = 0.47 } },
		},
		fx = { slash = "spearStreak", finisher = "skyPierce", skill = "piercingRush" },
	}
	-- Titan's Wrath (weapons round 2.5, spec 2026-11-08-forge-relayout-and-titans-wrath-design 3; owner 2026-11-08: the
	-- storyboard, exaggerated): the Titan's Lance's own skill in place of Piercing Rush. A long, loud charge in a low
	-- stance (a dodge or a switch before the thrust cancels it), then one huge thrust at its Hit marker
	-- (tools/blender/anim_titans_lance.py): every foe on the 14 x 4 line ahead. You stay put: the beam and the fissure
	-- carry the reach. The spear's cuts, moves and sounds, the same tables.
	local spear = SWORDS.spear
	-- Its own sounds on top of the spear's (Pro Sound Effects, measured into Config/SoundLevels)
	local lanceSounds = table.clone(sounds)
	lanceSounds.wrathCharge = "rbxassetid://9125973984" -- Spaceship Blast High Pitch Energy Charge Up: light into the tip
	lanceSounds.wrathRumble = "rbxassetid://9114344093" -- Energy Presence 8: the ground rumbling through the charge
	lanceSounds.wrathThrust = "rbxassetid://9120023325" -- Thunder With Lion Roar Searing Blast 5: the thrust
	lanceSounds.thornsTear = "rbxassetid://9118676043" -- Rocks Dirt Debris Pouring Bursts 13: thorns tearing up
	lanceSounds.wrathFissure = "rbxassetid://9113216700" -- Avalanche Crashing 3: the fissure tearing open (its burst)
	local lanceAnimations = table.clone(animations)
	lanceAnimations.skill = "rbxassetid://108621386304529" -- Titan's Wrath (SwordAnimations.TitansLance.skill)
	SWORDS.titansLance = {
		name = "Titan's Lance",
		power = starter.power,
		element = nil,
		model = "TitansLance",
		slash = starter.slash,
		combo = spear.combo,
		skill = {
			power = 0.9,
			hitAt = 1.35,
			length = 2.2,
			cooldown = SKILL_COOLDOWN,
			shape = { kind = "line", length = 14, width = 4 },
			free = { at = 1.35 }, -- the thrust
		},
		animations = lanceAnimations,
		sounds = lanceSounds,
		-- the spear's cuts; the skill: light gathering, the ground rumbling, the thrust's roar, thorns tearing up (the
		-- fissure's crash plays where it bursts: Config/SwordSkillFx titansWrath burstSound)
		cues = {
			cut1 = spear.cues.cut1,
			cut2 = spear.cues.cut2,
			cut3 = spear.cues.cut3,
			skill = { { key = "wrathCharge", at = 0.05 }, { key = "wrathRumble", at = 0.15 }, { key = "wrathThrust", at = 1.31 }, { key = "thornsTear", at = 1.42 } },
		},
		fx = { slash = "spearStreak", finisher = "skyPierce", skill = "titansWrath" },
	}
	-- The Halberd's and the Trident's own skills (weapons round 2.5 part 2, spec 2026-11-09-halberd-and-trident-skills-
	-- design; owner 2026-11-09), in place of Piercing Rush; the spear's cuts, moves and sounds, the same tables. Neither
	-- moves you. Their animations: tools/blender/anim_magma_halberd.py, anim_tidal_trident.py (SwordAnimations.<model>.skill,
	-- published 2026-11-09).
	local function ownSkill(name: string, model: string, skill: Skill, skillAnimation: string, look: string, skillCues: { Cue }, extra: { [string]: string }): Sword
		local own = table.clone(spear.animations)
		own.skill = skillAnimation
		local ownSounds = table.clone(spear.sounds)
		for key, id in extra do
			ownSounds[key] = id
		end
		return {
			name = name,
			power = starter.power,
			element = nil,
			model = model,
			slash = starter.slash,
			combo = spear.combo,
			skill = skill,
			animations = own,
			sounds = ownSounds,
			cues = { cut1 = spear.cues.cut1, cut2 = spear.cues.cut2, cut3 = spear.cues.cut3, skill = skillCues },
			fx = { slash = "spearStreak", finisher = "skyPierce", skill = look },
		}
	end
	-- Magma Cleave ("since magma halberd is very rare something simple is fine. we can just do one big swipe. with
	-- flaming horizontal slash effects"): a short wind-up over the shoulder, one huge swing right to left at its Hit
	-- marker: every foe in the half circle in front of you, 11 studs out
	SWORDS.magmaHalberd = ownSkill("Magma Halberd", "MagmaHalberd", {
		power = 0.9,
		hitAt = 0.6,
		length = 1.2,
		cooldown = SKILL_COOLDOWN,
		shape = { kind = "arc", radius = 11, angle = 180 },
		free = { at = 0.6 },
	}, "rbxassetid://139376815690800", "magmaCleave", {
		{ key = "cleaveCharge", at = 0.02 },
		{ key = "cleaveRush", at = 0.22 },
		{ key = "cleaveWhoosh", at = 0.46 },
		{ key = "cleaveFire", at = 0.6 },
	}, {
		-- the charge-up (owner 2026-11-09: "add a charging up sound while charging"), measured in Studio 2026-11-09: the
		-- fire swells from 0.2 s to its peak at 0.72 s; the reversed whoosh peaks 0.38 s in, so at the swing
		cleaveCharge = "rbxassetid://9114463016", -- Flame Licks 4
		cleaveRush = "rbxassetid://9118158113", -- Reversed Whoosh Backwards Hissing Burst 2
		-- Pro Sound Effects already measured (Config/SoundLevels)
		cleaveWhoosh = "rbxassetid://9120717850", -- Whoosh Fast Swish By 4: the big swing
		cleaveFire = "rbxassetid://9114438917", -- Fire Sheet 3: the fire crescent bursting out
	})
	-- Torrent Strike ("the player strike the ground with the trident, while the trident is stuck to the ground,
	-- torrents of water appears from the ground"): raised overhead, slammed prongs-first into the ground (its Slam
	-- marker), torrents bursting up round you at its Hit marker: every foe within 12 studs, once (a second, wider ring of
	-- torrents is only for show)
	SWORDS.tidalTrident = ownSkill("Tidal Trident", "TidalTrident", {
		power = 0.9,
		hitAt = 0.75,
		length = 1.9,
		cooldown = SKILL_COOLDOWN,
		shape = { kind = "spin", radius = 12 },
		free = { at = 0.75 },
	}, "rbxassetid://97640469455794", "torrentStrike", {
		{ key = "swing2", at = 0.4 },
		{ key = "torrentSlam", at = 0.55 },
		{ key = "torrentSplash", at = 0.57 },
		{ key = "torrentSurge", at = 0.75 },
		{ key = "torrentRain", at = 2.85, stopAfter = 2 }, -- a 51 s clip: only while the water falls
	}, {
		-- Pro Sound Effects already measured (Config/SoundLevels)
		torrentSlam = "rbxassetid://9125484367", -- Deep Hits Big Reverberant Booms Rumbling Tail 2: the prongs hit the ground
		torrentSplash = "rbxassetid://9120585252", -- Water Splash Big Water Splash Dive In 1: the splash ring
		torrentSurge = "rbxassetid://9120607089", -- Water Surge 3: the torrents bursting up
		torrentRain = "rbxassetid://9112793880", -- Heavy Rain 1: the water falling back
	})
end

-- The scythe moveset (weapons round 3, spec 2026-11-09-weapons-round3-scythes-design 5.2; the owner: "epic. I want
-- exaggerated moves, wide slashes in all directions", "a bit slower but still flashy"): shared by all four scythes.
-- Upright at your side between moves like the spear; every attack brings both hands on with a heavy wind-up. Each cut
-- about a third slower than the sword's and so harder, the same damage a second against one foe (tests/SwordsConfig):
-- Reap, one huge sweep across your front; Back Sweep, the blade carving round behind you and through your front again
-- (its damage lands in front: every cut soft-aims you at the foe, so a hit behind you would miss the lone foe of most
-- fights); Whirlwind, two full spins, every foe round you. Nothing past 10 studs (a boss's swipe still reaches you).
-- Reaping Cyclone (spec 5.3): three spins, a ring of crescents each, every foe within 9 studs on the third. Timings are
-- its animations' (tools/blender/anim_scythe.py, approved and published by the owner 2026-11-09); sounds and cues are
-- the spear's until its own (plan Task 6).
do
	-- its own moves (published by the owner 2026-11-09); dodge, flinch, down and get up stay the Steel Sword's
	local animations = table.clone(starter.animations)
	animations.ready = "rbxassetid://107381698123347"
	animations.draw = "rbxassetid://120963161842619"
	animations.sheath = "rbxassetid://87007060779059"
	animations.run = "rbxassetid://93344115404944"
	animations.cut1 = "rbxassetid://84614363717630"
	animations.cut2 = "rbxassetid://101503127287374"
	animations.cut3 = "rbxassetid://112263670560674"
	animations.skill = "rbxassetid://133282199201010"
	local spear = SWORDS.spear
	SWORDS.scythe = {
		name = "Scythe",
		power = starter.power,
		element = nil,
		model = "Scythe",
		slash = starter.slash,
		combo = {
			-- Reap: wound back over the right shoulder, one huge flat sweep right to left across your front, a step in
			{ power = 0.4334, hitAt = 0.34, cancelAt = 0.50, length = 0.85, reach = 10, arc = 180, lunge = { studs = 1.1, from = 0.22, to = 0.34 } },
			-- Back Sweep: a low spin, the blade across your front, round behind you and through your front again at the hit
			{ power = 0.4334, hitAt = 0.42, cancelAt = 0.58, length = 0.90, reach = 10, arc = 180, lunge = { studs = 0.8, from = 0.15, to = 0.42 } },
			-- Whirlwind: two full spins with the scythe held out, every foe round you as the second ends, a shake
			{ power = 1.1301, hitAt = 0.98, length = 1.70, reach = 10, arc = 360 },
		},
		-- Reaping Cyclone: three spins with the scythe raised high, every foe within 9 studs on the third
		skill = {
			power = 0.9,
			hitAt = 0.94,
			length = 1.6,
			cooldown = SKILL_COOLDOWN,
			shape = { kind = "spin", radius = 9 },
			free = { at = 0.94 },
		},
		animations = animations,
		sounds = table.clone(spear.sounds),
		cues = {
			cut1 = table.clone(spear.cues.cut1),
			cut2 = table.clone(spear.cues.cut2),
			cut3 = table.clone(spear.cues.cut3),
			skill = table.clone(spear.cues.skill),
		},
		fx = { slash = "scytheSweep", finisher = "scytheWhirl", skill = "reapingCyclone" },
	}
end

return {
	STARTER = "starterSword",
	SWORDS = SWORDS,
	SKILL_COOLDOWN = SKILL_COOLDOWN,
	UNLOCK_SHOP_LEVEL = 4, -- everyone gets the starter sword here (when boss 1 opens)
	SHEATH_SECONDS = 4, -- the sword goes back on your back after this long without attacking
	COMBO_RESET = 0.9, -- a tap this long after a cut ends still continues the combo; later starts it again
	LUNGE_STOP = 1.0, -- studs short of a foe's edge a cut's lunge stops (SwordRules.lungeLength)
	SOFT_AIM_RANGE = 14, -- attacking turns you toward a target whose edge is this close...
	SOFT_AIM_ANGLE = 75, -- ...and within this many degrees of where you face
	PLAYER_DAMAGE_COLOR = { 255, 214, 92 }, -- your hits' numbers (your creature's stay white)
	-- Where a weapon sits, by family (Config/Weapons `family`; its model's origin is where the hand holds it, the blade or
	-- head along +Y): `hand` in the right hand's space (the grip the animations were keyed with: 0.18 down, tilted
	-- `angleX` degrees about X, then `twist` about the blade), `back` in the UpperTorso's space, `backScale` its size there.
	-- tools/blender/anim_kit.py hand_grip() keeps the same hand numbers.
	GRIPS = {
		-- twist (owner 2026-11-07: "hold the sword the right way, not flat"): every sword model has its edge along X, so a
		-- quarter turn puts the flat to the palm and the edge leading the cuts. Back (2026-11-06, owner: the longer new
		-- swords pierced the ground; keep the original angle, just higher): the handle up over the right shoulder, the
		-- blade down to the left hip, every sword's tip clear of the ground (the Sunforged Blade, the longest, by about
		-- 0.3 studs on an R15 body) with the hilt under a stud over the head; at 1.4x the hilt would stand 2+ studs up
		sword = {
			hand = { y = -0.18, angleX = -140, twist = 90 },
			back = { x = 0.65, y = 1.9, z = 0.68, angleZ = 150 },
			backScale = 1.05,
		},
		-- Upright at your side (owner's pick C, 2026-11-07): the grip 31% up from the butt; the hand's tilt of -90 makes a
		-- hanging arm hold it straight ahead (the spear's moves are keyed with it, tools/blender/anim_spear.py): in the
		-- ready pose it leans 14 degrees, the butt by the right foot. On the back at its own size, the head up over the
		-- right shoulder 40 degrees from upright (measured in Studio on the longest, the 9.2-stud Titan's Lance: its butt
		-- 0.3 studs over the ground, its tip 3 over the head; 20 degrees from upright put the butt 2.5 into the ground)
		spear = {
			hand = { y = -0.18, angleX = -90, twist = 0 },
			back = { x = 0, y = -0.4, z = 0.7, angleZ = -40 },
			backScale = 1,
		},
		-- Upright at your side like the spear (spec 5.1), the blade over your head curving back; on the back diagonal, the
		-- blade over the shoulder (the spear's numbers to start, calibrated in Studio: plan Task 5). The models have their
		-- blade along +X (Roblox's importer flips Blender's X), so half a turn round the shaft puts it to the left of the
		-- right hand, over the head, as the moves were keyed. tools/blender/anim_kit.py hand_grip("scythe") keeps the same
		-- hand numbers.
		scythe = {
			hand = { y = -0.18, angleX = -90, twist = 180 },
			back = { x = 0, y = -0.4, z = 0.7, angleZ = -40 },
			backScale = 1,
		},
	},
	BODY_WAIT = 10, -- seconds a new character's sword waits for its UpperTorso to arrive before going on it
	GRAB_SECONDS = 0.16, -- into the draw, the hand reaches the sword (the draw move's Grab marker)
	RELEASE_SECONDS = 0.25, -- into the put-away, the sword is back on the back (the sheath move's Release marker)
	POPUP_TURN = 0.8, -- radians a second the sword turns in the first-sword popup
	SOUND_VOLUME = 0.5, -- the sword's sounds (a few play over each other in a combo)
	HIT_SOUND_WINDOW = 0.6, -- seconds: after your own reach check plays the hit sound, the server's hit plays none
	SOUND_PITCH = { 0.88, 1.12 }, -- each sword sound plays at a pitch picked from this range (no clip on a loop)
	-- exceptions: the ring chime softer, a landed hit louder, the layers under a swish or a hit quieter than it
	SOUND_VOLUMES = {
		ring = 0.3,
		hit = 0.6,
		air1 = 0.3,
		air2 = 0.3,
		jump = 0.45,
		slam = 0.55,
		ground = 0.4,
		dashDraw = 0.4,
		dash = 0.45,
		cutLines = 0.45,
		hitThud = 0.35,
		hitBig = 0.4,
		-- the Sunforged Blade's (owner 2026-11-06: the forge's quiet level)
		fireWhoosh = 0.25,
		lavaBurst = 0.35,
		flameLicks = 0.25,
		fireSwing = 0.35,
		fireBurst = 0.4,
		-- the Verdant Blade's
		leafRustle = 0.3,
		rootCrack = 0.35,
		vinesTear = 0.5, -- a quiet clip (its level 35)
		vineSnap = 0.4,
		-- the Prism Blade's
		crystalChime = 0.45, -- a quiet clip (its level 28)
		prismShatter = 0.35,
		prismSummon = 0.5, -- a quiet clip (its level 32)
		prismStrike = 0.35,
		prismBoom = 0.4,
		-- the Forge Sword's (each element's version at the same volume)
		elementLayer = 0.3,
		elementBlast = 0.4,
		-- the spear's
		thrustAir = 0.3,
		spinWhoosh = 0.35,
		rockBurst = 0.4,
		rushCharge = 0.35,
		rushDash = 0.4,
		skid = 0.3,
		wrathCharge = 0.35,
		wrathRumble = 0.45,
		wrathThrust = 0.5,
		thornsTear = 0.4,
		wrathFissure = 0.5,
		cleaveCharge = 0.35,
		cleaveRush = 0.35,
	},
}
