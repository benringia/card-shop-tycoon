--!strict
-- Every item a player can hold. Saved as items = { [itemId] = count } (whole numbers, up to MAX_STACK).
-- Add an entry here for a new item; ItemService gives and takes them, the binder's Bag tab lists them.
-- Plain data only so Lune tests can load this file.
return {
	MAX_STACK = 9999,
	ITEMS = {
		starShard = {
			name = "Star Shard",
			icon = "Shard", -- a Config/UIIcons name (or an emoji)
			description = "Counts as one duplicate when condensing any card.",
			source = "Frontier monsters · 3% (elites 10%)",
			use = "Card Condenser → Use Star Shards (covers up to half of a star)",
		},
		-- Boss ladder (Config/Bosses): fragments open the next boss, the rest help you climb. Account-bound.
		fragment_caveBroodQueen = {
			name = "Brood Queen Key Fragment",
			icon = "🔑",
			description = "3 of these open the Cave Brood Queen's arena.",
			source = "Meadow Warden (boss)",
			use = "Opens the Cave Brood Queen the first time you fight her",
		},
		fragment_emberColossus = {
			name = "Colossus Key Fragment",
			icon = "🔑",
			description = "5 of these open the Ember Colossus's arena.",
			source = "Cave Brood Queen (boss)",
			use = "Opens the Ember Colossus the first time you fight it",
		},
		xpTonic = {
			name = "XP Tonic",
			icon = "🧪",
			description = "Gives one creature 400 XP.",
			source = "Meadow Warden, Cave Brood Queen, Ember Colossus (bosses)",
			use = "Party panel → XP Tonic on a party card",
			xp = 400,
		},
		gradingSeal = {
			name = "Grading Seal",
			icon = "🏅",
			description = "Counts as one duplicate at the Grading Station.",
			source = "Ember Colossus (boss)",
			use = "Grading Station → Use Grading Seals (covers up to half a step)",
		},
		trophy_meadowWarden = {
			name = "Meadow Warden Trophy",
			icon = "🏆",
			description = "For beating the Meadow Warden.",
			source = "Meadow Warden, first win",
			use = "Build → Trophies: place it in your shop",
			trophy = true,
		},
		trophy_caveBroodQueen = {
			name = "Brood Queen Trophy",
			icon = "🏆",
			description = "For beating the Cave Brood Queen.",
			source = "Cave Brood Queen, first win",
			use = "Build → Trophies: place it in your shop",
			trophy = true,
		},
		trophy_emberColossus = {
			name = "Ember Colossus Trophy",
			icon = "🏆",
			description = "For beating the Ember Colossus.",
			source = "Ember Colossus, first win",
			use = "Build → Trophies: place it in your shop",
			trophy = true,
		},
	},
}
