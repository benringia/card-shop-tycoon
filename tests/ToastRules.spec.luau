--!strict
-- Toasts as Cindercub's speech bubbles stacked over the cash pill (owner's pick A, 2026-11-06)
local ToastRules = require("../src/shared/Util/ToastRules")
local Toasts = require("../src/shared/Config/Toasts")
local expect = require("./lib/expect")

local function entry(id: number, message: string): ToastRules.Entry
	return { id = id, message = message }
end

return {
	-- owner 2026-11-12: "make the bubble come out of him ... like he's saying the notification"; 2026-11-13 pick P1: Pish
	-- peeks over the cash pill on a computer and says the toasts again
	["the toast stack sits so its tail ends just over Pish's head"] = function()
		local head = { x = 900, y = 500 }
		local corner = ToastRules.stackCorner(head, Toasts.TAIL_RIGHT, Toasts.TAIL, 1)
		expect.near(corner.x - Toasts.TAIL_RIGHT, head.x, 1e-9, "the tail over his head")
		expect.equal(corner.y < head.y and corner.y >= head.y - Toasts.TAIL, true, "just above it")
		local scaled = ToastRules.stackCorner(head, Toasts.TAIL_RIGHT, Toasts.TAIL, 0.7)
		expect.near(scaled.x - Toasts.TAIL_RIGHT * 0.7, head.x, 1e-9, "at a smaller HUD scale too")
	end,
	["sales are money, errors are errors, the rest is news"] = function()
		expect.equal(ToastRules.kind(false, true), "money")
		expect.equal(ToastRules.kind(true, false), "error")
		expect.equal(ToastRules.kind(false, false), "news")
		for _, kind in { "money", "error", "news" } do
			assert(Toasts.KINDS[kind] ~= nil, `a look for {kind}`)
		end
	end,

	["they last longer (owner 2026-11-06): 6 s, errors 8, a toast's own time doubled"] = function()
		expect.equal(ToastRules.seconds(Toasts, "news", nil), 6)
		expect.equal(ToastRules.seconds(Toasts, "money", nil), 6)
		expect.equal(ToastRules.seconds(Toasts, "error", nil), 8)
		expect.equal(ToastRules.seconds(Toasts, "news", 5), 10, "the level-up toast")
		expect.equal(ToastRules.seconds(Toasts, "news", 1.5), 3, "a quick loot pickup stays quick")
	end,

	["a new toast joins the stack; past the most, the oldest goes"] = function()
		local bump, drop = ToastRules.place({ entry(1, "a"), entry(2, "b") }, "c", 3)
		expect.isNil(bump)
		expect.equal(#drop, 0)
		local _, full = ToastRules.place({ entry(1, "a"), entry(2, "b"), entry(3, "c") }, "d", 3)
		expect.equal(#full, 1)
		expect.equal(full[1], 1, "the oldest")
		local _, phone = ToastRules.place({ entry(1, "a"), entry(2, "b"), entry(3, "c") }, "d", 2)
		expect.equal(#phone, 2, "a phone keeps 2")
		expect.equal(phone[1], 1)
		expect.equal(phone[2], 2)
	end,

	["the same message twice in a row bumps the bubble already up"] = function()
		local bump, drop = ToastRules.place({ entry(1, "a"), entry(2, "Get closer to the shelf.") }, "Get closer to the shelf.", 3)
		expect.equal(bump, 2)
		expect.equal(#drop, 0)
		local again = ToastRules.place({ entry(1, "Get closer"), entry(2, "b") }, "Get closer", 3)
		expect.isNil(again, "only the newest counts")
	end,

	["Cindercub hops once for a burst of toasts"] = function()
		expect.equal(ToastRules.hopNow(nil, 10, Toasts.HOP_GAP), true)
		expect.equal(ToastRules.hopNow(10, 10.3, Toasts.HOP_GAP), false)
		expect.equal(ToastRules.hopNow(10, 10 + Toasts.HOP_GAP, Toasts.HOP_GAP), true)
	end,

	["a message's own emoji goes in the icon chip"] = function()
		local icon, rest = ToastRules.leadingEmoji("😴 Nightowl is tired: scanning slower for 5 min.")
		expect.equal(icon, "😴")
		expect.equal(rest, "Nightowl is tired: scanning slower for 5 min.")
		local none, same = ToastRules.leadingEmoji("Get closer to the shelf.")
		expect.isNil(none)
		expect.equal(same, "Get closer to the shelf.")
		expect.isNil((ToastRules.leadingEmoji("$5 from a sale")), "plain text first")
	end,

	["at most 3 bubbles, 2 on phones"] = function()
		expect.equal(Toasts.MAX, 3)
		expect.equal(Toasts.MAX_TOUCH, 2)
	end,
	-- Owner 2026-11-21: "move pish icon at the top of quests". On a computer Pish now sits on the quest strip's top
	-- edge at the top right. His bubbles sit in a row in the top bar's strip, the newest right over his head, older
	-- ones to its left: a stack hanging down beside him covered an open window's close button (seen over the Bag)
	["Pish on the quests: his bubbles sit in a row along the top, the newest over his head"] = function()
		expect.equal(ToastRules.mode(false, true), "row", "a computer with Pish on the quests")
		expect.equal(ToastRules.mode(false, false), "up", "Pish over the cash at the bottom: bubbles rise")
		expect.equal(ToastRules.mode(true, false), "down", "a phone: under the column")
		expect.equal(ToastRules.mode(true, true), "down", "a touch screen keeps its own")
		expect.equal(ToastRules.max("row", Toasts), Toasts.MAX_TOUCH, "a row has room for two")
		expect.equal(ToastRules.max("down", Toasts), Toasts.MAX_TOUCH)
		expect.equal(ToastRules.max("up", Toasts), Toasts.MAX)
	end,
	-- Owner 2026-11-21: "just remove pish. and make the toast notification appear on the lower right": with nobody to
	-- say them, a computer's bubbles are plain (no tail pointing at empty space)
	["a bubble has a tail only when someone says it"] = function()
		expect.equal(ToastRules.tail("up", true), true, "Pish over the cash: his speech bubble")
		expect.equal(ToastRules.tail("up", false), false, "no Pish on the HUD: a plain bubble")
		expect.equal(ToastRules.tail("row", true), true)
		expect.equal(ToastRules.tail("down", false), true, "a phone's bubbles keep theirs, hanging from the column")
	end,
	-- owner 2026-11-20 ("Do. C": the combat HUD tidy): in a fight the toasts landed on the skill buttons (a computer's
	-- lower right) or beside the party strip (a phone); they hang under the foe's bar at the top centre instead
	["in a fight the toasts hang under the foe's bar, plain, two at most"] = function()
		expect.equal(ToastRules.mode(false, false, true), "under")
		expect.equal(ToastRules.mode(true, false, true), "under", "a phone too")
		expect.equal(ToastRules.mode(false, true, true), "under", "whatever Pish does")
		expect.equal(ToastRules.mode(false, false, false), "up", "no fight: as before")
		expect.equal(ToastRules.tail("under", true), false, "nobody says them")
		expect.equal(ToastRules.tail("under", false), false)
		expect.equal(ToastRules.max("under", Toasts), Toasts.MAX_TOUCH)
		local spot = ToastRules.under({ x = 600, y = 6, w = 720, h = 70 }, 96, Toasts.UNDER_GAP)
		expect.equal(spot.x, 960, "centred on the bar")
		expect.equal(spot.y, 96 + Toasts.UNDER_GAP, "under what hangs from the bar (its states, its adds)")
		expect.equal(ToastRules.under({ x = 600, y = 6, w = 720, h = 70 }, 0, Toasts.UNDER_GAP).y, 76 + Toasts.UNDER_GAP, "nothing under the bar: its own foot")
	end,

	-- owner 2026-11-28 "make sure no overlapping elements": a phone's stack hangs from the top left of the cash column,
	-- where the What now? bubble stands by the quest strip's arrow; the toasts hang under the bubble while it's there
	["a phone's toasts hang under the What now? bubble where it sits on their spot"] = function()
		local stack = { left = 119, right = 459 }
		local reach = Toasts.TOUCH_REACH
		expect.equal(ToastRules.hangBelow(14, stack, nil, reach, Toasts.GAP), 14, "no bubble: where they always hang")
		local bubble = { x = 259, y = 8, w = 289, h = 46 }
		expect.equal(ToastRules.hangBelow(14, stack, bubble, reach, Toasts.GAP), 54 + Toasts.GAP, "under it, the bubbles' gap off it")
		expect.equal(ToastRules.hangBelow(14, stack, { x = 470, y = 8, w = 260, h = 46 }, reach, Toasts.GAP), 14, "beside them: no move")
		expect.equal(ToastRules.hangBelow(14, stack, { x = 259, y = 14 + reach, w = 289, h = 46 }, reach, Toasts.GAP), 14, "under where they reach: no move")
		expect.equal(ToastRules.hangBelow(60, stack, { x = 259, y = 0, w = 289, h = 46 }, reach, Toasts.GAP), 60, "over them already: no move")
	end,
}
