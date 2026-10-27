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
	slots: { { Weighted } },
}

local ById: { [string]: Pack } = {
	FirstSparkPack = {
		productId = "FirstSparkPack",
		name = "First Spark",
		color = Color3.fromRGB(255, 140, 50),
		art = "rbxassetid://81309929146607", -- fire phoenix (Figma image generator)
		slots = PackOdds.SLOTS.FirstSparkPack,
	},
	-- The First Spark Deck Box: 5 cards opened at once, two of them Rare or better ($9 against a pack's $3)
	DeckBox = {
		productId = "DeckBox",
		name = "First Spark",
		kind = "Deck",
		color = Color3.fromRGB(150, 95, 210),
		art = "rbxassetid://81309929146607", -- the First Spark phoenix, like the pack
		slots = PackOdds.SLOTS.DeckBox,
	},
}

return {
	ById = ById,
	RIP_COOLDOWN = 1, -- seconds between pack opens per player (server)
	PITY = PackOdds.PITY,
	RANK = PackOdds.RANK,
}
