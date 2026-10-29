--!strict
-- Swappable town props (main town spec, docs/props.md). A slot's model comes from ReplicatedStorage.PropModels
-- (assets/props/<Slot>.rbxm and its variants); a missing, empty, too-big or broken one gets a part-built stand-in,
-- so the town never breaks. Placed props are stripped of scripts, scaled, anchored and stood on the given spot.
-- Shared: the server builds the town and shops with it, the client builds placement ghosts the same way.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local PropFit = require(Shared:WaitForChild("Util"):WaitForChild("PropFit"))
local TownLayout = require(Shared:WaitForChild("Util"):WaitForChild("TownLayout"))
local ShelfLooks = require(Shared:WaitForChild("Util"):WaitForChild("ShelfLooks"))
local CaseLook = require(Shared:WaitForChild("Util"):WaitForChild("CaseLook"))

local Props = {}

local STRIPPED = { "LuaSourceContainer", "ProximityPrompt", "ClickDetector", "Sound", "Tool" }
-- PropModels: synced by Rojo from assets/props. PlaceProps: kept in the place file, for models with unions
-- (Rojo live sync drops union shapes); their git copies are in assets/place-props (docs/props.md)
local SOURCE_FOLDERS = { "PlaceProps", "PropModels" }
local MIN_HEIGHT = 0.05

local WOOD = Color3.fromRGB(125, 90, 60)
local DARK_WOOD = Color3.fromRGB(95, 65, 45)
local STONE = Color3.fromRGB(150, 145, 140)
local LAMP_GLOW = Color3.fromRGB(255, 220, 150)
local STEEL_BLACK = Color3.fromRGB(28, 30, 36)
local CHARCOAL = Color3.fromRGB(52, 56, 64)
local WHITE = Color3.fromRGB(244, 245, 248)
local LED_WHITE = Color3.fromRGB(255, 246, 228)
local HEDGE_GREEN = Color3.fromRGB(72, 132, 70)
local SPRING_STONE = Color3.fromRGB(196, 202, 214)
local SPRING_TRIM = Color3.fromRGB(150, 160, 182)
local SPRING_WATER = Color3.fromRGB(90, 200, 255)
local SPRING_CRYSTAL = Color3.fromRGB(110, 210, 255)

local variantCache: { [string]: { Instance } } = {}

-- Free models can carry scripts and noise: none of it may run or play
function Props.strip(root: Instance)
	for _, descendant in root:GetDescendants() do
		for _, className in STRIPPED do
			if descendant:IsA(className) then
				descendant:Destroy()
				break
			end
		end
	end
end

function Props.color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function countParts(model: Instance): number
	local count = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

-- A source is a Model, or a lone part (some packs save single MeshParts)
local function isUsable(source: Instance): boolean
	if source:IsA("BasePart") then
		return source.Size.Y >= MIN_HEIGHT
	end
	if not source:IsA("Model") then
		return false
	end
	local parts = countParts(source)
	if parts == 0 or parts > Town.MAX_PROP_PARTS then
		return false
	end
	local ok, _, size = pcall(function()
		return (source :: Model):GetBoundingBox()
	end)
	return ok and size.Y >= MIN_HEIGHT
end

-- Every usable source model for a slot, sorted by name so every server picks the same one
local function getVariants(slot: string): { Instance }
	local cached = variantCache[slot]
	if cached then
		return cached
	end
	local found: { Instance } = {}
	local info = Town.SLOTS[slot]
	if info and (info :: any).built then
		-- A code-built look wins: old model files for it are ignored
		variantCache[slot] = found
		return found
	end
	for _, folderName in SOURCE_FOLDERS do
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		for _, child in if folder then folder:GetChildren() else {} do
			if TownLayout.isVariant(slot, child.Name, Town.SLOTS) and isUsable(child) then
				table.insert(found, child)
			end
		end
	end
	table.sort(found, function(a, b)
		return a.Name < b.Name
	end)
	variantCache[slot] = found
	return found
end

