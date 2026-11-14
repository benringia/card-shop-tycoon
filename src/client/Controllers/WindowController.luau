--!strict
-- Shop windows on the owner's screen (spec docs/superpowers/specs/2026-11-14-shop-windows-design.md; Config/Windows):
-- the window tiles in the Shop menu's Decor tab (Tiles), placing one on a wall (a see-through ghost window slides along
-- the side or back wall under the pointer, green where it fits, red with the reason where it doesn't; click or press
-- Place, Q or Cancel to stop; touch: tap the wall, then Place), and an owner-only Edit prompt on each placed window
-- (Move, or Sell for half its price). The server (WindowService) checks it all again, its refusals on the Blocked card.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Windows = require(Config:WaitForChild("Windows"))
local PlacementConfig = require(Config:WaitForChild("Placement"))
local PlotConfig = require(Config:WaitForChild("Plots"))
local Town = require(Config:WaitForChild("Town"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local WindowRules = require(Shared:WaitForChild("Util"):WaitForChild("WindowRules"))
local WindowLooks = require(Shared:WaitForChild("Util"):WaitForChild("WindowLooks"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local WindowController = {}

local PICTURE = 110 -- the tile's picture height (the Build tiles' 3D pictures)
local RAY_LENGTH = 400

type Session = {
	style: string,
	moving: number?, -- the index of the window being moved
	ghost: Model,
	highlight: Highlight,
	status: TextLabel,
	window: WindowRules.Window?,
	valid: boolean,
	reason: string?,
}

local player = Players.LocalPlayer
local session: Session? = nil
local pointer: Vector2? = nil
local bar: Frame
local placeButton: TextButton
local renderConnection: RBXScriptConnection? = nil
local editPanel: Frame
local editTitle: TextLabel
local sellButton: TextButton
local editing: number? = nil

local function ownPlot(): Model?
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

-- The windows in the owner's shop now, by index (the attributes PlotService.SetWindows puts on each model)
local function placedWindows(plot: Model): { WindowRules.Window }
	local list: { WindowRules.Window } = {}
	local folder = plot:FindFirstChild("Windows")
	if not folder then
		return list
	end
	for _, model in folder:GetChildren() do
		local index, style, side, at = model:GetAttribute("Index"), model:GetAttribute("Style"), model:GetAttribute("Side"), model:GetAttribute("At")
		if typeof(index) == "number" and typeof(style) == "string" and typeof(side) == "string" and typeof(at) == "number" then
			list[index] = { style = style, side = side, at = at }
		end
	end
	return list
end

local function achieved(styleId: string): boolean
	local keys = player:GetAttribute("DecorAchieved")
	return typeof(keys) == "string" and table.find(string.split(keys, ","), `window:{styleId}`) ~= nil
end

local function number(name: string, default: number): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function money(amount: number): string
	return (string.gsub(string.format("$%d", amount), "^(%$%d)(%d%d%d)$", "%1,%2"))
end

-- Where the pointer meets one of the shop's side or back walls: that side and the spot along it (snapped)
local function wallUnderPointer(plot: Model): (string?, number?)
	local camera = workspace.CurrentCamera
	local floor = plot:FindFirstChild("Floor")
	if not pointer or not camera or not floor or not floor:IsA("BasePart") then
		return nil, nil
	end
	local walls = {}
	for _, child in plot:GetChildren() do
		if child:IsA("BasePart") and typeof(child:GetAttribute("WallSide")) == "string" then
			table.insert(walls, child)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = walls
	local ray = camera:ScreenPointToRay(pointer.X, pointer.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
	if not hit then
		return nil, nil
	end
	local side = hit.Instance:GetAttribute("WallSide") :: string
	local here = floor.CFrame:PointToObjectSpace(hit.Position)
	return side, WindowRules.snap(Windows, if side == "back" then here.X else here.Z)
end

local function setTint(current: Session)
	local color = if current.valid then PlacementConfig.GHOST_VALID_COLOR else PlacementConfig.GHOST_INVALID_COLOR
	current.highlight.FillColor = color
	current.highlight.OutlineColor = color
	current.status.Text = if current.valid then "" elseif current.window then current.reason or "" else "Point at a side or back wall"
	placeButton.BackgroundColor3 = if current.valid then UIKit.Colors.Accent else UIKit.Colors.Row
	placeButton.TextTransparency = if current.valid then 0 else 0.5
end

local function update()
	local current = session
	local plot = ownPlot()
	if not current or not plot then
		return
	end
	local floor = plot:FindFirstChild("Floor") :: BasePart
	local side, at = wallUnderPointer(plot)
	if side and at then
		local window: WindowRules.Window = { style = current.style, side = side, at = at }
		current.window = window
		current.ghost:PivotTo(WindowLooks.cframe(floor, window, Windows, PlotConfig.WIDTH, PlotConfig.DEPTH, Town.WALL_THICKNESS))
		local ok, why = WindowRules.canPlace(Windows, placedWindows(plot), window, current.moving)
		current.valid, current.reason = ok, why
	else
		current.valid = false
	end
	setTint(current)
end

function WindowController.Cancel()
	local current = session
	if not current then
		return
	end
	current.ghost:Destroy()
	session = nil
	pointer = nil
	bar.Visible = false
	ProximityPromptService.Enabled = true
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

local function confirm()
	local current = session
	if not current then
		return
	end
	update()
	local window = current.window
	if not current.valid or not window then
		return -- the label says why
	end
	if current.moving then
		Remotes.MoveWindow:FireServer(current.moving, window.side, window.at)
	else
		Remotes.PlaceWindow:FireServer(current.style, window.side, window.at)
	end
	WindowController.Cancel()
end

-- A see-through window of `style` sliding along the walls; `moving` (an index) moves that window instead of buying one
function WindowController.Begin(style: string, moving: number?)
	local info = Windows.STYLES[style]
	if not info or not ownPlot() then
		return
	end
	WindowController.Cancel()
	local ghost = WindowLooks.build(style, info.width, info.height)
	ghost.Name = "WindowGhost"
	for _, part in ghost:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Root" then
			part.Transparency = math.max(part.Transparency, PlacementConfig.GHOST_MODEL_TRANSPARENCY)
			part.CastShadow = false
		end
	end
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = PlacementConfig.GHOST_FILL_TRANSPARENCY
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = ghost
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(240, 54)
	board.StudsOffset = Vector3.new(0, info.height / 2 + 1.2, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Parent = ghost.PrimaryPart
	local title = if moving then `Move {info.name}` else `{info.name} · {money(info.price)}`
	local name = UIKit.label(board, title, Enum.Font.FredokaOne, 20, Color3.new(1, 1, 1))
	name.Size = UDim2.fromScale(1, 0.55)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextStrokeTransparency = 0.3
	local status = UIKit.label(board, "", Enum.Font.GothamBold, 15, PlacementConfig.GHOST_INVALID_COLOR)
	status.Position = UDim2.fromScale(0, 0.55)
	status.Size = UDim2.fromScale(1, 0.45)
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextStrokeTransparency = 0.3
	ghost.Parent = workspace
	session = { style = style, moving = moving, ghost = ghost, highlight = highlight, status = status, valid = false }
	pointer = UserInputService:GetMouseLocation()
	bar.Visible = true
	ProximityPromptService.Enabled = false
	renderConnection = RunService.RenderStepped:Connect(update)
end

function WindowController.IsActive(): boolean
	return session ~= nil
end

-- The Decor tab's window tiles (after the shop looks, before the pieces): a picture of each style, its name, and its
-- price, the shop level it unlocks at, or the achievement it needs. `onPick` runs as placing starts (the Shop menu
-- closes).
function WindowController.Tiles(list: ScrollingFrame, palette: any, firstOrder: number, onPick: () -> ()): { GuiObject }
	local frames: { GuiObject } = {}
	local buttons: { [string]: TextButton } = {}
	for index, id in Windows.ORDER do
		local info = Windows.STYLES[id]
		local tile = Instance.new("Frame")
		tile.Name = "Window" .. id
		tile.LayoutOrder = firstOrder + index
		tile.BackgroundColor3 = palette.row
		tile.Parent = list
		UIKit.corner(tile, 14)
		UIKit.outline(tile)
		-- the window itself, front on, against a sky
		local view = Instance.new("ViewportFrame")
		view.Name = "Preview"
		view.Position = UDim2.fromOffset(8, 8)
		view.Size = UDim2.new(1, -16, 0, PICTURE)
		view.BackgroundColor3 = Color3.fromRGB(150, 200, 245) -- a sky behind the glass, so white frames show
		view.Ambient = Color3.fromRGB(210, 210, 210)
		view.LightDirection = Vector3.new(-1, -1, 1)
		view.Parent = tile
		UIKit.corner(view, 10)
		local model = WindowLooks.build(id, info.width, info.height)
		model.Parent = view
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		local reach = math.max(info.width, info.height)
		camera.CFrame = CFrame.lookAt(Vector3.new(reach * 0.35, reach * 0.15, -reach * 2.3), Vector3.zero)
		camera.Parent = view
		view.CurrentCamera = camera
		local name = UIKit.label(tile, info.name, Enum.Font.FredokaOne, 17, UIKit.Colors.Text)
		name.Position = UDim2.fromOffset(10, PICTURE + 12)
		name.Size = UDim2.new(1, -20, 0, 22)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextWrapped = false
		local detail = UIKit.label(tile, `Window · Decor +{info.points}`, Enum.Font.GothamBold, 13, UIKit.Colors.Subtext)
		detail.Position = UDim2.fromOffset(10, PICTURE + 34)
		detail.Size = UDim2.new(1, -20, 0, 18)
		local button = UIKit.button(tile, "", UIKit.Colors.Success)
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Position = UDim2.new(0.5, 0, 1, -8)
		button.Size = UDim2.new(1, -16, 0, 48)
		button.Font = Enum.Font.FredokaOne
		button.TextSize = 20
		button.TextWrapped = true
		button.Activated:Connect(function()
			local plot = ownPlot()
			local count = if plot then #placedWindows(plot) else 0
			local ok, why = WindowRules.canBuy(Windows, id, number("Level", 1), number("Cash", 0), info.needs == nil or achieved(id), count)
			if not ok then
				UIController.Notify(why or "You can't buy that window yet.", true)
				return
			end
			onPick()
			WindowController.Begin(id)
		end)
		buttons[id] = button
		table.insert(frames, tile)
	end
	local function refresh()
		local level, cash = number("Level", 1), number("Cash", 0)
		for id, button in buttons do
			local info = Windows.STYLES[id]
			local needs = info.needs ~= nil and not achieved(id)
			local low = not needs and level < info.level
			button.Text = if needs then `🔒 {info.how}` elseif low then `🔒 Lv {info.level}` else money(info.price)
			button.TextSize = if needs then 14 else 20
			-- Soft buttons (UIKit): mint when you can buy it, pink when you're short, grey-lilac while locked
			button.BackgroundColor3 = if needs or low then UIKit.Colors.Locked elseif cash < info.price then UIKit.Colors.Danger else UIKit.Colors.Success
		end
	end
	for _, attribute in { "Level", "Cash", "DecorAchieved" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	refresh()
	return frames
end

local function buildBar(parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = "WindowBar"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -90)
	frame.Size = UDim2.fromOffset(290, 56)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	local keys = UserInputService.KeyboardEnabled
	local buttons = {
		{ text = if keys then "✅ Place (Click)" else "✅ Place", color = UIKit.Colors.Accent, action = confirm },
		{ text = if keys then "❌ Cancel (Q)" else "❌ Cancel", color = UIKit.Colors.Danger, action = WindowController.Cancel },
	}
	for index, info in buttons do
		local button = UIKit.button(frame, info.text, info.color)
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(140, 56)
		button.TextSize = 16
		button.Activated:Connect(info.action)
		if index == 1 then
			placeButton = button
		end
	end
	return frame
end

-- The owner's small Edit window for one placed window: Move it, or Sell it for half its price
local function buildEditPanel(parent: Instance)
	local list
	editPanel, list = UIKit.panel(parent, "WindowEdit", "Window")
	editPanel.Size = UDim2.fromOffset(320, 230)
	editTitle = editPanel:FindFirstChild("Title", true) :: TextLabel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = list
	local move = UIKit.button(list, "↔️ Move", UIKit.Colors.Secondary)
	move.LayoutOrder = 1
	move.Size = UDim2.new(1, -20, 0, 52)
	move.Activated:Connect(function()
		local plot = ownPlot()
		local index = editing
		local window = if plot and index then placedWindows(plot)[index] else nil
		UIKit.closePanel(editPanel)
		if window and index then
			WindowController.Begin(window.style, index)
		end
	end)
	sellButton = UIKit.button(list, "", UIKit.Colors.Danger)
	sellButton.LayoutOrder = 2
	sellButton.Size = UDim2.new(1, -20, 0, 52)
	sellButton.Activated:Connect(function()
		if editing then
			Remotes.SellWindow:FireServer(editing)
		end
		UIKit.closePanel(editPanel)
	end)
end

local function openEdit(index: number, style: string)
	local info = Windows.STYLES[style]
	if not info then
		return
	end
	editing = index
	if editTitle then
		editTitle.Text = info.name
	end
	sellButton.Text = `💰 Sell · +{money(math.floor(info.price * Windows.SELL_REFUND))}`
	editPanel.Visible = true
end

-- An owner-only Edit prompt on each window of the owner's shop (made here, so visitors never see it)
local function watchWindows()
	local function prompts(folder: Folder)
		for _, model in folder:GetChildren() do
			local root = if model:IsA("Model") then model.PrimaryPart else nil
			local index, style = model:GetAttribute("Index"), model:GetAttribute("Style")
			if root and typeof(index) == "number" and typeof(style) == "string" and not root:FindFirstChild("EditWindow") then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "EditWindow"
				prompt.ActionText = "Edit"
				prompt.ObjectText = Windows.STYLES[style] and Windows.STYLES[style].name or "Window"
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 14
				prompt.RequiresLineOfSight = false
				prompt.Parent = root
				prompt.Triggered:Connect(function()
					openEdit(index, style)
				end)
			end
		end
	end
	-- a few times a second: a window (or its root part) can arrive a moment after its folder
	task.spawn(function()
		while true do
			local plot = ownPlot()
			local folder = if plot then plot:FindFirstChild("Windows") else nil
			if folder and folder:IsA("Folder") then
				prompts(folder)
			end
			task.wait(0.5)
		end
	end)
end

function WindowController.Start()
	local gui = UIController.GetScreenGui()
	bar = buildBar(gui)
	buildEditPanel(gui)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not session or gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
			confirm()
		elseif input.KeyCode == Enum.KeyCode.Q then
			WindowController.Cancel()
		end
	end)
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if not session or gameProcessed then
			return
		end
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	watchWindows()
end

return WindowController
