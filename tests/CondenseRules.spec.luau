--!strict
local CondenseRules = require("../src/shared/Util/CondenseRules")
local config = require("../src/shared/Config/Beasts")
local grading = require("../src/shared/Config/Grading")
local expect = require("./lib/expect")

local function counts(normal: number, foil: number)
	return { normal = normal, foil = foil }
end

local function total(takes: { any }): number
	local sum = 0
	for _, take in takes do
		sum += take.count
	end
	return sum
end

local BEAST_STAR0 = { beast = true, foil = false, grade = "S", stars = 0 } -- next star costs 4
local BEAST_STAR1 = { beast = true, foil = false, grade = "S", stars = 1 } -- next star costs 8

return {
	["goldSealAllowed: any step except a Legendary's A to S"] = function()
		expect.equal(CondenseRules.goldSealAllowed("Legendary", "S"), false, "the chase stays paid")
		expect.equal(CondenseRules.goldSealAllowed("Legendary", "A"), true, "B to A is fine")
		expect.equal(CondenseRules.goldSealAllowed("Epic", "S"), true, "other rarities to S")
	end,

	["shards: not used when duplicates are enough"] = function()
		local takes, reason, used = CondenseRules.plan(config, { C = counts(4, 0) }, BEAST_STAR0, 10)
		assert(takes, `expected a plan, got {reason}`)
		expect.equal(used, 0, "no shards")
		expect.equal(total(takes), 4, "four duplicates")
	end,

	["shards: cover the shortfall after duplicates"] = function()
		local takes, reason, used = CondenseRules.plan(config, { C = counts(5, 0) }, BEAST_STAR1, 3)
		assert(takes, `expected a plan, got {reason}`)
		expect.equal(used, 3, "three shards")
		expect.equal(total(takes), 5, "all five duplicates")
	end,

	["shards: at most half the cost"] = function()
		local takes, reason, used = CondenseRules.plan(config, { C = counts(3, 0) }, BEAST_STAR1, 10)
		expect.isNil(takes, "refused")
		expect.equal(reason, "short:3:8", "reason")
		expect.equal(used, 0, "nothing used")
		local ok, _, half = CondenseRules.plan(config, { C = counts(4, 0) }, BEAST_STAR1, 4)
		assert(ok, "4 duplicates + 4 shards is enough")
		expect.equal(half, 4, "half the cost in shards")
	end,

	["shards: nil means no shards"] = function()
		local takes, reason, used = CondenseRules.plan(config, { C = counts(5, 0) }, BEAST_STAR1)
		expect.isNil(takes, "short without shards")
		expect.equal(reason, "short:5:8", "reason")
		expect.equal(used, 0, "zero")
	end,

	["uses normals weakest grade first, then foils"] = function()
		local stacks = { C = counts(2, 1), B = counts(1, 0), S = counts(3, 2) }
		local takes = CondenseRules.plan(config, stacks, { beast = true, foil = false, grade = "S", stars = 1 }) -- needs 8
		assert(takes, "expected a plan")
		expect.equal(total(takes), 8, "total")
		expect.equal(takes[1].grade, "C", "first C")
		expect.equal(takes[1].foil, false, "first normal")
		expect.equal(takes[2].grade, "B", "then B")
		expect.equal(takes[3].grade, "S", "then S normal")
		expect.equal(takes[3].count, 3, "all S normals")
		expect.equal(takes[4].foil, true, "then foils")
		expect.equal(takes[4].grade, "C", "C foil first")
	end,

	["plain main is not a duplicate"] = function()
		local stacks = { C = counts(4, 0) }
		local takes, reason = CondenseRules.plan(config, stacks, { beast = false, foil = false, grade = "C", stars = 0 })
		expect.isNil(takes, "refused")
		expect.equal(reason, "short:3:4", "reason")
		expect.equal(CondenseRules.countDuplicates(stacks, { beast = false, foil = false, grade = "C", stars = 0 }), 3, "count")
		stacks.C.normal = 5
		local ok = CondenseRules.plan(config, stacks, { beast = false, foil = false, grade = "C", stars = 0 })
		assert(ok, "5 copies: main + 4")
		expect.equal(total(ok), 4, "uses 4")
	end,

	["levelled main counts every plain copy"] = function()
		local takes = CondenseRules.plan(config, { A = counts(4, 0) }, { beast = true, foil = false, grade = "A", stars = 0 })
		assert(takes, "expected a plan")
		expect.equal(total(takes), 4, "uses all 4")
	end,

	["max stars refused"] = function()
		local takes, reason = CondenseRules.plan(config, { C = counts(99, 0) }, { beast = true, foil = false, grade = "C", stars = 5 })
		expect.isNil(takes, "refused")
		expect.equal(reason, "max", "reason")
	end,

	["default main: levelled first, then plain foil, then plain normal"] = function()
		local copies = {
			{ key = "plainSfoil", beast = false, foil = true, power = 300 },
			{ key = "plainC", beast = false, foil = false, power = 200 },
			{ key = "lv1", beast = true, foil = false, power = 230 },
			{ key = "lv8", beast = true, foil = false, power = 400 },
			{ key = "plainBfoil", beast = false, foil = true, power = 250 },
		}
		CondenseRules.sortMainChoices(copies)
		local order = {}
		for _, copy in copies do
			table.insert(order, copy.key)
		end
		expect.equal(table.concat(order, ","), "lv8,lv1,plainSfoil,plainBfoil,plainC", "order")
	end,

	["finds the card a plain main became"] = function()
		local before = { old = true }
		local beasts = {
			old = { cardId = "FS30", foil = false, grade = "C" },
			other = { cardId = "FS01", foil = false, grade = "C" },
			wrongGrade = { cardId = "FS30", foil = false, grade = "S" },
			fresh = { cardId = "FS30", foil = false, grade = "C" },
		}
		before.other = true
		before.wrongGrade = true
		expect.equal(CondenseRules.findNewCard(before, beasts, "FS30", false, "C"), "fresh", "new one")
		before.fresh = true
		expect.isNil(CondenseRules.findNewCard(before, beasts, "FS30", false, "C"), "none new")
	end,

	["junk counts are ignored"] = function()
		local stacks: any = { C = { normal = -3, foil = 0 / 0 }, B = "junk", Z = counts(50, 0) }
		local takes, reason = CondenseRules.plan(config, stacks, { beast = true, foil = false, grade = "C", stars = 0 })
		expect.isNil(takes, "unknown grade Z and bad counts don't count")
		expect.equal(reason, "short:0:4", "reason")
	end,
	["grading: the next grade, and none past S"] = function()
		expect.equal(CondenseRules.nextGrade(config.GRADES, "C"), "B", "C")
		expect.equal(CondenseRules.nextGrade(config.GRADES, "A"), "S", "A")
		expect.isNil(CondenseRules.nextGrade(config.GRADES, "S"), "S is the top")
		expect.isNil(CondenseRules.nextGrade(config.GRADES, "Z"), "unknown")
	end,

	["grading: a step costs that rarity's duplicates and cash, taking the weakest copies first"] = function()
		local plainMain = { beast = false, foil = false, grade = "C", stars = 0 }
		-- 3 plain C copies: one is the main, two are duplicates; a Legendary C -> B needs 1
		local plan, reason = CondenseRules.gradePlan(grading, config, "Legendary", { C = counts(3, 0), S = counts(1, 0) }, plainMain)
		assert(plan, `expected a plan, got {reason}`)
		expect.equal(plan.grade, "B", "goes up to B")
		expect.equal(plan.copies, grading.COSTS.Legendary.B.copies, "copies")
		expect.equal(plan.cash, grading.COSTS.Legendary.B.cash, "cash")
		expect.equal(#plan.takes, 1, "one stack")
		expect.equal(plan.takes[1].grade, "C", "a C copy goes before the S")
		expect.equal(total(plan.takes), plan.copies, "takes the copies it costs")
	end,

	["grading: the plain main itself is never a duplicate"] = function()
		local plainMain = { beast = false, foil = false, grade = "C", stars = 0 }
		local plan, reason = CondenseRules.gradePlan(grading, config, "Legendary", { C = counts(1, 0) }, plainMain)
		expect.isNil(plan, "only the main")
		expect.equal(reason, "short:0:1", "reason")
	end,

	["grading: short of duplicates, already S, or an unknown rarity"] = function()
		local beastA = { beast = true, foil = false, grade = "A", stars = 2 }
		local plan, reason = CondenseRules.gradePlan(grading, config, "Legendary", { C = counts(2, 0) }, beastA)
		expect.isNil(plan, "A -> S needs 3")
		expect.equal(reason, "short:2:3", "short")
		local _, maxed = CondenseRules.gradePlan(grading, config, "Legendary", { C = counts(9, 0) }, { beast = true, foil = false, grade = "S", stars = 0 })
		expect.equal(maxed, "max", "S can't go higher")
		local _, unknown = CondenseRules.gradePlan(grading, config, "Mythic", { C = counts(9, 0) }, beastA)
		expect.equal(unknown, "unknown", "no costs for that rarity")
	end,

	["grading: costs rise with each step, Legendary C to S 6 copies and $15,500"] = function()
		for rarity, steps in grading.COSTS do
			assert(steps.B.cash < steps.A.cash and steps.A.cash < steps.S.cash, `{rarity} cash doesn't rise`)
			assert(steps.B.copies <= steps.A.copies and steps.A.copies <= steps.S.copies, `{rarity} copies don't rise`)
		end
		assert(grading.COSTS.Legendary.S.cash >= 12500, "Legendary A -> S costs at least $12,500")
		local top = CondenseRules.gradeCostToTop(grading, config.GRADES, "Legendary", "C")
		expect.equal(top.copies, 6, "copies C to S")
		expect.equal(top.cash, 15500, "cash C to S")
		local fromS = CondenseRules.gradeCostToTop(grading, config.GRADES, "Legendary", "S")
		expect.equal(fromS.copies, 0, "nothing past S")
	end,
	["grading seals cover missing duplicates, at most half a step"] = function()
		local beastA = { beast = true, foil = false, grade = "A", stars = 0 }
		-- Legendary A -> S needs 3 duplicates; half of 3, rounded down, is 1
		local plan, reason = CondenseRules.gradePlan(grading, config, "Legendary", { C = counts(2, 0) }, beastA, 5)
		assert(plan, `expected a plan, got {reason}`)
		expect.equal(plan.seals, 1, "one seal fills the gap")
		expect.equal(total(plan.takes), 2, "the two real duplicates go first")
		local none, short = CondenseRules.gradePlan(grading, config, "Legendary", {}, beastA, 5)
		expect.isNil(none, "seals can't cover more than half a step")
		expect.equal(short, "short:0:3", "reason")
		local enough = CondenseRules.gradePlan(grading, config, "Legendary", { C = counts(3, 0) }, beastA, 5)
		assert(enough, "a plan")
		expect.equal(enough.seals, 0, "no seals when the duplicates are enough")
		local without = CondenseRules.gradePlan(grading, config, "Legendary", { C = counts(3, 0) }, beastA)
		assert(without, "a plan")
		expect.equal(without.seals, 0, "no seals given")
	end,
}
