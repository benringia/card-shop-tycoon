--!strict
-- The boss chests' rules (spec 2026-11-11-boss-chests-design; Config/BossChests): the material count, what the two
-- chests you didn't pick show, where yours goes in the row, and the checks on a pick. Pure, Lune-tested.
-- kind "empty": a reduced win's chest whose material missed; reason: "strong" (too strong for the boss) or "tired"
-- (the day's soft cap)
export type Content = { kind: "weapon" | "material" | "mystery" | "empty", weaponId: string?, item: string?, count: number?, reason: string? }
export type Set = { id: string, bossId: string, weaponId: string, mine: Content, others: { Content }, opened: boolean }
export type Weights = { { count: number, weight: number } }

local ChestRules = {}

-- The material count for a roll in [0, 1) by the weights (the last entry takes anything past the rest)
function ChestRules.materialCount(roll: number, weights: Weights): number
	local reach = 0
	for _, entry in weights do
		reach += entry.weight
		if roll < reach then
			return entry.count
		end
	end
	return weights[#weights].count
end

-- Your chest: the weapon if it dropped; otherwise its material (count by the weights), always on a full-loot win
-- (factor 1) and at `factor`'s chance on a reduced one, else empty with the reason
function ChestRules.mine(weaponId: string, dropped: boolean, material: string, factor: number, chanceRoll: number, countRoll: number, weights: Weights, reason: string?): Content
	if dropped then
		return { kind = "weapon", weaponId = weaponId }
	end
	if factor >= 1 or chanceRoll < factor then
		return { kind = "material", item = material, count = ChestRules.materialCount(countRoll, weights) }
	end
	return { kind = "empty", reason = reason }
end

-- Why a win's loot was reduced (BossRules' two factors): too strong for the boss before the day's soft cap; nil: full
function ChestRules.reason(softCap: number, overPower: number): string?
	if overPower < 1 then
		return "strong"
	end
	return if softCap < 1 then "tired" else nil
end

-- Whether another chest shows the weapon under a "?": only when it didn't drop and you don't have it yet (the owner
-- 2026-11-11: "the ? should only show if you dont have the sword")
function ChestRules.showsMystery(dropped: boolean, owned: boolean): boolean
	return not dropped and not owned
end

-- The two chests you didn't pick (display only, never given): with `mystery` the weapon under a "?" and some material,
-- in an order by rolls[3]; otherwise two material amounts. rolls: three numbers in [0, 1)
function ChestRules.others(mystery: boolean, weaponId: string, material: string, rolls: { number }, weights: Weights): { Content }
	local first: Content = { kind = "material", item = material, count = ChestRules.materialCount(rolls[1], weights) }
	if not mystery then
		local second: Content = { kind = "material", item = material, count = ChestRules.materialCount(rolls[2], weights) }
		return { first, second }
	end
	local mystery: Content = { kind = "mystery", weaponId = weaponId }
	return if rolls[3] < 0.5 then { mystery, first } else { first, mystery }
end

-- The row of chests: yours at `index`, the others round it in their order
function ChestRules.layout(index: number, mine: Content, others: { Content }): { Content }
	local row: { Content } = {}
	local next = 1
	for slot = 1, #others + 1 do
		if slot == index then
			table.insert(row, mine)
		else
			table.insert(row, others[next])
			next += 1
		end
	end
	return row
end

-- A picked chest: a whole number 1..total, or nil
function ChestRules.validIndex(raw: unknown, total: number): number?
	if typeof(raw) ~= "number" or raw ~= raw or raw % 1 ~= 0 then
		return nil
	end
	local index = raw :: number
	return if index >= 1 and index <= total then index else nil
end

-- Whether a pick may open this set: it exists, the id matches and it isn't opened yet
function ChestRules.canOpen(set: Set?, id: unknown): boolean
	return set ~= nil and typeof(id) == "string" and set.id == id and not set.opened
end

-- The chest the server opens when nobody picked in time
function ChestRules.autoIndex(roll: number, total: number): number
	return math.clamp(math.floor(roll * total) + 1, 1, total)
end

return ChestRules
