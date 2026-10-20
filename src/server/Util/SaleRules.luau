--!strict
-- Checks a player-to-player buy against what the buyer confirmed, so a seller can't swap in a
-- different copy (another grade, foil or levelled card) or change the price while the buy is in flight.
-- Pure (no requires, no Roblox APIs) so tests/ can run it in Lune.
local SaleRules = {}

local PRICE_TOLERANCE = 0.001 -- floating point slack when comparing the price the buyer saw
local DEFAULT_GRADE = "C" -- matches Config/Beasts DEFAULT_GRADE; a missing expected grade means a plain C

export type Listing = { cardId: string, foil: boolean, grade: string, price: number, beastId: string? }

-- "ok", "gone" (a different copy is in the slot now) or "price" (same copy, new price).
-- expected comes from the client, so every field is untrusted.
function SaleRules.check(current: Listing, expected: { [string]: any }): string
	local wantedGrade = if typeof(expected.grade) == "string" then expected.grade else DEFAULT_GRADE
	local wantedBeastId = if typeof(expected.beastId) == "string" then expected.beastId else nil
	if current.cardId ~= expected.cardId or current.foil ~= expected.foil then
		return "gone"
	end
	if current.grade ~= wantedGrade or current.beastId ~= wantedBeastId then
		return "gone"
	end
	if typeof(expected.price) ~= "number" or math.abs(current.price - expected.price) > PRICE_TOLERANCE then
		return "price"
	end
	return "ok"
end

return SaleRules
