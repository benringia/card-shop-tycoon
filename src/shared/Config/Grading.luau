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
	-- The grade swap (owner 2026-11-20: a player raised a Grade C card to 5 stars and then pulled a Grade S copy; "okay
	-- do the grade swap. but make it a little more expensive"): a levelled or starred card takes the grade of your best
	-- spare copy of the same card. The spare is used up, and it costs `share` of the grading cash between the two
	-- grades, rounded to `round` (Legendary C to S: $5,430 against $15,500 and 6 copies; a Common's $1,090). Stars and
	-- levels never move. CondenseRules.swapPlan, CardService.GradeUp `swap`.
	SWAP = { share = 0.35, round = 10 },
	ACTION_COOLDOWN = 0.5, -- seconds between grade-up requests per player (server)
	USE_DISTANCE = 12, -- studs: how close the owner must stand to use it (server check, panel closes past it)
	IN_FLIGHT_TIMEOUT = 2, -- seconds the Grade Up button stays locked waiting for the server (client)
	-- The window's words (owner 2026-11-20: "check the other machines ... for pain points/ confusing elements")
	EXPLAIN = "Extra copies and cash raise a card's grade: more Power. Grade S is the best!",
	DONE_HEADING = "Fresh from the Grading Station!",
}
