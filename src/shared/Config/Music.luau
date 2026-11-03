--!strict
-- Background music (TownMusicController, Util/MusicRules). Plain data (Lune-tested).
return {
	-- The town (owner 2026-11-04: subtle and gentle, under the birds, wind and waterfall of Config/Scenery SOUNDS): two
	-- soft APM underscores (Roblox-licensed, no lead melody, so they stay in the background) taking turns with a little
	-- quiet between them. It fades out when you leave the town (the Wild valley, a boss arena) and back in when you return.
	TOWN = {
		tracks = {
			"rbxassetid://9038622066", -- "Lakefront Days (Ukulele Underscore Version)", 138 s
			"rbxassetid://9038622062", -- "Lakefront Days (Underscore Version)", acoustic guitar, 138 s
		},
		volume = 0.12,
		fade = 3, -- seconds to fade in or out
		gap = 6, -- seconds of quiet between tracks
		margin = 40, -- studs past the island's edge that still count as town
		checkEvery = 0.5, -- seconds between checks of where you are
	},
}
