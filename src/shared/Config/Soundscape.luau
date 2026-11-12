--!strict
-- The worlds' soundscape (the owner 2026-11-11: "improve what you can improve in the worlds town/wilds/frontier, make it
-- more immersive"; SoundscapeController, Util/SoundscapeRules): on top of each area's one ambient loop (Config/Scenery
-- SOUNDS, WildValley / FrontierValley BIOMES' sound), small sounds now and then from somewhere round you (spots: birds
-- in the trees, a drip in the caves, a wolf far off in Frostwood), a night bed of crickets in town as the birds' loop
-- fades out, and gusts of wind through the town's trees (they bend harder, leaves blow past). All Pro Sound Effects.
-- Spots: `ids` picked at random, every `every` seconds (min, max), `distance` studs away in any direction and `height`
-- up, at `volume`, `pitch` (min, max) for variety; heard out to `range`. In town the `day` spots fade out and the `night`
-- ones in with the night (NIGHT: clock hours; SoundscapeRules.nightShare). Not in a boss arena.
export type Spot = {
	ids: { string },
	every: { number },
	distance: { number },
	height: { number },
	volume: number,
	pitch: { number },
	range: number,
}

local BIRDS = { "rbxassetid://9117236709", "rbxassetid://9117236946", "rbxassetid://9114891754" } -- Parakeet Chirps 4, 6; Jungle Bird 1
-- Cockatiel Bird Interior Whistling Chirps 1: measured 55 (peak 110) against the other birds' 17-29 (owner 2026-11-13:
-- "a really loud whistling bird in town. lower its volume"), so its own spot, at about the others' loudness and rarer
local WHISTLE = { "rbxassetid://9113844972" }
local OWLS = { "rbxassetid://9117181543", "rbxassetid://9117181035" } -- Owl Hooting Reverberant Dry Several 5, 1
local WINGS = { "rbxassetid://9116383749", "rbxassetid://9116383743" } -- Magical Wing Flutter Pass By 5, 6
-- one drop each (owner 2026-11-12: the Caves' "loud triple droplets" were Water Drips Into Filled Bowl clips of several)
local DRIPS = { "rbxassetid://9126183559", "rbxassetid://9126181980", "rbxassetid://9126178890" } -- Water Drip Distant Single Splattering Drops
local PEBBLES = { "rbxassetid://9117268152", "rbxassetid://9118689425" } -- Pebbles Movement 1; Rocks Knock Against Each Other 3
local BUBBLES = { "rbxassetid://9120310416", "rbxassetid://9120306743" } -- Underwater Bubbles Deeper Med Short Bursts 6; Underwater Bubbles 6 (pitched down: lava)
local ICE = { "rbxassetid://9114858761", "rbxassetid://9114858583" } -- Ice Cracks 2; Ice Crackle Large Block Cracks 1
local WOLVES = { "rbxassetid://9120790529", "rbxassetid://9120790553" } -- Wolf Howl Two Versions 1, 2
local WHISPERS = { "rbxassetid://9126213995", "rbxassetid://9126213744" } -- Whisper Bursts Eerie Unintelligible

local function spot(ids: { string }, every: { number }, distance: { number }, height: { number }, volume: number, pitch: { number }, range: number?): Spot
	return { ids = ids, every = every, distance = distance, height = height, volume = volume, pitch = pitch, range = range or 90 }
end

return {
	CHECK_EVERY = 0.25, -- seconds between looks at where you are
	NIGHT = { from = 18.3, full = 20, fade = 3.5, gone = 5.8 }, -- the town's clock: dusk, full night, dawn, day
	TOWN = {
		day = {
			spot(BIRDS, { 3, 7 }, { 18, 40 }, { 8, 20 }, 0.18, { 0.9, 1.15 }),
			spot(WHISTLE, { 20, 40 }, { 24, 45 }, { 10, 20 }, 0.06, { 0.95, 1.05 }),
			spot(WINGS, { 14, 26 }, { 10, 22 }, { 6, 14 }, 0.12, { 0.95, 1.1 }),
		},
		night = {
			spot(OWLS, { 14, 26 }, { 30, 60 }, { 12, 24 }, 0.16, { 0.95, 1.05 }, 120),
		},
		dayBed = "BirdsSound", -- Config/Scenery SOUNDS' birds (SceneryService names its holder "<name>Sound"): out at night
		nightBed = { id = "rbxassetid://9112764546", volume = 0.12 }, -- Crickets Night 1 (loop)
	},
	-- The Wild valley's biomes (Config/WildValley BIOMES): 1 the Meadow, 2 the Caves, 3 Ember Ridge
	WILD = {
		{
			spot(BIRDS, { 3, 6 }, { 18, 45 }, { 8, 22 }, 0.18, { 0.9, 1.2 }),
			spot(WHISTLE, { 20, 40 }, { 24, 50 }, { 10, 22 }, 0.06, { 0.95, 1.05 }),
			spot(WINGS, { 10, 20 }, { 10, 24 }, { 6, 16 }, 0.12, { 0.95, 1.1 }),
		},
		{
			spot(DRIPS, { 3, 7 }, { 8, 26 }, { 0, 6 }, 0.1, { 0.9, 1.1 }),
			spot(WINGS, { 16, 30 }, { 8, 20 }, { 6, 14 }, 0.12, { 1.2, 1.4 }), -- bats: the flutter, faster
		},
		{
			spot(BUBBLES, { 3, 7 }, { 12, 30 }, { 0, 2 }, 0.2, { 0.45, 0.6 }),
			spot(PEBBLES, { 10, 20 }, { 14, 32 }, { 2, 10 }, 0.16, { 0.85, 1.05 }),
		},
	},
	-- The Frontier valley's biomes (Config/FrontierValley BIOMES): 1 Frostwood, 2 Stormpeak, 3 the Rift (its lightning,
	-- rain and tremors are FrontierFxController's)
	-- The Dungeon (spec 2026-11-12-dungeon-atmosphere): drips, rubble, chains, whispers and crystal rings round you
	-- all the way down (one group: the whole cavern)
	DUNGEON = {
		spot(DRIPS, { 6, 12 }, { 10, 26 }, { 4, 14 }, 0.1, { 0.85, 1.05 }),
		spot(PEBBLES, { 14, 26 }, { 14, 34 }, { 6, 16 }, 0.14, { 0.7, 0.9 }),
		spot({ "rbxassetid://9113763252", "rbxassetid://9113763407" }, { 30, 55 }, { 20, 40 }, { 4, 12 }, 0.1, { 0.8, 0.95 }), -- Pro Sound Effects: Chain Rattle 2, 4
		spot(WHISPERS, { 35, 60 }, { 16, 30 }, { 2, 8 }, 0.07, { 0.85, 1 }),
		spot({ "rbxassetid://9116223893" }, { 20, 40 }, { 12, 28 }, { 2, 10 }, 0.06, { 1.4, 1.9 }), -- Large Metal Triangle hit, pitched up: a crystal ringing
	},
	FRONTIER = {
		{
			spot(ICE, { 9, 18 }, { 12, 30 }, { 0, 6 }, 0.18, { 0.9, 1.1 }),
			spot(WOLVES, { 26, 46 }, { 70, 110 }, { 10, 20 }, 0.12, { 0.95, 1.05 }, 160),
		},
		{
			spot(PEBBLES, { 8, 16 }, { 14, 32 }, { 2, 12 }, 0.16, { 0.8, 1 }),
		},
		{
			spot(WHISPERS, { 22, 40 }, { 14, 30 }, { 2, 8 }, 0.08, { 0.85, 1 }),
			spot(PEBBLES, { 12, 22 }, { 14, 30 }, { 0, 8 }, 0.14, { 0.7, 0.9 }),
		},
	},
	-- Gusts through the town (and the Meadow): now and then the wind picks up for `seconds` (in over `rise`, out over
	-- `fall`), the trees bend up to `sway` times as far, leaves blow past and the wind's rustle swells to `volume`
	GUST = {
		every = { 22, 45 },
		seconds = 5,
		rise = 1.2,
		fall = 1.8,
		sway = 2.6,
		sound = "rbxassetid://9116258071", -- Leaves Rustle Wind Blowing Through Trees 1 (a part of it, faded in and out)
		soundLength = 76,
		volume = 0.22,
		leaves = { rate = 14, speed = { 10, 16 }, size = 0.5 },
	},
}
