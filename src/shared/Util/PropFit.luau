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

-- Per-axis scale that makes a box (turned by yaw) fill `fit` exactly (stretch slots, straight parts only)
function PropFit.stretchFactors(box: Size, fit: Size, yaw: number): (number, number, number)
	local turned = PropFit.turnedSize(box, yaw)
	return fit.x / math.max(turned.x, MIN_SIZE), fit.y / math.max(turned.y, MIN_SIZE), fit.z / math.max(turned.z, MIN_SIZE)
end

-- True when every axis vector points straight along x, y or z (a part turned only in quarter turns)
function PropFit.isAxisAligned(axes: { Size }): boolean
	for _, axis in axes do
		for _, value in { axis.x, axis.y, axis.z } do
			local size = math.abs(value)
			if size > 0.01 and size < 0.99 then
				return false
			end
		end
	end
	return true
end

-- A model's own YawOffset attribute wins; otherwise the slot's turn (Town.SLOTS[slot].yaw); otherwise none
function PropFit.resolveYaw(attribute: unknown, slotYaw: number?): number
	if typeof(attribute) == "number" then
		return attribute
	end
	return slotYaw or 0
end

-- x centres for `count` scan items between spanMin and spanMax, centred, `spacing` apart or closer if they
-- would not fit (they may overlap when there are many)
function PropFit.itemXs(count: number, spanMin: number, spanMax: number, itemWidth: number, spacing: number): { number }
	local xs = {}
	if count <= 0 then
		return xs
	end
	local first, last = spanMin + itemWidth / 2, spanMax - itemWidth / 2
	local step = if count > 1 then math.min(spacing, math.max(last - first, 0) / (count - 1)) else 0
	local start = (first + last) / 2 - step * (count - 1) / 2
	for index = 1, count do
		table.insert(xs, start + (index - 1) * step)
	end
	return xs
end

-- How many copies of a model (modelWidth x modelDepth) to line up across totalWidth, and the even scale that
-- makes them fill it exactly while staying close to targetDepth deep
function PropFit.tileAcross(totalWidth: number, modelWidth: number, modelDepth: number, targetDepth: number): (number, number)
	local wanted = targetDepth / math.max(modelDepth, MIN_SIZE)
	local count = math.max(1, math.floor(totalWidth / math.max(modelWidth * wanted, MIN_SIZE) + 0.5))
	return count, totalWidth / (count * math.max(modelWidth, MIN_SIZE))
end

-- Parts a prop wants painted in its owner's colour (e.g. the awning's "COLOUR ME" union)
local TINT_NAMES = { ["COLOUR ME"] = true, ["COLOR ME"] = true, ColourMe = true, ColorMe = true, Tint = true }

function PropFit.isTintPart(name: string): boolean
	return TINT_NAMES[name] == true
end

-- Register counter, front (customer side) at -Z: scan items lie along the front edge, props along the back.
-- Returns the z offsets of the item row and the prop row from the counter centre.
function PropFit.counterZ(counterDepth: number, itemDepth: number, propDepth: number): (number, number)
	return -counterDepth / 2 + itemDepth / 2, counterDepth / 2 - propDepth / 2
end

return PropFit
