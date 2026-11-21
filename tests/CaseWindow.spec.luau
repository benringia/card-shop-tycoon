--!strict
-- The card cases' window (owner 2026-11-21: "in glass cases make sure grades are noticeable too. redesign glass cases
-- window", his pick A of three mockups, "the case itself"; "also do the same for collector case"): every slot a big
-- card with its grade across it, a price tag under it and two words on how it sells; one bar under them for the
-- tapped card. Its words and sizes (Util/CaseWindow)
local CaseWindow = require("../src/shared/Util/CaseWindow")
local expect = require("./lib/expect")

return {
	["a price reads like money: commas, cents only when there are some"] = function()
		expect.equal(CaseWindow.money(3000), "$3,000")
		expect.equal(CaseWindow.money(1234567), "$1,234,567")
		expect.equal(CaseWindow.money(1200.5), "$1,200.50")
		expect.equal(CaseWindow.money(2.5), "$2.50")
		expect.equal(CaseWindow.money(14), "$14.00")
		expect.equal(CaseWindow.money(0.6), "$0.60")
		expect.equal(CaseWindow.money(999.999), "$1,000")
	end,

	["the grade across a card, in capitals"] = function()
		expect.equal(CaseWindow.gradeWords("S"), "GRADE S")
		expect.equal(CaseWindow.gradeWords("C"), "GRADE C")
		-- a card too narrow for the words (a phone's, beside the bar) wears the letter alone
		expect.equal(CaseWindow.gradeWords("S", 44), "S")
		expect.equal(CaseWindow.gradeWords("B", 69), "B")
		expect.equal(CaseWindow.gradeWords("B", 70), "GRADE B")
	end,

	["how a card sells, in two words and a colour"] = function()
		-- a Glass Showcase: the Prices window's own words for this price, green at or under market, then amber, then red
		local text, tone = CaseWindow.sells("CustomerCards", "Always buy", 1, false)
		expect.equal(text, "Always buy")
		expect.equal(tone, "good")
		text, tone = CaseWindow.sells("CustomerCards", "48% buy", 1.1, false)
		expect.equal(text, "48% buy")
		expect.equal(tone, "fair")
		text, tone = CaseWindow.sells("CustomerCards", "Won't buy", 1.6, false)
		expect.equal(tone, "bad")
		-- a Collector Case (players buy): the price against what the card is worth
		text, tone = CaseWindow.sells("PlayerCards", "", 1, false)
		expect.equal(text, "Fair price")
		expect.equal(tone, "good")
		text, tone = CaseWindow.sells("PlayerCards", "", 0.8, false)
		expect.equal(text, "20% under")
		expect.equal(tone, "good")
		text, tone = CaseWindow.sells("PlayerCards", "", 1.25, false)
		expect.equal(text, "25% over")
		expect.equal(tone, "fair")
		text, tone = CaseWindow.sells("PlayerCards", "", 2, false)
		expect.equal(text, "100% over")
		expect.equal(tone, "bad")
		-- a card just put in waits for its price
		text, tone = CaseWindow.sells("CustomerCards", "Always buy", 1, true)
		expect.equal(text, "Set its price")
		expect.equal(tone, "hold")
	end,

	["the bar's line about the tapped card: what it is worth, then what it is"] = function()
		expect.equal(CaseWindow.worthLine({ market = 3000, rarity = "Legendary", foil = true, level = 1, stars = 0 }), "Worth $3,000 · Legendary · Foil")
		expect.equal(CaseWindow.worthLine({ market = 0.6, rarity = "Common", foil = false, level = 1, stars = 0 }), "Worth $0.60 · Common")
		expect.equal(CaseWindow.worthLine({ market = 90, rarity = "Epic", foil = false, level = 12, stars = 2 }), "Worth $90.00 · Epic · Lv 12 · 2 stars")
		expect.equal(CaseWindow.worthLine({ market = 90, rarity = "Epic", foil = false, level = 1, stars = 1 }), "Worth $90.00 · Epic · 1 star")
	end,

	["the bar's small line: who can buy, and when"] = function()
		expect.equal(CaseWindow.hint("CustomerCards", true), "Customers can't buy it until you press Done.")
		expect.equal(CaseWindow.hint("PlayerCards", true), "Players can't buy it until you press Done.")
		expect.equal(CaseWindow.hint("CustomerCards", false), "Customers buy it at this price.")
		expect.equal(CaseWindow.hint("PlayerCards", false), "Players buy it at this price. Tap the price to type one.")
	end,

	["the slots stand in one row of six, more in rows of six; a card as big as the row lets it"] = function()
		expect.equal(CaseWindow.columns(6), 6)
		expect.equal(CaseWindow.columns(4), 4)
		expect.equal(CaseWindow.columns(12), 6)
		expect.equal(CaseWindow.columns(0), 1)
		-- the window's own 772 px for six cards 10 apart: each 120 wide, its card 0.7 as wide as tall, the tag and the
		-- words under it
		local tile = CaseWindow.tile(772, 320, 6, 1)
		expect.equal(tile.w, 120)
		expect.equal(tile.face, 171)
		expect.equal(tile.h, 171 + CaseWindow.LOOK.under)
		-- a short pane (a phone): the card shrinks to fit the height, never under the smallest
		local short = CaseWindow.tile(600, 190, 6, 1)
		assert(short.h <= 190, `fits the height: {short.h}`)
		assert(short.w >= CaseWindow.LOOK.minWidth, "still a card")
		-- two rows: each row gets half the height when that still fits a card, else the pane scrolls
		local two = CaseWindow.tile(772, 320, 6, 2)
		assert(two.w >= CaseWindow.LOOK.minWidth)
	end,
}
