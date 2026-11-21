--!strict
-- Codes (owner 2026-11-19: "should we add JOIN our DISCORD or something now that we have discord server? reward?",
-- then "yes do code box"): a box in the Store where a player types a code we posted (the game page, our Discord) for
-- a small gift. Everyone can redeem one, each code once a player; no reward is tied to leaving Roblox. Config/Codes,
-- Util/CodeRules.
local Codes = require("../src/shared/Config/Codes")
local CodeRules = require("../src/shared/Util/CodeRules")
local Items = require("../src/shared/Config/Items")
local Luck = require("../src/shared/Config/Luck")
local Gifts = require("../src/shared/Config/Gifts")
local GiftRules = require("../src/shared/Util/GiftRules")
local expect = require("./lib/expect")

local CFG: any = {
	MAX_LENGTH = 20,
	CODES = {
		HELLO = { reward = { cash = 100 } },
		OLD = { reward = { cash = 5 }, ends = 1000 },
	},
}

return {
	-- Owner 2026-11-21: "add a noticeable notification if CODES get redeemed": a redeemed code plays the gifts' win
	-- moment (Util/GiftWin: the screen dims, the present drops in, rattles and bursts, its gifts flip in as cards, a
	-- pack can be opened right there), its own title and colours
	["a redeemed code plays the gifts' win moment: its look, and every code's gifts as cards"] = function()
		local look = (Gifts.WIN :: any).code
		assert(look, "a look for codes")
		expect.equal(look.title, "CODE REDEEMED!")
		assert(typeof(look.picture) == "string" and look.chest == nil, "a picture, not a chest")
		expect.equal(#look.colors, 2)
		for code, entry in Codes.CODES do
			local lines = GiftRules.lines(entry.reward, Items, Luck)
			assert(#lines >= 1 and #lines <= 4, `{code}: {#lines} cards`)
		end
	end,

	["what a player types becomes a code: capitals, no spaces or symbols"] = function()
		expect.equal(CodeRules.normalize(" hello ", 20), "HELLO")
		expect.equal(CodeRules.normalize("one-more pack!", 20), "ONEMOREPACK")
		expect.equal(CodeRules.normalize("Pish2026", 20), "PISH2026")
		expect.isNil(CodeRules.normalize("", 20), "nothing typed")
		expect.isNil(CodeRules.normalize("   !!! ", 20), "nothing left")
		expect.isNil(CodeRules.normalize(string.rep("A", 21), 20), "too long")
		expect.isNil(CodeRules.normalize(42, 20), "not text")
		expect.isNil(CodeRules.normalize(nil, 20))
	end,

	["a code works once a player; unknown, used and ended ones say why"] = function()
		local result, entry = CodeRules.check(CFG, {}, "HELLO", 500)
		expect.equal(result, "ok")
		assert(entry and entry.reward.cash == 100, "its reward")
		expect.equal((CodeRules.check(CFG, { "HELLO" }, "HELLO", 500)), "used")
		expect.equal((CodeRules.check(CFG, {}, "NOPE", 500)), "unknown")
		expect.equal((CodeRules.check(CFG, {}, nil, 500)), "empty")
		expect.equal((CodeRules.check(CFG, {}, "OLD", 999)), "ok", "before it ends")
		expect.equal((CodeRules.check(CFG, {}, "OLD", 1000)), "expired")
		expect.equal((CodeRules.check(CFG, { "OLD" }, "OLD", 2000)), "used", "used wins over ended")
	end,

	["a saved list is made safe: codes only, each once, junk gone"] = function()
		local clean = CodeRules.clean({ "HELLO", "HELLO", 5, "bad code", "OLD", string.rep("B", 30) }, 20)
		expect.equal(#clean, 2)
		expect.equal(clean[1], "HELLO")
		expect.equal(clean[2], "OLD")
		expect.equal(#CodeRules.clean(nil, 20), 0)
		expect.equal(#CodeRules.clean("x", 20), 0)
		-- a code we no longer list stays used: adding it back can't pay twice
		expect.equal(CodeRules.clean({ "GONE" }, 20)[1], "GONE")
	end,

	["every code we ship is typeable, pays something real and says what you got"] = function()
		local count = 0
		for code, entry in Codes.CODES do
			count += 1
			expect.equal(CodeRules.normalize(code, Codes.MAX_LENGTH), code, `{code} as typed`)
			local reward = entry.reward
			local pays = (reward.cash or 0) > 0 or (reward.items ~= nil and #reward.items > 0) or reward.luck ~= nil
			assert(pays, `{code} pays something`)
			assert((reward.cash or 0) <= 1000, `{code}: a small gift, not an economy skip`)
			for _, grant in reward.items or {} do
				assert(Items.ITEMS[grant.item], `{code}: {grant.item} is a real item`)
				assert(grant.count >= 1 and grant.count <= 5, `{code}: a few of {grant.item}`)
			end
			if reward.luck then
				assert(Luck.STRENGTHS[reward.luck.strength], `{code}: a real luck strength`)
			end
			local words = CodeRules.gotLine(reward, Items, Luck)
			assert(string.sub(words, 1, 9) == "You got: " and #words > 12, `{code}: its words ({words})`)
		end
		assert(count >= 1, "at least the launch code")
		for _, key in { "ok", "unknown", "used", "expired", "empty", "busy" } do
			assert(typeof(Codes.TEXT[key]) == "string" and Codes.TEXT[key] ~= "", `TEXT.{key}`)
		end
	end,

	["what you got, in words"] = function()
		local words = CodeRules.gotLine({ cash = 250, items = { { item = "sparkPack", count = 2 } }, luck = { strength = "x2", seconds = 900 } }, Items, Luck)
		assert(string.find(words, "$250", 1, true), words)
		assert(string.find(words, "x2", 1, true), words)
		assert(string.find(words, "15 min", 1, true), words)
	end,
}
