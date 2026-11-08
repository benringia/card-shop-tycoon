--!strict
-- How the player's fight looks and feels (spec 2026-11-02-you-in-the-fight-design): the closing-ring warning (look B),
-- hit feel (sparks, a flash on what you hit, hit-stop, shake), the slash trail, the boss's wind-up glow and the loss
-- countdown. Ring textures: tools/textures/make_ring_textures.py, uploaded. Plain data.
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

return {
	-- The sword-moves round's effect textures (tools/textures/make_sword_fx.py, assets/ui/fx-sword), white, tinted in
	-- game: the swing arc's body (upright: a Beam runs a texture's height along its length), the hit's star burst (a
	-- 4 x 4 flipbook), the dash slash's cut lines (upright) and the stars the arc sheds
	TEXTURES = {
		crescent = "rbxassetid://103655929836006",
		burst = "rbxassetid://114900780647359",
		line = "rbxassetid://111098556704939",
		star = "rbxassetid://117269166059195",
	},

	-- Closing rings: a thin outline of the area and a glowing ring closing onto it (RingRules.closingScale)
	RING_OUTLINE = "rbxassetid://127119552313668",
	RING_GLOW = "rbxassetid://78616850376916",
	CONE_OUTLINE = "rbxassetid://113532760508849",
	CONE_GLOW = "rbxassetid://124524147480952",
	RING_FIT = { outline = 1.024, glow = 1.09 }, -- the textures' margins: a texture this many times the area fits it
	RING_COLOR = rgb(255, 122, 26), -- orange (owner's pick from the mockup): stands out on every arena floor
	RING_OUTLINE_TRANSPARENCY = 0.25,
	RING_LIFT = 0.15, -- studs above the ground (no z-fighting)
	RING_FLASH_SECONDS = 0.3, -- the white flash as it lands, fading out
	RING_GROUND_RAY = 30, -- studs down from the ring's height to find the ground

	-- Hits
	-- Your swing freezes this long on a hit (hit-stop; sword-moves round): a cut, and the finisher or the dash slash
	HIT_STOP = { cut = 0.08, big = 0.12 },
	-- The finisher's hang (Swords cut `hang`): your camera eases in by `degrees` of field of view, then back in `back`
	-- seconds as the slam lands
	HANG_ZOOM = { degrees = 7, back = 0.12 },
	FADE = { strike = 0.04 }, -- seconds a cut or the skill blends in (Util/SwordAnims): snappy, no mushy start
	FLASH_SECONDS = 0.12, -- what you hit flashes white this long
	SPARKS = 14, -- sparks per sword hit
	SPARK_COLOR = rgb(255, 236, 170),
	SHAKE = { cut = { seconds = 0.08, studs = 0.12 }, skill = { seconds = 0.18, studs = 0.3 }, hurt = { seconds = 0.15, studs = 0.25 } },

	-- The candy sparkle arc on every swing (Util/HitFx.swingArc; sword-moves round), in the sword's slash colour
	-- (Config/Swords slash) with a white core: a circle of `radius` studs in the swing's plane, centred `up` and `ahead`
	-- of your root, the plane turned `yaw` and rolled `tilt` degrees about your forward axis (0: flat; 90: upright). It
	-- runs from `start` degrees (0 your right, 90 ahead, 180 your left, in the rolled plane) through `sweep` degrees
	-- (at most 180: one Beam), appears `from` seconds into the move, wipes along in `wipe` seconds and fades in `fade`.
	ARCS = {
		-- the forehand: high on the right, down across to low on the left
		cut1 = { tilt = 40, yaw = 0, radius = 4.2, start = -10, sweep = 150, up = 0.8, ahead = 0.6, from = 0.15, wipe = 0.1, fade = 0.2, width = 2.8 },
		-- the backhand: low on the left, rising out to the right
		cut2 = { tilt = 25, yaw = 0, radius = 4.2, start = 190, sweep = -170, up = 0.5, ahead = 0.6, from = 0.12, wipe = 0.1, fade = 0.2, width = 2.8 },
		-- the finisher: upright, from over your head down into the ground in front, as the fall from the hang starts
		cut3 = { tilt = 90, yaw = 0, radius = 4.4, start = -20, sweep = 170, up = 1.2, ahead = 1, from = 0.56, wipe = 0.12, fade = 0.28, width = 3.4 },
		-- the dash slash's draw: flat, from your left round to your right, as the dash ends
		skill = { tilt = 0, yaw = 0, radius = 5, start = 175, sweep = -170, up = 0.2, ahead = 0, from = 0.42, wipe = 0.1, fade = 0.3, width = 3.4 },
	},
	ARC_CORE = 0.4, -- the white core's width, a share of the arc's
	ARC_GLOW = 0.4, -- the coloured body's light emission: lower shows its pastel colour on bright ground (the core is 1)
	ARC_TRAIL = 0.65, -- the share of the arc lit behind the wipe's head
	ARC_SOFT = 0.04, -- the head's soft edge, a share of the arc
	ARC_STARS = { rate = 120, size = 0.55, life = { 0.3, 0.55 }, speed = { 1, 3 }, fall = 6 }, -- the stars it sheds
	-- A sword hit (BattleController / your own predicted hit): a star burst (`big` for the finisher and the dash slash)
	-- on the foe's side facing you (`share` of its radius out, `up` studs above your root), a ring snapping out on big
	-- hits, two crossing cut lines on each foe the dash slash hits, a dust puff where the finisher lands
	BURST = { size = 5, big = 7, seconds = 0.35, share = 0.7, up = 1 },
	-- A landed cut's impact in place of the star burst (owner 2026-11-08, picked in game from the free Yona VFX Pack,
	-- Creator Store 18170940328; Util/HitFx.impact): its Hit-01 (a white flash, sparks and a shockwave) and Golden-Sparks-01
	-- (a gold shockwave, specks, streaks flung out and a star), emitted once each at the burst point. The pack's own
	-- numbers, its sizes times the sword's slash scale (`big` more on the finisher and the dash slash). Textures are
	-- Config/AttackFx TEXTURES keys; sizes { time, studs, envelope }, transparency { time, value }, colour { r, g, b };
	-- flipbook: a 4x4 sheet played once over each particle's life (`fps`: the pack's framerate, `random`: start frame).
	IMPACT = {
		big = 1.35,
		seconds = 1.5, -- the holder lasts past the longest particle (1 s)
		emitters = {
			{ texture = "hitFlash", count = 3, lifetime = { 0.45, 0.45 }, size = { { 0, 4, 0 }, { 0.989, 3.812, 0 }, { 1, 4.5, 0 } }, transparency = { { 0, 1 }, { 0.035, 0 }, { 0.9, 0 }, { 1, 1 } }, color = { 255, 255, 255 }, brightness = 10, zOffset = 4, flipbook = { fps = 30 } },
			{ texture = "hitSparks", count = 12, lifetime = { 0.125, 0.25 }, size = { { 0, 0.25, 0 }, { 0.375, 3, 0 }, { 1, 3, 0 } }, transparency = { { 0, 1 }, { 0.25, 0 }, { 0.75, 0 }, { 1, 1 } }, color = { 255, 255, 255 }, brightness = 10, zOffset = 5, rotation = { -360, 360 }, flipbook = { fps = 45, random = true } },
			{ texture = "shockwave", count = 1, lifetime = { 1, 1 }, size = { { 0, 0.437, 0 }, { 0.497, 3.75, 0 }, { 1, 5.125, 0 } }, transparency = { { 0, 0 }, { 1, 0 } }, color = { 255, 255, 255 }, brightness = 10, zOffset = 3, rotation = { -360, 360 }, flipbook = { fps = 1 } },
			{ texture = "shockwave", count = 1, lifetime = { 1, 1 }, size = { { 0, 0.437, 0 }, { 0.497, 3.75, 0 }, { 1, 5.125, 0 } }, transparency = { { 0, 0 }, { 1, 0 } }, color = { 255, 235, 83 }, brightness = 10, zOffset = 3, rotation = { -360, 360 }, flipbook = { fps = 1 } },
			{ texture = "goldSpeck", count = 5, lifetime = { 0.25, 0.5 }, speed = { 10, 15 }, spread = { -360, 360 }, size = { { 0, 0.292, 0.25 }, { 1, 0, 0 } }, transparency = { { 0, 1 }, { 0.101, 0 }, { 1, 0 } }, color = { 255, 235, 83 }, brightness = 5, zOffset = 1, rotation = { -360, 360 }, drag = 1 },
			{ texture = "goldDot", count = 5, lifetime = { 0.2, 0.4 }, speed = { 12, 12 }, spread = { -360, 360 }, size = { { 0, 0, 0 }, { 1, 0.388, 0 } }, transparency = { { 0, 1 }, { 0.026, 0 }, { 0.802, 0 }, { 1, 1 } }, color = { 255, 235, 83 }, brightness = 5, zOffset = 1, rotation = { -360, 360 }, drag = 1 },
			{ texture = "goldStreak", count = 25, lifetime = { 0.5, 1 }, speed = { 25, 25 }, spread = { -180, 180 }, size = { { 0, 0.875, 0.875 }, { 1, 0, 0 } }, transparency = { { 0, 1 }, { 0.25, 0 }, { 1, 1 } }, color = { 255, 235, 83 }, brightness = 10, zOffset = 2, rotation = { -90, -90 }, fall = 10, drag = 5, alongFlight = true, squash = { { 0, 0.188, 1 }, { 1, -0.488, 1 } } },
			{ texture = "goldStar", count = 25, lifetime = { 0.25, 0.5 }, size = { { 0, 1.563, 0.125 }, { 1, 0.5, 0.125 } }, transparency = { { 0, 1 }, { 0.5, 0 }, { 1, 1 } }, color = { 255, 235, 83 }, brightness = 1, zOffset = 4, squash = { { 0, -1, 0 }, { 1, 0.487, 0 } } },
		},
	},
	-- The Magma Halberd's Eruption perk (weapons round 2): a lava burst and ring on the foe, on top of the extra hit's own
	ERUPT = { color = { 255, 120, 40 }, size = 9, ring = 10 },
	RING = { size = 10, seconds = 0.3 },
	CUT_LINES = { length = 8, width = 1.1, delay = 0.06, grow = 0.06, hold = 0.12, fade = 0.25, angle = 35 },
	DUST = { radius = 5, seconds = 0.4, puffs = 8, color = rgb(232, 222, 205) },

	-- The slash trail on your blade while a cut or the skill swings
	TRAIL_SECONDS = 0.35,
	TRAIL_LIFETIME = 0.16,
	TRAIL_COLOR = rgb(210, 235, 255),
	TRAIL_BLADE = { base = 0.8, tip = 4.3 }, -- studs up the blade from the grip
	-- a spear's head (weapons round 2): its bottom and tip over the grip (31% up the spear; measured on the four models:
	-- the heads start 2.4-3.0 studs up, the tips 5.9-6.4)
	TRAIL_BLADE_SPEAR = { base = 2.6, tip = 5.9 },
	-- Drawing your sword: a flash of light and a glint at the blade's tip
	GLEAM = { seconds = 0.3, brightness = 4, range = 8, size = 2.2, color = rgb(255, 250, 225) },

	-- The boss winding up: a quick hit flashes it red; a big attack rears it back (its roar pose) with an orange glow
	WINDUP_QUICK_COLOR = rgb(255, 70, 70),
	WINDUP_BIG_COLOR = rgb(255, 160, 60),
	WINDUP_FILL = 0.55, -- the glow's strongest (Highlight fill transparency)
}
