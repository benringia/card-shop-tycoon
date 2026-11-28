--!strict
-- The Store page's rows (spec 2026-11-28-robux-round-design, Store A): the Forever list in order with its owned and NEW
-- states, and the Starter Pack banner only while it's for sale to this player
local StoreRules = require("../src/shared/Util/StoreRules")
local Monetization = require("../src/shared/Config/Monetization")
local expect = require("./lib/expect")

return {
	["the Forever rows come in order with their owned state"] = function()
		local rows = StoreRules.forever({ VIP = true }, 0, Monetization)
		expect.equal(#rows, 4)
		expect.equal(rows[1].key, "VIP")
		expect.equal(rows[1].owned, true)
		expect.equal(rows[2].key, "QuickOpen")
		expect.equal(rows[3].key, "NightShift")
		expect.equal(rows[4].key, "ExtraJobSlot")
		expect.equal(rows[4].new, false, "the slot isn't new")
	end,

	["NEW shows on new passes until NEW_UNTIL, never once owned"] = function()
		local before = StoreRules.forever({}, Monetization.NEW_UNTIL - 1, Monetization)
		expect.equal(before[2].new, true)
		expect.equal(StoreRules.forever({}, Monetization.NEW_UNTIL, Monetization)[2].new, false)
		expect.equal(StoreRules.forever({ QuickOpen = true }, 0, Monetization)[2].new, false)
	end,

	["NEW_UNTIL is 2027-01-01 UTC"] = function()
		expect.equal(Monetization.NEW_UNTIL, 1798761600)
	end,

	["the Starter banner shows only unowned and not restricted"] = function()
		expect.equal(StoreRules.showStarter(false, false), true)
		expect.equal(StoreRules.showStarter(true, false), false)
		expect.equal(StoreRules.showStarter(false, true), false)
		expect.equal(StoreRules.showStarter(false, nil), false, "policy still being read")
	end,

	["every Forever row and the Starter Pack have their Store words"] = function()
		for _, key in Monetization.FOREVER do
			local words = Monetization.STORE[key]
			assert(words and words.icon and words.name and words.line and words.win, `{key} has icon, name, line, win`)
		end
		local starter = Monetization.STORE.StarterPack
		assert(starter and starter.name and starter.line and starter.tag and #starter.chips == 3, "the banner's words")
	end,
}
