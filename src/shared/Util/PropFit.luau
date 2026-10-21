--!strict
-- Prop sizing maths (main town spec), kept Roblox-free so Lune can test it. Sizes are { x, y, z } tables.
export type Size = { x: number, y: number, z: number }

local PropFit = {}

local MIN_SIZE = 0.05

-- The footprint a box takes up after turning it `yaw` degrees about the vertical axis
function PropFit.turnedSize(size: Size, yaw: number): Size
	local c, s = math.abs(math.cos(math.rad(yaw))), math.abs(math.sin(math.rad(yaw)))
	return { x = c * size.x + s * size.z, y = size.y, z = s * size.x + c * size.z }
end

-- Scale that makes a box (turned by yaw) fit inside `fit` on every axis
function PropFit.fitRatio(box: Size, fit: Size, yaw: number): number
	local turned = PropFit.turnedSize(box, yaw)
	return math.min(
		fit.x / math.max(turned.x, MIN_SIZE),
		fit.y / math.max(turned.y, MIN_SIZE),
		fit.z / math.max(turned.z, MIN_SIZE)
	)
end

-- Register counter, front (customer side) at -Z: scan items lie along the front edge, props along the back.
-- Returns the z offsets of the item row and the prop row from the counter centre.
function PropFit.counterZ(counterDepth: number, itemDepth: number, propDepth: number): (number, number)
	return -counterDepth / 2 + itemDepth / 2, counterDepth / 2 - propDepth / 2
end

return PropFit
