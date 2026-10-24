--!strict
-- Price tags on your own shelves are buttons: point at one (or tap it on a phone) and it lights up, with a
-- "Set Price" tooltip by the cursor; click it to open a small Set Price window with that product's +/- row (the same price as the
-- Prices panel). Tags belong to the shelf part they sit on, which carries the product (ProductId attribute).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))
local PricingController = require(Controllers:WaitForChild("PricingController"))

local REACH = 24 -- studs from your character a tag can be used from
local HIGHLIGHT = Color3.fromRGB(255, 255, 255)
local HINT_COLOR = Color3.fromRGB(28, 36, 66)

local player = Players.LocalPlayer

local PriceTagController = {}

local panel: Frame
local list: ScrollingFrame
local highlight: Highlight
local hint: TextLabel
local hovered: BasePart? = nil

local function getOwnShelves(): Instance?
	local plotId = player:GetAttribute("PlotId")
	if typeof(plotId) ~= "number" then
		return nil
	end
	local plots = workspace:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot" .. plotId)
	return plot and plot:FindFirstChild("Shelves")
end

-- The price tag under a screen point on your own shelves, within reach (nil if none, while a window is open,
-- or over UI)
local function tagAt(screen: Vector2): BasePart?
	if UIKit.pointerBlocked(screen) then
		return nil
	end
	local camera = workspace.CurrentCamera
	local shelves = getOwnShelves()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not shelves or not root then
		return nil
	end
	local tags = {}
	for _, item in shelves:GetDescendants() do
		if item.Name == "PriceTag" and item:IsA("BasePart") then
			table.insert(tags, item)
		end
	end
	if #tags == 0 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = tags
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if not hit then
		return nil
	end
	local tag = hit.Instance
	if (tag.Position - root.Position).Magnitude > REACH then
		return nil
	end
	return tag
end

local function setHovered(tag: BasePart?)
	if tag == hovered then
		return
	end
	hovered = tag
	highlight.Adornee = tag
	highlight.Enabled = tag ~= nil
	hint.Visible = tag ~= nil
end

local function openFor(tag: BasePart)
	local shelf = tag.Parent
	local productId = shelf and shelf:GetAttribute("ProductId")
	if typeof(productId) ~= "string" then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	PricingController.AddRow(list, 1, productId)
	panel.Visible = true
end

local function build()
	local screenGui = UIController.GetScreenGui()
	panel, list = UIKit.panel(screenGui, "SetPrice", "Set Price")
	panel.Size = UDim2.fromOffset(460, 172)
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit:Destroy()
	end

	highlight = Instance.new("Highlight")
	highlight.Name = "PriceTagHover"
	highlight.FillColor = HIGHLIGHT
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = HIGHLIGHT
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = screenGui

	-- The tooltip by the cursor (main screen, which starts below Roblox's top bar)
	hint = UIKit.label(screenGui, "🏷️ Set Price", Enum.Font.FredokaOne, 17, Color3.fromRGB(255, 250, 235))
	hint.Name = "SetPriceHint"
	hint.Size = UDim2.fromOffset(124, 34)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.BackgroundColor3 = HINT_COLOR
	hint.BackgroundTransparency = 0.05
	hint.ZIndex = 60
	hint.Visible = false
	UIKit.corner(hint, 17)
	UIKit.outline(hint, Color3.fromRGB(255, 214, 50), 2)
end

function PriceTagController.Start()
	build()
	-- Mouse: light up the tag under the pointer
	RunService.RenderStepped:Connect(function()
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		setHovered(tagAt(mouse))
		if hovered then
			local inset = game:GetService("GuiService"):GetGuiInset()
			hint.Position = UDim2.fromOffset(mouse.X + 16, mouse.Y - inset.Y + 12)
		end
	end)
	-- Click (or tap) a tag to set its price
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local isClick = input.UserInputType == Enum.UserInputType.MouseButton1
		local isTap = input.UserInputType == Enum.UserInputType.Touch
		if not isClick and not isTap then
			return
		end
		-- Touch positions start below the top bar; rays use the whole viewport
		local inset = game:GetService("GuiService"):GetGuiInset()
		local tag = if isClick then hovered else tagAt(Vector2.new(input.Position.X, input.Position.Y + inset.Y))
		if tag then
			setHovered(tag)
			openFor(tag)
		end
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible and UserInputService.TouchEnabled then
			setHovered(nil)
		end
	end)
end

return PriceTagController
