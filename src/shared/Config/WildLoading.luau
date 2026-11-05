--!strict
-- The Wild's loading screen (owner 2026-11-05: "when entering wilds can we do a loading screen that make sure
-- everything is loaded before player can walk in", look A "Portal swirl"). It shows the moment the portal sends you
-- (WildService fires WildTravel "loading"), and once you've arrived it holds you still until the ground under you,
-- the valley's scenery, the monsters' models and the area's music are in (Util/WildLoadingRules,
-- Controllers/WildLoadingController). Plain data (Lune-tested).
return {
	TITLE = "The Wild",
	-- What each step waits for, in order: ground, scenery, monsters, sounds (WildLoadingRules.ORDER)
	STEPS = { "Opening the portal...", "Growing the valley...", "Waking the monsters...", "Tuning the sounds..." },
	READY = "Here we go!",
	TIPS = {
		"Tip: monsters get stronger the further you go.",
		"Tip: swap to a creature whose element beats the boss's.",
		"Tip: the healing spring wakes resting cards 3x faster.",
		"Tip: an elite monster drops better loot.",
	},
	MIN_SECONDS = 1.2, -- shown at least this long, so it never just flashes
	MAX_SECONDS = 12, -- after you arrive, never held longer than this (a slow device walks in with what's loaded)
	WAIT_SECONDS = 30, -- before you arrive (the server streams the valley in first), never shown longer than this
	FADE_SECONDS = 0.5,
	GROUND_DEPTH = 60, -- studs below you the ground must be found
	SWIRL = "rbxassetid://82162011115712", -- five spiral arms, white (tools/textures/make_portal_swirl.py)
	GLOW = "rbxassetid://111832033900052", -- Config/AttackFx TEXTURES glow: the swirl's bright heart
	BACKDROP = "rbxassetid://95161168581849", -- the First Spark binder cover (a flowery valley), dimmed behind it
	BACKDROP_RECT = { 0, 560, 680, 454 }, -- its hills and flowers (x, y, width, height of the 680 x 1014 painting)
	SWIRL_SIZE = 0.6, -- of the screen's height
	SWIRL_TURN = { 50, -32 }, -- degrees a second: the two copies turn against each other
	COLORS = {
		back = { 13, 33, 18 }, -- deep green over the backdrop
		swirl = { 125, 255, 176 }, -- the front copy
		swirlBack = { 184, 255, 122 }, -- the copy behind it, bigger and fainter
		glow = { 217, 255, 230 },
		bar = { 74, 222, 128 },
		barEnd = { 200, 255, 176 },
		track = { 255, 255, 255 },
		text = { 255, 255, 255 },
		tip = { 200, 232, 206 },
	},
}
