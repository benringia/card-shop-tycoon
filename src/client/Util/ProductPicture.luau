--!strict
-- A product's picture on the left of a UIKit.row (Set Price, Prices, Order Stock): packs and deck boxes show their 3D
-- model (Util/PackModels, the one on the shelves and the opening stage) turned a little in a ViewportFrame, other
-- products their icon (Products icon). The row's text moves over to make room.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packs = require(Shared:WaitForChild("Config"):WaitForChild("Packs"))
local PackModels = require(Shared:WaitForChild("Util"):WaitForChild("PackModels"))

local ClientUtil = script.Parent :: Instance
local Icon = require(ClientUtil:WaitForChild("Icon"))

local FOOTPRINT = Vector2.new(38, 56) -- px, a pack's picture (the icons are 56 x 56)
local TURN_DEGREES = 22 -- the model turns this far so its side shows
local FIELD_OF_VIEW = 20
local MARGIN = 1.06 -- the model fills the picture but for this much air

local ProductPicture = {}

ProductPicture.WIDTH = 66 -- how far the row's text moves right

-- The model framed in a ViewportFrame: a camera in front of it (models face -Z) far enough back that it fits both ways
local function modelPicture(row: Frame, model: Model): ViewportFrame
	local view = Instance.new("ViewportFrame")
	view.Name = "PackModel"
	view.Size = UDim2.fromOffset(FOOTPRINT.X, FOOTPRINT.Y)
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(190, 190, 200)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-0.6, -0.8, 1)
	view.Parent = row
	model:PivotTo(CFrame.Angles(0, math.rad(TURN_DEGREES), 0))
	model.Parent = view
	local centre, size = model:GetBoundingBox()
	local halfTan = math.tan(math.rad(FIELD_OF_VIEW / 2))
	local aspect = FOOTPRINT.X / FOOTPRINT.Y
	local distance = math.max(size.Y / 2 / halfTan, size.X / 2 / (halfTan * aspect)) * MARGIN + size.Z / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = FIELD_OF_VIEW
	camera.CFrame = CFrame.lookAt(centre.Position - Vector3.new(0, 0, distance), centre.Position)
	camera.Parent = view
	view.CurrentCamera = camera
	return view
end

function ProductPicture.add(row: Frame, productId: string, iconName: string): GuiObject
	local pack = Packs.ById[productId]
	local picture: GuiObject
	if pack then
		picture = modelPicture(row, if pack.kind == "Deck" then PackModels.deckBox(productId) else PackModels.pack(productId, "High"))
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
