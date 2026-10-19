--!strict
-- Pack contents and odds, keyed by the product ID of the pack. See DESIGN.md section 5.3.
-- Odds are shown to players in the pack opening screen, so keep these accurate.
-- The last slot is the "hit slot": it flips last, with a build-up.
export type Weighted = { rarity: string, weight: number }

export type Pack = {
	productId: string,
	name: string,
	color: Color3,
	slots: { { Weighted } },
}

local COMMON: { Weighted } = { { rarity = "Common", weight = 1 } }

local ById: { [string]: Pack } = {
	FirstSparkPack = {
		productId = "FirstSparkPack",
		name = "First Spark",
		color = Color3.fromRGB(255, 140, 50),
		slots = {
			COMMON,
			COMMON,
			COMMON,
			{ { rarity = "Common", weight = 0.7 }, { rarity = "Rare", weight = 0.3 } },
			{ { rarity = "Rare", weight = 0.8 }, { rarity = "Epic", weight = 0.17 }, { rarity = "Legendary", weight = 0.03 } },
		},
	},
}

return {
	ById = ById,
	RIP_COOLDOWN = 1, -- seconds between pack opens per player (server)
}
