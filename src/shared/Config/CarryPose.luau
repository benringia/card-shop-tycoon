--!strict
-- Carrying a box (owner 2026-11-23: "We also need a better animation for player for holding boxes"; DESIGN 4.3 "Carrying
-- a box"): the box is held in both arms in front of the belly and chest, welded to the UpperTorso (StockService) so it
-- rides the walk's sway with the body, and every client poses the carrier's arms round it (CarryPoseController: each
-- joint's Transform after the walk or idle, blended in and out) with a slight lean back under the weight. Before, the
-- box floated in front of the root while the arms swung. Plain data. Studs and degrees.
return {
	-- the box's middle from the UpperTorso's: this far down and out in front (its back against the belly)
	BOX = { down = 0.32, forward = 1.48 },
	-- the arms round it: shoulders forward and a touch in, elbows bent so the hands hold its sides; the chest leaning
	-- back a little (the waist)
	POSE = { shoulder = 48, inward = 8, elbow = 42, lean = 6 },
	EASE = 0.2, -- s to take the box up or let it go
}