local function addPart(model: Model, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- Cylinders run along X: this stands one up
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- The Card Condenser (Town.CONDENSER_LOOK), bottom centre at the origin, front -Z. Its Rotor (the crystal and the
-- floating cards) is a Model of its own that CondenserFxController spins on each client.
local function buildCondenser(model: Model)
	local look = Town.CONDENSER_LOOK
	local block, cylinder = Enum.PartType.Block, Enum.PartType.Cylinder
	local body, trim, glow = Props.color(look.BODY), Props.color(look.TRIM), Props.color(look.GLOW)
	local baseTop = look.BASE_HEIGHT
	local chamberTop = baseTop + look.CHAMBER_HEIGHT
	local chamberY = baseTop + look.CHAMBER_HEIGHT / 2
	-- Base: the plinth, a glowing ring round its top, a screen and a card slot on its front
	addPart(model, cylinder, Vector3.new(look.BASE_HEIGHT, look.BASE_RADIUS * 2, look.BASE_RADIUS * 2), CFrame.new(0, baseTop / 2, 0) * UPRIGHT, body, Enum.Material.Metal)
	addPart(model, cylinder, Vector3.new(0.12, look.BASE_RADIUS * 2 + 0.1, look.BASE_RADIUS * 2 + 0.1), CFrame.new(0, baseTop - 0.1, 0) * UPRIGHT, glow, Enum.Material.Neon)
	addPart(model, block, Vector3.new(1.9, 0.8, 0.3), CFrame.new(0, 0.6, -look.BASE_RADIUS + 0.1), trim, Enum.Material.SmoothPlastic)
	local screen = addPart(model, block, Vector3.new(1.7, 0.6, 0.02), CFrame.new(0, 0.6, -look.BASE_RADIUS - 0.06), Color3.fromRGB(22, 20, 40), Enum.Material.SmoothPlastic)
	screen.Name = "Screen"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(340, 120)
	gui.LightInfluence = 0
	gui.Parent = screen
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = glow:Lerp(Color3.new(1, 1, 1), 0.5)
	label.Text = look.SCREEN_TEXT
	label.Parent = gui
	addPart(model, block, Vector3.new(1.2, 0.06, 0.1), CFrame.new(0, baseTop - 0.3, -look.BASE_RADIUS + 0.2), glow, Enum.Material.Neon).Name = "CardSlot"
	-- Chamber: glass with a glowing floor
	local glass = addPart(model, cylinder, Vector3.new(look.CHAMBER_HEIGHT, look.CHAMBER_RADIUS * 2, look.CHAMBER_RADIUS * 2), CFrame.new(0, chamberY, 0) * UPRIGHT, Props.color(look.GLASS), Enum.Material.Glass)
	glass.Name = "Glass"
	glass.Transparency = look.GLASS_TRANSPARENCY
	glass.CastShadow = false
	local floor = addPart(model, cylinder, Vector3.new(0.04, look.CHAMBER_RADIUS * 1.7, look.CHAMBER_RADIUS * 1.7), CFrame.new(0, baseTop + 0.02, 0) * UPRIGHT, glow, Enum.Material.Neon)
	floor.Transparency = look.FLOOR_TRANSPARENCY
	-- Side pillars with light strips, holding the cap
	local pillarX = (look.CHAMBER_RADIUS + look.BASE_RADIUS) / 2
	for _, side in { -1, 1 } do
		addPart(model, block, Vector3.new(0.45, look.CHAMBER_HEIGHT, 0.45), CFrame.new(side * pillarX, chamberY, 0), body, Enum.Material.Metal)
		addPart(model, block, Vector3.new(0.08, look.CHAMBER_HEIGHT - 0.4, 0.06), CFrame.new(side * pillarX, chamberY, -0.25), glow, Enum.Material.Neon)
	end
	local capRadius = pillarX + 0.3
	addPart(model, cylinder, Vector3.new(0.1, capRadius * 2 + 0.1, capRadius * 2 + 0.1), CFrame.new(0, chamberTop + 0.05, 0) * UPRIGHT, glow, Enum.Material.Neon)
	addPart(model, cylinder, Vector3.new(look.CAP_HEIGHT, capRadius * 2, capRadius * 2), CFrame.new(0, chamberTop + look.CAP_HEIGHT / 2, 0) * UPRIGHT, body, Enum.Material.Metal)
	addPart(model, cylinder, Vector3.new(0.25, 2, 2), CFrame.new(0, chamberTop + look.CAP_HEIGHT + 0.12, 0) * UPRIGHT, trim, Enum.Material.Metal)

	-- Rotor: a crystal with three cards circling it, sparkling
	local rotor = Instance.new("Model")
	rotor.Name = "Rotor"
	rotor:SetAttribute("RotorY", chamberY)
	local crystal = Instance.new("Part")
	crystal.Name = "Crystal"
	crystal.Size = Vector3.new(0.6, 1.1, 0.6)
	crystal.CFrame = CFrame.new(0, chamberY, 0) * CFrame.Angles(0, math.rad(45), 0)
	crystal.Color = glow
	crystal.Material = Enum.Material.Neon
	crystal.Parent = rotor
	for index = 1, 3 do
		local angle = (index - 1) * math.pi * 2 / 3
		local card = Instance.new("Part")
		card.Name = "Card"
		card.Size = Vector3.new(0.55, 0.8, 0.04)
		card.CFrame = CFrame.new(0, chamberY, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -look.CORE_RADIUS) * CFrame.Angles(math.rad(10), 0, 0)
		card.Color = Props.color(look.CARD)
		card.Material = Enum.Material.SmoothPlastic
		card.Parent = rotor
	end
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(0.3, 0.8)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.3, 0)
	sparkles.Color = ColorSequence.new(glow:Lerp(Color3.new(1, 1, 1), 0.4))
	sparkles.LightEmission = 1
	sparkles.Parent = crystal
	rotor.PrimaryPart = crystal
	rotor.Parent = model
