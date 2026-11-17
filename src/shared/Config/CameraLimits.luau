--!strict
-- How far players can zoom the camera out (owner 2026-11-12: "should we restrict zooming out too much on camera?";
-- Roblox's default is 128 studs, which shows the map's edges and makes phones draw far more): MAX_ZOOM studs everywhere,
-- BOSS_MAX_ZOOM in a boss fight so the big bosses fit (CameraLimitController). Plain data.
return {
	MAX_ZOOM = 25, -- owner 2026-11-15 from a screenshot ("make zoomout limited to about this size"; 40 before)
	BOSS_MAX_ZOOM = 70,
	-- A phone's camera as a fight begins (owner 2026-11-17: "When battle starts, zoom out to the max (we set this earlier
	-- around 40 something) so that players pet and boss/monster is visible on screen"; FightTouchController): out to
	-- `wild` studs in a wild fight (the max there), `boss` in a boss fight (the player can still zoom to BOSS_MAX_ZOOM), but
	-- only into open space: it stops `wallMargin` studs short of a wall behind you, and a camera already past one (zoomed
	-- out by an earlier fight) comes in to it, never nearer than `nearest` (a boss arena starts you with your back to its
	-- fence; the trees and the exit portal past it would hide the fight). A wild fight
	-- also looks down at `wildPitch` degrees (at least), your pet and the monster round you in view; a boss fight keeps
	-- the angle its intro hands back (looking down pushes the boss, 30 studs ahead, off the top of a phone's screen). With
	-- a boss's intro it waits up to `introTakes` seconds for the intro to take the camera, then up to `waitSeconds` for it
	-- to give the camera back; the zoom's floor is held `holdSeconds`
	FIGHT_ZOOM = { wild = 25, boss = 45, wildPitch = 35, wallMargin = 1.5, nearest = 12, introTakes = 3, waitSeconds = 6, holdSeconds = 0.25 },
}
