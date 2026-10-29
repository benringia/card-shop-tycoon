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

-- An upright disc (a cylinder part stood up), centred at height y
local function disc(model: Model, radius: number, height: number, y: number, color: Color3, material: Enum.Material): Part
	return addPart(model, Enum.PartType.Cylinder, Vector3.new(height, radius * 2, radius * 2), CFrame.new(0, y, 0) * UPRIGHT, color, material)
end

-- A ring of `count` small cards circling the machine's axis at height y: a Rotor of its own (CondenserFxController
-- spins it `spin` times the usual speed, a minus turning it the other way, and bobs it `phase` seconds out of step)
local function cardRing(model: Model, y: number, count: number, radius: number, size: { number }, color: Color3, spin: number, phase: number)
	local rotor = Instance.new("Model")
	rotor.Name = "Rotor"
	rotor:SetAttribute("RotorY", y)
	rotor:SetAttribute("Spin", spin)
	rotor:SetAttribute("Phase", phase)
	local hub = Instance.new("Part")
	hub.Name = "Hub"
	hub.Size = Vector3.one * 0.1
	hub.Transparency = 1
	hub.CFrame = CFrame.new(0, y, 0)
	hub.Parent = rotor
	for index = 1, count do
		local angle = (index - 1) * math.pi * 2 / count
		local card = Instance.new("Part")
		card.Name = "Card"
		card.Size = Vector3.new(size[1], size[2], 0.03)
		card.CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius) * CFrame.Angles(math.rad(12), 0, 0)
		card.Color = color
		card.Material = Enum.Material.SmoothPlastic
		card.Parent = rotor
	end
	rotor.PrimaryPart = hub
	rotor.Parent = model
end

-- A dark strip with a word in light on a round body's front (flat, so its middle stands just proud of the curve)
local function frontStrip(model: Model, radius: number, y: number, width: number, text: string, color: Color3)
	local strip = addPart(model, Enum.PartType.Block, Vector3.new(width, 0.38, 0.08), CFrame.new(0, y, -radius - 0.03), Color3.fromRGB(28, 32, 46), Enum.Material.SmoothPlastic)
	strip.Name = "Screen"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(width * 300, 114)
	gui.LightInfluence = 0
	gui.Parent = strip
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
end

