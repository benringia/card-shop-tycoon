--!strict
-- Place ids in the Cardshop Simulator experience (10772040916). Teleports only go to these.
-- Setting FRONTIER_PLACE_ID (or DUNGEON_PLACE_ID) to 0 turns its portal into "coming soon".
return {
	MAIN_PLACE_ID = 75599593337434,
	FRONTIER_PLACE_ID = 73033858769620,
	DUNGEON_PLACE_ID = 79143483483478, -- the final boss's place, reached from the Frontier (0: "coming soon")
	FRONTIER_PORTAL = { x = 104, y = 0, z = 9 }, -- main game: east end of the street, beside the Wild portal
	TRAVEL_COOLDOWN = 3, -- seconds between travel requests
}
