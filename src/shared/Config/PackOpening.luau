--!strict
-- Pack opening presentation (client only). Timings in seconds. See DESIGN.md section 5.7.
-- Sound IDs are empty until you pick some: paste e.g. "rbxassetid://123" to enable.
return {
	TEAR_SECONDS = 0.45,
	DEAL_DELAY = 0.08, -- between each face-down card appearing
	FLIP_SECONDS = 0.18, -- each half of the flip
	FLASH_SECONDS = 0.6, -- the white flash on big pulls (CardReveal flash = true)
	FOIL_SHIMMER_SECONDS = 1.6, -- one sweep of the foil shimmer

	-- Border thickness by rarity, so better pulls feel heavier
	STROKE_THICKNESS = { Common = 2, Rare = 3, ["Very Rare"] = 3.5, Epic = 4, Legendary = 6 },

	TEAR_SOUND_ID = "",
	FLIP_SOUND_ID = "",
	HIT_SOUND_IDS = { Rare = "", ["Very Rare"] = "", Epic = "", Legendary = "" },
}
