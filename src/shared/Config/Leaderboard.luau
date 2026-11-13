--!strict
-- The plaza leaderboard (owner 2026-11-13: "Remove roblox leaderboards on load, we will be adding a leaderboard in game
-- at the plaza for most cards opened"; two lists, "names of all time players across all servers and names of the
-- players within their server"; no reward for now). Ranks lifetime packs opened (the save's stats.packsOpened). Built
-- and kept by the server (LeaderboardService, Server/Util/LeaderboardBoard); Roblox's own player list is hidden on join
-- (UIController). Plain data, read by Lune tests. Studs, seconds, colours { r, g, b }.
local Leaderboard = {}

-- The shared store of every player's total (an OrderedDataStore), named after the save store so the launch wipe
-- (a new Data.STORE_NAME) clears it too
function Leaderboard.storeName(dataStore: string): string
	return `{dataStore}_PacksOpened`
end

Leaderboard.TOP = 10 -- rows on each list
Leaderboard.READ_EVERY = 120 -- the all-time top is read from the store this often (GetSortedAsync has a per-minute budget)
Leaderboard.WRITE_EVERY = 60 -- a player's changed total goes to the store at most this often, and when they leave
Leaderboard.SERVER_EVERY = 1 -- this server's list (and the live totals on the all-time one) checked this often

-- Each list is a giant card in the plaza's card fan (owner 2026-11-13, pick A; Config/Plaza FAN: which cards, their
-- rims and where they stand): its front drawn in pixels over the whole card, `width` x `height`. A panel `inset` of the
-- card (the gold card shows round it as its frame, its rarity colour as the panel's rim): the top `art` of it a sky
-- window with the list's title and the top three on a podium (2nd, 1st, 3rd: avatar, name, count, a step with the place
-- in gold, silver, bronze), the rest a cream text box of rows (rank, avatar, name, count) in the game's window colours
-- (Config/CreamTheme); white text on the sky gets a plum outline (`outline`, its transparency `outlineFade`).
-- `distance`: drawn this far (studs); `light`: how much the scene's light changes it (0: always as drawn)
Leaderboard.FACE = {
	width = 500,
	height = 700,
	inset = { 0.88, 0.92 },
	corner = 0.05,
	stroke = 6,
	art = 0.45,
	podium = 3,
	subtitle = "MOST PACKS OPENED",
	lists = {
		allTime = { title = "ALL TIME", sky = { { 255, 214, 110 }, { 255, 150, 90 } } },
		server = { title = "THIS SERVER", sky = { { 150, 210, 255 }, { 165, 139, 255 } } },
	},
	steps = { -- by place: the block's height (px) and colour
		{ height = 78, color = { 255, 214, 94 } },
		{ height = 54, color = { 223, 230, 238 } },
		{ height = 38, color = { 233, 167, 122 } },
	},
	avatar = { 74, 60, 60 }, -- by place (px)
	box = { 255, 248, 253 },
	rowAlt = { 247, 236, 255 },
	boxPad = 10,
	rowHeight = 46,
	ink = { 91, 61, 110 },
	inkSoft = { 150, 120, 170 },
	count = { 160, 100, 12 },
	white = { 255, 255, 255 },
	outline = { 91, 61, 110 },
	outlineFade = 0.35,
	sizes = { title = 42, subtitle = 20, podiumName = 24, podiumCount = 22, place = 30, rank = 24, name = 26, count = 26, note = 24 },
	loading = "Loading...",
	empty = "Open packs to get on the board!",
	distance = 170,
	light = 0,
}

return Leaderboard
