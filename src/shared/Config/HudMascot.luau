--!strict
-- The creature peeking over the party bar (spec 2026-11-03-hud-creature-pals-design; drawn by Util/HudMascotView,
-- timing in Util/HudMascotRules). Everything about it is here, so another creature can replace it (the owner plans one
-- based on their own pet): new pictures, sizes, eye spots, lid colour and voice, nothing else (docs/hud-mascot.md).
-- Plain data (Lune-tested).
return {
	-- Pish as he is: furrowed brows and his underbite, a little grumpy (owner 2026-11-10)
	name = "Pish",
	-- Transparent stickers (assets/ui/mascot, made with tools/ui-art/cutout.py): its head and two front paws, cut off at
	-- the paws; its tail. "" means no mascot.
	images = { peek = "rbxassetid://125657246581399", tail = "rbxassetid://102206389239561" },
	-- pixels at full HUD scale (the pictures' own shapes, 512x405 and 322x333); a little smaller since the owner
	-- 2026-11-11 ("make pish a little smaller here on the UI"; it was 86x68 and 30x31)
	size = { peek = { 70, 55 }, tail = { 25, 26 } },
	-- Its eyes on the peek picture, as shares of its width and height, for blinking
	eyes = {
		{ x = 0.289, y = 0.36, w = 0.127, h = 0.116 },
		{ x = 0.584, y = 0.356, w = 0.117, h = 0.121 },
	} :: { { x: number, y: number, w: number, h: number } },
	lid = { 222, 214, 204 }, -- the fur colour round its eyes (the blink's lids)
	crease = { 110, 95, 85 }, -- the line across a closed eye
	-- Its voice when tapped: Pish's yip (Config/Pish SOUNDS), quiet
	voice = { id = "rbxassetid://9113955748", volume = 0.3, pitch = { min = 1.6, max = 1.8 } },
	-- It peeks over the cushion's left end, where nothing sits above it (on touch screens the level pill is above the
	-- right end), so the bar keeps no room for it; raise this for a mascot that would reach something above
	headroom = 0,
	-- Which end of the party bar it sits on (owner 2026-11-12: "move pish's icon to the right side of the party UI, then
	-- make the bubble come out of him"; HudMascotRules.side): the right on a PC, where the toasts come out of it; the left
	-- on a touch screen, where the level pill sits over the right end. `seat`: px kept free at the cushion's right end for
	-- it, clear of the third card. `offset`: left, from the cushion's left end (past your face, Party.BAR.HIT 70 px);
	-- right, its right edge in from the bar's right end; overlap, how far its paws come down over the edge
	sides = { pc = "right", touch = "left" },
	seat = 64,
	offset = { left = 76, right = 6, overlap = 12 },
	-- Its tap area (bounce and chirp), from the cushion's left end up from where its paws end: 48 px even at the smallest
	-- HUD scale (0.7), and over its paws so a tap there doesn't reach the Party pill underneath
	tapArea = { w = 86, h = 84 },
	clipPad = 8, -- pixels of room round the sticker, so breathing and bouncing never get cut off
	blink = { every = { 3, 7 }, seconds = 0.12 },
	breath = { period = 4, scale = 0.03 }, -- a slow swell (eased in and out)
	tilt = { period = 5.2, degrees = 1.2 }, -- a slow head tilt beside it, drawn smoothly
	-- Its tail: where its bottom sits (pixels right of its own left edge and down from the cushion's top edge), its angle
	-- and sway
	tail = { period = 2.4, degrees = 10, angle = -30, at = { 4, 12 } },
	duck = { down = 0.15, hold = 0.35, up = 0.3 },
	tap = { seconds = 0.35, scale = 0.12 },
}
