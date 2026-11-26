--!strict
-- Which duplicates the Condenser uses for the next star, and what the Grading Station needs for the next grade,
-- shared by the client previews and the server.
-- Pure (no requires, no Roblox APIs): callers pass Config/Beasts (and Config/Grading) in, so tests/ can run it in Lune.
-- Rule: plain copies of the same card only; all normal copies weakest grade first, then foil copies
-- weakest grade first. A plain main copy is set aside first and is not a duplicate. A copy better than the card that
-- gets the star or the grade is never used up (the Grading Station since 2026-11-20, the Condenser since 2026-11-21).
local CondenseRules = {}

export type Counts = { normal: number, foil: number }
export type Take = { grade: string, foil: boolean, count: number }
export type Main = { beast: boolean, foil: boolean, grade: string, stars: number }
type Config = { GRADES: { string }, STAR_COSTS: { number }, MAX_STARS: number, MAX_SHARD_SHARE: number? }

local DEFAULT_GRADES = { "C", "B", "A", "S" } -- matches Config/Beasts GRADES when no config is passed

local function readCount(value: any): number
	return if typeof(value) == "number" and value == value and value > 0 and value ~= math.huge then math.floor(value) else 0
end

-- Copies in one stack that can be used as duplicates, after setting a plain main aside
local function available(byGrade: { [string]: any }, grade: string, foil: boolean, main: Main): number
	local stack = byGrade[grade]
	local count = if typeof(stack) == "table" then readCount(if foil then stack.foil else stack.normal) else 0
	if not main.beast and main.grade == grade and main.foil == foil then
		count -= 1
	end
	return math.max(0, count)
end

-- Every stack in the order duplicates are used: normals weakest grade first, then foils
local function eachStack(grades: { string }, visit: (grade: string, foil: boolean) -> ())
	for _, foil in { false, true } do
		for _, grade in grades do
			visit(grade, foil)
		end
	end
end

-- The grades a star or a grade-up may use copies of: the main copy's own and the ones under it. A copy better than the
-- card it goes into is never used up (owner 2026-11-20: a step to Grade B listed a Grade S spare among its copies;
-- 2026-11-21: "condenser never uses better copies")
local function noBetter(grades: { string }, main: Main): { string }
	local top = table.find(grades, main.grade) or #grades
	local list: { string } = {}
	for index = 1, top do
		list[index] = grades[index]
	end
	return list
end

-- The duplicates a star may use for this main copy: the plain copies no better than it
function CondenseRules.countDuplicates(byGrade: { [string]: any }, main: Main, config: Config?): number
	local total = 0
	eachStack(noBetter(if config then config.GRADES else DEFAULT_GRADES, main), function(grade, foil)
		total += available(byGrade, grade, foil, main)
	end)
	return total
end

