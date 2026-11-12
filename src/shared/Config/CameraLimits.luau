--!strict
-- How far players can zoom the camera out (owner 2026-11-12: "should we restrict zooming out too much on camera?";
-- Roblox's default is 128 studs, which shows the map's edges and makes phones draw far more): MAX_ZOOM studs everywhere,
-- BOSS_MAX_ZOOM in a boss fight so the big bosses fit (CameraLimitController). Plain data.
return {
	MAX_ZOOM = 40, -- the owner's pick (45 suggested)
	BOSS_MAX_ZOOM = 70,
}
