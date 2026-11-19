--!strict
-- Weekly events (owner 2026-11-19: "suggest a recurring scheduled events", then "build the weekend events"): the same
-- every week on UTC days, nobody runs them. Saturday is Boss Rush (boss loot twice as fast, one more material in every
-- chest), Sunday is Lucky Sunday (free 2x Luck for your first 30 minutes that day). Config/Events, Util/EventRules.
local Events = require("../src/shared/Config/Events")
local EventRules = require("../src/shared/Util/EventRules")
local Bosses = require("../src/shared/Config/Bosses")
local Luck = require("../src/shared/Config/Luck")
local expect = require("./lib/expect")

local DAY = 86400
-- 2026-11-21 00:00 UTC is a Saturday (launch day): 20,778 days after 1970-01-01, a Thursday
local SATURDAY = 20778 * DAY
local SUNDAY = SATURDAY + DAY
local MONDAY = SATURDAY + 2 * DAY
local FRIDAY = SATURDAY - DAY

return {
	["weekday: Monday is 1, Sunday is 7, by the UTC day"] = function()
		expect.equal(EventRules.weekday(0), 4, "1970-01-01 was a Thursday")
		expect.equal(EventRules.weekday(SATURDAY), 6)
		expect.equal(EventRules.weekday(SATURDAY + DAY - 1), 6, "the day's last second")
		expect.equal(EventRules.weekday(SUNDAY), 7)
		expect.equal(EventRules.weekday(MONDAY), 1)
		expect.equal(EventRules.dayNumber(SATURDAY + 5), 20778)
	end,

	["today: Boss Rush on Saturday, Lucky Sunday on Sunday, nothing on the other days"] = function()
		local saturday = EventRules.today(Events, SATURDAY + 3600)
		assert(saturday, "Saturday's event")
		expect.equal(saturday.id, "bossRush")
		local sunday = EventRules.today(Events, SUNDAY + 3600)
		assert(sunday, "Sunday's event")
		expect.equal(sunday.id, "luckySunday")
		for offset = 2, 6 do
			expect.isNil(EventRules.today(Events, SATURDAY + offset * DAY), `day +{offset}`)
		end
	end,

	["Studio can force an event or switch them off (the /event command)"] = function()
		local forced = EventRules.today(Events, MONDAY, "bossRush")
		assert(forced, "forced")
		expect.equal(forced.id, "bossRush")
		expect.isNil(EventRules.today(Events, SATURDAY, "off"), "off on a Saturday")
		local unknown = EventRules.today(Events, SATURDAY, "nope")
		assert(unknown, "an unknown name: the calendar")
		expect.equal(unknown.id, "bossRush")
	end,

	["Boss Rush: boss loot twice as fast and one more material in every chest"] = function()
		local rush = EventRules.today(Events, SATURDAY)
		expect.equal(EventRules.lootCooldown(rush, Bosses.LOOT_COOLDOWN), 210, "3:30 instead of 7:00")
		expect.equal(EventRules.chestBonus(rush), 1)
		expect.equal(EventRules.lootCooldown(nil, Bosses.LOOT_COOLDOWN), Bosses.LOOT_COOLDOWN, "no event")
		expect.equal(EventRules.chestBonus(nil), 0)
		local sunday = EventRules.today(Events, SUNDAY)
		expect.equal(EventRules.lootCooldown(sunday, Bosses.LOOT_COOLDOWN), Bosses.LOOT_COOLDOWN, "Sunday isn't a rush")
		expect.equal(EventRules.chestBonus(sunday), 0)
	end,

	["Lucky Sunday: free luck once a day, a strength the game has"] = function()
		local sunday = EventRules.today(Events, SUNDAY)
		local today = EventRules.dayNumber(SUNDAY)
		local gift = EventRules.luckGift(sunday, today - 7, today)
		assert(gift, "this Sunday's luck")
		expect.equal(gift.strength, "x2")
		expect.equal(gift.seconds, 30 * 60)
		assert(Luck.STRENGTHS[gift.strength], "a real luck strength")
		expect.isNil(EventRules.luckGift(sunday, today, today), "given already today")
		expect.isNil(EventRules.luckGift(EventRules.today(Events, SATURDAY), today - 1, today - 1), "Boss Rush gives no luck")
		expect.isNil(EventRules.luckGift(nil, 0, today), "no event")
	end,

	-- The toast when you arrive or the day turns: Sunday's says "you got" only when the luck was given just now
	["the toast: what you got, or that today's luck is already yours"] = function()
		local sunday = EventRules.today(Events, SUNDAY)
		assert(sunday, "Sunday's event")
		expect.equal(EventRules.toast(sunday, true), sunday.toast)
		local again = EventRules.toast(sunday, false)
		assert(again ~= sunday.toast and string.find(again, "Lucky Sunday", 1, true), "a rejoin doesn't say you got it again")
		local rush = EventRules.today(Events, SATURDAY)
		assert(rush, "Saturday's event")
		expect.equal(EventRules.toast(rush, false), rush.toast, "nothing is given on Boss Rush: the same words")
	end,

	["time left today, in words a kid reads"] = function()
		expect.equal(EventRules.secondsLeft(SATURDAY), DAY)
		expect.equal(EventRules.secondsLeft(SATURDAY + DAY - 60), 60)
		expect.equal(EventRules.span(5 * 3600 + 120), "5h")
		expect.equal(EventRules.span(26 * 3600), "1d 2h")
		expect.equal(EventRules.span(48 * 3600), "2d")
		expect.equal(EventRules.span(42 * 60 + 5), "42 min")
		expect.equal(EventRules.span(20), "1 min")
	end,

	["the chip: today's event and how long it lasts, or the next one and how long until it"] = function()
		local words, live = EventRules.chip(Events, SATURDAY + 19 * 3600)
		expect.equal(words, "Boss Rush · 5h left")
		expect.equal(live, true)
		words, live = EventRules.chip(Events, FRIDAY + 22 * 3600)
		expect.equal(words, "Next: Boss Rush in 2h")
		expect.equal(live, false)
		words, live = EventRules.chip(Events, MONDAY + 12 * 3600)
		expect.equal(words, "Next: Boss Rush in 4d 12h", "from Monday noon to Saturday")
		words, live = EventRules.chip(Events, MONDAY, "luckySunday")
		expect.equal(live, true, "a forced event shows as on")
		local quiet: any = { DAYS = {} }
		expect.isNil((EventRules.chip(quiet, MONDAY)), "no events at all: no chip")
	end,

	["the next event and when it starts"] = function()
		local event, wait = EventRules.next(Events, SATURDAY + 3600)
		assert(event, "an event")
		expect.equal(event.id, "luckySunday", "from Saturday: Sunday's")
		expect.equal(wait, DAY - 3600)
		event, wait = EventRules.next(Events, SUNDAY + 3600)
		assert(event, "an event")
		expect.equal(event.id, "bossRush", "from Sunday: next Saturday's")
		expect.equal(wait, 6 * DAY - 3600)
	end,

	["every event has its words and an icon; saved state made safe"] = function()
		for weekday, event in Events.DAYS do
			assert(weekday >= 1 and weekday <= 7, "a weekday")
			for _, key in { "id", "name", "icon", "line", "toast" } do
				assert(typeof((event :: any)[key]) == "string" and (event :: any)[key] ~= "", `{event.id}.{key}`)
			end
		end
		expect.equal(EventRules.clean(nil).luckDay, -1)
		expect.equal(EventRules.clean({ luckDay = 20779 }).luckDay, 20779)
		expect.equal(EventRules.clean({ luckDay = "x" }).luckDay, -1, "junk")
		expect.equal(EventRules.clean({ luckDay = 0 / 0 }).luckDay, -1, "NaN")
	end,
}
