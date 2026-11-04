--!strict
-- Swords the player fights bosses with (spec 2026-11-02-you-in-the-fight-design). Only the starter sword for now; the
-- Forge (project 2) adds one per boss, each with its own combo and skill. Plain data so Lune tests can load it.
-- A cut's damage: the summoned creature's ATK x the cut's power x the sword's power (BattleSim.swordHit). Times are
-- seconds from the cut's start: `hitAt` is the strike frame of its animation (its Hit marker), `cancelAt` the end of
-- its follow-through (the next cut may start there; SwordRules.nextCut), `length` the whole cut. `reach` counts from
-- the target's edge; `arc` is the cone in front of you it hits (degrees). `lunge`: how far the cut carries you forward
-- for real, and when (the animations are exported in place; SwordController moves you, stopping short of a foe).
export type Lunge = { studs: number, from: number, to: number }
export type Cut = { power: number, hitAt: number, cancelAt: number?, length: number, reach: number, arc: number, lunge: Lunge? }
-- The skill (the dash slash, sword-moves round): `dash` moves you `studs` forward from `from` to `to` (through foes
-- like the dodge, never past `maxStuds`); at `hitAt` the cut lines appear and every foe whose edge is within `width` / 2
-- of the path is hit (the server clamps the path to maxStuds + slack)
export type Dash = { studs: number, maxStuds: number, margin: number, width: number, from: number, to: number, slack: number }
export type Skill = { power: number, hitAt: number, length: number, cooldown: number, dash: Dash }
-- animations: published asset ids by move ("" until published: Studio plays ReplicatedStorage.SwordAnimations);
-- sounds: asset ids by moment ("" plays nothing); slash: its hits' slash arc (colour { r, g, b }, size; Config/SwordFx
-- SLASH, Util/HitFx), plain on the starter, bolder on the Forge's swords
export type Sword = {
	name: string,
	power: number,
	element: string?,
	model: string, -- ReplicatedStorage.WeaponModels child
	combo: { Cut },
	skill: Skill,
	animations: { [string]: string },
	sounds: { [string]: string },
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
			-- the finisher: both hands, a spinning leap into a slam
			{ power = 0.51, hitAt = 0.40, length = 0.88, reach = 10, arc = 70, lunge = { studs = 2.6, from = 0.17, to = 0.40 } },
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
			-- The sword-moves round (spec 2026-11-04-sword-moves-design): empty until the owner saves the new
			-- KeyframeSequences to Roblox (Studio plays them unpublished, SwordAnims); then their ids go here
			cut1 = "",
			cut2 = "",
			cut3 = "",
			skill = "",
			dodge = "rbxassetid://110055662976350",
			flinch = "rbxassetid://91049639458737",
			down = "rbxassetid://117813163577525",
			getUp = "rbxassetid://124246174866336",
			ready = "rbxassetid://106912114526036",
			run = "rbxassetid://130791965340714",
		},
		-- Pro Sound Effects (Roblox's licensed library)
		sounds = {
			swing1 = "rbxassetid://9119750447", -- Sword Swishes 9: fast airy swipe
			swing2 = "rbxassetid://9119749812", -- Sword Swishes 4: sharp swipe
			swing3 = "rbxassetid://9119749263", -- Sword Swish 5: swing with a metal shing (the slam, the skill)
			hit = "rbxassetid://9119746598", -- Sword Hit 1: a slice with a metal ring
			draw = "rbxassetid://9119744642", -- Sword Draw Clang 29: unsheathing
			dodge = "rbxassetid://9126013644", -- Swish Sharp 13: the dash
			ring = "rbxassetid://9116394545", -- Magic Glows Chiming Hits 1: a ring appears under you
			down = "rbxassetid://9113473249", -- Body Fall 31: knocked down
			getUp = "rbxassetid://9126013811", -- Swish Sharp 17: back up
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
	SOUND_VOLUMES = { ring = 0.3, hit = 0.6 }, -- exceptions: the ring chime softer, a landed hit louder
}
