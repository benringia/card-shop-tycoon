--!strict
-- Grading Station: raises one copy's grade a step (C -> B -> A -> S) for plain duplicates of the same card plus
-- cash, the sure (slow) path to Grade S next to the lucky pull. Which copies are used: Util/GradeRules. DESIGN.md 5.9.
export type Step = { copies: number, cash: number }

-- What each step costs, by the card's rarity and the grade it goes up to
local COSTS: { [string]: { [string]: Step } } = {
	Common = { B = { copies = 2, cash = 100 }, A = { copies = 4, cash = 500 }, S = { copies = 8, cash = 2500 } },
	Rare = { B = { copies = 2, cash = 100 }, A = { copies = 4, cash = 500 }, S = { copies = 8, cash = 2500 } },
	["Very Rare"] = { B = { copies = 2, cash = 250 }, A = { copies = 3, cash = 1000 }, S = { copies = 6, cash = 5000 } },
	Epic = { B = { copies = 1, cash = 500 }, A = { copies = 2, cash = 2500 }, S = { copies = 4, cash = 10000 } },
	Legendary = { B = { copies = 1, cash = 500 }, A = { copies = 2, cash = 2500 }, S = { copies = 3, cash = 12500 } },
}

return {
	COSTS = COSTS,
	MAX_SEAL_SHARE = 0.5, -- Grading Seals cover at most this share of a step's duplicates (like Star Shards)
	-- (The grade swap, 2026-11-20, left with the window's redesign: owner 2026-11-26, "drop both")
	ACTION_COOLDOWN = 0.5, -- seconds between grade-up requests per player (server)
	USE_DISTANCE = 12, -- studs: how close the owner must stand to use it (server check, panel closes past it)
	IN_FLIGHT_TIMEOUT = 2, -- seconds the Grade Up button stays locked waiting for the server (client)
	-- The window's words (owner 2026-11-26: "there should be an "Upgrade" tab where the player put the specific card
	-- they want to upgrade, then, the option to use upgrade materialls will then show the user. remove search"; the
	-- recipe's own words: Util/CondenseRules gradeSay, gradeButton, copiesTile, sealTile, goldTile)
	WINDOW = {
		TABS = { "Upgrade", "Ready" },
		SLOT = "Put a card in",
		SLOT_SUB = "Tap to pick one",
		CHANGE = "Change card",
		EMPTY_SAY = "Put in the card you want to grade up.",
		EMPTY_SUB = "Then pick what to use: its extra copies, Grading Seals or a Gold Seal.",
		EMPTY_BUTTON = "Upgrade",
		USE = "USE",
		PICK_TITLE = "Pick a card to grade up",
		PICK_SUB = "Your cards with extra copies. Ready ones first: they can go up a grade now.",
		PICK_NONE = "Get two or more copies of a card to grade it up. Rip more packs!",
		READY_SUB = "These can go up a grade now. Tap one to put it in.",
		READY_NONE = "Nothing is ready yet. Find more copies, then come back!",
	},
	DONE_HEADING = "Fresh from the Grading Station!",
}
