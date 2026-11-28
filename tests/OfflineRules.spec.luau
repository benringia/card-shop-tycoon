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

	["away time: racks add 30 minutes each with a restocker"] = function()
		expect.equal(Offline.RACK_MINUTES, 30)
		expect.equal(Offline.MAX_EXTRA_MINUTES, 120)
		local base, extra = OfflineRules.split(240, 3, true, Offline)
		expect.equal(base, 120)
		expect.equal(extra, 90, "3 racks: an hour and a half more")
		base, extra = OfflineRules.split(240, 3, false, Offline)
		expect.equal(extra, 0, "no restocker: no extra time")
		base, extra = OfflineRules.split(100, 3, true, Offline)
		expect.equal(base, 100)
		expect.equal(extra, 0, "home before the shelves' time ran out")
		base, extra = OfflineRules.split(240, 5, true, Offline)
		expect.equal(extra, 120, "never past MAX_EXTRA_MINUTES")
		base, extra = OfflineRules.split(240, 0, true, Offline)
		expect.equal(extra, 0, "no rack holds boxes")
	end,

	["minutesAway's cap"] = function()
		expect.equal(OfflineRules.minutesAway(NOW - 300 * 60, NOW, Offline, 240), 240)
		expect.equal(OfflineRules.minutesAway(NOW - 300 * 60, NOW, Offline), Offline.MAX_MINUTES, "no cap given: today's")
	end,

	["planRacks: shelves first, racks refill, extra time sells racks only"] = function()
		local stock = { { productId = "FirstSparkPack", shelf = 10, rack = 48, price = 3, chance = 1 } }
		local plan = OfflineRules.planRacks(stock, 120, 0, Offline)
		expect.equal(plan.fromShelves[1], 10)
		expect.equal(plan.fromRacks[1], 48, "the restocker refilled the shelf from the rack")
		expect.equal(plan.units, 58)
		expect.equal(plan.cash, 174)
		local slow = OfflineRules.planRacks(stock, 10, 30, Offline)
		expect.equal(slow.fromShelves[1], 10, "the shelf first")
		expect.equal(slow.fromRacks[1], 48, "10 refilled in the first 10 minutes, 38 in the rack's extra time")
		local short = OfflineRules.planRacks({ { productId = "DeckBox", shelf = 0, rack = 10, price = 9, chance = 1 } }, 0, 30, Offline)
		expect.equal(short.fromRacks[1], 10, "the extra time sells what's in the racks, never more")
		local none = OfflineRules.planRacks({ { productId = "DeckBox", shelf = 5, rack = 0, price = 9, chance = 1 } }, 0, 120, Offline)
		expect.equal(none.units, 0, "extra time with nothing in the racks sells nothing")
		local picky = OfflineRules.planRacks({ { productId = "CardSleeves", shelf = 20, rack = 20, price = 9, chance = 0 } }, 120, 120, Offline)
		expect.equal(picky.units, 0, "a price nobody pays sells nothing")
	end,

	["boxTakes: half-used box first, boxes touched"] = function()
		local takes, touched = OfflineRules.boxTakes({ 24, 10, 24 }, 30)
		expect.equal(takes[1], 20)
		expect.equal(takes[2], 10, "the half-used box first")
		expect.equal(takes[3], 0)
		expect.equal(touched, 2)
		local all, count = OfflineRules.boxTakes({ 5, 5 }, 99)
		expect.equal(all[1] + all[2], 10, "never more than the boxes hold")
		expect.equal(count, 2)
		local _, zero = OfflineRules.boxTakes({ 24 }, 0)
		expect.equal(zero, 0)
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

	-- Seen 2026-11-27 checking the overlap bug: the card said "1 packs"
	["the welcome-back card's chips: one is singular, more plural"] = function()
		expect.equal(OfflineRules.soldWords(1, "FirstSparkPack", Offline), "1 pack")
		expect.equal(OfflineRules.soldWords(18, "FirstSparkPack", Offline), "18 packs")
		expect.equal(OfflineRules.soldWords(1, "DeckBox", Offline), "1 deck box")
		expect.equal(OfflineRules.soldWords(1, "BulkCards", Offline), "1 bulk handful")
		expect.equal(OfflineRules.soldWords(1, "Mystery", Offline), "1 item", "a product without words")
		expect.equal(OfflineRules.soldWords(3, "Mystery", Offline), "3 items")
		local Products = require("../src/shared/Config/Products")
		for _, product in Products.List do
			local word = Offline.SINGULARS[product.id]
			assert(typeof(word) == "string" and #word > 0 and #word <= 16, `{product.id} has a short singular`)
		end
	end,

	["the pace is slow next to a busy shop's: about a fifth"] = function()
		assert(Offline.UNITS_PER_MINUTE > 0 and Offline.UNITS_PER_MINUTE <= 3, "a slow pace")
		assert(Offline.MAX_MINUTES <= 180, "a few hours at most")
	end,

	-- Bug (owner 2026-11-27: "add the overlap bug to the list"): on joining, a mutation choice left waiting and the Welcome
	-- back card opened on top of each other. The card waits for the stage (a reveal, a pack opening) like for a window
	["the Welcome back card waits for the screen: loading, the prologue, a window, a dialog, a reveal on the stage"] = function()
		local clear = { ready = true, panelOpen = false, screenClear = true, stageShown = false, revealing = false }
		local function with(changes: { [string]: any }): any
			local facts = table.clone(clear) :: any
			for key, value in changes do
				facts[key] = value
			end
			return facts
		end
		expect.equal(OfflineRules.cardFree(clear), true, "nothing on screen")
		expect.equal(OfflineRules.cardFree(with({ ready = false })), false, "still loading or in the prologue")
		expect.equal(OfflineRules.cardFree(with({ panelOpen = true })), false, "a window is up")
		expect.equal(OfflineRules.cardFree(with({ screenClear = false })), false, "a purchase dialog or Roblox's menu")
		expect.equal(OfflineRules.cardFree(with({ stageShown = true })), false, "a weapon reveal or a pack opening on the stage")
		expect.equal(OfflineRules.cardFree(with({ revealing = true })), false, "a reveal waiting its turn")
	end,

	-- Night Shift (the game pass; Robux round, spec 2026-11-28-robux-round-design): the welcome-back limits doubled, and
	-- the Welcome back card's words when you were away past the normal limit
	["Night Shift doubles both limits"] = function()
		local cfg = OfflineRules.caps(Offline, true, Offline.NIGHT_SHIFT.factor)
		expect.equal(cfg.MAX_MINUTES, 240)
		expect.equal(cfg.MAX_EXTRA_MINUTES, 240)
		expect.equal(cfg.RACK_MINUTES, Offline.RACK_MINUTES, "a rack still adds its half hour")
		expect.equal(OfflineRules.caps(Offline, false, 2).MAX_MINUTES, 120)
		expect.equal(Offline.MAX_MINUTES, 120, "the config itself untouched")
	end,

	["the selling limit"] = function()
		expect.equal(OfflineRules.limit(Offline, 0, true), 120)
		expect.equal(OfflineRules.limit(Offline, 3, false), 120, "no Restocker: racks don't sell")
		expect.equal(OfflineRules.limit(Offline, 3, true), 210)
		expect.equal(OfflineRules.limit(Offline, 9, true), 240)
		expect.equal(OfflineRules.limit(OfflineRules.caps(Offline, true, 2), 9, true), 480, "8 h with Night Shift")
	end,

	["the note shows only when away past the normal limit"] = function()
		expect.isNil(OfflineRules.nightShiftNote(100, 120, 240, true))
		expect.isNil(OfflineRules.nightShiftNote(120, 120, 240, false))
		local owned = OfflineRules.nightShiftNote(380, 120, 240, true) :: any
		expect.equal(owned.owned, true)
		expect.equal(owned.sold, 240)
		expect.equal(owned.other, 120)
		local offer = OfflineRules.nightShiftNote(380, 120, 240, false) :: any
		expect.equal(offer.owned, false)
		expect.equal(offer.sold, 120)
		expect.equal(offer.other, 240)
		expect.equal((OfflineRules.nightShiftNote(180, 120, 240, true) :: any).sold, 180, "away 3 h: all 3 sold")
	end,

	["hours in plain words"] = function()
		expect.equal(OfflineRules.hoursText(120), "2")
		expect.equal(OfflineRules.hoursText(150), "2.5")
		expect.equal(OfflineRules.hoursText(480), "8")
		expect.equal(OfflineRules.hoursText(200), "3.3")
	end,

	["the Night Shift words"] = function()
		expect.equal(string.format(Offline.NIGHT_SHIFT.owned, "4", "2"), "Night Shift sold for 4 h (2 h without it)")
		expect.equal(string.format(Offline.NIGHT_SHIFT.offer, "2", "4"), "Your shop sold for 2 h. Night Shift keeps it selling for 4 h.")
	end,
}
