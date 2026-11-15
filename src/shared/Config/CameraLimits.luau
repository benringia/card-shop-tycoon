--!strict
-- How far players can zoom the camera out (owner 2026-11-12: "should we restrict zooming out too much on camera?";
-- Roblox's default is 128 studs, which shows the map's edges and makes phones draw far more): MAX_ZOOM studs everywhere,
-- BOSS_MAX_ZOOM in a boss fight so the big bosses fit (CameraLimitController). Plain data.
return {
	MAX_ZOOM = 25, -- owner 2026-11-15 from a screenshot ("make zoomout limited to about this size"; 40 before)
	BOSS_MAX_ZOOM = 70,
}
