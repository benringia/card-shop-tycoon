--!strict
-- The town's moving extras (Portal Worlds spec): tree sway, the frame watchdog that turns the extras off on a slow
-- device, and the town's animals (CRITTERS). All client side. Plain data, read by Lune tests. Studs and seconds.
return {
	-- Trees near the camera lean gently in the wind (TreeSwayController): canopies only, a few times a second
	SWAY = {
		RANGE = 150, -- studs from the camera
		HZ = 30, -- updates a second
		ANGLE = 0.025, -- radians at the most
		SPEED = 1.3,
		SCAN_SECONDS = 2, -- trees streaming in or out are picked up this often
	},
	-- Extras switch off after SLOW_SECONDS of frames slower than SLOW_FRAME (smoothed over SMOOTH_SECONDS) and back on
	-- after FAST_SECONDS faster than FAST_FRAME; a single frame over MAX_FRAME (a loading hitch) is ignored. A graphics
	-- level the player set at or below LOW_QUALITY also turns them off (Roblox doesn't say what "Automatic" picked).
	WATCHDOG = {
		SLOW_FRAME = 1 / 45,
		SLOW_SECONDS = 3,
		FAST_FRAME = 1 / 55,
		FAST_SECONDS = 10,
		SMOOTH_SECONDS = 0.25,
		MAX_FRAME = 1,
		LOW_QUALITY = 3,
	},
	BUTTERFLY_RANGE = 120, -- studs: flocks further from the camera stand still
}
