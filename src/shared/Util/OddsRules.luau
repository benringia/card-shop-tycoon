--!strict
-- Pull odds for the rarity guide, worked out from a pack's slot weights (pure, Lune-tested), so the guide
-- always matches the real rolls in Config/Packs.
export type Weighted = { rarity: string, weight: number }
export type PackSlots = { slots: { { Weighted } } }

local OddsRules = {}

-- Chance that one card pulled from this pack is each rarity: each slot's weights scaled to 1, averaged
function OddsRules.perCard(pack: PackSlots): { [string]: number }
	local odds: { [string]: number } = {}
	local slotCount = #pack.slots
	if slotCount == 0 then
		return odds
	end
	for _, slot in pack.slots do
		local total = 0
		for _, option in slot do
			total += option.weight
		end
		if total > 0 then
			for _, option in slot do
				odds[option.rarity] = (odds[option.rarity] or 0) + option.weight / total / slotCount
			end
		end
	end
	return odds
end

-- How many cards of a rarity one pack gives on average (each slot's chance of it, added up); for a rare hit
-- that is near enough the chance a pack has one
function OddsRules.perPack(pack: PackSlots, rarity: string): number
	local expected = 0
	for _, slot in pack.slots do
		local total, hit = 0, 0
		for _, option in slot do
			total += option.weight
			if option.rarity == rarity then
				hit += option.weight
			end
		end
		if total > 0 then
			expected += hit / total
		end
	end
	return expected
end

-- "About 1 in N cards" (never: math.huge)
function OddsRules.oneIn(chance: number): number
	if chance <= 0 then
		return math.huge
	end
	return math.floor(1 / chance + 0.5)
end

return OddsRules
