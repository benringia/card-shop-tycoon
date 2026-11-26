--!strict
-- A card's grade you notice (owner 2026-11-26: "Make grade more noticeable in general. when pulling a card, drops, etc.
-- in the binder, highgrade cards should be highlighted too", pick A "Medal + glow" of the mockups in artifact
-- DHqTbCQGqpWaK4fTAFCbzz): the grade is a round medal on the card's top-right corner, bigger the better the grade
-- (Util/CardFace, and Util/WeaponFace's weapon cards); A cards glow blue and S cards glow gold and twinkle, everywhere the
-- card shows; a pulled A or S card says it out loud with a ding (Util/OpeningCards); a dropped one's beam takes its
-- grade's colour under a tag (Util/CardLoot). Pictures by tools/ui-art/make_grade_look.py (assets/ui/grade, uploaded,
-- not synced). Plain data (tests/GradeLook.spec), read through Shared/Util/GradeLook. Sizes are shares of the card's
-- width unless they say otherwise.
return {
	IMAGES = {
		medal = {
			C = "rbxassetid://136161675432861",
			B = "rbxassetid://138145298045458",
			A = "rbxassetid://118193587773627",
			S = "rbxassetid://73175958063334",
		},
		glow = "rbxassetid://90052590673585", -- white, a card with GLOW_PICTURE.reach round it, stretched behind one
		sparkle = "rbxassetid://123884896034644",
	},
	-- the medal's circle, bigger the better the grade (the mockup's 32 / 38 / 44 / 50 px on a 112 px card, a little
	-- smaller: it sits inside the card, which a card on a 3D surface or in a scrolling list can't draw past)
	MEDAL = { C = 0.24, B = 0.28, A = 0.32, S = 0.36 },
	INSET = 0.025, -- the circle in from the card's top and right edges
	PICTURE = 0.8, -- the circle's share of its picture (its soft shadow round it)
	NAME = { x = 0.07, gap = 0.02 }, -- the name from the card's left edge, kept this far from the medal
	LEVEL = { w = 0.22, h = 0.086, gap = 0.012 }, -- the Level chip, centred under the medal
	-- A and S cards glow: on a screen, a solid ring `width` wide round the card in `ring` and a soft glow past it in
	-- `color` at `transparency` (the mockup's box-shadow); a card on its own 3D surface (the pack opening's, a case's, a
	-- dropped one) has the ring inside its rim instead. `pulse`: seconds a breath of the glow, `breath` how much fainter
	-- it gets (0: holds still); `twinkle`: sparkles on its edges (SPARKLES)
	GLOW = {
		A = { color = { 61, 139, 255 }, ring = { 143, 186, 255 }, width = 0.027, transparency = 0.4, pulse = 0, breath = 0, twinkle = false },
		S = { color = { 255, 186, 40 }, ring = { 255, 216, 77 }, width = 0.027, transparency = 0.15, pulse = 1.6, breath = 0.3, twinkle = true },
	},
	-- the glow picture: a card with this much of its width round it on every side (make_grade_look.py GLOW_REACH),
	-- stretched behind the card (sizes as shares of the card, so a window's UIScale scales it once)
	GLOW_PICTURE = { reach = 0.25 },
	-- an S card's two sparkles twinkling on its edges (the mockup's): middles in card widths across and card heights
	-- down, sizes in card widths; a card on a 3D surface has them TWINKLE.inside in from its edges
	SPARKLES = {
		{ x = -0.027, y = 0.256, size = 0.196, delay = 0 },
		{ x = 1.054, y = 0.79, size = 0.143, delay = 0.6 },
	},
	TWINKLE = { seconds = 1.2, low = 0.6, inside = 0.03 }, -- a twinkle's length, how small it shrinks, the 3D inset
	-- a pulled A or S card (the pack opening): its words in a pill beside the rarity's banner (alone in the banner's place
	-- when there's none), popping in with a ding. Heights and gaps are shares of the screen's height
	CALLOUT = {
		words = { A = "GRADE A!", S = "GRADE S!" },
		height = 0.065,
		aspect = 3.4, -- width over height
		gap = 0.015, -- between it and the banner
		looks = {
			A = { top = { 214, 232, 255 }, bottom = { 110, 168, 255 }, ink = { 16, 46, 110 } },
			S = { top = { 255, 230, 128 }, bottom = { 245, 166, 35 }, ink = { 74, 42, 0 } },
		},
		pop = 0.35, -- seconds it pops in
	},
	-- the medal landing on a pulled A or S card: it pops from `pop` times its size with a ding (Pro Sound Effects "Synth
	-- Sparkle Tone High Pitch Bell Tone Ding 4", the opening's chime, at its volume), higher for S
	DING = { id = "rbxassetid://9126073001", volume = 0.28, pitch = { A = 1.1, S = 1.3 }, pop = 1.35 },
	-- a dropped A or S card in the Wild: its beam, ground glow, light and sparkles in its grade's colour (GLOW.color), a
	-- white tag over it edged in its ring colour, `rise` studs over the card's top
	DROP = { words = "%s · Grade %s!", ink = { A = { 31, 79, 168 }, S = { 138, 82, 0 } }, rise = 0.5 },
}