end

-- The Grading Station (Town.GRADING_LOOK), bottom centre at the origin, front -Z: a cabinet with a screen, a scanner
-- bed on top with a card under a glowing scan bar, a magnifier on an arm, and a graded slab on a stand at the back
local function buildGradingStation(model: Model)
	local look = Town.GRADING_LOOK
	local block, cylinder = Enum.PartType.Block, Enum.PartType.Cylinder
	local body, trim, glow = Props.color(look.BODY), Props.color(look.TRIM), Props.color(look.GLOW)
	local top = look.CABINET_HEIGHT
	local frontZ = -look.DEPTH / 2
	-- Cabinet: navy body, gold trim round the top and base, a gold plinth strip
	addPart(model, block, Vector3.new(look.WIDTH, top, look.DEPTH), CFrame.new(0, top / 2, 0), body, Enum.Material.Metal)
	addPart(model, block, Vector3.new(look.WIDTH + 0.12, 0.18, look.DEPTH + 0.12), CFrame.new(0, top - 0.09, 0), trim, Enum.Material.Metal)
	addPart(model, block, Vector3.new(look.WIDTH + 0.12, 0.3, look.DEPTH + 0.12), CFrame.new(0, 0.15, 0), trim, Enum.Material.Metal)
	-- Front screen
	local screen = addPart(model, block, Vector3.new(3.2, 1.1, 0.06), CFrame.new(0, top * 0.6, frontZ - 0.03), Color3.fromRGB(16, 18, 30), Enum.Material.SmoothPlastic)
	screen.Name = "Screen"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 140)
	gui.LightInfluence = 0
	gui.Parent = screen
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = trim:Lerp(Color3.new(1, 1, 1), 0.35)
	label.Text = look.SCREEN_TEXT
	label.Parent = gui
	-- Scanner bed on top, a card lying on it under a glowing scan bar held by two gold posts
	local bedY = top + 0.12
	addPart(model, block, Vector3.new(2.6, 0.24, 2), CFrame.new(-0.6, bedY, -0.2), Props.color(look.BED), Enum.Material.SmoothPlastic)
	addPart(model, block, Vector3.new(0.9, 0.04, 1.25), CFrame.new(-0.6, bedY + 0.14, -0.2), Props.color(look.CARD), Enum.Material.SmoothPlastic).Name = "Card"
	for _, side in { -1, 1 } do
		addPart(model, block, Vector3.new(0.18, 0.9, 0.18), CFrame.new(-0.6 + side * 1.2, bedY + 0.55, -0.2), trim, Enum.Material.Metal)
	end
	addPart(model, block, Vector3.new(2.6, 0.16, 0.22), CFrame.new(-0.6, bedY + 1.05, -0.2), trim, Enum.Material.Metal)
	addPart(model, block, Vector3.new(2.3, 0.06, 0.1), CFrame.new(-0.6, bedY + 0.95, -0.2), glow, Enum.Material.Neon).Name = "ScanBar"
	-- Magnifier on an arm over the right of the bed
	addPart(model, block, Vector3.new(0.16, 1.4, 0.16), CFrame.new(1.7, top + 0.7, 0.6), trim, Enum.Material.Metal)
	addPart(model, block, Vector3.new(0.12, 0.12, 1.1), CFrame.new(1.7, top + 1.4, 0.1), trim, Enum.Material.Metal)
	addPart(model, cylinder, Vector3.new(0.12, 0.9, 0.9), CFrame.new(1.7, top + 1.25, -0.45) * UPRIGHT, trim, Enum.Material.Metal)
	local lens = addPart(model, cylinder, Vector3.new(0.06, 0.75, 0.75), CFrame.new(1.7, top + 1.25, -0.45) * UPRIGHT, Color3.fromRGB(200, 230, 255), Enum.Material.Glass)
	lens.Transparency = 0.5
	-- A graded slab (a card in a clear case with a gold label) on a stand at the back
	addPart(model, block, Vector3.new(0.5, 0.5, 0.3), CFrame.new(1.4, top + 0.25, 1.3), body, Enum.Material.Metal)
	local slab = addPart(model, block, Vector3.new(1.1, 1.6, 0.14), CFrame.new(1.4, top + 1.3, 1.3) * CFrame.Angles(math.rad(-12), 0, 0), Props.color(look.SLAB), Enum.Material.Glass)
	slab.Transparency = 0.25
	addPart(model, block, Vector3.new(0.85, 0.3, 0.16), CFrame.new(1.4, top + 1.85, 1.31) * CFrame.Angles(math.rad(-12), 0, 0), trim, Enum.Material.SmoothPlastic)
	addPart(model, block, Vector3.new(0.75, 1, 0.16), CFrame.new(1.4, top + 1.15, 1.31) * CFrame.Angles(math.rad(-12), 0, 0), Props.color(look.CARD), Enum.Material.SmoothPlastic)
