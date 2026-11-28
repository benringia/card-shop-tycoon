--!strict
-- The Starter Pack (spec 2026-11-28-robux-round-design; a one-time developer product, Config/Monetization UNLOCKS
-- "StarterPack", R$ 99): the Sunny Shop look (Config/Decor, perk "StarterPack"), the "Shop Starter" title
-- (Config/Titles) and 30 minutes of 2x Luck. Its card shows once, at the first calm moment after an hour of play
-- counted after Pish's first visit in the main place (StarterService counts, StarterController shows; Util/StarterRules).
-- Never shown or sold where Roblox restricts paid random items (it holds luck). Plain data.
return {
	PLAY_SECONDS = 60 * 60, -- play before the card shows (counted one second at a time, saved: data.starter.played)
	TICK = 1, -- seconds between the server's play counts
	POLL = 1, -- seconds between the client's calm-moment checks while the card waits
	LUCK = { strength = "x2", seconds = 30 * 60 }, -- the luck it gives (Config/Luck STRENGTHS)
	LOOK = "SunnyShop", -- its shop look (Config/Decor LOOKS)
	TITLE = "shopStarter", -- its title (Config/Titles)
	-- The card's words (StarterController): a pack, never a gift (kids read "gift" as free)
	CARD = {
		title = "Starter Pack!",
		line = "A one-time pack to start your shop:",
		rows = {
			{ icon = "🌞", name = "Sunny Shop look", line = "A shop look only in this pack" },
			{ icon = "🏆", name = '"Shop Starter" title', line = "It shows over your name" },
			{ icon = "🍀", name = "2x Luck · 30 min", line = "Better last cards in your packs" },
		},
		later = "Maybe later",
		foot = "It stays in the Store if you change your mind.",
		-- the window: its most size (px) and Pish's peek sticker (Config/HudMascot images.peek) over its top-left corner,
		-- placed like Turts' (`left` px in, its bottom `overlap` px below the window's top)
		maxSize = { 420, 400 },
		peek = { size = { 70, 55 }, left = 10, overlap = 26 },
	},
}
