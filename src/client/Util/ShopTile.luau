--!strict
-- The Shop window's tiles on a phone (Config/ShopTiles, Util/ShopTileRules; pre-launch QA 2026-11-19): turns a built
-- tile (BuildController's shelves, Util/LookTiles' looks, WindowController.Tiles' windows: a picture at the top, a
-- name, a line, a button along the bottom) into a row tile, picture on the left, so it shows whole in a phone's short
-- list. The tiles are found by where their builders put them (the picture at 8, 8; the name and the line under it).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopTiles = require(Shared:WaitForChild("Config"):WaitForChild("ShopTiles"))
local ShopTileRules = require(Shared:WaitForChild("Util"):WaitForChild("ShopTileRules"))

local ShopTile = {}

local PICTURE_AT = UDim2.fromOffset(8, 8)
local NAME_Y = ShopTiles.FULL.picture + 12
local DETAIL_Y = ShopTiles.FULL.picture + 34

-- The list's grid cell: two row tiles to a row on a phone, the tall tile elsewhere
function ShopTile.cell(phone: boolean): (UDim2, UDim2)
	if phone then
		local look = ShopTiles.PHONE
		return UDim2.new(1 / look.columns, -look.gap, 0, look.height), UDim2.fromOffset(look.gap, look.gap)
	end
	local full = ShopTiles.FULL
	return UDim2.fromOffset(full.width, full.height), UDim2.fromOffset(full.gap, full.gap)
end

-- A built tile as a phone's row tile
function ShopTile.compact(tile: GuiObject)
	local row = ShopTileRules.row(ShopTiles)
	for _, child in tile:GetChildren() do
		if not child:IsA("GuiObject") then
			continue
		end
		if child:IsA("TextButton") then
			-- the button: under the words, beside the picture, finger-sized
			child.AnchorPoint = Vector2.new(1, 1)
			child.Position = UDim2.new(1, -row.margin, 1, -row.margin)
			child.Size = UDim2.new(1, -(row.beside + row.margin), 0, row.button)
		elseif child.Position == PICTURE_AT then
			child.Size = UDim2.fromOffset(row.picture, row.picture)
		elseif child:IsA("TextLabel") and child.Position.Y.Offset == NAME_Y then
			child.Position = UDim2.fromOffset(row.beside, row.nameY)
			child.Size = UDim2.new(1, -(row.beside + row.margin), 0, row.nameHeight)
			child.TextSize = ShopTiles.PHONE.nameSize
		elseif child:IsA("TextLabel") and child.Position.Y.Offset == DETAIL_Y then
			child.Position = UDim2.fromOffset(row.beside, row.detailY)
			child.Size = UDim2.new(1, -(row.beside + row.margin), 0, row.detailHeight)
			child.TextSize = ShopTiles.PHONE.detailSize
			child.TextTruncate = Enum.TextTruncate.AtEnd
			child.TextWrapped = false
		end
	end
end

return ShopTile
