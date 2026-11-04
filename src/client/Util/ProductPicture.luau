--!strict
-- A product's picture on the left of a UIKit.row (Set Price, Prices, Order Stock): packs and deck boxes show a sharp
-- picture of the real model (round 5, spec 2026-11-04-round5-design section 6: Config/ProductPictures, rendered once
-- and uploaded), fitted with air around it; a look with no picture yet, and other products, show their icon. The row's
-- text moves over to make room.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packs = require(Shared:WaitForChild("Config"):WaitForChild("Packs"))
local ProductPictures = require(Shared:WaitForChild("Config"):WaitForChild("ProductPictures"))
local ProductPictureRules = require(Shared:WaitForChild("Util"):WaitForChild("ProductPictureRules"))

local ClientUtil = script.Parent :: Instance
local Icon = require(ClientUtil:WaitForChild("Icon"))

local ICON_SIZE = 56 -- px, an icon's picture

local ProductPicture = {}

ProductPicture.WIDTH = 66 -- how far the row's text moves right

-- The uploaded picture, fitted inside AREA with MARGIN of air on every side
local function picture(row: Frame, image: string): ImageLabel
	local fit = ProductPictures.AREA - 2 * ProductPictures.MARGIN
	local label = Instance.new("ImageLabel")
	label.Name = "ProductPicture"
	label.BackgroundTransparency = 1
	label.Image = image
	label.ScaleType = Enum.ScaleType.Fit
	label.Size = UDim2.fromOffset(fit, fit)
	label.ZIndex = row.ZIndex + 1
	label.Parent = row
	return label
end

function ProductPicture.add(row: Frame, productId: string, iconName: string): GuiObject
	local pack = Packs.ById[productId]
	local shown: GuiObject
	if pack then
		local image, fallback = ProductPictureRules.pick(ProductPictures, pack.look, if pack.kind == "Deck" then "Deck" else "Pack")
		shown = if image then picture(row, image) else Icon.make(row, fallback, UDim2.fromOffset(ICON_SIZE, ICON_SIZE))
	else
		shown = Icon.make(row, iconName, UDim2.fromOffset(ICON_SIZE, ICON_SIZE))
	end
	shown.AnchorPoint = Vector2.new(0.5, 0.5)
	shown.Position = UDim2.new(0, 38, 0.5, 0)
	for _, label in row:GetChildren() do
		if label:IsA("TextLabel") then
			label.Position += UDim2.fromOffset(ProductPicture.WIDTH, 0)
			label.Size -= UDim2.fromOffset(ProductPicture.WIDTH, 0)
		end
	end
	return shown
end

return ProductPicture
