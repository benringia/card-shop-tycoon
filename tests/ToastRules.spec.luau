--!strict
-- Toasts as Cindercub's speech bubbles stacked over the cash pill (owner's pick A, 2026-11-06)
local ToastRules = require("../src/shared/Util/ToastRules")
local Toasts = require("../src/shared/Config/Toasts")
local expect = require("./lib/expect")

local function entry(id: number, message: string): ToastRules.Entry
	return { id = id, message = message }
end

return {
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
}