-- The Card Condenser (Town.CONDENSER_LOOK), bottom centre at the origin, front -Z, in the Grading Station's style: a
-- dark plinth with a violet rim, a white body with a light band, a card slot and a CONDENSER strip, a see-through
-- chamber with a glowing floor, a white cap. Its Rotors (the crystal with three cards, and a ring of small cards
-- below it and one above it turning the other way) are Models of their own that CondenserFxController moves.
local function buildCondenser(model: Model)
	local look = Town.CONDENSER_LOOK
	local block = Enum.PartType.Block
	local shell, dark, glow = Props.color(look.SHELL), Props.color(look.DARK), Props.color(look.GLOW)
	local cardColor = Props.color(look.CARD)
	local plinthTop = look.PLINTH_HEIGHT
	local baseTop = look.BASE_HEIGHT
	disc(model, look.BASE_RADIUS, plinthTop, plinthTop / 2, dark, Enum.Material.SmoothPlastic)
	disc(model, look.BASE_RADIUS + 0.03, 0.07, 0.06, glow, Enum.Material.Neon)
	disc(model, look.BODY_RADIUS, baseTop - plinthTop, (plinthTop + baseTop) / 2, shell, Enum.Material.SmoothPlastic).Reflectance = 0.08
	disc(model, look.BODY_RADIUS + 0.02, 0.08, baseTop - 0.15, glow, Enum.Material.Neon)
	-- Front: the card slot glowing inside, and the name strip
	addPart(model, block, Vector3.new(1.2, 0.12, 0.1), CFrame.new(0, baseTop - 0.4, -look.BODY_RADIUS - 0.02), dark, Enum.Material.SmoothPlastic)
	addPart(model, block, Vector3.new(1.05, 0.04, 0.11), CFrame.new(0, baseTop - 0.4, -look.BODY_RADIUS - 0.03), glow, Enum.Material.Neon).Name = "CardSlot"
	frontStrip(model, look.BODY_RADIUS, plinthTop + 0.3, 1.7, look.SCREEN_TEXT, glow:Lerp(Color3.new(1, 1, 1), 0.4))
	-- The chamber: an emitter ring, see-through walls, a glowing floor
	local chamberY = baseTop + look.CHAMBER_HEIGHT / 2
	disc(model, look.CHAMBER_RADIUS + 0.15, 0.12, baseTop + 0.06, dark, Enum.Material.SmoothPlastic)
	disc(model, look.CHAMBER_RADIUS + 0.19, 0.05, baseTop + 0.1, glow, Enum.Material.Neon)
	local glass = disc(model, look.CHAMBER_RADIUS, look.CHAMBER_HEIGHT, chamberY, Props.color(look.GLASS), Enum.Material.SmoothPlastic)
	glass.Name = "Glass"
	glass.Transparency = look.GLASS_TRANSPARENCY
	glass.Reflectance = 0.15
	glass.CastShadow = false
	disc(model, look.CHAMBER_RADIUS * 0.85, 0.04, baseTop + 0.14, glow, Enum.Material.Neon).Transparency = look.FLOOR_TRANSPARENCY
	-- The cap: white, a violet ring under it, a dark top
	local capY = baseTop + look.CHAMBER_HEIGHT + look.CAP_HEIGHT / 2
	disc(model, look.CHAMBER_RADIUS + 0.2, look.CAP_HEIGHT, capY, shell, Enum.Material.SmoothPlastic)
	disc(model, look.CHAMBER_RADIUS + 0.23, 0.06, capY - look.CAP_HEIGHT / 2 - 0.02, glow, Enum.Material.Neon)
	disc(model, 0.85, 0.15, capY + look.CAP_HEIGHT / 2 + 0.07, dark, Enum.Material.SmoothPlastic)

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
		card.Color = cardColor
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
	-- The outer rings: small cards below and above the crystal, turning the other way, bobbing out of step
	cardRing(model, chamberY - look.RING_RISE, look.RING_CARDS, look.RING_RADIUS, look.RING_CARD, cardColor, look.RING_SPIN, 0.8)
	cardRing(model, chamberY + look.RING_RISE, look.RING_CARDS, look.RING_RADIUS, look.RING_CARD, cardColor, look.RING_SPIN, 1.6)
end

