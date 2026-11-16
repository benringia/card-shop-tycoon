--!strict
-- Tips shown the first few times (owner 2026-11-17: "make sure players know you can put packs in the bag"): the To Bag
-- bubble shows the first 3 times you pick up a box of packs, and never again once you've used To Bag.
local TipRules = require("../src/server/Util/TipRules")
local Tips = require("../src/shared/Config/Tips")
local expect = require("./lib/expect")

local function showsOf(tips: TipRules.Tips, id: string, shows: number, times: number): (TipRules.Tips, string)
	local seen = {}
	for _ = 1, times do
		local show
		tips, show = TipRules.next(tips, id, shows)
		table.insert(seen, if show then "yes" else "no")
	end
	return tips, table.concat(seen, ",")
end

return {
	["a tip shows its first few times, then never"] = function()
		local tips, seen = showsOf(TipRules.clean(nil), "toBag", 3, 5)
		expect.equal(seen, "yes,yes,yes,no,no")
		expect.equal(tips.toBag, 3, "counted up to its shows, no further")
		local _, other = showsOf(tips, "another", 1, 2)
		expect.equal(other, "yes,no", "each tip counts on its own")
	end,

	["once you've done what it teaches, it never shows again"] = function()
		local tips = TipRules.done(TipRules.clean(nil), "toBag", 3)
		local _, seen = showsOf(tips, "toBag", 3, 2)
		expect.equal(seen, "no,no")
		local again = TipRules.done({ toBag = 1 }, "toBag", 3)
		expect.equal(again.toBag, 3, "done part way")
	end,

	["a saved tips map is cleaned"] = function()
		local clean = TipRules.clean({ toBag = 2.7, bad = -4, words = "x", [5] = 1, huge = 1e9 })
		expect.equal(clean.toBag, 2, "whole numbers")
		expect.isNil(clean.bad, "below zero: dropped")
		expect.isNil(clean.words, "not a number: dropped")
		expect.isNil((clean :: any)[5], "not a name: dropped")
		expect.equal(clean.huge, TipRules.MAX_COUNT, "capped")
		expect.equal(next(TipRules.clean("junk")), nil, "junk: none seen")
	end,

	-- Its words go in a bubble drawn with our fonts: plain ASCII plus the middle dot, short (like Pish's lines)
	["the tips' words are short and drawable"] = function()
		for key, tip in Tips do
			if typeof(tip) == "table" and key ~= "BUBBLE" then
				assert(typeof(tip.id) == "string" and tip.id ~= "", `{key} has an id`)
				assert(typeof(tip.shows) == "number" and tip.shows >= 1, `{key} shows at least once`)
				local plain = string.gsub(tip.text, "·", "")
				assert(not string.find(plain, "[^\32-\126]"), `{key}'s words are plain text: {tip.text}`)
				assert(#tip.text <= 60, `{key}'s words are short ({#tip.text} letters)`)
			end
		end
		expect.equal(Tips.TO_BAG.shows, 3, "the To Bag bubble: the first 3 boxes of packs")
	end,
}