end

-- A boss trophy (Town.TROPHY_LOOK), bottom centre at the origin, front -Z: a stone plinth with a gold band and a
-- gem (named Gem, recoloured per boss) on its front, a gold cup with two handles on top
local function buildTrophy(model: Model)
	local look = Town.TROPHY_LOOK
	local block, cylinder, ball = Enum.PartType.Block, Enum.PartType.Cylinder, Enum.PartType.Ball
	local stone, gold = Props.color(look.STONE), Props.color(look.GOLD)
	local width, height = look.PLINTH_WIDTH, look.PLINTH_HEIGHT
	addPart(model, block, Vector3.new(width + 0.4, 0.3, width + 0.4), CFrame.new(0, 0.15, 0), stone, Enum.Material.Slate)
	addPart(model, block, Vector3.new(width, height, width), CFrame.new(0, height / 2, 0), stone, Enum.Material.Slate)
	addPart(model, block, Vector3.new(width + 0.1, 0.2, width + 0.1), CFrame.new(0, height - 0.3, 0), gold, Enum.Material.Metal)
	local gem = addPart(model, block, Vector3.new(0.6, 0.6, 0.15), CFrame.new(0, height * 0.5, -width / 2 - 0.05) * CFrame.Angles(0, 0, math.rad(45)), Props.color(look.GEM), Enum.Material.Neon)
	gem.Name = "Gem"
	-- The cup: a foot, a stem, the bowl and its rim, two ring handles
	local top = height
	addPart(model, cylinder, Vector3.new(0.2, 1.3, 1.3), CFrame.new(0, top + 0.1, 0) * UPRIGHT, gold, Enum.Material.Metal)
	addPart(model, cylinder, Vector3.new(0.7, 0.35, 0.35), CFrame.new(0, top + 0.55, 0) * UPRIGHT, gold, Enum.Material.Metal)
	addPart(model, ball, Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, top + 1.5, 0), gold, Enum.Material.Metal)
	addPart(model, cylinder, Vector3.new(0.9, 1.7, 1.7), CFrame.new(0, top + 2.05, 0) * UPRIGHT, gold, Enum.Material.Metal)
	addPart(model, cylinder, Vector3.new(0.06, 1.5, 1.5), CFrame.new(0, top + 2.52, 0) * UPRIGHT, stone, Enum.Material.SmoothPlastic)
	for _, side in { -1, 1 } do
		addPart(model, cylinder, Vector3.new(0.15, 0.8, 0.8), CFrame.new(side * 0.95, top + 1.75, 0), gold, Enum.Material.Metal)
	end
end

