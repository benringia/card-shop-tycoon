--!strict
-- What each pack can roll, and the pity that guarantees rare pulls. Plain data (no Color3) so Lune can load it: the
-- tests and the economy simulator (tools/economy) use the real numbers. Config/Packs adds the look. DESIGN.md 5.3.
-- Odds are shown to players in the rarity guide, so keep these accurate. The last slot is the "hit slot": it flips
-- last, with a build-up, and it is the one pity raises.
export type Weighted = { rarity: string, weight: number }

local COMMON: { Weighted } = { { rarity = "Common", weight = 1 } }

return {
	SLOTS = {
		FirstSparkPack = {
			COMMON,
			COMMON,
			COMMON,
			{ { rarity = "Common", weight = 0.7 }, { rarity = "Rare", weight = 0.3 } },
			{ { rarity = "Rare", weight = 0.7 }, { rarity = "Very Rare", weight = 0.15 }, { rarity = "Epic", weight = 0.14 }, { rarity = "Legendary", weight = 0.01 } },
		},
		-- The First Spark Deck Box: 5 cards opened at once, two of them Rare or better ($9 against a pack's $3)
		DeckBox = {
			COMMON,
			COMMON,
			{ { rarity = "Common", weight = 0.5 }, { rarity = "Rare", weight = 0.5 } },
			{ { rarity = "Rare", weight = 0.75 }, { rarity = "Very Rare", weight = 0.25 } },
			{ { rarity = "Rare", weight = 0.52 }, { rarity = "Very Rare", weight = 0.25 }, { rarity = "Epic", weight = 0.22 }, { rarity = "Legendary", weight = 0.01 } },
		},
	} :: { [string]: { { Weighted } } },

	-- Bad-luck protection, counted per player across every pack and Deck Box they open (saved: data.pity). A player's
	-- first Legendary is guaranteed within FIRST_LEGENDARY_PACKS packs (a quick hook for new players), every later one
	-- within LEGENDARY_PACKS: the last pack of the run has a Legendary in its hit slot. Without an Epic or better for
	-- EPIC_PACKS - 1 packs, the next one's is an Epic. A pity Legendary guarantees the card, not a good copy: its grade
	-- rolls from LEGENDARY_GRADES, far stingier than a lucky pull's.
	PITY = {
		FIRST_LEGENDARY_PACKS = 130,
		LEGENDARY_PACKS = 210,
		EPIC_PACKS = 40,
		LEGENDARY_GRADES = { C = 0.8, B = 0.18, A = 0.018, S = 0.002 },
	},

	-- Rarity rank, for "an Epic or better" (matches Config/Rarities order)
	RANK = { Common = 1, Rare = 2, ["Very Rare"] = 3, Epic = 4, Legendary = 5 } :: { [string]: number },
}
