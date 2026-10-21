--!strict
local Migrations = require("../src/server/Util/Migrations")
local expect = require("./lib/expect")

local function sequence(grades: { string }): () -> string
	local i = 0
	return function()
		i += 1
		return grades[(i - 1) % #grades + 1]
	end
end

return {
	["v4: lowers saved beast stars by one, not below 0"] = function()
		local data: any = { version = 3, beasts = { a = { stars = 1 }, b = { stars = 3 }, c = { stars = 0 } } }
		Migrations.run(data, 4)
		expect.equal(data.beasts.a.stars, 0, "1 -> 0")
		expect.equal(data.beasts.b.stars, 2, "3 -> 2")
		expect.equal(data.beasts.c.stars, 0, "0 stays 0")
		expect.equal(data.version, 4, "version")
	end,

	["v4: lowers displayed card stars"] = function()
		local data: any = {
			version = 3,
			beasts = {},
			layout = { { shelfId = "CardCase", cards = { { slot = 1, cardId = "FS30", stars = 2 }, { slot = 2, cardId = "FS01" } } } },
		}
		Migrations.run(data, 4)
		expect.equal(data.layout[1].cards[1].stars, 1, "displayed beast")
		expect.isNil(data.layout[1].cards[2].stars, "plain displayed card untouched")
	end,

	["v4: tolerates missing and junk tables"] = function()
		local data: any = { version = 3, layout = { "junk", { cards = "junk" } } }
		Migrations.run(data, 4)
		expect.equal(data.version, 4, "version")
	end,

	["run: v4 data unchanged"] = function()
		local data: any = { version = 4, beasts = { a = { stars = 2 } } }
		Migrations.run(data, 4)
		expect.equal(data.beasts.a.stars, 2, "not lowered twice")
	end,

	["run: newer save is never downgraded"] = function()
		local data: any = { version = 5, beasts = { a = { stars = 2 } } }
		Migrations.run(data, 4)
		expect.equal(data.version, 5, "version kept")
		expect.equal(data.beasts.a.stars, 2, "stars untouched")
	end,

	["run: v1 goes through every step"] = function()
		local data: any = { showcase = { 1 } }
		Migrations.run(data, 4)
		expect.isNil(data.showcase, "v2 dropped showcase")
		expect.equal(typeof(data.beasts), "table", "v3 added beasts")
		expect.equal(data.version, 4, "version")
	end,
	["v5: splits old stacks into grades"] = function()
		local data: any = { version = 4, cards = { FS01 = { normal = 3, foil = 1 } }, beasts = {} }
		Migrations.run(data, 5, sequence({ "S", "C", "C", "B" }))
		local stack = data.cards.FS01
		expect.equal(stack.S.normal, 1, "S normal")
		expect.equal(stack.C.normal, 2, "C normal")
		expect.equal(stack.B.foil, 1, "B foil")
		expect.equal(data.version, 5, "version")
	end,

	["v5: levelled and displayed cards get a grade, existing grades kept"] = function()
		local data: any = {
			version = 4,
			cards = {},
			beasts = { a = { cardId = "FS01", stars = 0 }, b = { cardId = "FS02", stars = 0, grade = "A" } },
			layout = { { cards = { { slot = 1, cardId = "FS03" } } } },
		}
		Migrations.run(data, 5, sequence({ "B" }))
		expect.equal(data.beasts.a.grade, "B", "rolled")
		expect.equal(data.beasts.b.grade, "A", "kept")
		expect.equal(data.layout[1].cards[1].grade, "B", "displayed rolled")
	end,

	["v5: huge counts are capped, totals kept"] = function()
		local calls = 0
		local data: any = { version = 4, cards = { FS01 = { normal = 1e9, foil = -5 }, FS02 = { normal = 0 / 0 } } }
		Migrations.run(data, 5, function()
			calls += 1
			return "S"
		end)
		local stack = data.cards.FS01
		expect.equal((stack.S and stack.S.normal or 0) + (stack.C and stack.C.normal or 0), 1e9, "total normal")
		assert(calls <= 10000, `rolled {calls} times`)
		expect.equal(next(data.cards.FS02 or {}), nil, "NaN stack empty")
	end,

	["v6: adds an empty jobs list, keeps existing"] = function()
		local data: any = { version = 5, cards = {} }
		Migrations.run(data, 6)
		expect.equal(typeof(data.jobs), "table", "jobs added")
		expect.equal(next(data.jobs), nil, "empty")
		local kept: any = { version = 5, jobs = { { slot = 1, beastId = "a", job = "Cashier" } } }
		Migrations.run(kept, 6)
		expect.equal(kept.jobs[1].job, "Cashier", "kept")
	end,

	["v5: already graded stacks untouched"] = function()
		local data: any = { version = 4, cards = { FS01 = { S = { normal = 2, foil = 0 } } } }
		Migrations.run(data, 5, sequence({ "C" }))
		expect.equal(data.cards.FS01.S.normal, 2, "kept")
	end,
}
