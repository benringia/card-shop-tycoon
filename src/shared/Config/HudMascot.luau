--!strict
-- The creature peeking over the party bar (spec 2026-11-03-hud-creature-pals-design; drawn by Util/HudMascotView,
-- timing in Util/HudMascotRules). Everything about it is here, so another creature can replace it (the owner plans one
-- based on their own pet): new pictures, sizes, eye spots, lid colour and voice, nothing else (docs/hud-mascot.md).
-- Plain data (Lune-tested).
return {
	name = "Cindercub",
	-- Transparent stickers (assets/ui/mascot, made with tools/ui-art/cutout.py): its head and two front paws, cut off at
	-- the paws; its tail. "" means no mascot.
	images = { peek = "rbxassetid://76268668069671", tail = "rbxassetid://72530681377183" },
	size = { peek = { 72, 69 }, tail = { 26, 36 } }, -- pixels at full HUD scale (the pictures' own shapes, 512x490 and 224x311)
	-- Its eyes on the peek picture, as shares of its width and height, for blinking
	eyes = {
		{ x = 0.271, y = 0.531, w = 0.104, h = 0.114 },
		{ x = 0.605, y = 0.529, w = 0.105, h = 0.116 },
	} :: { { x: number, y: number, w: number, h: number } },
	lid = { 222, 74, 51 }, -- the fur colour round its eyes (the blink's lids)
	-- Its chirp when tapped (Party.VOICE small chirp, Pro Sound Effects "Parakeet Chirps 8")
	voice = { id = "rbxassetid://9117237144", volume = 0.3, pitch = { min = 0.95, max = 1.15 } },
	-- It peeks over the cushion's left end, where nothing sits above it (on touch screens the level pill is above the
	-- right end), so the bar keeps no room for it; raise this for a mascot that would reach something above
	headroom = 0,
	offset = { left = 6, overlap = 12 }, -- from the cushion's left end; how far its paws come down over the edge
	blink = { every = { 3, 7 }, seconds = 0.12 },
	breath = { period = 3.2, scale = 0.025 },
	tail = { period = 2.4, degrees = 10 },
	duck = { down = 0.15, hold = 0.35, up = 0.3 },
	tap = { seconds = 0.35, scale = 0.12 },
}
