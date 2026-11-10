--!strict
-- The creature peeking over the party bar (spec 2026-11-03-hud-creature-pals-design; drawn by Util/HudMascotView,
-- timing in Util/HudMascotRules). Everything about it is here, so another creature can replace it (the owner plans one
-- based on their own pet): new pictures, sizes, eye spots, lid colour and voice, nothing else (docs/hud-mascot.md).
-- Plain data (Lune-tested).
return {
	name = "Pish",
	-- Transparent stickers (assets/ui/mascot, made with tools/ui-art/cutout.py): its head and two front paws, cut off at
	-- the paws; its tail. "" means no mascot.
	images = { peek = "rbxassetid://133179727267427", tail = "rbxassetid://118500581089750" },
	size = { peek = { 86, 63 }, tail = { 30, 31 } }, -- pixels at full HUD scale (the pictures' own shapes, 512x374 and 284x292)
	-- Its eyes on the peek picture, as shares of its width and height, for blinking
	eyes = {
		{ x = 0.297, y = 0.34, w = 0.107, h = 0.126 },
		{ x = 0.574, y = 0.34, w = 0.107, h = 0.126 },
	} :: { { x: number, y: number, w: number, h: number } },
	lid = { 232, 226, 216 }, -- the fur colour round its eyes (the blink's lids)
	crease = { 110, 95, 85 }, -- the line across a closed eye
	-- Its voice when tapped: Pish's yip (Config/Pish SOUNDS), quiet
	voice = { id = "rbxassetid://9113955748", volume = 0.3, pitch = { min = 1.6, max = 1.8 } },
	-- It peeks over the cushion's left end, where nothing sits above it (on touch screens the level pill is above the
	-- right end), so the bar keeps no room for it; raise this for a mascot that would reach something above
	headroom = 0,
	offset = { left = 6, overlap = 12 }, -- from the cushion's left end; how far its paws come down over the edge
	-- Its tap area (bounce and chirp), from the cushion's left end up from where its paws end: 48 px even at the smallest
	-- HUD scale (0.7), and over its paws so a tap there doesn't reach the Party pill underneath
	tapArea = { w = 86, h = 84 },
	clipPad = 8, -- pixels of room round the sticker, so breathing and bouncing never get cut off
	blink = { every = { 3, 7 }, seconds = 0.12 },
	breath = { period = 4, scale = 0.03 }, -- a slow swell (eased in and out)
	tilt = { period = 5.2, degrees = 1.2 }, -- a slow head tilt beside it, drawn smoothly
	-- Its tail: where its bottom sits (pixels from the cushion's left end and down from its top edge), its angle and sway
	tail = { period = 2.4, degrees = 10, angle = -30, at = { 10, 12 } },
	duck = { down = 0.15, hold = 0.35, up = 0.3 },
	tap = { seconds = 0.35, scale = 0.12 },
}
