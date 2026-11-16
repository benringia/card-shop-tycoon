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

	["money given lines up on the counter, and wraps to a second row"] = function()
		local given = RegisterStation.GIVEN
		local first = RegisterStationRules.givenSpot(given, 1, 8)
		local second = RegisterStationRules.givenSpot(given, 2, 8)
		assert(second.x > first.x and second.z == first.z, "side by side")
		local ninth = RegisterStationRules.givenSpot(given, 9, 8)
		assert(ninth.z ~= first.z and ninth.x == first.x, "a second row")
	end,
}
