--!strict
-- The early game never makes you wait (owner 2026-11-20: "optimize early game, players should NOT wait for something
-- in early game"): a new shop's deliveries, a fainted creature's rest and the stations' timers are short, growing to
-- their normal lengths as the shop does
local EarlyRules = require("../src/shared/Util/EarlyRules")
local Early = require("../src/shared/Config/Early")
local Stock = { DELIVERY_SECONDS = 10 } -- Config/Stock's (it needs Roblox to load)
local Combat = require("../src/shared/Config/Combat")
local Upgrades = require("../src/shared/Config/Upgrades")
local Customers = require("../src/shared/Config/Customers")
local expect = require("./lib/expect")

return {
	["the early game is the new shop's own window"] = function()
		expect.equal(Early.fullUntil, Customers.NEW_SHOP.fullUntil, "as long as the new shop's customer boost")
		expect.equal(Early.goneAt, Customers.NEW_SHOP.goneAt)
		expect.equal(EarlyRules.share(1, Early), 1)
		expect.equal(EarlyRules.share(Early.fullUntil, Early), 1)
		expect.equal(EarlyRules.share(Early.goneAt, Early), 0)
		expect.equal(EarlyRules.share(60, Early), 0)
		local last = 1
		for level = Early.fullUntil, Early.goneAt do
			local share = EarlyRules.share(level, Early)
			assert(share <= last, "it only fades")
			last = share
		end
	end,

	["an order arrives in a few seconds in a new shop, in ten later"] = function()
		expect.equal(EarlyRules.delivery(1, Early, Stock.DELIVERY_SECONDS), 3)
		expect.equal(EarlyRules.delivery(8, Early, Stock.DELIVERY_SECONDS), 3)
		expect.equal(EarlyRules.delivery(15, Early, Stock.DELIVERY_SECONDS), Stock.DELIVERY_SECONDS)
		local mid = EarlyRules.delivery(12, Early, Stock.DELIVERY_SECONDS)
		assert(mid > 3 and mid < Stock.DELIVERY_SECONDS, "growing in between")
	end,

	["a fainted creature rests a minute in the early game, five later"] = function()
		expect.equal(EarlyRules.rest(1, Early, Combat.REST_SECONDS), 60)
		expect.equal(EarlyRules.rest(8, Early, Combat.REST_SECONDS), 60)
		expect.equal(EarlyRules.rest(15, Early, Combat.REST_SECONDS), Combat.REST_SECONDS)
		expect.equal(EarlyRules.rest(40, Early, Combat.REST_SECONDS), Combat.REST_SECONDS)
		expect.equal(EarlyRules.restWords(60), "1:00")
		expect.equal(EarlyRules.restWords(300), "5:00")
		expect.equal(EarlyRules.restWords(204), "3:24")
	end,

	["the stations' timers are a quarter as long in the early game"] = function()
		local star = Upgrades.WAITS.star[1]
		expect.equal(EarlyRules.stationWait(star, 1, Early), math.round(star * Early.stationWait))
		assert(EarlyRules.stationWait(star, 1, Early) <= 10, "a first star is seconds away")
		expect.equal(EarlyRules.stationWait(star, 15, Early), star)
		expect.equal(EarlyRules.stationWait(Upgrades.WAITS.craft, 30, Early), Upgrades.WAITS.craft, "later as before")
		assert(EarlyRules.stationWait(1, 1, Early) >= 1, "never nothing")
	end,
}
