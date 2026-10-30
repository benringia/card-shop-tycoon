--!strict
-- The Card Festival Square (the user's pick C, 2026-10-30; placements in Config/Plaza, Util/PlazaLayout): a white
-- gazebo with a stepped turquoise dome over the healing fountain, a fan of five giant cards with real card art and gold
-- rims facing where new players appear, three market stalls with striped awnings, six cafe tables, string lights from
-- the gazebo's rim to eight lamp posts, four potted trees. Built once at server start by SceneryService; main game only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CardDesign = require(Config:WaitForChild("CardDesign"))
local Plaza = require(Config:WaitForChild("Plaza"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Wild = require(Config:WaitForChild("Wild"))
local PlazaLayout = require(Shared:WaitForChild("Util"):WaitForChild("PlazaLayout"))
local ScenePieces = require(script.Parent:WaitForChild("ScenePieces"))

local PlazaBuild = {}

local piece = ScenePieces.piece
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X: stand them up

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function centre(): Vector3
	return Vector3.new(Wild.SPRING.x, 0, Wild.SPRING.z)
end

local function at(angle: number, r: number): Vector3
	local p = PlazaLayout.at(angle, r)
	return centre() + Vector3.new(p.x, 0, p.z)
end

-- No collisions, no shadow: trims, lights and small details
local function detail(part: BasePart): BasePart
	part.CanCollide = false
	part.CastShadow = false
	return part
end

local function buildGazebo(parent: Instance)
	local g = Plaza.GAZEBO
	local model = Instance.new("Model")
	model.Name = "Gazebo"
	local base = centre()
	local white, trim, gold = rgb(g.white), rgb(g.trim), rgb(g.gold)
	local floor = g.platform.height
	piece(model, "Platform", Vector3.new(g.platform.height, g.platform.radius * 2, g.platform.radius * 2), CFrame.new(base + Vector3.new(0, g.platform.height / 2, 0)) * UPRIGHT, white, Enum.Material.Limestone, Enum.PartType.Cylinder)
	-- A gold band round the platform's edge: a slightly wider disc just under its top, so only the rim shows
	detail(piece(model, "PlatformEdge", Vector3.new(0.16, g.platform.radius * 2 + 0.3, g.platform.radius * 2 + 0.3), CFrame.new(base + Vector3.new(0, g.platform.height - 0.13, 0)) * UPRIGHT, gold, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder))
	local top = floor + g.postHeight
	local corners = {}
	for index = 1, g.posts do
		local angle = (index - 0.5) / g.posts * 360
		local p = at(angle, g.radius)
		table.insert(corners, p)
		piece(model, "ColumnBase", Vector3.new(g.postSize * 1.5, 0.6, g.postSize * 1.5), CFrame.new(p + Vector3.new(0, floor + 0.3, 0)), trim, Enum.Material.SmoothPlastic)
		piece(model, "Column", Vector3.new(g.postHeight - 1.2, g.postSize, g.postSize), CFrame.new(p + Vector3.new(0, floor + g.postHeight / 2, 0)) * UPRIGHT, white, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		piece(model, "ColumnCap", Vector3.new(g.postSize * 1.5, 0.6, g.postSize * 1.5), CFrame.new(p + Vector3.new(0, top - 0.3, 0)), trim, Enum.Material.SmoothPlastic)
	end
	-- The beam round the column tops, a gold band under it
	for index, a in corners do
		local b = corners[index % #corners + 1]
		local length = (b - a).Magnitude + g.postSize
		local mid = (a + b) / 2
		piece(model, "Ring", Vector3.new(g.postSize * 1.3, g.ring, length), CFrame.lookAt(mid, b) + Vector3.new(0, top + g.ring / 2, 0), white, Enum.Material.SmoothPlastic)
		detail(piece(model, "RingBand", Vector3.new(g.postSize * 1.35, 0.18, length), CFrame.lookAt(mid, b) + Vector3.new(0, top + 0.1, 0), gold, Enum.Material.SmoothPlastic))
	end
	-- The dome: stepped discs, each a shade lighter going up, then a lantern and a gold finial
	local y = top + g.ring
	for index, tier in g.dome do
		local radius, height = tier[1], tier[2]
		local shade = rgb(g.roofDark):Lerp(rgb(g.roof), (index - 1) / math.max(#g.dome - 1, 1))
		piece(model, "Dome", Vector3.new(height, radius * 2, radius * 2), CFrame.new(base + Vector3.new(0, y + height / 2, 0)) * UPRIGHT, shade, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		y += height
	end
	local lantern = piece(model, "Lantern", Vector3.new(g.lantern, g.lantern, g.lantern), CFrame.new(base + Vector3.new(0, y + g.lantern / 2, 0)), rgb(g.light.color), Enum.Material.Neon)
	detail(lantern)
	piece(model, "Finial", Vector3.new(0.9, 0.9, 0.9), CFrame.new(base + Vector3.new(0, y + g.lantern + 0.45, 0)), gold, Enum.Material.Metal, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = rgb(g.light.color)
	light.Brightness = g.light.brightness
	light.Range = g.light.range
	light.Shadows = false
	light.Parent = ScenePieces.anchor(model, "GazeboLight", base + Vector3.new(0, top - 1.5, 0))
	model.Parent = parent
end

-- One giant card: gold, its art inset with a rim in its rarity colour; the card back on the other side
local function giantCard(parent: Instance, spec: any, cframe: CFrame)
	local fan = Plaza.FAN
	local width = spec.height / 1.4
	local card = piece(parent, "GiantCard", Vector3.new(width, spec.height, 0.3), cframe, rgb(fan.gold), Enum.Material.Metal)
	card.CastShadow = true
	local tier = (Rarities.Tiers :: any)[spec.rarity]
	local rim = if tier then tier.color else Color3.new(1, 1, 1)
	local front = Instance.new("SurfaceGui")
	front.Face = Enum.NormalId.Front
	front.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	front.PixelsPerStud = fan.pixelsPerStud
	front.LightInfluence = 0.3
	front.MaxDistance = fan.distance
	front.Parent = card
	local art = Instance.new("ImageLabel")
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(0.86, 0.9)
	art.BackgroundColor3 = rim
	art.Image = (CardDesign.ART_IMAGES :: any)[spec.card] or ""
	art.ScaleType = Enum.ScaleType.Crop
	art.Parent = front
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.05, 0)
	corner.Parent = art
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = rim
	stroke.Thickness = 6
	stroke.Parent = art
	local back = Instance.new("SurfaceGui")
	back.Face = Enum.NormalId.Back
	back.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	back.PixelsPerStud = fan.pixelsPerStud
	back.LightInfluence = 0.3
	back.MaxDistance = fan.distance
	back.Parent = card
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.86, 0.9)
	panel.BackgroundColor3 = rgb(fan.back)
	panel.Parent = back
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0.05, 0)
	backCorner.Parent = panel
	if spec.rarity == "Legendary" then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(rim)
		sparkles.LightEmission = 1
		sparkles.Rate = 6
		sparkles.Lifetime = NumberRange.new(1, 1.8)
		sparkles.Speed = NumberRange.new(0.3, 0.8)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.4, 0)
		sparkles.Parent = card
	end
end

local function buildFan(parent: Instance)
	local fan = Plaza.FAN
	local model = Instance.new("Model")
	model.Name = "CardFan"
	local middle = at(fan.angle, fan.r)
	local face = Vector3.new(fan.face.x, 0, fan.face.z)
	local facing = CFrame.lookAt(middle, face)
	local cards = PlazaLayout.fanCards(Plaza)
	-- A long stone plinth under all five, a gold band along its top
	local base = fan.base
	local width = (#cards - 1) * fan.step + 4
	local plinth = facing * CFrame.new(0, base.height / 2, fan.depthStep)
	piece(model, "Plinth", Vector3.new(width, base.height, base.depth), plinth, rgb(base.color), Enum.Material.Limestone)
	detail(piece(model, "PlinthBand", Vector3.new(width + 0.16, 0.2, base.depth + 0.16), plinth * CFrame.new(0, base.height / 2 - 0.16, 0), rgb(fan.gold), Enum.Material.Metal))
	for index, spec in fan.cards do
		local card = cards[index]
		local foot = CFrame.lookAt(Vector3.new(card.x, 0, card.z) + centre() * Vector3.new(1, 0, 1), Vector3.new(card.x, 0, card.z) + centre() * Vector3.new(1, 0, 1) + facing.LookVector)
		-- Leaning out from its foot (and a little back), so the five open like a hand of cards
		local stand = foot * CFrame.new(0, base.height, 0) * CFrame.Angles(0, 0, math.rad(card.lean)) * CFrame.Angles(math.rad(-fan.tilt), 0, 0)
		giantCard(model, spec, stand * CFrame.new(0, card.height / 2, 0))
	end
	model.Parent = parent
end

local function buildStall(parent: Instance, spec: any)
	local s = Plaza.STALL
	local model = Instance.new("Model")
	model.Name = "MarketStall"
	local spot = at(spec.angle, spec.r)
	local frame = CFrame.lookAt(spot, centre()) -- its counter faces the gazebo
	local color, wood, white = rgb(spec.color), rgb(s.wood), rgb(s.stripe)
	piece(model, "Counter", Vector3.new(s.width, s.counter - 0.3, s.depth), frame * CFrame.new(0, (s.counter - 0.3) / 2, 0), color:Lerp(Color3.new(1, 1, 1), 0.35), Enum.Material.SmoothPlastic)
	piece(model, "CounterTop", Vector3.new(s.width + 0.4, 0.3, s.depth + 0.4), frame * CFrame.new(0, s.counter - 0.15, -0.1), wood, Enum.Material.Wood)
	detail(piece(model, "CounterStripe", Vector3.new(s.width + 0.02, 0.3, 0.05), frame * CFrame.new(0, s.counter * 0.55, -s.depth / 2 - 0.02), color, Enum.Material.SmoothPlastic))
	for _, x in { -s.width / 2 + 0.2, s.width / 2 - 0.2 } do
		for _, z in { -s.depth / 2 - 0.1, s.depth / 2 + 0.6 } do
			piece(model, "Post", Vector3.new(0.3, s.postHeight, 0.3), frame * CFrame.new(x, s.postHeight / 2, z), wood, Enum.Material.Wood)
		end
	end
	-- The striped awning tips down toward the front
	local length = s.depth + 2.2
	local stripeWidth = (s.width + 0.6) / s.stripes
	for index = 1, s.stripes do
		local x = -(s.width + 0.6) / 2 + (index - 0.5) * stripeWidth
		local stripe = piece(model, "Awning", Vector3.new(stripeWidth, 0.15, length), frame * CFrame.new(x, s.postHeight + 0.35, -0.2) * CFrame.Angles(math.rad(s.slope), 0, 0), if index % 2 == 1 then color else white, Enum.Material.Fabric)
		stripe.CastShadow = true
	end
	model.Parent = parent
end

local function buildTable(parent: Instance, angle: number)
	local t = Plaza.TABLE
	local model = Instance.new("Model")
	model.Name = "CafeTable"
	local spot = at(angle, Plaza.TABLES.r)
	local top = t.top
	piece(model, "TableTop", Vector3.new(0.2, top.radius * 2, top.radius * 2), CFrame.new(spot + Vector3.new(0, top.height, 0)) * UPRIGHT, rgb(t.white), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	piece(model, "TablePole", Vector3.new(top.height, 0.25, 0.25), CFrame.new(spot + Vector3.new(0, top.height / 2, 0)) * UPRIGHT, rgb(t.metal), Enum.Material.Metal, Enum.PartType.Cylinder)
	detail(piece(model, "TableFoot", Vector3.new(0.15, 1.5, 1.5), CFrame.new(spot + Vector3.new(0, 0.08, 0)) * UPRIGHT, rgb(t.metal), Enum.Material.Metal, Enum.PartType.Cylinder))
	for index = 1, t.chairs do
		local a = math.rad(angle * 7 + index / t.chairs * 360)
		local place = spot + Vector3.new(math.cos(a), 0, math.sin(a)) * t.chairRadius
		local chair = CFrame.lookAt(place, Vector3.new(spot.X, 0, spot.Z))
		piece(model, "Seat", Vector3.new(1.1, 0.25, 1.1), chair * CFrame.new(0, 1.6, 0), rgb(t.wood), Enum.Material.Wood)
		piece(model, "ChairBack", Vector3.new(1.1, 1.3, 0.18), chair * CFrame.new(0, 2.35, 0.5), rgb(t.wood), Enum.Material.Wood)
		detail(piece(model, "ChairLeg", Vector3.new(1.5, 0.2, 0.2), chair * CFrame.new(0, 0.75, 0) * UPRIGHT, rgb(t.metal), Enum.Material.Metal, Enum.PartType.Cylinder))
	end
	model.Parent = parent
end

-- A lamp post at the rim and a string of warm bulbs sagging from the gazebo's rim to it
local function buildLampAndLights(parent: Instance, angle: number)
	local lamps, lights = Plaza.LAMPS, Plaza.LIGHTS
	local model = Instance.new("Model")
	model.Name = "StringLights"
	local spot = at(angle, lamps.r)
	local metal = Color3.fromRGB(46, 48, 56)
	piece(model, "LampBase", Vector3.new(0.5, 1, 1), CFrame.new(spot + Vector3.new(0, 0.25, 0)) * UPRIGHT, metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	piece(model, "LampPost", Vector3.new(lamps.height, 0.35, 0.35), CFrame.new(spot + Vector3.new(0, lamps.height / 2, 0)) * UPRIGHT, metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	detail(piece(model, "LampGlow", Vector3.new(0.9, 1.1, 0.9), CFrame.new(spot + Vector3.new(0, lamps.height + 0.4, 0)), rgb(lights.color), Enum.Material.Neon))
	piece(model, "LampCap", Vector3.new(1.3, 0.3, 1.3), CFrame.new(spot + Vector3.new(0, lamps.height + 1.1, 0)), metal, Enum.Material.Metal)
	local fromPoint = at(angle, lights.from.r) + Vector3.new(0, lights.from.y, 0)
	local toPoint = spot + Vector3.new(0, lamps.height + 0.4, 0)
	-- The wire: a Beam whose ends point straight down, so CurveSize makes it sag (the bulbs follow the same curve)
	local holder = ScenePieces.anchor(model, "Wire", fromPoint)
	local function hook(point: Vector3): Attachment
		local attachment = Instance.new("Attachment")
		attachment.Parent = holder
		attachment.WorldCFrame = CFrame.fromMatrix(point, Vector3.new(0, -1, 0), Vector3.new(1, 0, 0))
		return attachment
	end
	local wire = Instance.new("Beam")
	wire.Attachment0 = hook(fromPoint)
	wire.Attachment1 = hook(toPoint)
	wire.CurveSize0 = PlazaLayout.curveFor(lights.sag)
	wire.CurveSize1 = -PlazaLayout.curveFor(lights.sag)
	wire.Width0 = 0.08
	wire.Width1 = 0.08
	wire.Segments = 16
	wire.Color = ColorSequence.new(rgb(lights.wire))
	wire.LightInfluence = 1
	wire.FaceCamera = true
	wire.Parent = holder
	local bulbs = PlazaLayout.stringLight(
		{ x = fromPoint.X, y = fromPoint.Y, z = fromPoint.Z },
		{ x = toPoint.X, y = toPoint.Y, z = toPoint.Z },
		lights.sag,
		lights.spacing
	)
	for _, bulb in bulbs do
		detail(piece(model, "Bulb", Vector3.new(lights.bulb, lights.bulb, lights.bulb), CFrame.new(bulb.x, bulb.y - 0.2, bulb.z), rgb(lights.color), Enum.Material.Neon, Enum.PartType.Ball))
	end
	model.Parent = parent
end

local function buildTrees(parent: Instance)
	local planter = Plaza.PLANTER
	for _, tree in Plaza.TREES do
		local spot = at(tree.angle, tree.r)
		piece(parent, "Planter", Vector3.new(planter.height, planter.radius * 2, planter.radius * 2), CFrame.new(spot + Vector3.new(0, planter.height / 2, 0)) * UPRIGHT, rgb(planter.color), Enum.Material.Slate, Enum.PartType.Cylinder)
		ScenePieces.placeModel(parent, { model = tree.model, x = spot.X, z = spot.Z, height = tree.height, yaw = tree.angle }, "PottedTree", planter.height)
	end
end

function PlazaBuild.build(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "FestivalSquare"
	buildGazebo(folder)
	buildFan(folder)
	for _, stall in Plaza.STALLS do
		buildStall(folder, stall)
	end
	for _, angle in Plaza.TABLES.angles do
		buildTable(folder, angle)
	end
	for _, angle in Plaza.LAMPS.angles do
		buildLampAndLights(folder, angle)
	end
	buildTrees(folder)
	folder.Parent = parent
end

return PlazaBuild
