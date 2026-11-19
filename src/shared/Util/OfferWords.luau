--!strict
-- The words on the register's offer panel (RegisterController; owner 2026-11-19: "improve bargainers offer UI to be
-- immersive and easily understandable"): the customer's ask in their own words, your price beside theirs, what the
-- difference means for you, and buttons that say what they do. Pure, Lune-tested: reads Config/Customers OFFER_WORDS
-- (passed in as `words`). Money in dollars, shown to the cent.
local OfferWords = {}

export type Offer = {
	kind: string, -- "kid" | "haggle"
	cardName: string?, -- a kid's card
	asking: number?, -- a kid's price
	worth: number?, -- what the kid's card is worth
	offer: number?, -- a bargain hunter's offer
	total: number?, -- the scanned total
	triesLeft: number,
}
export type Main = {
	title: string,
	quote: string,
	leftLabel: string,
	leftValue: string,
	rightLabel: string,
	rightValue: string,
	delta: string,
	tone: "good" | "bad" | "plain",
	yes: string,
	counter: string,
	no: string,
	foot: string,
}
export type Counter = { title: string, hint: string, warn: boolean, send: string }

function OfferWords.money(value: number): string
	return string.format("$%.2f", value)
end

local function cents(value: number): number
	return math.round(value * 100)
end

-- The panel's first view
function OfferWords.main(words: any, offer: Offer): Main
	local money = OfferWords.money
	if offer.kind == "kid" then
		local w = words.kid
		local asking, worth = offer.asking or 0, offer.worth or 0
		local gap = cents(worth) - cents(asking)
		local delta, tone: "good" | "bad" | "plain" = w.fair, "plain"
		if gap > 0 then
			delta, tone = string.format(w.under, money(gap / 100)), "good"
		elseif gap < 0 then
			delta, tone = string.format(w.over, money(-gap / 100)), "bad"
		end
		return {
			title = w.title,
			quote = string.format(w.quote, offer.cardName or w.card),
			leftLabel = w.left,
			leftValue = money(worth),
			rightLabel = w.right,
			rightValue = money(asking),
			delta = delta,
			tone = tone,
			yes = string.format(w.yes, money(asking)),
			counter = w.counter,
			no = w.no,
			foot = w.foot,
		}
	end
	local w = words.haggle
	local total, theirs = offer.total or 0, offer.offer or 0
	local less = math.max(0, cents(total) - cents(theirs))
	local percent = if total > 0 then math.round((1 - theirs / total) * 100) else 0
	return {
		title = w.title,
		quote = string.format(w.quote, money(theirs)),
		leftLabel = w.left,
		leftValue = money(total),
		rightLabel = w.right,
		rightValue = money(theirs),
		delta = string.format(w.delta, money(less / 100), percent),
		tone = "bad",
		yes = string.format(w.yes, money(theirs)),
		counter = w.counter,
		no = w.no,
		foot = w.foot,
	}
end

-- The counter view at `price`. A bargain hunter gives one try (too high and they leave); a kid who said no once says so
function OfferWords.counter(words: any, offer: Offer, price: number, retries: number): Counter
	local money = OfferWords.money
	if offer.kind == "kid" then
		local w = words.kid
		local refused = offer.triesLeft < retries + 1
		return {
			title = w.counterTitle,
			hint = if refused and offer.triesLeft == 1 then w.lastTry else w.counterHint,
			warn = refused,
			send = string.format(w.send, money(price)),
		}
	end
	local w = words.haggle
	return { title = w.counterTitle, hint = w.counterHint, warn = true, send = string.format(w.send, money(price)) }
end

return OfferWords
