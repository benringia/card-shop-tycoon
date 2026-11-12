--!strict
-- The phone HUD, slimmed (owner 2026-11-13, pick A: "yea lets do A"): one pill with cash and the level badge whose XP
-- ring fills, the rating in the Phone, the party bar without its "Party" word, one weapon chip (Util/CompactHud,
-- Util/UiLayout.weaponSwitch)
local CompactHud = require("../src/shared/Util/CompactHud")
local UiLayout = require("../src/shared/Util/UiLayout")
local HudMascot = require("../src/shared/Config/HudMascot")
local expect = require("./lib/expect")

return {
	-- owner 2026-11-13 (a phone screenshot): "pish and coins overlapping. move them higher up. make sure nothing is
	-- overlapping": Pish pokes up over the party bar, so the column keeps a gap for him and the cash pill goes up into
	-- the free strip beside Roblox's top bar, never off the screen
	["Pish's room over the party bar, and how far the cash pill can go up"] = function()
		local rise = CompactHud.mascotRise(HudMascot)
		expect.equal(rise, HudMascot.size.peek[2] - HudMascot.offset.overlap, "his picture over the bar's top edge")
		expect.equal(CompactHud.mascotRise({ images = { peek = "" }, size = HudMascot.size, offset = HudMascot.offset }), 0, "no picture: no room")
		expect.equal(CompactHud.lift(43, 0.84, 58, 8), 43 * 0.84, "a phone with Roblox's top bar: up into its strip")
		expect.equal(CompactHud.lift(43, 1, 20, 8), 24, "a small inset: up only as far as the screen's top (4 px left)")
		expect.equal(CompactHud.lift(43, 1, 0, 8), 4)
	end,

	["cash on a phone: whole dollars with commas, millions short"] = function()
		expect.equal(CompactHud.money(53661.84), "$53,661")
		expect.equal(CompactHud.money(412.5), "$412")
		expect.equal(CompactHud.money(0), "$0")
		expect.equal(CompactHud.money(999999), "$999,999")
		expect.equal(CompactHud.money(1250000), "$1.25M")
		expect.equal(CompactHud.money(12000000), "$12M")
		expect.equal(CompactHud.money(-5), "$0", "never below zero")
	end,

	["the XP ring: the right half fills first, then the left, each up to 180 degrees"] = function()
		local function both(share: number): string
			local right, left = CompactHud.ring(share)
			return `{right},{left}`
		end
		expect.equal(both(0), "0,0")
		expect.equal(both(0.25), "90,0")
		expect.equal(both(0.5), "180,0")
		expect.equal(both(0.75), "180,90")
		expect.equal(both(1), "180,180")
		expect.equal(both(1.4), "180,180", "never past full")
		expect.equal(both(-1), "0,0")
	end,

	["one weapon chip on a phone: just the chip and its dots, a big tap target, on the right edge"] = function()
		local look = { chip = 58, side = 40, arrow = 30, hit = 48, gap = 6, right = 12, name = 22, compactChip = 64, dots = 10 }
		for _, view in { { w = 750, h = 381 }, { w = 667, h = 375 } } do
			local r = UiLayout.weaponSwitch(view, look, 0.7, false, nil, true)
			expect.near(r.w, look.compactChip * r.scale, 1e-6, "as wide as the chip")
			expect.equal(look.compactChip * r.scale >= 48, true, "a finger-sized chip")
			expect.near(r.x + r.w, view.w - look.right, 1e-6, "on the right edge")
			expect.equal(r.y >= 0 and r.y + r.h <= view.h, true, "on screen")
		end
	end,
}
