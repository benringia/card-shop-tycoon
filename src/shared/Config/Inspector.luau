--!strict
-- The card inspector (client only): a real 3D card in front of the camera you drag to tilt and flip.
-- Studs and degrees. See DESIGN.md section 10.6.
return {
	DISTANCE = 3, -- studs in front of the camera (close: nothing in the world gets in front)
	OFFSET_Y = 0.15, -- studs up, leaving room for the Flip button under the card
	MARGIN_PX = 12, -- the card's left edge stays at least this far from the screen's
	CARD_RIGHT_SHARE = 0.55, -- where the card's right edge goes until the info panel says (share of the width)
	STAGE_POSITION = Vector3.new(0, 2500, 0), -- the camera waits here while the card is up: nothing of the world near
	RIBBON_TEXT = "BEST COPY", -- on the card while your best copy is shown
	RIBBON_COLOR = Color3.fromRGB(245, 180, 40),
	CARD_SIZE = Vector3.new(1.8, 2.57, 0.03), -- about 60% of the screen's height
	MAX_TILT = 35, -- degrees the card tilts while dragged
	DRAG_DEGREES_PER_PIXEL = 0.45,
	FLIP_DRAG = 110, -- dragging sideways past this many degrees flips the card
	RETURN_SPEED = 10, -- how fast it eases back (per second)
	FACE_PIXELS_PER_STUD = 440,
	FACE_BRIGHTNESS = 1.4,
	BACKDROP_COLOR = Color3.fromRGB(12, 14, 26), -- the solid sheet behind the card
	BACKDROP_GAP = 0.4, -- studs behind the card
}
