--!strict
-- Placement mode: a see-through copy of the real model (or a plain box) glides after the pointer, snaps to the
-- grid, and turns red where it can't go. Its footprint is drawn on the floor, an arrow shows its front, and a label
-- names it. Used for buying shelves and for moving shelves or fixtures (the order computer).
-- Mouse: click to place, R to rotate, Q to cancel. Touch: tap to move the ghost, then use the buttons.
-- Shop prompts are hidden while placing. The server runs the same PlacementGrid checks, so this is a preview.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local PlacementConfig = require(Config:WaitForChild("Placement"))
local PlacementGrid = require(Shared:WaitForChild("Util"):WaitForChild("PlacementGrid"))
local Props = require(Shared:WaitForChild("Util"):WaitForChild("Props"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local UIKit = require((Controllers.Parent :: Instance):WaitForChild("Util"):WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

type Rect = PlacementGrid.Rect

-- NewShelf: id is a shelf type. MoveShelf: id is the shelf's uid. MoveFixture: id is the fixture name.
export type PlacementKind = "NewShelf" | "MoveShelf" | "MoveFixture"

type Session = {
	kind: PlacementKind,
	id: string,
	size: Vector3,
	rotation: number,
	gridX: number,
	gridZ: number,
	valid: boolean,
	floor: BasePart,
	blocked: { Rect },
	ghost: Model, -- holds the hitbox box, the model copy, the footprint, the arrow and the label
	box: Part, -- the ghost's centre; the plain look when there is no model
	tinted: { Instance }, -- what turns green or red: the Highlight, the footprint, the arrow
	status: TextLabel,
	shown: CFrame?, -- where the ghost is drawn this frame (glides toward the snapped cell)
}

local RAY_LENGTH = 500

local player = Players.LocalPlayer

local PlacementController = {}

local session: Session? = nil
local pointer: Vector2? = nil
local bar: Frame
local placeButton: TextButton
local renderConnection: RBXScriptConnection? = nil

local function getOwnPlot(): Model?
	local plotId = player:GetAttribute("PlotId")
	local plots = workspace:FindFirstChild("Plots")
	if typeof(plotId) ~= "number" or not plots then
		return nil
	end
	return plots:FindFirstChild("Plot" .. plotId) :: Model?
end

local function ghostPart(parent: Instance, name: string, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

-- The cells the ghost covers, as a grid on the floor under it
local function addFootprint(ghost: Model, size: Vector3): Part
	local grid = PlacementConfig.GRID_SIZE
	local cellsX, cellsZ = math.ceil(size.X / grid - 1e-3), math.ceil(size.Z / grid - 1e-3)
	local footprint = ghostPart(ghost, "Footprint", Vector3.new(cellsX * grid, 0.05, cellsZ * grid), CFrame.new(0, -size.Y / 2 + 0.03, 0))
	footprint.Material = Enum.Material.Neon
	footprint.Transparency = PlacementConfig.FOOTPRINT_TRANSPARENCY
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = footprint
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromScale(1 / cellsX, 1 / cellsZ)
	layout.CellPadding = UDim2.new()
	layout.Parent = gui
	for _ = 1, cellsX * cellsZ do
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency = 1
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0.3
		stroke.Thickness = 2
		stroke.Parent = cell
		cell.Parent = gui
	end
	return footprint
end

-- A chevron on the floor in front of the ghost: the side customers see
local function addArrow(ghost: Model, size: Vector3): { Part }
	local arms = {}
	local front = -size.Z / 2 - 0.9
	for _, side in { -1, 1 } do
		local arm = ghostPart(ghost, "Arrow", Vector3.new(1.1, 0.06, 0.25), CFrame.new(side * 0.35, -size.Y / 2 + 0.05, front) * CFrame.Angles(0, side * math.rad(35), 0))
		arm.Material = Enum.Material.Neon
		table.insert(arms, arm)
	end
	return arms
end

local function addLabel(box: Part, size: Vector3, title: string): TextLabel
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(220, 54)
	board.StudsOffset = Vector3.new(0, size.Y / 2 + PlacementConfig.GHOST_LABEL_HEIGHT, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Parent = box
	local name = UIKit.label(board, title, Enum.Font.FredokaOne, 22, Color3.new(1, 1, 1))
	name.Size = UDim2.fromScale(1, 0.55)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextStrokeTransparency = 0.3
	local status = UIKit.label(board, "", Enum.Font.GothamBold, 16, PlacementConfig.GHOST_INVALID_COLOR)
	status.Position = UDim2.fromScale(0, 0.55)
	status.Size = UDim2.fromScale(1, 0.45)
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextStrokeTransparency = 0.3
	return status
end

-- The ghost: a see-through copy of the real model when there is one (else a plain box), its footprint, an
-- arrow for its front and a name label. Built around the origin; update() moves it.
local function makeGhost(size: Vector3, opts: BeginOptions): (Model, Part, { Instance }, TextLabel)
	local ghost = Instance.new("Model")
	ghost.Name = "PlacementGhost"
	local box = ghostPart(ghost, "Box", size, CFrame.new())
	box.Transparency = PlacementConfig.GHOST_TRANSPARENCY
	local tinted: { Instance } = { addFootprint(ghost, size) }
	for _, arm in addArrow(ghost, size) do
		table.insert(tinted, arm)
	end
	if opts.prop and Props.hasModel(opts.prop) then
		box.Transparency = 1
		local model = Props.fit(opts.prop, size, CFrame.new(0, -size.Y / 2, 0), ghost)
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CastShadow = false
				descendant.Transparency = math.max(descendant.Transparency, PlacementConfig.GHOST_MODEL_TRANSPARENCY)
				local color = opts.propColors and opts.propColors[descendant.Name]
				if color then
					descendant.Color = color
				end
			elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Light") then
				descendant:Destroy()
			end
		end
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = PlacementConfig.GHOST_FILL_TRANSPARENCY
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = model
		table.insert(tinted, highlight)
	else
		table.insert(tinted, box)
	end
	local status = addLabel(box, size, opts.title or "Place")
	ghost.PrimaryPart = box
	ghost.Parent = workspace
	return ghost, box, tinted, status
end

-- Moves the session's grid cell to wherever the pointer hits the plot floor
local function followPointer(current: Session)
	local camera = workspace.CurrentCamera
	if not pointer or not camera then
		return
	end
	local ray = camera:ScreenPointToRay(pointer.X, pointer.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { current.floor }

	local result = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
	if not result then
		return
	end
	local w, d = PlacementGrid.getFootprint(current.size, current.rotation)
	current.gridX, current.gridZ = PlacementGrid.worldToCell(current.floor.CFrame, result.Position, w, d)
end

local function update(dt: number)
	local current = session
	if not current then
		return
	end
	followPointer(current)

	local size = current.size
	local target = current.floor.CFrame * PlacementGrid.getLocalCFrame(size, current.gridX, current.gridZ, current.rotation)
	-- Glide to the snapped cell instead of jumping (frame-rate independent)
	local shown = if current.shown then current.shown:Lerp(target, math.min(1, dt * PlacementConfig.GHOST_GLIDE)) else target
	current.shown = shown
	current.ghost:PivotTo(shown)

	current.valid = PlacementGrid.isFree(current.blocked, size, current.gridX, current.gridZ, current.rotation)
	local color = if current.valid then PlacementConfig.GHOST_VALID_COLOR else PlacementConfig.GHOST_INVALID_COLOR
	for _, item in current.tinted do
		if item:IsA("Highlight") then
			item.FillColor = color
			item.OutlineColor = color
		elseif item:IsA("BasePart") then
			item.Color = color
		end
	end
	current.status.Text = if current.valid then "" else PlacementConfig.INVALID_TEXT
	placeButton.BackgroundColor3 = if current.valid then UIKit.Colors.Accent else UIKit.Colors.Row
	placeButton.TextTransparency = if current.valid then 0 else 0.5
end

function PlacementController.Cancel()
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

local function rotate()
	local current = session
	if current then
		current.rotation = (current.rotation + 1) % PlacementConfig.ROTATION_STEPS
	end
end

local function confirm()
	local current = session
	if not current then
		return
	end
	update(0)
	if not current.valid then
		UIController.Notify("Can't place it there.", true)
		return
	end

	local remote = if current.kind == "NewShelf"
		then Remotes.PlaceShelf
		elseif current.kind == "MoveShelf" then Remotes.MoveShelf
		else Remotes.MoveFixture
	remote:FireServer(current.id, current.gridX, current.gridZ, current.rotation)
	PlacementController.Cancel()
end

export type BeginOptions = {
	kind: PlacementKind,
	id: string,
	rotation: number?,
	gridX: number?,
	gridZ: number?,
	prop: string?, -- the prop slot drawn as the ghost (Config/Shelves prop, or "Computer")
	propColors: { [string]: Color3 }?,
	title: string?, -- the ghost's label, e.g. "Wall Shelf · $400" or "Move Collector Case"
}

-- Starts placement mode for something of this size: a new shelf, or moving a shelf or fixture
function PlacementController.Begin(size: Vector3, opts: BeginOptions)
	PlacementController.Cancel()

	local plotModel = getOwnPlot()
	local floor = plotModel and plotModel:FindFirstChild("Floor") :: BasePart?
	if not plotModel or not floor then
		UIController.Notify("You don't have a shop yet.", true)
		return
	end

	local camera = workspace.CurrentCamera
	-- New shelves start under the screen centre; moved things start where they are
	pointer = if opts.gridX == nil and camera then camera.ViewportSize / 2 else nil
	local ignoreId = if opts.kind == "NewShelf" then nil else opts.id

	local ghost, box, tinted, status = makeGhost(size, opts)
	session = {
		kind = opts.kind,
		id = opts.id,
		size = size,
		rotation = opts.rotation or 0,
		gridX = opts.gridX or 0,
		gridZ = opts.gridZ or 0,
		valid = false,
		floor = floor,
		blocked = PlacementGrid.getBlockedRects(plotModel, floor.CFrame, ignoreId),
		ghost = ghost,
		box = box,
		tinted = tinted,
		status = status,
		shown = nil,
	}
	bar.Visible = true
	ProximityPromptService.Enabled = false -- shop prompts would cover the ghost
	update(0)
	renderConnection = RunService.RenderStepped:Connect(update)
end

function PlacementController.IsActive(): boolean
	return session ~= nil
end

local function buildBar(parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = "PlacementBar"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -90)
	frame.Size = UDim2.fromOffset(420, 56)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	-- Key hints only where there is a keyboard
	local keys = UserInputService.KeyboardEnabled
	local buttons = {
		{ text = if keys then "🔄 Rotate (R)" else "🔄 Rotate", color = UIKit.Colors.Row, action = rotate },
		{ text = if keys then "✅ Place (Click)" else "✅ Place", color = UIKit.Colors.Accent, action = confirm },
		{ text = if keys then "❌ Cancel (Q)" else "❌ Cancel", color = UIKit.Colors.Danger, action = PlacementController.Cancel },
	}
	for index, info in buttons do
		local button = UIKit.button(frame, info.text, info.color)
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(132, 56)
		button.TextSize = 16
		button.Activated:Connect(info.action)
		if index == 2 then
			placeButton = button
		end
	end

	return frame
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if not session or gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		pointer = Vector2.new(input.Position.X, input.Position.Y)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		pointer = Vector2.new(input.Position.X, input.Position.Y)
		confirm()
	elseif input.KeyCode == Enum.KeyCode.R then
		rotate()
	elseif input.KeyCode == Enum.KeyCode.Q then
		PlacementController.Cancel()
	end
end

local function onInputChanged(input: InputObject, gameProcessed: boolean)
	if not session or gameProcessed then
		return
	end
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch then
		pointer = Vector2.new(input.Position.X, input.Position.Y)
	end
end

function PlacementController.Start()
	bar = buildBar(UIController.GetScreenGui())
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
end

return PlacementController
