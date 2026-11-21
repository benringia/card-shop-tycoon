--!strict
-- Timed station upgrades (owner 2026-11-12: "forge, condenser, and grading station should have a waiting time on
-- upgrades, the higher the upgrade the longer wait time"; spec 2026-11-12-timed-upgrades-revive-design): the waits, the
-- skip tiers, the clock and the saved jobs (Util/UpgradeRules, Config/Upgrades)
local UpgradeRules = require("../src/shared/Util/UpgradeRules")
local cfg = require("../src/shared/Config/Upgrades")
-- Config/Cards builds Color3s (not loadable in Lune): readJob only needs its ById, built here from the plain list
local Cards = { ById = {} :: { [string]: any } }
for index, row in require("../src/shared/Config/CardList").SET1 do
	local id = string.format("FS%02d", index) -- Cards.luau's ids for set 1 (First Spark)
	Cards.ById[id] = { id = id, name = row[1] }
end
local Weapons = require("../src/shared/Config/Weapons")
local expect = require("./lib/expect")

return {
	["waits grow with the upgrade, crafting the longest (owner: up to 1 hour)"] = function()
		expect.equal(UpgradeRules.seconds(cfg, "star", 1), 30)
		expect.equal(UpgradeRules.seconds(cfg, "star", 5), 1800)
		expect.equal(UpgradeRules.seconds(cfg, "grade", "S"), 3600)
		expect.equal(UpgradeRules.seconds(cfg, "level", 10), 1800)
		expect.equal(UpgradeRules.seconds(cfg, "craft"), 3600)
		for kind, waits in cfg.WAITS do -- nothing longer than crafting, nothing over an hour (before its rarity)
			local list = if typeof(waits) == "table" then waits else { waits }
			for _, s in list do
				expect.equal(s <= cfg.WAITS.craft and s <= 3600, true, kind)
			end
		end
	end,

	-- owner 2026-11-20: "adjust upgrade times. the rarer/stronger the item the longer the wait time for upgraade"
	["the rarer the card or weapon, the longer every upgrade waits"] = function()
		local order = { "Common", "Rare", "Very Rare", "Epic", "Legendary" }
		local jobs: { { any } } = { { "star", 1 }, { "star", 5 }, { "grade", "B" }, { "grade", "S" }, { "level", 1 }, { "level", 10 }, { "reforge" }, { "craft" } }
		for _, job in jobs do
			local last = 0
			for _, rarity in order do
				local seconds = UpgradeRules.seconds(cfg, job[1], job[2], rarity)
				assert(seconds > last, `{job[1]} {tostring(job[2])}: a {rarity} waits {seconds}, more than the rarity before ({last})`)
				expect.equal(seconds, math.floor(seconds), "whole seconds")
				assert(seconds <= cfg.MAX_WAIT, `{job[1]} {rarity}: never over {cfg.MAX_WAIT} s`)
				last = seconds
			end
		end
		expect.equal(cfg.RARITY_TIMES["Very Rare"], 1, "the tables are a Very Rare's waits")
		expect.equal(UpgradeRules.seconds(cfg, "star", 5, "Very Rare"), 1800)
		expect.equal(UpgradeRules.seconds(cfg, "star", 5, "Legendary"), 1800 * cfg.RARITY_TIMES.Legendary)
		expect.equal(UpgradeRules.seconds(cfg, "star", 1, "Common"), 30 * cfg.RARITY_TIMES.Common)
		expect.equal(UpgradeRules.seconds(cfg, "star", 5), 1800, "no rarity given: the table's own")
		expect.equal(UpgradeRules.seconds(cfg, "star", 5, "Mythic"), 1800, "an unknown one too")
	end,

	["the stronger the upgrade, the longer too, at every rarity"] = function()
		for rarity in cfg.RARITY_TIMES do
			for stars = 2, 5 do
				assert(UpgradeRules.seconds(cfg, "star", stars, rarity) > UpgradeRules.seconds(cfg, "star", stars - 1, rarity), `{rarity} star {stars}`)
			end
			for level = 2, 10 do
				assert(UpgradeRules.seconds(cfg, "level", level, rarity) > UpgradeRules.seconds(cfg, "level", level - 1, rarity), `{rarity} +{level}`)
			end
		end
	end,

	["the longest wait is a job the save still reads back, and a skip still has a price"] = function()
		local longest = UpgradeRules.seconds(cfg, "craft", nil, "Legendary")
		expect.equal(longest <= cfg.MAX_WAIT, true)
		local job = UpgradeRules.readJob({ kind = "level", startedAt = 1000, finishAt = 1000 + cfg.MAX_WAIT, weaponId = Weapons.WEAPONS[1].id, grade = "C", level = 1 }, Cards, Weapons)
		assert(job ~= nil, "a job as long as the longest wait isn't junk")
		expect.equal(UpgradeRules.tier(cfg, cfg.MAX_WAIT), cfg.TIERS[#cfg.TIERS].name)
	end,

	["a skip's tier by the time left"] = function()
		expect.equal(UpgradeRules.tier(cfg, 299), "S")
		expect.equal(UpgradeRules.tier(cfg, 301), "M")
		expect.equal(UpgradeRules.tier(cfg, 1201), "L")
		expect.equal(UpgradeRules.tier(cfg, 3600), "L")
	end,

	["clocks and the busy line"] = function()
		expect.equal(UpgradeRules.clock(45), "0:45")
		expect.equal(UpgradeRules.clock(750), "12:30")
		expect.equal(UpgradeRules.clock(3600), "1:00:00")
		expect.equal(UpgradeRules.busyText("Forge", 750), "The Forge is busy (12:30 left)")
	end,

	["a token covers its tier or smaller, the smallest one first"] = function()
		expect.equal(UpgradeRules.tokenFor({ S = 0, M = 1, L = 1 }, "S", cfg), "M")
		expect.equal(UpgradeRules.tokenFor({ S = 0, M = 0, L = 0 }, "S", cfg), nil)
		expect.equal(UpgradeRules.tokenFor({ S = 2, M = 0, L = 0 }, "M", cfg), nil)
	end,

	["a saved job is read back, or nil when it can't be (its item is given back by the caller)"] = function()
		local cardId = next(Cards.ById) :: string
		local weaponId = Weapons.WEAPONS[1].id
		local beast = { id = "b1", cardId = cardId, foil = false, level = 1, xp = 0, stars = 1, grade = "C" }
		expect.equal(UpgradeRules.readJob({ kind = "star", startedAt = 100, finishAt = 130, beast = beast }, Cards, Weapons) ~= nil, true)
		expect.equal(UpgradeRules.readJob({ kind = "craft", startedAt = 100, finishAt = 3700, weaponId = weaponId, grade = "A" }, Cards, Weapons) ~= nil, true)
		expect.equal(UpgradeRules.readJob({ kind = "bake", startedAt = 100, finishAt = 130, beast = beast }, Cards, Weapons), nil, "unknown kind")
		-- the Recycler's job (owner 2026-11-21: "add timers for every conversion"): no item inside, what it will give
		local recycle = UpgradeRules.readJob({ kind = "recycle", startedAt = 100, finishAt = 200, gains = { { item = "wildOre", count = 5 }, { item = "starShard", count = 1 } }, cash = 87.6 }, Cards, Weapons)
		assert(recycle and recycle.gains and #recycle.gains == 2, "read back")
		expect.equal(recycle.gains[1].item, "wildOre")
		expect.equal(recycle.gains[1].count, 5)
		expect.equal(recycle.cash, 87.6)
		-- junk in it is dropped, what's good is kept (nothing is lost for one bad line)
		local partly = UpgradeRules.readJob({ kind = "recycle", startedAt = 100, finishAt = 200, gains = { { item = "wildOre", count = 5 }, { item = 7, count = 1 }, { item = "xpTonic", count = -2 }, "x" }, cash = "lots" }, Cards, Weapons)
		assert(partly and partly.gains and #partly.gains == 1, "the good line kept")
		expect.equal(partly.cash, 0)
		expect.equal(UpgradeRules.readJob({ kind = "recycle", startedAt = 100, finishAt = 200, gains = {}, cash = 0 }, Cards, Weapons), nil, "nothing in it")
		expect.equal(UpgradeRules.readJob({ kind = "recycle", startedAt = 100, finishAt = 200, cash = 12 }, Cards, Weapons) ~= nil, true, "cash alone")
		expect.equal(UpgradeRules.readJob({ kind = "recycle", startedAt = 100, finishAt = 200, cash = 12, beast = beast }, Cards, Weapons), nil, "never an item too")
		expect.equal(UpgradeRules.readJob({ kind = "star", startedAt = 100, finishAt = 130, beast = beast, gains = { { item = "wildOre", count = 5 } } }, Cards, Weapons) ~= nil, true, "a card's job ignores gains")
		expect.equal(cfg.STATIONS.recycler, "Recycler")
		expect.equal(UpgradeRules.readJob({ kind = "star", startedAt = 100, finishAt = 130 }, Cards, Weapons), nil, "no item")
		expect.equal(UpgradeRules.readJob({ kind = "star", startedAt = 130, finishAt = 100, beast = beast }, Cards, Weapons), nil, "ends before it starts")
		expect.equal(UpgradeRules.readJob({ kind = "star", startedAt = 100, finishAt = 130, plain = { cardId = "nope", foil = false, grade = "B" } }, Cards, Weapons), nil, "unknown card")
	end,

	["a job is due once its time is up (also while you were away)"] = function()
		expect.equal(UpgradeRules.due({ finishAt = 200 } :: any, 199), false)
		expect.equal(UpgradeRules.due({ finishAt = 200 } :: any, 200), true)
		expect.equal(UpgradeRules.due({ finishAt = 200 } :: any, 90000), true, "finished hours ago, offline")
	end,

	-- owner 2026-11-20: "Condenser: sometimes it says Ready when it's still counting down". A finished job leaves a
	-- note for its reveal (the player's CondenserDone); a note that outlived its Take it out showed "Ready!" again over
	-- the next job. A machine with a job in it is never ready
	["a machine says Ready only with nothing inside and a result waiting"] = function()
		expect.equal(UpgradeRules.showsReady(false, "FS01|0|C|1|1"), true, "finished, waiting to be taken out")
		expect.equal(UpgradeRules.showsReady(true, "FS01|0|C|1|1"), false, "the next one is still counting down")
		expect.equal(UpgradeRules.showsReady(true, nil), false)
		expect.equal(UpgradeRules.showsReady(false, nil), false, "empty")
		expect.equal(UpgradeRules.showsReady(false, ""), false)
		expect.equal(UpgradeRules.showsReady(false, true), true, "the Forge's own flag")
	end,

	-- owner 2026-11-20: "Grading a rare/stronger card should take 45mins to hours" (a Legendary's Grade S took 50
	-- minutes, its Grade A 16)
	["grading a rare or strong card takes 45 minutes to hours"] = function()
		local function minutes(grade: string, rarity: string): number
			return UpgradeRules.seconds(cfg, "grade", grade, rarity) / 60
		end
		assert(minutes("S", "Rare") >= 45, "a Rare's Grade S")
		assert(minutes("A", "Epic") >= 45, "an Epic's Grade A")
		assert(minutes("A", "Legendary") >= 60, "a Legendary's Grade A: an hour")
		expect.equal(minutes("S", "Legendary"), 120, "a Legendary's Grade S: two hours")
		expect.equal(minutes("S", "Epic"), 90)
		assert(minutes("B", "Common") <= 10, "a Common's first step stays short")
		for _, rarity in { "Common", "Rare", "Very Rare", "Epic", "Legendary" } do
			assert(minutes("B", rarity) < minutes("A", rarity) and minutes("A", rarity) < minutes("S", rarity), `{rarity}: each grade longer`)
			assert(UpgradeRules.seconds(cfg, "grade", "S", rarity) <= cfg.MAX_WAIT, rarity)
		end
	end,
}
