--!strict
-- Shop variety (owner 2026-11-24: "any idea how to make them buy and display all products?", picks 1 and 2; spec
-- 2026-11-24-shop-variety-design): "Found it all!", a customer who finds every product on their list paying a little
-- more (Config/Customers FOUND_ALL), and the word a customer uses for a product they missed (Config/Offline PLURALS).
-- CustomerService pays and says it; the rating's half of variety is RatingRules.stocked. Pure (tests/VarietyRules).
local VarietyRules = {}

-- Whether a customer of `kind` with this `list` (product ids, repeats allowed) found it all: a FOUND_ALL type, at least
-- `minProducts` different products listed, and some of every one in `bought`
function VarietyRules.foundAll(cfg: any, kind: string, list: { string }, bought: { [string]: boolean }): boolean
	local rule = cfg.FOUND_ALL
	if not rule.types[kind] then
		return false
	end
	local seen: { [string]: boolean } = {}
	local distinct = 0
	for _, productId in list do
		if not seen[productId] then
			seen[productId] = true
			distinct += 1
			if not bought[productId] then
				return false
			end
		end
	end
	return distinct >= rule.minProducts
end

-- The bonus on `total` (what their products came to): FOUND_ALL.share of it, to the cent, never below 0
function VarietyRules.bonus(cfg: any, total: number): number
	return math.max(0, math.round(total * cfg.FOUND_ALL.share * 100) / 100)
end

-- The toast beside the cash: "Found it all! +$4.20"
function VarietyRules.toast(cfg: any, bonus: number): string
	return string.format(cfg.FOUND_ALL.toast, bonus)
end

-- What a customer calls a product they missed ("No sleeves? Aww."): its plural (Config/Offline PLURALS), "things"
-- for one without
function VarietyRules.word(plurals: { [string]: string }, productId: string): string
	return plurals[productId] or "things"
end

return VarietyRules
