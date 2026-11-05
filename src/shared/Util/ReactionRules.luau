--!strict
-- Customer reactions (spec 2026-11-06-customers-design): which cards on display make a passing customer stop with a
-- "whoa", how many can watch one at once, and whether a customer near your creature stops to pet it. Pure
-- (Lune-tested): reads Config/Customers REACTIONS, passed in as cfg.
local ReactionRules = {}

export type ShownCard = { rarity: string, foil: boolean }

-- Epic, Legendary or any foil
function ReactionRules.drawsAWhoa(card: ShownCard): boolean
	return card.foil or card.rarity == "Epic" or card.rarity == "Legendary"
end

-- Whether one more customer can stop at a card `watching` already watch: a Legendary holds a small crowd, others one
function ReactionRules.room(cfg: any, watching: number, card: ShownCard): boolean
	local limit = if card.rarity == "Legendary" then cfg.REACTIONS.crowd else 1
	return watching < limit
end

-- Whether a customer `distance` studs from your summoned creature stops to pet it
function ReactionRules.pets(cfg: any, distance: number, roll: number): boolean
	local reactions = cfg.REACTIONS
	return distance <= reactions.petReach and roll < reactions.petChance
end

return ReactionRules
