--!strict
-- The Dungeon (spec 2026-10-29-dungeon-final-boss-design.md): a third place reached from the Frontier's Dungeon
-- portal, one run per (reserved) server. A prism-crystal cavern along +X: the entrance hall, three sealed rooms of
-- elite packs, then the Prism Hydra's chamber (its arena, built by WildService.BuildBossArenas at CHAMBER). Creatures
-- keep their HP from room to room. Monsters come from the Frontier's species. Plain data so Lune tests can load it.
return {
	BOSS = "prismHydra", -- the chamber's boss (Config/Bosses)
	-- Each room: a pack of `count` elites at `level`, names cycled through `species` (mixed elements)
	ROOMS = {
		{ species = { "Frost Wisp", "Shade Lynx" }, count = 2, level = 45 },
		{ species = { "Storm Hawk", "Lava Brute" }, count = 2, level = 47 },
		-- Room 3 (spec 2026-11-11-dungeon-puzzles): its pack stands in a shield fed by `count` pylons the players break
		-- with their swords (BattleSim pylons; `hp` each, tuned with tools/balance/bosses: the shield down in about 15 s
		-- fought well); `atk` softens its pack (x PACK_SCALE.atk) for the hits the creatures take while it's shielded, so
		-- the Hydra is reached with about the HP it was before the pylons
		{ species = { "Rift Horror", "Prism Crab", "Lava Brute" }, count = 3, level = 50, pylons = { count = 3, hp = 900 }, atk = 0.55 }, -- 900 (was 450): harder, owner 2026-11-12; creatures can help (a pylon's prompt)
	},

	-- The run's order (owner 2026-11-11): each step opens the next; the Prism Hydra's chamber after the last
	STEPS = {
		{ kind = "fight", room = 1 },
		{ kind = "beams" },
		{ kind = "fight", room = 2 },
		{ kind = "plates" },
		{ kind = "fight", room = 3 },
		{ kind = "lock" },
	},
	-- The Hydra's welcome when the run opens (spec 2026-11-12-dungeon-atmosphere; DungeonIntroController): its beats'
	-- start times in seconds; the full one the first time ever, the short one after (DungeonRules.introKind)
	INTRO = {
		full = {
			{ at = 0, beat = "slam" }, -- the way back slams shut, dust
			{ at = 1.2, beat = "torches" }, -- the hall's braziers die one by one, the music starts
			{ at = 3, beat = "drift" }, -- the camera drifts into the dark
			{ at = 5, beat = "eyes" }, -- one pair of eyes opens, slowly (longer since 2026-11-12, the owner)
			{ at = 7.2, beat = "blink" }, -- it blinks
			{ at = 8.4, beat = "pairs" }, -- four more pairs, the heads' colours, one by one
			{ at = 10.6, beat = "look" }, -- the pupils narrow to slits on you, the heads lean in
			{ at = 11.8, beat = "roar" }, -- the eyes narrow, the roar, shake and dust
			{ at = 13.4, beat = "title" }, -- the eyes shut, the title, a heartbeat
			{ at = 15, beat = "end" },
		},
		short = {
			{ at = 0, beat = "pairs" },
			{ at = 1, beat = "roar" },
			{ at = 2.5, beat = "end" },
		},
		TITLE = "THE DUNGEON",
		SUBTITLE = "Something waits below...",
		EYES = { distance = 70, height = 22, spread = 30, size = 3.6 }, -- studs ahead of the hall, how high, how wide apart
		SHAKE = 0.6, -- studs the camera trembles at the roar
	},
	-- The hall's braziers (the welcome puts them out one by one, nearest first), from the hall's start
	HALL_BRAZIERS = { { x = 12, z = -11 }, { x = 12, z = 11 }, { x = 30, z = -11 }, { x = 30, z = 11 } },
	-- The objective (top right, plain text): each stage's line (ObjectiveRules); "pylons" is room 3 while one stands
	OBJECTIVES = {
		waiting = "Wait for your group",
		room = "Defeat the guardians",
		beams = "Lead the light to the prism",
		plates = "Hold every plate",
		pylons = "Break the crystal pylons",
		lock = "Strike the crystals in the door's order",
		boss = "Defeat the Prism Hydra",
		won = "Take the portal home",
		out = "You're out of the run",
		gather = "Gather on the puzzle island", -- the next puzzle waits for the whole group (owner 2026-11-12)
	},
	GATHER_MESSAGE = "The puzzle waits until your whole group is on its island.",
	-- A room's pack (DungeonService, DungeonRules.packSpots): spread this far round the ring's middle (room 3's round its
	-- shield's), rising out of the ground over `emerge` seconds with a burst of light (MonsterController)
	PACK_SPAWN = { radius = 18, shieldRadius = 5, emerge = 1.2, color = { 190, 120, 255 }, sound = "rbxassetid://9120732821" },
	-- Crystal clusters' variety (DungeonBuilder crystalCluster): their size, how often one is oversized, leans, has a
	-- smaller one beside it
	CRYSTAL_VARIETY = { normal = { 0.5, 1.3 }, big = { 1.8, 2.8 }, oversized = 0.15, leanChance = 0.45, lean = 35, pairChance = 0.3 },
	-- Gate seals and their pillars go see-through when the camera comes this close (a fight's camera behind the gate)
	CAMERA_FADE = { within = 26, amount = 0.85, every = 0.15 },
	-- A brazier's fire (DungeonBuilder torchFire): flames off its bowl, a few sparks, a gently flickering light
	TORCH = { flameTexture = "rbxasset://textures/particles/fire_main.dds", size = 1.6, lifetime = { 0.45, 0.8 }, rate = 28, speed = { 2.5, 4.5 }, sparks = 3, flicker = { every = 0.07, low = 1.1, high = 1.7 } },
	GATHER_TIMEOUT = 75, -- seconds, then it opens for whoever's there (one idle player never holds the rest)
	LAIR_MESSAGE = "The Hydra's door is open! Enter the castle's gate to its lair.",
	-- In a puzzle room (owner 2026-11-12): its name over the line and clues under it, the first at once, the next every
	-- CLUE_EVERY seconds on the stage (ObjectiveRules.hint). "{order}" is the lock's order (the Hydra's phases).
	OBJECTIVE_LABELS = {
		beams = "PUZZLE ROOM: PRISM BEAMS",
		plates = "PUZZLE ROOM: WEIGHT PLATES",
		lock = "PUZZLE ROOM: THE HYDRA'S LOCK",
		pylons = "SHIELD PYLONS",
		gather = "NEXT: A PUZZLE ROOM",
	},
	CLUES = {
		beams = {
			"Tap a crystal mirror to turn it.",
			"A mirror bends the beam to a side next to it.",
			"Follow the beam from the gem. Turn the mirror where it stops.",
		},
		plates = {
			"Stand on the glowing plates.",
			"Too few players? Send your creature onto a plate.",
			"Every plate must be held at once.",
			"Those glowing cracks in the wall... try your sword.",
		},
		lock = {
			"The order is shown over the Hydra's door.",
			"Strike the crystals in that order. A wrong one resets.",
			"The order: {order}.",
		},
		pylons = {
			"Swing your sword at the crystal pylons.",
			"Walk up to a pylon to send your creature at it.",
			"The shield falls when every pylon breaks.",
		},
	},
	CLUE_EVERY = 40,
	-- The danger all the way down (DungeonAmbienceController, AmbienceRules): distant roars, the Hydra's eyes glimpsed in
	-- the dark, the eerie music and its heartbeat near the chamber
	AMBIENCE = {
		roarEvery = { 50, 80 },
		roarVolume = { 0.08, 0.25 }, -- halved (owner 2026-11-12: "lower the roaring sound")
		roarShake = 0.15, -- studs
		glimpseEvery = { 90, 160 },
		glimpseSeconds = 1.6,
		glimpseDistance = { 45, 70 }, -- studs ahead of the player
		heartbeatFrom = 5, -- steps done before the heartbeat comes in (the lock)
		musicVolume = 0.07, -- the owner: lower, twice (2026-11-12; was 0.35, then 0.15)
		heartbeatVolume = 0.4,
		fightShare = 0.5, -- roars and music at this share during a fight
	},
	-- The welcome's and the danger's sounds (Pro Sound Effects; the music APM). Volumes are the sound's own.
	SOUNDS = {
		slam = { id = "rbxassetid://9125393362", volume = 0.8 }, -- Big Rocks Drop Interior Muffled Some Debris
		torchOut = { id = "rbxassetid://9114439212", volume = 0.35 }, -- Fire Whoosh 1
		breath = { id = "rbxassetid://9113586144", volume = 0.5, pitch = 0.6 }, -- Breath Exhale 17, slowed: something huge
		growl = { id = "rbxassetid://9125467848", volume = 0.45 }, -- Creature Growls Lion Deep Guttural Rumbling
		roar = { id = "rbxassetid://9113987603", volume = 0.4 }, -- Creature Vocal Giant Crab Monster Roars 1 (6.2 s); 0.9 before the owner's "lower the roaring sound"
		rubble = { id = "rbxassetid://9125391923", volume = 0.4 }, -- Big Rocks Drop Interior (dust after a roar)
		title = { id = "rbxassetid://9039689736", volume = 0.5 }, -- APM "Dark Matter": a distant threatening swell
		heartbeat = { id = "rbxassetid://9116329971", volume = 1 }, -- Low Tonal Throb 1 (35 s loop), the music's heartbeat layer
		music = { id = "rbxassetid://9040208531", volume = 1 }, -- APM "Majestic Power (e)": dark, moody, layered drone (118 s)
		chime = { id = "rbxassetid://9116223893", volume = 0.25, pitch = 1.6 }, -- the objective changing: a soft ring
		fall = { id = "rbxassetid://9125651408", volume = 0.5 }, -- a short yell as you go over (PSE, Male Scream Short)
		fallWind = { id = "rbxassetid://9114374625", volume = 0.6, pitch = 0.7 }, -- the rush of air past you (PSE, Fast Pass By)
	},
	-- The puzzles' sounds (owner 2026-11-12: "sounds to indicate what they're doing is right"; DungeonPuzzleService cue),
	-- all already in the game: Pro Sound Effects
	-- A Dungeon chest's opening (DungeonPuzzleController): its rattle (seconds, radians of shake), the light column's
	-- height, the reward card's title and how long it stays
	CHEST_REVEAL = { rattle = 0.7, shake = 0.08, column = 14, title = "Chest opened!", seconds = 3.5 },
	-- The cinematics (owner 2026-11-12; DungeonCinematicController): a puzzle's gate opening (the camera on it, the seal
	-- shatters at openAt, when the server opens it), and after the lock the way to the Hydra (the camera flies down the
	-- bridge to the castle gate, its five dragon heads' eyes light one by one from socketsAt, the door bursts open at
	-- openAt, the roar). Seconds; back / up: studs the camera stands behind the door (against the way through) and above
	-- it; aimUp: how high over the door's foot it looks (the heads sit high on the gate)
	CINEMATIC = {
		door = { seconds = 3.6, openAt = 1.6, back = 22, up = 8 },
		hydra = { seconds = 8, openAt = 4.8, roarAt = 5.3, from = { back = 70, up = 30 }, to = { back = 42, up = 16 }, aimUp = 20, fly = 3, socketsAt = 3.2, socketEvery = 0.25, shake = 0.5 },
	},
	-- The castle gate's five dragon heads (PortalDungeon's Eye1..5): dark until the Hydra's lock is solved, then lit one
	-- by one in the cinematic (owner 2026-11-12: "the hydra gate should light their eyes") in the portal's eye colours
	-- (Config/Town PORTAL_LOOKS.Dungeon.glow); `dark`: their colour until then
	HYDRA_EYES = { dark = { 34, 28, 48 } },
	PUZZLE_SOUNDS = {
		turn = { id = "rbxassetid://9118628895", volume = 0.35 }, -- Rock Impacts 11: a mirror grinds round
		closer = { id = "rbxassetid://9116394545", volume = 0.45 }, -- Magic Glows Soft Chiming Hits: the light went further
		lit = { id = "rbxassetid://9126073001", volume = 0.6 }, -- Synth Sparkle Ding: the prism lit
		plateOn = { id = "rbxassetid://9118608925", volume = 0.5, pitch = 1.1 }, -- Rock Hits Rock: a plate sinks
		plateOff = { id = "rbxassetid://9118608925", volume = 0.35, pitch = 0.8 }, -- the same, lower: it rises
		right = { id = "rbxassetid://9116224192", volume = 0.5 }, -- Large Metal Triangle hit: a right crystal (higher each time)
		wrong = { id = "rbxassetid://9119582950", volume = 0.3, pitch = 0.7 }, -- Static bursts, low: wrong, it resets
		solved = { id = "rbxassetid://9116385087", volume = 0.7 }, -- Magic Burst 5: the puzzle solved
		shatter = { id = "rbxassetid://9113966327", volume = 0.6, pitch = 1.3 }, -- Crash Wood Glass, quick: a seal breaks
		chestOpen = { id = "rbxassetid://9120881682", volume = 0.4 }, -- Wood Groan Creak Opening Wood Chest (1.1 s)
		-- your reward shows: one soft bell, 1.6 s (owner 2026-11-12: "subtle and short"; was a 3.3 s shimmer at 0.6)
		reward = { id = "rbxassetid://9126073318", volume = 0.22 }, -- PSE "Synth Sparkle Tone ... Bell Tone Ding 1"
	},
	-- The run line's names for the puzzle steps (DungeonController)
	STAGES = { beams = "Prism beams", plates = "Weight plates", lock = "Element lock" },
	-- What a puzzle step's toast says when it opens
	HINTS = {
		beams = "Turn the mirrors to lead the light to the door's prism!",
		plates = "Stand on a plate and send your creature to the other!",
		lock = "Strike the crystals in the order shown over the door!",
		pylons = "Break the crystal pylons with your sword: they shield the pack!", -- room 3's fight
	},

	-- Prism beams: tap a mirror ("Turn") and it turns a quarter; the beam from the gem must reach the door's prism.
	-- Grid cells are CELL studs; a layout's dir / facing: 0 +x, 1 +y, 2 -x, 3 -y (Util/BeamRules). One layout per run.
	BEAMS = {
		TURN_COOLDOWN = 0.4, -- seconds between one player's turns
		CELL = 8,
		-- Found by a search (one solution each, every mirror on the path, 6-9 taps from the start)
		LAYOUTS = {
			-- 7 taps, an 18-cell path
			{ width = 6, height = 5, gem = { x = 1, y = 3, dir = 0 }, prism = { x = 6, y = 1 }, mirrors = { { x = 1, y = 1, facing = 1 }, { x = 1, y = 4, facing = 2 }, { x = 5, y = 4, facing = 1 }, { x = 5, y = 3, facing = 3 } } },
			-- 9 taps, a 10-cell path
			{ width = 6, height = 5, gem = { x = 1, y = 1, dir = 0 }, prism = { x = 6, y = 5 }, mirrors = { { x = 3, y = 1, facing = 2 }, { x = 5, y = 5, facing = 1 }, { x = 5, y = 4, facing = 2 }, { x = 3, y = 4, facing = 2 } } },
			-- 6 taps, a 12-cell path
			{ width = 6, height = 5, gem = { x = 1, y = 5, dir = 0 }, prism = { x = 4, y = 1 }, mirrors = { { x = 1, y = 1, facing = 3 }, { x = 3, y = 5, facing = 1 }, { x = 3, y = 2, facing = 2 }, { x = 1, y = 2, facing = 2 } } },
		},
	},
	-- Weight plates: all pressed at once opens the door for good; SOLO plates for runs under GROUP_FROM players, else
	-- GROUP. SIZE: a plate's side (studs). Never more needed than the players left can cover (Util/PlateRules).
	PLATES = { CHECK_EVERY = 0.25, SOLO = 2, GROUP = 3, GROUP_FROM = 3, SIZE = 8 },
	-- Element lock: strike the crystals in the Hydra's phase order (Util/LockRules)
	LOCK = { STRIKE_COOLDOWN = 0.4 },
	-- The secret wall in the plate room: TAPS shared taps break it; its chest's first find ever gives TITLE, later finds
	-- MATERIAL at MATERIAL_CHANCE (a Hydra win: 80%, 1-2), else CASH
	SECRET = { TAPS = 3, TAP_COOLDOWN = 0.5, TITLE = "Seeker", MATERIAL = "material_prismHydra", MATERIAL_CHANCE = 0.25, CASH = 250 },
	-- The puzzle and secret chests: the boss chests' model WIDTH studs wide, opened from DISTANCE studs
	CHEST = { DISTANCE = 10, WIDTH = 4 },
	-- The fight rooms' monsters in the Dungeon: rainbow crystal shards on the back and a soft rainbow glow (client)
	CRYSTAL_LOOK = { shards = 4, glow = 0.25 },

	-- Pack monsters' elite stats (Frontier ELITE_HP_MULTIPLIER / ELITE_ATK_MULTIPLIER) times these: three rooms in a row
	-- with no healing. HP raised (0.21 to 0.27) when the players got their swords in every room (owner 2026-11-12) so the
	-- run stays as it was (`lune run tools/balance/bosses 200 1 7`: the Hydra reached every time, 73-86% HP left)
	PACK_SCALE = { hp = 0.27, atk = 0.33 },

	ARRIVAL_WAIT = 60, -- the rooms stay shut until every player has loaded; after this long a player who never came is left behind
	OUT_DELAY = 4, -- seconds before a player who is out goes back to the Frontier
	ROOM_INTRO_SECONDS = 3, -- the room seals, then the pack appears after this

	-- Layout (studs). The hall (the ledge) at ORIGIN; the way winds on along +X (ABYSS.ROUTE, Util/AbyssLayout) to the
	-- Hydra's castle; the Hydra's arena is in its lair at CHAMBER, its gate on its -X side.
	ORIGIN = { x = 0, y = 0, z = 0 },
	HALL = { length = 40, width = 26, height = 32 },
	ROOM_RADIUS = 40, -- the fight rings (28 before the owner's "arenas should be bigger", 2026-11-12)
	PACK_OFFSET = 8, -- the pack stands this far past a ring's centre (away from the gate)
	ENTRY_STEP = 16, -- members enter this far past a ring's gate (the camera behind them is inside, not in the gate)
	ROOM_LEASH = 42, -- a run fight's leash, from the ring's centre (RunOptions.leashCenter): the ring and its rim
	CORRIDOR_WIDTH = 14,
	-- The Hydra's arena in its lair (WildService buildRing's look, DungeonBuilder's gate and entrance): violet stone,
	-- glowing violet cracks, crystal-tipped posts, the boss's sign over its gate's seal
	LAIR_ARENA = {
		floor = { 58, 44, 84 }, floorMaterial = "Limestone", path = { 70, 56, 100 }, pathMaterial = "Cobblestone",
		post = { 72, 58, 104 }, postMaterial = "Cobblestone", postSize = 1.8, postHeight = 7, tip = { 190, 120, 255 },
		cracks = { seed = 77, count = 14, size = 46, width = { 0.4, 0.9 } },
		signHeight = 18,
		-- the way in: the portal you came through on the dome's wall, a causeway to the gate lined with braziers
		portalScale = 1.1, causewayWidth = 14, braziers = 4,
	},
	LAIR_PROMPT_DISTANCE = 14, -- the castle gate's Enter prompt (DungeonService.enterLair checks it again)
	CHAMBER = { x = 2200, y = 0, z = 0 }, -- the Hydra's lair, past the cave's east wall (ABYSS.LAIR; tests/AbyssLayout)
	-- The Crystal Abyss (spec 2026-11-12-dungeon-world; Util/AbyssLayout, DungeonBuilder): every step its own island
	-- over a bottomless chasm in a giant cave, bridges between them; falling in is death (out of the run)
	ABYSS = {
		-- Round 3 part 2 (spec docs/superpowers/specs/2026-11-12-abyss-regions-design.md): the way winds. Between two steps:
		-- straight out of one island to a small stop `lead` studs on, `middle` stops across the cave (each `swing` off the
		-- line, alternating), a stop straight in front of the next island, `between` studs of x from the first stop to
		-- the last; `z`: each step island's z, then the castle's (AbyssLayout.islands)
		ROUTE = { z = { 60, -50, 65, -55, 60, -45 }, castleZ = 0, lead = 30, between = 130, middle = 2, swing = 0, stopSize = { 11, 13 } },
		-- A fight room sits in a crater: its island reaches `outer`, a rock rim `height` tall round it from the ring's
		-- edge out, open `gap` degrees at its ways in and out (the room can't be seen from the path)
		CRATER = { outer = 50, height = 16, gap = 13 },
		-- The Hydra's castle at the end of the way (concept assets/blender/DungeonWorld/concept_castle.png): a square
		-- plateau `size` each side of its middle, its broken front wall `front` studs before its middle with the hydra gate
		-- (the PortalDungeon model at `gateScale`, the Hydra's door sealing it), walls and towers behind
		CASTLE = {
			size = 46, front = 18, wall = 6, wallHeight = { 16, 28 }, towers = { 34, 50 }, towerRadius = 7,
			gateScale = 1.3, gateWidth = 26, -- the PortalDungeon model's opening and frame, unscaled
			breach = { chance = 0.2, height = 0.6 }, -- a knocked-down wall piece: still over a jump (7 studs)
			-- the forecourt's dead (owner 2026-11-12: "this part of the entrance is empty. add large animal bones or
			-- adventurer bones"): props at x studs from the gate (out front is negative) and z from the castle's middle
			-- line, turned yaw degrees, tipped tilt, sunk sink studs, at scale; the walkway from the bridge stays open
			bones = {
				{ model = "DragonSkeleton", x = -14, z = -30, yaw = 90, scale = 1.5 },
				{ model = "TitanSkull", x = -12, z = 28, yaw = -120, scale = 0.9, sink = 1.5 },
				{ model = "Ribcage", x = -19, z = 36, yaw = 25, scale = 0.8, sink = 1 },
				{ model = "HornedSkull", x = -6, z = -17, yaw = 40, scale = 0.8, sink = 0.5 },
				{ model = "GiantSword", x = -20, z = 18, yaw = 60, tilt = 18, scale = 0.8, sink = 1 },
				{ model = "Bones", x = -5, z = 12, yaw = 20, scale = 1.3 },
				{ model = "Bones", x = -19, z = -13, yaw = 110, scale = 1.3 },
				{ model = "Bones", x = -23, z = 27, yaw = 200, scale = 1.2 },
				{ model = "Bones", x = -9, z = -40, yaw = 70, scale = 1.3 },
				{ model = "Bones", x = -15, z = 41, yaw = 140, scale = 1.1 },
			},
			portal = { height = 26 }, -- the solid slab in the gate (the door's height)
			-- the Blender castle's sizes (tools/blender/build_castle.py: x across, y back from its front wall), for the
			-- invisible blocks that make its walls and towers solid
			model = {
				gap = 15, wide = 44, deep = 62, wall = 5, wallTall = 22,
				towers = { { x = -18, y = 0.5, radius = 6 }, { x = 18, y = 0.5, radius = 6 }, { x = -44, y = 0, radius = 7 }, { x = 44, y = 0, radius = 7 }, { x = -44, y = 62, radius = 7 }, { x = 44, y = 62, radius = 7 } },
				-- where the model's pivot (split_pack puts it at the bottom centre of its bounds) sits from the gate (its
				-- Blender origin), in the model's own axes (+z behind the front); build_castle.py prints it after a rebuild
				pivot = { x = -1.09, y = -1.13, z = 31.55 },
			},
		},
		-- The Hydra's lair: a dome of rock `radius` round Dungeon.CHAMBER (past the cave's east wall, out of sight); the
		-- castle's portal takes the group there (DungeonService.EnterLair)
		LAIR = { radius = 95, wall = 30, carving = { reach = 58, scale = 2.5 } }, -- the Hydra's carving behind the arena
		-- Rock spires beside the way's turns (Terrain, floor to ceiling): their radius and how clear of the way they keep
		SPIRES = { radius = { 14, 19 }, clear = 8 },
		RIM = 2, -- a fight island reaches this far past its ring (the barrier sits at the edge)
		PUZZLE_HALF = 32, -- a puzzle island's half side
		LEDGE = { back = -12 }, -- the entrance ledge (square) from x back to HALL.length
		BRIDGE_WIDTH = 8,
		RAIL_HEIGHT = 1.5,
		UNDERSIDE = 34, -- how deep an island's rock hangs under its floor
		KILL_Y = -60, -- below this you have fallen
		CEILING_Y = 110,
		CAVE_HALF_WIDTH = 260,
		GLOW = { y = -70, every = 120, range = 60, brightness = 2, color = { 150, 90, 255 } }, -- dim lights deep down
		DOOR_RADIUS = 13, -- the Hydra's door
		FALL_MESSAGE = "You fell into the abyss.",
		FALL_FX_ABOVE = 20, -- the client's scream and fade start this far above KILL_Y
		FALL_CHECK = 0.25, -- seconds between the server's checks for fallen players
		-- Round 2 (owner 2026-11-12, concepts assets/blender/DungeonWorld/concept_arena_walls.png, concept_backdrop.png):
		-- a fight room's ring of broken walls (the props pack's DungeonWall, CrackedWall, DungeonPillarBroken), none within
		-- `gapOut` degrees of the way out or `gapIn` of the way in (its seal between two pillars); each piece `scale` times
		-- its size, sunk up to `sink` of its height, leaning up to `tilt` degrees, `radius` studs from the ring's middle.
		-- Behind them an invisible wall `wallHeight` tall in `wallSegment`-degree pieces: nobody walks in but through the
		-- Fight gate (owner 2026-11-12: "I should not be able to go to a room unless I fight"); its seal opens once cleared
		RUINS = { count = 16, gapOut = 28, gapIn = 14, scale = { 0.95, 1.15 }, sink = { 0, 0.35 }, tilt = 6, radius = 41, wallHeight = 16, wallSegment = 8 },
		-- The hydra seal across a closed gate (the DungeonSigil standing up, `size` across; DungeonBuilder.hide opens it)
		SEAL = { size = 11, height = 7.5, pillarScale = 0.75, pillarApart = 15, light = 14 },
		-- The rock columns under a gate's posts, down into the chasm (Terrain), so nothing floats
		COLUMN = { radius = 2.2, depth = 30, apart = 16, landing = 8 }, -- landing: the stone under the gate, studs along the bridge
		GATE_WING = { reach = 14, above = 8 }, -- invisible walls past a gate's ends over the chasm (no jumping round it): studs out, studs over its top
		LOCK_SEAL = { x = 12, z = -22 }, -- the lock island's Hydra seal with the order (studs from its middle), facing it
		GATE_HALF = 11.5, -- an island gate's barrier and landing, each side of the bridge's middle (its posts on the landing)
		-- The far scenery (AbyssLayout.backdrop): giant crystals on the side walls, far islands, falls of light into the
		-- chasm, giant hydra carvings (the Hydra's door, scaled up); everything at |z| >= band[1], the path far from it
		BACKDROP = {
			band = { 150, 245 }, -- |z| from the cave's middle line: past the winding way's widest swing
			crystals = 18, crystalScale = { 4, 8 },
			islands = 8, islandSize = { 10, 20 }, islandY = { -30, 35 },
			falls = 6, fallWidth = { 6, 12 },
			reliefs = 3, reliefScale = 3,
			lights = 6, -- PointLights on the brightest crystals (no more: perf)
			colors = { { 150, 90, 255 }, { 80, 220, 255 }, { 255, 110, 210 } },
			-- the cave's haze: the dark reads as violet depth instead of black
			haze = { offset = 0.1, color = { 70, 45, 110 }, decay = { 35, 22, 60 }, glare = 0, haze = 1.8 }, -- density: LIGHTING
		},
	},
	-- The regions (owner 2026-11-12: "different regions per room"), one per Hydra head: each step's island and the stops
	-- on the way to it take its step's region, the ledge the first one's, the castle CASTLE_REGION. A region's Terrain
	-- (top and rock: each material is the region's own, Terrain colours are per material), its crystals, its light
	-- falls, its haze (DungeonRegionController blends to it as you walk in) and an accent (mist, flicker, embers, motes)
	REGION_OF_STEP = { "Tide", "Tide", "Volt", "Volt", "Ember", "Ember" },
	CASTLE_REGION = "Shade",
	REGIONS = {
		Tide = {
			top = "Glacier", topColor = { 104, 150, 178 }, rock = "Sandstone", rockColor = { 38, 62, 84 },
			crystals = { { 110, 220, 255 }, { 150, 200, 255 }, { 90, 255, 220 } }, fall = { 110, 210, 255 },
			haze = { color = { 50, 80, 120 }, decay = { 20, 40, 70 } }, accent = "mist",
		},
		Volt = {
			top = "Slate", topColor = { 70, 72, 96 }, rock = "Pavement", rockColor = { 44, 44, 62 },
			crystals = { { 255, 220, 80 }, { 255, 240, 150 }, { 180, 160, 255 } }, fall = { 255, 225, 110 },
			haze = { color = { 80, 70, 60 }, decay = { 40, 34, 50 } }, accent = "flicker",
		},
		Ember = {
			top = "Basalt", topColor = { 52, 36, 36 }, rock = "CrackedLava", rockColor = { 255, 96, 40 },
			crystals = { { 255, 120, 60 }, { 255, 70, 50 }, { 255, 180, 90 } }, fall = { 255, 120, 60 },
			haze = { color = { 110, 45, 35 }, decay = { 60, 22, 18 } }, accent = "embers",
		},
		Shade = {
			top = "Limestone", topColor = { 100, 74, 140 }, rock = "Cobblestone", rockColor = { 86, 70, 112 }, -- Cobblestone: the castle reads as built stone
			crystals = { { 190, 110, 255 }, { 120, 255, 160 }, { 255, 120, 220 } }, fall = { 190, 120, 255 },
			haze = { color = { 70, 45, 110 }, decay = { 35, 22, 60 } }, accent = "motes",
		},
	},
	-- The puzzle rooms' pieces (DungeonBuilder; offsets in studs from the room's centre, z across the cavern)
	PUZZLE = {
		-- the beam puzzle's target prism, made to stand out (owner 2026-11-12): bigger, a column of light, a glow, a label
		TARGET = { scale = 1.6, color = { 255, 225, 140 }, column = 45, width = 3, light = 24, labelHeight = 9, labelDistance = 140, text = "Light this prism!" },
		LENGTH = 64,
		PLATES = { { x = -14, z = -12 }, { x = 14, z = -12 }, { x = 0, z = 14 } }, -- the third only for runs of 3-4
		ALCOVE = { z = 34, depth = 12, width = 14 }, -- the secret niche on the plate room's +z side, its cracked wall at z
		LOCK_LAYOUT = { "Bloom", "Ember", "Tide", "Shade", "Volt" }, -- the lock's crystals across the room (not the door's order)
		LOCK_SPACING = 9,
		PYLON_RADIUS = 20, -- room 3's pylons round the ring's centre
		PYLON_HIT_RADIUS = 2.5, -- a pylon's size for sword hits
		-- each pylon's prompt sending your creature at it, like the plates' (owner 2026-11-12: "make the crystal
		-- interactable so my pet will start attacking it"; made on each fighter's client, BattleController): its reach, the
		-- server's extra slack (lag), its texts
		PYLON_PROMPT = { distance = 12, slack = 6, send = "Send creature", back = "Call creature back", object = "Crystal pylon" },
		PYLON_BROKEN = 0.85, -- a broken pylon's transparency
		SHIELD_RADIUS = 9, -- the shield round its pack
		SHIELD_UP = 0.55, -- the shield's transparency while it stands
		SHIELD_FLICKER = 0.15, -- seconds the shield flickers when a pylon breaks
		SHIELD_SHATTER = 0.35, -- seconds the shield bursts outward and fades when the last one breaks
		BEAM_WIDTH = 0.6, -- each standing pylon's beam into the shield
		BEAM_HEIGHT = 3.5,
	},
	-- The element of each COLORS.CRYSTALS entry, in order
	ELEMENTS = { "Ember", "Tide", "Bloom", "Volt", "Shade" },
	WALL_HEIGHT = 30,

	COLORS = {
		FLOOR = { 46, 40, 62 },
		WALL = { 34, 29, 48 },
		DOOR = { 120, 90, 200 },
		CRYSTALS = { { 255, 120, 80 }, { 90, 170, 255 }, { 120, 220, 110 }, { 255, 220, 90 }, { 170, 100, 230 } }, -- the five elements
	},
	LIGHTING = { ambient = { 150, 138, 190 }, outdoorAmbient = { 130, 118, 175 }, brightness = 3, clockTime = 0, fogColor = { 18, 10, 32 }, fogEnd = 300, atmosphereDensity = 0.42 }, -- thicker since 2026-11-12 (the danger round)
}
