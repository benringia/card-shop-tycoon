--!strict
-- How far each client draws a shop's small screens (DESIGN 10.5). Beyond these distances the engine skips them, so a
-- street full of shops stays light on phones: a full server's 594 shop screens cost 5.4 ms a frame on a PC before.
-- Plain data, read by Lune tests.
return {
	SCREEN_DISTANCE = 60, -- studs: price tags, shelf headers, machine screens and box prints stop drawing beyond this
	FULL_CARD_DISTANCE = 30, -- studs: closer, a displayed card shows its full face; further, a flat picture of its art
	FLAT_BACK_COLOR = { 70, 110, 245 }, -- a displayed card's back and edges from afar (the card back's blue)
}
