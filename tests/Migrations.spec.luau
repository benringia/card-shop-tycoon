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

	["v7: adds an empty party, keeps existing"] = function()
		local data: any = { version = 6, jobs = {} }
		Migrations.run(data, 7)
		expect.equal(typeof(data.party), "table", "party added")
		expect.equal(typeof(data.party.slots), "table", "slots")
		expect.equal(next(data.party.slots), nil, "empty")
		local kept: any = { version = 6, party = { slots = { ["1"] = "abc" }, summoned = 1 } }
		Migrations.run(kept, 7)
		expect.equal(kept.party.slots["1"], "abc", "kept slot")
		expect.equal(kept.party.summoned, 1, "kept summon")
	end,

	["v15: swordFights starts at 0 so everyone sees the button names for 3 boss fights"] = function()
		local data: any = { version = 14 }
		Migrations.run(data, 15)
		expect.equal(data.swordFights, 0)
		expect.equal(data.version, 15)
		local kept: any = { version = 14, swordFights = 2 }
		Migrations.run(kept, 15)
		expect.equal(kept.swordFights, 2, "a saved count stays")
		for _, bad in { "3", -1, 0 / 0, math.huge, 1.5 } do
			local junk: any = { version = 14, swordFights = bad }
			Migrations.run(junk, 15)
			expect.equal(junk.swordFights, 0, `junk {bad} becomes 0`)
		end
	end,

	["v14: seenSword starts false so existing players see the sword popup once"] = function()
		local data: any = { version = 13 }
		Migrations.run(data, 14)
		expect.equal(data.seenSword, false)
		expect.equal(data.version, 14)
		local kept: any = { version = 13, seenSword = true } -- Reconcile can't add true, but a bad value is replaced
		Migrations.run(kept, 14)
		expect.equal(kept.seenSword, true, "a saved true stays")
		local junk: any = { version = 13, seenSword = "yes" }
		Migrations.run(junk, 14)
		expect.equal(junk.seenSword, false, "junk becomes false")
	end,

	["v13: existing players have already seen the welcome"] = function()
		local data: any = { version = 12, seenWelcome = false } -- Reconcile may add false before the migration runs
		Migrations.run(data, 13)
		expect.equal(data.seenWelcome, true, "no welcome cinematic for existing players")
		local fresh: any = { version = 12 }
		Migrations.run(fresh, 13)
		expect.equal(fresh.seenWelcome, true, "set when missing too")
	end,

	["v12: adds an empty bosses table, keeps existing"] = function()
		local data: any = { version = 11, pity = { legendary = 0, epic = 0, firstDone = false } }
		Migrations.run(data, 12)
		expect.equal(typeof(data.bosses), "table", "bosses added")
		expect.equal(next(data.bosses), nil, "empty")
		local kept: any = { version = 11, bosses = { meadowWarden = { lootAt = 123 } } }
		Migrations.run(kept, 12)
		expect.equal(kept.bosses.meadowWarden.lootAt, 123, "kept")
	end,

	["v11: adds pity counts from zero, keeps existing"] = function()
		local data: any = { version = 10, items = {} }
		Migrations.run(data, 11)
		expect.equal(data.pity.legendary, 0, "legendary")
		expect.equal(data.pity.epic, 0, "epic")
		expect.equal(data.pity.firstDone, false, "first Legendary still to come")
		local kept: any = { version = 10, pity = { legendary = 57, epic = 12 } }
		Migrations.run(kept, 11)
		expect.equal(kept.pity.legendary, 57, "kept")
	end,

	["v10: adds empty items, keeps existing"] = function()
		local data: any = { version = 9, pvp = {} }
		Migrations.run(data, 10)
		expect.equal(typeof(data.items), "table", "items added")
		expect.equal(next(data.items), nil, "empty")
		local kept: any = { version = 9, items = { starShard = 2 } }
		Migrations.run(kept, 10)
		expect.equal(kept.items.starShard, 2, "kept")
	end,

	["v9: adds an empty pvp record, keeps existing"] = function()
		local data: any = { version = 8, resting = {} }
		Migrations.run(data, 9)
		expect.equal(typeof(data.pvp), "table", "pvp added")
		expect.equal(data.pvp.wins, 0, "wins")
		expect.equal(data.pvp.losses, 0, "losses")
		expect.equal(data.pvp.draws, 0, "draws")
		local kept: any = { version = 8, pvp = { wins = 4, losses = 1, draws = 0 } }
		Migrations.run(kept, 9)
		expect.equal(kept.pvp.wins, 4, "kept")
	end,

	["v8: adds empty resting, keeps existing"] = function()
		local data: any = { version = 7, party = { slots = {} } }
		Migrations.run(data, 8)
		expect.equal(typeof(data.resting), "table", "resting added")
		expect.equal(next(data.resting), nil, "empty")
		local kept: any = { version = 7, resting = { abc = 123 } }
		Migrations.run(kept, 8)
		expect.equal(kept.resting.abc, 123, "kept")
	end,

	["v16: an empty Armory and the Steel Sword equipped; junk cleaned"] = function()
		local data: any = { version = 15 }
		Migrations.run(data, 16)
		expect.equal(typeof(data.weapons), "table")
		expect.equal(next(data.weapons), nil)
		expect.equal(data.equippedWeapon, "starterSword")
		expect.equal(data.version, 16)
		local junk: any = { version = 15, weapons = "x", equippedWeapon = 5 }
		Migrations.run(junk, 16)
		expect.equal(typeof(junk.weapons), "table")
		expect.equal(junk.equippedWeapon, "starterSword")
	end,

	["v17: existing players skip the first visit; no gift yet"] = function()
		local data: any = { version = 16 }
		Migrations.run(data, 17)
		local tutorial = data.tutorial
		expect.equal(typeof(tutorial), "table")
		expect.equal(tutorial.firstVisit, "done", "not sent through the first visit")
		expect.equal(tutorial.step, 1)
		expect.equal(tutorial.giftClaimed, false, "Pish's gift still to come (a replay gives it)")
		expect.equal(tutorial.firstGiven, true, "no first-visit pack for an existing shop")
		expect.equal(tutorial.customerSent, true, "an existing shop gets no free customer from a replay")
		expect.equal(typeof(tutorial.lessons), "table")
		expect.equal(next(tutorial.lessons), nil)
		expect.equal(typeof(tutorial.early), "table")
		expect.equal(tutorial.pishLuckAt, 0)
		expect.equal(data.version, 17)
		local junk: any = { version = 16, tutorial = "junk" }
		Migrations.run(junk, 17)
		expect.equal(junk.tutorial.firstVisit, "done")
		expect.equal(junk.tutorial.giftClaimed, false)
	end,

	["v18: Chikin's combat tour is done for every shop past Pish's tour, still to do for one mid-tour"] = function()
		local data: any = { version = 17, tutorial = { firstVisit = "done" } }
		Migrations.run(data, 18)
		expect.equal(data.combat.firstVisit, "done", "an existing player already fights")
		expect.equal(data.combat.step, 1)
		expect.equal(typeof(data.combat.early), "table")
		expect.equal(data.version, 18)
		local skipped: any = { version = 17, tutorial = { firstVisit = "skipped" } }
		Migrations.run(skipped, 18)
		expect.equal(skipped.combat.firstVisit, "done")
		local mid: any = { version = 17, tutorial = { firstVisit = "todo", step = 3 } }
		Migrations.run(mid, 18)
		expect.equal(mid.combat.firstVisit, "todo", "a new player mid-tour gets Chikin after Pish")
		local junk: any = { version = 17, tutorial = "junk" }
		Migrations.run(junk, 18)
		expect.equal(junk.combat.firstVisit, "done", "unknown counts as done")
	end,

	["v19: dungeon.secretFound added, false; a present one kept"] = function()
		local data: any = { version = 18 }
		Migrations.run(data, 19)
		expect.equal(typeof(data.dungeon), "table", "added")
		expect.equal(data.dungeon.secretFound, false, "not found yet")
		expect.equal(data.dungeon.seenIntro, false, "the Hydra's welcome not seen yet")
		expect.equal(data.version, 19)
		local seen: any = { version = 18, dungeon = { secretFound = false, seenIntro = true } }
		Migrations.run(seen, 19)
		expect.equal(seen.dungeon.seenIntro, true, "a seen welcome kept")
		local found: any = { version = 18, dungeon = { secretFound = true } }
		Migrations.run(found, 19)
		expect.equal(found.dungeon.secretFound, true, "kept")
		local junk: any = { version = 18, dungeon = "junk" }
		Migrations.run(junk, 19)
		expect.equal(junk.dungeon.secretFound, false, "junk replaced")
	end,

	["v5: already graded stacks untouched"] = function()
		local data: any = { version = 4, cards = { FS01 = { S = { normal = 2, foil = 0 } } } }
		Migrations.run(data, 5, sequence({ "C" }))
		expect.equal(data.cards.FS01.S.normal, 2, "kept")
	end,
}
