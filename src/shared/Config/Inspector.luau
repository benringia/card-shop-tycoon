--!strict
-- The card inspector (client only): a real 3D card in front of the camera you drag to tilt and flip.
-- Studs and degrees. See DESIGN.md section 10.6.
return {
	DISTANCE = 6, -- studs in front of the camera
	OFFSET_X = -1.4, -- the card sits left of centre; the info panel is on the right
	CARD_SIZE = Vector3.new(2.45, 3.5, 0.06),
	MAX_TILT = 35, -- degrees the card tilts while dragged
	DRAG_DEGREES_PER_PIXEL = 0.45,
	FLIP_DRAG = 110, -- dragging sideways past this many degrees flips the card
	RETURN_SPEED = 10, -- how fast it eases back (per second)
	FACE_PIXELS_PER_STUD = 220,
	FACE_BRIGHTNESS = 1.4,
	BACKDROP_COLOR = Color3.fromRGB(12, 14, 26), -- the solid sheet behind the card
	BACKDROP_GAP = 2, -- studs behind the card (in front of your character and pet)
}
