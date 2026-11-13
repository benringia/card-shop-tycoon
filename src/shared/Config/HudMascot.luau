--!strict
-- The creature peeking over the cash pill (spec 2026-11-03-hud-creature-pals-design; drawn by Util/HudMascotView,
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
	-- Where it sits (owner 2026-11-13 pick P1: "over the cash, saying the toasts"; a computer only, a phone has none):
	-- over the cash pill's top edge, behind the pill, on a seat in the corner's column. `x`: its left edge in from the
	-- seat's left edge; `overlap`: how far its paws go down behind the pill's edge
	perch = { x = 8, overlap = 12 },
	-- Its tap area (bounce and chirp: the "Support the dev" card), centred on it above the pill's top edge: 48 px even at
	-- the smallest HUD scale (0.7)
	tapArea = { w = 70, h = 70 },
	clipPad = 8, -- pixels of room round the sticker, so breathing and bouncing never get cut off
	blink = { every = { 3, 7 }, seconds = 0.12 },
	breath = { period = 4, scale = 0.03 }, -- a slow swell (eased in and out)
	tilt = { period = 5.2, degrees = 1.2 }, -- a slow head tilt beside it, drawn smoothly
	-- Its tail: where its bottom sits (pixels right of its own left edge and down from the pill's top edge, behind the
	-- pill), its angle and sway
	tail = { period = 2.4, degrees = 10, angle = -30, at = { 4, 12 } },
	duck = { down = 0.15, hold = 0.35, up = 0.3 },
	tap = { seconds = 0.35, scale = 0.12 },
}
