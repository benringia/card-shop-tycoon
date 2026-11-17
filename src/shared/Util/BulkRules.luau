--!strict
-- The Bulk Bin's rules (Config/Bulk; owner 2026-11-17, "lets do C"): which binder copies are extras, how many whole
-- handfuls fit a bin, which copies go first, and whether a customer asks for a handful. Pure (no requires, no Roblox
-- APIs): callers pass the config and the card lookups in; BulkService and CustomerService use it.
local BulkRules = {}

export type Owned = { normal: number, foil: number }
export type Stacks = { [string]: { [string]: Owned } } -- cardId -> grade -> counts (CardService.GetStacks)
export type Take = { cardId: string, grade: string, count: number }
type Config = { KEEP: number, RARITIES: { [string]: boolean }, GRADES: { [string]: boolean }, GRADE_ORDER: { string } }

local function whole(value: any): number
	return if typeof(value) == "number" and value == value and value > 0 then math.floor(value) else 0
end

-- The extra copies a bin can take from `stacks`: per card of a bulk rarity, its plain (never foil) copies past the
-- `KEEP` best ones (by GRADE_ORDER, best first), of a bulk grade only. Plainest grade first, then by card id, so the
-- same binder always gives the same list. Returns the takes and how many cards they hold.
function BulkRules.extras(stacks: Stacks, rarityOf: (cardId: string) -> string?, config: Config): ({ Take }, number)
	local takes: { Take } = {}
	local total = 0
	local ids = {}
	for cardId in stacks do
		table.insert(ids, cardId)
	end
	table.sort(ids)
	for _, cardId in ids do
		local rarity = rarityOf(cardId)
		if rarity and config.RARITIES[rarity] then
			local byGrade = stacks[cardId]
			local keep = config.KEEP
			for _, grade in config.GRADE_ORDER do
				local owned = byGrade[grade]
				local copies = if owned then whole(owned.normal) else 0
				local kept = math.min(copies, keep)
				keep -= kept
				local spare = copies - kept
				if spare > 0 and config.GRADES[grade] then
					table.insert(takes, { cardId = cardId, grade = grade, count = spare })
					total += spare
				end
			end
		end
	end
	-- the plainest grade first (the last in GRADE_ORDER), then by card id
	local rank = {}
	for index, grade in config.GRADE_ORDER do
		rank[grade] = index
	end
	table.sort(takes, function(a, b)
		if a.grade ~= b.grade then
			return (rank[a.grade] or 0) > (rank[b.grade] or 0)
		end
		return a.cardId < b.cardId
	end)
	return takes, total
end

-- How many whole handfuls of `per` the `extras` make in a bin with `room` handfuls free, and how many cards that is
function BulkRules.fill(extras: number, room: number, per: number): (number, number)
	if per <= 0 then
		return 0, 0
	end
	local handfuls = math.max(0, math.min(whole(extras) // per, whole(room)))
	return handfuls, handfuls * per
end

-- The first `cards` copies of `takes` (they're plainest first): exactly the cards going in
function BulkRules.trim(takes: { Take }, cards: number): { Take }
	local chosen: { Take } = {}
	local left = whole(cards)
	for _, take in takes do
		if left <= 0 then
			break
		end
		local taken = math.min(take.count, left)
		table.insert(chosen, { cardId = take.cardId, grade = take.grade, count = taken })
		left -= taken
	end
	return chosen
end

-- Whether a customer of `kind` adds a handful to their list (`roll` 0-1): only while one of the shop's bins has some
function BulkRules.wants(kind: string, binStocked: boolean, roll: number, chances: { [string]: number }): boolean
	local chance = chances[kind]
	return binStocked and chance ~= nil and roll < chance
end

return BulkRules
