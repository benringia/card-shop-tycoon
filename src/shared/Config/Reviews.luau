--!strict
-- The phone's Reviews app (owner 2026-11-13: "yes ratings app show customer feedbacks", the small version for the
-- testers; Util/ReviewRules, Server/Services/ReviewService, client ReviewsController): customers post about their visit
-- (CustomerService's outcomes), the newest MAX this session, not saved. Each outcome posts at its `chance` (most sales
-- don't, or the feed would be only sales) with stars in `stars` and one of its `lines`. Plain data.
return {
	-- The Reviews app's red count of unread posts: off (owner 2026-11-21: "remove notifications for reviews on the
	-- phone"); it also kept the Phone tile's count up. ReviewRules.badge
	BADGE = false,
	MAX = 20,
	NAMES = {
		"Maya", "Theo", "Lena", "Omar", "Zoe", "Kai", "Ivy", "Leo", "Nora", "Finn",
		"Aria", "Max", "Ruby", "Sam", "Luna", "Eli", "Mia", "Jay", "Ava", "Noah",
	},
	COLORS = { { 255, 184, 110 }, { 110, 195, 255 }, { 127, 224, 176 }, { 183, 155, 255 }, { 255, 143, 184 }, { 255, 214, 110 } },
	OUTCOMES = {
		paid = {
			chance = 0.35,
			stars = { 4, 5 },
			lines = { "Fair prices, got my packs!", "Nice shop, will come back!", "Found what I wanted!", "Friendly shop, quick checkout!" },
		},
		happyMoment = {
			chance = 0.6,
			stars = { 5, 5 },
			lines = { "Whoa, that card on display! 😍", "Such a cute creature here! 🐾", "Best display in town! ✨" },
		},
		annoyed = {
			chance = 1,
			stars = { 2, 2 },
			lines = { "They wouldn't take my offer...", "Haggled and got nothing 😤" },
		},
		gaveUp = {
			chance = 1,
			stars = { 1, 2 },
			lines = { "Waited ages at the register...", "Nobody at the counter 😴" },
		},
		-- Found nothing they wanted. `named`: when the customer knows what they missed (spec
		-- 2026-11-24-shop-variety-design), `%s` its plural (Config/Offline PLURALS); `lines` when not (a collector, an
		-- empty shop)
		noStock = {
			chance = 1,
			stars = { 1, 1 },
			lines = { "Shelves were empty 😢", "Nothing left to buy..." },
			named = { "No %s at all 😢", "Couldn't find any %s 😢" },
		},
		-- Bought something but missed a product on their list
		partial = {
			chance = 1,
			stars = { 3, 3 },
			lines = { "Couldn't find everything 😕", "Almost had it all 😕" },
			named = { "No %s here 😕", "Wanted %s too 😕" },
		},
		-- Found everything on their list ("Found it all!", Config/Customers FOUND_ALL)
		foundAll = {
			chance = 0.5,
			stars = { 5, 5 },
			lines = { "Found everything! 🛍️", "Had all I wanted! ✨" },
		},
	},
	TITLE = "Reviews",
	EMPTY = "No reviews yet. Open your shop and serve some customers!",
	TIPS_TITLE = "What would help",
	SECONDS = { minute = "%dm", hour = "%dh", now = "now" },
}
