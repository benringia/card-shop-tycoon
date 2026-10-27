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

return CondenseRules
