--!strict
-- Background music (TownMusicController, Util/MusicRules). Plain data (Lune-tested).
return {
	-- The town (owner 2026-11-04: subtle and gentle, under the birds, wind and waterfall of Config/Scenery SOUNDS): soft
	-- APM pieces (Roblox-licensed) taking turns with a little quiet between them. It fades out when you leave the town
	-- (the Wild valley, a boss arena) and back in when you return.
	TOWN = {
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
		volume = 0.03, -- the owner: 0.12 overpowered the birds, wind and waterfall; 0.05 still a little loud
		fade = 3, -- seconds to fade in or out
		gap = 6, -- seconds of quiet between tracks
		margin = 40, -- studs past the island's edge that still count as town
		checkEvery = 0.5, -- seconds between checks of where you are
	},
}
