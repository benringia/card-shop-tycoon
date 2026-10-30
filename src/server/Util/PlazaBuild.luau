--!strict
-- The Card Festival Square (the user's pick C, 2026-10-30; placements in Config/Plaza, Util/PlazaLayout): a cream
-- gazebo with a stepped teal tiled dome over the healing fountain (WildService builds the fountain), a fan of five
-- giant cards with real card art and gold rims facing where new players appear, three festival carts with striped
-- canopies, six cafe tables with townsfolk sitting at three (PlazaNpcController makes them sip), string lights from the
-- gazebo's rim to eight lamp posts, and curved planters of bushes and flowers along the edge holding the lamps and four
-- trees. Built once at server start by SceneryService; main game only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CardDesign = require(Config:WaitForChild("CardDesign"))
local Customers = require(Config:WaitForChild("Customers"))
local Plaza = require(Config:WaitForChild("Plaza"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Wild = require(Config:WaitForChild("Wild"))
local PlazaLayout = require(Shared:WaitForChild("Util"):WaitForChild("PlazaLayout"))
local NpcMotion = require(script.Parent:WaitForChild("NpcMotion"))
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
	local stone, trim, gold = rgb(g.stone), rgb(g.trim), rgb(g.gold)
	local columnMaterial = (Enum.Material :: any)[g.columnMaterial]
	local floor = g.platform.height
	piece(model, "Platform", Vector3.new(g.platform.height, g.platform.radius * 2, g.platform.radius * 2), CFrame.new(base + Vector3.new(0, g.platform.height / 2, 0)) * UPRIGHT, rgb(g.platformStone), Enum.Material.Limestone, Enum.PartType.Cylinder)
	piece(model, "Inlay", Vector3.new(0.04, g.inlay.radius * 2, g.inlay.radius * 2), CFrame.new(base + Vector3.new(0, g.platform.height + 0.02, 0)) * UPRIGHT, rgb(g.inlay.color), Enum.Material.Slate, Enum.PartType.Cylinder)
	-- A gold band round the platform's edge: a slightly wider disc just under its top, so only the rim shows
	detail(piece(model, "PlatformEdge", Vector3.new(0.16, g.platform.radius * 2 + 0.3, g.platform.radius * 2 + 0.3), CFrame.new(base + Vector3.new(0, g.platform.height - 0.13, 0)) * UPRIGHT, gold, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder))
	local top = floor + g.postHeight
	local corners = {}
	for index = 1, g.posts do
		local angle = (index - 0.5) / g.posts * 360
		local p = at(angle, g.radius)
		table.insert(corners, p)
		piece(model, "ColumnBase", Vector3.new(g.postSize * 1.5, 0.6, g.postSize * 1.5), CFrame.new(p + Vector3.new(0, floor + 0.3, 0)), trim, columnMaterial)
		piece(model, "Column", Vector3.new(g.postHeight - 1.2, g.postSize, g.postSize), CFrame.new(p + Vector3.new(0, floor + g.postHeight / 2, 0)) * UPRIGHT, stone, columnMaterial, Enum.PartType.Cylinder)
		piece(model, "ColumnCap", Vector3.new(g.postSize * 1.5, 0.6, g.postSize * 1.5), CFrame.new(p + Vector3.new(0, top - 0.3, 0)), trim, columnMaterial)
	end
	-- The beam round the column tops, a gold band under it
	for index, a in corners do
		local b = corners[index % #corners + 1]
		local length = (b - a).Magnitude + g.postSize
		local mid = (a + b) / 2
		piece(model, "Ring", Vector3.new(g.postSize * 1.3, g.ring, length), CFrame.lookAt(mid, b) + Vector3.new(0, top + g.ring / 2, 0), stone, columnMaterial)
		detail(piece(model, "RingBand", Vector3.new(g.postSize * 1.35, 0.18, length), CFrame.lookAt(mid, b) + Vector3.new(0, top + 0.1, 0), gold, Enum.Material.SmoothPlastic))
	end
	-- The dome: stepped discs, each a shade lighter going up, then a lantern and a gold finial
	local y = top + g.ring
	for index, tier in g.dome do
		local radius, height = tier[1], tier[2]
		local shade = rgb(g.roofDark):Lerp(rgb(g.roof), (index - 1) / math.max(#g.dome - 1, 1))
		piece(model, "Dome", Vector3.new(height, radius * 2, radius * 2), CFrame.new(base + Vector3.new(0, y + height / 2, 0)) * UPRIGHT, shade, (Enum.Material :: any)[g.roofMaterial], Enum.PartType.Cylinder)
		y += height
	end
	local lantern = piece(model, "Lantern", Vector3.new(g.lantern, g.lantern, g.lantern), CFrame.new(base + Vector3.new(0, y + g.lantern / 2, 0)), rgb(g.light.color), Enum.Material.Neon)
	detail(lantern)
	local finial = piece(model, "Finial", Vector3.new(0.9, 0.9, 0.9), CFrame.new(base + Vector3.new(0, y + g.lantern + 0.45, 0)), gold, Enum.Material.Metal, Enum.PartType.Ball)
	local elements = Plaza.FOUNTAIN.elements
	local keys = {}
	for index, element in elements do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#elements - 1), rgb(element.color)))
	end
	local beacon = Instance.new("ParticleEmitter")
	beacon.Name = "Beacon"
	beacon.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beacon.Color = ColorSequence.new(keys)
	beacon.LightEmission = 1
	beacon.Rate = g.beacon.rate
	beacon.Lifetime = NumberRange.new(g.beacon.lifetime[1], g.beacon.lifetime[2])
	beacon.Speed = NumberRange.new(g.beacon.speed[1], g.beacon.speed[2])
	beacon.SpreadAngle = Vector2.new(g.beacon.spread, g.beacon.spread)
	beacon.Size = NumberSequence.new(g.beacon.size, 0)
	beacon.RotSpeed = NumberRange.new(-60, 60)
	beacon.EmissionDirection = Enum.NormalId.Top
	beacon.Parent = finial
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

-- A big spoked wheel standing in the cart's XY plane at `hub` (its axle along the cart's Z): a ring of tyre blocks,
-- spokes and a hub
local function buildWheel(model: Model, hub: CFrame)
	local w = Plaza.STALL.wheel
	local wood, dark = rgb(Plaza.STALL.wood), rgb(Plaza.STALL.woodDark)
	local chord = 2 * w.radius * math.sin(math.pi / w.segments) + 0.06
	for index = 1, w.segments do
		local turn = CFrame.Angles(0, 0, (index - 0.5) / w.segments * math.pi * 2)
		piece(model, "Tyre", Vector3.new(chord, w.tire, w.thickness), hub * turn * CFrame.new(0, w.radius - w.tire / 2, 0), dark, Enum.Material.Wood)
	end
	for index = 1, w.spokes do
		local turn = CFrame.Angles(0, 0, index / w.spokes * math.pi * 2)
		detail(piece(model, "Spoke", Vector3.new(0.14, w.radius - w.tire, 0.14), hub * turn * CFrame.new(0, (w.radius - w.tire) / 2, 0), wood, Enum.Material.Wood))
	end
	piece(model, "Hub", Vector3.new(w.thickness * 1.8, 0.5, 0.5), hub * CFrame.Angles(0, math.rad(90), 0), rgb(Plaza.STALL.gold), Enum.Material.Metal, Enum.PartType.Cylinder)
end

-- A chalkboard on an A-frame, the stall's word on it, facing the gazebo
local function buildEasel(model: Model, frame: CFrame, word: string)
	local s = Plaza.STALL
	local e = s.easel
	local stand = frame * CFrame.new(e.x, 0, e.z)
	local lean = CFrame.Angles(math.rad(-12), 0, 0)
	local board = piece(model, "Chalkboard", Vector3.new(e.width, e.height, 0.08), stand * CFrame.new(0, 0.35 + e.height / 2, 0) * lean, rgb(s.slate), Enum.Material.Slate)
	detail(piece(model, "ChalkboardFrame", Vector3.new(e.width + 0.14, e.height + 0.14, 0.06), board.CFrame * CFrame.new(0, 0, 0.05), rgb(s.wood), Enum.Material.Wood))
	for _, side in { -1, 1 } do
		detail(piece(model, "EaselLeg", Vector3.new(0.1, e.height + 0.5, 0.1), stand * CFrame.new(side * (e.width / 2 - 0.05), (e.height + 0.5) / 2, 0.25) * CFrame.Angles(math.rad(14), 0, 0), rgb(s.woodDark), Enum.Material.Wood))
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.MaxDistance = 80
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.5)
	label.Position = UDim2.fromScale(0.05, 0.25)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(250, 248, 240)
	label.Text = word
	label.Parent = gui
end

-- A festival cart (Plaza.STALL) facing the gazebo: -Z is its front, toward the customers
local function buildStall(parent: Instance, spec: any)
	local s = Plaza.STALL
	local model = Instance.new("Model")
	model.Name = "FestivalCart"
	local spot = at(spec.angle, spec.r)
	local frame = CFrame.lookAt(spot, centre())
	local color, wood, dark, white, gold = rgb(spec.color), rgb(s.wood), rgb(s.woodDark), rgb(s.stripe), rgb(s.gold)
	local body = s.body
	local counter = body.bottom + body.height + s.top.thickness
	piece(model, "CartBox", Vector3.new(body.width, body.height, body.depth), frame * CFrame.new(0, body.bottom + body.height / 2, 0), wood, Enum.Material.Wood)
	piece(model, "CartTop", Vector3.new(body.width + s.top.overhang * 2, s.top.thickness, body.depth + s.top.overhang * 2), frame * CFrame.new(0, counter - s.top.thickness / 2, 0), dark, Enum.Material.Wood)
	-- Slats in its colour and white across the front
	local slat = (body.width - 0.3) / s.slats
	for index = 1, s.slats do
		local x = -(body.width - 0.3) / 2 + (index - 0.5) * slat
		detail(piece(model, "Slat", Vector3.new(slat - 0.06, body.height - 0.3, 0.08), frame * CFrame.new(x, body.bottom + body.height / 2, -body.depth / 2 - 0.04), if index % 2 == 1 then color else white, Enum.Material.SmoothPlastic))
	end
	-- Two big wheels at one end, front and back; a handle and its prop leg at the other
	local w = s.wheel
	for _, side in { -1, 1 } do
		buildWheel(model, frame * CFrame.new(w.x, w.radius, side * (body.depth / 2 + w.thickness / 2 + 0.05)))
	end
	local h = s.handle
	for _, side in { -1, 1 } do
		local from = Vector3.new(-body.width / 2, h.height, side * h.spread)
		local to = Vector3.new(-body.width / 2 - h.length, h.height + 0.25, side * h.spread)
		detail(piece(model, "Handle", Vector3.new(0.14, 0.14, (to - from).Magnitude), frame * CFrame.lookAt((from + to) / 2, to), dark, Enum.Material.Wood))
	end
	detail(piece(model, "HandleGrip", Vector3.new(0.18, 0.18, h.spread * 2 + 0.2), frame * CFrame.new(-body.width / 2 - h.length, h.height + 0.25, 0), dark, Enum.Material.Wood))
	detail(piece(model, "PropLeg", Vector3.new(0.16, h.height, 0.16), frame * CFrame.new(-body.width / 2 - h.length * 0.6, h.height / 2, 0), dark, Enum.Material.Wood))
	-- Turned posts at the corners, gold balls on top
	local postX, postZ = body.width / 2 - 0.2, body.depth / 2 - 0.15
	local canopyBase = counter + s.post.height
	for _, x in { -postX, postX } do
		for _, z in { -postZ, postZ } do
			piece(model, "Post", Vector3.new(s.post.height, s.post.radius * 2, s.post.radius * 2), frame * CFrame.new(x, counter + s.post.height / 2, z) * UPRIGHT, wood, Enum.Material.Wood, Enum.PartType.Cylinder)
			detail(piece(model, "PostBead", Vector3.one * (s.post.radius * 3), frame * CFrame.new(x, counter + s.post.height * 0.5, z), dark, Enum.Material.Wood, Enum.PartType.Ball))
		end
	end
	-- The canopy: a striped barrel arching from front to back, bands in its colour and white
	local c = s.canopy
	local halfDepth = body.depth / 2 + c.overhang
	local canopyWidth = body.width + c.overhang * 2
	local points = {}
	for index = 0, c.segments do
		local phi = math.pi * (1 - index / c.segments)
		table.insert(points, Vector2.new(halfDepth * math.cos(phi), canopyBase + c.rise * math.sin(phi)))
	end
	for index = 1, c.segments do
		local a, b = points[index], points[index + 1]
		local mid = (a + b) / 2
		local tilt = math.atan2(-(b.Y - a.Y), b.X - a.X)
		local band = piece(model, "Canopy", Vector3.new(canopyWidth, c.thickness, (b - a).Magnitude + 0.04), frame * CFrame.new(0, mid.Y, mid.X) * CFrame.Angles(tilt, 0, 0), if index % 2 == 1 then color else white, Enum.Material.Fabric)
		band.CastShadow = true
	end
	for _, x in { -canopyWidth / 2, canopyWidth / 2 } do
		for _, z in { -halfDepth, halfDepth } do
			detail(piece(model, "CanopyBall", Vector3.one * 0.36, frame * CFrame.new(x, canopyBase + 0.1, z), gold, Enum.Material.Metal, Enum.PartType.Ball))
		end
	end
	-- The scalloped fringe along the front: a band, round flaps hanging below it
	local f = s.fringe
	detail(piece(model, "Valance", Vector3.new(canopyWidth, 0.3, 0.06), frame * CFrame.new(0, canopyBase - 0.1, -halfDepth - 0.02), color, Enum.Material.Fabric))
	for index = 1, f.count do
		local x = -canopyWidth / 2 + (index - 0.5) * canopyWidth / f.count
		detail(piece(model, "Scallop", Vector3.new(0.05, f.radius * 2, f.radius * 2), frame * CFrame.new(x, canopyBase - 0.25, -halfDepth + 0.01) * CFrame.Angles(0, math.rad(90), 0), if index % 2 == 1 then white else color, Enum.Material.Fabric, Enum.PartType.Cylinder))
	end
	-- A lantern hanging at the front corner over the wheels, lit warm
	local l = s.lantern
	local hook = Vector3.new(postX - 0.1, canopyBase - 0.1, -halfDepth + 0.25)
	detail(piece(model, "LanternChain", Vector3.new(0.05, l.drop, 0.05), frame * CFrame.new(hook - Vector3.new(0, l.drop / 2, 0)), dark, Enum.Material.Metal))
	local lamp = detail(piece(model, "Lantern", Vector3.one * l.size, frame * CFrame.new(hook - Vector3.new(0, l.drop + l.size / 2, 0)), rgb(l.color), Enum.Material.Neon, Enum.PartType.Ball))
	detail(piece(model, "LanternCap", Vector3.new(l.size * 0.9, 0.14, l.size * 0.9), lamp.CFrame * CFrame.new(0, l.size / 2, 0), dark, Enum.Material.Metal))
	local light = Instance.new("PointLight")
	light.Color = rgb(l.color)
	light.Brightness = l.brightness
	light.Range = l.range
	light.Shadows = false
	light.Parent = lamp
	-- Card packs standing along the counter, a couple of boxes at the end
	for index, packColor in s.packs do
		local x = -body.width / 2 + 0.55 + (index - 1) * 0.5
		detail(piece(model, "Pack", Vector3.new(0.42, 0.6, 0.08), frame * CFrame.new(x, counter + 0.3, -0.35) * CFrame.Angles(math.rad(-10), 0, 0), rgb(packColor), Enum.Material.SmoothPlastic))
	end
	detail(piece(model, "Box", Vector3.new(0.7, 0.45, 0.5), frame * CFrame.new(body.width / 2 - 0.6, counter + 0.225, 0.1), color:Lerp(white, 0.3), Enum.Material.Cardboard))
	detail(piece(model, "Box", Vector3.new(0.5, 0.35, 0.4), frame * CFrame.new(body.width / 2 - 0.65, counter + 0.625, 0.1) * CFrame.Angles(0, math.rad(12), 0), gold, Enum.Material.Cardboard))
	buildEasel(model, frame, spec.sign)
	model.Parent = parent
end

-- A bistro chair at `chair` (from PlazaLayout.chairs): a round seat on four thin dark legs, a round back on two posts
-- leaning back a little; returns the seat's top, facing the table
local function buildChair(model: Model, chair: PlazaLayout.Chair): CFrame
	local t = Plaza.TABLE
	local seat, back = t.seat, t.back
	local spot = centre() + Vector3.new(chair.x, 0, chair.z)
	local frame = CFrame.lookAt(spot, spot + Vector3.new(chair.faceX, 0, chair.faceZ))
	local wood, metal = rgb(t.wood), rgb(t.metal)
	piece(model, "Seat", Vector3.new(seat.thickness, seat.radius * 2, seat.radius * 2), frame * CFrame.new(0, seat.height, 0) * UPRIGHT, wood, Enum.Material.Wood, Enum.PartType.Cylinder)
	local legLength = seat.height - seat.thickness / 2
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local inset = seat.radius * 0.62
		detail(piece(model, "ChairLeg", Vector3.new(legLength, t.leg, t.leg), frame * CFrame.new(corner[1] * inset, legLength / 2, corner[2] * inset) * UPRIGHT, metal, Enum.Material.Metal, Enum.PartType.Cylinder))
	end
	local lean = math.rad(back.lean)
	local rise = back.y - seat.height
	local backZ = seat.radius * 0.8
	for _, side in { -1, 1 } do
		local foot = Vector3.new(side * seat.radius * 0.7, seat.height, backZ)
		local head = foot + Vector3.new(0, rise, math.tan(lean) * rise)
		detail(piece(model, "ChairPost", Vector3.new((head - foot).Magnitude, t.leg, t.leg), frame * CFrame.lookAt((foot + head) / 2, head) * CFrame.Angles(0, math.rad(90), 0), metal, Enum.Material.Metal, Enum.PartType.Cylinder))
	end
	piece(model, "ChairBack", Vector3.new(0.14, back.radius * 2, back.radius * 2), frame * CFrame.new(0, back.y, backZ + math.tan(lean) * rise) * CFrame.Angles(lean, 0, 0) * CFrame.Angles(0, math.rad(90), 0), wood, Enum.Material.Wood, Enum.PartType.Cylinder)
	return frame * CFrame.new(0, seat.height + seat.thickness / 2, 0)
end

-- A townsperson sitting on a chair (the customers' blocky look), a cup in hand; the rig is anchored at its root, so it
-- costs no physics. Each client plays the sit animation and the sips (PlazaNpcController).
local function buildSitter(parent: Instance, seatTop: CFrame, index: number)
	local sitter = Plaza.SITTER
	local description = Instance.new("HumanoidDescription")
	local skin = Customers.SKIN_COLORS[(index * 2) % #Customers.SKIN_COLORS + 1]
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = Customers.CLOTHES_COLORS[(index * 3) % #Customers.CLOTHES_COLORS + 1]
	local legs = Customers.CLOTHES_COLORS[(index * 5 + 1) % #Customers.CLOTHES_COLORS + 1]
	description.LeftLegColor = legs
	description.RightLegColor = legs
	local rig = NpcMotion.createRig(description, "Townsfolk", seatTop)
	local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		end
	end
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	root.CFrame = seatTop * CFrame.new(0, sitter.rootHeight, sitter.back)
	local hand = rig:FindFirstChild("RightHand") :: BasePart?
	if hand then
		local cup = detail(piece(rig, "Cup", Vector3.new(0.42, 0.3, 0.3), hand.CFrame, rgb(sitter.cup), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder))
		cup.Anchored = false
		cup.Massless = true
		local weld = Instance.new("Weld")
		weld.Part0 = hand
		weld.Part1 = cup
		weld.C0 = CFrame.new(0, -0.2, -0.15) * UPRIGHT
		weld.Parent = cup
	end
	rig.Parent = parent
end

-- A round wooden cafe table on a dark pedestal, a cloth just under its top and a little vase of flowers, its chairs
-- round it and townsfolk in the chairs Plaza.TABLE.sitters names
local function buildTable(parent: Instance, townsfolk: Instance, index: number)
	local t = Plaza.TABLE
	local model = Instance.new("Model")
	model.Name = "CafeTable"
	local spot = at(Plaza.TABLES.angles[index], Plaza.TABLES.r)
	local top, metal = t.top, rgb(t.metal)
	piece(model, "TableTop", Vector3.new(top.thickness, top.radius * 2, top.radius * 2), CFrame.new(spot + Vector3.new(0, top.height, 0)) * UPRIGHT, rgb(t.wood), Enum.Material.Wood, Enum.PartType.Cylinder)
	local clothRadius = top.radius + t.cloth.overhang
	detail(piece(model, "TableCloth", Vector3.new(t.cloth.drop, clothRadius * 2, clothRadius * 2), CFrame.new(spot + Vector3.new(0, top.height - top.thickness / 2 - t.cloth.drop / 2 + 0.04, 0)) * UPRIGHT, rgb(t.clothColor), Enum.Material.Fabric, Enum.PartType.Cylinder))
	piece(model, "TablePole", Vector3.new(top.height, 0.28, 0.28), CFrame.new(spot + Vector3.new(0, top.height / 2, 0)) * UPRIGHT, metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	detail(piece(model, "TableFoot", Vector3.new(0.14, 1.4, 1.4), CFrame.new(spot + Vector3.new(0, 0.07, 0)) * UPRIGHT, metal, Enum.Material.Metal, Enum.PartType.Cylinder))
	local vaseFoot = top.height + top.thickness / 2
	detail(piece(model, "Vase", Vector3.new(t.vase.height, t.vase.radius * 2, t.vase.radius * 2), CFrame.new(spot + Vector3.new(0, vaseFoot + t.vase.height / 2, 0)) * UPRIGHT, Color3.fromRGB(170, 220, 230), Enum.Material.Glass, Enum.PartType.Cylinder))
	detail(piece(model, "Bloom", Vector3.one * 0.42, CFrame.new(spot + Vector3.new(0, vaseFoot + t.vase.height + 0.12, 0)), rgb(t.flowers[(index - 1) % #t.flowers + 1]), Enum.Material.SmoothPlastic, Enum.PartType.Ball))
	local seats = {}
	for _, chair in PlazaLayout.chairs(Plaza, index) do
		table.insert(seats, buildChair(model, chair))
	end
	model.Parent = parent
	for _, sitter in t.sitters do
		if sitter.table == index then
			buildSitter(townsfolk, seats[sitter.chair], index)
		end
	end
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

-- The curved stone planters along the edge, grass on top, the bushes and flowers in them and the trees standing in
-- them (the lamps stand in them too: their posts are built by buildLampAndLights)
local function buildPlanters(parent: Instance)
	local planters = Plaza.PLANTERS
	local model = Instance.new("Model")
	model.Name = "Planters"
	local stone, soil = rgb(planters.stone), rgb(planters.soil)
	for _, arc in planters.arcs do
		local count = math.max(1, math.ceil((arc[2] - arc[1]) / planters.piece))
		local step = (arc[2] - arc[1]) / count
		local length = 2 * (planters.r + planters.width / 2) * math.sin(math.rad(step / 2)) + 0.05
		for index = 0, count - 1 do
			local spot = at(arc[1] + step * (index + 0.5), planters.r)
			local frame = CFrame.lookAt(spot, centre())
			piece(model, "PlanterStone", Vector3.new(length, planters.height, planters.width), frame * CFrame.new(0, planters.height / 2, 0), stone, Enum.Material.Slate)
			detail(piece(model, "PlanterGrass", Vector3.new(length, 0.12, planters.width - 0.4), frame * CFrame.new(0, planters.height + 0.02, 0), soil, Enum.Material.LeafyGrass))
		end
	end
	for _, plant in PlazaLayout.planterPlants(Plaza) do
		local placed = ScenePieces.placeModel(model, { model = plant.model, x = centre().X + plant.x, z = centre().Z + plant.z, height = plant.height, yaw = plant.yaw }, "PlanterPlant", planters.height)
		if placed then
			for _, part in placed:GetDescendants() do
				if part:IsA("BasePart") then
					part.CanCollide = false
					part.CastShadow = false
				end
			end
		end
	end
	for _, tree in Plaza.TREES do
		local spot = at(tree.angle, tree.r)
		ScenePieces.placeModel(model, { model = tree.model, x = spot.X, z = spot.Z, height = tree.height, yaw = tree.angle }, "PlanterTree", planters.height)
	end
	model.Parent = parent
end

function PlazaBuild.build(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "FestivalSquare"
	buildGazebo(folder)
	buildFan(folder)
	for _, stall in Plaza.STALLS do
		buildStall(folder, stall)
	end
	local townsfolk = Instance.new("Folder")
	townsfolk.Name = "Townsfolk"
	townsfolk.Parent = folder
	for index in Plaza.TABLES.angles do
		buildTable(folder, townsfolk, index)
	end
	for _, angle in Plaza.LAMPS.angles do
		buildLampAndLights(folder, angle)
	end
	buildPlanters(folder)
	folder.Parent = parent
end

return PlazaBuild
