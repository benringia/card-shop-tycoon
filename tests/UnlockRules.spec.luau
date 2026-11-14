--!strict
-- One-time unlocks sold as developer products and saved (owner 2026-11-14 gave the Extra Job Slot as developer product
-- 3731134573, not a game pass): owned forever once bought, never sold twice (MonetizationService counts a saved unlock
-- as owning the pass; the Store and the Jobs panel show "Owned")
local UnlockRules = require("../src/shared/Util/UnlockRules")
local Monetization = require("../src/shared/Config/Monetization")
local expect = require("./lib/expect")

return {
	["the Extra Job Slot is a one-time developer product"] = function()
		expect.equal(Monetization.PRODUCTS.ExtraJobSlot, 3731134573)
		assert(table.find(Monetization.UNLOCKS, "ExtraJobSlot"), "listed as a one-time unlock")
		for _, key in Monetization.UNLOCKS do
			assert(Monetization.PASSES[key] ~= nil, `{key} is also a pass key, so every pass check counts it`)
		end
	end,

	["a saved list keeps only known unlocks that are owned"] = function()
		local clean = UnlockRules.clean({ ExtraJobSlot = true, Nope = true, Other = "x" }, Monetization.UNLOCKS)
		expect.equal(clean.ExtraJobSlot, true)
		expect.isNil(clean.Nope, "unknown keys dropped")
		expect.isNil(UnlockRules.clean({ ExtraJobSlot = false }, Monetization.UNLOCKS).ExtraJobSlot, "only true counts")
		expect.isNil(UnlockRules.clean("junk", Monetization.UNLOCKS).ExtraJobSlot)
	end,

	["an unlock is for sale only when it's made and not owned yet"] = function()
		expect.equal(UnlockRules.canBuy({}, "ExtraJobSlot", 3731134573, Monetization.UNLOCKS), true)
		expect.equal(UnlockRules.canBuy({ ExtraJobSlot = true }, "ExtraJobSlot", 3731134573, Monetization.UNLOCKS), false, "owned: never twice")
		expect.equal(UnlockRules.canBuy({}, "ExtraJobSlot", 0, Monetization.UNLOCKS), false, "not made yet")
		expect.equal(UnlockRules.canBuy({}, "Luck15", 3731134842, Monetization.UNLOCKS), false, "not an unlock")
	end,
}
