--!strict
-- What customers say (owner 2026-11-19: "add personalities for the customers like chat bubbles"): a short speech bubble
-- over a customer at a moment of their visit, in their type's own voice (Config/Customers TYPES): the kid can't wait to
-- rip a pack, the collector is picky, the bargain hunter wants a deal, the big spender buys a lot. The server picks the
-- moment and the line (CustomerService.Say, Util/ChatRules) and the client draws it (CustomerController). Plain data,
-- Lune-tested (tests/ChatRules): plain ASCII, short enough for the bubble; a type without lines for a moment says the
-- plain customer's. `%s` in a line is the moment's own word (a bargain hunter's offer: "$2.72").
return {
	SECONDS = 3.2, -- a bubble's time on screen
	MAX_DISTANCE = 60, -- studs it's drawn from
	OFFSET_Y = 4.3, -- studs over the head (above the mood icon); a collector's is above their card bubble
	OFFSET_Y_COLLECTOR = 6.2,
	MAX_CHARS = 34,
	WIDTH = 250,
	HEIGHT = 40,
	-- How often a customer speaks at each moment (1: always). The quiet ones keep a full shop from being a wall of text
	CHANCE = {
		enter = 0.55, -- walking in
		found = 0.3, -- took something off a shelf
		pricey = 1, -- over what they'd pay
		missing = 1, -- what they wanted wasn't on any shelf
		queue = 0.35, -- joining the line
		gaveUp = 1, -- waited too long
		paid = 0.85, -- paid at the register
		haggle = 1, -- a bargain hunter's offer
		deal = 1, -- you took it (or your counter was fine)
		noDeal = 1, -- no deal: they put it all back
		admire = 1, -- stopped at a great card on display
		pet = 1, -- petting your creature
		pull = 1, -- a kid's great pull
		sell = 1, -- a kid offering their pull
		sold = 1, -- you bought it
	} :: { [string]: number },
	LINES = {
		plain = {
			enter = { "Ooh, a card shop!", "Just looking around.", "Hello there!", "What's new today?" },
			found = { "Found it!", "I'll take this one.", "This looks good!" },
			pricey = { "That's too much!", "Too pricey for me." },
			missing = { "Aw, they don't have it.", "Sold out?", "Maybe next time." },
			queue = { "Nice shop!", "Is this the line?", "Hmm hmm hmm..." },
			gaveUp = { "This takes too long!", "I can't wait any more." },
			paid = { "Thank you!", "Thanks! Bye!", "See you again!" },
			deal = { "Deal!" },
			noDeal = { "No deal? Okay, bye." },
			admire = { "Whoa! Look at that!", "What a card!" },
			pet = { "Aww, so cute!", "Who's a good pal?" },
		},
		kid = {
			enter = { "Packs! Packs! Packs!", "I saved my pocket money!", "Wow, so many cards!" },
			found = { "I want this one!", "Yesss!", "This one looks lucky!" },
			pricey = { "I don't have that much!", "Aww, too much..." },
			missing = { "Nooo, no packs?", "Aww..." },
			queue = { "Hurry, hurry!", "I can't wait to open it!", "Are we there yet?" },
			gaveUp = { "I'm bored!", "Too slow!" },
			paid = { "Time to rip it open!", "Please be a Legendary!", "Thanks a lot!" },
			admire = { "WOW! So shiny!", "I want that one!" },
			pet = { "Can I keep it?", "Hi little buddy!" },
			pull = { "WOW! Look what I got!", "No way! No way!", "Best pack ever!" },
			sell = { "Want to buy my card?", "I'll sell you this one!" },
			sold = { "Yay! More pack money!", "Thanks! Pleasure!" },
		},
		collector = {
			enter = { "I'm hunting a rare one.", "Let's see your showcase.", "Only the best for me." },
			found = { "There it is! Finally!", "A fine one." },
			pricey = { "Not at that price.", "Hmm. Overpriced." },
			missing = { "Not here. Shame.", "Still looking..." },
			queue = { "Careful with it, please.", "It goes right in my binder." },
			paid = { "My collection grows!", "Worth every coin." },
			admire = { "Magnificent!", "Now THAT is a card." },
		},
		bargain = {
			enter = { "Any deals today?", "I love a discount.", "Let's find a bargain." },
			found = { "Hmm, a bit pricey...", "I bet I can get it cheaper." },
			pricey = { "Ha! Not at that price!", "Way too much!" },
			queue = { "Let's talk price.", "Everything has a price." },
			haggle = { "How about %s?", "I'll give you %s!", "Take %s. Final offer!" },
			deal = { "Deal! Pleasure!", "Ha! What a bargain!", "You won't regret it!" },
			noDeal = { "No deal? I'm out!", "Then keep your cards!", "Too pricey for me!" },
			paid = { "I love a bargain!", "A fair price. Bye!" },
		},
		bigSpender = {
			enter = { "I'll take the good stuff.", "Money is no problem.", "Show me everything!" },
			found = { "I'll take lots!", "One of everything!", "Fill my bag!" },
			pricey = { "Even I won't pay that!" },
			queue = { "Lovely little shop.", "I'm in no rush." },
			paid = { "Keep up the good work!", "Lovely shop! Bye!", "I'll be back for more!" },
		},
	} :: { [string]: { [string]: { string } } },
}
