--!strict
-- What your own shelves hold, only when you want it: point at a shelf or the order computer (or tap it on a phone)
-- and it gets a soft outline, with a tooltip by the cursor showing its Info attribute (product and stock, a card
-- case's count, "Order Stock"), and an "Empty" badge floats over any product shelf with nothing on it so you can
-- spot it across the shop. PlacementService (shelves) and PlotService (the computer) set Info; Empty is shelves only.
-- Visitors see neither. Price tags keep their own "Set Price" tooltip (PriceTagController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))
local PlacementConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Placement"))

local TIP_COLOR = Color3.fromRGB(28, 36, 66)
local TIP_TEXT = Color3.fromRGB(255, 250, 235)
local EMPTY_COLOR = Color3.fromRGB(225, 70, 60)
local HOVER_COLOR = Color3.fromRGB(255, 255, 255)
local TIP_PADDING = 12 -- pixels each side of the tooltip text

local player = Players.LocalPlayer

local ShelfInfoController = {}

local tip: TextLabel
local highlight: Highlight
local tipUntil = 0 -- a tap's tooltip stays up until this time
local watched: { [BasePart]: boolean } = {}

local function getOwnPlot(): Instance?
	local plotId = player:GetAttribute("PlotId")
	if typeof(plotId) ~= "number" then
		return nil
	end
	local plots = workspace:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot" .. plotId)
end

local function getOwnShelves(): Instance?
	local plot = getOwnPlot()
	return plot and plot:FindFirstChild("Shelves")
end

-- The part carrying the Info attribute (a shelf, or the computer) that owns a hit part
local function shelfOf(hit: Instance, plot: Instance): BasePart?
	local current: Instance? = hit
	while current and current ~= plot do
		if current:IsA("BasePart") and current:GetAttribute("Info") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Your shelf (or computer) under a screen point, within reach (nil over a price tag: that has its own tooltip,
-- and nil while a window is open or the point is over UI)
local function shelfAt(screen: Vector2): BasePart?
	if UIKit.pointerBlocked(screen) then
		return nil
	end
	local camera = workspace.CurrentCamera
	local plot = getOwnPlot()
	local shelves = plot and plot:FindFirstChild("Shelves")
	local computer = plot and plot:FindFirstChild("OrderComputer", true)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not plot or not shelves or not root then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = if computer then { shelves, computer } else { shelves }
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if not hit or hit.Instance.Name == "PriceTag" then
		return nil
	end
	local shelf = shelfOf(hit.Instance, plot)
	if not shelf or (shelf.Position - root.Position).Magnitude > PlacementConfig.SHELF_INFO.REACH then
		return nil
	end
	return shelf
end

-- The outline goes on the model drawn on the part (shelves with props have an invisible hitbox part)
local function outline(shelf: BasePart?)
	local target: Instance? = shelf and (shelf:FindFirstChildOfClass("Model") or shelf)
	if highlight.Adornee ~= target then
		highlight.Adornee = target
	end
	highlight.Enabled = target ~= nil
end

local function showTip(shelf: BasePart?, screen: Vector2)
	local info = shelf and shelf:GetAttribute("Info")
	if typeof(info) ~= "string" then
		tip.Visible = false
		outline(nil)
		return
	end
	outline(shelf)
	tip.Text = info
	local inset = GuiService:GetGuiInset()
	tip.Position = UDim2.fromOffset(screen.X + 16, screen.Y - inset.Y + 12)
	tip.Visible = true
end

-- The floating "Empty" badge over one of your shelves, shown while its Empty attribute is true
local function watchShelf(shelf: Instance)
	if not shelf:IsA("BasePart") or watched[shelf] then
		return
	end
	watched[shelf] = true
	local look = PlacementConfig.SHELF_INFO
	local board = Instance.new("BillboardGui")
	board.Name = "EmptyBadge"
	board.Size = UDim2.fromOffset(96, 30)
	-- Out past the shelf's front (its own space, so it follows moves): a wall behind it can't cut through the badge
	board.StudsOffsetWorldSpace = Vector3.new(0, shelf.Size.Y / 2 + look.EMPTY_GAP, -(shelf.Size.Z / 2 + look.EMPTY_FORWARD))
	board.MaxDistance = look.EMPTY_MAX_DISTANCE
	board.LightInfluence = 0
	local badge = UIKit.label(board, "📦 Empty", Enum.Font.FredokaOne, 16, Color3.new(1, 1, 1))
	badge.Size = UDim2.fromScale(1, 1)
	badge.TextXAlignment = Enum.TextXAlignment.Center
	badge.BackgroundColor3 = EMPTY_COLOR
	badge.BackgroundTransparency = 0.05
	UIKit.corner(badge, 15)
	UIKit.outline(badge, Color3.new(1, 1, 1), 2)
	board.Adornee = shelf
	board.Parent = shelf
	local function refresh()
		board.Enabled = shelf:GetAttribute("Empty") == true
	end
	refresh()
	shelf:GetAttributeChangedSignal("Empty"):Connect(refresh)
	shelf.Destroying:Connect(function()
		watched[shelf] = nil
	end)
end

-- Watch whichever Shelves folder is yours (you get a plot after joining)
local function watchPlot()
	local shelves = getOwnShelves()
	if not shelves then
		return
	end
	for _, shelf in shelves:GetChildren() do
		watchShelf(shelf)
	end
	shelves.ChildAdded:Connect(watchShelf)
end

function ShelfInfoController.Start()
	tip = UIKit.label(UIController.GetScreenGui(), "", Enum.Font.FredokaOne, 16, TIP_TEXT)
	tip.Name = "ShelfInfoTip"
	tip.TextXAlignment = Enum.TextXAlignment.Center
	tip.TextWrapped = false
	tip.Size = UDim2.fromOffset(0, 34)
	tip.AutomaticSize = Enum.AutomaticSize.X -- as wide as its text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, TIP_PADDING)
	padding.PaddingRight = UDim.new(0, TIP_PADDING)
	padding.Parent = tip
	tip.BackgroundColor3 = TIP_COLOR
	tip.BackgroundTransparency = 0.05
	tip.ZIndex = 60
	tip.Visible = false
	UIKit.corner(tip, 17)
	UIKit.outline(tip, Color3.fromRGB(150, 170, 230), 2)

	highlight = Instance.new("Highlight")
	highlight.Name = "ShelfHover"
	highlight.FillColor = HOVER_COLOR
	highlight.FillTransparency = 0.85
	highlight.OutlineColor = HOVER_COLOR
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = UIController.GetScreenGui()

	watchPlot()
	player:GetAttributeChangedSignal("PlotId"):Connect(watchPlot)

	-- Mouse: the shelf under the pointer
	RunService.RenderStepped:Connect(function()
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			if os.clock() > tipUntil then
				tip.Visible = false
				outline(nil)
			end
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		showTip(shelfAt(mouse), mouse)
	end)
	-- Touch: tap a shelf to see its tooltip for a moment
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		-- Touch positions start below the top bar; rays and showTip use the whole viewport, like the mouse
		local screen = Vector2.new(input.Position.X, input.Position.Y + GuiService:GetGuiInset().Y)
		local shelf = shelfAt(screen)
		if shelf then
			showTip(shelf, screen)
			tipUntil = os.clock() + PlacementConfig.SHELF_INFO.TAP_SECONDS
		end
	end)
end

return ShelfInfoController
