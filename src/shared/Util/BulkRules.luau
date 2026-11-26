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
-- same binder always gives the same list. The cards in `keepOut` give none (the window's taps: owner 2026-11-26, pick
-- B). Returns the takes and how many cards they hold.
function BulkRules.extras(stacks: Stacks, rarityOf: (cardId: string) -> string?, config: Config, keepOut: { [string]: boolean }?): ({ Take }, number)
	local takes: { Take } = {}
	local total = 0
	local ids = {}
	for cardId in stacks do
		table.insert(ids, cardId)
	end
	table.sort(ids)
	for _, cardId in ids do
		local rarity = rarityOf(cardId)
		if rarity and config.RARITIES[rarity] and not (keepOut and keepOut[cardId]) then
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

-- The Bulk Bin window (owner 2026-11-26: "Currently with one click all your commons are gone. make the player use it
-- display a window. so that they will know what they putting on it", pick B: tap a card to keep it out). Its tiles:
-- each card's extras added up, the most first (a tie by card id)
export type Tile = { cardId: string, count: number }

function BulkRules.byCard(takes: { Take }): { Tile }
	local totals: { [string]: number } = {}
	for _, take in takes do
		totals[take.cardId] = (totals[take.cardId] or 0) + whole(take.count)
	end
	local tiles: { Tile } = {}
	for cardId, count in totals do
		if count > 0 then
			table.insert(tiles, { cardId = cardId, count = count })
		end
	end
	table.sort(tiles, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.cardId < b.cardId
	end)
	return tiles
end

-- The cards the client keeps out (Remotes.FillBulkBin's list of card ids), as a set; nil (refused) for anything but a
-- plain list of at most `max` strings. Ids that are no card keep nothing out. Nothing sent: none kept out.
function BulkRules.readKeepOut(value: unknown, isCard: (cardId: string) -> boolean, max: number): { [string]: boolean }?
	local set: { [string]: boolean } = {}
	if value == nil then
		return set
	elseif typeof(value) ~= "table" then
		return nil
	end
	local list = value :: { [any]: any }
	local count = 0
	for key, cardId in list do
		count += 1
		if typeof(key) ~= "number" or typeof(cardId) ~= "string" or count > max then
			return nil
		end
		if isCard(cardId) then
			set[cardId] = true
		end
	end
	if count ~= #list then
		return nil -- gaps or named keys: not a plain list
	end
	return set
end

-- The window's footer and button: `extras` the copies not kept out, `kept` the cards kept out, `room` the handfuls the
-- bin still has room for, `per` cards to a handful, `keep` copies always kept of each card. `cards` go in now as
-- `handfuls`; `ready`: the button works.
export type Words = { title: string, line: string, button: string, ready: boolean, cards: number, handfuls: number }

function BulkRules.words(view: { extras: number, kept: number, room: number, per: number, keep: number }): Words
	local handfuls, cards = BulkRules.fill(view.extras, view.room, view.per)
	local none = { title = "", line = "", button = "Nothing to put in", ready = false, cards = 0, handfuls = 0 }
	if whole(view.room) <= 0 then
		none.title, none.line, none.button = "This bin is full", "Customers buy the handfuls one at a time, or place another bin.", "Bin full"
		return none
	elseif whole(view.extras) <= 0 and whole(view.kept) <= 0 then
		none.title, none.line = "No extra Commons yet", `The bin takes Commons past the {view.keep} you keep of each card.`
		return none
	elseif whole(view.extras) <= 0 then
		none.title, none.line = "Every card is kept out", "Tap a card to put it back in."
		return none
	elseif handfuls <= 0 then
		none.title, none.line = "Not enough for a handful yet", `A handful is {view.per} cards.`
		return none
	end
	local parts: { string } = {}
	if whole(view.kept) > 0 then
		table.insert(parts, `{whole(view.kept)} kept out`)
	end
	local left = whole(view.extras) - cards
	if left > 0 then
		table.insert(parts, `{left} stay in your binder`)
	end
	table.insert(parts, `customers buy them {view.per} at a time`)
	return {
		title = `{cards} cards = {handfuls} handful{if handfuls == 1 then "" else "s"}`,
		line = table.concat(parts, " · "),
		button = `Put {cards} in`,
		ready = true,
		cards = cards,
		handfuls = handfuls,
	}
end

return BulkRules
