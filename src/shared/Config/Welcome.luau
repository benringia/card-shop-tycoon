--!strict
-- The first-visit welcome cinematic (Portal Worlds spec): a flight past Forest Falls, Frostpeak, over the plaza and past
-- Ember Canyon, ending in front of the player's own shop; the time of day runs as a time-lapse from morning to
-- sunset, holding sunset for the last SUNSET_SHARE. Plain data, read by Lune tests (Util/WelcomePath).
-- KEYS: t (0..1 of the flight), the camera's position and where it looks; the shop's key is added at t = 1.
return {
	SECONDS = 11,
	SUNSET_SHARE = 0.5,
	KEYS = {
		{ t = 0, pos = { x = 218, y = 40, z = -82 }, look = { x = 185, y = 16, z = -150 } }, -- Forest Falls
		{ t = 0.22, pos = { x = 158, y = 46, z = 72 }, look = { x = 205, y = 36, z = 185 } }, -- Frostpeak and the aurora
		{ t = 0.45, pos = { x = 62, y = 44, z = -22 }, look = { x = 0, y = 5, z = 0 } }, -- over the plaza
		{ t = 0.68, pos = { x = -118, y = 40, z = -22 }, look = { x = -215, y = 10, z = 0 } }, -- Ember Canyon
	},
	SHOP_VIEW = { back = 32, up = 11, lookUp = 8 }, -- studs out from the shop's door, above the ground; looking at the sign
	SKIP_SIZE = { 140, 56 }, -- pixels
	STREAM_TIMEOUT = 3, -- seconds at most to wait for the scenery along the flight to stream in (all keys at once)
	BAR_SHARE = 0.09, -- the black cinema bars, share of the screen's height each
	TITLE = "Welcome to Cardshop Simulator",
	TITLE_SECONDS = { 0.6, 3.6 }, -- when the title shows
}
