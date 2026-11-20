--!strict
-- Which duplicates the Condenser uses for the next star, and what the Grading Station needs for the next grade,
-- shared by the client previews and the server.
-- Pure (no requires, no Roblox APIs): callers pass Config/Beasts (and Config/Grading) in, so tests/ can run it in Lune.
-- Rule: plain copies of the same card only; all normal copies weakest grade first, then foil copies
-- weakest grade first. A plain main copy is set aside first and is not a duplicate.
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

function CondenseRules.countDuplicates(byGrade: { [string]: any }, main: Main, config: Config?): number
	local total = 0
	eachStack(if config then config.GRADES else DEFAULT_GRADES, function(grade, foil)
		total += available(byGrade, grade, foil, main)
	end)
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
	return CondenseRules.pick(config.GRADES, byGrade, main, need - used), nil, used
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

-- Main copy choices in default order: levelled cards first (the card you've been raising), then plain
-- foil, then plain normal; strongest first inside each group. Sorts in place.
export type MainChoice = { key: string, beast: any, foil: boolean, power: number } -- beast: truthy for a levelled card

function CondenseRules.sortMainChoices<T>(choices: { T & MainChoice })
	local function group(choice: MainChoice): number
		return if choice.beast then 1 elseif choice.foil then 2 else 3
	end
	table.sort(choices, function(a, b)
		if group(a) ~= group(b) then
			return group(a) < group(b)
		end
		if a.power ~= b.power then
			return a.power > b.power
		end
		return a.key < b.key
	end)
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
	local have = CondenseRules.countDuplicates(byGrade, main, config)
	local maxSeals = math.floor(step.copies * (grading.MAX_SEAL_SHARE or 0))
	local used = math.max(0, math.min(step.copies - have, maxSeals, math.floor(seals or 0)))
	if have + used < step.copies then
		return nil, `short:{have}:{step.copies}`
	end
	return {
		grade = grade,
		copies = step.copies,
		cash = step.cash,
		takes = CondenseRules.pick(config.GRADES, byGrade, main, step.copies - used),
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

-- The Condenser list's small line under a card's name and its bar's share (spec 2026-11-04-round4-design section 3):
-- `owned` plain copies, `have` duplicates usable now, `need` duplicates for the next star (0 at max stars)
function CondenseRules.rowLine(owned: number, have: number, need: number, ready: boolean): (string, number)
	if need <= 0 then
		return "Max stars", 1
	end
	if ready then
		return `You have {owned} copies · a star uses {need}`, 1
	end
	return `{have} of {need} copies for the next star`, math.clamp(have / need, 0, 1)
end

-- The big button's words (owner 2026-11-20: "very confusing ... easily understandable"): what it does and how long it
-- takes (`clock`, "2:00"), "Putting it in..." while the server answers, else what's missing (`reason` from `plan`:
-- "max", "short:<have>:<need>")
function CondenseRules.buttonWords(canCondense: boolean, reason: string?, clock: string, inFlight: boolean): string
	if inFlight then
		return "Putting it in..."
	elseif canCondense then
		return `Add a star · takes {clock}`
	elseif reason == "max" then
		return "Max stars reached"
	end
	local have, need = string.match(reason or "", "^short:(%d+):(%d+)$")
	return if have then `Need {need} extra copies (you have {have})` else "This copy can't go in now"
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

-- Under the chosen card's stars: which star this adds, or that it has them all
function CondenseRules.starWords(stars: number, maxStars: number): string
	if stars >= maxStars then
		return `Has all {maxStars} stars`
	end
	return `Adds star {stars + 1} of {maxStars}`
end

-- The box under the chosen card, two plain lines: the copy that stays and gets the star (`gradeText`: "Grade S"), and
-- the copies used up (`uses`: "3 Grade C + 1 Grade B"; nil with nothing to use yet)
-- (`what`: "star" at the Condenser, "grade" at the Grading Station)
function CondenseRules.keepWords(gradeText: string, level: number, uses: string?, what: string?): (string, string?)
	return `Gets the {what or "star"}: your {gradeText} · Lv {level} copy`, if uses then `Used up: {uses}` else nil
end

-- The Grading Station in plain words (owner 2026-11-20: "check the other machines ... for pain points/ confusing
-- elements"; it said "Owned 7 · C -> B: 3 + $5") ----------------------------------------------------------------

-- A row's line: the copies you have and what the next grade uses (`toGrade` nil at Grade S)
function CondenseRules.gradeRowLine(owned: number, toGrade: string?, copies: number, cashText: string): string
	local have = `You have {owned} {if owned == 1 then "copy" else "copies"}`
	if not toGrade then
		return `{have} · Grade S: the best`
	end
	return `{have} · Grade {toGrade} uses {copies} + {cashText}`
end

-- Under the chosen card's name: what grading does to it
function CondenseRules.gradeWords(grade: string, nextGrade: string?): string
	return if nextGrade then `Makes it Grade {nextGrade}` else `Grade {grade}: the best it can be`
end

-- The Grading Station's button: what it makes, the price (or that a Gold Seal pays) and the wait; else what's missing.
-- `grade` false: this copy can't be graded now (`reason` from the plan: "max", "short:<have>:<need>")
function CondenseRules.gradeButtonWords(view: { inFlight: boolean, grade: (string | boolean)?, cash: string, have: string, affordable: boolean, gold: boolean, clock: string, reason: string? }): string
	if view.inFlight then
		return "Putting it in..."
	end
	if typeof(view.grade) == "string" then
		if not view.affordable then
			return `Need {view.cash} (you have {view.have})`
		end
		return `Make it Grade {view.grade} · {if view.gold then "Gold Seal pays" else view.cash} · takes {view.clock}`
	end
	if view.reason == "max" then
		return "Already Grade S"
	end
	local have, need = string.match(view.reason or "", "^short:(%d+):(%d+)$")
	return if have then `Need {need} extra copies (you have {have})` else "This copy can't go in now"
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
