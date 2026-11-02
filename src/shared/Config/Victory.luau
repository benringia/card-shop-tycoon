--!strict
-- The fight's end screen, design B "banner and loot strip" (owner, 2026-11-03; Util/VictoryScreen, Util/VictoryRules):
-- a big glowing word over the arena, a row of reward tiles popping in one by one, the party's XP bars under them
-- (clear of the HUD buttons). Plain data.
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

return {
	SECONDS = 6, -- on screen before it goes by itself (a tap closes it sooner)
	TITLE_SIZE = 64, -- px, on a 400 px tall screen and up; smaller screens scale it down
	TILE = { width = 92, height = 96, gap = 10, perRow = 5 },
	PORTRAIT = 40,
	-- Timings (seconds after it opens)
	TITLE_POP = 0.35,
	TILES_FROM = 0.5,
	TILE_GAP = 0.16,
	XP_FROM = 0.9,
	XP_FILL = 1, -- seconds an XP bar takes to fill
	-- Colours by result
	COLORS = {
		win = { title = rgb(255, 226, 122), shade = rgb(255, 160, 40), stroke = rgb(150, 80, 8) },
		conquered = { title = rgb(255, 210, 90), shade = rgb(255, 120, 40), stroke = rgb(140, 60, 0) },
		lose = { title = rgb(255, 130, 120), shade = rgb(220, 50, 50), stroke = rgb(90, 10, 10) },
		run = { title = rgb(230, 230, 240), shade = rgb(160, 160, 180), stroke = rgb(40, 40, 55) },
	},
	TILE_BACK = rgb(20, 16, 30),
	RARE = rgb(255, 207, 74),
	XP_FILL_COLOR = rgb(57, 182, 232),
	-- Roblox-licensed sounds the pack opening already uses
	SOUNDS = {
		win = "rbxassetid://1844539433", -- Orchestral Hits (APM)
		tile = "rbxassetid://106984966606682", -- Cartoon Pop (Daily Sounds)
		rare = "rbxassetid://9116395089", -- Magic Glows Soft Clusters Of Chiming Hits 4 (Pro Sound Effects)
		levelUp = "rbxassetid://9116418035", -- Magic Tone Falling Shimmer (Pro Sound Effects)
	},
	VOLUME = 0.5,
	-- Seconds of silence at the start of a sound's file, skipped so it lands with the moment (measured in Studio)
	START_AT = { win = 0.3, levelUp = 0.38 },
	-- Normal monsters get a toast instead (Util/FightToast): slides down at the top, edge colour by kind, gone after
	-- `seconds`; a soft pop as it lands (the chime for a card or shards)
	TOAST = {
		seconds = 2.6,
		top = 64, -- px under the top bar, clear of the Shop button
		edge = { win = rgb(62, 224, 138), rare = rgb(255, 207, 74), lose = rgb(224, 71, 58), run = rgb(154, 150, 168) },
	},
}
