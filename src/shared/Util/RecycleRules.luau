--!strict
-- The Recycler's rules (Config/Recycler; owner 2026-11-21, "can we have add a recycler. that can make extra cards turn
-- into upgrade materials. make sure the costs are fair", layout A): which binder copies are extras, how many
-- materials a pile makes, which copies go, and the window's words. Pure (no requires, no Roblox APIs): callers pass
-- the configs and the card lookups in; RecyclerService and the client's RecyclerController use it, so the window
-- shows exactly what the server will do (tests/RecycleRules). Never a creature (owner 2026-11-21: "make sure players
-- cant accidentally recycle their most powerful creatures. or the creatures they've been using"): only plain copies
-- go, a card keeps the copies its creatures can still use, and the server takes no copy the player didn't see in the
-- list they confirmed (`trimToShown`).
local RecycleRules = {}

export type Take = { cardId: string, grade: string, count: number }
export type Pile = { rarity: string, takes: { Take }, count: number }
export type Gain = { item: string, count: number }
type Recipe = { per: number, item: string }
type Config = {
	ORDER: { string },
	RECIPES: { [string]: Recipe },
	COINS: { [string]: number },
	MODES: { string },
	SECONDS: { [string]: number },
	SECONDS_PER_DOLLAR: number,
	MIN_SECONDS: number,
	MAX_SECONDS: number,
	SPARE: number,
	GRADES: { [string]: boolean },
	GRADE_ORDER: { string },
	PLURALS: { [string]: { string } },
	ITEM_WORDS: { [string]: { string } },
}
type BeastsConfig = { STAR_COSTS: { number }, MAX_STARS: number }
type GradingConfig = { COSTS: { [string]: { [string]: { copies: number, cash: number } } } }
type Stacks = { [string]: { [string]: any } }
type BeastFacts = { cardId: string, stars: number, grade: string }

local MAX_SHOWN = 300 -- lines in a confirmed list (a card and a grade each: 37 cards, two grades)
local MAX_SHOWN_COUNT = 1000000 -- copies on one line
local SHOWN_GRADES = { C = true, B = true } -- the grades that ever go (Config/Recycler GRADES)

local function whole(value: any): number
	return if typeof(value) == "number" and value == value and value > 0 and value ~= math.huge then math.floor(value) else 0
end

-- The copies a card of `rarity` still needs: the duplicates for the stars its best card is missing (`stars`: the most
-- stars any of its levelled cards has, 0 with none), the ones for the grades above its best (`bestGrade`), and SPARE
function RecycleRules.reserve(config: Config, beasts: BeastsConfig, grading: GradingConfig, rarity: string, stars: number, bestGrade: string): number
	local need = config.SPARE
	for star = math.max(0, math.floor(stars)) + 1, beasts.MAX_STARS do
		need += beasts.STAR_COSTS[star] or 0
	end
	local steps = grading.COSTS[rarity]
	local reached = false -- GRADE_ORDER is best first: every grade before `bestGrade` is one still to reach
	for _, grade in config.GRADE_ORDER do
		if grade == bestGrade then
			reached = true
		end
		local step = if steps then steps[grade] else nil
		if not reached and step then
			need += step.copies
		end
	end
	return need
end

-- The duplicates a creature of `rarity` still needs: the ones for the stars it is missing and for the grades over its
-- own (its reserve without the spare copies)
function RecycleRules.need(config: Config, beasts: BeastsConfig, grading: GradingConfig, rarity: string, stars: number, grade: string): number
	return RecycleRules.reserve(config, beasts, grading, rarity, stars, grade) - config.SPARE
end

-- The grades a creature of `grade` takes copies of, in the order it keeps them: its own and the ones under it (the
-- Condenser and the Grading Station never use a copy better than the card), then the ones over it from the lowest
-- up (a grade-up opens them)
function RecycleRules.useOrder(gradeOrder: { string }, grade: string): { string }
	local at = table.find(gradeOrder, grade) or #gradeOrder
	local order: { string } = {}
	for index = at, #gradeOrder do
		table.insert(order, gradeOrder[index])
	end
	for index = at - 1, 1, -1 do
		table.insert(order, gradeOrder[index])
	end
	return order
end

-- The plain copies of one card that stay, by grade (`owned`: its plain copies by grade): its SPARE best ones, then
-- what each of its creatures (`mains`: stars and grade) still needs from the copies it can use, the most any one of
-- them needs of each grade
function RecycleRules.keep(config: Config, beasts: BeastsConfig, grading: GradingConfig, rarity: string, owned: { [string]: number }, mains: { { stars: number, grade: string } }): { [string]: number }
	local keep: { [string]: number } = {}
	local left: { [string]: number } = {}
	for _, grade in config.GRADE_ORDER do
		keep[grade] = 0
		left[grade] = whole(owned[grade])
	end
	local spare = config.SPARE
	for _, grade in config.GRADE_ORDER do
		local take = math.min(left[grade], spare)
		keep[grade] += take
		left[grade] -= take
		spare -= take
	end
	local most: { [string]: number } = {}
	for _, main in mains do
		local need = RecycleRules.need(config, beasts, grading, rarity, main.stars, main.grade)
		for _, grade in RecycleRules.useOrder(config.GRADE_ORDER, main.grade) do
			local take = math.min(left[grade] or 0, need)
			most[grade] = math.max(most[grade] or 0, take)
			need -= take
		end
	end
	for grade, count in most do
		keep[grade] += count
	end
	return keep
end

-- The binder's extras by rarity (every rarity with a recipe has a pile, even an empty one). Per card: the plain copies
-- it keeps (RecycleRules.keep) stay; the rest, of a recycled grade only, are extras. A creature (`beasts`: every
-- levelled card the player has, in the binder, a station or a case: its card, stars and grade) is never a plain copy,
-- so it never goes; a card with none keeps a full kit for its best copy (0 stars, its grade). Foils never count and
-- never go. Takes come plainest grade first, then by card id, so the same binder always gives the same list.
function RecycleRules.piles(config: Config, beastsConfig: BeastsConfig, grading: GradingConfig, stacks: Stacks, beasts: { [any]: BeastFacts }, rarityOf: (cardId: string) -> string?): { [string]: Pile }
	local piles: { [string]: Pile } = {}
	for _, rarity in config.ORDER do
		piles[rarity] = { rarity = rarity, takes = {}, count = 0 }
	end
	local rank: { [string]: number } = {}
	for index, grade in config.GRADE_ORDER do
		rank[grade] = index
	end
	-- each card's creatures
	local mains: { [string]: { { stars: number, grade: string } } } = {}
	for _, beast in beasts do
		if typeof(beast) == "table" and typeof(beast.cardId) == "string" and rank[beast.grade] then
			mains[beast.cardId] = mains[beast.cardId] or {}
			table.insert(mains[beast.cardId], { stars = whole(beast.stars), grade = beast.grade })
		end
	end
	local ids = {}
	for cardId in stacks do
		table.insert(ids, cardId)
	end
	table.sort(ids)
	for _, cardId in ids do
		local rarity = rarityOf(cardId)
		local pile = if rarity then piles[rarity] else nil
		local byGrade = stacks[cardId]
		if pile and rarity and typeof(byGrade) == "table" then
			-- its plain copies, and its best copy (plain or foil) for a card with no creature
			local owned: { [string]: number } = {}
			local bestAt = math.huge
			for index, grade in config.GRADE_ORDER do
				local entry = byGrade[grade]
				local normal = if typeof(entry) == "table" then whole(entry.normal) else 0
				local foil = if typeof(entry) == "table" then whole(entry.foil) else 0
				owned[grade] = normal
				if normal + foil > 0 and index < bestAt then
					bestAt = index
				end
			end
			local bestGrade = config.GRADE_ORDER[bestAt] or config.GRADE_ORDER[#config.GRADE_ORDER]
			local keep = RecycleRules.keep(config, beastsConfig, grading, rarity, owned, mains[cardId] or { { stars = 0, grade = bestGrade } })
			for _, grade in config.GRADE_ORDER do
				local extra = owned[grade] - (keep[grade] or 0)
				if extra > 0 and config.GRADES[grade] then
					table.insert(pile.takes, { cardId = cardId, grade = grade, count = extra })
					pile.count += extra
				end
			end
		end
	end
	for _, pile in piles do
		table.sort(pile.takes, function(a, b)
			if a.grade ~= b.grade then
				return (rank[a.grade] or 0) > (rank[b.grade] or 0)
			end
			return a.cardId < b.cardId
		end)
	end
	return piles
end

-- The confirmed list (owner 2026-11-21: "make sure players cant accidentally recycle ..."): a press shows the cards that
-- will go first, and what the player confirmed caps what the server takes, card by card and grade by grade

local function shownKey(cardId: string, grade: string): string
	return `{cardId}:{grade}`
end

-- The list a press shows, as the client sends it: copies by "card:grade"
function RecycleRules.shownMap(takes: { Take }): { [string]: number }
	local shown: { [string]: number } = {}
	for _, take in takes do
		local key = shownKey(take.cardId, take.grade)
		shown[key] = (shown[key] or 0) + take.count
	end
	return shown
end

-- What a client sent as its confirmed list, checked (keys "card:grade" of a grade that goes, whole counts, a sane
-- size); nil when it isn't one
function RecycleRules.readShown(raw: any): { [string]: number }?
	if typeof(raw) ~= "table" then
		return nil
	end
	local shown: { [string]: number } = {}
	local lines = 0
	for key, count in raw do
		lines += 1
		if lines > MAX_SHOWN or typeof(key) ~= "string" then
			return nil
		end
		local grade = string.match(key, "^[%w_]+:(%u)$")
		if not grade or not SHOWN_GRADES[grade] then
			return nil
		end
		if typeof(count) ~= "number" or count ~= count or count < 1 or count ~= math.floor(count) or count > MAX_SHOWN_COUNT then
			return nil
		end
		shown[key] = count
	end
	return shown
end

-- The server's piles cut back to the confirmed list: no card or grade the player didn't see, never more of it
function RecycleRules.trimToShown(piles: { [string]: Pile }, shown: { [string]: number }): { [string]: Pile }
	local out: { [string]: Pile } = {}
	for rarity, pile in piles do
		local trimmed: Pile = { rarity = pile.rarity, takes = {}, count = 0 }
		for _, take in pile.takes do
			local count = math.min(take.count, shown[shownKey(take.cardId, take.grade)] or 0)
			if count > 0 then
				table.insert(trimmed.takes, { cardId = take.cardId, grade = take.grade, count = count })
				trimmed.count += count
			end
		end
		out[rarity] = trimmed
	end
	return out
end

-- The review's list: one line a card (its grades added up), the most first, then by card id
function RecycleRules.byCard(takes: { Take }): { { cardId: string, count: number } }
	local counts: { [string]: number } = {}
	for _, take in takes do
		counts[take.cardId] = (counts[take.cardId] or 0) + take.count
	end
	local list: { { cardId: string, count: number } } = {}
	for cardId, count in counts do
		table.insert(list, { cardId = cardId, count = count })
	end
	table.sort(list, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.cardId < b.cardId
	end)
	return list
end

-- The review's question: "Recycle these 52 cards?"
function RecycleRules.reviewSay(count: number): string
	if count == 1 then
		return "Recycle this card?"
	end
	return `Recycle these {RecycleRules.count(count)} cards?`
end

-- What `count` extras make at `per` to one: the materials made, the cards used (whole materials only), and how many
-- more cards the next one needs
function RecycleRules.make(count: number, per: number): (number, number, number)
	local have = whole(count)
	local each = math.max(1, whole(per))
	local made = have // each
	return made, made * each, each - have % each
end

-- The first `cards` copies of `takes` (they're plainest first): exactly the cards going in
function RecycleRules.trim(takes: { Take }, cards: number): { Take }
	local out: { Take } = {}
	local left = cards
	for _, take in takes do
		if left <= 0 then
			break
		end
		local count = math.min(take.count, left)
		table.insert(out, { cardId = take.cardId, grade = take.grade, count = count })
		left -= count
	end
	return out
end

-- What recycling does: the copies that go and the materials made, for one `rarity`'s pile or (nil) every pile in the
-- window's order, the same material added up. Nothing to make: both empty.
function RecycleRules.plan(config: Config, piles: { [string]: Pile }, rarity: string?): ({ Take }, { Gain })
	local takes: { Take } = {}
	local gains: { Gain } = {}
	local at: { [string]: number } = {}
	for _, name in config.ORDER do
		local recipe, pile = config.RECIPES[name], piles[name]
		if recipe and pile and (rarity == nil or rarity == name) then
			local made, used = RecycleRules.make(pile.count, recipe.per)
			if made > 0 then
				for _, take in RecycleRules.trim(pile.takes, used) do
					table.insert(takes, take)
				end
				local index = at[recipe.item]
				if index then
					gains[index].count += made
				else
					table.insert(gains, { item = recipe.item, count = made })
					at[recipe.item] = #gains
				end
			end
		end
	end
	return takes, gains
end

-- Coins instead (Config/Recycler COINS): the copies that go and the cash they pay, to the cent, for one `rarity`'s
-- pile or (nil) every pile. Every extra goes: there are no leftovers. Nothing to sell: no takes, 0.
function RecycleRules.coinPlan(config: Config, piles: { [string]: Pile }, rarity: string?): ({ Take }, number)
	local takes: { Take } = {}
	local cents = 0
	for _, name in config.ORDER do
		local each, pile = config.COINS[name], piles[name]
		if each and pile and pile.count > 0 and (rarity == nil or rarity == name) then
			for _, take in pile.takes do
				table.insert(takes, take)
			end
			cents += math.round(pile.count * each * 100)
		end
	end
	return takes, cents / 100
end

-- Whether `mode` is one of the window's (what a client sends)
function RecycleRules.modeOk(mode: any): boolean
	return mode == "materials" or mode == "coins"
end

-- How long a conversion takes: SECONDS for each material made and SECONDS_PER_DOLLAR for the cash, between
-- MIN_SECONDS and MAX_SECONDS, in whole seconds
function RecycleRules.seconds(config: Config, gains: { Gain }, cash: number): number
	local seconds = 0
	for _, gain in gains do
		seconds += (config.SECONDS[gain.item] or 0) * gain.count
	end
	seconds += math.max(0, cash) * config.SECONDS_PER_DOLLAR
	return math.clamp(math.round(seconds), config.MIN_SECONDS, config.MAX_SECONDS)
end

-- What goes in the station (UpgradeJobService, saved with the save): what it is making and its times (os.time)
function RecycleRules.job(gains: { Gain }, cash: number, now: number, seconds: number): { kind: string, startedAt: number, finishAt: number, gains: { Gain }, cash: number }
	return { kind = "recycle", startedAt = now, finishAt = now + seconds, gains = gains, cash = cash }
end

-- "$87.60", "$3,175.00"
function RecycleRules.money(amount: number): string
	local cents = math.round(math.max(0, amount) * 100)
	return string.format("$%s.%02d", RecycleRules.count(cents // 100), cents % 100)
end

-- A row's small line in coins: "$0.20 each"
function RecycleRules.coinSub(config: Config, rarity: string): string
	return `{RecycleRules.money(config.COINS[rarity] or 0)} each`
end

-- "3,214"
function RecycleRules.count(amount: number): string
	local digits = string.reverse((string.gsub(string.reverse(tostring(whole(amount))), "(%d%d%d)", "%1,")))
	return if string.sub(digits, 1, 1) == "," then string.sub(digits, 2) else digits
end

-- A row's title: "3,214 extra Rares", "1 extra Epic", "No extra Legendaries"
function RecycleRules.rowTitle(config: Config, rarity: string, count: number): string
	local words = config.PLURALS[rarity] or { rarity, rarity }
	if count <= 0 then
		return `No extra {words[2]}`
	end
	return `{RecycleRules.count(count)} extra {if count == 1 then words[1] else words[2]}`
end

-- "40 Wild Ore", "1 XP Tonic", "9 Star Shards"
function RecycleRules.outWords(config: Config, item: string, made: number): string
	local words = config.ITEM_WORDS[item] or { item, item }
	return `{RecycleRules.count(made)} {if made == 1 then words[1] else words[2]}`
end

-- A row's small line, its recipe: "80 make 1 Wild Ore", "1 makes 1 Star Shard"
function RecycleRules.rowSub(config: Config, rarity: string): string
	local recipe = config.RECIPES[rarity]
	if not recipe then
		return ""
	end
	return `{recipe.per} {if recipe.per == 1 then "makes" else "make"} {RecycleRules.outWords(config, recipe.item, 1)}`
end

-- A row's button and whether it can be pressed: "Recycle", how many more cards the first material needs, or "None"
function RecycleRules.rowButton(count: number, per: number): (string, boolean)
	local made, _, more = RecycleRules.make(count, per)
	if made > 0 then
		return "Recycle", true
	elseif whole(count) > 0 then
		return `{more} more`, false
	end
	return "None", false
end

local function listed(config: Config, gains: { Gain }, cash: number?, joiner: string, last: string): string
	local parts: { string } = {}
	for _, gain in gains do
		table.insert(parts, RecycleRules.outWords(config, gain.item, gain.count))
	end
	if cash and cash > 0 then
		table.insert(parts, RecycleRules.money(cash))
	end
	if #parts <= 1 then
		return parts[1] or ""
	end
	return table.concat(parts, joiner, 1, #parts - 1) .. last .. parts[#parts]
end

-- The big button's words and the small line under them: everything every pile makes (materials, or `cash`)
function RecycleRules.allWords(config: Config, gains: { Gain }, cash: number?): (string, string?)
	if #gains == 0 and not (cash and cash > 0) then
		return "Nothing to recycle yet", nil
	end
	return "Recycle everything", listed(config, gains, cash, " · ", " · ")
end

-- What a conversion makes, in words: "40 Wild Ore and 2 Star Shards", "$87.60"
function RecycleRules.makes(config: Config, gains: { Gain }, cash: number?): string
	return listed(config, gains, cash, ", ", " and ")
end

-- What you got, said once it's done: "You got 40 Wild Ore and 2 Star Shards!"
function RecycleRules.doneWords(config: Config, gains: { Gain }, cash: number?): string
	return `You got {RecycleRules.makes(config, gains, cash)}!`
end

return RecycleRules
