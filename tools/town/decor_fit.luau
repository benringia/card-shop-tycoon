--!strict
-- Which hand-placed town decor pieces (assets/town/TownDecor.rbxm: each child of its groups is a piece) stand in a
-- shop: a piece is in the way when any of its parts reaching under the roofline overlaps a shop's footprint grown by
-- `margin` (its wall). Canopies wholly over the roofline may lean over a roof. Shared by tools/town/fit_town_decor and
-- tests/TownDecorFit (spec 2026-11-23-shop-rooms-design). Lune only: @lune/roblox instances.
local TownLayout = require("../../src/shared/Util/TownLayout")

local DecorFit = {}

-- The shops' roof top over the ground: the floor's top (1) + the walls (Town.WALL_HEIGHT 18) + the roof (1)
DecorFit.ROOFLINE = 20

export type Hit = { group: string, piece: string, instance: any }

-- A part's world box on the ground (x and z) and its lowest point, from its rotation and size
local function extents(part: any): (number, number, number, number, number)
	local frame, size = part.CFrame, part.Size
	local right, up, look = frame.RightVector, frame.UpVector, frame.LookVector
	local hx = (math.abs(right.X) * size.X + math.abs(up.X) * size.Y + math.abs(look.X) * size.Z) / 2
	local hy = (math.abs(right.Y) * size.X + math.abs(up.Y) * size.Y + math.abs(look.Y) * size.Z) / 2
	local hz = (math.abs(right.Z) * size.X + math.abs(up.Z) * size.Y + math.abs(look.Z) * size.Z) / 2
	local at = frame.Position
	return at.X - hx, at.X + hx, at.Z - hz, at.Z + hz, at.Y - hy
end

-- A piece's whole box on the ground, every part at any height (where it must move from to stand clear)
function DecorFit.box(piece: any): TownLayout.Rect
	local box = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
	local parts = piece:GetDescendants()
	table.insert(parts, piece)
	for _, part in parts do
		if part:IsA("BasePart") then
			local minX, maxX, minZ, maxZ = extents(part)
			box.minX, box.maxX = math.min(box.minX, minX), math.max(box.maxX, maxX)
			box.minZ, box.maxZ = math.min(box.minZ, minZ), math.max(box.maxZ, maxZ)
		end
	end
	return box
end

function DecorFit.inTheWay(root: any, rects: { TownLayout.Rect }, margin: number, roofline: number): { Hit }
	local hits: { Hit } = {}
	for _, group in root:GetChildren() do
		for _, piece in group:GetChildren() do
			local parts = piece:GetDescendants()
			table.insert(parts, piece)
			for _, part in parts do
				if part:IsA("BasePart") then
					local minX, maxX, minZ, maxZ, bottom = extents(part)
					if bottom < roofline and TownLayout.touches({ minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }, rects, margin) then
						table.insert(hits, { group = group.Name, piece = piece.Name, instance = piece })
						break
					end
				end
			end
		end
	end
	return hits
end

return DecorFit
