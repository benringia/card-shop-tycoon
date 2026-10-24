--!strict
-- Pack contents and odds, keyed by the product ID of the pack. See DESIGN.md section 5.3.
-- Odds are shown to players in the pack opening screen, so keep these accurate.
-- The last slot is the "hit slot": it flips last, with a build-up.
export type Weighted = { rarity: string, weight: number }

export type Pack = {
	productId: string,
	name: string,
	color: Color3,
	art: string?, -- the pack's front picture (assets/ui/packs); none = a plain pack in its colour
	-- "Deck": a deck box (its lid lifts off and every card shows at once); nil = a pack (torn open, one card at a time)
	kind: string?,
	slots: { { Weighted } },
}

local COMMON: { Weighted } = { { rarity = "Common", weight = 1 } }

local ById: { [string]: Pack } = {
	FirstSparkPack = {
		productId = "FirstSparkPack",
		name = "First Spark",
		color = Color3.fromRGB(255, 140, 50),
		art = "rbxassetid://81309929146607", -- fire phoenix (Figma image generator)
		slots = {
			COMMON,
			COMMON,
			COMMON,
			{ { rarity = "Common", weight = 0.7 }, { rarity = "Rare", weight = 0.3 } },
			{ { rarity = "Rare", weight = 0.68 }, { rarity = "Very Rare", weight = 0.15 }, { rarity = "Epic", weight = 0.14 }, { rarity = "Legendary", weight = 0.03 } },
		},
	},
	-- The First Spark Deck Box: 5 cards opened at once, two of them Rare or better ($9 against a pack's $3)
	DeckBox = {
		productId = "DeckBox",
		name = "First Spark",
		kind = "Deck",
		color = Color3.fromRGB(150, 95, 210),
		art = "rbxassetid://81309929146607", -- the First Spark phoenix, like the pack
		slots = {
			COMMON,
			COMMON,
			{ { rarity = "Common", weight = 0.5 }, { rarity = "Rare", weight = 0.5 } },
			{ { rarity = "Rare", weight = 0.75 }, { rarity = "Very Rare", weight = 0.25 } },
			{ { rarity = "Rare", weight = 0.45 }, { rarity = "Very Rare", weight = 0.25 }, { rarity = "Epic", weight = 0.22 }, { rarity = "Legendary", weight = 0.08 } },
		},
	},
}

return {
	ById = ById,
	RIP_COOLDOWN = 1, -- seconds between pack opens per player (server)
}
