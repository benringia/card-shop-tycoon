--!strict
-- Card Condenser: combines duplicates of a card into one main copy for +1 star.
-- Star costs live in Config/Beasts (STAR_COSTS); which copies are used is in Util/CondenseRules.
return {
	ACTION_COOLDOWN = 0.5, -- seconds between condense requests per player (server)
	USE_DISTANCE = 12, -- studs: how close the owner must stand to use it (server check, panel closes past it)
	IN_FLIGHT_TIMEOUT = 2, -- seconds the Condense button stays locked waiting for the server (client)
	-- The window's words (owner 2026-11-26: "remove the "ALL" tabs and "Need Copies tap". The first tab is now
	-- "Condense" or something where the players put the card they want to condense. the condenser then autofills the
	-- extra cards(weakest)"; the recipe's own words: Util/CondenseRules say, fillChip, buttonWords)
	WINDOW = {
		TABS = { "Condense", "Ready" },
		SLOT = "Put a card in",
		SLOT_SUB = "Tap to pick one",
		CHANGE = "Change card",
		EMPTY_SAY = "Put in the card you want to give a star.",
		EMPTY_SUB = "The Condenser finds its extra copies for you, the weakest first.",
		EMPTY_BUTTON = "Add a star!",
		OTHER = "Pick other copies", -- which copy gets the star (the copy picker), beside its +Power
		PICK_TITLE = "Pick a card to condense",
		PICK_SUB = "Your cards with extra copies. Ready ones first: they can get a star now.",
		PICK_NONE = "No extra copies yet. Rip more packs!",
		READY_SUB = "These can get a star now. Tap one to put it in.",
		READY_NONE = "Nothing is ready yet. Find more copies, then come back!",
	},
	-- The heading of a finished star's reveal (client Util/DoneReveal; its numbers are Config/Upgrades REVEAL)
	DONE_HEADING = "Fresh out of the Condenser!",
}
