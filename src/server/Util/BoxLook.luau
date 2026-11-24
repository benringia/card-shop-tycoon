--!strict
-- A delivery box's look, wherever it is: on the pad and in hands (StockService) or on a storage rack (PlacementService;
-- spec 2026-11-24-storage-racks-design). The 2.5 x 1.5 x 2 hitbox Part named StockBox (the stock LOD hides what's named
-- so under a shop's Shelves: client ShopLodController) with the product's box model welded on (Products boxProp,
-- assets/props) and its stickers wearing the product's picture (Util/DeliveryLooks), else the branded case
-- (Util/BrandBox). It carries its ProductId and Units attributes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Products = require(Config:WaitForChild("Products"))
local StockConfig = require(Config:WaitForChild("Stock"))
local ShopDetail = require(Config:WaitForChild("ShopDetail"))
local Props = require(Shared:WaitForChild("Util"):WaitForChild("Props"))
local BrandBox = require(Shared:WaitForChild("Util"):WaitForChild("BrandBox"))
local DeliveryLooks = require(Shared:WaitForChild("Util"):WaitForChild("DeliveryLooks"))

local BoxLook = {}

-- `onRack`: a box standing on a storage rack keeps only its front sticker (its back faces the rack's back), drawn like
-- the shop's other screens (ShopDetail.SCREEN_DISTANCE: closer for visitors through Util/ShopLod)
function BoxLook.build(productId: string, units: number, onRack: boolean?): Part
	local product = Products.ById[productId]
	local box = Instance.new("Part")
	box.Name = "StockBox"
	box.Size = StockConfig.BOX_SIZE
	box.Color = StockConfig.BOX_COLOR
	box.Material = Enum.Material.Cardboard
	box.Anchored = true
	box:SetAttribute("ProductId", productId)
	box:SetAttribute("Units", units)
	local model = Props.weldFit(product.boxProp, box)
	if model then
		box.Transparency = 1
		DeliveryLooks.finishBox(model, product.id, product.icon)
	else
		BrandBox.draw(box, product, `x{units}`)
	end
	if onRack then
		for _, descendant in box:GetDescendants() do
			if descendant:IsA("SurfaceGui") then
				if descendant.Face == Enum.NormalId.Back then
					descendant:Destroy()
				else
					descendant.MaxDistance = ShopDetail.SCREEN_DISTANCE
				end
			end
		end
	end
	return box
end

return BoxLook