-- Stand-ins built around the origin, bottom at y = 0, front facing -Z
local function buildFallback(slot: string, height: number, size: Vector3?, variant: number): Model
	local model = Instance.new("Model")
	local block, cylinder = Enum.PartType.Block, Enum.PartType.Cylinder
	if ShelfLooks.isShelf(slot) then
		ShelfLooks.draw(model, slot, size or Vector3.new(4, 7, 2))
	elseif slot == "CardCase" then
		CaseLook.draw(model, size or Vector3.new(6, 4, 2))
	elseif slot == "Lamp" then
		addPart(model, cylinder, Vector3.new(height * 0.9, 0.5, 0.5), CFrame.new(0, height * 0.45, 0) * UPRIGHT, DARK_WOOD, Enum.Material.Wood)
		local head = addPart(model, block, Vector3.new(1.4, height * 0.1, 1.4), CFrame.new(0, height * 0.95, 0), LAMP_GLOW, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = LAMP_GLOW
		light.Range = 16
		light.Brightness = 1
		light.Parent = head
	elseif slot == "Bench" then
		addPart(model, block, Vector3.new(5, 0.4, 1.6), CFrame.new(0, height * 0.5, 0), WOOD, Enum.Material.Wood)
		addPart(model, block, Vector3.new(5, height * 0.5, 0.3), CFrame.new(0, height * 0.75, 0.7), WOOD, Enum.Material.Wood)
		for _, x in { -2.2, 2.2 } do
			addPart(model, block, Vector3.new(0.3, height * 0.5, 1.4), CFrame.new(x, height * 0.25, 0), DARK_WOOD, Enum.Material.Wood)
		end
	elseif slot == "Fence" then
		local length = Town.LAYOUT.FENCE_SECTION
		for _, x in { -length / 2 + 0.25, length / 2 - 0.25 } do
			addPart(model, block, Vector3.new(0.5, height, 0.5), CFrame.new(x, height / 2, 0), DARK_WOOD, Enum.Material.Wood)
		end
		for _, y in { height * 0.4, height * 0.8 } do
			addPart(model, block, Vector3.new(length, 0.35, 0.25), CFrame.new(0, y, 0), WOOD, Enum.Material.Wood)
		end
	elseif slot == "StreetLight" then
		-- A slim black pole with a flat arm reaching over the street and an LED head
		addPart(model, block, Vector3.new(1.2, 0.5, 1.2), CFrame.new(0, 0.25, 0), STEEL_BLACK, Enum.Material.Metal)
		addPart(model, cylinder, Vector3.new(height - 0.4, 0.35, 0.35), CFrame.new(0, (height - 0.4) / 2 + 0.3, 0) * UPRIGHT, STEEL_BLACK, Enum.Material.Metal)
		addPart(model, block, Vector3.new(0.3, 0.3, 2.4), CFrame.new(0, height - 0.2, -1.1), STEEL_BLACK, Enum.Material.Metal)
		addPart(model, block, Vector3.new(0.9, 0.25, 1.4), CFrame.new(0, height - 0.45, -2.1), STEEL_BLACK, Enum.Material.Metal)
		local glow = addPart(model, block, Vector3.new(0.7, 0.06, 1.2), CFrame.new(0, height - 0.6, -2.1), LED_WHITE, Enum.Material.Neon)
		glow.Name = "LED"
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Color = LED_WHITE
		light.Range = 22
		light.Angle = 100
		light.Brightness = 1.2
		light.Parent = glow
	elseif slot == "Hedge" then
		-- A trimmed box hedge on a low stone curb, one fence section long
		local length = Town.LAYOUT.FENCE_SECTION
		addPart(model, block, Vector3.new(length, 0.5, 1.8), CFrame.new(0, 0.25, 0), Color3.fromRGB(170, 172, 178), Enum.Material.Concrete)
		addPart(model, block, Vector3.new(length, height - 0.5, 1.4), CFrame.new(0, 0.5 + (height - 0.5) / 2, 0), HEDGE_GREEN, Enum.Material.Grass)
	elseif slot == "Condenser" then
		buildCondenser(model)
	elseif slot == "GradingStation" then
		buildGradingStation(model)
	elseif slot == "Trophy" then
		buildTrophy(model)
	elseif slot == "Computer" then
		-- A modern workstation, its front (-Z) the room side: a white desk on black panel legs, a slim widescreen
		-- facing the chair, keyboard, mouse, a small plant, a drawer unit underneath and an office chair
		local deskTop = 2.6
		addPart(model, block, Vector3.new(7, 0.2, 3), CFrame.new(0, deskTop - 0.1, 0.9), WHITE, Enum.Material.SmoothPlastic)
		for _, side in { -1, 1 } do
			addPart(model, block, Vector3.new(0.2, deskTop - 0.2, 2.6), CFrame.new(side * 3.3, (deskTop - 0.2) / 2, 0.9), STEEL_BLACK, Enum.Material.Metal)
		end
		addPart(model, block, Vector3.new(1.7, 2.1, 2.4), CFrame.new(2.2, 1.05, 1), CHARCOAL, Enum.Material.SmoothPlastic)
		addPart(model, block, Vector3.new(1.4, 0.06, 0.04), CFrame.new(2.2, 1.6, -0.22), STEEL_BLACK, Enum.Material.Metal)
		addPart(model, block, Vector3.new(1.4, 0.06, 0.04), CFrame.new(2.2, 0.8, -0.22), STEEL_BLACK, Enum.Material.Metal)
		-- Monitor
		addPart(model, block, Vector3.new(1.2, 0.08, 0.8), CFrame.new(0, deskTop + 0.04, 1.6), STEEL_BLACK, Enum.Material.Metal)
		addPart(model, block, Vector3.new(0.18, 1, 0.12), CFrame.new(0, deskTop + 0.55, 1.75), STEEL_BLACK, Enum.Material.Metal)
		addPart(model, block, Vector3.new(3.6, 1.9, 0.12), CFrame.new(0, deskTop + 1.75, 1.65), STEEL_BLACK, Enum.Material.SmoothPlastic)
		local screen = addPart(model, block, Vector3.new(3.4, 1.7, 0.02), CFrame.new(0, deskTop + 1.75, 1.58), Color3.fromRGB(22, 34, 60), Enum.Material.SmoothPlastic)
		screen.Name = "Screen"
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(340, 170)
		gui.LightInfluence = 0
		gui.Parent = screen
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(16, 10)
		title.Size = UDim2.new(1, -32, 0, 34)
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.Text = "📦 ORDER STOCK"
		title.Parent = gui
		for row = 1, 3 do
			local bar = Instance.new("Frame")
			bar.BorderSizePixel = 0
			bar.BackgroundColor3 = if row == 1 then Color3.fromRGB(110, 120, 240) else Color3.fromRGB(60, 78, 120)
			bar.Position = UDim2.fromOffset(16, 40 + row * 30)
			bar.Size = UDim2.new(1, -32, 0, 20)
			bar.Parent = gui
		end
		addPart(model, block, Vector3.new(2.2, 0.08, 0.7), CFrame.new(0, deskTop + 0.04, 0.2), CHARCOAL, Enum.Material.SmoothPlastic)
		addPart(model, block, Vector3.new(0.3, 0.08, 0.45), CFrame.new(1.6, deskTop + 0.04, 0.25), CHARCOAL, Enum.Material.SmoothPlastic)
		-- A small plant at the back corner
		addPart(model, cylinder, Vector3.new(0.6, 0.6, 0.6), CFrame.new(-2.8, deskTop + 0.3, 1.8) * UPRIGHT, WHITE, Enum.Material.SmoothPlastic)
		addPart(model, Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9), CFrame.new(-2.8, deskTop + 0.95, 1.8), HEDGE_GREEN, Enum.Material.Grass)
		-- Office chair on the room side, facing the desk
		local chairZ = -1.6
		addPart(model, cylinder, Vector3.new(0.12, 1.7, 1.7), CFrame.new(0, 0.06, chairZ) * UPRIGHT, STEEL_BLACK, Enum.Material.Metal)
		addPart(model, cylinder, Vector3.new(1.1, 0.2, 0.2), CFrame.new(0, 0.65, chairZ) * UPRIGHT, STEEL_BLACK, Enum.Material.Metal)
		addPart(model, block, Vector3.new(1.6, 0.3, 1.5), CFrame.new(0, 1.35, chairZ), CHARCOAL, Enum.Material.Fabric)
		addPart(model, block, Vector3.new(1.5, 1.8, 0.2), CFrame.new(0, 2.4, chairZ - 0.75) * CFrame.Angles(math.rad(-8), 0, 0), CHARCOAL, Enum.Material.Fabric)
	elseif slot == "Terminal" then
		-- A POS tablet on a stand, its screen tilted toward the cashier (+Z), and a card reader on the customers' side
		addPart(model, block, Vector3.new(1.1, 0.12, 0.9), CFrame.new(-0.3, 0.06, 0.15), STEEL_BLACK, Enum.Material.Metal)
		addPart(model, cylinder, Vector3.new(0.7, 0.3, 0.3), CFrame.new(-0.3, 0.47, 0.25) * UPRIGHT, STEEL_BLACK, Enum.Material.Metal)
		local tilt = CFrame.new(-0.3, 1.25, 0.25) * CFrame.Angles(math.rad(-18), math.pi, 0)
		addPart(model, block, Vector3.new(1.7, 1.1, 0.1), tilt, STEEL_BLACK, Enum.Material.SmoothPlastic)
		local screen = addPart(model, block, Vector3.new(1.55, 0.95, 0.02), tilt * CFrame.new(0, 0, -0.06), Color3.fromRGB(40, 95, 170), Enum.Material.Neon)
		screen.Name = "Screen"
		addPart(model, block, Vector3.new(0.45, 0.1, 0.7), CFrame.new(0.75, 0.05, -0.45) * CFrame.Angles(math.rad(8), 0, 0), STEEL_BLACK, Enum.Material.SmoothPlastic)
		addPart(model, block, Vector3.new(0.12, 0.02, 0.12), CFrame.new(0.75, 0.11, -0.65), Color3.fromRGB(90, 230, 140), Enum.Material.Neon)
	elseif slot == "HealingSpring" then
		-- A round stone basin with a carved rim, glowing water, a pillar and a crystal floating above it
		local radius = 5
		addPart(model, cylinder, Vector3.new(0.8, radius * 2 + 0.6, radius * 2 + 0.6), CFrame.new(0, 0.4, 0) * UPRIGHT, SPRING_TRIM, Enum.Material.Slate)
		addPart(model, cylinder, Vector3.new(1.4, radius * 2, radius * 2), CFrame.new(0, 1.1, 0) * UPRIGHT, SPRING_STONE, Enum.Material.Slate)
		-- The rim: stone blocks round the edge, every other one a little taller
		local blocks = 16
		for index = 1, blocks do
			local angle = (index / blocks) * math.pi * 2
			local tall = index % 2 == 0
			local rim = addPart(model, block, Vector3.new(2.1, if tall then 0.9 else 0.7, 0.8), CFrame.new(0, 0, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 2.0 + (if tall then 0.1 else 0), -(radius - 0.3)), if tall then SPRING_STONE else SPRING_TRIM, Enum.Material.Slate)
			rim.Name = "Rim"
		end
		local water = addPart(model, cylinder, Vector3.new(0.3, (radius - 0.7) * 2, (radius - 0.7) * 2), CFrame.new(0, 1.95, 0) * UPRIGHT, SPRING_WATER, Enum.Material.Neon)
		water.Name = "Water"
		water.Transparency = 0.25
		water.CanCollide = false
		-- The pillar: a tiered column in the middle
		addPart(model, cylinder, Vector3.new(0.6, 2.4, 2.4), CFrame.new(0, 2.3, 0) * UPRIGHT, SPRING_TRIM, Enum.Material.Slate)
		addPart(model, cylinder, Vector3.new(2.2, 1.3, 1.3), CFrame.new(0, 3.6, 0) * UPRIGHT, SPRING_STONE, Enum.Material.Slate)
		addPart(model, cylinder, Vector3.new(0.4, 2, 2), CFrame.new(0, 4.85, 0) * UPRIGHT, SPRING_TRIM, Enum.Material.Slate)
		local bowl = addPart(model, cylinder, Vector3.new(0.2, 1.6, 1.6), CFrame.new(0, 5.1, 0) * UPRIGHT, SPRING_WATER, Enum.Material.Neon)
		bowl.Name = "Water"
		bowl.CanCollide = false
				-- The crystal: a cube stood on its corner reads as a gem as it turns
		local crystal = addPart(model, block, Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, height - 0.3, 0) * CFrame.Angles(math.rad(45), 0, math.rad(35.26)), SPRING_CRYSTAL, Enum.Material.Glass)
		crystal.Transparency = 0.15
		crystal.Reflectance = 0.2
		crystal.Name = "Crystal"
		crystal.CanCollide = false
	elseif slot == "Portal" then
		local width = height * 0.85
		for _, x in { -width / 2, width / 2 } do
			addPart(model, block, Vector3.new(1.5, height, 1.5), CFrame.new(x, height / 2, 0), STONE, Enum.Material.Slate)
		end
		addPart(model, block, Vector3.new(width + 1.5, 1.5, 1.5), CFrame.new(0, height - 0.75, 0), STONE, Enum.Material.Slate)
	else
		-- CounterDecor and anything new: a plain box
		local box = size or Vector3.new(height, height, height)
		addPart(model, block, box, CFrame.new(0, box.Y / 2, 0), WOOD, Enum.Material.Wood)
	end
	model.WorldPivot = CFrame.new()
	return model
