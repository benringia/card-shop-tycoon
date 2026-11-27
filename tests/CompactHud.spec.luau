--!strict
-- The phone HUD, slimmed (owner 2026-11-13, pick A: "yea lets do A"): the cash pill's words, the rating in the Phone,
-- one weapon chip; where each HUD button sits (Util/CompactHud, Util/UiLayout.weaponSwitch)
local CompactHud = require("../src/shared/Util/CompactHud")
local UiLayout = require("../src/shared/Util/UiLayout")
local PhoneForm = require("../src/shared/Config/PhoneForm")
local SoftHud = require("../src/shared/Config/SoftHud")
local expect = require("./lib/expect")

return {
	-- Pre-launch QA 2026-11-19 (owner: "do all"): standing up, the Phone's app tiles came out 31 px on a Galaxy A06 and
	-- 36 px on an iPhone 17 Pro (the rule is 48). On a short screen it lies on its side, where they stay finger-sized.
	["the Phone lies on its side on a short screen, so its app tiles stay finger-sized"] = function()
		local tile = SoftHud.TILE.size
		-- screen heights under Roblox's 58 px top bar
		for name, height in { GalaxyA06 = 280, iPhone17Pro = 323 } do
			local tallScale = math.min(1, height * PhoneForm.fit / PhoneForm.tall.h)
			assert(tallScale * tile < PhoneForm.minTile, `{name}: standing up its tiles were too small`)
			local wide, scale = CompactHud.phoneForm(height, PhoneForm, tile)
			expect.equal(wide, true, name)
			assert(scale * tile >= PhoneForm.minTile, `{name}: tiles {scale * tile} px`)
			assert(scale * PhoneForm.wide.h <= height, `{name}: fits the screen's height`)
		end
		assert(CompactHud.phoneForm(280, PhoneForm, tile) and 705 >= select(2, CompactHud.phoneForm(280, PhoneForm, tile)) * PhoneForm.wide.w + 32, "fits a Galaxy A06's width")
		-- a tall screen keeps the standing phone at its size
		local wide, scale = CompactHud.phoneForm(1022, PhoneForm, tile)
		expect.equal(wide, false, "a desktop")
		expect.equal(scale, 1)
		local short, shortScale = CompactHud.phoneForm(477, PhoneForm, tile)
		expect.equal(short, false, "a short desktop window: still big enough standing")
		assert(shortScale * tile >= PhoneForm.minTile, "its tiles")
		local tablet, tabletScale = CompactHud.phoneForm(710, PhoneForm, tile)
		expect.equal(tablet, false, "an iPad")
		assert(tabletScale * tile >= PhoneForm.minTile, "its tiles are big enough standing")
	end,

	["the Phone on its side holds every app in two rows beside the dogs"] = function()
		local tile, gapX, gapY, top = SoftHud.TILE.size, 12, 26, 22 -- Util/Hud's app grid
		local screenWidth = PhoneForm.wide.w - 20 -- inside the bezel
		local appsWidth = screenWidth - (PhoneForm.wideSide + 34)
		assert(appsWidth >= PhoneForm.wideColumns * tile + (PhoneForm.wideColumns - 1) * gapX, `apps row: {appsWidth}`)
		local homeHeight = PhoneForm.wide.h - 20 - 34 -- under the status bar
		local rows = 2 -- ten apps at most (nine and Studio's Admin)
		assert(homeHeight - 44 >= top + rows * tile + (rows - 1) * gapY, "two rows of apps")
		assert(PhoneForm.wideColumns * rows >= 10, "room for every app")
	end,

	-- Owner 2026-11-17 ("move quest done strip a little higher on mobile. it overlaps with the jump button"): the strip
	-- went under the top-right column's frame (a fixed height with room to spare), onto Roblox's jump button
	["the phone's quest strip: under the column's last piece, never on the jump button"] = function()
		local screen = { w = 750, h = 323 } -- an iPhone 17 Pro's HUD space (381 under the 58 px top bar)
		local jump = CompactHud.jumpRect(screen.w, screen.h)
		expect.equal(jump.x, 655, "the jump button 95 px from the right")
		expect.equal(jump.y, 233, "and 90 from the bottom")
		expect.equal(jump.w, 70, "a phone's small jump button")
		local top, right = CompactHud.questSpot(150, { w = 150, h = 38 }, screen, jump, 16, 8)
		expect.equal(top, 158, "just under the party dock")
		expect.equal(right, 16, "at the right edge")
		-- a longer column (a team strip under it) would reach the jump button: beside it instead
		top, right = CompactHud.questSpot(210, { w = 150, h = 38 }, screen, jump, 16, 8)
		expect.equal(top, 218, "still under the column")
		assert(screen.w - right <= jump.x - 8, "left of the jump button")
		local tablet = CompactHud.jumpRect(1024, 710)
		expect.equal(tablet.w, 120, "a tablet's big jump button")
		expect.equal(tablet.x, 1024 - 170, "170 from the right")
		expect.equal(tablet.y, 710 - 210, "210 from the bottom")
	end,

	-- Owner 2026-11-17 ("mobile version screen now too crowded ... lets just display the important stuffs on mobile", "go
	-- A" of artifact GtT4bM87otu1aayFVANr7z): a phone keeps the essentials; the rest shows only where and when it matters
	["what a phone shows: the essentials, the rest only where and when it matters"] = function()
		local pc = CompactHud.phonePieces(false, true, false, false)
		for name, shown in pc :: any do
			-- (Turts' pill follows his restock on a computer too since 2026-11-21: below)
			if name ~= "questChip" and name ~= "turtsChip" then
				expect.equal(shown, true, `{name}: as today on a computer`)
			end
		end
		expect.equal(pc.questChip, false, "a computer keeps the quest strip")
		local town = CompactHud.phonePieces(true, true, false, false)
		expect.equal(town.nextUnlock, false, "no next-unlock line")
		expect.equal(town.quickParty, false, "no quick Party button (Party is in the Phone)")
		expect.equal(town.partyName, false, "no name under the creature")
		expect.equal(town.emptySlots, false, "no empty + slots")
		expect.equal(town.sideSlots, false, "one creature at a time: the rest a swipe or a hold away")
		expect.equal(town.weaponChip, true, "the weapon beside it in town too (the pair never moves)")
		expect.equal(town.giftTile, false, "the gift tile only once a gift is ready")
		expect.equal(town.turtsChip, false, "Turts' chip only just after he restocks")
		expect.equal(town.questChip, true, "the quests as a chip by the cash")
		expect.equal(town.mainRow, false, "no main quest row: the chip shows it once the day's quests are done")
		expect.equal(town.eventChip, false, "no weekly event chip: a phone gets its toast and the Boss Ladder's line")
		expect.equal(pc.eventChip, true, "a computer may show the event chip under the quests (when: EventRules.chipShown)")
		-- Owner 2026-11-21 ("I want to clean up", pick 1 of three mockups): a computer's pills under the quests show
		-- only when there's something to do, as a phone's always did
		expect.equal(pc.turtsChip, false, "a computer: no Turts pill while he's only counting down")
		expect.equal(CompactHud.phonePieces(false, true, false, true).turtsChip, true, "a computer: his pill once he has new stock")
		local wild = CompactHud.phonePieces(true, false, true, true)
		expect.equal(wild.sideSlots, false, "one creature in the Wild too (owner 2026-11-17: swipe or hold for the rest)")
		expect.equal(wild.weaponChip, true, "the weapon chip in the Wild")
		expect.equal(wild.emptySlots, false, "still no empty slots")
		expect.equal(wild.giftTile, true, "a ready gift shows")
		expect.equal(wild.turtsChip, true, "a fresh restock shows")
	end,

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
		local look = { chip = 72, side = 44, hit = 48, row = 8, drop = 8, rise = 9, name = 20, gap = 6, right = 12, compactChip = 64 }
		for _, view in { { w = 750, h = 381 }, { w = 667, h = 375 } } do
			local r = UiLayout.weaponSwitch(view, look, 0.7, false, nil, true)
			expect.near(r.w, look.compactChip * r.scale, 1e-6, "as wide as the chip")
			expect.near(r.h, look.compactChip * r.scale, 1e-6, "as tall as the chip (no dots under it)")
			expect.equal(look.compactChip * r.scale >= 48, true, "a finger-sized chip")
			expect.near(r.x + r.w, view.w - look.right, 1e-6, "on the right edge")
			expect.equal(r.y >= 0 and r.y + r.h <= view.h, true, "on screen")
		end
	end,

	-- Owner 2026-11-17 ("make sure nothing is cutoff/overlapping on all devices"): on a phone the left column held the
	-- Phone, Cards and the Gift tile, and on every landscape phone the Gift tile sat on the thumbstick's resting spot.
	-- A `bottom` tile (Gift) joins the bottom-centre row on a phone, clear of the thumbstick and the jump button; on a
	-- computer it stays in its own place
	["the Gift tile sits in the bottom row on a phone, clear of the thumbstick"] = function()
		local gift = { bottom = true }
		expect.equal(CompactHud.spot(gift, true, true), "bottom", "a phone: the bottom-centre row")
		expect.equal(CompactHud.spot(gift, true, false), "bottom", "in the Wild too")
		expect.equal(CompactHud.spot(gift, false, true), "tile", "a computer: its own place (the side column)")
	end,
}
