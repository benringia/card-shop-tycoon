--!strict
-- The Wild's loading screen (owner 2026-11-05: "when entering wilds can we do a loading screen that make sure
-- everything is loaded before player can walk in"). It shows the moment the portal sends you (WildService fires
-- WildTravel "loading"), and once you've arrived it holds you still until the ground under you, the valley's scenery,
-- the monsters' models and the area's music are in (Util/WildLoadingRules, Controllers/WildLoadingController). Since
-- 2026-11-13 it's the binder like every loading screen (its look: Config/LoadingScreen LOOKS.Wild, or LOOKS.Frontier
-- inside the Frontier); these are its steps and timings. Plain data (Lune-tested).
return {
	-- What each step waits for, in order: ground, scenery, monsters, sounds (WildLoadingRules.ORDER)
	STEPS = { "Opening the portal...", "Growing the valley...", "Waking the monsters...", "Tuning the sounds..." },
	READY = "Here we go!",
	MIN_SECONDS = 1.2, -- shown at least this long, so it never just flashes
	MAX_SECONDS = 12, -- after you arrive, never held longer than this (a slow device walks in with what's loaded)
	WAIT_SECONDS = 30, -- before you arrive (the server streams the valley in first), never shown longer than this
	FADE_SECONDS = 0.5,
	GROUND_DEPTH = 60, -- studs below you the ground must be found
}
