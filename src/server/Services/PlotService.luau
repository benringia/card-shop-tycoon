--!strict
-- Builds the shop plots and their modern shells (white walls, glass front with sliding doors, sign band, flat
-- roof; main town spec).
-- DataService claims one per player on join and releases it on leave.
-- Other services ask PlotService.GetPlot(player) to find a player's plot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local PlotConfig = require(Config:WaitForChild("Plots"))
local Town = require(Config:WaitForChild("Town"))
local PlacementGrid = require(Shared:WaitForChild("Util"):WaitForChild("PlacementGrid"))
local PropFit = require(Shared:WaitForChild("Util"):WaitForChild("PropFit"))
local RegisterConfig = require(Config:WaitForChild("Register"))

local Props = require(Shared:WaitForChild("Util"):WaitForChild("Props"))

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

-- Height of the glass shop front's top above the plot CFrame (the sign band runs above it)
local function frontTop(): number
	return PlotConfig.FLOOR_THICKNESS / 2 + Town.AWNING_HEIGHT
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

-- Decoration that never blocks the camera, clicks or paths
local function trimPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = shellPart(parent, name, size, cframe, color, material)
	part.CanCollide = false
	part.CanQuery = false
	return part
end

-- A smooth white wall with the charcoal band along its outside foot
local function buildWall(parent: Instance, plotCFrame: CFrame, size: Vector3, offset: Vector3, outward: Vector3)
	local look = Town.SHOP
	local bottom = -PlotConfig.FLOOR_THICKNESS / 2
	local height = wallTop() - bottom
	shellPart(parent, "Wall", Vector3.new(size.X, height, size.Z), plotCFrame * CFrame.new(offset.X, bottom + height / 2, offset.Z), Props.color(look.WALL))
	local band = Vector3.new(size.X + math.abs(outward.X) * 0.1, look.BASE_HEIGHT, size.Z + math.abs(outward.Z) * 0.1)
	trimPart(parent, "BaseBand", band, plotCFrame * CFrame.new(offset + outward * 0.05 + Vector3.new(0, bottom + look.BASE_HEIGHT / 2 - offset.Y, 0)), Props.color(look.CHARCOAL))
end

