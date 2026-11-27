--!strict
-- The tutorial's cues (client Util/TutorialCues; Pish's and Chikin's). Owner 2026-11-21: "make the highlight more
-- noticeable, also make it fit the shape of what it is highlighting. also make the pawprint more noticeable"; owner
-- 2026-11-27 ("Maybe just use arrows instead of paws. to be simple", picks B and 1; spec
-- 2026-11-27-tutorial-arrows-design): arrows where the paws were. Plain data, Lune-tested (tests/CueShape; shapes:
-- Util/CueShape).
return {
	-- The gold ring round a button: `gap` px outside the button's own outline (owner 2026-11-20: "the highight border
	-- doesnt fit the tile": it stood 6 px off with a squarer corner than a tile drawn bigger on a computer),
	-- `thickness` px, with a dark `edge` px line outside it (it shows on light windows too); its corner is the
	-- button's own as drawn (`fallback` px when none is found); it pulses between the `pulse` transparencies
	RING = { gap = 2, thickness = 6, edge = 2, fallback = 14, pulse = { 0, 0.3 } },
	-- A second ring pinging outward from it: every `period` seconds it grows `grow` px and fades (from `from`
	-- transparency), `thickness` px
	PING = { period = 1.1, grow = 24, thickness = 4, from = 0.15 },
	-- The bouncing arrow (pick B, the UIIcons ArrowCue: its own white edge and dark outline): `size` px (smaller over a
	-- small button, down to `min`). `sideShare`: a target whose right edge lies within this share of the screen's width
	-- from the left (a tile in the side column: the Phone under the gift) gets its arrow on its right, pointing left,
	-- not over it (CueShape.pointerSide)
	POINTER = { size = 78, min = 48, sideShare = 0.12 },
	-- The arrows lying on the ground along the way (pick 1, the UIIcons Chevron; paw prints on the screen before): one
	-- every `gap` studs along the walking route (`max` at most), only the next `ahead` past the player, the last `fade`
	-- fading out (TrailRules.ahead); each `size` studs square, `lift` studs over the ground, drawn `pixelsPerStud` sharp
	-- and over walls and doors (a SurfaceGui AlwaysOnTop); never fainter than `dim` transparency as the glow flows
	-- toward the goal; `rotation` turns the picture on its surface so it points along the way (a Top-face picture's top
	-- edge lies along its part's -X, server Util/RegisterBuild; the part looks along the way)
	TRAIL = { gap = 3, max = 200, ahead = 12, fade = 4, size = 2.6, lift = 0.15, pixelsPerStud = 60, dim = 0.35, rotation = 90 },
	-- A thing in the world off the screen or behind the camera: its arrow waits at the screen's edge pointing the way
	-- (CueShape.offscreen), `margin` px in from the sides, between the `top` and `bottom` shares of the height (clear of
	-- the talk card, the bottom tiles and a phone's thumbstick)
	OFFSCREEN = { margin = 56, top = 0.26, bottom = 0.3 },
	-- The spotlight: `pad` px of light round the button, its hole in the button's shape
	SPOT = { pad = 8, dim = 0.45 },
	EDGE = { 44, 26, 60 }, -- the dark line outside the gold ring
}
