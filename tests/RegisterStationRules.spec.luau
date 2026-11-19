--!strict
-- Manning the register in first person (owner 2026-11-16: "Man the cashier ... switch to first person with the UI of an
-- actual cash register"): what the register's screen and the hint show, and the cash drawer's money slots
local RegisterStationRules = require("../src/shared/Util/RegisterStationRules")
local RegisterStation = require("../src/shared/Config/RegisterStation")
local Payment = require("../src/shared/Config/Payment")
local expect = require("./lib/expect")

local function state(overrides: { [string]: any }): RegisterStationRules.State
	local base = { manned = true, checkoutOpen = false, remaining = 0, offerOpen = false, paying = nil }
	for key, value in overrides do
		(base :: any)[key] = value
	end
	return base :: any
end

return {
	["what the screen shows, step by step"] = function()
		expect.equal(RegisterStationRules.situation(state({ manned = false, checkoutOpen = true, remaining = 2 })), "off", "not manned: nothing")
		expect.equal(RegisterStationRules.situation(state({})), "idle", "no customer yet")
		expect.equal(RegisterStationRules.situation(state({ checkoutOpen = true, remaining = 2 })), "scan")
		expect.equal(RegisterStationRules.situation(state({ checkoutOpen = true, remaining = 0 })), "charge")
		expect.equal(RegisterStationRules.situation(state({ checkoutOpen = true, offerOpen = true })), "offer", "a deal to answer first")
		expect.equal(RegisterStationRules.situation(state({ checkoutOpen = true, paying = "card" })), "card")
		expect.equal(RegisterStationRules.situation(state({ checkoutOpen = true, paying = "cash" })), "cash")
		expect.equal(RegisterStationRules.situation(state({ checkoutOpen = false, paying = "cash" })), "idle", "the checkout ended: done paying")
	end,

	["the screen says what to do in every situation (owner: \"it is also currently confusing for the kids\")"] = function()
		for _, situation in { "idle", "scan", "charge", "offer", "card", "cash" } do
			local line = RegisterStation.SAY[situation]
			assert(typeof(line) == "string" and line ~= "", situation)
		end
	end,

	["the helper: the biggest note or coin that still fits the change left"] = function()
		local drawer = Payment.DRAWER
		expect.equal(RegisterStationRules.nextPiece(drawer, 400), 100, "$4.00: a $1")
		expect.equal(RegisterStationRules.nextPiece(drawer, 1460), 1000, "$14.60: a $10")
		expect.equal(RegisterStationRules.nextPiece(drawer, 60), 25, "60 cents: a quarter")
		expect.equal(RegisterStationRules.nextPiece(drawer, 4), 1, "4 cents: a penny")
		expect.equal(RegisterStationRules.nextPiece(drawer, 0), nil, "nothing left")
		expect.equal(RegisterStationRules.nextPiece(drawer, -100), nil, "too much given")
		-- following it always makes the exact change
		for change = 1, 4999, 37 do
			local left, count = change, 0
			while left > 0 do
				local piece = RegisterStationRules.nextPiece(drawer, left) :: number
				left -= piece
				count += 1
			end
			expect.equal(left, 0, `exact for {change}`)
			assert(count <= Payment.MAX_PIECES, `{change} in at most {Payment.MAX_PIECES} pieces`)
		end
	end,

	["the screen's clock reads the town's time"] = function()
		expect.equal(RegisterStationRules.clock(9.7), "9:42 AM")
		expect.equal(RegisterStationRules.clock(0), "12:00 AM")
		expect.equal(RegisterStationRules.clock(12.5), "12:30 PM")
		expect.equal(RegisterStationRules.clock(23.99), "11:59 PM")
	end,

	["every note and coin has its picture"] = function()
		for _, cents in Payment.DRAWER do
			local image = RegisterStation.MONEY_IMAGES[cents]
			assert(typeof(image) == "string" and string.match(image, "^rbxassetid://%d+$"), `{cents}`)
		end
	end,

	["the drawer: one slot per bill and coin, bills at the back, coins in front, none overlapping, all inside the tray"] = function()
		local tray = RegisterStation.UNIT.drawer.size
		local slots = RegisterStationRules.drawerSlots(Payment.DRAWER, tray[1], tray[3], RegisterStation.NOTE_ROW)
		expect.equal(#slots, #Payment.DRAWER)
		for index, slot in slots do
			expect.equal(slot.cents, Payment.DRAWER[index])
			assert(math.abs(slot.x) + slot.width / 2 <= tray[1] / 2 + 1e-6, `{slot.cents} inside the tray's width`)
			assert(math.abs(slot.z) + slot.depth / 2 <= tray[3] / 2 + 1e-6, `{slot.cents} inside the tray's depth`)
			local bill = slot.cents >= 100
			-- +Z is toward the cashier: coins nearest them
			if bill then
				assert(slot.z < 0, `{slot.cents}: bills at the back`)
			else
				assert(slot.z > 0, `{slot.cents}: coins in front`)
			end
			for other = index + 1, #slots do
				local them = slots[other]
				local apart = math.abs(slot.x - them.x) >= (slot.width + them.width) / 2 - 1e-6
					or math.abs(slot.z - them.z) >= (slot.depth + them.depth) / 2 - 1e-6
				assert(apart, `{slot.cents} and {them.cents} don't overlap`)
			end
		end
	end,

	-- Owner 2026-11-19 (second playthrough): "make the card machine unusable when it's not supposed to be used": its
	-- keys only work while a customer pays by card; any other time its face is asleep
	["the card machine is awake only for a card payment"] = function()
		expect.equal(RegisterStationRules.keypadOn("card"), true)
		for _, situation in { "off", "idle", "scan", "charge", "offer", "cash" } do
			expect.equal(RegisterStationRules.keypadOn(situation :: any), false, `{situation}: asleep`)
		end
		assert(#RegisterStation.SCREEN.keypadOff > 0 and #RegisterStation.SCREEN.keypadOffHint > 0, "its sleeping face says so")
	end,

	-- Owner 2026-11-19 (second playthrough): "add money model on the cashier for moneys at the table": the change you
	-- lay on the counter is the drawer's own notes and coins (their pictures), big enough to read and to tap
	["money on the counter is the drawer's notes and coins: note-shaped, apart, clear of the counter's decor"] = function()
		local Town = require("../src/shared/Config/Town")
		local given = RegisterStation.GIVEN
		local bill, coin = given.billSize, given.coinSize
		local aspect = bill[1] / bill[3]
		assert(math.abs(aspect - RegisterStation.NOTE_ASPECT) < 0.03, "a note keeps its picture's shape")
		assert(bill[3] >= 0.55, "a note big enough to read from the cashier's eye")
		assert(coin[2] >= 0.28 and coin[2] == coin[3], "a round coin big enough to tap")
		assert(given.step >= bill[1] + 0.03, "notes side by side don't overlap")
		local last = RegisterStationRules.givenSpot(given, given.perRow, given.perRow)
		local decor = Town.COUNTER.DECOR
		assert(last.x + bill[1] / 2 <= decor.x - decor.width / 2, "a full row stops before the counter's decor")
		local register = Town.COUNTER.REGISTER
		local first = RegisterStationRules.givenSpot(given, 1, given.perRow)
		assert(first.x - bill[1] / 2 >= register.x + register.width / 2, "and starts past the register")
		local second = RegisterStationRules.givenSpot(given, given.perRow + 1, given.perRow)
		assert(first.z - second.z >= bill[3] + 0.02, "a second row clear of the first")
		for _, cents in Payment.DRAWER do
			assert(RegisterStation.MONEY_IMAGES[cents], `{cents}: its picture`)
			assert(RegisterStation.MONEY_COLORS[cents], `{cents}: its colour`)
		end
	end,

	["money given lines up on the counter, and wraps to a second row"] = function()
		local given = RegisterStation.GIVEN
		local first = RegisterStationRules.givenSpot(given, 1, 8)
		local second = RegisterStationRules.givenSpot(given, 2, 8)
		assert(second.x > first.x and second.z == first.z, "side by side")
		local ninth = RegisterStationRules.givenSpot(given, 9, 8)
		assert(ninth.z ~= first.z and ninth.x == first.x, "a second row")
	end,

	-- Owner 2026-11-16: "money should be visible while I'm using cash register. with immersive animation/effects when
	-- someone buys something": coins fly from the register into the cash pill, more for a bigger sale
	["a sale's coins: a few for a small sale, more for a big one, never past the cap"] = function()
		local fx = RegisterStation.SALE_FX
		local small = RegisterStationRules.saleCoins(2, fx)
		local mid = RegisterStationRules.saleCoins(12.5, fx)
		local big = RegisterStationRules.saleCoins(90, fx)
		local huge = RegisterStationRules.saleCoins(100000, fx)
		expect.equal(small >= fx.coins[1], true, "at least the fewest")
		expect.equal(small < mid and mid < big, true, `more for more ({small}, {mid}, {big})`)
		expect.equal(huge, fx.coins[2], "never past the most")
		expect.equal(RegisterStationRules.saleCoins(0, fx), fx.coins[1], "a free sale still shows the fewest")
	end,
}