end

local function toSize(vector: Vector3): PropFit.Size
	return { x = vector.X, y = vector.Y, z = vector.Z }
end

-- Stretches a model of plain straight blocks to fill `fit` exactly, in its pivot's space. False (model untouched)
-- when any part is a mesh, a non-block shape or turned at an angle: those can only scale evenly.
local function stretch(model: Model, boxSize: Vector3, fit: Vector3, yaw: number): boolean
	local parts: { Part } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if not descendant:IsA("Part") or descendant.Shape ~= Enum.PartType.Block then
				return false
			end
			table.insert(parts, descendant)
		elseif descendant:IsA("SpecialMesh") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			return false
		end
	end
	local pivot = model.WorldPivot
	local relatives: { CFrame } = {}
	for index, part in parts do
		local relative = pivot:ToObjectSpace(part.CFrame)
		if not PropFit.isAxisAligned({ toSize(relative.RightVector), toSize(relative.UpVector), toSize(relative.LookVector) }) then
			return false
		end
		relatives[index] = relative
	end
	local sx, sy, sz = PropFit.stretchFactors(toSize(boxSize), toSize(fit), yaw)
	local scale = Vector3.new(sx, sy, sz)
	for index, part in parts do
		local relative = relatives[index]
		-- How much each of the part's own axes grows, given where it points in pivot space
		local function grow(axis: Vector3): number
			return (axis * scale).Magnitude
		end
		part.Size = Vector3.new(part.Size.X * grow(relative.RightVector), part.Size.Y * grow(relative.UpVector), part.Size.Z * grow(relative.LookVector))
		part.CFrame = pivot * (CFrame.new(relative.Position * scale) * relative.Rotation)
	end
	return true
