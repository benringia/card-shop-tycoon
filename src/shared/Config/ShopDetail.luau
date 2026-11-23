--!strict
-- How far each client draws a shop's small screens (DESIGN 10.5). Beyond these distances the engine skips them, so a
-- street full of shops stays light on phones: a full server's 594 shop screens cost 5.4 ms a frame on a PC before.
-- Plain data, read by Lune tests.
return {
	-- studs: price tags, shelf headers, machine screens and box prints stop drawing beyond this. 66 (60 until the shop
	-- rooms): the 50 x 40 hall's diagonal (64) and the front door to a room's back corner (65), not the whole building's
	-- 78, which would draw the neighbours' screens too
	SCREEN_DISTANCE = 66,
	FULL_CARD_DISTANCE = 30, -- studs: closer, a displayed card shows its full face; further, a flat picture of its art
	FLAT_BACK_COLOR = { 75, 45, 165 }, -- a displayed card's back and edges from afar (the card back's violet)
	-- Owner 2026-11-24 ("add the two fixes", after six full shops were measured against one; Util/ShopLod, client
	-- ShopLodController): another player's (or a free plot's) shop screens draw from this close instead: from the
	-- hall's middle that still reaches its farthest corner (32), and the neighbours' tags stop drawing from the street
	VISITOR_SCREEN_DISTANCE = 33,
	-- A shop's shelf stock (display boxes and packs, deck boxes, booster boxes, sleeves, bulk heaps) hides on your
	-- screen while the camera is more than STOCK_HIDE studs from the shop's floor and shows again within STOCK_SHOW
	-- (about 110k triangles a full shop); looked at every LOD_CHECK s
	STOCK_SHOW = 72,
	STOCK_HIDE = 80,
	LOD_CHECK = 0.5,
}
