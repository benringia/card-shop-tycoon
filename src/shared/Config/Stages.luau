--!strict
-- Where the client-only stages (the binder, the card view, the pack opening) go (Util/StageRules, client
-- Util/StageSpot). Roblox keeps the world's light worked out round the camera; a stage thousands of studs up made it
-- drop the shop's, and after closing the room showed lit like the open air for ~20 s while it was worked out again
-- (owner 2026-11-06: "the room is so bright"). So each stage goes right above the player, at the first of LIFTS whose
-- box is clear of the world, and only falls back to its far STAGE_POSITION when all are blocked. Studs. Plain data,
-- read by Lune tests.
return {
	LIFTS = { 120, 160, 200 }, -- above the player's feet, lowest first
	KEEPS_LIGHT = 220, -- measured 2026-11-06: the camera 220 studs up for 15 s kept the shop's light; 400 lost it
	CLEAR_OF_TOWN = 100, -- the town's tallest pieces (gazebo, portals, trees) stay well under this
}
