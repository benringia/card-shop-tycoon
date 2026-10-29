--!strict
-- The 3D binder (spec 2026-10-29-3d-binder-design.md): an open ring binder lying on a desk under lamp light, on a
-- client-only stage far above the world. Studs, degrees, seconds and pixels. The binder's own colours (case, stitch,
-- pages, chrome) stay in Config/Collection.BOOK. See DESIGN.md section 10.6.
return {
	STAGE_POSITION = Vector3.new(0, 3200, 0), -- apart from the card view's (Inspector.STAGE_POSITION): it opens from here
	FIELD_OF_VIEW = 30, -- narrow, so the far page doesn't look much smaller than the near one
	TILT = 24, -- degrees the open binder leans back from facing the camera (it lies on the desk)

	PAGE_SIZE = Vector2.new(3, 4.4), -- studs, one page
	SPINE_GAP = 0.36, -- studs between the pages (the ring rail)
	CASE_MARGIN = 0.22, -- studs of leather round the pages
	PAGE_PIXELS_PER_STUD = 160, -- a page's canvas: 480 x 704 px
	-- 2 x 2 pockets a page, big enough to read on a phone (the user's call, 2026-10-29; 3 x 3 was too small); pads
	-- and gap are fractions of the page
	POCKETS = { columns = 2, rows = 2, padX = 0.06, padY = 0.04, gap = 0.04 },
	-- Set dividers sticking out of the case's right edge (studs), top down; the open set's sticks out further. depth is
	-- the drawn tab; a tap counts over the gaps too (depth + gap, 48+ px tall on a landscape phone)
	TAB = { depth = 0.6, stickOut = 0.72, openExtra = 0.12, gap = 0.12, top = 0.3 },
	CASE_THICKNESS = 0.12,
	CASE_CORNER = 0.2, -- studs: the leather case's rounded corners
	-- studs: the dashed seam round the case, fine and faint
	STITCH = { inset = 0.1, dash = 0.1, gap = 0.07, thickness = 0.014, transparency = 0.55 },
	RAIL_WIDTH = 0.24,
	RING_RADIUS = 0.36, -- the chrome rings arch over the pages' inner edges
	RING_THICKNESS = 0.11,
	RING_SEGMENTS = 9,
	SHADOW_TRANSPARENCY_DESK = 0.35, -- the binder's soft shadow on the desk

	-- The desk and the painted lamp light (looks the same at every graphics quality: no real light needed)
	DESK_COLOR = Color3.fromRGB(138, 90, 53),
	DESK_PLANK_COLOR = Color3.fromRGB(96, 60, 34), -- the lines between planks
	DESK_PLANK_WIDTH = 1.6, -- studs
	LAMP_COLOR = Color3.fromRGB(255, 226, 170),
	LAMP_TRANSPARENCY = 0.35, -- the light pool at its brightest (over the binder)
	VIGNETTE_TRANSPARENCY = 0.6, -- the screen's edges, darkest
	BINDER_BRIGHTNESS = 1.3, -- the binder's own surfaces (case, pages and their cards, tabs, a turning page) lit by the lamp
	BACKDROP_COLOR = Color3.fromRGB(22, 15, 10),

	-- Turning a page: a chain of strips bending as it goes over the rings
	STRIPS = 4, -- fewer strips: fewer SurfaceGuis to redraw each frame of a turn (6 cost a 55 ms frame at low graphics)
	TURN_SECONDS = 0.5,
	BEND_DEGREES = 40, -- how far the outer edge leads the spine side mid-turn
	MAX_SPEEDUP = 4, -- turns this many times faster when many are asked for at once
	HOLD_REPEAT = 0.18, -- seconds between turns while a page key is held
	DRAG_EDGE = 0.3, -- share of a page's width at its outer edge where a press grabs the page
	FINISH_SPEED = 1.5, -- turn progress per second that finishes a released drag (or flicks it back)
	SWIPE_PIXELS = 60,
	TAP_PIXELS = 10,
	TAP_SECONDS = 0.35,
	TURN_SHADE = 0.55, -- how dark a page gets standing up (0 none, 1 black)
	SHADOW_TRANSPARENCY = 0.5, -- the turning page's shadow on the page under it, at its darkest
	TURN_SOUND_ID = "95995953662374", -- "Book Page Turn 12" (Creator Store, free, 0.7 s); "" plays none
	TURN_SOUND_VOLUME = 0.5,

	LIFT_SECONDS = 0.3, -- a picked card flying out of its sleeve toward the camera
	LIFT_SCREEN_SHARE = 0.6, -- it ends in the middle of the screen, this share of its height (any pocket stays whole)
}
