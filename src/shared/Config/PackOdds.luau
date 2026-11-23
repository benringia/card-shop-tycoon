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
		-- The First Spark Deck Box: 5 cards opened at once, two of them Rare or better ($9 against a pack's $3). It
		-- costs three packs, so it is worth three (owner 2026-11-20: "whats the point of deck box? its just an expensive
		-- version of the booster pack? if not fix it"; tests/DeckBox): its hit card is always Very Rare or better, and
		-- its chance of an Epic or better (40%) and of a Legendary (3%) is a little over three packs' (38.6%, 2.97%).
		-- Three packs still give three times the cards. (Its hit slot was Rare 52 / Very Rare 25 / Epic 22 / Legendary 1:
		-- worse than three packs at everything.)
		DeckBox = {
			COMMON,
			COMMON,
			{ { rarity = "Common", weight = 0.5 }, { rarity = "Rare", weight = 0.5 } },
			{ { rarity = "Rare", weight = 0.75 }, { rarity = "Very Rare", weight = 0.25 } },
			{ { rarity = "Very Rare", weight = 0.6 }, { rarity = "Epic", weight = 0.37 }, { rarity = "Legendary", weight = 0.03 } },
		},
		-- The Frontier Pack (owner 2026-11-23, pick B: Frontier cards "take ages to find it and upgrade it"): 5 of the
		-- Frontier set's cards (Rare, Epic, Legendary: two of each), opened once the Frost Tyrant is beaten. Three Rares,
		-- an Epic one time in five, and its hit an Epic a third of the time and a Legendary one time in twenty: about one
		-- Epic in two packs. A Legendary per dollar like a First Spark pack's (5% at $15 against 1% at $3), and the
		-- Frontier has only two, so a chosen one comes far sooner than by drops alone
		FrontierPack = {
			{ { rarity = "Rare", weight = 1 } },
			{ { rarity = "Rare", weight = 1 } },
			{ { rarity = "Rare", weight = 1 } },
			{ { rarity = "Rare", weight = 0.8 }, { rarity = "Epic", weight = 0.2 } },
			{ { rarity = "Rare", weight = 0.62 }, { rarity = "Epic", weight = 0.33 }, { rarity = "Legendary", weight = 0.05 } },
		},
	} :: { [string]: { { Weighted } } },

	-- Bad-luck protection, counted per player across every pack and Deck Box they open (saved: data.pity). Without an
	-- Epic or better for EPIC_PACKS - 1 packs, the next one's hit slot is an Epic. LEGENDARY_GRADES: the stingy grades
	-- of a Legendary that wasn't luck (Turts' Legendary Pack; a pity Legendary's when a pity sets one).
	PITY = {
		-- No Legendary guarantee (owner 2026-11-20: "remove the 140 cards to get legendary. My friend already has 1200
		-- packs and spamming open 10 cards": the first was guaranteed within 130 packs and every later one within 210,
		-- so packs by the hundred bought Legendaries). A Legendary is luck now: its 1% (3% in a Deck Box) and Luck.
		-- Util/PityRules still knows FIRST_LEGENDARY_PACKS and LEGENDARY_PACKS should a pity set them again; the saved
		-- count goes on.
		EPIC_PACKS = 40,
		LEGENDARY_GRADES = { C = 0.8, B = 0.18, A = 0.018, S = 0.002 },
	},

	-- Rarity rank, for "an Epic or better" (matches Config/Rarities order)
	RANK = { Common = 1, Rare = 2, ["Very Rare"] = 3, Epic = 4, Legendary = 5 } :: { [string]: number },
}
