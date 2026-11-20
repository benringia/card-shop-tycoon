--!strict
-- The tutorial's cues on screen (client Util/TutorialCues; Pish's and Chikin's). Owner 2026-11-21: "make the highlight
-- more noticeable, also make it fit the shape of what it is highlighting. also make the pawprint more noticeable".
-- Plain data, Lune-tested (tests/CueShape; shapes: Util/CueShape).
return {
	-- The gold ring round a button: `pad` px off it, `thickness` px, with a dark `edge` px line outside it (it shows
	-- on light windows too); its corner is the button's own (`fallback` px when none is found); it pulses between the
	-- `pulse` transparencies
	RING = { pad = 6, thickness = 6, edge = 2, fallback = 14, pulse = { 0, 0.3 } },
	-- A second ring pinging outward from it: every `period` seconds it grows `grow` px and fades (from `from`
	-- transparency), `thickness` px
	PING = { period = 1.1, grow = 24, thickness = 4, from = 0.15 },
	-- The bouncing paw: `size` px (smaller over a small button, down to `min`), a dark backing `back` times its size
	-- behind it and a soft gold halo `halo` times its size
	-- `sideShare`: a target whose right edge lies within this share of the screen's width from the left (a tile in the
	-- side column: the Phone under the gift) gets its paw on its right, pointing left, not over it (CueShape.pawSide)
	PAW = { size = 78, min = 48, back = 1.22, halo = 1.7, haloDim = 0.72, sideShare = 0.12 },
	-- A paw print on the ground: `px` up close (`near` studs away), down to `min` px far off; never fainter than `dim`
	-- transparency as the wave passes; the same dark backing
	PRINT = { px = 60, min = 24, near = 12, dim = 0.3 },
	-- The spotlight: `pad` px of light round the button, its hole in the button's shape
	SPOT = { pad = 8, dim = 0.45 },
	BACKING = { 60, 32, 12 }, -- the dark brown behind a gold paw
	EDGE = { 44, 26, 60 }, -- the dark line outside the gold ring
}
