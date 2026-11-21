--!strict
-- Every item a player can hold. Saved as items = { [itemId] = count } (whole numbers, up to MAX_STACK).
-- Add an entry here for a new item; ItemService gives and takes them, the binder's Bag tab lists them. Its words
-- (description: what it does, source: where to get it, use: how to use it) are written so a child understands them
-- (owner 2026-11-14): short, plain, no trading-card jargon (tests/ItemRules).
-- Plain data only so Lune tests can load this file.
return {
	MAX_STACK = 9999,
	ITEMS = {
		starShard = {
			name = "Star Shard",
			icon = "Shard", -- a Config/UIIcons name (or an emoji)
			description = "Works like a spare copy of any card when you add a star to it.",
			source = "Frontier monsters · 3% (elites 10%)",
			use = "At the Card Condenser, tap Use Star Shards. They can fill up to half of a star.",
		},
		-- Boss ladder (Config/Bosses): fragments open the next boss, the rest help you climb. Account-bound. Every key
		-- fragment and trophy has its own picture (Config/UIIcons sheet 10, owner 2026-11-14)
		fragment_caveBroodQueen = {
			name = "Brood Queen Key Fragment",
			icon = "KeyBrood",
			description = "Collect 3 to unlock the Cave Brood Queen's arena.",
			source = "Meadow Warden (boss)",
			use = "Opens the Cave Brood Queen the first time you fight her",
		},
		fragment_emberColossus = {
			name = "Colossus Key Fragment",
			icon = "KeyColossus",
			description = "Collect 5 to unlock the Ember Colossus's arena.",
			source = "Cave Brood Queen (boss)",
			use = "Opens the Ember Colossus the first time you fight it",
		},
		fragment_frostTyrant = {
			name = "Frost Tyrant Key Fragment",
			icon = "KeyFrost",
			description = "Collect 5 to unlock the Frost Tyrant's arena in the Frontier.",
			source = "Ember Colossus (boss)",
			use = "Opens the Frost Tyrant the first time you fight it",
		},
		fragment_stormSovereign = {
			name = "Sovereign Key Fragment",
			icon = "KeyStorm",
			description = "Collect 8 to unlock the Storm Sovereign's arena in the Frontier.",
			source = "Frost Tyrant (boss)",
			use = "Opens the Storm Sovereign the first time you fight it",
		},
		fragment_riftDevourer = {
			name = "Devourer Key Fragment",
			icon = "KeyRift",
			description = "Collect 8 to unlock the Rift Devourer's arena in the Frontier.",
			source = "Storm Sovereign (boss)",
			use = "Opens the Rift Devourer the first time you fight it",
		},
		fragment_prismHydra = {
			name = "Hydra Key Fragment",
			icon = "KeyHydra",
			description = "Collect 10 to unlock the Prism Hydra in the Dungeon.",
			source = "Rift Devourer (boss)",
			use = "Opens the Prism Hydra the first time you fight it",
		},
		-- Weapons (Config/Weapons): each boss's weapon material (full loot only, 80%, 1-2; its daily chest 2) and Wild
		-- Ore for the Forge weapons. Account-bound. Their icons: Config/UIIcons sheet 7 (weapons round 1).
		material_meadowWarden = {
			name = "Warden Heartwood",
			icon = "WardenHeartwood",
			description = "Used to make and upgrade the Verdant Blade, Sunforged Blade and Titan's Lance.",
			source = "Meadow Warden (boss) · full loot",
			use = "Bring it to the Forge in your shop",
		},
		material_caveBroodQueen = {
			name = "Brood Silk",
			icon = "BroodSilk",
			description = "Used to make and upgrade the Widow's Reaper and Sunforged Blade.",
			source = "Cave Brood Queen (boss) · full loot",
			use = "Bring it to the Forge in your shop",
		},
		material_emberColossus = {
			name = "Colossus Core",
			icon = "ColossusCore",
			description = "Used to make and upgrade the Magma Halberd and Sunforged Blade.",
			source = "Ember Colossus (boss) · full loot",
			use = "Bring it to the Forge in your shop",
		},
		material_frostTyrant = {
			name = "Frost Heart",
			icon = "FrostHeart",
			description = "Used to make and upgrade the Tidal Trident and Titan's Lance.",
			source = "Frost Tyrant (boss) · full loot",
			use = "Bring it to the Forge in your shop",
		},
		material_stormSovereign = {
			name = "Storm Crystal",
			icon = "StormCrystal",
			description = "Used to make and upgrade the Storm Reaper and Titan's Lance.",
			source = "Storm Sovereign (boss) · full loot",
			use = "Bring it to the Forge in your shop",
		},
		material_riftDevourer = {
			name = "Rift Shard",
			icon = "RiftShard",
			description = "Used to make and upgrade the Rift Reaper.",
			source = "Rift Devourer (boss) · full loot",
			use = "Bring it to the Forge in your shop",
		},
		material_prismHydra = {
			name = "Prism Scale",
			icon = "PrismScale",
			description = "Used to make and upgrade the Prism Blade.",
			source = "Prism Hydra (boss) · full loot",
			use = "Bring it to the Forge in your shop",
		},
		wildOre = {
			name = "Wild Ore",
			icon = "WildOre",
			description = "Used to make and upgrade the Forge Sword, Forge Spear and Forge Scythe.",
			source = "Wild and Frontier monsters · 15% (elites 60%) · shop level gifts",
			use = "Bring it to the Forge in your shop",
		},
		-- Shop level gifts (Config/Levels GIFTS) and your own stock: opened from the Bag (remote OpenBagPack,
		-- LevelUpService). `stock`: the shop product it is. A carried box of it goes in the Bag (the To Bag tile, remote
		-- BagBox, StockService; owner 2026-11-17: "put all the cardpacks inside the box to their inventory ... they will
		-- never have to go back to the delivery to pickup packs to rip"), and opening one gives its market price in shop
		-- XP, like ripping it from the box
		sparkPack = {
			name = "First Spark Pack",
			icon = "FirstSparkPack",
			description = "A pack of First Spark cards. Open it to see what you get!",
			source = "Your shop's stock (carry a box, tap To Bag) · shop level gifts",
			use = "Open your Bag and tap Open",
			open = "FirstSparkPack", -- the Config/Packs product it opens
			stock = "FirstSparkPack",
			-- its Bag button that puts a box of them back on your delivery pad to sell (owner 2026-11-20: "Cards in
			-- your inventory should also be placed in shelves by players"; remote ShopBagStock, StockService)
			shop = "To shop",
		},
		deckBox = {
			name = "First Spark Deck Box",
			icon = "FirstSparkDeck",
			description = "A box of 5 First Spark cards. One is always Very Rare or better!",
			source = "Your shop's stock (carry a box, tap To Bag)",
			use = "Open your Bag and tap Open",
			open = "DeckBox",
			stock = "DeckBox",
			shop = "To shop",
		},
		-- Pish's present at the start of the first visit (spec 2026-11-09-tutorial-pish-design 15): a First Spark pack with
		-- his picture (owner: "we need an icon for pish's gift. that will make players excited")
		pishPresent = {
			name = "Pish's Present",
			icon = "PishPresent",
			description = "A pack of cards from Pish to start your shop. Open it!",
			source = "Pish, at the start of your first visit",
			use = "Open your Bag and tap Open",
			open = "FirstSparkPack",
		},
		-- Pish's gift at the end of the first visit (spec 2026-11-09-tutorial-pish-design 5): opened from the Bag like the
		-- level-up pack, its hit card Very Rare or better (`floor`, Util/LuckRules.atLeast)
		pishGift = {
			name = "Pish's Gift",
			icon = "PishGift",
			description = "A pack of cards from Pish. The last card is Very Rare or even better!",
			source = "Pish, at the end of your first visit",
			use = "Open your Bag and tap Open",
			open = "FirstSparkPack",
			floor = "Very Rare",
		},
		-- Turts' rug shop's packs (spec 2026-11-13-turts-shop-design, Config/Turts): First Spark packs opened from the Bag,
		-- the hit card at least the pack's tier; the Legendary Pack's Legendary rolls the stingy pity grades (`stingyGrade`)
		vrPack = {
			name = "Very Rare Pack",
			icon = "PackVeryRare",
			description = "A pack of cards. The last card is always Very Rare or better!",
			source = "Turts' rug shop",
			use = "Open your Bag and tap Open",
			open = "FirstSparkPack",
			floor = "Very Rare",
		},
		epicPack = {
			name = "Epic Pack",
			icon = "PackEpic",
			description = "A pack of cards. The last card is always Epic or better!",
			source = "Turts' rug shop",
			use = "Open your Bag and tap Open",
			open = "FirstSparkPack",
			floor = "Epic",
		},
		legendaryPack = {
			name = "Legendary Pack",
			icon = "PackLegendary",
			description = "A pack of cards. The last card is always a Legendary!",
			source = "Turts' rug shop",
			use = "Open your Bag and tap Open",
			open = "FirstSparkPack",
			floor = "Legendary",
			stingyGrade = true,
		},
		goldSeal = {
			name = "Gold Seal",
			icon = "GoldSeal",
			description = "Pays the cash to grade a card up once, like C to B. Not for a Legendary from A to S.",
			source = "A rare drop from the Storm Sovereign, Rift Devourer and Prism Hydra · shop level gifts",
			use = "At the Grading Station, tap Gold Seals: one pays the cash for that grade.",
		},
		-- Boss trophies: placed in your shop straight from the Bag with Place (ItemRules.placesInShop,
		-- BuildController.PlaceTrophy; owner 2026-11-17), no longer from the Shop's Build menu
		trophy_frostTyrant = {
			name = "Frost Tyrant Trophy",
			icon = "TrophyFrost",
			description = "You won this by beating the Frost Tyrant! Put it in your shop to show it off.",
			source = "Frost Tyrant, first win",
			use = "In your Bag, tap Place and put it in your shop",
			trophy = true,
		},
		trophy_stormSovereign = {
			name = "Storm Sovereign Trophy",
			icon = "TrophyStorm",
			description = "You won this by beating the Storm Sovereign! Put it in your shop to show it off.",
			source = "Storm Sovereign, first win",
			use = "In your Bag, tap Place and put it in your shop",
			trophy = true,
		},
		trophy_riftDevourer = {
			name = "Rift Devourer Trophy",
			icon = "TrophyRift",
			description = "You won this by beating the Rift Devourer! Put it in your shop to show it off.",
			source = "Rift Devourer, first win",
			use = "In your Bag, tap Place and put it in your shop",
			trophy = true,
		},
		trophy_prismHydra = {
			name = "Prism Hydra Trophy",
			icon = "TrophyHydra",
			description = "You won this by beating the Prism Hydra in the Dungeon! Show it off in your shop.",
			source = "Prism Hydra, first win",
			use = "In your Bag, tap Place and put it in your shop",
			trophy = true,
		},
		xpTonic = {
			name = "XP Tonic",
			icon = "XpTonic",
			description = "Gives one of your creatures 120 XP to help it level up.",
			source = "Meadow Warden, Cave Brood Queen, Ember Colossus (bosses) · shop level gifts",
			use = "In your Bag, tap Use and pick a creature from your party",
			xp = 120, -- owner 2026-11-20: "Reduce exp tonic exp to 120" (300 since 2026-11-17, 400 before)
		},
		gradingSeal = {
			name = "Grading Seal",
			icon = "GradingSeal",
			description = "Works like a spare copy of a card when you grade it up.",
			source = "Ember Colossus, Frost Tyrant (bosses)",
			use = "At the Grading Station, tap Grading Seals (or an empty spot) to put them in. They can fill up to half the copies a grade needs.",
		},
		trophy_meadowWarden = {
			name = "Meadow Warden Trophy",
			icon = "TrophyWarden",
			description = "You won this by beating the Meadow Warden! Put it in your shop to show it off.",
			source = "Meadow Warden, first win",
			use = "In your Bag, tap Place and put it in your shop",
			trophy = true,
		},
		trophy_caveBroodQueen = {
			name = "Brood Queen Trophy",
			icon = "TrophyBrood",
			description = "You won this by beating the Cave Brood Queen! Put it in your shop to show it off.",
			source = "Cave Brood Queen, first win",
			use = "In your Bag, tap Place and put it in your shop",
			trophy = true,
		},
		trophy_emberColossus = {
			name = "Ember Colossus Trophy",
			icon = "TrophyColossus",
			description = "You won this by beating the Ember Colossus! Put it in your shop to show it off.",
			source = "Ember Colossus, first win",
			use = "In your Bag, tap Place and put it in your shop",
			trophy = true,
		},
	},
}
