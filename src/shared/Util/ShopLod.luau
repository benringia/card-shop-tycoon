--!strict
-- Detail other shops drop on your screen (owner 2026-11-24: "add the two fixes", after six full shops were measured
-- against one; Config/ShopDetail, client ShopLodController, DESIGN 10.5): another player's shop screens draw from
-- closer, and a far shop's shelf stock hides. Roblox-free, Lune-tested (tests/ShopLod).
local ShopLod = {}

-- The draw distance a shop screen gets on this client, from the one the server gave it (`given`): another player's
-- shop (or a free plot) draws its shop-distance screens from VISITOR_SCREEN_DISTANCE; your own keeps the shop's, and
-- any other distance stays (signs drawn from anywhere, card faces)
function ShopLod.screenDistance(cfg: any, own: boolean, given: number): number
	if own or given ~= cfg.SCREEN_DISTANCE then
		return given
	end
	return cfg.VISITOR_SCREEN_DISTANCE
end

-- How far a point is from a plot's floor across the ground: `x`, `z` in the floor's own frame, its half width and half
-- depth; 0 over it
function ShopLod.footprintDistance(x: number, z: number, halfWidth: number, halfDepth: number): number
	local dx = math.max(math.abs(x) - halfWidth, 0)
	local dz = math.max(math.abs(z) - halfDepth, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- Whether a shop's shelf stock shows with the camera `distance` studs from its floor: within STOCK_SHOW, and once
-- `shown` until past STOCK_HIDE, so it never flickers at the edge
function ShopLod.stockShown(cfg: any, distance: number, shown: boolean): boolean
	return distance <= (if shown then cfg.STOCK_HIDE else cfg.STOCK_SHOW)
end

return ShopLod
