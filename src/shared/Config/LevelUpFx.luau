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
		},
		default = 1,
		maxVolume = 0.15,
		creature = { volumeScale = 0.6, pitch = 1.25 }, -- a creature plays its set's sound, quieter and higher
	} :: any,
	SPARK_WAIT = 4, -- seconds your own creature's level-up from a fight waits for its XP sparks to land, at most
}
