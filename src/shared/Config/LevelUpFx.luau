--!strict
-- The level-up pillar (spec 2026-11-04-round4-design section 9; owner's pick 2026-11-04: the light pillar and the
-- spinning circle, no rays, confetti or ground ring): textures rendered in Blender (tools/blender/build_levelup_fx.py,
-- tools/textures/make_levelup_fx.py, sources assets/ui/fx-levelup) and uploaded, white so they tint. Sounds are
-- Roblox-licensed (Pro Sound Effects, APM Music); in Studio "/levelsound <rise|beam|chime|fanfare> <n> [volume]"
-- (or the admin panel) tries option n of a moment until "/levelsound <moment> 0". Plain data (Lune-tested:
-- tests/LevelUpFxConfig.spec).
export type Sound = { id: string, volume: number, pitch: number }
export type Option = { name: string, id: string, volume: number, pitch: number }

return {
	IMAGES = {
		rune = "rbxassetid://116932502368636", -- the magic circle (rings, diamonds and dots, a sunburst and a sparkle)
		beam = "rbxassetid://136647385378986", -- a soft column of light with streaks (its height runs along the beam)
		mote = "rbxassetid://94350825263791", -- a soft four-point sparkle
	},
	RANGE = 60, -- studs: other players closer than this to your camera see and hear your level-up
	HOLD_CHECK_SECONDS = 0.5, -- how often the server sends shop level-ups that waited for a fight to end
	-- After a boss fight a held level-up also waits out its end screen: the victory screen (Config/Victory SECONDS), or
	-- the defeat countdown (Combat.LOSS_COUNTDOWN) and the trip home
	AFTER_BOSS = { win = 6, lose = 8 },
	-- Seconds from the start: the circle opens at 0, the pillar shoots up at `beam`, the badge pops at `badge`, the
	-- beam thins and the circle fades from `fade`, everything is gone at `done`
	TIMING = { beam = 0.4, badge = 1.0, fade = 1.5, done = 3 },
	SIZES = {
		shop = { rune = 9, beamHeight = 16, beamWidth = 5, core = 1.4 }, -- studs
		creature = { rune = 6, beamHeight = 11, beamWidth = 3.4, core = 1 },
	},
	COLORS = {
		gold = { { 255, 226, 120 }, { 255, 246, 200 } }, -- the glow, bottom to top
		rainbow = { "pink", "butter", "mint", "sky", "lilac" }, -- every 10th level, bottom to top (BabyColors names)
		rune = { 255, 216, 90 },
		runeMilestone = { { 255, 201, 63 }, { 79, 180, 255 } }, -- the two-toned circle of a 10th level
	},
	-- One soft sound per level-up (round 5, spec 2026-11-04-round5-design section 7; owner: round 4's four stacked sounds
	-- were "too loud, too much"), when the badge pops; a 10th shop level adds its sting. Three sets of licensed PSE / APM
	-- sounds to pick in Studio ("/levelsound <1-3> [volume]", the Admin panel's "Level sound" buttons; the attribute
	-- LevelSoundSet); `default` plays otherwise. Volumes about half of round 4's loudest, under maxVolume.
	SOUNDS = {
		sets = {
			{
				name = "Soft sparkle ping",
				sound = { id = "rbxassetid://9126076030", volume = 0.07, pitch = 1 }, -- PSE "Synth Sparkle Tone High Pitch Tone Burst Ping 4"
				sting = { id = "rbxassetid://9047103106", volume = 0.12, pitch = 1 }, -- APM "All It Takes Sting 2"
			},
			{
				name = "Bright bell ding",
				sound = { id = "rbxassetid://9126073001", volume = 0.07, pitch = 1.1 }, -- PSE "Synth Sparkle Tone High Pitch Bell Tone Ding 4"
				sting = { id = "rbxassetid://9047103106", volume = 0.12, pitch = 1 }, -- APM "All It Takes Sting 2"
			},
			{
				name = "Twirling chime",
				sound = { id = "rbxassetid://9125644676", volume = 0.06, pitch = 1 }, -- PSE "Magic Twirling Small High Pitch Spinning Chime 1"
				sting = { id = "rbxassetid://1839881844", volume = 0.1, pitch = 1 }, -- APM "Spinning Around (b)", a 2 s lively link
			},
			-- Owner 2026-11-16: "in addition to the visual effect on shop level up. add a satisfying immersive sound
			-- effect": a rise winding up before the badge pops (`at`: seconds from the pop), a bright game chime on it, a
			-- shimmer trailing off
			{
				name = "Power-up fanfare",
				sound = { id = "rbxassetid://9125446706", volume = 0.3, pitch = 1 }, -- PSE "Computer Melody Melodic Blitz Electronic Game" (bright, dazzling)
				sting = { id = "rbxassetid://9047103106", volume = 0.2, pitch = 1 }, -- APM "All It Takes Sting 2"
				layers = {
					{ id = "rbxassetid://9119816546", volume = 0.2, pitch = 1, at = -1.1 }, -- PSE "Synth Power Up Multi Tone Wind Ups Rise 2"
					{ id = "rbxassetid://9116394876", volume = 0.22, pitch = 1, at = 0.05 }, -- PSE "Magic Glows Soft Clusters Of Chiming Hits 2"
				},
			},
		},
		default = 4,
		maxVolume = 0.35,
		creature = { volumeScale = 0.85, pitch = 1.2 }, -- a creature plays its set's sound, a little quieter and higher
	} :: any,
	-- A creature's level-up glows on it for a while (owner 2026-11-16: "it should be noticeable. pets should glow for some
	-- time"): a golden fill pulsing between `low` and `high` transparency `pulseSpeed` times a second, a white outline,
	-- fading out over its last `fade` seconds
	CREATURE_GLOW = { seconds = 3.5, fill = { 255, 220, 110 }, outline = { 255, 255, 255 }, low = 0.35, high = 0.75, pulseSpeed = 1.6, fade = 1 },
	-- A creature's level chip over it (owner 2026-11-17: "make that bubble more immersive. add designs/animations", mockup
	-- B "Level chip"): a white pill edged `edge` studs in the creature's element colour with its element's icon, the old
	-- level muted, three arrows lighting one after another (`arrows`: seconds after it pops at TIMING.badge), the new
	-- level popping in big and gold (`newLevel`), a "+1" floating up (`plus`), a shine sweeping across (`shine`, over
	-- `shineSeconds`), sparkles twinkling (`sparkles`) and a gold LEVEL UP! tab on top. `size` in studs (width,
	-- height). It stays `hold` seconds after it pops, then rises `rise` studs as it fades over `fade`.
	CHIP = {
		size = { 6.4, 2.4 },
		edge = 0.13,
		arrows = { 0.3, 0.4, 0.5 },
		newLevel = 0.62,
		plus = 0.72,
		shine = 1.0,
		shineSeconds = 0.6,
		sparkles = { 0.6, 0.78 },
		hold = 2.8,
		fade = 0.5,
		rise = 0.8,
	},
	SPARK_WAIT = 4, -- seconds your own creature's level-up from a fight waits for its XP sparks to land, at most
	-- The middle card after your own shop's pillar (owner 2026-11-16: "there should be some sort of reward every level
	-- up ... and an immersive notification at the center of the screen"; mockup picked): "LEVEL UP!" on a lilac ribbon,
	-- the level in a gold badge, what it gave (the cash every level, the gift every 5th: Config/Levels), what it
	-- unlocked and any title it earned (Util/LevelUpCard). It pops in `delay` seconds into the pillar, its gifts one
	-- after another `stagger` apart with `sound`, over soft turning rays; it closes on its button or after `seconds`.
	-- Pixels at a REFERENCE-sized screen, scaled to the real one between `minScale` and `maxScale`.
	CARD = {
		delay = 2.2,
		seconds = 7,
		stagger = 0.16,
		reference = { 900, 560 },
		minScale = 0.62,
		maxScale = 1.25,
		width = 460,
		chip = { 94, 96 }, -- a gift's chip: width, height (four to a row)
		dim = 0.55, -- the screen behind it
		rays = "rbxassetid://139701534930046", -- Config/PackFx IMAGES.rays
		raysSize = 720,
		raysTurnSeconds = 18,
		sound = { id = "rbxassetid://9117841338", volume = 0.3 }, -- PSE "Pop Airy 1", once as the gifts land
		colors = {
			cardTop = { 255, 246, 255 },
			cardBottom = { 241, 230, 255 },
			shadow = { 139, 102, 217 },
			ribbonTop = { 190, 160, 244 },
			ribbonBottom = { 139, 102, 217 },
			outline = { 58, 29, 92 },
			badgeTop = { 255, 236, 160 },
			badgeBottom = { 214, 140, 24 },
			badgeOutline = { 138, 90, 0 },
			chipEdge = { 201, 179, 242 },
			chipNew = { 255, 211, 107 },
			words = { 58, 29, 92 },
			soft = { 109, 90, 150 },
			button = { 87, 211, 154 },
		},
	},
}
