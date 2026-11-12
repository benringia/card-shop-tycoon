--!strict
-- The phone's Reviews app (owner 2026-11-13: "yes ratings app show customer feedbacks", the small version for the
-- testers): customers post about their visit (Util/ReviewRules, Config/Reviews)
local ReviewRules = require("../src/shared/Util/ReviewRules")
local Reviews = require("../src/shared/Config/Reviews")
local expect = require("./lib/expect")

local function rolls(over: any): any
	local base = { chance = 0, name = 0, line = 0, stars = 0, color = 0 }
	for key, value in over do
		base[key] = value
	end
	return base
end

return {
	["every visit outcome has short posts, a star range and a chance"] = function()
		for _, outcome in { "paid", "happyMoment", "annoyed", "gaveUp", "noStock" } do
			local look = Reviews.OUTCOMES[outcome]
			assert(look, `{outcome} posts`)
			expect.equal(#look.lines >= 2 and look.chance > 0 and look.chance <= 1, true, outcome)
			expect.equal(look.stars[1] >= 1 and look.stars[2] <= 5 and look.stars[1] <= look.stars[2], true, `{outcome} stars`)
			for _, line in look.lines do
				expect.equal(#line <= 44, true, `{line}: short`)
			end
		end
		expect.equal(#Reviews.NAMES >= 10 and #Reviews.COLORS >= 3, true)
	end,

	["a visit becomes a post: a name, stars in its range and a line; unknown or unlucky visits post nothing"] = function()
		local post = ReviewRules.make(Reviews, "noStock", rolls({}), 100) :: any
		expect.equal(post.stars, 1, "empty shelves: one star")
		expect.equal(post.at, 100)
		expect.equal(table.find(Reviews.NAMES, post.name) ~= nil and table.find(Reviews.OUTCOMES.noStock.lines, post.line) ~= nil, true)
		local happy = ReviewRules.make(Reviews, "happyMoment", rolls({ stars = 0.99 }), 5) :: any
		expect.equal(happy.stars, Reviews.OUTCOMES.happyMoment.stars[2])
		expect.equal(ReviewRules.make(Reviews, "madeUp", rolls({}), 0), nil, "unknown outcome")
		expect.equal(ReviewRules.make(Reviews, "paid", rolls({ chance = 0.999 }), 0), nil, "most sales don't post")
	end,

	["the feed keeps the newest first, at most MAX; unseen counts posts after the last look"] = function()
		local list = {}
		for index = 1, Reviews.MAX + 3 do
			list = ReviewRules.push(list, { name = "A", stars = 3, line = "x", at = index, color = 1 }, Reviews.MAX)
		end
		expect.equal(#list, Reviews.MAX)
		expect.equal(list[1].at, Reviews.MAX + 3, "newest first")
		expect.equal(ReviewRules.unseen(list, Reviews.MAX + 1), 2)
		expect.equal(ReviewRules.unseen(list, 0), Reviews.MAX)
		expect.equal(ReviewRules.unseen({}, 0), 0)
	end,
}
