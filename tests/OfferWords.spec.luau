--!strict
-- The register's offer panel in words (owner 2026-11-19, second playthrough: "improve bargainers offer UI to be
-- immersive and easily understandable"; it said "Offers $2.72 for $3.25 (-16%)" over Deal / Counter / No)
local OfferWords = require("../src/shared/Util/OfferWords")
local Customers = require("../src/shared/Config/Customers")
local expect = require("./lib/expect")

local WORDS = Customers.OFFER_WORDS
local RETRIES = Customers.OFFER.retries

local function haggle(offer: number, total: number): OfferWords.Offer
	return { kind = "haggle", offer = offer, total = total, triesLeft = 1 }
end

local function kid(asking: number, worth: number, triesLeft: number?): OfferWords.Offer
	return { kind = "kid", cardName = "Voltkit", asking = asking, worth = worth, triesLeft = triesLeft or RETRIES + 1 }
end

return {
	["a bargain hunter asks in their own words, your price beside theirs, and what you'd lose"] = function()
		local main = OfferWords.main(WORDS, haggle(2.72, 3.25))
		expect.equal(main.quote, '"Can I have it all for $2.72?"')
		expect.equal(main.leftLabel, "Your price")
		expect.equal(main.leftValue, "$3.25")
		expect.equal(main.rightLabel, "Their offer")
		expect.equal(main.rightValue, "$2.72")
		expect.equal(main.delta, "You get $0.53 less (-16%)")
		expect.equal(main.tone, "bad")
		expect.equal(main.yes, "Deal for $2.72", "the button says the price you'd get")
		expect.equal(main.counter, "Ask for more")
		expect.equal(main.no, "No deal")
		assert(string.find(main.foot, "shel", 1, true), "what No deal does: it all goes back on the shelves")
		-- cents never drift: 10% off $0.30
		expect.equal(OfferWords.main(WORDS, haggle(0.27, 0.30)).delta, "You get $0.03 less (-10%)")
		expect.equal(OfferWords.main(WORDS, haggle(0, 0)).delta, "You get $0.00 less (-0%)", "no total: no error")
	end,

	["a kid's offer: what the card is worth beside what they ask, and whether it's a good buy"] = function()
		local fair = OfferWords.main(WORDS, kid(5, 5))
		expect.equal(fair.quote, '"Want to buy my Voltkit?"')
		expect.equal(fair.leftLabel, "It's worth")
		expect.equal(fair.rightLabel, "They ask")
		expect.equal(fair.delta, "A fair price.")
		expect.equal(fair.tone, "plain")
		expect.equal(fair.yes, "Buy for $5.00")
		local good = OfferWords.main(WORDS, kid(3.8, 5))
		expect.equal(good.delta, "$1.20 under its worth: a good buy!")
		expect.equal(good.tone, "good")
		local dear = OfferWords.main(WORDS, kid(5.5, 5))
		expect.equal(dear.delta, "$0.50 over its worth.")
		expect.equal(dear.tone, "bad")
		assert(string.find(fair.foot, "keep", 1, true), "what No thanks does: they keep their card")
		local unnamed = OfferWords.main(WORDS, { kind = "kid", asking = 1, worth = 1, triesLeft = 1 })
		expect.equal(unnamed.quote, '"Want to buy my card?"')
	end,

	["the counter view: a bargain hunter gives one try and says so; a kid who said no gives one more"] = function()
		local one = OfferWords.counter(WORDS, haggle(2.72, 3.25), 3, RETRIES)
		expect.equal(one.title, "Name your price")
		expect.equal(one.send, "Ask for $3.00")
		expect.equal(one.warn, true)
		assert(string.find(one.hint, "One try", 1, true), "too high and they walk away")
		local first = OfferWords.counter(WORDS, kid(5, 5), 4, RETRIES)
		expect.equal(first.title, "Your offer")
		expect.equal(first.send, "Offer $4.00")
		expect.equal(first.warn, false)
		local last = OfferWords.counter(WORDS, kid(5, 5, 1), 4, RETRIES)
		expect.equal(last.warn, true)
		expect.equal(last.hint, WORDS.kid.lastTry)
	end,

	["every word fits a child and a button: short, no symbols the fonts can't draw"] = function()
		for kind, words in WORDS :: { [string]: { [string]: string } } do
			for key, text in words do
				assert(#text <= 62, `{kind}.{key} is short`)
				assert(not string.find(text, "[\226][\156\152\136]"), `{kind}.{key}: no check marks, stars or minus signs (they draw as boxes)`)
			end
			for _, key in { "yes", "counter", "no", "send" } do
				assert(#string.format(words[key], "$999.99") <= 20, `{kind}.{key} fits its button`)
			end
		end
	end,
}
