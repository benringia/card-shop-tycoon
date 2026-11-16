--!strict
-- Tips shown the first few times (server Util/TipRules counts them, TipService saves the counts). Plain ASCII and the
-- middle dot, at most 60 letters (tests/TipRules). Plain data.
return {
	-- A bubble with Pish's face over the To Bag tile, the first 3 times you pick up a box of packs, never again once
	-- you've used To Bag (owner 2026-11-17: "make sure players know you can put packs in the bag"; mockup approved)
	TO_BAG = {
		id = "toBag",
		shows = 3,
		text = "Tap To Bag to keep these packs! Open them anywhere.",
	},

	-- The bubble's look (client Util/TileTip), as in the approved mockup: px at full HUD scale, colours as RGB
	BUBBLE = {
		size = { 300, 64 },
		gap = 26, -- from the bubble's bottom to the tile's top
		margin = 8, -- kept from the screen's edges
		corner = 18,
		back = { 255, 250, 255 },
		edge = { 196, 160, 235 },
		edgeThickness = 2.5,
		ink = { 92, 58, 120 },
		textSize = 17,
		face = 62, -- Pish's sticker (Config/HudMascot peek), over the bubble's left end
		tail = 18,
		ring = { color = { 255, 214, 90 }, thickness = 4, pad = 7, corner = 22, pulse = 0.9 },
		popSeconds = 0.25,
	},
}
