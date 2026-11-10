--!strict
-- The owner 2026-11-10: "picking up an item should show a notification" (the old "+1 item" note was too easy to miss):
-- each pickup pops a card at the top right; the same item again while its card shows adds to it; a few stack
local ItemPopupRules = require("../src/shared/Util/ItemPopupRules")
local Victory = require("../src/shared/Config/Victory")
local expect = require("./lib/expect")

local CFG = { seconds = 3, max = 3, height = 50, gap = 6, top = 70 }

return {
	["a pickup pops a card; the same item again adds to it and keeps it up"] = function()
		local list = ItemPopupRules.add({}, "gradingSeal", 1, 10, CFG)
		expect.equal(#list, 1)
		expect.equal(list[1].count, 1)
		list = ItemPopupRules.add(list, "gradingSeal", 2, 12, CFG)
		expect.equal(#list, 1, "merged")
		expect.equal(list[1].count, 3)
		expect.equal(list[1].untilTime, 15, "shown 3 s from the last pickup")
		expect.equal(list[1].bumped, 2, "it says it grew")
	end,

	["different items stack, newest at the bottom, the oldest dropped past the cap"] = function()
		local list = {}
		for index, item in { "a", "b", "c", "d" } do
			list = ItemPopupRules.add(list, item, 1, index, CFG)
		end
		expect.equal(#list, 3)
		expect.equal(list[1].item, "b", "the oldest went")
		expect.equal(list[3].item, "d")
	end,

	["a card goes when its time is up"] = function()
		local list = ItemPopupRules.add({}, "a", 1, 0, CFG)
		list = ItemPopupRules.add(list, "b", 1, 2, CFG)
		local kept = ItemPopupRules.expire(list, 3.5)
		expect.equal(#kept, 1)
		expect.equal(kept[1].item, "b")
	end,

	["cards sit one under the other from the top"] = function()
		expect.equal(ItemPopupRules.slotY(1, CFG), 70)
		expect.equal(ItemPopupRules.slotY(3, CFG), 70 + 2 * 56)
	end,

	["the pickup cards' numbers are set"] = function()
		local cfg = Victory.PICKUP
		assert(cfg.seconds >= 2 and cfg.seconds <= 5, "long enough to read")
		assert(cfg.max >= 3, "a few stack")
		assert(cfg.height >= 48, "big enough to read on a phone")
		assert(cfg.top >= 60, "under Roblox's top bar")
		assert(string.match(cfg.sound, "^rbxassetid://%d+$"), "a pickup sound")
	end,
}
