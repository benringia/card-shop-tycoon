--!strict
-- The creature peeking over the party bar (spec 2026-11-03-hud-creature-pals-design; drawn by Util/HudMascotView,
-- timing in Util/HudMascotRules). Everything about it is here, so another creature can replace it (the owner plans one
-- based on their own pet): new pictures, sizes, eye spots, lid colour and voice, nothing else (docs/hud-mascot.md).
-- Plain data (Lune-tested).
return {
	name = "Cindercub",
	-- Transparent stickers: its head and two front paws, cut off at the paws; its tail. "" until uploaded (then no mascot
	-- and no headroom).
	images = { peek = "", tail = "" },
	size = { peek = { 96, 72 }, tail = { 26, 36 } }, -- pixels at full HUD scale
	-- Its eyes on the peek picture, as shares of its width and height, for blinking
	eyes = {} :: { { x: number, y: number, w: number, h: number } },
	lid = { 220, 72, 32 }, -- the fur colour round its eyes (the blink's lids)
	-- Its chirp when tapped (Party.VOICE small chirp, Pro Sound Effects "Parakeet Chirps 8")
	voice = { id = "rbxassetid://9117237144", volume = 0.3, pitch = { min = 0.95, max = 1.15 } },
	headroom = 40, -- pixels the party bar keeps free above the cushion for its head
	offset = { right = 18, overlap = 10 }, -- from the cushion's right end; how far its paws come down over the edge
	blink = { every = { 3, 7 }, seconds = 0.12 },
	breath = { period = 3.2, scale = 0.025 },
	tail = { period = 2.4, degrees = 10 },
	duck = { down = 0.15, hold = 0.35, up = 0.3 },
	tap = { seconds = 0.35, scale = 0.12 },
}
