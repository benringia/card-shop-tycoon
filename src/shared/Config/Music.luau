--!strict
-- Background music (MusicController, Util/MusicRules): the town, the Wild valley's three areas and its three boss
-- arenas. Each place: its `key` (Studio: "/music <key> <n> [volume]" plays option n anywhere, "/music <key> 0" goes back
-- to the picked tracks; "/music <n>" is the town's), the `tracks` it plays, the `options` to pick them from and its
-- `volume`. Plain data (Lune-tested).

-- APM pieces (Roblox-licensed) to choose from, by name
local function option(name: string, id: string): { name: string, id: string }
	return { name = name, id = `rbxassetid://{id}` }
end

return {
	-- The town (owner 2026-11-04: subtle and gentle, under the birds, wind and waterfall of Config/Scenery SOUNDS): soft
	-- APM pieces (Roblox-licensed) taking turns with a little quiet between them. It fades out when you leave the town
	-- (the Wild valley, a boss arena) and back in when you return.
	TOWN = {
		key = "town",
		-- What plays: the owner's pick from `options` (Studio: "/music <n> [volume]" plays option n over the ambience,
		-- "/music 0" goes back to these)
		tracks = {
			"rbxassetid://83889171451910", -- "Drifting Into Dreamland - Underscore", 169 s (the owner's pick, 2026-11-04)
		},
		-- Soft APM pieces to choose from (owner 2026-11-04: the first pick overpowered the ambience)
		options = {
			{ name = "White Owl (bells and piano)", id = "rbxassetid://9048757009" },
			{ name = "Wistful Wonderings (guitar and harmonium)", id = "rbxassetid://9043424638" },
			{ name = "Soft Tranquility (sparse)", id = "rbxassetid://105460275738508" },
			{ name = "Drifting Into Dreamland (underscore)", id = "rbxassetid://83889171451910" },
			{ name = "Lakefront Days (ukulele underscore, the first pick)", id = "rbxassetid://9038622066" },
		},
		-- The owner's number (2026-11-04, after 0.07): 0.21. Before: 0.12 overpowered the birds, wind and waterfall (with
		-- the first, louder track); 0.013, 0.022, 0.045 and 0.07 too low. Try others with "/music 4 <volume>".
		volume = 0.21,
		-- A CompressorSoundEffect on the music as a limiter: the track swells in its later parts (owner 2026-11-03: "too
		-- loud, specially on later parts"), so above the threshold it barely grows (ratio 20). Round 5 kept the threshold,
		-- so the loudest part rises with the volume (tests/MusicRules).
		compressor = { threshold = -48.5, ratio = 20, attack = 0.02, release = 0.5 },
		fade = 3, -- seconds to fade in or out
		gap = 6, -- seconds of quiet between tracks
		margin = 40, -- studs past the island's edge that still count as town
		checkEvery = 0.5, -- seconds between checks of where you are
	},

	-- The Wild valley (owner 2026-11-04: "finalize the wilds": music in the valley and in every boss arena). Each area
	-- (Config/WildValley BIOMES order) has its own piece, crossfading as you walk from one to the next (on a pass
	-- between them the last one keeps playing); each boss arena (the same zone order) has its own battle piece while
	-- you're in it, in place of the boss fights' drone (Bosses.MUSIC_ID, kept for the Frontier and the Dungeon). The
	-- owner picks from the options by ear; until then the first option plays. Each loops.
	WILD = {
		areas = {
			{
				key = "meadow", -- light, bright adventure
				tracks = { "rbxassetid://1841593944" },
				options = {
					option("Enchanted Kingdom (magical fantasy adventure)", "1841593944"),
					option("Pastures Green (English pastoral orchestra)", "130182237855242"),
					option("Fancytale (fantasy adventure)", "1848093905"),
				},
				volume = 0.2,
			},
			{
				key = "gorge", -- the caves: mysterious, echoey
				tracks = { "rbxassetid://9038404354" },
				options = {
					option("Mysterious Cave", "9038404354"),
					option("Curious Shadows (dark fantasy)", "1843503016"),
					option("Lair of the Wizard (magical fantasy)", "1841594242"),
				},
				volume = 0.2,
			},
			{
				key = "ridge", -- Ember Ridge: foreboding, volcanic
				tracks = { "rbxassetid://1835286723" },
				options = {
					option("Foreboding Volcano (orchestral landscape)", "1835286723"),
					option("Under The Volcano", "9038165770"),
					option("Mythic Mountain (dark fantasy, no percussion)", "1843501727"),
				},
				volume = 0.2,
			},
		},
		arenas = {
			{
				key = "warden", -- the Meadow Warden's grove: an enchanted-forest battle
				tracks = { "rbxassetid://1845205138" },
				options = {
					option("Forest Chase (epic adventure)", "1845205138"),
					option("Battle Of Wonderland (epic fantasy)", "1845108839"),
					option("Combat Of Giants (epic adventure trailer)", "1839391532"),
				},
				volume = 0.25,
			},
			{
				key = "brood", -- the Cave Brood Queen's hollow: dark and creepy
				tracks = { "rbxassetid://1841360723" },
				options = {
					option("Creepy Crawlers (tension)", "1841360723"),
					option("Ghastly Unknown (dark fantasy underscore)", "1843501883"),
					option("The Dark Walk (epic battle)", "119847251210739"),
				},
				volume = 0.25,
			},
			{
				key = "colossus", -- the Ember Colossus' lava field: big and fiery
				tracks = { "rbxassetid://96625587462633" },
				options = {
					option("Giant's Grave (epic battle)", "96625587462633"),
					option("The Heroic Battle of Giants (symphonic metal)", "9039352479"),
					option("Fuel to the Fire (distorted eruption)", "1837843587"),
				},
				volume = 0.25,
			},
		},
		fade = 2.5, -- seconds to crossfade from one place's music to the next
	},
}
