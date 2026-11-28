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

	-- Robux round (spec 2026-11-28-robux-round-design): the Starter Pack is a one-time unlock holding 2x Luck, so it's
	-- chance-based and not sold where paid random items are restricted
	["the Starter Pack is a one-time unlock, a pass key and chance-based"] = function()
		assert(table.find(Monetization.UNLOCKS, "StarterPack"), "listed as a one-time unlock")
		expect.equal(Monetization.PASSES.StarterPack, 0)
		expect.equal(Monetization.PRODUCTS.StarterPack ~= nil, true)
		expect.equal(UnlockRules.chanceBased("StarterPack", Monetization), true)
		expect.equal(UnlockRules.chanceBased("ExtraJobSlot", Monetization), false)
	end,

	["the new passes are pass keys"] = function()
		for _, key in { "VIP", "QuickOpen", "NightShift" } do
			expect.equal(typeof(Monetization.PASSES[key]), "number", key)
		end
	end,

	["a grant that fails leaves it unbought"] = function()
		local bought = {}
		expect.equal(UnlockRules.apply(bought, "StarterPack", function()
			return false
		end), false)
		expect.isNil(bought.StarterPack, "Roblox asks again")
		expect.equal(UnlockRules.apply(bought, "StarterPack", function()
			return true
		end), true)
		expect.equal(bought.StarterPack, true)
		expect.equal(UnlockRules.apply({}, "ExtraJobSlot", nil), true, "no grant: just owned")
	end,

	["every pass and unlock has a win card"] = function()
		local Luck = require("../src/shared/Config/Luck")
		for key in Monetization.PASSES do
			local kind = Monetization.WIN_KINDS[key]
			assert(kind, `{key} has a win kind`)
			local win = Luck.WIN[kind]
			assert(win and win.title and win.text and win.glyph, `{kind} has a title, text and glyph`)
		end
	end,
}
