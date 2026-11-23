--!strict
-- A product's picture on the left of a menu row (Set Price, Prices, Order Stock): packs and deck boxes show a sharp
-- picture of the real model (round 5, spec 2026-11-04-round5-design section 6: Config/ProductPictures, rendered once
-- and uploaded), fitted with air around it; a look with no picture yet, and other products, show their icon. The row's
-- text moves over to make room.
local ContentProvider = game:GetService("ContentProvider")
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

-- The uploaded picture, fitted inside AREA with MARGIN of air on every side, over the drawn icon that shows until the
-- picture has downloaded (ProductPictureRules.showIcon: still processing, or rejected). Its fetch decides, not IsLoaded:
-- that only turns true once the window draws it, and its change signal never fires (the icon stayed over the pack). The
-- label itself is preloaded (an image id given as a string reports Failure), and only the picture's own fetch counts
-- (the icon's glyph is fetched with it).
local function picture(row: GuiObject, image: string, fallback: string, size: UDim2, iconSize: UDim2): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = "ProductPicture"
	label.BackgroundTransparency = 1
	label.Image = image
	label.ScaleType = Enum.ScaleType.Fit
	label.Size = size
	label.ZIndex = row.ZIndex + 2
	label.Parent = row
	local icon = Icon.make(label, fallback, iconSize)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.ZIndex = row.ZIndex + 1
	task.spawn(function()
		ContentProvider:PreloadAsync({ label }, function(content: string, status: Enum.AssetFetchStatus)
			if content == image then
				icon.Visible = ProductPictureRules.showIcon(status == Enum.AssetFetchStatus.Success)
			end
		end)
	end)
	return label
end

-- The picture to show for a product and the drawn icon under it: a pack's or deck box's by its look, any other
-- product's real model (sleeves, a booster box), else its drawn icon alone
local function choose(productId: string, iconName: string): (string?, string)
	local pack = Packs.ById[productId]
	if pack then
		return ProductPictureRules.pick(ProductPictures, pack.look, if pack.kind == "Deck" then "Deck" else "Pack")
	end
	return ProductPictureRules.forProduct(ProductPictures, productId, nil, nil), iconName
end

function ProductPicture.add(row: Frame, productId: string, iconName: string): GuiObject
	local image, fallback = choose(productId, iconName)
	local fit = ProductPictures.AREA - 2 * ProductPictures.MARGIN
	local iconSize = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
	local shown: GuiObject = if image then picture(row, image, fallback, UDim2.fromOffset(fit, fit), iconSize) else Icon.make(row, fallback, iconSize)
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

-- The product's picture filling `holder` (the order computer's cards and cart lines), centred, its drawn icon under it
-- until it has loaded (or alone, for a product with no picture)
function ProductPicture.fill(holder: GuiObject, productId: string, iconName: string): GuiObject
	local image, fallback = choose(productId, iconName)
	local iconSize = UDim2.fromScale(0.62, 0.62)
	local shown: GuiObject = if image then picture(holder, image, fallback, UDim2.fromScale(1, 1), iconSize) else Icon.make(holder, fallback, iconSize)
	shown.AnchorPoint = Vector2.new(0.5, 0.5)
	shown.Position = UDim2.fromScale(0.5, 0.5)
	return shown
end

return ProductPicture
