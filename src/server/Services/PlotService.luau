--!strict
-- Builds the shop plots and their shells (themed walls, open front, striped awning, roof; main town spec).
-- DataService claims one per player on join and releases it on leave.
-- Other services ask PlotService.GetPlot(player) to find a player's plot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local PlotConfig = require(Config:WaitForChild("Plots"))
local Town = require(Config:WaitForChild("Town"))
local PlacementGrid = require(Shared:WaitForChild("Util"):WaitForChild("PlacementGrid"))
local PropFit = require(Shared:WaitForChild("Util"):WaitForChild("PropFit"))
local RegisterConfig = require(Config:WaitForChild("Register"))

local Props = require((script.Parent :: Instance).Parent:WaitForChild("Util"):WaitForChild("Props"))

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
	roof: Part,
	shelvesFolder: Folder,
	owner: Player?,
}

type PlotCallback = (player: Player, plot: Plot) -> ()

local PlotService = {}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}
local releasedCallbacks: { PlotCallback } = {}

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

local function getTheme(id: number)
	return Town.PLOT_THEMES[(id - 1) % #Town.PLOT_THEMES + 1]
end

-- Height of the wall tops above the plot CFrame (the floor centre)
local function wallTop(): number
	return PlotConfig.FLOOR_THICKNESS / 2 + Town.WALL_HEIGHT
end

local function shellPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A wall with a trim strip along its top and a baseboard (both a little thicker than the wall)
local function buildWall(parent: Instance, plotCFrame: CFrame, size: Vector3, offset: Vector3, wall: Color3, trim: Color3)
	local bottom = -PlotConfig.FLOOR_THICKNESS / 2
	local height = wallTop() - bottom
	shellPart(parent, "Wall", Vector3.new(size.X, height, size.Z), plotCFrame * CFrame.new(offset.X, bottom + height / 2, offset.Z), wall)
	local trimSize = Vector3.new(size.X + 0.2, Town.TRIM_HEIGHT, size.Z + 0.2)
	shellPart(parent, "Trim", trimSize, plotCFrame * CFrame.new(offset.X, wallTop() - Town.TRIM_HEIGHT / 2, offset.Z), trim)
	local baseboard = shellPart(parent, "Baseboard", trimSize, plotCFrame * CFrame.new(offset.X, PlotConfig.FLOOR_THICKNESS / 2 + Town.TRIM_HEIGHT / 2, offset.Z), trim)
	baseboard.CanCollide = false
end

-- Walls sit outside the floor edges, so the placement grid and saved layouts are unchanged. Open front.
local function buildShell(id: number, plotCFrame: CFrame, parent: Instance): Part
	local theme = getTheme(id)
	local wall, trim = Props.color(theme.wall), Props.color(theme.trim)
	local thickness = Town.WALL_THICKNESS
	local halfWidth, halfDepth = PlotConfig.WIDTH / 2, PlotConfig.DEPTH / 2
	local outerWidth = PlotConfig.WIDTH + thickness * 2
	local bottom = -PlotConfig.FLOOR_THICKNESS / 2

	buildWall(parent, plotCFrame, Vector3.new(outerWidth, 0, thickness), Vector3.new(0, 0, halfDepth + thickness / 2), wall, trim)
	for _, side in { -1, 1 } do
		buildWall(parent, plotCFrame, Vector3.new(thickness, 0, PlotConfig.DEPTH), Vector3.new(side * (halfWidth + thickness / 2), 0, 0), wall, trim)
		local pillar = Vector3.new(Town.PILLAR_SIZE, wallTop() - bottom, Town.PILLAR_SIZE)
		shellPart(parent, "Pillar", pillar, plotCFrame * CFrame.new(side * (halfWidth + thickness / 2), bottom + pillar.Y / 2, -halfDepth), trim)
	end

	-- Striped awning sloping down and out over the street from the front top edge
	local slope = math.atan2(Town.AWNING_DROP, Town.AWNING_DEPTH)
	local length = math.sqrt(Town.AWNING_DEPTH ^ 2 + Town.AWNING_DROP ^ 2)
	local stripe = outerWidth / Town.AWNING_STRIPES
	for index = 1, Town.AWNING_STRIPES do
		local x = -outerWidth / 2 + (index - 0.5) * stripe
		local color = if index % 2 == 1 then Props.color(theme.awning) else Props.color(Town.STRIPE_COLOR)
		local cframe = plotCFrame
			* CFrame.new(x, wallTop() - Town.AWNING_DROP / 2, -halfDepth - Town.AWNING_DEPTH / 2)
			* CFrame.Angles(-slope, 0, 0)
		local part = shellPart(parent, "Awning", Vector3.new(stripe, 0.3, length), cframe, color, Enum.Material.Fabric)
		part.CanCollide = false
	end

	-- The client hides this roof while you stand in the shop (TownController)
	local roofSize = Vector3.new(outerWidth, Town.ROOF_THICKNESS, PlotConfig.DEPTH + thickness)
	local roof = shellPart(parent, "Roof", roofSize, plotCFrame * CFrame.new(0, wallTop() + Town.ROOF_THICKNESS / 2, thickness / 2), Props.color(theme.roof))
	roof.CanQuery = false -- the camera never pulls in because of it
	return roof
end

-- The shop sign stands on the awning's outer lip, facing the street
local function buildSign(plotCFrame: CFrame, parent: Instance): TextLabel
	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Anchored = true
	sign.Size = PlotConfig.SIGN_SIZE
	sign.CFrame = plotCFrame
		* CFrame.new(0, wallTop() - Town.AWNING_DROP + PlotConfig.SIGN_SIZE.Y / 2, -PlotConfig.DEPTH / 2 - Town.AWNING_DEPTH)
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

-- Register faces the street like the plot; customers queue in front of it, the owner stands behind.
-- The counter part is what the shop systems use; the register and counter props sit on top of it.
local function buildRegister(id: number, plotCFrame: CFrame, parent: Instance): Part
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
	register.Color = Props.color(getTheme(id).trim)
	register.Material = Enum.Material.Wood
	register:SetAttribute("BlocksPlacement", true)
	register.Parent = parent
	addSurfaceLabel(register, PlotConfig.REGISTER_TEXT)
	-- Props go in the strip along the back edge, clear of the scan items on the front edge (RegisterService)
	local counter = Town.COUNTER
	local _, propZ = PropFit.counterZ(size.Z, RegisterConfig.ITEM_SIZE.Z, counter.PROP_DEPTH)
	local counterTop = register.CFrame * CFrame.new(0, size.Y / 2, propZ)
	local registerBox = Vector3.new(counter.REGISTER.width, counter.REGISTER.height, counter.PROP_DEPTH)
	Props.fit("Register", registerBox, counterTop * CFrame.new(counter.REGISTER.x, 0, 0), parent)
	local decorBox = Vector3.new(counter.DECOR.width, counter.DECOR.height, counter.PROP_DEPTH)
	Props.fit("CounterDecor", decorBox, counterTop * CFrame.new(counter.DECOR.x, 0, 0), parent, id)

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
		register = buildRegister(id, plotCFrame, model),
		roof = buildShell(id, plotCFrame, model),
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

-- Called by DataService when a player joins
function PlotService.Claim(player: Player)
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
	plot.floor.Color = Props.color(getTheme(plot.id).floor)
	plot.signLabel.Text = string.format(PlotConfig.OWNED_SIGN_FORMAT, player.DisplayName)
	player:SetAttribute("PlotId", plot.id)
	player.RespawnLocation = plot.spawn

	-- Already spawned in the plaza (Studio play tests), so respawn them on the plot
	if player.Character then
		player:LoadCharacter()
	end
end

-- Called by DataService after the player's data has been saved
function PlotService.Release(player: Player)
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

	for _, callback in releasedCallbacks do
		task.spawn(callback, player, plot)
	end
end

function PlotService.GetPlot(player: Player): Plot?
	return plotByPlayer[player]
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
end

return PlotService
