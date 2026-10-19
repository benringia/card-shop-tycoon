--!strict
-- Placement mode: a ghost shelf follows the pointer, snaps to the grid, and turns red where it can't go.
-- Mouse: click to place, R to rotate, Q to cancel. Touch: tap to move the ghost, then use the buttons.
-- The server runs the same PlacementGrid checks, so the ghost colour is only a preview.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Shelves = require(Config:WaitForChild("Shelves"))
local PlacementConfig = require(Config:WaitForChild("Placement"))
local PlacementGrid = require(Shared:WaitForChild("Util"):WaitForChild("PlacementGrid"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local UIKit = require((Controllers.Parent :: Instance):WaitForChild("Util"):WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

type ShelfDef = typeof(Shelves.List[1])
type Rect = PlacementGrid.Rect

type Session = {
	def: ShelfDef,
	moveUid: string?,
	rotation: number,
	gridX: number,
	gridZ: number,
	valid: boolean,
	floor: BasePart,
	blocked: { Rect },
	ghost: Part,
}

local RAY_LENGTH = 500

local player = Players.LocalPlayer

local PlacementController = {}

local session: Session? = nil
local pointer: Vector2? = nil
local bar: Frame
local renderConnection: RBXScriptConnection? = nil

local function getOwnPlot(): Model?
	local plotId = player:GetAttribute("PlotId")
	local plots = workspace:FindFirstChild("Plots")
	if typeof(plotId) ~= "number" or not plots then
		return nil
	end
	return plots:FindFirstChild("Plot" .. plotId) :: Model?
end

local function makeGhost(def: ShelfDef): Part
	local ghost = Instance.new("Part")
	ghost.Name = "PlacementGhost"
	ghost.Size = def.size
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.Transparency = PlacementConfig.GHOST_TRANSPARENCY
	ghost.Material = Enum.Material.SmoothPlastic
	ghost.Parent = workspace
	return ghost
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
	local w, d = PlacementGrid.getFootprint(current.def.size, current.rotation)
	current.gridX, current.gridZ = PlacementGrid.worldToCell(current.floor.CFrame, result.Position, w, d)
end

local function update()
	local current = session
	if not current then
		return
	end
	followPointer(current)

	local size = current.def.size
	current.ghost.CFrame = current.floor.CFrame
		* PlacementGrid.getLocalCFrame(size, current.gridX, current.gridZ, current.rotation)
	current.valid = PlacementGrid.isFree(current.blocked, size, current.gridX, current.gridZ, current.rotation)
	current.ghost.Color = if current.valid then PlacementConfig.GHOST_VALID_COLOR else PlacementConfig.GHOST_INVALID_COLOR
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
	update()
	if not current.valid then
		UIController.Notify("Can't place it there.", true)
		return
	end

	if current.moveUid then
		Remotes.MoveShelf:FireServer(current.moveUid, current.gridX, current.gridZ, current.rotation)
	else
		Remotes.PlaceShelf:FireServer(current.def.id, current.gridX, current.gridZ, current.rotation)
	end
	PlacementController.Cancel()
end

export type BeginOptions = {
	moveUid: string?,
	rotation: number?,
	gridX: number?,
	gridZ: number?,
}

-- Starts placing a new shelf, or moving an existing one when options.moveUid is set
function PlacementController.Begin(def: ShelfDef, options: BeginOptions?)
	PlacementController.Cancel()

	local plotModel = getOwnPlot()
	local floor = plotModel and plotModel:FindFirstChild("Floor") :: BasePart?
	if not plotModel or not floor then
		UIController.Notify("You don't have a shop yet.", true)
		return
	end

	local opts: BeginOptions = options or {}
	local camera = workspace.CurrentCamera
	-- New shelves start under the screen centre; moved shelves start where they are
	pointer = if opts.gridX == nil and camera then camera.ViewportSize / 2 else nil

	session = {
		def = def,
		moveUid = opts.moveUid,
		rotation = opts.rotation or 0,
		gridX = opts.gridX or 0,
		gridZ = opts.gridZ or 0,
		valid = false,
		floor = floor,
		blocked = PlacementGrid.getBlockedRects(plotModel, floor.CFrame, opts.moveUid),
		ghost = makeGhost(def),
	}
	bar.Visible = true
	update()
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
	frame.Size = UDim2.fromOffset(340, 56)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local buttons = {
		{ text = "Rotate", color = UIKit.Colors.Row, action = rotate },
		{ text = "Place", color = UIKit.Colors.Accent, action = confirm },
		{ text = "Cancel", color = UIKit.Colors.Danger, action = PlacementController.Cancel },
	}
	for index, info in buttons do
		local button = UIKit.button(frame, info.text, info.color)
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(104, 56)
		button.Activated:Connect(info.action)
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
