--!strict
-- Builds the shop plots and assigns one to each player on join, releasing it on leave.
-- Other services ask PlotService.GetPlot(player) to find a player's plot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlotConfig = require(Shared:WaitForChild("Config"):WaitForChild("Plots"))
local PlacementGrid = require(Shared:WaitForChild("Util"):WaitForChild("PlacementGrid"))

local COMPUTER_FIXTURE_ID = "OrderComputer"

export type Plot = {
	id: number,
	model: Model,
	floor: Part,
	signLabel: TextLabel,
	spawn: SpawnLocation,
	computer: Part,
	deliverySpot: Part,
	register: Part,
	shelvesFolder: Folder,
	owner: Player?,
}

type PlotCallback = (player: Player, plot: Plot) -> ()

local PlotService = {}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}
local claimedCallbacks: { PlotCallback } = {}
local releasedCallbacks: { PlotCallback } = {}

local function runCallbacks(callbacks: { PlotCallback }, player: Player, plot: Plot)
	for _, callback in callbacks do
		task.spawn(callback, player, plot)
	end
end

-- Plot CFrame sits at the floor centre with LookVector pointing at the street (the shop front)
local function getPlotCFrame(index: number): CFrame
	local row = (index - 1) // PlotConfig.PER_ROW
	local col = (index - 1) % PlotConfig.PER_ROW
	local side = if row == 0 then -1 else 1

	local x = (col - (PlotConfig.PER_ROW - 1) / 2) * (PlotConfig.WIDTH + PlotConfig.GAP)
	local z = side * (PlotConfig.STREET_WIDTH + PlotConfig.DEPTH) / 2
	local center = Vector3.new(x, PlotConfig.FLOOR_THICKNESS / 2, z)

	return CFrame.lookAt(center, center + Vector3.new(0, 0, -side))
end

local function addSurfaceLabel(part: Part, text: string): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = PlotConfig.SIGN_TEXT_COLOR
	label.Text = text
	label.Parent = gui

	return label
end

local function buildSign(plotCFrame: CFrame, parent: Instance): TextLabel
	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Anchored = true
	sign.Size = PlotConfig.SIGN_SIZE
	sign.CFrame = plotCFrame * CFrame.new(0, PlotConfig.SIGN_HEIGHT, -PlotConfig.DEPTH / 2)
	sign.Color = PlotConfig.SIGN_COLOR
	sign.Parent = parent

	return addSurfaceLabel(sign, PlotConfig.FREE_SIGN_TEXT)
end

-- Snaps the computer to a grid cell. Attributes let the owner's client start a move from here.
local function setComputerCell(computer: Part, plotCFrame: CFrame, gridX: number, gridZ: number, rotation: number)
	computer.CFrame = plotCFrame * PlacementGrid.getLocalCFrame(computer.Size, gridX, gridZ, rotation)
	computer:SetAttribute("GridX", gridX)
	computer:SetAttribute("GridZ", gridZ)
	computer:SetAttribute("Rotation", rotation)
end

local function buildComputer(plotCFrame: CFrame, parent: Instance): Part
	local computer = Instance.new("Part")
	computer.Name = COMPUTER_FIXTURE_ID
	computer.Anchored = true
	computer.Size = PlotConfig.COMPUTER_SIZE
	computer.Color = PlotConfig.COMPUTER_COLOR
	computer:SetAttribute("BlocksPlacement", true)
	computer:SetAttribute("FixtureId", COMPUTER_FIXTURE_ID)
	setComputerCell(computer, plotCFrame, PlotConfig.COMPUTER_GRID_X, PlotConfig.COMPUTER_GRID_Z, 0)
	computer.Parent = parent

	addSurfaceLabel(computer, PlotConfig.COMPUTER_TEXT)
	return computer
end

local function buildDeliverySpot(plotCFrame: CFrame, parent: Instance): Part
	local size = PlotConfig.DELIVERY_PAD_SIZE
	local pad = Instance.new("Part")
	pad.Name = "DeliverySpot"
	pad.Anchored = true
	pad.CanCollide = false
	pad.Size = size
	pad.CFrame = plotCFrame
		* CFrame.new(
			-PlotConfig.WIDTH / 2 + PlotConfig.DELIVERY_INSET,
			(PlotConfig.FLOOR_THICKNESS + size.Y) / 2,
			-PlotConfig.DEPTH / 2 + PlotConfig.DELIVERY_INSET
		)
	pad.Color = PlotConfig.DELIVERY_COLOR
	pad:SetAttribute("BlocksPlacement", true)
	pad.Parent = parent
	return pad
end

