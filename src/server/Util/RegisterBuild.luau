--!strict
-- The register unit on each shop's checkout counter (owner 2026-11-16: man the register in first person; modern, to
-- match the shop; Config/RegisterStation UNIT): a white base, a screen facing the cashier on a charcoal stand, a cash
-- drawer in the base that slides out toward the cashier (its bills and coins named Money_<cents>, each with a Money
-- attribute), and a card machine on the cashier's side. The owner's client drives it (RegisterStationController):
-- the screen's and the keypad's pictures, the drawer opening. The body is the Meshy model when it's imported
-- (PropModels.RegisterBody: tools/blender/build_register.py), else a code-built one of the same shape; the working
-- parts (the screen glass, the drawer, the card machine) are always code-built on top
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Payment = require(Shared:WaitForChild("Config"):WaitForChild("Payment"))
local RegisterStation = require(Shared:WaitForChild("Config"):WaitForChild("RegisterStation"))
local RegisterStationRules = require(Shared:WaitForChild("Util"):WaitForChild("RegisterStationRules"))

local RegisterBuild = {}

local UNIT = RegisterStation.UNIT
local COLORS = RegisterStation.COLORS

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: { number }, material: Enum.Material?): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = rgb(color)
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

-- A picture on a clear plate's top (a note's or coin's face). A Top-face picture is drawn with its top edge along the
-- part's -X, so plates are turned a quarter (`QUARTER`) to read upright from the cashier's side
local function picture(plate: BasePart, image: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 400
	gui.LightInfluence = 0.4
	gui.Parent = plate
	local face = Instance.new("ImageLabel")
	face.BackgroundTransparency = 1
	face.Size = UDim2.fromScale(1, 1)
	face.Image = image
	face.Parent = gui
end

local QUARTER = CFrame.Angles(0, math.rad(-90), 0)

-- A little stack of notes in a compartment, lying lengthwise toward the cashier like in a real drawer, each a touch
-- askew, the top one showing the note's picture with its value upright and big (owner 2026-11-16: "we need a model for
-- the cash and coins inside register"; "the numbers on the bills are hard to see")
local function noteStack(drawer: Model, at: CFrame, cents: number, room: Vector3)
	local aspect = RegisterStation.NOTE_ASPECT
	local width = math.min(room.X * 0.94, room.Z * 0.94 * aspect)
	local length = width / aspect
	local color = RegisterStation.MONEY_COLORS[cents]
	local thickness = 0.018
	local top = at
	for index = 1, RegisterStation.NOTE_STACK do
		local twist = (index % 2 == 0 and 1 or -1) * math.rad(2 + index)
		top = at * CFrame.new((index - 2) * 0.01, thickness * (index - 0.5), (index - 2) * 0.012) * CFrame.Angles(0, twist, 0)
		local note = part(drawer, "Money_" .. cents, Vector3.new(width, thickness, length), top, color)
		note:SetAttribute("Money", cents)
	end
	local plate = part(drawer, "MoneyFace", Vector3.new(length, 0.004, width), top * CFrame.new(0, thickness / 2 + 0.003, 0) * QUARTER, color)
	plate.Transparency = 1
	plate.CanQuery = false
	picture(plate, RegisterStation.MONEY_IMAGES[cents])
end

-- A round cup with a few coins in it, the top one showing the coin's picture
local function coinCup(drawer: Model, at: CFrame, cents: number, room: Vector3)
	local across = math.min(room.X, room.Z) * 0.96
	local cup = part(drawer, "CoinCup", Vector3.new(0.05, across, across), at * CFrame.new(0, 0.025, 0) * CFrame.Angles(0, 0, math.rad(90)), COLORS.trim)
	cup.Shape = Enum.PartType.Cylinder
	cup:SetAttribute("Money", cents) -- a tap anywhere in the cup counts
	local coin = across * RegisterStation.COIN_SIZES[cents]
	local thickness = 0.035
	local color = RegisterStation.MONEY_COLORS[cents]
	local top = at
	for index = 1, RegisterStation.COIN_STACK do
		top = at * CFrame.new((index - 2) * 0.015, 0.05 + thickness * (index - 0.5), (2 - index) * 0.012)
		local piece = part(drawer, "Money_" .. cents, Vector3.new(thickness, coin, coin), top * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Metal)
		piece.Shape = Enum.PartType.Cylinder
		piece:SetAttribute("Money", cents)
	end
	local plate = part(drawer, "MoneyFace", Vector3.new(coin, 0.004, coin), top * CFrame.new(0, thickness / 2 + 0.003, 0) * QUARTER, color)
	plate.Transparency = 1
	plate.CanQuery = false
	picture(plate, RegisterStation.MONEY_IMAGES[cents])
end

local function buildDrawer(unit: Model, base: CFrame, plainFront: boolean)
	local look = UNIT.drawer
	local size = vector(look.size)
	local drawer = Instance.new("Model")
	drawer.Name = "CashDrawer"
	drawer.Parent = unit
	-- closed: inside the base, its floor at the base's bottom
	local origin = base * CFrame.new(0, size.Y / 2 + 0.02, look.closedZ)
	local floor = -size.Y / 2 + 0.06
	local tray = part(drawer, "DrawerTray", Vector3.new(size.X, 0.06, size.Z), origin * CFrame.new(0, -size.Y / 2 + 0.03, 0), COLORS.tray)
	drawer.PrimaryPart = tray
	part(drawer, "DrawerFront", Vector3.new(size.X + 0.08, size.Y + 0.08, 0.08), origin * CFrame.new(0, 0, size.Z / 2 + 0.04), COLORS.body)
	-- the Meshy body has its own handle on its drawer face: no second one on top
	if not plainFront then
		part(drawer, "DrawerHandle", Vector3.new(0.6, 0.08, 0.06), origin * CFrame.new(0, 0.02, size.Z / 2 + 0.11), COLORS.accent, Enum.Material.Neon)
	end
	-- the dividers: one between the notes and the coins, and one between each compartment
	local wall = 0.03
	local wallHeight = size.Y * 0.55
	local rowLine = -size.Z / 2 + size.Z * RegisterStation.NOTE_ROW
	part(drawer, "DrawerDivider", Vector3.new(size.X, wallHeight, wall), origin * CFrame.new(0, floor + wallHeight / 2, rowLine), COLORS.trim)
	local slots = RegisterStationRules.drawerSlots(Payment.DRAWER, size.X, size.Z, RegisterStation.NOTE_ROW)
	local columns = #slots / 2
	for column = 1, columns - 1 do
		local x = -size.X / 2 + size.X / columns * column
		part(drawer, "DrawerDivider", Vector3.new(wall, wallHeight, size.Z), origin * CFrame.new(x, floor + wallHeight / 2, 0), COLORS.trim)
	end
	for _, slot in slots do
		local at = origin * CFrame.new(slot.x, floor, slot.z)
		local room = Vector3.new(slot.width, 0, slot.depth)
		if slot.cents >= 100 then
			noteStack(drawer, at, slot.cents, room)
		else
			coinCup(drawer, at, slot.cents, room)
		end
	end
end

-- The Meshy body (Config/RegisterStation BODY) scaled to its width, its front turned to the cashier; nil while it isn't
-- imported
local function meshBody(unit: Model, base: CFrame): BasePart?
	local folder = ReplicatedStorage:FindFirstChild("PropModels")
	local template = if folder then folder:FindFirstChild(RegisterStation.BODY.model) else nil
	local source = if template and template:IsA("BasePart") then template elseif template then template:FindFirstChildWhichIsA("MeshPart", true) else nil
	if not source or not source:IsA("BasePart") then
		return nil
	end
	local body = source:Clone()
	for _, child in body:GetDescendants() do
		if child:IsA("LuaSourceContainer") then
			child:Destroy()
		end
	end
	local scale = RegisterStation.BODY.width / source.Size.X
	body.Name = "RegisterHousing" -- the prompt and Pish's paw find it by this name
	body.Size = source.Size * scale
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CastShadow = false
	-- imported axis-aligned with its front -Z: turned half round so it faces the cashier (+Z), its bottom on the counter
	body.CFrame = base * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, body.Size.Y / 2, 0)
	body.Parent = unit
	return body
