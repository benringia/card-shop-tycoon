--!strict
-- Which duplicates the Condenser uses for the next star, shared by the client preview and the server.
-- Pure (no requires, no Roblox APIs): callers pass Config/Beasts in, so tests/ can run it in Lune.
-- Rule: plain copies of the same card only; all normal copies weakest grade first, then foil copies
-- weakest grade first. A plain main copy is set aside first and is not a duplicate.
local CondenseRules = {}

export type Counts = { normal: number, foil: number }
export type Take = { grade: string, foil: boolean, count: number }
export type Main = { beast: boolean, foil: boolean, grade: string, stars: number }
type Config = { GRADES: { string }, STAR_COSTS: { number }, MAX_STARS: number }

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

-- The copies to take for the next star, or nil and a reason: "max" or "short:<have>:<need>"
function CondenseRules.plan(config: Config, byGrade: { [string]: any }, main: Main): ({ Take }?, string?)
	if main.stars >= config.MAX_STARS then
		return nil, "max"
	end
	local need = config.STAR_COSTS[math.floor(main.stars) + 1] or math.huge
	local have = CondenseRules.countDuplicates(byGrade, main, config)
	if have < need then
		return nil, `short:{have}:{need}`
	end
	local takes: { Take } = {}
	local remaining = need
	eachStack(config.GRADES, function(grade, foil)
		local count = math.min(remaining, available(byGrade, grade, foil, main))
		if count > 0 then
			table.insert(takes, { grade = grade, foil = foil, count = count })
			remaining -= count
		end
	end)
	return takes, nil
end

return CondenseRules
