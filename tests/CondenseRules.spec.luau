--!strict
local CondenseRules = require("../src/shared/Util/CondenseRules")
local config = require("../src/shared/Config/Beasts")
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

return {
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
}
