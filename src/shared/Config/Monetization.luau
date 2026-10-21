--!strict
-- Game pass and developer product IDs. Create them on Creator Hub (your experience -> Monetization ->
-- Passes), then paste the ID here. 0 means "not created yet": the game treats it as not owned and the UI
-- shows "Coming soon".
return {
	PASSES = {
		ExtraJobSlot = 0, -- +1 shop job slot (DESIGN 8)
	},
	CHECK_RETRY_SECONDS = 60, -- after a failed ownership check, wait this long before asking Roblox again
}
