--!strict
-- Which duplicates the Condenser uses for the next star, shared by the client preview and the server.
-- Pure (no requires, no Roblox APIs): callers pass Config/Beasts in, so tests/ can run it in Lune.
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
	local takes: { Take } = {}
	local remaining = need - used
	eachStack(config.GRADES, function(grade, foil)
		local count = math.min(remaining, available(byGrade, grade, foil, main))
		if count > 0 then
			table.insert(takes, { grade = grade, foil = foil, count = count })
			remaining -= count
		end
	end)
	return takes, nil, used
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

return CondenseRules
