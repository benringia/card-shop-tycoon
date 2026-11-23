--!strict
-- Place ids in the One More Pack experience (10772040916). Teleports only go to these.
-- Setting FRONTIER_PLACE_ID (or DUNGEON_PLACE_ID) to 0 turns its portal into "coming soon".
return {
	MAIN_PLACE_ID = 75599593337434,
	FRONTIER_PLACE_ID = 73033858769620,
	DUNGEON_PLACE_ID = 79143483483478, -- the final boss's place, reached from the Frontier (0: "coming soon")
	FRONTIER_PORTAL = { x = 182, y = 10, z = 128 }, -- main game: in the snowy clearing at Frostpeak, at the end of its trail (Town.PORTAL_AREAS)
	TRAVEL_COOLDOWN = 3, -- seconds between travel requests
	-- A teleport's loading screen goes up the moment it starts (owner 2026-11-23: "a few seconds delay before the loading
	-- screen to frontier appears which caused the player confusions"; Remotes.Departing): the save's hand-off and the
	-- teleport itself take a few seconds before Roblox shows its own copy of the screen
	DEPARTURE = {
		MAX_SECONDS = 30, -- no teleport took over by then: the screen goes and says so
		STUDIO_HOLD = 2.5, -- Studio can't teleport: the screen shows this long, then "only in the published game"
		FAILED = "The teleport didn't work. Try again in a moment.",
	},
}
