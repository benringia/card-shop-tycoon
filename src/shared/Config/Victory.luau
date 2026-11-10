--!strict
-- The fight's end screen, design B "banner and loot strip" (owner, 2026-11-03; Util/VictoryScreen, Util/VictoryRules):
-- a big glowing word over the arena, a row of reward tiles popping in one by one, the party's XP bars under them
-- (clear of the HUD buttons). Plain data.
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

-- A boss win's sting (the owner 2026-11-10: "after defeating a boss change the victory sound effects to something
-- rewarding/satisfying"): three APM stings to pick from by ear (Studio: /victorysound <1-3> plays one and uses it on
-- your next wins this session), the first the default; `startAt` skips silence at the file's start
local WIN_OPTIONS = {
	{ id = "rbxassetid://1836473422", name = "Victory Fanfare Sting", startAt = 0 }, -- Olympiad: a classic brass fanfare
	{ id = "rbxassetid://85130118995016", name = "Arc Of Triumph (Sting)", startAt = 0 }, -- Brass & Glory: heroic
	{ id = "rbxassetid://9040233162", name = "Light Fun Orchestral Transition 04", startAt = 0 }, -- playful and light
}

return {
	WIN_OPTIONS = WIN_OPTIONS,
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
		win = WIN_OPTIONS[1].id, -- a boss win's sting (was Orchestral Hits, APM 1844539433)
		tile = "rbxassetid://106984966606682", -- Cartoon Pop (Daily Sounds)
		rare = "rbxassetid://9116395089", -- Magic Glows Soft Clusters Of Chiming Hits 4 (Pro Sound Effects)
		levelUp = "rbxassetid://9116418035", -- Magic Tone Falling Shimmer (Pro Sound Effects)
	},
	VOLUME = 0.5,
	-- Seconds of silence at the start of a sound's file, skipped so it lands with the moment (measured in Studio)
	START_AT = { win = WIN_OPTIONS[1].startAt, levelUp = 0.38 },
	-- Normal monsters get a toast instead (Util/FightToast): slides down at the top, edge colour by kind, gone after
	-- `seconds`; a soft pop as it lands (the chime for a card or shards)
	TOAST = {
		seconds = 2.6,
		top = 64, -- px under the top bar, clear of the Shop button
		edge = { win = rgb(62, 224, 138), rare = rgb(255, 207, 74), lose = rgb(224, 71, 58), run = rgb(154, 150, 168) },
	},
	-- Boss loot picked up (Util/ItemPopup, Util/ItemPopupRules; the owner 2026-11-10: "picking up an item should show a
	-- notification"): a card per item at the top right, under Roblox's top bar, `width` px wide, stacking down (three
	-- at most, clear of the weapon switch)
	PICKUP = { seconds = 3, max = 3, width = 250, height = 56, gap = 8, top = 70, right = 16, sound = "rbxassetid://106984966606682" },
}
