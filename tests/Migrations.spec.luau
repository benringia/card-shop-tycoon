--!strict
local Migrations = require("../src/server/Util/Migrations")
local expect = require("./lib/expect")

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
}