end

-- Clone a source model and size it: to `height`, or (when `fit` is given) to the largest size that fits inside it
local function prepareModel(source: Instance, height: number, fit: Vector3?, slotYaw: number?, canStretch: boolean, roll: number?): Model
	local model: Model
	if source:IsA("Model") then
		model = source:Clone()
	else
		model = Instance.new("Model")
		local part = source:Clone()
		part.Parent = model
		local yaw = source:GetAttribute("YawOffset")
		if yaw ~= nil then
			model:SetAttribute("YawOffset", yaw)
		end
	end
	Props.strip(model)
	local yaw = PropFit.resolveYaw(model:GetAttribute("YawOffset"), slotYaw) -- degrees, for models that don't face -Z
	-- Measure along world axes: some packs save a tipped pivot (Z-up exports), which would lay the model down
	model.PrimaryPart = nil
	model.WorldPivot = CFrame.new(model:GetPivot().Position)
	if roll and roll ~= 0 then
		-- Stand the model up first (e.g. a landscape board turned portrait), then measure it upright
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, 0, math.rad(roll)))
		model.WorldPivot = CFrame.new(model:GetPivot().Position)
	end
	local boxCFrame, boxSize = model:GetBoundingBox()
	model.WorldPivot = boxCFrame * CFrame.new(0, -boxSize.Y / 2, 0) * CFrame.Angles(0, math.rad(yaw), 0)
	if fit and canStretch and stretch(model, boxSize, fit, yaw) then
		return model
	end
	local ratio = if fit
		then PropFit.fitRatio({ x = boxSize.X, y = boxSize.Y, z = boxSize.Z }, { x = fit.X, y = fit.Y, z = fit.Z }, yaw)
		else height / math.max(boxSize.Y, MIN_HEIGHT)
	model:ScaleTo(model:GetScale() * ratio)
	return model
