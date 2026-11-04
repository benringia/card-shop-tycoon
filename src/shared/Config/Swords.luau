--!strict
-- Swords the player fights bosses with (spec 2026-11-02-you-in-the-fight-design). Only the starter sword for now; the
-- Forge (project 2) adds one per boss, each with its own combo and skill. Plain data so Lune tests can load it.
-- A cut's damage: the summoned creature's ATK x the cut's power x the sword's power (BattleSim.swordHit). Times are
-- seconds from the cut's start: `hitAt` is the strike frame of its animation (its Hit marker), `cancelAt` the end of
-- its follow-through (the next cut may start there; SwordRules.nextCut), `length` the whole cut. `reach` counts from
-- the target's edge; `arc` is the cone in front of you it hits (degrees). `lunge`: how far the cut carries you forward
-- for real, and when (the animations are exported in place; SwordController moves you, stopping short of a foe).
export type Lunge = { studs: number, from: number, to: number }
-- `hang`: the slow-motion stretch at the top of a jump (in the animation's keys), when your camera eases in
-- (SwordFx.HANG_ZOOM)
export type Hang = { from: number, to: number }
export type Cut = { power: number, hitAt: number, cancelAt: number?, length: number, reach: number, arc: number, lunge: Lunge?, hang: Hang? }
-- The skill (the dash slash, sword-moves round): `dash` moves you `studs` forward from `from` to `to` (through foes
-- like the dodge, never past `maxStuds`); at `hitAt` the cut lines appear and every foe whose edge is within `width` / 2
-- of the path is hit (the server clamps the path to maxStuds + slack)
export type Dash = { studs: number, maxStuds: number, margin: number, width: number, from: number, to: number, slack: number }
export type Skill = { power: number, hitAt: number, length: number, cooldown: number, dash: Dash }
-- animations: published asset ids by move ("" until published: Studio plays ReplicatedStorage.SwordAnimations);
-- sounds: asset ids by moment ("" plays nothing); cues: each move's sounds layered at set moments, seconds from its
-- start (SwordController; a dodge stops the ones still to come); slash: its swing arcs' and hits' colour
-- ({ r, g, b }) and size (Config/SwordFx, Util/HitFx), plain on the starter, bolder on the Forge's swords
export type Cue = { key: string, at: number }
export type Sword = {
	name: string,
	power: number,
	element: string?,
	model: string, -- ReplicatedStorage.WeaponModels child
	combo: { Cut },
	skill: Skill,
	animations: { [string]: string },
	sounds: { [string]: string },
	cues: { [string]: { Cue } },
	slash: { color: { number }, scale: number },
}

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
			cooldown = 8,
			dash = { studs = 9, maxStuds = 20, margin = 1.5, width = 4, from = 0.30, to = 0.42, slack = 3 },
		},
		animations = {
			draw = "rbxassetid://94917864223617",
			sheath = "rbxassetid://96323080543778",
			-- The sword-moves round (spec 2026-11-04-sword-moves-design), saved to Roblox by the owner; the skill
			-- is empty until it's saved too (Studio plays it unpublished, SwordAnims)
			cut1 = "rbxassetid://134918938054012",
			cut2 = "rbxassetid://113721218431899",
			cut3 = "rbxassetid://101353745325846", -- the big jump version (1.25 s, Hit 0.70)
			skill = "",
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

return {
	STARTER = "starterSword",
	SWORDS = SWORDS,
	UNLOCK_SHOP_LEVEL = 4, -- everyone gets the starter sword here (when boss 1 opens)
	SHEATH_SECONDS = 4, -- the sword goes back on your back after this long without attacking
	COMBO_RESET = 0.9, -- a tap this long after a cut ends still continues the combo; later starts it again
	LUNGE_STOP = 1.0, -- studs short of a foe's edge a cut's lunge stops (SwordRules.lungeLength)
	SOFT_AIM_RANGE = 14, -- attacking turns you toward a target whose edge is this close...
	SOFT_AIM_ANGLE = 75, -- ...and within this many degrees of where you face
	PLAYER_DAMAGE_COLOR = { 255, 214, 92 }, -- your hits' numbers (your creature's stay white)
	-- Where a sword sits (its model's origin is the grip's centre, the blade along +Y): in the right hand, in the hand's
	-- space (the grip the animations were keyed with), and on the back, in the UpperTorso's space (the handle up over
	-- the right shoulder, the blade down to the left hip)
	HAND_GRIP = { y = -0.18, angleX = -140 },
	BACK_GRIP = { x = 0.65, y = 1.15, z = 0.68, angleZ = 150 },
	BACK_SCALE = 1.4, -- the sword is this much bigger on the back, so it (and the looks the shop will sell) stands out
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
	},
}