end

-- The code-built body of the same shape: a white base with a lilac strip, a charcoal pole and bezel
local function standInBody(unit: Model, base: CFrame, screenAt: CFrame)
	local housing = UNIT.housing
	local housingSize = vector(housing.size)
	part(unit, "RegisterHousing", housingSize, base * CFrame.new(0, housingSize.Y / 2, housing.z), COLORS.body)
	part(unit, "RegisterLed", Vector3.new(housingSize.X * 0.9, 0.05, 0.03), base * CFrame.new(0, housingSize.Y - 0.12, housing.z + housingSize.Z / 2 + 0.01), COLORS.accent, Enum.Material.Neon)
	local stand = UNIT.stand
	local standSize = vector(stand.size)
	part(unit, "RegisterStand", standSize, base * CFrame.new(0, housingSize.Y + standSize.Y / 2, stand.z), COLORS.trim)
	local glass = UNIT.screen.size
	part(unit, "RegisterBezel", Vector3.new(glass[1] + 0.16, glass[2] + 0.16, 0.14), screenAt * CFrame.new(0, 0, -0.08), COLORS.trim)
end

-- The unit on the counter whose top centre is `counterTop` (+Z toward the cashier)
function RegisterBuild.build(counterTop: CFrame, parent: Instance): Model
	local unit = Instance.new("Model")
	unit.Name = "RegisterUnit"
	local base = counterTop * CFrame.new(UNIT.x, 0, 0)

	-- The glass's face, leaning back, facing the cashier (its +Z)
	local screen = UNIT.screen
	local centre = screen.centre
	local screenAt = base * CFrame.new(centre[1], centre[2], centre[3]) * CFrame.Angles(math.rad(-screen.tilt), 0, 0)
	local model = meshBody(unit, base)
	if not model then
		standInBody(unit, base, screenAt)
	end
	-- the screen the game draws on (Util/RegisterScreen on its Back face), just in front of the glass, just inside the
	-- bezel; clear itself (the display draws its own rounded background, so no square corner sticks out)
	local display = part(unit, "RegisterScreen", Vector3.new(screen.size[1], screen.size[2], 0.04), screenAt * CFrame.new(0, 0, -0.01), COLORS.screen, Enum.Material.Glass)
	display.Transparency = 1

	buildDrawer(unit, base, model ~= nil)
	-- the opening the drawer leaves on the base's front, shown by the owner's client while it's out
	local cavity = UNIT.cavity
	local opening = part(unit, "DrawerCavity", Vector3.new(cavity.size[1], cavity.size[2], 0.02), base * CFrame.new(0, cavity.y, cavity.z), COLORS.tray)
	opening.Transparency = 1
	opening.CanQuery = false

	-- The card machine on the base, tilted up toward the cashier, its low edge resting on the base
	local card = UNIT.card
	local cardSize = vector(card.size)
	local rise = math.sin(math.rad(card.tilt)) * cardSize.Z / 2
	local cardAt = counterTop * CFrame.new(card.x, card.y + rise + cardSize.Y / 2, card.z) * CFrame.Angles(math.rad(card.tilt), 0, 0)
	part(unit, "CardMachine", cardSize, cardAt, COLORS.trim)
	-- turned a quarter so its Top face's picture reads upright from the cashier's side (a SurfaceGui on Top is drawn
	-- with its top edge along the part's -X)
	local keypadAt = cardAt * CFrame.new(0, cardSize.Y / 2 + 0.01, 0) * CFrame.Angles(0, math.rad(-90), 0)
	part(unit, "CardKeypad", Vector3.new(cardSize.Z - 0.08, 0.02, cardSize.X - 0.08), keypadAt, COLORS.screen, Enum.Material.Glass)

	unit.Parent = parent
	return unit
end

return RegisterBuild
