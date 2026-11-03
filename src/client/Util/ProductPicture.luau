--!strict
-- A product's picture on the left of a UIKit.row (Set Price, Prices, Order Stock): packs and deck boxes show their 3D
-- model (Util/PackModels, the one on the shelves and the opening stage) turned a little in a ViewportFrame, other
-- products their icon (Products icon). The row's text moves over to make room.
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
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

local pictures: { { view: ViewportFrame, model: Model } } = {} -- every picture built, to redraw once all has loaded
local watchWindow: (view: ViewportFrame, model: Model) -> ()

ProductPicture.WIDTH = 66 -- how far the row's text moves right

-- Puts the model back into its ViewportFrame so the picture is drawn again with what has loaded
local function redraw(view: ViewportFrame, model: Model)
	if model.Parent == view then
		model.Parent = nil
		model.Parent = view
	end
end

-- Redraws the picture a frame after any window it sits in opens (a hidden ViewportFrame doesn't draw its model). When
-- the picture goes (a shelf's Set Price row is rebuilt on every open) its watchers go and it's forgotten, so nothing
-- piles up on the windows that stay.
function watchWindow(view: ViewportFrame, model: Model)
	local connections: { RBXScriptConnection } = {}
	local item: Instance? = view.Parent
	while item and item:IsA("GuiObject") do
		local holder = item :: GuiObject
		table.insert(connections, holder:GetPropertyChangedSignal("Visible"):Connect(function()
			if holder.Visible then
				task.defer(function()
					RunService.RenderStepped:Wait()
					redraw(view, model)
				end)
			end
		end))
		item = item.Parent
	end
	view.Destroying:Once(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		for index = #pictures, 1, -1 do
			if pictures[index].view == view then
				table.remove(pictures, index)
			end
		end
	end)
end

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
	-- The menus are built at start, before the model's meshes and maps have loaded, and a ViewportFrame doesn't redraw
	-- when they arrive; nor does a model put back in while its window is hidden (round 4: the pictures stayed grey
	-- after the loading screen). So the model is put back in once it has loaded and again each time its window opens.
	table.insert(pictures, { view = view, model = model })
	task.spawn(function()
		ContentProvider:PreloadAsync({ model })
		redraw(view, model)
	end)
	watchWindow(view, model)
	return view
end

-- Puts every picture's model back into its ViewportFrame, so it redraws with whatever has loaded since
function ProductPicture.redrawAll()
	for index = #pictures, 1, -1 do
		local picture = pictures[index]
		if not picture.view.Parent then
			table.remove(pictures, index)
		else
			redraw(picture.view, picture.model)
		end
	end
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
