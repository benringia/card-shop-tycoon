--!strict
-- The delivery boxes' models (owner 2026-11-14; tools/blender/build_delivery_props.py, Config/Products boxProp): their
-- stickers wear the product's picture. A box model has a Picture part on its front and a PictureBack on its back, each its
-- own part (a decal covers its part's whole face).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Packs = require(Config:WaitForChild("Packs"))
local ProductPictures = require(Config:WaitForChild("ProductPictures"))
local UIIcons = require(Config:WaitForChild("UIIcons"))
local ProductPictureRules = require(script.Parent:WaitForChild("ProductPictureRules"))

local DeliveryLooks = {}

local STICKER_FACES = { Picture = Enum.NormalId.Front, PictureBack = Enum.NormalId.Back }
local STICKER_PIXELS = 120
local STICKER_FILL = 0.84 -- the picture's share of the white sticker

-- What a product's sticker shows (owner 2026-11-20: "delivery boxes should use the actualy first spark model as box
-- icons"): the picture of its real model (Config/ProductPictures: the pack, the deck box, the sleeve packets, the
-- booster box), else its drawn icon
function DeliveryLooks.picture(productId: string, icon: string?): string?
	local pack = Packs.ById[productId]
	local image = ProductPictureRules.forProduct(ProductPictures, productId, if pack then pack.look else nil, if not pack then nil elseif pack.kind == "Deck" then "Deck" else "Pack")
	return image or (if icon then (UIIcons :: any)[icon] else nil)
end

-- A box model's stickers wear the product's picture, whole and unstretched on the white label (a SurfaceGui: a decal
-- would stretch a tall pack across the sticker)
function DeliveryLooks.finishBox(model: Instance, productId: string, icon: string?)
	local image = DeliveryLooks.picture(productId, icon)
	if not image then
		return
	end
	for _, part in model:GetDescendants() do
		local face = STICKER_FACES[part.Name]
		if part:IsA("BasePart") and face then
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Sticker"
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = STICKER_PIXELS
			gui.LightInfluence = 1
			gui.Parent = part
			local label = Instance.new("ImageLabel")
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.fromScale(0.5, 0.5)
			label.Size = UDim2.fromScale(STICKER_FILL, STICKER_FILL)
			label.BackgroundTransparency = 1
			label.ScaleType = Enum.ScaleType.Fit
			label.Image = image
			label.Parent = gui
		end
	end
end

return DeliveryLooks