-- Sliding glass doors: two panels that part when anyone (players or customers) comes near. They never collide,
-- so nothing is ever stuck behind them; the panes beside them are the solid wall.
local function buildDoors(parent: Instance, plotCFrame: CFrame)
	local look = Town.SHOP
	local z = -PlotConfig.DEPTH / 2 - Town.WALL_THICKNESS / 2
	local floorTop = PlotConfig.FLOOR_THICKNESS / 2
	local half = look.DOOR_WIDTH / 2
	local glass, frame = Props.color(look.GLASS), Props.color(look.FRAME)
	local panels = {}
	for _, side in { -1, 1 } do
		local closed = plotCFrame * CFrame.new(side * half / 2, floorTop + look.DOOR_HEIGHT / 2, z)
		local panel = trimPart(parent, "DoorGlass", Vector3.new(half, look.DOOR_HEIGHT, 0.2), closed, glass, Enum.Material.Glass)
		panel.Transparency = look.GLASS_TRANSPARENCY
		-- A thin frame round each panel, and a long bar handle by the middle
		local edge = Instance.new("SelectionBox")
		edge.Adornee = panel
		edge.Color3 = frame
		edge.LineThickness = 0.08
		edge.SurfaceTransparency = 1
		edge.Parent = panel
		local handle = trimPart(parent, "DoorHandle", Vector3.new(0.15, 3.5, 0.15), closed * CFrame.new(-side * (half / 2 - 0.6), 0, -0.25), frame, Enum.Material.Metal)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = panel
		weld.Part1 = handle
		weld.Parent = panel
		handle.Anchored = false
		table.insert(panels, { part = panel, closed = closed, open = closed * CFrame.new(side * (half - 0.4), 0, 0.35) })
	end
	-- Door head: the frame bar over the doorway
	trimPart(parent, "DoorHead", Vector3.new(look.DOOR_WIDTH + look.MULLION * 2, look.MULLION, 0.6), plotCFrame * CFrame.new(0, floorTop + look.DOOR_HEIGHT, z), frame, Enum.Material.Metal)

	local centre = (plotCFrame * CFrame.new(0, floorTop + 3, z)).Position
	local sense = OverlapParams.new()
	sense.FilterType = Enum.RaycastFilterType.Include
	local isOpen = false
	local info = TweenInfo.new(look.DOOR_OPEN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.spawn(function()
		-- The plot is built first and put in the world after, so wait for it
		while not parent:IsDescendantOf(workspace) do
			task.wait(0.5)
		end
		while parent:IsDescendantOf(workspace) do
			-- Anyone's root part within reach of the doorway, on either side
			local roots = {}
			for _, model in workspace:GetChildren() do
				local root = model:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					table.insert(roots, root)
				end
			end
			local customers = workspace:FindFirstChild("Customers")
			if customers then
				for _, model in customers:GetChildren() do
					local root = model:FindFirstChild("HumanoidRootPart")
					if root then
						table.insert(roots, root)
					end
				end
			end
			local near = false
			for _, root in roots do
				if ((root :: BasePart).Position - centre).Magnitude <= look.DOOR_SENSE then
					near = true
					break
				end
			end
			if near ~= isOpen then
				isOpen = near
				for _, panel in panels do
					TweenService:Create(panel.part, info, { CFrame = if near then panel.open else panel.closed }):Play()
				end
			end
			task.wait(0.15)
		end
	end)
end

-- The glass shop front: black-framed panes each side of the sliding doors, up to the sign band
local function buildStorefront(parent: Instance, plotCFrame: CFrame, outerWidth: number)
	local look = Town.SHOP
	local z = -PlotConfig.DEPTH / 2 - Town.WALL_THICKNESS / 2
	local floorTop = PlotConfig.FLOOR_THICKNESS / 2
	local bottom = -PlotConfig.FLOOR_THICKNESS / 2
	local height = frontTop() - bottom
	local glass, frame = Props.color(look.GLASS), Props.color(look.FRAME)
	local doorHalf = look.DOOR_WIDTH / 2
	local sideWidth = outerWidth / 2 - doorHalf
	for _, side in { -1, 1 } do
		local paneWidth = sideWidth / look.PANES
		for index = 1, look.PANES do
			local x = side * (doorHalf + (index - 0.5) * paneWidth)
			local pane = shellPart(parent, "ShopWindow", Vector3.new(paneWidth, height, 0.3), plotCFrame * CFrame.new(x, bottom + height / 2, z), glass, Enum.Material.Glass)
			pane.Transparency = look.GLASS_TRANSPARENCY
			pane.CastShadow = false
		end
		-- Uprights between the panes and at the door jambs
		for index = 0, look.PANES do
			local x = side * (doorHalf + index * paneWidth)
			trimPart(parent, "Mullion", Vector3.new(look.MULLION, height, 0.6), plotCFrame * CFrame.new(x, bottom + height / 2, z), frame, Enum.Material.Metal)
		end
		-- A transom bar across the panes at door height, and the sill
		local midX = side * (doorHalf + sideWidth / 2)
		trimPart(parent, "Transom", Vector3.new(sideWidth, look.MULLION, 0.6), plotCFrame * CFrame.new(midX, floorTop + look.DOOR_HEIGHT, z), frame, Enum.Material.Metal)
		trimPart(parent, "Sill", Vector3.new(sideWidth, look.BASE_HEIGHT * 0.6, 0.7), plotCFrame * CFrame.new(midX, floorTop + look.BASE_HEIGHT * 0.3, z), Props.color(look.CHARCOAL))
	end
	-- Glass over the doors up to the sign band
	local over = frontTop() - (floorTop + look.DOOR_HEIGHT)
	local fanlight = shellPart(parent, "ShopWindow", Vector3.new(look.DOOR_WIDTH, over, 0.3), plotCFrame * CFrame.new(0, floorTop + look.DOOR_HEIGHT + over / 2, z), glass, Enum.Material.Glass)
	fanlight.Transparency = look.GLASS_TRANSPARENCY
	fanlight.CanCollide = false
	buildDoors(parent, plotCFrame)
end

-- A slim flat canopy over the doors with small down-lights, and a planter each side of the doorway
local function buildEntrance(parent: Instance, plotCFrame: CFrame)
	local look = Town.SHOP
	local front = -PlotConfig.DEPTH / 2 - Town.WALL_THICKNESS
	local floorTop = PlotConfig.FLOOR_THICKNESS / 2
	local width = look.DOOR_WIDTH + 6
	local y = floorTop + look.DOOR_HEIGHT + 0.8
	trimPart(parent, "Canopy", Vector3.new(width, 0.4, Town.AWNING_DEPTH), plotCFrame * CFrame.new(0, y, front - Town.AWNING_DEPTH / 2), Props.color(look.CANOPY), Enum.Material.Metal)
	for _, x in { -width / 2 + 2, 0, width / 2 - 2 } do
		local lamp = trimPart(parent, "CanopyLight", Vector3.new(0.8, 0.1, 0.8), plotCFrame * CFrame.new(x, y - 0.25, front - Town.AWNING_DEPTH / 2), Props.color(look.CANOPY_LIGHT), Enum.Material.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Color = lamp.Color
		light.Range = 12
		light.Angle = 70
		light.Brightness = 1.2
		light.Parent = lamp
	end
	for _, side in { -1, 1 } do
		local x = side * (look.DOOR_WIDTH / 2 + look.PLANTER_OFFSET)
		local at = plotCFrame * CFrame.new(x, floorTop, front - 1.4)
		trimPart(parent, "Planter", Vector3.new(look.PLANTER_SIZE, 2.6, look.PLANTER_SIZE), at * CFrame.new(0, 1.3, 0), Props.color(look.PLANTER), Enum.Material.Concrete)
		local leaves = trimPart(parent, "PlanterLeaves", Vector3.new(2.6, 3.4, 2.6), at * CFrame.new(0, 4.1, 0), Props.color(look.LEAVES), Enum.Material.Grass)
		leaves.Shape = Enum.PartType.Ball
	end
end

-- Modern LED ceiling panels in rows, so the shop is evenly bright
local function buildCeilingLights(plotCFrame: CFrame, parent: Instance)
	local look = Town.SHOP
	local color = Props.color(look.PANEL)
	for _, z in look.PANEL_ROWS do
		for _, x in look.PANEL_COLS do
			local panel = trimPart(parent, "CeilingLight", Vector3.new(look.PANEL_SIZE[1], 0.15, look.PANEL_SIZE[2]), plotCFrame * CFrame.new(x, wallTop() - 0.08, z), color, Enum.Material.Neon)
			if z == 0 then
				local light = Instance.new("SurfaceLight")
				light.Face = Enum.NormalId.Bottom
				light.Color = color
				light.Range = look.PANEL_RANGE
				light.Angle = 110
				light.Brightness = look.PANEL_BRIGHTNESS
				light.Parent = panel
			end
		end
	end
end

-- The modern shell: white walls with a charcoal foot, a glass shop front with sliding doors, a charcoal sign
-- band with a strip in the shop's accent colour, a flat roof with a slim edge, a greige feature wall and LED panels.
-- Walls sit outside the floor edges, so the placement grid and saved layouts are unchanged.
local function buildShell(id: number, plotCFrame: CFrame, parent: Instance): Part
	local look = Town.SHOP
	local theme = getTheme(id)
	local accent = Props.color(theme.accent)
	local charcoal = Props.color(look.CHARCOAL)
	local thickness = Town.WALL_THICKNESS
	local halfWidth, halfDepth = PlotConfig.WIDTH / 2, PlotConfig.DEPTH / 2
	local outerWidth = PlotConfig.WIDTH + thickness * 2
	local floorTop = PlotConfig.FLOOR_THICKNESS / 2

	buildWall(parent, plotCFrame, Vector3.new(outerWidth, 0, thickness), Vector3.new(0, 0, halfDepth + thickness / 2), Vector3.new(0, 0, 1))
	for _, side in { -1, 1 } do
		buildWall(parent, plotCFrame, Vector3.new(thickness, 0, PlotConfig.DEPTH), Vector3.new(side * (halfWidth + thickness / 2), 0, 0), Vector3.new(side, 0, 0))
	end
	-- Feature wall: the back wall's inside face in a warm greige (the same in every shop)
	trimPart(parent, "FeatureWall", Vector3.new(PlotConfig.WIDTH, Town.WALL_HEIGHT - 1, 0.1), plotCFrame * CFrame.new(0, floorTop + (Town.WALL_HEIGHT - 1) / 2, halfDepth - 0.05), Props.color(look.FEATURE_WALL))

	buildStorefront(parent, plotCFrame, outerWidth)
	-- Sign band: charcoal from the top of the glass to the roof edge, with a glowing accent strip under it
	local band = wallTop() - frontTop()
	shellPart(parent, "FrontWall", Vector3.new(outerWidth, band, thickness), plotCFrame * CFrame.new(0, frontTop() + band / 2, -halfDepth - thickness / 2), charcoal)
	trimPart(parent, "AccentStrip", Vector3.new(outerWidth, look.ACCENT_STRIP, 0.2), plotCFrame * CFrame.new(0, frontTop() + look.ACCENT_STRIP / 2, -halfDepth - thickness - 0.1), accent, Enum.Material.Neon)
	buildEntrance(parent, plotCFrame)

	-- Flat roof: the camera stays under it inside the shop; a slim charcoal parapet round the edge
	local roofSize = Vector3.new(outerWidth, Town.ROOF_THICKNESS, PlotConfig.DEPTH + thickness * 2)
	local roof = shellPart(parent, "Roof", roofSize, plotCFrame * CFrame.new(0, wallTop() + Town.ROOF_THICKNESS / 2, 0), Props.color(look.CEILING))
	local top = wallTop() + Town.ROOF_THICKNESS + look.PARAPET / 2
	for _, z in { -1, 1 } do
		trimPart(parent, "Parapet", Vector3.new(outerWidth + 0.4, look.PARAPET, 0.6), plotCFrame * CFrame.new(0, top, z * (halfDepth + thickness)), charcoal)
	end
	for _, x in { -1, 1 } do
		trimPart(parent, "Parapet", Vector3.new(0.6, look.PARAPET, PlotConfig.DEPTH + thickness * 2 + 0.4), plotCFrame * CFrame.new(x * (halfWidth + thickness), top, 0), charcoal)
	end
	buildCeilingLights(plotCFrame, parent)
	return roof
end

-- The shop sign: a lit sign box on the charcoal band above the glass, facing the street
local function buildSign(plotCFrame: CFrame, parent: Instance): TextLabel
	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Anchored = true
	sign.CanCollide = false
	sign.CanQuery = false -- the camera never snaps in because of it
	sign.Size = PlotConfig.SIGN_SIZE
	sign.CFrame = plotCFrame
		* CFrame.new(0, (frontTop() + wallTop()) / 2, -PlotConfig.DEPTH / 2 - Town.WALL_THICKNESS - PlotConfig.SIGN_SIZE.Z / 2)
	sign.Color = PlotConfig.SIGN_COLOR
	sign.Parent = parent

	return addSurfaceLabel(sign, PlotConfig.FREE_SIGN_TEXT)
end

-- Snaps the computer to a grid cell. Attributes let the owner's client start a move from here.
-- A fixture part that shows a prop model: the part turns into an invisible hitbox (prompts and its label stay).
-- `box` (width, height, depth) lets the model be bigger than the part, its front lined up with the part's.
local function dressFixture(part: Part, slot: string, parent: Instance, box: Vector3?): boolean
	if not Props.hasLook(slot) then
		return false
	end
	part.Transparency = 1
	local size = box or part.Size
	local front = -part.Size.Z / 2 + size.Z / 2
	Props.fit(slot, size, part.CFrame * CFrame.new(0, -part.Size.Y / 2, front), parent)
	return true
end

local function setComputerCell(computer: Part, plotCFrame: CFrame, gridX: number, gridZ: number, rotation: number)
	computer.CFrame = plotCFrame * PlacementGrid.getLocalCFrame(computer.Size, gridX, gridZ, rotation)
	local visual = computer:FindFirstChild("Computer")
	if visual and visual:IsA("Model") then
		visual:PivotTo(computer.CFrame * CFrame.new(0, -computer.Size.Y / 2, 0))
	end
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

	computer:SetAttribute("Info", PlotConfig.COMPUTER_TEXT) -- the owner's hover tooltip (ShelfInfoController)
	dressFixture(computer, "Computer", computer) -- a child, so it moves with the computer
	return computer
end

-- The delivery spot outside on the sidewalk beside the doors (Town.DELIVERY): a concrete platform level with the
-- shop floor, a charcoal mat with a yellow border, a sign on its street face and two bollards. The returned part is
-- the invisible spot boxes stand on (StockService); it lies flush with the mat.
local function buildDeliverySpot(plotCFrame: CFrame, parent: Instance): Part
	local look = Town.DELIVERY
	local size = Vector3.new(look.SIZE[1], look.SIZE[2], look.SIZE[3])
	local floorTop = PlotConfig.FLOOR_THICKNESS / 2
	local centre = plotCFrame * CFrame.new(look.X, 0, -PlotConfig.DEPTH / 2 - Town.WALL_THICKNESS - look.GAP - size.Z / 2)
	-- From the ground (the floor's underside) up to the floor top
	local platform = shellPart(parent, "DeliveryPlatform", Vector3.new(size.X, PlotConfig.FLOOR_THICKNESS, size.Z), centre, Props.color(look.PLATFORM), Enum.Material.Concrete)
	local mat = trimPart(parent, "DeliveryMat", Vector3.new(size.X - 0.2, 0.06, size.Z - 0.2), centre * CFrame.new(0, floorTop + 0.03, 0), Props.color(look.MAT), Enum.Material.Fabric)
	local inner = size.X - 0.2 - look.BORDER_WIDTH * 2
	for _, side in { -1, 1 } do
		local edge = (size.X - 0.2) / 2 - look.BORDER_WIDTH / 2
		trimPart(parent, "DeliveryBorder", Vector3.new(size.X - 0.2, 0.02, look.BORDER_WIDTH), mat.CFrame * CFrame.new(0, 0.04, side * edge), Props.color(look.BORDER))
		trimPart(parent, "DeliveryBorder", Vector3.new(look.BORDER_WIDTH, 0.02, inner), mat.CFrame * CFrame.new(side * edge, 0.04, 0), Props.color(look.BORDER))
		-- Bollards on the street-side corners
		local bollard = trimPart(parent, "DeliveryBollard", Vector3.new(look.BOLLARD_HEIGHT, look.BOLLARD_SIZE, look.BOLLARD_SIZE), centre * CFrame.new(side * (size.X / 2 - 0.5), floorTop + look.BOLLARD_HEIGHT / 2, -(size.Z / 2 - 0.5)) * CFrame.Angles(0, 0, math.rad(90)), Props.color(look.BOLLARD), Enum.Material.Metal)
		bollard.Shape = Enum.PartType.Cylinder
		bollard.CanCollide = true
		local band = trimPart(parent, "DeliveryBollardBand", Vector3.new(0.3, look.BOLLARD_SIZE + 0.04, look.BOLLARD_SIZE + 0.04), bollard.CFrame * CFrame.new(look.BOLLARD_HEIGHT / 2 - 0.45, 0, 0), Props.color(look.BORDER))
		band.Shape = Enum.PartType.Cylinder
	end
	local sign = Instance.new("SurfaceGui")
	sign.Face = Enum.NormalId.Front
	sign.CanvasSize = Vector2.new(600, 100)
	sign.LightInfluence = 0
	sign.Parent = platform
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Props.color(look.BORDER)
	text.Text = look.TEXT
	text.Parent = sign

	local pad = Instance.new("Part")
	pad.Name = "DeliverySpot"
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanQuery = false
	pad.Transparency = 1
	pad.Size = size
	pad.CFrame = mat.CFrame * CFrame.new(0, 0.03 - size.Y / 2, 0)
	pad.Parent = parent
	return pad
end

-- The modern checkout (Town.COUNTER) around the counter part, which is its white body: a charcoal plinth, a dark
-- stone top overhanging the customers' side, an LED strip in the shop's accent colour under it, and pendant
-- lights hanging from the ceiling over it
local function buildCheckout(register: Part, accent: Color3, parent: Instance)
	local look = Town.COUNTER
	local size = register.Size
	local cframe = register.CFrame
	local bottom = -size.Y / 2
	register.Color = Props.color(Town.SHOP.WALL)
	register.Material = Enum.Material.SmoothPlastic
	trimPart(parent, "CounterPlinth", Vector3.new(size.X + 0.04, look.PLINTH_HEIGHT, size.Z + 0.04), cframe * CFrame.new(0, bottom + look.PLINTH_HEIGHT / 2, 0), Props.color(Town.SHOP.CHARCOAL))
	-- The top's surface sits just above the body's, where the terminal and scan items stand
	local topY = size.Y / 2 - look.TOP_THICKNESS / 2 + 0.01
	trimPart(parent, "CounterTop", Vector3.new(size.X + 0.1, look.TOP_THICKNESS, size.Z + look.TOP_OVERHANG), cframe * CFrame.new(0, topY, -look.TOP_OVERHANG / 2), Props.color(look.TOP), Enum.Material.Marble)
	local ledY = size.Y / 2 - look.TOP_THICKNESS - look.LED_HEIGHT / 2 - 0.05
	trimPart(parent, "CounterLed", Vector3.new(size.X, look.LED_HEIGHT, 0.04), cframe * CFrame.new(0, ledY, -size.Z / 2 - 0.02), accent, Enum.Material.Neon)

	local pendant = look.PENDANT
	local cordLength = Town.WALL_HEIGHT - pendant.BOTTOM - pendant.SHADE_HEIGHT
	for index = 1, pendant.COUNT do
		local x = (index - 1 - (pendant.COUNT - 1) / 2) * pendant.SPREAD
		local shadeY = bottom + pendant.BOTTOM + pendant.SHADE_HEIGHT / 2
		local cord = trimPart(parent, "PendantCord", Vector3.new(cordLength, pendant.CORD, pendant.CORD), cframe * CFrame.new(x, shadeY + pendant.SHADE_HEIGHT / 2 + cordLength / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Props.color(Town.SHOP.FRAME))
		cord.Shape = Enum.PartType.Cylinder
		local shade = trimPart(parent, "PendantShade", Vector3.new(pendant.SHADE_HEIGHT, pendant.SHADE_WIDTH, pendant.SHADE_WIDTH), cframe * CFrame.new(x, shadeY, 0) * CFrame.Angles(0, 0, math.rad(90)), Props.color(Town.SHOP.FRAME), Enum.Material.Metal)
		shade.Shape = Enum.PartType.Cylinder
		local bulb = trimPart(parent, "PendantBulb", Vector3.new(0.45, 0.45, 0.45), cframe * CFrame.new(x, shadeY - pendant.SHADE_HEIGHT / 2, 0), Props.color(pendant.BULB), Enum.Material.Neon)
		bulb.Shape = Enum.PartType.Ball
		bulb.CastShadow = false
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Angle = 80
		light.Color = Props.color(pendant.BULB)
		light.Brightness = pendant.BRIGHTNESS
		light.Range = pendant.RANGE
		light.Parent = bulb
	end
end

-- Register faces the street like the plot; customers queue in front of it, the owner stands behind.
-- The counter part is what the shop systems use; the terminal and counter props sit on top of it.
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
	register:SetAttribute("BlocksPlacement", true)
	register.Parent = parent
	local counter = Town.COUNTER
	register:SetAttribute("Info", PlotConfig.REGISTER_TEXT) -- the owner's hover tooltip (ShelfInfoController)
	buildCheckout(register, Props.color(getTheme(id).accent), parent)
	-- The terminal takes the left end; the decor sits in the back strip, clear of the scan items on the
	-- front edge (RegisterService)
	local counterTop = register.CFrame * CFrame.new(0, size.Y / 2, 0)
	local registerBox = Vector3.new(counter.REGISTER.width, counter.REGISTER.height, counter.REGISTER.depth)
	Props.fit("Terminal", registerBox, counterTop * CFrame.new(counter.REGISTER.x, 0, 0), parent)
	local _, propZ = PropFit.counterZ(size.Z, RegisterConfig.ITEM_SIZE.Z, counter.PROP_DEPTH)
	local decorBox = Vector3.new(counter.DECOR.width, counter.DECOR.height, counter.PROP_DEPTH)
	Props.fit("CounterDecor", decorBox, counterTop * CFrame.new(counter.DECOR.x, 0, propZ), parent, id)

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
	plot.floor.Color = Props.color(Town.SHOP.FLOOR)
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
