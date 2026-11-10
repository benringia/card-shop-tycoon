--!strict
-- Background music (MusicController, Util/MusicRules): the town, the Wild valley's three areas and its three boss
-- arenas. Each place: its `key` (Studio: "/music <key> <n> [volume]" plays option n anywhere, "/music <key> 0" goes back
-- to the picked tracks; "/music <n>" is the town's), the `tracks` it plays, the `options` to pick them from and its
-- `volume`, a `compressor` evening out its louder parts (with `makeup` dB given back; MusicController) and, for the
-- Wild valley's areas, an `ambient` loop under it. Plain data (Lune-tested).

-- APM pieces (Roblox-licensed) to choose from, by name
local function option(name: string, id: string): { name: string, id: string }
	return { name = name, id = `rbxassetid://{id}` }
end

-- The Wild's leveler (owner 2026-11-04: each piece "with leveler"): measured in Studio with Sound.PlaybackLoudness,
-- it keeps a piece's average where the owner heard it (Enchanted Kingdom at 0.2: 104 before, 107 after; Lair of the
-- Wizard 93, 94) and cuts its peaks (201 to 126, 214 to 124; Giant's Grave 310 to 132). The town's limiter (-48.5 dB,
-- ratio 20, no makeup) would crush these to a whisper (88 to 2).
local LEVELER = { threshold = -20, ratio = 6, attack = 0.02, release = 0.5, makeup = 7 }

return {
	-- The town (owner 2026-11-04: subtle and gentle, under the birds, wind and waterfall of Config/Scenery SOUNDS): soft
	-- APM pieces (Roblox-licensed) taking turns with a little quiet between them. It fades out when you leave the town
	-- (the Wild valley, a boss arena) and back in when you return.
	TOWN = {
		key = "town",
		-- What plays: the owner's pick from `options` (Studio: "/music <n> [volume]" plays option n over the ambience,
		-- "/music 0" goes back to these)
		tracks = {
			"rbxassetid://9048757009", -- "White Owl" (bells and piano; the owner's pick, 2026-11-04, after Drifting Into Dreamland)
		},
		-- Soft APM pieces to choose from (owner 2026-11-04: the first pick overpowered the ambience)
		options = {
			{ name = "White Owl (bells and piano)", id = "rbxassetid://9048757009" },
			{ name = "Wistful Wonderings (guitar and harmonium)", id = "rbxassetid://9043424638" },
			{ name = "Soft Tranquility (sparse)", id = "rbxassetid://105460275738508" },
			{ name = "Drifting Into Dreamland (underscore)", id = "rbxassetid://83889171451910" },
			{ name = "Lakefront Days (ukulele underscore, the first pick)", id = "rbxassetid://9038622066" },
		},
		-- The owner's number (2026-11-04, with White Owl): 0.18, down from 0.21. Before: 0.12 overpowered the birds, wind
		-- and waterfall (with the first, louder track); 0.013, 0.022, 0.045 and 0.07 too low. Try others with
		-- "/music 4 <volume>".
		volume = 0.18,
		-- A CompressorSoundEffect on the music as a limiter: the track swells in its later parts (owner 2026-11-03: "too
		-- loud, specially on later parts"), so above the threshold it barely grows (ratio 20). Round 5 kept the threshold,
		-- so the loudest part rises with the volume (tests/MusicRules).
		compressor = { threshold = -48.5, ratio = 20, attack = 0.02, release = 0.5 },
		fade = 3, -- seconds to fade in or out
		gap = 6, -- seconds of quiet between tracks
		margin = 40, -- studs past the island's edge that still count as town
		checkEvery = 0.5, -- seconds between checks of where you are
	},

	-- The pack opening (owner 2026-11-10: "change the music on this screen. too plain"): its own piece while the opening
	-- shows, crossfading from wherever you are and back (MusicController). Studio: "/music opening <n> [volume]" plays
	-- option n; the owner picks by ear.
	OPENING = {
		key = "opening",
		tracks = {
			"rbxassetid://9048776085", -- "Enchanted Butterflies" (whimsical mallets and piano; first pick, to judge)
		},
		options = {
			option("Enchanted Butterflies (whimsical mallets and piano)", "9048776085"),
			option("Mischievous Elves (playful magic orchestra)", "1841594035"),
			option("Magic and Mayhem (bouncy magic orchestra)", "1841593987"),
			option("Pixie Dance (light and sparkly)", "1838007325"),
			option("Jackpot (game show, fast and driving)", "1836301731"),
			option("Mr Happy Go Lucky (cheerful pizzicato)", "9043031481"),
		},
		volume = 0.25,
		compressor = LEVELER,
		fade = 0.8, -- seconds: quick, so the music changes as the pack comes up
	},

	-- The Wild valley (owner 2026-11-04: "finalize the wilds": music in the valley and in every boss arena). Each area
	-- (Config/WildValley BIOMES order) has its own piece, crossfading as you walk from one to the next (on a pass
	-- between them the last one keeps playing); each boss arena (the same zone order) has its own battle piece while
	-- you're in it, in place of the boss fights' drone (Bosses.MUSIC_ID, kept for the Frontier and the Dungeon). Each
	-- loops through the leveler. The valley plays only solo piano or acoustic guitar (owner 2026-11-04, after the
	-- orchestral picks: "acoustic guitars or piano only"), very quiet, the owner's pick of each by ear with its volume;
	-- the arenas keep the owner's battle picks. Each area also plays a Pro Sound Effects ambient loop under its music
	-- (turned down by the owner: the Meadow 0.03, the Caves 0.05, the lava 0.008), crossfading the same way (the
	-- arenas have theirs in Config/WildValley ARENA_DRESSING).
	WILD = {
		areas = {
			{
				key = "meadow", -- light, bright adventure
				tracks = { "rbxassetid://1838420686" }, -- Woodland Walk (the owner's pick, option 3)
				compressor = LEVELER,
				-- Field Birds Tweeting 1: cicadas, birds, insects buzzing by, light tree movement (PlaybackLoudness ignores
				-- Volume, so what you hear ~ loudness x volume: this loop reads ~11, the music ~90-150); the first pick, Birds
				-- Peaceful 2 (~4.6 x 0.3 against ~98 x 0.1), was lost under the music.
				ambient = { id = "rbxassetid://9112779471", volume = 0.03 },
				options = {
					option("Butterflies (uplifting, summery; solo guitar)", "1842176339"),
					option("Running Through The Fields (solo piano)", "137990447184466"),
					option("Woodland Walk (classical solo guitar)", "1838420686"),
				},
				volume = 0.005,
			},
			{
				key = "gorge", -- the caves: mysterious, echoey
				tracks = { "rbxassetid://1842181702" }, -- Calm Waters (the owner's pick, option 2)
				compressor = LEVELER,
				ambient = { id = "rbxassetid://9120505513", volume = 0.05 }, -- Water Cave Trickle Very Thin 3: drips, echo
				options = {
					option("Secret Waterfall (introspective; solo piano)", "1843514537"),
					option("Calm Waters (slow, sparse; solo guitar)", "1842181702"),
					option("Air Currents (floating; classical solo guitar)", "1842276365"),
				},
				volume = 0.01,
			},
			{
				key = "ridge", -- Ember Ridge: foreboding, volcanic
				tracks = { "rbxassetid://1842276365" }, -- Air Currents (the owner's pick, option 4; Hombre Solo before)
				compressor = LEVELER,
				ambient = { id = "rbxassetid://9112823197", volume = 0.008 }, -- Lava Rumble 1: bubbling lava (the owner's number)
				options = {
					option("Moonlight Sonata (Beethoven; solo piano)", "9046646008"),
					option("Live Piano Stories 04 (drama, mysterious; solo piano)", "127337767677606"),
					option("Hombre Solo (intense, Spanish; solo guitar)", "1842276088"),
					option("Air Currents (floating; classical solo guitar)", "1842276365"),
				},
				volume = 0.005,
			},
		},
		arenas = {
			{
				key = "warden", -- the Meadow Warden's grove: an enchanted-forest battle
				tracks = { "rbxassetid://1845205138" }, -- Forest Chase (the owner's pick)
				compressor = LEVELER,
				options = {
					option("Forest Chase (epic adventure)", "1845205138"),
					option("Battle Of Wonderland (epic fantasy)", "1845108839"),
					option("Combat Of Giants (epic adventure trailer)", "1839391532"),
				},
				volume = 0.006, -- owner 2026-11-05 (down from 0.1)
			},
			{
				key = "brood", -- the Cave Brood Queen's hollow: dark and creepy
				tracks = { "rbxassetid://1841360723" }, -- Creepy Crawlers (the owner's pick)
				compressor = LEVELER,
				options = {
					option("Creepy Crawlers (tension)", "1841360723"),
					option("Ghastly Unknown (dark fantasy underscore)", "1843501883"),
					option("The Dark Walk (epic battle)", "119847251210739"),
				},
				volume = 0.008, -- down with the warden (2026-11-05), keeping its lift over it
			},
			{
				key = "colossus", -- the Ember Colossus' lava field: big and fiery
				tracks = { "rbxassetid://96625587462633" }, -- Giant's Grave (the owner's pick)
				compressor = LEVELER,
				options = {
					option("Giant's Grave (epic battle)", "96625587462633"),
					option("The Heroic Battle of Giants (symphonic metal)", "9039352479"),
					option("Fuel to the Fire (distorted eruption)", "1837843587"),
				},
				volume = 0.006, -- down with the warden (2026-11-05)
			},
		},
		fade = 2.5, -- seconds to crossfade from one place's music to the next
	},
}
