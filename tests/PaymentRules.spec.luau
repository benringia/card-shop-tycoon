--!strict
-- The register's payment step (owner 2026-11-16: "players go into the cashier and type/click the actual total and change
-- of the customer"; mockup approved): card customers have you type the total, cash customers have you count the change
local PaymentRules = require("../src/shared/Util/PaymentRules")
local Payment = require("../src/shared/Config/Payment")
local expect = require("./lib/expect")

local function typeAll(keys: { string }): string
	local text = ""
	for _, key in keys do
		text = PaymentRules.typeKey(text, key, Payment.MAX_TYPED)
	end
	return text
end

return {
	["how they pay: about half by card; kids mostly cash, big spenders mostly card"] = function()
		local function cardShare(kind: string): number
			local cards = 0
			for step = 0, 999 do
				if PaymentRules.method(Payment, kind, step / 1000) == "card" then
					cards += 1
				end
			end
			return cards / 1000
		end
		local plain = cardShare("plain")
		assert(plain > 0.4 and plain < 0.6, "about half")
		assert(cardShare("kid") < plain, "kids pay cash more")
		assert(cardShare("bigSpender") > plain, "big spenders tap a card more")
		expect.equal(cardShare("someNewType"), plain, "an unknown type pays like anyone")
	end,

	["cash: they hand over the next bill up, never the exact total"] = function()
		expect.equal(PaymentRules.given(Payment, 1750), 2000)
		expect.equal(PaymentRules.given(Payment, 300), 500)
		expect.equal(PaymentRules.given(Payment, 500), 1000, "an exact $5 total: a $10 bill")
		expect.equal(PaymentRules.given(Payment, 9999), 10000)
		expect.equal(PaymentRules.given(Payment, 24000), 25000, "past $100: up to the next $50")
		expect.equal(PaymentRules.given(Payment, 25000), 30000)
		for total = 1, 30000, 137 do
			local given = PaymentRules.given(Payment, total)
			assert(given > total, `more than {total}`)
			assert(given - total <= 5000, `change at most $50 for {total}`)
		end
	end,

	["the card machine: digits, one point, two decimals, delete"] = function()
		expect.equal(typeAll({ "1", "7", ".", "5", "0" }), "17.50")
		expect.equal(typeAll({ "1", "7", ".", ".", "5" }), "17.5", "a second point is ignored")
		expect.equal(typeAll({ "1", ".", "2", "5", "9" }), "1.25", "two decimals at most")
		expect.equal(typeAll({ ".", "5" }), "0.5", "a point first means 0.")
		expect.equal(typeAll({ "0", "0", "7" }), "7", "no leading zeros")
		expect.equal(typeAll({ "1", "2", "del" }), "1")
		expect.equal(typeAll({ "1", "2", "clear" }), "")
		expect.equal(typeAll({ "1", "x", "2" }), "12", "anything else is ignored")
		local long = typeAll({ "9", "9", "9", "9", "9", "9", "9", "9", "9", "9" })
		assert(#long <= Payment.MAX_TYPED, "the screen has room for so many")
	end,

	["what was typed in cents"] = function()
		expect.equal(PaymentRules.typedCents("17.50"), 1750)
		expect.equal(PaymentRules.typedCents("17.5"), 1750)
		expect.equal(PaymentRules.typedCents("17"), 1700)
		expect.equal(PaymentRules.typedCents("0.5"), 50)
		expect.equal(PaymentRules.typedCents(""), nil)
		expect.equal(PaymentRules.typedCents("."), nil)
		expect.equal(PaymentRules.typedCents("1.2.3"), nil)
	end,

	["a card payment is right only at the exact total"] = function()
		expect.equal(PaymentRules.cardRight(1750, 1750), true)
		expect.equal(PaymentRules.cardRight(1700, 1750), false)
		expect.equal(PaymentRules.cardRight(17.5, 1750), false, "dollars sent as cents: wrong")
		expect.equal(PaymentRules.cardRight((0 / 0 :: any) :: number, 1750), false, "not a number")
	end,

	["change: exact, short, too much, or not money from the drawer"] = function()
		expect.equal(PaymentRules.checkChange(Payment, { 100, 100, 25, 25 }, 250), "ok")
		expect.equal(PaymentRules.checkChange(Payment, { 100, 100 }, 250), "short")
		expect.equal(PaymentRules.checkChange(Payment, { 500 }, 250), "over")
		expect.equal(PaymentRules.checkChange(Payment, {}, 250), "short")
		expect.equal(PaymentRules.checkChange(Payment, { 300 }, 300), "bad", "no $3 bill in the drawer")
		expect.equal(PaymentRules.checkChange(Payment, { 100, -100 }, 0), "bad", "no negative money")
		expect.equal(PaymentRules.checkChange(Payment, { 1.5 } :: any, 1.5), "bad", "whole cents only")
		expect.equal(PaymentRules.checkChange(Payment, "lots" :: any, 250), "bad", "a list of pieces")
		local tooMany = table.create(Payment.MAX_PIECES + 1, 1)
		expect.equal(PaymentRules.checkChange(Payment, tooMany, Payment.MAX_PIECES + 1), "bad", "a handful, not a sackful")
	end,

	["money words with plain ASCII (the game fonts draw no cents sign)"] = function()
		expect.equal(PaymentRules.money(1750), "$17.50")
		expect.equal(PaymentRules.money(25), "$0.25")
		expect.equal(PaymentRules.money(2000), "$20.00")
		for _, cents in Payment.DRAWER do
			assert(string.match(PaymentRules.pieceText(cents), "^[%$%d%.]+$"), `{cents}: plain text`)
		end
		expect.equal(PaymentRules.pieceText(2000), "$20")
		expect.equal(PaymentRules.pieceText(25), "$0.25")
	end,
}
