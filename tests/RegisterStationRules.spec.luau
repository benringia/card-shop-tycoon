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

	-- Owner 2026-11-20: "make clicking on moneys on the cashier more immersive": a tapped note or coin flies out of
	-- the drawer onto the counter (and back when you take it off), with its own sound climbing as you count
	["counting change: each piece's sound a little higher than the last, never a squeak"] = function()
		local fx = RegisterStation.GIVE_FX
		expect.equal(RegisterStationRules.givePitch(1, fx), 1, "the first piece at its own pitch")
		assert(RegisterStationRules.givePitch(2, fx) > 1, "the second a little higher")
		assert(RegisterStationRules.givePitch(4, fx) > RegisterStationRules.givePitch(3, fx))
		expect.equal(RegisterStationRules.givePitch(40, fx), fx.sounds.pitchMax, "capped")
		expect.equal(RegisterStationRules.givePitch(0, fx), 1)
		assert(fx.sounds.pitchMax <= 1.4, "never a squeak")
		assert(fx.sounds.backPitch < 1, "taking one back sounds lower")
		for _, kind in { "note", "coin" } do
			local sound = fx.sounds[kind]
			assert(string.match(sound.id, "^rbxassetid://%d+$"), `{kind}: a sound`)
			assert(sound.volume > 0 and sound.volume <= 0.5, `{kind}: under the register's own sounds`)
			assert(sound.cut > 0.1 and sound.cut <= 0.8, `{kind}: one short flick of a longer clip`)
		end
		assert(fx.fly >= 0.15 and fx.fly <= 0.35, "quick: a fast counter never waits for it")
		assert(fx.back <= fx.fly)
	end,

	["the piece you just laid down is the last of its value in the row (the row runs high to low)"] = function()
		expect.equal(RegisterStationRules.addedIndex({ 100 }, 100), 1)
		expect.equal(RegisterStationRules.addedIndex({ 500, 100, 100, 25 }, 100), 3, "after the $1 already there")
		expect.equal(RegisterStationRules.addedIndex({ 500, 100, 25, 25, 1 }, 25), 4)
		expect.equal(RegisterStationRules.addedIndex({ 500, 100 }, 500), 1)
		expect.isNil(RegisterStationRules.addedIndex({ 500, 100 }, 25), "not on the counter")
		expect.isNil(RegisterStationRules.addedIndex({}, 25))
	end,

	["a piece flies in a low arc: on the line at both ends, highest in the middle"] = function()
		expect.equal(RegisterStationRules.arcLift(0, 0.5), 0)
		expect.equal(RegisterStationRules.arcLift(1, 0.5), 0)
		expect.equal(RegisterStationRules.arcLift(0.5, 0.5), 0.5)
		expect.equal(RegisterStationRules.arcLift(3, 0.5), 0, "never under the counter")
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
	-- Owner 2026-11-21: "make this LEAVE button in cashier consistent with the rest of the buttons. and add a hotkey":
	-- the soft cotton candy look with an icon and a key in a white circle, like the HUD's tiles; its key leaves too
	["Leave has a hotkey no other button on the register or the HUD uses"] = function()
		local pill = RegisterStation.LEAVE_PILL
		assert(typeof(pill.key) == "string" and string.match(pill.key, "^%u$"), "one letter")
		for _, taken in { "B", "I", "K", "P", "Q", "Z", "C", "E", "F", "R", "W", "A", "S", "D", "M", "O" } do
			assert(pill.key ~= taken, `{taken} is taken (HUD tiles, weapons, prompts, walking, Roblox's own)`)
		end
		-- "hotkey X look like a close" (owner 2026-11-21): never the letter of a close button, and drawn as a square key
		assert(pill.key ~= "X", "an X on a button reads as close")
		assert(pill.cap >= 22, "a keyboard key you can read")
		expect.equal(RegisterStationRules.leaveKey(pill.key, pill, true, false), true, "its key, on the register")
		expect.equal(RegisterStationRules.leaveKey(pill.key, pill, false, false), false, "not on the register: nothing")
		expect.equal(RegisterStationRules.leaveKey(pill.key, pill, true, true), false, "typing in a box: nothing")
		expect.equal(RegisterStationRules.leaveKey("B", pill, true, false), false, "another key")
		assert(pill.height >= 48 and pill.width >= 120, "a tap target with room for the icon, the word and the key")
		assert(typeof(pill.icon) == "string" and #pill.icon > 0, "an icon, like the other buttons")
	end,
	-- owner 2026-11-20: "in cash register. can we just add a permanent guide/highlight for the change/give back? some
	-- kids doesnt do well with math and this will be so confusing for them"
	["the change guide is always on: the next note or coin glows from the first moment"] = function()
		expect.equal(RegisterStation.HELPER_SECONDS, 0, "no wait before it shows")
		expect.equal(RegisterStationRules.guideOn(0, RegisterStation), true, "the moment the customer pays")
		expect.equal(RegisterStationRules.guideOn(30, RegisterStation), true)
		assert(RegisterStation.HELPER_TAG.text ~= "", "a pointer over the glowing money")
	end,
	-- owner 2026-11-20: "change TAP to something like 'TAP 2X,3X' that decreases with every tap so that kids will
	-- understand it more"
	["the guide's pill counts the taps left on the glowing note or coin, down to 1"] = function()
		local drawer = Payment.DRAWER
		local tag = RegisterStation.HELPER_TAG
		local piece, taps = RegisterStationRules.tapsLeft(drawer, 350)
		expect.equal(piece, 100, "$3.50 left: the $1 note")
		expect.equal(taps, 3, "three times")
		expect.equal(RegisterStationRules.tapWords(taps, tag), "Tap 3x")
		piece, taps = RegisterStationRules.tapsLeft(drawer, 250)
		expect.equal(taps, 2, "one tap later: twice")
		expect.equal(RegisterStationRules.tapWords(taps, tag), "Tap 2x")
		piece, taps = RegisterStationRules.tapsLeft(drawer, 150)
		expect.equal(RegisterStationRules.tapWords(taps, tag), "Tap 1x")
		piece, taps = RegisterStationRules.tapsLeft(drawer, 50)
		expect.equal(piece, 25, "then the quarters")
		expect.equal(taps, 2)
		piece, taps = RegisterStationRules.tapsLeft(drawer, 4)
		expect.equal(piece, 1)
		expect.equal(taps, 4, "four pennies")
		piece, taps = RegisterStationRules.tapsLeft(drawer, 0)
		expect.isNil(piece, "nothing left to give")
		expect.equal(taps, 0)
		-- following the count always lands on the exact change
		for change = 1, 4999, 53 do
			local left = change
			while left > 0 do
				local coin, times = RegisterStationRules.tapsLeft(drawer, left)
				assert(coin and times >= 1, `a piece to tap for {left}`)
				left -= (coin :: number) * times
			end
			expect.equal(left, 0, `exact for {change}`)
		end
	end,
}
