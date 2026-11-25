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

-- v42 (the shop rooms): a save at v41, and the cells wide along x of a few shelves (unturned, turned) the way
-- DataService's footprint function gives them
local function v41(data: any): any
	data.version = 41
	return data
end
local WIDTHS: { [string]: { number } } = { WallShelf = { 1, 4 }, Shelf = { 2, 1 }, DisplayRack = { 4, 2 }, OrderComputer = { 5, 3 } }
local function footprint(id: string, rotation: number): number?
	local w = WIDTHS[id]
	return if w then w[rotation % 2 + 1] else nil
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

	-- Tips shown a few times (owner 2026-11-17: "make sure players know you can put packs in the bag"; Config/Tips):
	-- every save starts with none seen; a saved table stays for TipService to clean (TipRules.clean)
	["v32: every save starts with no tips seen; a saved table kept"] = function()
		local data: any = { version = 31, cash = 7 }
		Migrations.run(data, 32)
		expect.equal(data.version, 32)
		expect.equal(next(data.tips), nil, "an empty tips map")
		expect.equal(data.cash, 7, "the rest untouched")
		local kept: any = { version = 31, tips = { toBag = 2 } }
		Migrations.run(kept, 32)
		expect.equal(kept.tips.toBag, 2, "a saved table kept")
	end,

	-- Pish's tour gained a step after his present (owner 2026-11-17: "When the player opens their first card. Pish will
	-- then ask the player to summon them"): a saved tour step past the present moves one on, so it stays the same step
	["v35: a saved tour step past Pish's present moves one on; the present itself and junk left alone"] = function()
		local mid: any = { version = 34, tutorial = { firstVisit = "todo", step = 3 } }
		Migrations.run(mid, 35)
		expect.equal(mid.version, 35)
		expect.equal(mid.tutorial.step, 4, "orderStock stays orderStock")
		local first: any = { version = 34, tutorial = { firstVisit = "todo", step = 1 } }
		Migrations.run(first, 35)
		expect.equal(first.tutorial.step, 1, "still on the present: the new step comes next")
		local skipped: any = { version = 34, tutorial = { firstVisit = "skipped", step = 5 } }
		Migrations.run(skipped, 35)
		expect.equal(skipped.tutorial.step, 6, "a skipped tour keeps where it ended (the funnel)")
		local none: any = { version = 34, cash = 3 }
		Migrations.run(none, 35)
		expect.equal(none.tutorial, nil, "no tour saved: nothing made")
		local junk: any = { version = 34, tutorial = { step = "x" } }
		Migrations.run(junk, 35)
		expect.equal(junk.tutorial.step, "x", "junk left for TutorialRules.read")
	end,

	-- Main quests (owner 2026-11-18, look A): every save starts with no first builds paid; a saved list is kept for
	-- MainQuestRules.clean
	["v36: every save starts with no main quests done; a saved list kept"] = function()
		local data: any = { version = 35, cash = 7 }
		Migrations.run(data, 36)
		expect.equal(data.version, 36)
		expect.equal(typeof(data.mainQuests), "table")
		expect.equal(#data.mainQuests, 0, "nothing paid yet")
		expect.equal(data.cash, 7, "the rest untouched")
		local kept: any = { version = 35, mainQuests = { "Forge" } }
		Migrations.run(kept, 36)
		expect.equal(kept.mainQuests[1], "Forge", "a saved list kept")
	end,

	-- Weekly events (owner 2026-11-19: "build the weekend events"): every save starts with Lucky Sunday's luck never
	-- given; a saved table is kept for EventRules.clean
	["v37: every save starts with no event luck given; a saved table kept"] = function()
		local data: any = { version = 36, cash = 7 }
		Migrations.run(data, 37)
		expect.equal(data.version, 37)
		expect.equal(data.events.luckDay, -1, "never given")
		expect.equal(data.cash, 7, "the rest untouched")
		local kept: any = { version = 36, events = { luckDay = 20779 } }
		Migrations.run(kept, 37)
		expect.equal(kept.events.luckDay, 20779, "a saved day kept")
		local junk: any = { version = 36, events = "x" }
		Migrations.run(junk, 37)
		expect.equal(junk.events.luckDay, -1, "junk replaced")
	end,

	-- Codes (owner 2026-11-19: "yes do code box"): every save starts with no code used; a saved list is kept for
	-- CodeRules.clean
	["v38: every save starts with no codes used; a saved list kept"] = function()
		local data: any = { version = 37, cash = 7 }
		Migrations.run(data, 38)
		expect.equal(data.version, 38)
		expect.equal(typeof(data.codes), "table")
		expect.equal(#data.codes, 0, "none used")
		expect.equal(data.cash, 7, "the rest untouched")
		local kept: any = { version = 37, codes = { "ONEMOREPACK" } }
		Migrations.run(kept, 38)
		expect.equal(kept.codes[1], "ONEMOREPACK", "a saved list kept")
		local junk: any = { version = 37, codes = 5 }
		Migrations.run(junk, 38)
		expect.equal(#junk.codes, 0, "junk replaced")
	end,

	-- Posters are decor in `windows` now (owner 2026-11-19: "posters should be a decor"): the fixed front spots' list,
	-- built and dropped the same day and never released, goes; the windows stay
	-- v40 (owner 2026-11-20: "after level 20. make the leveling up more difficult"): levels past 20 cost more XP, so a
	-- saved XP total is moved onto the new curve at the same level and the same share of the way to the next
	["v40: a shop past level 20 keeps its level and its progress on the harder curve"] = function()
		local LevelMath = require("../src/shared/Util/LevelMath")
		local Levels = require("../src/shared/Config/Levels")
		local Data = require("../src/shared/Config/Data")
		expect.equal(Data.SCHEMA_VERSION >= 40, true, "the schema says so")
		local old = { BASE_XP = Levels.BASE_XP, POWER = Levels.POWER, ROUND_TO = Levels.ROUND_TO, MAX_LEVEL = Levels.MAX_LEVEL }
		local function oldAt(level: number, share: number): number
			local floor = LevelMath.getRequiredXp(old, level)
			return floor + math.floor((LevelMath.getRequiredXp(old, level + 1) - floor) * share)
		end
		for _, case in { { 21, 0 }, { 21, 0.5 }, { 30, 0.25 }, { 57, 0.4 }, { 57, 0.99 }, { 99, 0.5 } } do
			local level, share = case[1], case[2]
			local data: any = { version = 39, xp = oldAt(level, share) }
			Migrations.run(data, 40)
			expect.equal(LevelMath.getLevelForXp(Levels, data.xp), level, `Lv {level} at {share}: still Lv {level}`)
			local into, span = LevelMath.getProgress(Levels, data.xp)
			assert(math.abs(into / span - share) < 0.02, `Lv {level}: still {share} of the way ({into / span})`)
			expect.equal(data.xp, math.floor(data.xp), "whole XP")
			expect.equal(data.version, 40)
		end
	end,

	-- v41 (owner 2026-11-21: a boss kills leaderboard): the lifetime counter stats.bossKills. Kills before it were
	-- never counted, so a save starts at the bosses it has beaten at least once
	["v41: boss kills start at the bosses a save has cleared"] = function()
		local data: any = { version = 40, stats = { packsOpened = 12, customersServed = 3, totalEarned = 40 }, bosses = { meadowWarden = { cleared = true }, caveBroodQueen = { cleared = true }, emberColossus = { cleared = false }, junk = "x" } }
		Migrations.run(data, 41)
		expect.equal(data.version, 41)
		expect.equal(data.stats.bossKills, 2)
		expect.equal(data.stats.packsOpened, 12, "the other counters untouched")
		local fresh: any = { version = 40, stats = { packsOpened = 0, customersServed = 0, totalEarned = 0 } }
		Migrations.run(fresh, 41)
		expect.equal(fresh.stats.bossKills, 0)
		local none: any = { version = 40 }
		Migrations.run(none, 41)
		expect.equal(none.version, 41, "no stats table: left for the loader")
		local counted: any = { version = 40, stats = { bossKills = 9 }, bosses = { meadowWarden = { cleared = true } } }
		Migrations.run(counted, 41)
		expect.equal(counted.stats.bossKills, 9, "a count already there is kept")
	end,

	["v40: a shop at level 20 or under, at the cap, or with junk XP"] = function()
		local LevelMath = require("../src/shared/Util/LevelMath")
		local Levels = require("../src/shared/Config/Levels")
		local old = { BASE_XP = Levels.BASE_XP, POWER = Levels.POWER, ROUND_TO = Levels.ROUND_TO, MAX_LEVEL = Levels.MAX_LEVEL }
		for _, xp in { 0, 10, 5999, LevelMath.getRequiredXp(old, 20), LevelMath.getRequiredXp(old, 21) - 1 } do
			local data: any = { version = 39, xp = xp }
			Migrations.run(data, 40)
			expect.equal(data.xp, xp, `{xp} XP: untouched`)
		end
		local capped: any = { version = 39, xp = 300000 } -- past the old Lv 100 (271,500)
		Migrations.run(capped, 40)
		expect.equal(LevelMath.getLevelForXp(Levels, capped.xp), 100, "still the cap")
		expect.equal(capped.xp >= LevelMath.getRequiredXp(Levels, 100) + 28000, true, "what it had past the cap is kept")
		for _, junk in { "lots", -5, 0 / 0, math.huge } do
			local data: any = { version = 39, xp = junk }
			Migrations.run(data, 40)
			expect.equal(data.version, 40, "junk is left for the loader")
		end
		local none: any = { version = 39 }
		Migrations.run(none, 40)
		expect.isNil(none.xp)
	end,

	["v40: its curve is today's (a later change to Config/Levels needs its own migration)"] = function()
		local LevelMath = require("../src/shared/Util/LevelMath")
		local Levels = require("../src/shared/Config/Levels")
		-- the levels' floors move onto exactly today's floors
		local old = { BASE_XP = 40 / 6, POWER = 2.31, ROUND_TO = 10, MAX_LEVEL = 100 }
		for level = 21, 100 do
			local data: any = { version = 39, xp = LevelMath.getRequiredXp(old, level) }
			Migrations.run(data, 40)
			expect.equal(data.xp, LevelMath.getRequiredXp(Levels, level), `Lv {level}'s floor`)
		end
	end,

	["v39: the short-lived posters list goes; windows and the rest stay"] = function()
		local data: any = { version = 38, cash = 7, posters = { "beware", "", "", "wanted" }, windows = { { style = "Square", side = "left", at = 0 } } }
		Migrations.run(data, 39)
		expect.equal(data.version, 39)
		expect.isNil(data.posters, "dropped")
		expect.equal(#data.windows, 1, "windows untouched")
		expect.equal(data.cash, 7)
		local plain: any = { version = 38 }
		Migrations.run(plain, 39)
		expect.equal(plain.version, 39)
	end,

	-- Weekly quests (owner 2026-11-17: "what players do after daily quests?"): every save starts with no week rolled
	-- (QuestService rolls this week's); a saved week is kept for QuestRules.cleanWeek
	["v34: every save starts with no weekly quests rolled; a saved week kept"] = function()
		local data: any = { version = 33, cash = 7 }
		Migrations.run(data, 34)
		expect.equal(data.version, 34)
		expect.equal(data.weekly.week, -1, "no week rolled yet")
		expect.equal(#data.weekly.list, 0)
		expect.equal(data.weekly.chest, false)
		expect.equal(data.cash, 7, "the rest untouched")
		local kept: any = { version = 33, weekly = { week = 9, list = {}, chest = true } }
		Migrations.run(kept, 34)
		expect.equal(kept.weekly.week, 9, "a saved week kept")
		expect.equal(kept.weekly.chest, true)
	end,

	-- Daily quests and welcome-back earnings (owner 2026-11-17: "yes do the three now"): every save starts with no quests
	-- rolled yet (QuestService rolls today's) and no last-seen time (the first visit after the update earns nothing away)
	["v33: every save starts with fresh quests and no last-seen time; saved values kept"] = function()
		local data: any = { version = 32, cash = 7 }
		Migrations.run(data, 33)
		expect.equal(data.version, 33)
		expect.equal(data.quests.day, -1, "no quests rolled yet")
		expect.equal(#data.quests.list, 0)
		expect.equal(data.quests.bonus, false)
		expect.equal(data.lastSeen, 0, "never seen: nothing earned away")
		expect.equal(data.cash, 7, "the rest untouched")
		local kept: any = { version = 32, quests = { day = 5, list = {}, bonus = true }, lastSeen = 123 }
		Migrations.run(kept, 33)
		expect.equal(kept.quests.day, 5, "saved quests kept")
		expect.equal(kept.lastSeen, 123, "a saved time kept")
	end,

	-- Turts' rug shop (spec 2026-11-13-turts-shop-design): the restock a player last saw, what they bought in it, and a
	-- "restock now" roll if they bought one
	-- Chikin's tour reordered (owner 2026-11-16: the sword and its fight come in his first visit): a tour in progress
	-- keeps its place by step name; steps before the sword and finished or skipped tours are untouched
	["v31: a Chikin tour in progress keeps its place in the new order"] = function()
		-- old: hello party summon wild fight firstWin level4 sword wild2 fight2 boss
		-- new: hello party summon wild fight firstWin fight2 swordWin level4 sword wild2 boss
		local function after(step: number, firstVisit: string?): number
			local data: any = { version = 30, combat = { firstVisit = firstVisit or "todo", step = step } }
			Migrations.run(data, 31)
			expect.equal(data.version, 31)
			return data.combat.step
		end
		expect.equal(after(5), 5, "the first fight: the same")
		expect.equal(after(6), 6, "the first fight's end: the same")
		expect.equal(after(7), 9, "waiting for shop level 4")
		expect.equal(after(8), 10, "the level 4 hello")
		expect.equal(after(9), 11, "on the way to the Wild")
		expect.equal(after(10), 11, "the old sword fight: back to the Wild, then the boss")
		expect.equal(after(11), 12, "the boss goodbye")
		expect.equal(after(12), 12, "all done stays all done")
		expect.equal(after(8, "done"), 8, "a finished tour untouched")
		local none: any = { version = 30, cash = 5 }
		Migrations.run(none, 31)
		expect.isNil(none.combat, "no tour saved: nothing made up")
		local junk: any = { version = 30, combat = { firstVisit = "todo", step = "x" } }
		Migrations.run(junk, 31)
		expect.equal(junk.combat.step, "x", "junk left for TutorialRules.read")
	end,

	-- Daily, weekly and monthly gifts (spec 2026-11-15-daily-gifts-design): every save starts the round at day 1 with
	-- nothing played or earned; a saved table stays for GiftService to clean (Util/GiftRules.clean)
	["v30: every save starts the gifts fresh; a saved table kept"] = function()
		local data: any = { version = 29, cash = 50 }
		Migrations.run(data, 30)
		expect.equal(data.version, 30)
		expect.equal(data.gifts.streak, 0)
		expect.equal(data.gifts.lastDay, -1)
		expect.equal(data.gifts.claims, 0)
		expect.equal(data.cash, 50, "the rest untouched")
		local kept: any = { version = 29, gifts = { streak = 3, claims = 9 } }
		Migrations.run(kept, 30)
		expect.equal(kept.gifts.streak, 3)
		local junk: any = { version = 29, gifts = "junk" }
		Migrations.run(junk, 30)
		expect.equal(junk.gifts.streak, 0)
	end,

	-- The prologue (spec 2026-11-14-prologue-hydra-design): new saves play it once; every save from before counts it as
	-- seen, so existing players never see it
	["v29: saves from before the prologue count it as seen"] = function()
		local data: any = { version = 28, cash = 50 }
		Migrations.run(data, 29)
		expect.equal(data.version, 29)
		expect.equal(data.seenPrologue, true)
		expect.equal(data.cash, 50, "the rest untouched")
		local kept: any = { version = 28, seenPrologue = false }
		Migrations.run(kept, 29)
		expect.equal(kept.seenPrologue, false, "a flag already there is kept")
	end,

	-- One-time unlocks bought as developer products (the Extra Job Slot, owner 2026-11-14): none at first; a saved list
	-- kept for MonetizationService to clean
	["v28: every save starts with no bought unlocks; a saved list kept"] = function()
		local data: any = { version = 27, cash = 50 }
		Migrations.run(data, 28)
		expect.equal(data.version, 28)
		expect.equal(typeof(data.unlocks), "table")
		expect.isNil(data.unlocks.ExtraJobSlot)
		local kept: any = { version = 27, unlocks = { ExtraJobSlot = true } }
		Migrations.run(kept, 28)
		expect.equal(kept.unlocks.ExtraJobSlot, true)
		local junk: any = { version = 27, unlocks = 5 }
		Migrations.run(junk, 28)
		expect.equal(typeof(junk.unlocks), "table")
	end,

	-- Luck bought with Robux (Config/Luck, owner 2026-11-14): every save starts with none of either strength; a saved
	-- one is kept for LuckService to clean
	["v27: every save starts with no bought luck; a saved one kept"] = function()
		local data: any = { version = 26, cash = 50 }
		Migrations.run(data, 27)
		expect.equal(data.version, 27)
		expect.equal(data.luck.x2, 0)
		expect.equal(data.luck.x3, 0)
		expect.equal(data.cash, 50, "the rest untouched")
		local kept: any = { version = 26, luck = { x2 = 600, x3 = 0 } }
		Migrations.run(kept, 27)
		expect.equal(kept.luck.x2, 600)
		local junk: any = { version = 26, luck = "x" }
		Migrations.run(junk, 27)
		expect.equal(junk.luck.x2, 0)
	end,

	-- Shop windows (spec 2026-11-14-shop-windows-design): every shop starts with none; a list already there is kept
	-- for WindowService to clean (it pays back what no longer fits)
	["v26: every shop starts with no windows; a saved list kept"] = function()
		local data: any = { version = 25, cash = 50 }
		Migrations.run(data, 26)
		expect.equal(data.version, 26)
		expect.equal(typeof(data.windows), "table")
		expect.equal(#data.windows, 0)
		expect.equal(data.cash, 50, "the rest untouched")
		local kept: any = { version = 25, windows = { { style = "Square", side = "left", at = 0 } } }
		Migrations.run(kept, 26)
		expect.equal(#kept.windows, 1)
		local junk: any = { version = 25, windows = "x" }
		Migrations.run(junk, 26)
		expect.equal(typeof(junk.windows), "table")
	end,

	-- Shop decor (spec 2026-11-14-shop-decor-design): the look in use and the looks bought
	["v25: every shop starts in Cozy Wood with no looks bought; junk cleaned"] = function()
		local data: any = { version = 24, cash = 50 }
		Migrations.run(data, 25)
		expect.equal(data.version, 25)
		expect.equal(data.decor.look, "CozyWood")
		expect.equal(#data.decor.owned, 0)
		expect.equal(data.cash, 50, "the rest untouched")
		local kept: any = { version = 24, decor = { look = "NeonArcade", owned = { "NeonArcade", 3 } } }
		Migrations.run(kept, 25)
		expect.equal(kept.decor.look, "NeonArcade")
		expect.equal(table.concat(kept.decor.owned, ","), "NeonArcade", "only ids kept")
		local junk: any = { version = 24, decor = { look = 4, owned = "x" } }
		Migrations.run(junk, 25)
		expect.equal(junk.decor.look, "CozyWood")
		expect.equal(#junk.decor.owned, 0)
	end,

	["v24: Turts' shop starts with nothing bought; a saved one kept, junk cleaned"] = function()
		local data: any = { version = 23, cash = 50 }
		Migrations.run(data, 24)
		expect.equal(data.version, 24)
		expect.equal(data.turts.index, 0)
		expect.equal(#data.turts.bought, 0)
		expect.equal(data.turts.personal, nil)
		expect.equal(data.cash, 50, "the rest untouched")
		local kept: any = { version = 23, turts = { index = 9, bought = { "vrPack", 3 }, personal = { index = 9, offers = { "goldSeal", "xpTonic", "starShard" } } } }
		Migrations.run(kept, 24)
		expect.equal(kept.turts.index, 9)
		expect.equal(table.concat(kept.turts.bought, ","), "vrPack", "only offer ids kept")
		expect.equal(#kept.turts.personal.offers, 3)
		local junk: any = { version = 23, turts = { index = "x", bought = "y", personal = { index = 9, offers = "z" } } }
		Migrations.run(junk, 24)
		expect.equal(junk.turts.index, 0)
		expect.equal(#junk.turts.bought, 0)
		expect.equal(junk.turts.personal, nil, "a broken roll dropped")
	end,

	-- owner 2026-11-13: titles stay earned once earned; new ones are told once and marked new till the Titles tab is seen
	["v23: titles known and new start empty, not seeded; junk cleaned"] = function()
		local data: any = { version = 22 }
		Migrations.run(data, 23)
		expect.equal(data.version, 23)
		expect.equal(#data.titles.known == 0 and #data.titles.fresh == 0 and data.titles.seeded == false, true)
		local junk: any = { version = 22, titles = { known = { "tycoon", 5 }, fresh = "x", seeded = true } }
		Migrations.run(junk, 23)
		expect.equal(table.concat(junk.titles.known, ","), "tycoon", "only names kept")
		expect.equal(#junk.titles.fresh == 0 and junk.titles.seeded == true, true)
	end,

	-- "Support the dev" (owner 2026-11-12): how many gifts and the best tier
	["v22: support starts at no gifts; a saved one kept, junk cleaned"] = function()
		local data: any = { version = 21 }
		Migrations.run(data, 22)
		expect.equal(data.version, 22)
		expect.equal(data.support.gifts == 0 and data.support.best == 0, true, "nobody gave yet")
		local junk: any = { version = 21, support = { gifts = "x", best = 2 } }
		Migrations.run(junk, 22)
		expect.equal(junk.support.gifts == 0 and junk.support.best == 2, true)
	end,

	-- spec 2026-11-12-timed-upgrades-revive-design: station jobs, unused skips, remembered receipts
	["v21: upgrades, skip tokens and purchases start empty; junk replaced"] = function()
		local data: any = { version = 20 }
		Migrations.run(data, 21)
		expect.equal(data.version, 21)
		expect.equal(typeof(data.upgrades) == "table" and next(data.upgrades) == nil, true, "no jobs")
		expect.equal(data.skipTokens.S == 0 and data.skipTokens.M == 0 and data.skipTokens.L == 0, true, "no skips")
		expect.equal(typeof(data.purchases) == "table" and #data.purchases == 0, true, "no receipts")
		local junk: any = { version = 20, purchases = "x", skipTokens = { S = 2, M = "y" }, upgrades = 5 }
		Migrations.run(junk, 21)
		expect.equal(typeof(junk.purchases) == "table" and #junk.purchases == 0, true, "junk receipts: none")
		expect.equal(junk.skipTokens.S == 2 and junk.skipTokens.M == 0 and junk.skipTokens.L == 0, true, "a good count kept, junk zero")
		expect.equal(typeof(junk.upgrades) == "table", true, "junk jobs: none")
	end,

	["v20: title added (\"\": automatic); a saved string kept"] = function()
		local data: any = { version = 19 }
		Migrations.run(data, 20)
		expect.equal(data.title, "", "automatic for everyone")
		expect.equal(data.version, 20)
		local kept: any = { version = 19, title = "crystalSeeker" }
		Migrations.run(kept, 20)
		expect.equal(kept.title, "crystalSeeker")
		local junk: any = { version = 19, title = 5 }
		Migrations.run(junk, 20)
		expect.equal(junk.title, "", "junk: automatic")
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

	-- v42 (spec 2026-11-23-shop-rooms-design): the shop became 50 x 60 with its hall 5 studs wider each side and the
	-- floor's middle 10 studs further back; nothing moves away from the street
	["v42: rooms start closed; a junk value replaced"] = function()
		local data = v41({ rooms = "x" })
		Migrations.run(data, 42, nil, footprint)
		expect.equal(typeof(data.rooms), "table")
		expect.equal(#data.rooms, 0)
		local fresh = v41({})
		Migrations.run(fresh, 42, nil, footprint)
		expect.equal(typeof(fresh.rooms), "table")
	end,

	["v42: things by a side wall stay by it, the rest stay centred"] = function()
		local data = v41({
			layout = {
				{ shelfId = "WallShelf", gridX = 0, gridZ = 5, rotation = 0 }, -- by the left wall
				{ shelfId = "Shelf", gridX = 2, gridZ = 6, rotation = 0 }, -- within 4 studs of it
				{ shelfId = "Shelf", gridX = 3, gridZ = 7, rotation = 0 }, -- the middle: +3
				{ shelfId = "DisplayRack", gridX = 8, gridZ = 8, rotation = 0 },
				{ shelfId = "Shelf", gridX = 16, gridZ = 9, rotation = 0 }, -- its right edge within 4 studs of the right wall: +5
				{ shelfId = "Shelf", gridX = 18, gridZ = 10, rotation = 0 },
			},
			fixtures = { OrderComputer = { gridX = 15, gridZ = 17, rotation = 0 } },
		})
		Migrations.run(data, 42, nil, footprint)
		local xs = {}
		for index, entry in data.layout do
			xs[index] = entry.gridX
		end
		expect.equal(table.concat(xs, ","), "0,2,6,11,21,23")
		expect.equal(data.layout[4].gridZ, 8, "the distance from the street never changes")
		expect.equal(data.fixtures.OrderComputer.gridX, 20)
		expect.equal(data.fixtures.OrderComputer.gridZ, 17)
	end,

	["v42: a turned rack uses its turned width"] = function()
		local data = v41({ layout = { { shelfId = "DisplayRack", gridX = 16, gridZ = 3, rotation = 1 } } }) -- 2 wide turned: 16..18
		Migrations.run(data, 42, nil, footprint)
		expect.equal(data.layout[1].gridX, 21)
	end,

	["v42: side windows keep their spot; front posters stay on their pane"] = function()
		local data = v41({
			windows = {
				{ style = "Square", side = "left", at = 0 },
				{ style = "PosterBeware", side = "right", at = 12 },
				{ style = "PosterWanted", side = "front", at = 18.5 },
				{ style = "PosterOneMore", side = "front", at = -13.5 },
				{ style = "Wide", side = "back", at = 4 },
			},
		})
		Migrations.run(data, 42, nil, footprint)
		expect.equal(data.windows[1].at, -10)
		expect.equal(data.windows[2].at, 2)
		expect.near(data.windows[3].at, 6 + 2.5 * 20 / 3, 1e-6)
		expect.equal(data.windows[4].at, -16)
		expect.equal(data.windows[5].side, "back")
		expect.equal(data.windows[5].at, 4, "the load's clean moves it")
	end,

	["v42: junk and unknown things are left for the loader"] = function()
		local data = v41({ layout = { "junk", { shelfId = "Gone", gridX = 19, gridZ = 1, rotation = 0 }, { shelfId = "Shelf", gridX = "x" } }, fixtures = "x", windows = 5 })
		Migrations.run(data, 42, nil, footprint)
		expect.equal(data.layout[1], "junk")
		expect.equal(data.layout[2].gridX, 24, "1 wide when unknown: by the right wall")
		expect.equal(data.layout[3].gridX, "x")
		expect.equal(data.fixtures, "x")
		expect.equal(data.windows, 5)
	end,

	-- v43 (spec 2026-11-24-storage-racks-design): a storage rack's boxes ride on its layout entry (`boxes`); a save from
	-- before has no racks, so nothing moves
	["v43 (storage racks): nothing moves; a v42 layout comes through as it was"] = function()
		local Data = require("../src/shared/Config/Data")
		expect.equal(Data.SCHEMA_VERSION >= 43, true, "the schema is at v43: saves carry racks' boxes")
		local data = v41({
			layout = {
				{ shelfId = "Shelf", gridX = 8, gridZ = 3, rotation = 0, units = 12, productId = "FirstSparkPack", paid = 100 },
				{ shelfId = "WallShelf", gridX = 1, gridZ = 9, rotation = 1, units = 0, paid = 350 },
			},
		})
		Migrations.run(data, 42, nil, footprint)
		local before = table.clone(data.layout)
		local first, second = table.clone(data.layout[1]), table.clone(data.layout[2])
		Migrations.run(data, 43, nil, footprint)
		expect.equal(data.version, 43)
		expect.equal(#data.layout, #before)
		for key, value in first do
			expect.equal(data.layout[1][key], value, `first entry's {key}`)
		end
		for key, value in second do
			expect.equal(data.layout[2][key], value, `second entry's {key}`)
		end
		expect.isNil(data.layout[1].boxes, "no boxes added")
		expect.isNil(data.layout[2].boxes, "no boxes added")
	end,

	-- v44 (weapons round 4 part 2, spec 2026-11-25-weapons-round4-design): a weapon's record may carry its mutation and
	-- one waiting for the player's choice; a save from before has none, so its weapons come through as they were
	["v44 (mutations): weapons come through as they were"] = function()
		local Data = require("../src/shared/Config/Data")
		expect.equal(Data.SCHEMA_VERSION >= 44, true, "the schema is at v44: weapons carry mutations")
		local data = {
			version = 43,
			weapons = { verdantBlade = { grade = "A", level = 5 }, forgeSword_Ember = { grade = "C", level = 0 } },
			equippedWeapon = "verdantBlade",
		}
		Migrations.run(data, 44, nil, footprint)
		expect.equal(data.version, 44)
		expect.equal(data.weapons.verdantBlade.grade, "A")
		expect.equal(data.weapons.verdantBlade.level, 5)
		expect.isNil(data.weapons.verdantBlade.mutation, "no mutation added")
		expect.equal(data.weapons.forgeSword_Ember.grade, "C")
		expect.equal(data.equippedWeapon, "verdantBlade")
	end,

	["v42: a save from before v41 runs every step up to it (the footprint reaches step 41)"] = function()
		local data = v41({ layout = { { shelfId = "Shelf", gridX = 18, gridZ = 0, rotation = 0 } } })
		data.version = 40
		data.stats = { packsOpened = 0, customersServed = 0, totalEarned = 0 }
		Migrations.run(data, 42, nil, footprint)
		expect.equal(data.layout[1].gridX, 23)
		expect.equal(data.version, 42)
	end,
}
