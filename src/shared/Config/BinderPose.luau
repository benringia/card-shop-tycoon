--!strict
-- Reading your binder in the world (owner 2026-11-13: "Opening the binder should also show the character opening a
-- binder, so that other players know you are opening a binder", "like reading a book"; pose and binder only, no icon).
-- While a player's binder is open (player attribute ReadingBinder, set by BinderReadService), every client poses their
-- arms forward round a small open binder held at chest height and tips their head down (BinderPoseController), the
-- binder in the real binder's colours (Config/Collection BOOK), a page turning now and then. Plain data.
return {
	EASE = 0.3, -- seconds: the arms come up as it opens and go down as it closes
	-- Degrees, at full weight: shoulders forward, a little inward, elbows bent, the head tipped down
	POSE = { shoulder = 30, inward = 20, elbow = 75, neck = 18 },
	-- The binder held in front of the chest (studs, from the upper torso; degrees it leans back toward the face): two
	-- covers open in a shallow V, pages on them, rings at the spine
	BOOK = {
		forward = 1.45,
		down = 0.05,
		lean = 38,
		cover = { 1.05, 1.4, 0.07 }, -- one cover's width, height, thickness
		open = 18, -- degrees each cover tilts up from flat
		page = { 0.96, 1.28, 0.04 },
		-- the cards in its pockets, four a page, shuffled, in their rarities' colours (Config/Rarities)
		cardRarities = { "Legendary", "Epic", "Very Rare", "Rare", "Legendary", "Epic", "Very Rare", "Rare" },
		rings = 3,
		ring = 0.13,
	},
	FLIP = { every = { 3.5, 7 }, seconds = 0.5 }, -- a page turning over, now and then
	RANGE = 70, -- studs from the camera: closer players are posed and their pages turn
	COOLDOWN = 0.25, -- seconds between "opened" messages a player's client may send (closing is never limited)
}
