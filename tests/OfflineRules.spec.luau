--!strict
-- Welcome-back earnings (owner 2026-11-17: "yes do the three now"): while you're away your shop keeps selling what's on
-- its shelves, at your prices and their buy chances, at a slow pace, for up to MAX_MINUTES; under MIN_AWAY_MINUTES
-- nothing. Real stock only: empty shelves earn nothing.
local OfflineRules = require("../src/shared/Util/OfflineRules")
local Offline = require("../src/shared/Config/Offline")
local expect = require("./lib/expect")

local NOW = 1_800_000_000

return {
	["time away counts from MIN_AWAY_MINUTES, capped at MAX_MINUTES"] = function()
		expect.equal(OfflineRules.minutesAway(0, NOW, Offline), 0, "a new save (never seen) earns nothing")
		expect.equal(OfflineRules.minutesAway(NOW + 60, NOW, Offline), 0, "a clock from the future earns nothing")
		expect.equal(OfflineRules.minutesAway(NOW - (Offline.MIN_AWAY_MINUTES - 1) * 60, NOW, Offline), 0, "too short")
		expect.equal(OfflineRules.minutesAway(NOW - 45 * 60, NOW, Offline), 45)
		expect.equal(OfflineRules.minutesAway(NOW - 30 * 3600, NOW, Offline), Offline.MAX_MINUTES, "capped")
	end,

	["the shop sells its shelves' stock at their prices, by buy chance, never more than it holds"] = function()
		local shelves = {
			{ units = 10, price = 3, chance = 1 },
			{ units = 30, price = 2.5, chance = 0.5 },
			{ units = 0, price = 9, chance = 1 },
		}
		local plan = OfflineRules.plan(shelves, 20, Offline) -- 20 minutes: 20 x UNITS_PER_MINUTE customers' worth
		local budget = 20 * Offline.UNITS_PER_MINUTE
		local total = 0
		for index, sold in plan.sold do
			assert(sold >= 0 and sold <= shelves[index].units, `shelf {index} sells at most its stock`)
			total += sold
		end
		assert(total <= budget, "no more than the time allows")
		expect.equal(plan.sold[3], 0, "an empty shelf sells nothing")
		assert(plan.sold[1] > 0 and plan.sold[2] > 0, "both stocked shelves sell")
		expect.near(plan.cash, plan.sold[1] * 3 + plan.sold[2] * 2.5, 0.001, "cash is what sold at its price")
		expect.equal(plan.units, total)
	end,

	["long away: a small shop sells out; a price nobody pays sells nothing"] = function()
		local plan = OfflineRules.plan({ { units = 12, price = 3, chance = 0.95 } }, Offline.MAX_MINUTES, Offline)
		assert(plan.sold[1] >= 10, "nearly all of it after two hours")
		local never = OfflineRules.plan({ { units = 12, price = 9, chance = 0 } }, Offline.MAX_MINUTES, Offline)
		expect.equal(never.units, 0, "over the top: nobody buys")
		expect.equal(never.cash, 0)
		local none = OfflineRules.plan({}, 60, Offline)
		expect.equal(none.units, 0, "no shelves, nothing")
		local short = OfflineRules.plan({ { units = 12, price = 3, chance = 1 } }, 0, Offline)
		expect.equal(short.units, 0, "no time away, nothing")
	end,

	-- the welcome-back card names what sold ("18 packs"): every product the shop sells has its word
	["every shop product has a short plural for the welcome-back card"] = function()
		local Products = require("../src/shared/Config/Products")
		for _, product in Products.List do
			local word = Offline.PLURALS[product.id]
			assert(typeof(word) == "string" and #word > 0 and #word <= 16, `{product.id} has a short plural`)
		end
	end,

	["the pace is slow next to a busy shop's: about a fifth"] = function()
		assert(Offline.UNITS_PER_MINUTE > 0 and Offline.UNITS_PER_MINUTE <= 3, "a slow pace")
		assert(Offline.MAX_MINUTES <= 180, "a few hours at most")
	end,
}
