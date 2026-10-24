--!strict
-- A product's picture on the left of a UIKit.row (Prices, Order Stock): packs show their real front (the art on
-- the shelves), other products their icon (Products icon). The row's text moves over to make room.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Packs"))

local ClientUtil = script.Parent :: Instance
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))

local ProductPicture = {}

ProductPicture.WIDTH = 66 -- how far the row's text moves right

function ProductPicture.add(row: Frame, productId: string, iconName: string): GuiObject
	local pack = Packs.ById[productId]
	local picture: GuiObject
	if pack and pack.art then
		local front = Instance.new("ImageLabel")
		front.Name = "PackArt"
		front.BackgroundColor3 = pack.color
		front.Size = UDim2.fromOffset(38, 56)
		front.Image = pack.art
		front.ScaleType = Enum.ScaleType.Crop
		front.Parent = row
		UIKit.corner(front, 6)
		UIKit.outline(front, pack.color, 2)
		picture = front
	else
		picture = Icon.make(row, iconName, UDim2.fromOffset(56, 56))
	end
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.new(0, 38, 0.5, 0)
	for _, label in row:GetChildren() do
		if label:IsA("TextLabel") then
			label.Position += UDim2.fromOffset(ProductPicture.WIDTH, 0)
			label.Size -= UDim2.fromOffset(ProductPicture.WIDTH, 0)
		end
	end
	return picture
end

return ProductPicture