-- The plain copies better than this main copy: never used up, so the window can say they're safe
function CondenseRules.betterCopies(byGrade: { [string]: any }, main: Main, config: Config?): number
	local grades = if config then config.GRADES else DEFAULT_GRADES
	local total = 0
	for index = (table.find(grades, main.grade) or #grades) + 1, #grades do
		for _, foil in { false, true } do
			total += available(byGrade, grades[index], foil, main)
		end
	end
	return total
end

-- The copies to take for the next star, or nil and a reason: "max" or "short:<have>:<need>". With shards,
-- real duplicates go first and Star Shards cover what's missing, up to MAX_SHARD_SHARE of the cost.
-- The third result is how many shards to use.
function CondenseRules.plan(config: Config, byGrade: { [string]: any }, main: Main, shards: number?): ({ Take }?, string?, number)
	if main.stars >= config.MAX_STARS then
		return nil, "max", 0
	end
	local need = config.STAR_COSTS[math.floor(main.stars) + 1] or math.huge
	local have = CondenseRules.countDuplicates(byGrade, main, config)
	local maxShards = math.floor(need * (config.MAX_SHARD_SHARE or 0))
	local used = math.max(0, math.min(need - have, maxShards, math.floor(shards or 0)))
	if have + used < need then
		return nil, `short:{have}:{need}`, 0
	end
	return CondenseRules.pick(noBetter(config.GRADES, main), byGrade, main, need - used), nil, used
end

-- The first `count` duplicates in the order they're used (normals weakest grade first, then foils), never the plain
-- main itself. Takes fewer if there aren't that many: check countDuplicates first. Shared with the Grading Station.
function CondenseRules.pick(grades: { string }, byGrade: { [string]: any }, main: Main, count: number): { Take }
	local takes: { Take } = {}
	local remaining = count
	eachStack(grades, function(grade, foil)
		local take = math.min(remaining, available(byGrade, grade, foil, main))
		if take > 0 then
			table.insert(takes, { grade = grade, foil = foil, count = take })
			remaining -= take
		end
	end)
	return takes
end

-- Main copy choices in default order: levelled cards first (the card you've been raising), then plain ones; inside
-- each the best grade first (owner 2026-11-21: "sort by grade": a foil Grade C stood before a plain Grade A), then a
-- foil before a plain copy of its grade, then the strongest. Sorts in place.
export type MainChoice = { key: string, beast: any, foil: boolean, grade: string, power: number } -- beast: truthy for a levelled card

local GRADE_RANK = { S = 4, A = 3, B = 2, C = 1 }

function CondenseRules.sortMainChoices<T>(choices: { T & MainChoice })
	table.sort(choices, function(a, b)
		local levelledA, levelledB = a.beast and true or false, b.beast and true or false
		if levelledA ~= levelledB then
			return levelledA
		end
		local rankA, rankB = GRADE_RANK[a.grade] or 0, GRADE_RANK[b.grade] or 0
		if rankA ~= rankB then
			return rankA > rankB
		end
		if a.foil ~= b.foil then
			return a.foil
		end
		if a.power ~= b.power then
			return a.power > b.power
		end
		return a.key < b.key
	end)
end

-- The copy picker (owner 2026-11-21: "Keep a different card is so confusing. can we change wording or anything to make
-- it more understandable. also the next window make it more understandable"): the copies as pictures with a few plain
-- words. Since 2026-11-26 the stations' card picker's second step (owner: "when I click on a card, it then should let
-- me pick which copy of that card would I want to use"), and the Condenser's "Pick other copies" opens it too.

-- The picker's sentence and its small line; `what`: "star" (the Condenser) or "grade" (the Grading Station)
function CondenseRules.pickSay(name: string, what: string): (string, string)
	return `Which {name} gets the {what}?`, "Tap the one you want. Better ones are never used up."
end

-- Under a copy's picture: a levelled card's level, or how many plain ones there are (a foil wears its own tag)
function CondenseRules.copyLabel(view: { beast: boolean, level: number, count: number }): string
	return if view.beast then `Lv {view.level}` else `You have {view.count}`
end

-- The Condenser's line when copies are missing and better ones were left out; nil with none
function CondenseRules.safeWords(better: number): string?
	if better <= 0 then
		return nil
	end
	return if better == 1 then "Your 1 better copy stays safe: it is never used up." else `Your {better} better copies stay safe: they are never used up.`
end

-- After condensing a plain main: the levelled card it became (an ID that wasn't there before, same card,
-- foil and grade), so the panel keeps condensing that card instead of jumping to another one
function CondenseRules.findNewCard(
	beforeIds: { [string]: boolean },
	beasts: { [string]: { cardId: string, foil: boolean, grade: string } },
	cardId: string,
	foil: boolean,
	grade: string
): string?
	for id, beast in beasts do
		if not beforeIds[id] and beast.cardId == cardId and beast.foil == foil and beast.grade == grade then
			return id
		end
	end
	return nil
end

-- Grading Station ------------------------------------------------------------------------------------------------

export type GradeStep = { copies: number, cash: number }
export type GradePlan = { grade: string, copies: number, cash: number, takes: { Take }, seals: number } -- seals: Grading Seals used
type GradingConfig = { COSTS: { [string]: { [string]: GradeStep } }, MAX_SEAL_SHARE: number? }

-- The grade one step above, or nil at the top (or for an unknown grade)
function CondenseRules.nextGrade(grades: { string }, grade: string): string?
	local index = table.find(grades, grade)
	return if index then grades[index + 1] else nil
end

-- What going up to `grade` costs for a card of this rarity, or nil if there's no such step
function CondenseRules.gradeStepCost(grading: GradingConfig, rarity: string, grade: string): GradeStep?
	local byGrade = grading.COSTS[rarity]
	return if byGrade then byGrade[grade] else nil
end

-- The duplicates a grade-up may use for this main copy: the copies no better than it
function CondenseRules.gradeHave(config: Config, byGrade: { [string]: any }, main: Main): number
	local have = 0
	eachStack(noBetter(config.GRADES, main), function(grade, foil)
		have += available(byGrade, grade, foil, main)
	end)
	return have
end

-- The next grade for this main copy and what it takes, or nil and a reason: "max", "unknown" (no cost for that
-- rarity) or "short:<have>:<need>" (duplicates). With `seals`, real duplicates go first and Grading Seals cover what's
-- missing, up to MAX_SEAL_SHARE of the step. The caller checks the cash against the player's.
function CondenseRules.gradePlan(grading: GradingConfig, config: Config, rarity: string, byGrade: { [string]: any }, main: Main, seals: number?): (GradePlan?, string?)
	local grade = CondenseRules.nextGrade(config.GRADES, main.grade)
	if not grade then
		return nil, "max"
	end
	local step = CondenseRules.gradeStepCost(grading, rarity, grade)
	if not step then
		return nil, "unknown"
	end
	local usable = noBetter(config.GRADES, main)
	local have = CondenseRules.gradeHave(config, byGrade, main)
	local maxSeals = math.floor(step.copies * (grading.MAX_SEAL_SHARE or 0))
	local used = math.max(0, math.min(step.copies - have, maxSeals, math.floor(seals or 0)))
	if have + used < step.copies then
		return nil, `short:{have}:{step.copies}`
	end
	return {
		grade = grade,
		copies = step.copies,
		cash = step.cash,
		takes = CondenseRules.pick(usable, byGrade, main, step.copies - used),
		seals = used,
	}, nil
end

-- Whether a Gold Seal may pay this step's cash: any step but a Legendary's last one (A to S stays the cash chase)
function CondenseRules.goldSealAllowed(rarity: string, toGrade: string): boolean
	return not (rarity == "Legendary" and toGrade == "S")
end

-- Copies and cash to take a copy from `grade` all the way to the top (the panel's "to Grade S" line)
function CondenseRules.gradeCostToTop(grading: GradingConfig, grades: { string }, rarity: string, grade: string): GradeStep
	local total: GradeStep = { copies = 0, cash = 0 }
	local current = CondenseRules.nextGrade(grades, grade)
	while current do
		local step = CondenseRules.gradeStepCost(grading, rarity, current)
		if step then
			total.copies += step.copies
			total.cash += step.cash
		end
		current = CondenseRules.nextGrade(grades, current)
	end
	return total
end

-- The Condenser's window as a picture recipe (owner 2026-11-20: "make this window easier to understand and more
-- immersive. a kid wouldnt understand this"; pick A): the copies used, an arrow, the card with its new star, one plain
-- sentence, and Star Shards tapped into empty spots. Its words and its spots:

-- A list row's tag, what it is ("ready", "wait", "max") and its bar's share: `have` duplicates usable now, `need` for
-- the next star (0 at max stars), `ready` (the star can be added, with Star Shards when they're on)
function CondenseRules.rowTag(have: number, need: number, ready: boolean): (string, string, number)
	if need <= 0 then
		return "All stars", "max", 1
	elseif ready then
		return "Ready!", "ready", 1
	end
	return `{math.max(1, need - have)} more`, "wait", math.clamp(have / need, 0, 1)
end

-- How long a job takes, in words a child reads ("23 seconds", "2 minutes", "1 hour 30 minutes"): part minutes up
function CondenseRules.waitWords(seconds: number): string
	local total = math.max(1, math.ceil(seconds))
	if total < 60 then
		return `{total} second{if total == 1 then "" else "s"}`
	end
	local minutes = math.ceil(total / 60)
	if minutes < 60 then
		return `{minutes} minute{if minutes == 1 then "" else "s"}`
	end
	local hours, rest = minutes // 60, minutes % 60
	local hourWords = `{hours} hour{if hours == 1 then "" else "s"}`
	return if rest == 0 then hourWords else `{hourWords} {rest} minute{if rest == 1 then "" else "s"}`
end

-- The one sentence over the recipe: `copies` extra copies and `shards` Star Shards go in; `missing` more copies are
-- needed first; `max`: it has every star
function CondenseRules.say(view: { name: string, copies: number, shards: number, missing: number, max: boolean, maxStars: number }): string
	if view.max then
		return `{view.name} has all {view.maxStars} stars!`
	elseif view.missing > 0 then
		return `Find {view.missing} more {view.name} to add a star.`
	end
	local shards = if view.shards > 0 then ` and {view.shards} Star Shard{if view.shards == 1 then "" else "s"}` else ""
	return `Combine {view.copies} extra {view.name}{shards} into this one. It gets a star!` -- (owner 2026-11-26: not "Squish")
end

-- The chip over the recipe once a card is in (owner 2026-11-26: "the condenser then autofills the extra
-- cards(weakest)"): the `copies` it put in for you; nil with none
function CondenseRules.fillChip(copies: number): string?
	if copies <= 0 then
		return nil
	end
	return if copies == 1 then "Filled in for you: your weakest extra" else `Filled in for you: your {copies} weakest extras`
end

-- The big button's words and the small line under them: what it does and how long it takes (`seconds`), "Putting it
-- in..." while the server answers, else what's missing
function CondenseRules.buttonWords(view: { ready: boolean, inFlight: boolean, max: boolean, missing: number, seconds: number }): (string, string?)
	if view.inFlight then
		return "Putting it in...", nil
	elseif view.ready then
		return "Add a star!", `takes {CondenseRules.waitWords(view.seconds)}`
	elseif view.max then
		return "All stars!", nil
	elseif view.missing > 0 then
		return `{view.missing} more {if view.missing == 1 then "copy" else "copies"} needed`, nil
	end
	return "This copy can't go in now", nil
end

-- The recipe's spots, one for each of the `need` duplicates a star takes: "copy" (a duplicate going in), then "shard"
-- (a Star Shard standing in), then "offer" (an empty spot a tap fills with a shard), then "empty"
function CondenseRules.slots(need: number, copies: number, shards: number, offers: number): { string }
	local kinds: { string } = {}
	for index = 1, math.max(0, need) do
		kinds[index] = if index <= copies then "copy"
			elseif index <= copies + shards then "shard"
			elseif index <= copies + shards + offers then "offer"
			else "empty"
	end
	return kinds
end

-- How many empty spots offer a Star Shard: only while the shards are off (on, they show as shards), what's missing,
-- never more than `share` of the star (Config/Beasts MAX_SHARD_SHARE) nor than the shards `owned`
function CondenseRules.shardOffers(need: number, have: number, owned: number, share: number, on: boolean): number
	if on then
		return 0
	end
	return math.max(0, math.min(need - have, math.floor(need * share), math.floor(owned)))
end

-- How many spots across in the put-a-card-in windows' wide recipe (owner 2026-11-26, the mockups: a first star's 4
-- copies stand in one row): up to 4 in one row, up to 16 in two, more in three. The star costs (4, 8, 12, 16, 24) and
-- the grade steps' copies (1, 2, 3, 4, 6, 8) fill whole rows
function CondenseRules.slotColumns(need: number): number
	if need <= 4 then
		return math.max(1, need)
	elseif need <= 16 then
		return math.ceil(need / 2)
	end
	return math.ceil(need / 3)
end

export type StandIn = { have: number, on: boolean, used: number, offers: number, could: boolean, missing: number, max: boolean }

-- The line under the spots: what a tap does with the item that stands in for missing copies (`item`: "Star Shard",
-- "Grading Seal"; `what` it finishes: "star", "grade"); nil: nothing to say. `have` owned, `on`, `used` in the spots
-- now, `offers` (empty spots one could fill), `could` (turning them on finishes it), `missing` copies still needed as
-- things are, `max` (nothing more to add)
local function standInWords(view: StandIn, item: string, what: string): string?
	if view.have <= 0 or view.max then
		return nil
	elseif view.on then
		if view.missing > 0 then
			return `{item}s are in, but you still need {view.missing} more {if view.missing == 1 then "copy" else "copies"}.`
		elseif view.used > 0 then
			return if view.used == 1 then `Using 1 {item}. Tap it to take it out.` else `Using {view.used} {item}s. Tap one to take them out.`
		end
		return nil
	elseif view.offers > 0 then
		return if view.could then `Tap an empty spot: {item}s finish this {what}! ({view.have} left)` else `Tap an empty spot to use a {item} ({view.have} left)`
	end
	return nil
end

-- Star Shards at the Condenser
function CondenseRules.shardWords(view: StandIn): string?
	return standInWords(view, "Star Shard", "star")
end

-- The Grading Station's USE row (owner 2026-11-26, the redesign: "the option to use upgrade materialls will then show
-- the user"): three tiles under the recipe, a title and a small line each. The first, the copies that go in, picked for
-- you (the weakest: CondenseRules.pick):
function CondenseRules.copiesTile(copies: number): (string, string)
	if copies <= 0 then
		return "No extra copies", "Find more of this card"
	end
	return `{copies} extra cop{if copies == 1 then "y" else "ies"}`, "Your weakest, picked for you"
end

-- Grading Seals stand in for missing copies (as many as Config/Grading MAX_SEAL_SHARE lets). The tile is there even
-- with none (owner 2026-11-20: "whats the use of grading seals? I cant see it inside the grading station")
function CondenseRules.sealTile(view: StandIn): (string, string)
	local title = `Grading Seal{if view.have == 1 then "" else "s"} x{view.have}`
	if view.have <= 0 then
		return title, "You have none yet"
	elseif view.on and view.used > 0 then
		return title, `{view.used} in. Tap to take out`
	elseif not view.on and view.offers > 0 then
		return title, "Tap: fills a missing copy"
	end
	return title, "Fill in for missing copies"
end

-- ...and a Gold Seal pays a step's cash (`allowed`: not a Legendary's last step), never naming it: the cost shows only
-- on the button (owner 2026-11-26: "remove the cost anywhere else")
function CondenseRules.goldTile(have: number, on: boolean, allowed: boolean): (string, string)
	local title = `Gold Seal{if have == 1 then "" else "s"} x{have}`
	if have <= 0 then
		return title, "You have none yet"
	elseif not allowed then
		return title, "Not for a Legendary's Grade S"
	end
	return title, if on then "Pays the cash! Tap to undo" else "Tap: pays the cash"
end

-- The Grading Station as a picture recipe (owner 2026-11-20: "redesign it like the condenser to be easily understood.
-- it's currently so confusing"): the copies that go in, an arrow, the card with its new grade.

-- The one sentence over the recipe: `copies` extra copies and `seals` Grading Seals make it Grade `grade`; `missing`
-- more copies are needed first; `grade` nil: it is Grade S. Never the cash: that is the button's (owner 2026-11-26)
function CondenseRules.gradeSay(view: { name: string, grade: string?, copies: number, seals: number, missing: number }): string
	if not view.grade then
		return `{view.name} is Grade S: the best!`
	elseif view.missing > 0 then
		return `Find {view.missing} more {view.name} to make it Grade {view.grade}.`
	end
	local parts: { string } = {}
	if view.copies > 0 then
		table.insert(parts, `{view.copies} extra {view.name}`)
	end
	if view.seals > 0 then
		table.insert(parts, `{view.seals} Grading Seal{if view.seals == 1 then "" else "s"}`)
	end
	if #parts == 0 then
		return `Make it Grade {view.grade}!`
	end
	return `Use {table.concat(parts, " and ")} to make it Grade {view.grade}!`
end

-- A list row's tag, what it is ("ready", "wait", "cash", "max") and its bar's share: `have` usable copies, `need` for
-- the next grade (`grade` nil: it is Grade S), `ready` (copies and cash are there), `cashOk`
function CondenseRules.gradeRowTag(have: number, need: number, grade: string?, ready: boolean, cashOk: boolean): (string, string, number)
	if not grade then
		return "Top grade", "max", 1
	elseif ready then
		return "Ready!", "ready", 1
	elseif have < need then
		return `{need - have} more`, "wait", math.clamp(have / math.max(1, need), 0, 1)
	elseif not cashOk then
		return "Need cash", "cash", 1
	end
	return "Ready!", "ready", 1
end

-- The big button's words and the small line under them (owner 2026-11-26: "change "Make it Grade A" to "Upgrade" then
-- the cost. remove the cost anywhere else"): "Upgrade $2,500" (`gold`: a Gold Seal pays instead), and under it how long
-- it takes, the copies still missing, or the cash you have when it isn't enough
function CondenseRules.gradeButton(view: { inFlight: boolean, grade: string?, cash: string, have: string, affordable: boolean, missing: number, seconds: number, gold: boolean }): (string, string?)
	if view.inFlight then
		return "Putting it in...", nil
	elseif not view.grade then
		return "Top grade!", nil
	end
	local text = if view.gold then "Upgrade with a Gold Seal" else `Upgrade {view.cash}`
	if view.missing > 0 then
		return text, `{view.missing} more {if view.missing == 1 then "copy" else "copies"} needed`
	elseif not view.affordable then
		return text, `you have {view.have}`
	end
	return text, `takes {CondenseRules.waitWords(view.seconds)}`
end

-- A finished star waiting to be shown (the player's CondenserDone attribute, set by CondenserService when the job ends
-- and cleared when they take the card out in the Condenser's window): the card as it is now
export type Done = { cardId: string, foil: boolean, grade: string, level: number, stars: number }

local DONE_GRADES = { C = true, B = true, A = true, S = true }

function CondenseRules.encodeDone(done: Done): string
	return `{done.cardId}|{if done.foil then 1 else 0}|{done.grade}|{done.level}|{done.stars}`
end

-- `minStars`: the fewest stars a waiting result may have (1, a Condenser's new star; 0 for the Grading Station's, whose
-- plain copies have none)
function CondenseRules.decodeDone(value: unknown, minStars: number?): Done?
	if typeof(value) ~= "string" then
		return nil
	end
	local cardId, foil, grade, level, stars = string.match(value, "^([^|]+)|([01])|(%a)|(%d+)|(%d+)$")
	local levelNumber, starNumber = tonumber(level), tonumber(stars)
	if not cardId or not DONE_GRADES[grade] or not levelNumber or not starNumber or starNumber < (minStars or 1) then
		return nil
	end
	return { cardId = cardId, foil = foil == "1", grade = grade, level = levelNumber, stars = starNumber }
end

-- The reveal's line under the stars: how many it has now, in words (owner 2026-11-20: "easily understandable with
-- no '->'")
function CondenseRules.doneLine(stars: number): string
	if stars >= 5 then
		return `Now {stars} stars: the most!`
	end
	return `Now {stars} star{if stars == 1 then "" else "s"}!`
end

-- The grade under `grade` (what a card was before its grading); nil for C
local GRADE_UNDER = { B = "C", A = "B", S = "A" }
function CondenseRules.gradeBefore(grade: string): string?
	return GRADE_UNDER[grade]
end

-- The reveal's line under the new grade
function CondenseRules.gradeDoneLine(grade: string): string
	return if grade == "S" then "Now Grade S: the best!" else `Now Grade {grade}!`
end

-- How much a number grows, for the After column ("+51"); nothing when it doesn't
function CondenseRules.gain(before: number, after: number): string
	local more = math.floor(after - before + 0.5)
	return if more > 0 then `+{more}` else ""
end

return CondenseRules
