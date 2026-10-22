--!strict
-- Every item a player can hold. Saved as items = { [itemId] = count } (whole numbers, up to MAX_STACK).
-- Add an entry here for a new item; ItemService gives and takes them, the binder's Bag tab lists them.
-- Plain data only so Lune tests can load this file.
return {
	MAX_STACK = 9999,
	ITEMS = {
		starShard = {
			name = "Star Shard",
			icon = "✨",
			description = "Counts as one duplicate when condensing any card.",
			source = "Frontier monsters · 3% (elites 10%)",
			use = "Card Condenser → Use Star Shards (covers up to half of a star)",
		},
	},
}
