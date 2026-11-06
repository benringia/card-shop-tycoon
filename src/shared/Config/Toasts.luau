--!strict
-- Toasts (owner's pick A, 2026-11-06): Cindercub's speech bubbles stacked just above the cash pill, newest nearest
-- the coin, sales and messages alike (client UIController, Util/ToastRules). Plain data (colours { r, g, b }), read by
-- Lune tests. Seconds, pixels at full HUD scale.
return {
	SECONDS = 3,
	ERROR_SECONDS = 4,
	MAX = 3, -- bubbles at once; a new one past this pushes the oldest out early
	MAX_TOUCH = 2, -- landscape phones are short
	-- A bubble: white with the windows' white outline and soft lilac edge, a soft plum shadow and a tail at its
	-- bottom right; an icon chip on the left in its kind's colour, the words in its kind's ink
	WIDTH = 300, -- the most a bubble is wide before its words wrap
	TEXT = 15,
	CHIP = 28,
	ICON = 20,
	PAD = 10,
	GAP = 8, -- between bubbles (the tail sits in it)
	CORNER = 16,
	OUTLINE = 3,
	EDGE = { 240, 222, 245 },
	EDGE_THICKNESS = 2,
	SHADOW = { 91, 61, 110 },
	SHADOW_TRANSPARENCY = 0.82,
	SHADOW_OFFSET = 4,
	TAIL = 12, -- the tail's square, turned 45 degrees, half of it showing under the bubble
	TAIL_RIGHT = 22, -- from the bubble's right edge
	KINDS = {
		news = { chip = { 255, 240, 201 }, ink = { 91, 61, 110 }, icon = "Info" },
		money = { chip = { 217, 247, 223 }, ink = { 22, 112, 52 }, icon = "Coin" },
		error = { chip = { 255, 217, 223 }, ink = { 176, 40, 40 }, icon = "Close" },
	},
	-- Motion: pops up from POP.from of its size, POP.rise px lower, overshooting to POP.over then squashing to
	-- POP.squash before it settles (POP.seconds in all); leaving, it shrinks to OUT.scale and fades OUT.rise px up; the
	-- same message again bumps it to BUMP.scale
	POP = { from = 0.2, rise = 24, over = 1.1, squash = 0.96, seconds = 0.45 },
	OUT = { scale = 0.85, rise = 8, seconds = 0.25 },
	BUMP = { scale = 1.08, seconds = 0.2 },
	HOP_GAP = 1, -- the HUD's Cindercub hops at most once in this many seconds (one hop for a burst of toasts)
}
