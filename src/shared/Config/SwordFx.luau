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
	-- A landed cut's impact in place of the star burst (owner 2026-11-08, picked in game from free Creator Store packs:
	-- "make it look exactly like these"; Util/HitFx.impact): the slash streaks of the Euphoric Games VFX Pack's
	-- (112672322113504) Slash-Impact-01 (a streak facing you, specks flung left and right) and the Yona VFX Pack's
	-- (18170940328) Slash-01 (the same specks, counted twice here; a flat arc, a big stretched streak, sparks into the
	-- foe), emitted once each at the burst point from a holder standing level and turned to face your camera
	-- (SwordArcRules.impactFacing), as in the test the owner picked from. The test burst them back to back, layering the
	-- arcs: `echo` bursts them again `after` seconds later, `share` of the counts. In the weapon's colour with a white
	-- core ("update the effect colours based on weapon elements"), the element's particles on top (ELEMENT_HIT). The
	-- packs' own numbers, sizes and speeds times the sword's slash scale and the foe's size (`bySize`), `big` more on the
	-- finisher and the dash slash. Emitters as Util/PackEmitter reads them: textures are Config/AttackFx TEXTURES keys;
	-- sizes { time, studs, envelope }, transparency { time, value }, colour { r, g, b } or "tint" (the weapon's colour,
	-- `whiten` of the way to white); flipbook: a 4x4 sheet played once over each particle's life; `direction`: the
	-- holder's face it flies from (Front: toward your camera; default Top); `facing`: camera (default), perpendicular
	-- (faces its flight: a flat streak) or parallel (stretched along its flight); `accel` { x, y, z } in studs a second
	-- squared.
	IMPACT = {
		big = 1.35,
		seconds = 1.5, -- the holder lasts past the longest particle (1 s) and the echo
		echo = { after = 0.12, share = 0.5 },
		-- sized to what was hit (SwordArcRules.impactScale; the ring and cut lines too): a 5-stud body at the packs' size
		bySize = { reference = 5, power = 0.85, min = 0.7, max = 4 },
		emitters = {
			{ texture = "slashStreak", count = 10, lifetime = { 0.4, 0.4 }, speed = { 0.001, 0.001 }, spread = { 3, 3 }, size = { { 0, 2, 0 }, { 1, 2, 0 } }, transparency = { { 0, 1 }, { 0.1, 0 }, { 1, 0 } }, color = "tint", whiten = 0.15, brightness = 5, zOffset = 1, rotation = { 88, 92 }, direction = "Front", facing = "perpendicular", flipbook = {} },
			{ texture = "slashStreak", count = 20, lifetime = { 0.4, 0.4 }, speed = { 10, 10 }, spread = { 5, 0 }, size = { { 0, 0, 0 }, { 1, 2.67, 0 } }, transparency = { { 0, 1 }, { 0.499, 0 }, { 1, 1 } }, color = "tint", whiten = 0.15, brightness = 5, zOffset = 1, rotation = { 85, 95 }, accel = { 0, 0, -10 }, direction = "Right", facing = "parallel", flipbook = {} },
			{ texture = "slashStreak", count = 20, lifetime = { 0.4, 0.4 }, speed = { 10, 10 }, spread = { 5, 0 }, size = { { 0, 0, 0 }, { 1, 2.67, 0 } }, transparency = { { 0, 1 }, { 0.499, 0 }, { 1, 1 } }, color = "tint", whiten = 0.15, brightness = 5, zOffset = 1, rotation = { 85, 95 }, accel = { 0, 0, -10 }, direction = "Left", facing = "parallel", flipbook = {} },
			{ texture = "slashArc", count = 5, lifetime = { 0.4, 0.4 }, speed = { 0.001, 0.001 }, spread = { 5, 5 }, size = { { 0, 5, 0 }, { 1, 5, 0 } }, transparency = { { 0, 1 }, { 0.293, 1 }, { 0.5, 0 }, { 0.612, 0 }, { 1, 1 } }, color = "tint", whiten = 0.15, brightness = 10, zOffset = 0, rotation = { -100, -100 }, direction = "Bottom", facing = "perpendicular", flipbook = {} },
			{ texture = "slashStreak", count = 10, lifetime = { 0.4, 0.4 }, speed = { 0.001, 0.001 }, spread = { 3, 3 }, size = { { 0, 6, 0 }, { 1, 6, 0 } }, transparency = { { 0, 1 }, { 0.1, 0 }, { 1, 0 } }, color = "tint", whiten = 0.15, brightness = 5, zOffset = 1, rotation = { 88, 92 }, direction = "Front", facing = "perpendicular", squash = { { 0, 0, 0 }, { 1, 2.1, 0 } }, flipbook = {} },
			{ texture = "sparkStreak", count = 25, lifetime = { 0.5, 1 }, speed = { 25, 25 }, spread = { 100, 100 }, size = { { 0, 0.875, 0.875 }, { 1, 0, 0 } }, transparency = { { 0, 1 }, { 0.25, 0 }, { 1, 1 } }, color = "tint", whiten = 0.05, brightness = 10, zOffset = 2, rotation = { -90, -90 }, accel = { 10, -10, 0 }, drag = 5, direction = "Back", facing = "parallel", squash = { { 0, 0.188, 1 }, { 1, -0.488, 1 } } },
		},
	},
	-- Each element's own particles on a sword hit, on top of the slash streaks (owner 2026-11-08: "update the effect
	-- colours/particles based on weapon elements"; WeaponLookRules.hitElement; the Prism Blade's any of the five): Ember
	-- flames licking up and embers, Tide droplets thrown up and falling and a splash ring, Bloom leaves tumbling and
	-- motes, Volt crackling streaks and a flicker, Shade dark wisps and violet sparks. Emitters as IMPACT's (`tint`: the
	-- weapon's colour), sized with the hit.
	ELEMENT_HIT = {
		Ember = {
			{ texture = "flame", count = 13, lifetime = { 0.35, 0.6 }, speed = { 4, 9 }, spread = { 60, 60 }, size = { { 0, 1.44, 0.32 }, { 1, 0.32, 0 } }, transparency = { { 0, 0.2 }, { 1, 1 } }, color = "tint", brightness = 2, rotation = { -180, 180 }, accel = { 0, 10, 0 }, drag = 2 },
			{ texture = "spark", count = 26, lifetime = { 0.4, 0.8 }, speed = { 10, 20 }, spread = { 180, 180 }, size = { { 0, 0.56, 0 }, { 1, 0, 0 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = "tint", whiten = 0.4, brightness = 4, accel = { 0, 6, 0 }, drag = 3 },
		},
		Tide = {
			{ texture = "raindrop", count = 23, lifetime = { 0.4, 0.7 }, speed = { 10, 18 }, spread = { 70, 70 }, size = { { 0, 0.72, 0 }, { 1, 0.4, 0 } }, transparency = { { 0, 0 }, { 0.8, 0 }, { 1, 1 } }, color = "tint", whiten = 0.3, brightness = 2, accel = { 0, -35, 0 }, facing = "parallel" },
			{ texture = "ring", count = 2, lifetime = { 0.35, 0.35 }, speed = { 0.001, 0.001 }, size = { { 0, 0.8, 0 }, { 1, 6.4, 0 } }, transparency = { { 0, 0.2 }, { 1, 1 } }, color = "tint", whiten = 0.2, brightness = 2, direction = "Front", facing = "perpendicular" },
		},
		Bloom = {
			{ texture = "shard", count = 20, lifetime = { 0.6, 1 }, speed = { 8, 14 }, spread = { 180, 180 }, size = { { 0, 0.8, 0.16 }, { 1, 0.48, 0 } }, transparency = { { 0, 0 }, { 0.8, 0 }, { 1, 1 } }, color = "tint", brightness = 1.5, rotation = { -180, 180 }, rotSpeed = { -300, 300 }, accel = { 0, -6, 0 }, drag = 3 },
			{ texture = "glow", count = 7, lifetime = { 0.6, 1 }, speed = { 2, 5 }, spread = { 180, 180 }, size = { { 0, 0.64, 0 }, { 1, 0, 0 } }, transparency = { { 0, 0.3 }, { 1, 1 } }, color = "tint", whiten = 0.4, brightness = 2, accel = { 0, 4, 0 } },
		},
		Volt = {
			{ texture = "streak", count = 16, lifetime = { 0.1, 0.2 }, speed = { 30, 45 }, spread = { 180, 180 }, size = { { 0, 0.96, 0 }, { 1, 0.16, 0 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = "tint", whiten = 0.3, brightness = 6, facing = "parallel" },
			{ texture = "flare", count = 4, lifetime = { 0.15, 0.15 }, size = { { 0, 3.2, 0 }, { 1, 4.8, 0 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = "tint", whiten = 0.3, brightness = 4, rotation = { -180, 180 } },
		},
		Shade = {
			{ texture = "smoke", count = 13, lifetime = { 0.6, 1 }, speed = { 3, 6 }, spread = { 180, 180 }, size = { { 0, 1.28, 0 }, { 1, 2.88, 0 } }, transparency = { { 0, 0.4 }, { 1, 1 } }, color = "tint", emission = 0.3, brightness = 1, rotation = { -180, 180 }, rotSpeed = { -60, 60 }, accel = { 0, 2, 0 }, drag = 2 },
			{ texture = "spark", count = 16, lifetime = { 0.3, 0.6 }, speed = { 6, 12 }, spread = { 180, 180 }, size = { { 0, 0.48, 0 }, { 1, 0, 0 } }, transparency = { { 0, 0 }, { 1, 1 } }, color = "tint", whiten = 0.3, brightness = 3, drag = 2 },
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