end

-- True when assets/props holds a usable model for this slot (no stand-in needed)
function Props.hasModel(slot: string): boolean
	return #getVariants(slot) > 0
end

-- True when the slot has a real look: a model, or a code-built one (Town.SLOTS built = true)
function Props.hasLook(slot: string): boolean
	local info = Town.SLOTS[slot]
	return Props.hasModel(slot) or (info ~= nil and (info :: any).built == true)
end

-- The size a slot's model will have before scaling (first variant, turned by its yaw), or nil with no model
function Props.getSourceSize(slot: string): Vector3?
	local source = getVariants(slot)[1]
	if not source then
		return nil
	end
	local info = Town.SLOTS[slot]
	local ok, model = pcall(prepareModel, source, 1, nil, if info then (info :: any).yaw else nil, false, if info then (info :: any).roll else nil)
	if not ok then
		return nil
	end
	local _, size = model:GetBoundingBox()
	local scale = model:GetScale()
	model:Destroy()
	return size / scale
end

local function finish(model: Model, slot: string, at: CFrame, parent: Instance): Model
	local collide = Town.SLOTS[slot] ~= nil and Town.SLOTS[slot].collide
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = collide
			descendant.CanTouch = false
			descendant.CanQuery = collide
		end
	end
	model.Name = slot
	model:PivotTo(at)
	model.Parent = parent
	return model
end

local function make(slot: string, at: CFrame, parent: Instance, variant: number?, fit: Vector3?): Model
	local info = Town.SLOTS[slot]
	local height = if info then info.height else 1
	local index = variant or 1
	local variants = getVariants(slot)
	if #variants > 0 then
		local source = variants[(index - 1) % #variants + 1]
		local ok, model = pcall(prepareModel, source, height, fit, if info then (info :: any).yaw else nil, info ~= nil and (info :: any).stretch == true, if info then (info :: any).roll else nil)
		if ok then
			return finish(model, slot, at, parent)
		end
		warn(`[Props] {source.Name} failed to load, using the stand-in: {model}`)
	end
	return finish(buildFallback(slot, height, fit, index), slot, at, parent)
end

-- A prop `Town.SLOTS[slot].height` tall with its bottom centre on `at`. variant picks among the slot's files.
function Props.place(slot: string, at: CFrame, parent: Instance, variant: number?): Model
	return make(slot, at, parent, variant, nil)
end

-- The slot's model fitted onto a part that moves (a delivery box someone carries): unanchored, weightless and
-- welded to the part. Nil (the part keeps its own look) when the slot has no model.
function Props.weldFit(slot: string, part: BasePart): Model?
	if not Props.hasModel(slot) then
		return nil
	end
	local model = make(slot, part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0), part, nil, part.Size)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	return model
end

-- A prop scaled to fit inside `size`, bottom centre on `at` (Shelf on a shelf's hitbox, counter props)
function Props.fit(slot: string, size: Vector3, at: CFrame, parent: Instance, variant: number?): Model
	return make(slot, at, parent, variant, size)
end

-- The models replicate to every client: the Lune test keeps scripts out of assets/props, and the server strips
-- the source folder once at start as a second layer
if RunService:IsServer() then
	for _, folderName in SOURCE_FOLDERS do
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		if folder then
			Props.strip(folder)
		end
	end
end

return Props