-- Register faces the street like the plot; customers queue in front of it, the owner stands behind
local function buildRegister(plotCFrame: CFrame, parent: Instance): Part
	local size = PlotConfig.REGISTER_SIZE
	local register = Instance.new("Part")
	register.Name = "Register"
	register.Anchored = true
	register.Size = size
	register.CFrame = plotCFrame
		* CFrame.new(
			-PlotConfig.WIDTH / 2 + PlotConfig.REGISTER_SIDE_INSET,
			(PlotConfig.FLOOR_THICKNESS + size.Y) / 2,
			PlotConfig.DEPTH / 2 - PlotConfig.REGISTER_BACK_INSET
		)
	register.Color = PlotConfig.REGISTER_COLOR
	register.Material = Enum.Material.Wood
	register:SetAttribute("BlocksPlacement", true)
	register.Parent = parent
	addSurfaceLabel(register, PlotConfig.REGISTER_TEXT)

	-- Keeps shelves out of the customer queue line
	local zone = Instance.new("Part")
	zone.Name = "QueueZone"
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.Transparency = 1
	zone.Size = Vector3.new(PlotConfig.QUEUE_ZONE_WIDTH, 0.2, PlotConfig.QUEUE_ZONE_LENGTH)
	zone.CFrame = register.CFrame
		* CFrame.new(0, -size.Y / 2, -(size.Z + PlotConfig.QUEUE_ZONE_LENGTH) / 2)
	zone:SetAttribute("BlocksPlacement", true)
	zone.Parent = parent

	return register
end

-- Invisible pad used as the owner's RespawnLocation. Turned 180° so they face into the shop.
local function buildSpawn(plotCFrame: CFrame, parent: Instance): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "OwnerSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Size = PlotConfig.SPAWN_PAD_SIZE
	spawn.CFrame = plotCFrame
		* CFrame.new(0, 0, -PlotConfig.DEPTH / 2 + PlotConfig.SPAWN_INSET)
		* CFrame.Angles(0, math.pi, 0)
	spawn:SetAttribute("BlocksPlacement", true)
	spawn.Parent = parent
	return spawn
end

local function buildPlot(id: number, folder: Folder): Plot
	local plotCFrame = getPlotCFrame(id)

	local model = Instance.new("Model")
	model.Name = "Plot" .. id
	model:SetAttribute("PlotId", id)
	model:SetAttribute("OwnerUserId", 0)

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(PlotConfig.WIDTH, PlotConfig.FLOOR_THICKNESS, PlotConfig.DEPTH)
	floor.CFrame = plotCFrame
	floor.Color = PlotConfig.FREE_COLOR
	floor.Material = Enum.Material.WoodPlanks
	floor.Parent = model
	model.PrimaryPart = floor

	local shelvesFolder = Instance.new("Folder")
	shelvesFolder.Name = "Shelves"
	shelvesFolder.Parent = model

	local plot: Plot = {
		id = id,
		model = model,
		floor = floor,
		signLabel = buildSign(plotCFrame, model),
		spawn = buildSpawn(plotCFrame, model),
		computer = buildComputer(plotCFrame, model),
		deliverySpot = buildDeliverySpot(plotCFrame, model),
		register = buildRegister(plotCFrame, model),
		shelvesFolder = shelvesFolder,
		owner = nil,
	}
	model.Parent = folder
	return plot
end

local function findFreePlot(): Plot?
	for _, plot in plots do
		if plot.owner == nil then
			return plot
		end
	end
	return nil
end

local function claim(player: Player)
	if plotByPlayer[player] then
		return
	end

	local plot = findFreePlot()
	if not plot then
		warn(`[PlotService] No free plot for {player.Name}. Set Max Players to {PlotConfig.COUNT}.`)
		return
	end

	plot.owner = player
	plotByPlayer[player] = plot
	plot.model:SetAttribute("OwnerUserId", player.UserId)
	plot.floor.Color = PlotConfig.OWNED_COLOR
	plot.signLabel.Text = string.format(PlotConfig.OWNED_SIGN_FORMAT, player.DisplayName)
	player:SetAttribute("PlotId", plot.id)
	player.RespawnLocation = plot.spawn

	-- Already spawned in the plaza (Studio play tests), so respawn them on the plot
	if player.Character then
		player:LoadCharacter()
	end

	runCallbacks(claimedCallbacks, player, plot)
end

local function release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end

	plotByPlayer[player] = nil
	plot.owner = nil
	plot.model:SetAttribute("OwnerUserId", 0)
	plot.floor.Color = PlotConfig.FREE_COLOR
	plot.signLabel.Text = PlotConfig.FREE_SIGN_TEXT
	-- The next owner gets the default layout
	setComputerCell(plot.computer, plot.floor.CFrame, PlotConfig.COMPUTER_GRID_X, PlotConfig.COMPUTER_GRID_Z, 0)

	runCallbacks(releasedCallbacks, player, plot)
end

function PlotService.GetPlot(player: Player): Plot?
	return plotByPlayer[player]
end

-- Register before PlotService.Start() so no claim is missed
function PlotService.OnClaimed(callback: PlotCallback)
	table.insert(claimedCallbacks, callback)
end

function PlotService.OnReleased(callback: PlotCallback)
	table.insert(releasedCallbacks, callback)
end

function PlotService.GetPlots(): { Plot }
	return plots
end

PlotService.COMPUTER_FIXTURE_ID = COMPUTER_FIXTURE_ID

-- Moves the order computer. PlacementService validates the spot first.
function PlotService.SetComputerCell(plot: Plot, gridX: number, gridZ: number, rotation: number)
	setComputerCell(plot.computer, plot.floor.CFrame, gridX, gridZ, rotation)
end

function PlotService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = workspace

	for id = 1, PlotConfig.COUNT do
		table.insert(plots, buildPlot(id, folder))
	end

	Players.PlayerAdded:Connect(claim)
	Players.PlayerRemoving:Connect(release)
	-- Players who joined before this ran (common in Studio play tests)
	for _, player in Players:GetPlayers() do
		claim(player)
	end
end

return PlotService
