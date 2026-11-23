--!strict
-- Packs, keyed by the product ID of the pack. See DESIGN.md section 5.3. What each slot can roll, and the pity, live in
-- Config/PackOdds (plain data, so Lune tests and the economy simulator load the real numbers).
local PackOdds = require(script.Parent:WaitForChild("PackOdds"))

export type Weighted = PackOdds.Weighted

export type Pack = {
	productId: string,
	name: string,
	color: Color3,
	art: string?, -- the pack's front picture (assets/ui/packs); none = a plain pack in its colour
	-- "Deck": a deck box (its lid lifts off and every card shows at once); nil = a pack (torn open, one card at a time)
	kind: string?,
	model: string, -- its 3D model in ReplicatedStorage.PackModels (assets/packs): "Pack" or "DeckBox" (Util/PackModels)
	look: string, -- which of the model's Looks it wears (one per set)
	set: string?, -- the card set it opens into (Config/Cards BySetRarity); nil = "First Spark"
	slots: { { Weighted } },
}

local ById: { [string]: Pack } = {
	FirstSparkPack = {
		productId = "FirstSparkPack",
		name = "First Spark",
		color = Color3.fromRGB(255, 140, 50),
		art = "rbxassetid://81309929146607", -- fire phoenix (Figma image generator)
		model = "Pack",
		look = "FirstSpark",
		slots = PackOdds.SLOTS.FirstSparkPack,
	},
	-- The First Spark Deck Box: 5 cards opened at once, its hit card always Very Rare or better ($9 against a pack's
	-- $3; Config/PackOdds)
	DeckBox = {
		productId = "DeckBox",
		name = "First Spark",
		kind = "Deck",
		color = Color3.fromRGB(150, 95, 210),
		art = "rbxassetid://81309929146607", -- the First Spark phoenix, like the pack
		model = "DeckBox",
		look = "FirstSpark",
		slots = PackOdds.SLOTS.DeckBox,
	},
	-- The Frontier Pack (owner 2026-11-23, pick B): only Frontier cards, stocked once the Frost Tyrant is beaten
	-- (Config/Products unlockBoss). Its art: an aurora sky over the Stormking card's storm
	-- (tools/ui-art/make_frontier_pack_art.py, assets/ui/packs/Frontier.jpg); its 3D look baked into the pack models
	-- (tools/packs/add_look, docs/packs.md)
	FrontierPack = {
		productId = "FrontierPack",
		name = "Frontier",
		color = Color3.fromRGB(130, 90, 230),
		art = "rbxassetid://101498596854793",
		model = "Pack",
		look = "Frontier",
		set = "Frontier",
		slots = PackOdds.SLOTS.FrontierPack,
	},
}

return {
	ById = ById,
	RIP_COOLDOWN = 1, -- seconds between pack opens per player (server)
	PITY = PackOdds.PITY,
	RANK = PackOdds.RANK,
}
