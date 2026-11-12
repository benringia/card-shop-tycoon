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
		expect.equal(UpgradeRules.seconds(cfg, "grade", "S"), 1500)
		expect.equal(UpgradeRules.seconds(cfg, "level", 10), 1800)
		expect.equal(UpgradeRules.seconds(cfg, "craft"), 3600)
		for kind, waits in cfg.WAITS do -- nothing longer than crafting, nothing over an hour
			local list = if typeof(waits) == "table" then waits else { waits }
			for _, s in list do
				expect.equal(s <= cfg.WAITS.craft and s <= 3600, true, kind)
			end
		end
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
		expect.equal(UpgradeRules.readJob({ kind = "star", startedAt = 100, finishAt = 130 }, Cards, Weapons), nil, "no item")
		expect.equal(UpgradeRules.readJob({ kind = "star", startedAt = 130, finishAt = 100, beast = beast }, Cards, Weapons), nil, "ends before it starts")
		expect.equal(UpgradeRules.readJob({ kind = "star", startedAt = 100, finishAt = 130, plain = { cardId = "nope", foil = false, grade = "B" } }, Cards, Weapons), nil, "unknown card")
	end,

	["a job is due once its time is up (also while you were away)"] = function()
		expect.equal(UpgradeRules.due({ finishAt = 200 } :: any, 199), false)
		expect.equal(UpgradeRules.due({ finishAt = 200 } :: any, 200), true)
		expect.equal(UpgradeRules.due({ finishAt = 200 } :: any, 90000), true, "finished hours ago, offline")
	end,
}
