--!strict
-- The phone HUD, slimmed (owner 2026-11-13, pick A: "yea lets do A"): the cash pill's words, the rating in the Phone,
-- one weapon chip; where each HUD button sits (Util/CompactHud, Util/UiLayout.weaponSwitch)
local CompactHud = require("../src/shared/Util/CompactHud")
local UiLayout = require("../src/shared/Util/UiLayout")
local expect = require("./lib/expect")

return {
	-- owner 2026-11-13 round 2 (pick A, "move the admin tile inside phone and move binder tile under phone"): on a
	-- phone Bag, Bosses and Admin are Phone apps, Cards sits under the Phone, the shop apps stay in town
	["a HUD button's spot: Bag / Bosses / Admin in the Phone on a phone, Cards under it, shop apps only in town"] = function()
		local bag = { phone = true }
		expect.equal(CompactHud.spot(bag, false, true), "tile", "a computer: its own tile, as before")
		expect.equal(CompactHud.spot(bag, true, true), "phone")
		expect.equal(CompactHud.spot(bag, true, false), "phone", "in the Wild too")
		local cards = { side = true }
		expect.equal(CompactHud.spot(cards, true, true), "side", "under the Phone")
		expect.equal(CompactHud.spot(cards, true, false), "side")
		expect.equal(CompactHud.spot(cards, false, true), "tile")
		local shop = { app = true }
		expect.equal(CompactHud.spot(shop, true, true), "phone")
		expect.equal(CompactHud.spot(shop, true, false), "hidden", "no shop apps away from town")
		expect.equal(CompactHud.spot(shop, false, true), "phone")
		local party = { app = true, everywhere = true }
		expect.equal(CompactHud.spot(party, true, false), "phone")
		expect.equal(CompactHud.spot({}, true, true), "tile", "Drop and Rip stay where they are")
		-- owner 2026-11-13 (a PC screenshot): "put the bosses inside [the phone] as an app. only cards and bag should be
		-- left at the center ... put the admin tile inside phone": Bosses and Admin are Phone apps on a computer too
		local bosses = { phone = true, always = true }
		expect.equal(CompactHud.spot(bosses, false, true), "phone", "a computer: in the Phone too")
		expect.equal(CompactHud.spot(bosses, false, false), "phone", "everywhere")
		expect.equal(CompactHud.spot(bosses, true, true), "phone")
	end,

	-- owner 2026-11-13 (the party dock, pick A: Pish peeks over the Phone tile, a Support app inside): the Phone shows
	-- wherever it holds an app, on a computer too (Party and Support are everywhere)
	["the Phone tile: wherever it holds an app"] = function()
		expect.equal(CompactHud.phoneTile({ "phone" }), true)
		expect.equal(CompactHud.phoneTile({ "hidden", "phone" }), true, "the Wild: Party and Support")
		expect.equal(CompactHud.phoneTile({ "hidden", "tile" }), false, "nothing inside: no Phone")
		expect.equal(CompactHud.phoneTile({}), false)
	end,

	-- a ring drawn as two clipped halves (a timed buff's ring on a phone, owner 2026-11-13 buffs pick A)
	["a ring: the right half fills first, then the left, each up to 180 degrees"] = function()
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

	["cash on a phone: whole dollars with commas, millions short"] = function()
		expect.equal(CompactHud.money(53661.84), "$53,661")
		expect.equal(CompactHud.money(412.5), "$412")
		expect.equal(CompactHud.money(0), "$0")
		expect.equal(CompactHud.money(999999), "$999,999")
		expect.equal(CompactHud.money(1250000), "$1.25M")
		expect.equal(CompactHud.money(12000000), "$12M")
		expect.equal(CompactHud.money(-5), "$0", "never below zero")
	end,

	-- owner 2026-11-13 (declutter pick A): the weapon's dots became a small "1/6" on the chip's corner
	["the weapon chip's count: the one in hand of how many, nothing with one weapon"] = function()
		expect.equal(CompactHud.weaponCount({ "a", "b", "c", "d", "e", "f" }, "a"), "1/6")
		expect.equal(CompactHud.weaponCount({ "a", "b", "c" }, "c"), "3/3")
		expect.equal(CompactHud.weaponCount({ "a", "b" }, nil), "1/2", "nothing equipped yet: the first")
		expect.equal(CompactHud.weaponCount({ "a" }, "a"), "", "one weapon: no count")
		expect.equal(CompactHud.weaponCount({}, nil), "")
	end,

	["one weapon chip on a phone: just the chip, a big tap target, on the right edge"] = function()
		local look = { chip = 58, side = 40, arrow = 30, hit = 48, gap = 6, right = 12, name = 22, compactChip = 64 }
		for _, view in { { w = 750, h = 381 }, { w = 667, h = 375 } } do
			local r = UiLayout.weaponSwitch(view, look, 0.7, false, nil, true)
			expect.near(r.w, look.compactChip * r.scale, 1e-6, "as wide as the chip")
			expect.near(r.h, look.compactChip * r.scale, 1e-6, "as tall as the chip (no dots under it)")
			expect.equal(look.compactChip * r.scale >= 48, true, "a finger-sized chip")
			expect.near(r.x + r.w, view.w - look.right, 1e-6, "on the right edge")
			expect.equal(r.y >= 0 and r.y + r.h <= view.h, true, "on screen")
		end
	end,
}
