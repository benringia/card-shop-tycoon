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
	Legendary = { B = { copies = 1, cash = 2000 }, A = { copies = 2, cash = 10000 }, S = { copies = 3, cash = 40000 } },
}

return {
	COSTS = COSTS,
	ACTION_COOLDOWN = 0.5, -- seconds between grade-up requests per player (server)
	USE_DISTANCE = 12, -- studs: how close the owner must stand to use it (server check, panel closes past it)
	IN_FLIGHT_TIMEOUT = 2, -- seconds the Grade Up button stays locked waiting for the server (client)
}