-- The Grading Station (Town.GRADING_LOOK), bottom centre at the origin, front -Z: a futuristic scan pod. A dark
-- plinth with a glowing rim, a white body with a light band, a slot and a GRADING strip; on top an emitter under a
-- see-through column with a beam of light, where the Rotor (a gold card and the grade hologram over the cap) floats,
-- spun and bobbed on each client by CondenserFxController
local function buildGradingStation(model: Model)
	local look = Town.GRADING_LOOK
	local block = Enum.PartType.Block
	local shell, dark, glow = Props.color(look.SHELL), Props.color(look.DARK), Props.color(look.GLOW)
	-- Plinth and body, each with a thin glowing ring just proud of its side
	local plinthTop = look.PLINTH_HEIGHT
	disc(model, look.PLINTH_RADIUS, look.PLINTH_HEIGHT, plinthTop / 2, dark, Enum.Material.SmoothPlastic)
	disc(model, look.PLINTH_RADIUS + 0.03, 0.07, 0.06, glow, Enum.Material.Neon)
	local bodyTop = plinthTop + look.BODY_HEIGHT
	disc(model, look.BODY_RADIUS, look.BODY_HEIGHT, plinthTop + look.BODY_HEIGHT / 2, shell, Enum.Material.SmoothPlastic).Reflectance = 0.08
	disc(model, look.BODY_RADIUS + 0.02, 0.08, bodyTop - 0.55, glow, Enum.Material.Neon)
	-- Front: a card slot with a glow inside, and a dark strip with the name in light
	local frontZ = -look.BODY_RADIUS + 0.02
	addPart(model, block, Vector3.new(1.2, 0.14, 0.1), CFrame.new(0, bodyTop - 0.4, frontZ), dark, Enum.Material.SmoothPlastic)
	addPart(model, block, Vector3.new(1.05, 0.05, 0.11), CFrame.new(0, bodyTop - 0.4, frontZ - 0.005), glow, Enum.Material.Neon)
	frontStrip(model, look.BODY_RADIUS, plinthTop + 0.65, 1.6, look.SCREEN_TEXT, glow)
	-- The emitter, the see-through column with its beam, and the cap
	disc(model, look.EMITTER_RADIUS, 0.14, bodyTop + 0.07, dark, Enum.Material.SmoothPlastic)
	disc(model, look.EMITTER_RADIUS + 0.04, 0.05, bodyTop + 0.12, glow, Enum.Material.Neon)
	local columnMid = bodyTop + look.COLUMN_HEIGHT / 2
	local column = disc(model, look.COLUMN_RADIUS, look.COLUMN_HEIGHT, columnMid, Props.color(look.GLASS), Enum.Material.SmoothPlastic)
	column.Transparency = look.GLASS_TRANSPARENCY
	column.Reflectance = 0.15
	local beam = disc(model, look.BEAM_RADIUS, look.COLUMN_HEIGHT - 0.1, columnMid, glow, Enum.Material.Neon)
	beam.Transparency = look.BEAM_TRANSPARENCY
	local capY = bodyTop + look.COLUMN_HEIGHT + look.CAP_HEIGHT / 2
	disc(model, look.CAP_RADIUS, look.CAP_HEIGHT, capY, shell, Enum.Material.SmoothPlastic)
	disc(model, look.CAP_RADIUS + 0.03, 0.05, capY - look.CAP_HEIGHT / 2 - 0.02, glow, Enum.Material.Neon)
	-- Rotor: the floating card, and the grade hologram over the cap (a billboard, so the spin doesn't turn it)
	local rotor = Instance.new("Model")
	rotor.Name = "Rotor"
	rotor:SetAttribute("RotorY", columnMid)
	local card = Instance.new("Part")
	card.Name = "Card"
	card.Size = Vector3.new(look.CARD_SIZE[1], look.CARD_SIZE[2], 0.03)
	card.CFrame = CFrame.new(0, columnMid, 0)
	card.Color = Props.color(look.CARD)
	card.Material = Enum.Material.Neon
	card.Parent = rotor
	local holo = Instance.new("Part")
	holo.Name = "Hologram"
	holo.Size = Vector3.new(0.2, 0.2, 0.2)
	holo.Transparency = 1
	holo.CFrame = CFrame.new(0, capY + look.CAP_HEIGHT / 2 + look.HOLO_SIZE / 2 + 0.15, 0)
	holo.Parent = rotor
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(look.HOLO_SIZE, look.HOLO_SIZE)
	board.LightInfluence = 0
	board.MaxDistance = 90
	board.Parent = holo
	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromScale(0.9, 0.9)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.BackgroundColor3 = glow
	ring.BackgroundTransparency = 0.85
	ring.Parent = board
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = ring
	local edge = Instance.new("UIStroke")
	edge.Color = glow
	edge.Thickness = 3
	edge.Transparency = 0.15
	edge.Parent = ring
	local letter = Instance.new("TextLabel")
	letter.BackgroundTransparency = 1
	letter.Size = UDim2.fromScale(0.7, 0.7)
	letter.AnchorPoint = Vector2.new(0.5, 0.5)
	letter.Position = UDim2.fromScale(0.5, 0.5)
	letter.Font = Enum.Font.FredokaOne
	letter.TextScaled = true
	letter.TextColor3 = glow:Lerp(Color3.new(1, 1, 1), 0.35)
	letter.TextTransparency = 0.1
	letter.Text = look.HOLO_TEXT
	letter.Parent = ring
	rotor.PrimaryPart = card
	rotor.Parent = model
	-- Two rings of small cards circling the beam the other way, below and above the middle card
	local cardColor = Props.color(look.CARD)
	cardRing(model, columnMid - look.ORBIT_RISE, look.ORBIT_CARDS, look.ORBIT_RADIUS, look.ORBIT_CARD, cardColor, look.ORBIT_SPIN, 0.7)
	cardRing(model, columnMid + look.ORBIT_RISE, look.ORBIT_CARDS, look.ORBIT_RADIUS, look.ORBIT_CARD, cardColor, look.ORBIT_SPIN, 1.4)
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
