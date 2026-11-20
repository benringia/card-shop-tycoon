--!strict
-- Daily, weekly and monthly gifts (spec 2026-11-15-daily-gifts-design; owner: "go, can we also have weekly and
-- monthly. design must feel like a WIN. yes 10 min timer should start when they actually start playing")
local GiftRules = require("../src/shared/Util/GiftRules")
local Gifts = require("../src/shared/Config/Gifts")
local Items = require("../src/shared/Config/Items")
local Luck = require("../src/shared/Config/Luck")
local expect = require("./lib/expect")

local DAY = 86400
-- 2026-11-16 is a Monday (UTC)
local MONDAY = GiftRules.dayOf(os.time({ year = 2026, month = 11, day = 16, hour = 12 }))

-- A state whose daily gift is ready on `day`
local function readyOn(state: GiftRules.State, day: number): GiftRules.State
	return GiftRules.addPlay(state, day, Gifts.PLAY_SECONDS)
end

local function claimDaily(state: GiftRules.State, day: number): (GiftRules.State, GiftRules.Reward, GiftRules.Earned)
	return GiftRules.claim(readyOn(state, day), "daily", day, Gifts)
end

return {
	["days, Monday weeks and months from the day number"] = function()
		expect.equal(GiftRules.dayOf(0), 0)
		expect.equal(GiftRules.dayOf(DAY - 1), 0)
		expect.equal(GiftRules.dayOf(DAY), 1)
		-- 1970-01-01 was a Thursday: Monday the 5th starts week 1, Sunday the 4th is still week 0
		expect.equal(GiftRules.weekOf(3), 0)
		expect.equal(GiftRules.weekOf(4), 1)
		expect.equal(GiftRules.weekOf(MONDAY), GiftRules.weekOf(MONDAY + 6), "Monday to Sunday")
		expect.equal(GiftRules.weekOf(MONDAY + 7), GiftRules.weekOf(MONDAY) + 1, "the next Monday")
		expect.equal(GiftRules.monthOf(0), 197001)
		expect.equal(GiftRules.monthOf(MONDAY), 202611)
		expect.equal(GiftRules.monthOf(MONDAY + 14), 202611, "Nov 30")
		expect.equal(GiftRules.monthOf(MONDAY + 15), 202612, "Dec 1")
		expect.equal(GiftRules.monthOf(GiftRules.dayOf(os.time({ year = 2028, month = 2, day = 29, hour = 12 }))), 202802, "leap day")
		expect.equal(GiftRules.monthOf(GiftRules.dayOf(os.time({ year = 2028, month = 3, day = 1, hour = 12 }))), 202803)
	end,

	["the gifts are the agreed ones, every item real"] = function()
		expect.equal(#Gifts.DAILY, 7)
		expect.equal(Gifts.PLAY_SECONDS, 600, "10 minutes of play")
		expect.equal(Gifts.DAILY[1].cash, 300)
		expect.equal(Gifts.DAILY[3].items[1].item, "vrPack")
		expect.equal(Gifts.DAILY[7].items[1].item, "epicPack")
		expect.equal(Gifts.DAILY[7].luck.strength, "x2")
		expect.equal(Gifts.DAILY[7].luck.seconds, 900)
		expect.equal(Gifts.WEEKLY.days, 5)
		expect.equal(Gifts.WEEKLY.reward.cash, 1000)
		expect.equal(Gifts.MONTHLY.days, 20)
		expect.equal(Gifts.MONTHLY.reward.items[1].item, "legendaryPack")
		expect.equal(Gifts.MONTHLY.reward.luck.strength, "x3")
		local rewards = table.clone(Gifts.DAILY)
		table.insert(rewards, Gifts.WEEKLY.reward)
		table.insert(rewards, Gifts.MONTHLY.reward)
		for _, reward in rewards do
			for _, grant in reward.items or {} do
				expect.equal(Items.ITEMS[grant.item] ~= nil, true, grant.item)
				expect.equal(grant.count >= 1, true)
			end
			if reward.luck then
				expect.equal(Luck.STRENGTHS[reward.luck.strength] ~= nil, true, reward.luck.strength)
			end
		end
	end,

	["the monthly chest needs 8 days in the launch month, 20 after"] = function()
		expect.equal(GiftRules.monthTarget(Gifts, 202611), 8)
		expect.equal(GiftRules.monthTarget(Gifts, 202612), 20)
	end,

	["a bad save comes back clean"] = function()
		local state = GiftRules.clean({ streak = 99, lastDay = "x", played = -5, weekDays = 2.5, monthEarned = "yes" })
		expect.equal(state.streak, 0)
		expect.equal(state.lastDay, -1)
		expect.equal(state.played, 0)
		expect.equal(state.weekDays, 2)
		expect.equal(state.monthEarned, false)
		local none = GiftRules.clean(nil)
		expect.equal(none.claims, 0)
		expect.equal(GiftRules.clean({ streak = 6 }).streak, 6)
	end,

	["today's gift waits for 10 minutes of play that day"] = function()
		local state = GiftRules.addPlay(GiftRules.fresh(), MONDAY, 590)
		local view = GiftRules.view(state, MONDAY, Gifts)
		expect.equal(view.day, 1)
		expect.equal(view.ready, false)
		expect.equal(view.secondsLeft, 10)
		local ok, why = GiftRules.canClaim(state, "daily", MONDAY, Gifts)
		expect.equal(ok, false)
		expect.equal(why, "wait")
		state = GiftRules.addPlay(state, MONDAY, 10)
		expect.equal(GiftRules.view(state, MONDAY, Gifts).ready, true)
		expect.equal(GiftRules.view(state, MONDAY, Gifts).secondsLeft, 0)
		-- a new day starts the 10 minutes over
		local tomorrow = GiftRules.view(state, MONDAY + 1, Gifts)
		expect.equal(tomorrow.ready, false)
		expect.equal(tomorrow.secondsLeft, Gifts.PLAY_SECONDS)
	end,

	["one daily gift a day, the round going 1 to 7 and over"] = function()
		local state = GiftRules.fresh()
		local reward
		state, reward = claimDaily(state, MONDAY)
		expect.equal(reward, Gifts.DAILY[1])
		expect.equal(state.claims, 1)
		local again, why = GiftRules.canClaim(readyOn(state, MONDAY), "daily", MONDAY, Gifts)
		expect.equal(again, false)
		expect.equal(why, "claimed")
		local view = GiftRules.view(state, MONDAY, Gifts)
		expect.equal(view.claimedToday, true)
		expect.equal(view.day, 1, "today's tile stays the one claimed")
		expect.equal(GiftRules.view(state, MONDAY + 1, Gifts).day, 2, "tomorrow: day 2")
		for offset = 1, 6 do
			state, reward = claimDaily(state, MONDAY + offset)
			expect.equal(reward, Gifts.DAILY[offset + 1])
		end
		expect.equal(GiftRules.view(state, MONDAY + 7, Gifts).day, 1, "after the big gift, day 1 again")
		state, reward = claimDaily(state, MONDAY + 7)
		expect.equal(reward, Gifts.DAILY[1])
	end,

	["a missed day never resets the round"] = function()
		local state = GiftRules.fresh()
		state = claimDaily(state, MONDAY)
		state = claimDaily(state, MONDAY + 1)
		local view = GiftRules.view(state, MONDAY + 5, Gifts)
		expect.equal(view.day, 3, "away three days: still day 3")
	end,

	["the 5th day claimed in a week earns the weekly chest, kept past the week"] = function()
		local state = GiftRules.fresh()
		local earned
		for offset = 0, 3 do
			state, _, earned = claimDaily(state, MONDAY + offset)
			expect.equal(earned.week, false)
		end
		expect.equal(GiftRules.view(state, MONDAY + 3, Gifts).weekDays, 4)
		local early, why = GiftRules.canClaim(state, "weekly", MONDAY + 3, Gifts)
		expect.equal(early, false)
		expect.equal(why, "notEarned")
		state, _, earned = claimDaily(state, MONDAY + 4)
		expect.equal(earned.week, true)
		state, _, earned = claimDaily(state, MONDAY + 5)
		expect.equal(earned.week, false, "the 6th day earns nothing more")
		-- next Monday: the bar starts over, the chest still waits
		local view = GiftRules.view(state, MONDAY + 7, Gifts)
		expect.equal(view.weekDays, 0)
		expect.equal(view.weekEarned, true)
		local reward
		state, reward = GiftRules.claim(state, "weekly", MONDAY + 7, Gifts)
		expect.equal(reward, Gifts.WEEKLY.reward)
		expect.equal(GiftRules.view(state, MONDAY + 7, Gifts).weekEarned, false)
		local twice = GiftRules.canClaim(state, "weekly", MONDAY + 7, Gifts)
		expect.equal(twice, false)
	end,

	["days from last week don't count toward this week"] = function()
		local state = GiftRules.fresh()
		for offset = 3, 6 do -- Thursday to Sunday
			state = claimDaily(state, MONDAY + offset)
		end
		local earned
		state, _, earned = claimDaily(state, MONDAY + 7)
		expect.equal(earned.week, false)
		expect.equal(GiftRules.view(state, MONDAY + 7, Gifts).weekDays, 1)
	end,

	["the launch month's 8th day earns the monthly chest"] = function()
		local state = GiftRules.fresh()
		local earned
		local first = MONDAY - 6 -- Tuesday Nov 10
		for offset = 0, 7 do
			state, _, earned = claimDaily(state, first + offset)
		end
		expect.equal(earned.month, true)
		local view = GiftRules.view(state, first + 7, Gifts)
		expect.equal(view.monthDays, 8)
		expect.equal(view.monthTarget, 8)
		local reward
		state, reward = GiftRules.claim(state, "monthly", first + 7, Gifts)
		expect.equal(reward, Gifts.MONTHLY.reward)
		-- December: 20 days needed, the bar from 0
		local december = GiftRules.view(state, MONDAY + 15, Gifts)
		expect.equal(december.monthDays, 0)
		expect.equal(december.monthTarget, 20)
	end,

	["the gifts in words a child understands"] = function()
		local lines = GiftRules.lines(Gifts.DAILY[1], Items, Luck)
		expect.equal(#lines, 2)
		expect.equal(lines[1].text, "$300")
		expect.equal(lines[1].icon, "Cash")
		expect.equal(lines[2].text, "First Spark Pack")
		expect.equal(lines[2].icon, Items.ITEMS.sparkPack.icon)
		expect.equal(lines[2].item, "sparkPack")
		expect.equal(lines[2].pack, true, "a pack: OPEN IT NOW!")
		local ore = GiftRules.lines(Gifts.DAILY[4], Items, Luck)
		expect.equal(ore[1].text, "Wild Ore x10")
		expect.equal(ore[1].pack, false)
		local big = GiftRules.lines(Gifts.DAILY[7], Items, Luck)
		expect.equal(big[2].text, "15 min 2x Luck")
		local month = GiftRules.lines(Gifts.MONTHLY.reward, Items, Luck)
		expect.equal(month[1].text, "$5,000")
	end,
	-- Owner 2026-11-21: "switch phone and daily reward position. phone at the bottom of daily reward": in a computer's
	-- side column the gift's tile comes first, the Phone (order 0, Util/Hud's Manage tile) under it
	["the gift's tile sits over the Phone in the side column"] = function()
		assert(Gifts.TILE.order < 0, "before the Phone's tile (order 0)")
		expect.equal(Gifts.TILE.phoneBottom, true, "a phone still keeps it in the bottom row")
	end,
}
