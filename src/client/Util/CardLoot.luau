--!strict
-- A card a monster drops, on this client (owner 2026-11-18: "If a monster drops a new card. make it more noticeable";
-- pick C "loot beam"; Config/CardLoot, Shared/Util/CardLootRules): it lands on the ground where the monster poofed,
-- floating and turning slowly under a tall beam in its rarity colour, sparkles rising, a glow on the ground, a chime.
-- Walk to it (or wait: it comes to you) and it pops up showing its face, then flies into your Cards button, which
-- flashes a gold ring and a +1. Only the winner sees it (BattleController calls `drop`); the card is in the binder
-- already. A Grade A or S card's beam, glow, light and sparkles take its grade's colour, a tag over it saying so
-- ("Voidmaw · Grade A!", owner 2026-11-26, pick A "Medal + glow"; Config/GradeLook).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AttackFx = require(Config:WaitForChild("AttackFx"))
local LOOT = require(Config:WaitForChild("CardLoot"))
local Cards = require(Config:WaitForChild("Cards"))
local GradeLookConfig = require(Config:WaitForChild("GradeLook"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardLootRules = require(Shared:WaitForChild("Util"):WaitForChild("CardLootRules"))
local GradeLook = require(Shared:WaitForChild("Util"):WaitForChild("GradeLook"))

local ClientUtil = script.Parent :: Instance
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local SoundBank = require(ClientUtil:WaitForChild("SoundBank"))

local CardLoot = {}

local player = Players.LocalPlayer
local CANVAS = Vector2.new(340, 476) -- the card face's pixels (fixed: the face scales with the card)
local GOLD = Color3.fromRGB(255, 205, 70)

local function sound(spec: { id: string, volume: number }, at: Vector3, volume: number?)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(at)
	part.Parent = workspace
	Debris:AddItem(part, 4)
	local made = SoundBank.make(spec.id)
	made.Volume = spec.volume * (volume or 1)
	made.RollOffMaxDistance = 120
	made.Parent = part
	made:Play()
end

local function root(): BasePart?
	local character = player.Character
	local part = character and character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

-- The ground under `at` (characters, monsters' markers and non-solid things don't count)
local function groundUnder(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local skip: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	local markers = workspace:FindFirstChild("Monsters")
	if markers then
		table.insert(skip, markers)
	end
	params.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position else at
end

local function part(name: string, size: Vector3, cframe: CFrame): Part
	local made = Instance.new("Part")
	made.Name = name
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Size = size
	made.CFrame = cframe
	return made
end

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- The card itself: its face on the front (a fresh copy's, as the pack opening draws it: its grade's medal), its back on
-- the back
local function cardPart(card: any, foil: boolean, grade: string): Part
	local height = LOOT.cardHeight
	local made = part("LootCard", Vector3.new(height / 1.4, height, 0.05), CFrame.new())
	made.Color = Color3.new(1, 1, 1) -- its edge; the faces are drawn over both sides
	made.Material = Enum.Material.SmoothPlastic
	local outline = Instance.new("Highlight")
	outline.FillTransparency = 1
	outline.OutlineColor = CardFace.getRarityColor(card.rarity)
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = made
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = CANVAS
		gui.LightInfluence = 0
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = made
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundTransparency = 1
		frame.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
		if face == Enum.NormalId.Front then
			CardFace.render(frame, stroke, card, foil, nil, { level = 1, stars = BeastRules.START_STARS, grade = grade, fresh = true })
		else
			CardFace.renderBack(frame, stroke)
		end
	end
	return made
end

-- A Grade A or S drop's tag over the card ("Voidmaw · Grade A!": white, edged in its grade's ring colour); nil for C
-- and B
local function gradeTag(card: any, grade: string, body: Part): BillboardGui?
	local words = GradeLook.dropTag(GradeLookConfig, card.name, grade)
	local glow = GradeLook.glow(GradeLookConfig, grade)
	local ink = GradeLookConfig.DROP.ink[grade]
	if not words or not glow or not ink then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "GradeTag"
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(320, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, LOOT.cardHeight / 2 + GradeLookConfig.DROP.rise, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = body
	local pill = Instance.new("TextLabel")
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 36)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Font = Enum.Font.FredokaOne
	pill.Text = words
	pill.TextSize = 22
	pill.TextColor3 = rgb(ink)
	pill.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = rgb(glow.ring)
	edge.Thickness = 2.5
	edge.Parent = pill
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = pill
	return gui
end

-- The Cards button takes the card: a gold ring flashes round it and a +1 rises over it
local function cardsButtonGot()
	local button = Hud.find("Cards")
	local screen = button and button:FindFirstAncestorWhichIsA("ScreenGui")
	if not button or not screen then
		return
	end
	local at, size = button.AbsolutePosition, button.AbsoluteSize
	local origin = screen.AbsolutePosition
	local ring = Instance.new("Frame")
	ring.Name = "LootRing"
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(at.X - origin.X + size.X / 2, at.Y - origin.Y + size.Y / 2)
	ring.Size = UDim2.fromOffset(size.X, size.Y)
	ring.ZIndex = 50
	ring.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 5
	stroke.Parent = ring
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(size.X * 1.5, size.Y * 1.5) }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.45), { Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.5)
	local plus = Instance.new("TextLabel")
	plus.Name = "LootPlus"
	plus.BackgroundTransparency = 1
	plus.AnchorPoint = Vector2.new(0.5, 1)
	plus.Position = UDim2.fromOffset(at.X - origin.X + size.X / 2, at.Y - origin.Y)
	plus.Size = UDim2.fromOffset(80, 36)
	plus.Font = Enum.Font.FredokaOne
	plus.Text = "+1"
	plus.TextSize = 30
	plus.TextColor3 = Color3.fromRGB(80, 220, 110)
	plus.TextStrokeTransparency = 0.2
	plus.ZIndex = 51
	plus.Parent = screen
	TweenService:Create(plus, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = plus.Position - UDim2.fromOffset(0, 40),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(plus, 1)
end

-- The card from the world into the Cards button: its picture flying across the screen from `from` (screen pixels)
local function flyToCards(card: any, from: Vector2, width: number)
	local button = Hud.find("Cards")
	local screen = button and button:FindFirstAncestorWhichIsA("ScreenGui")
	if not button or not screen then
		return
	end
	local origin = screen.AbsolutePosition
	local image = Instance.new("ImageLabel")
	image.Name = "LootCardFlight"
	image.BackgroundColor3 = CardFace.getRarityColor(card.rarity)
	image.BorderSizePixel = 0
	image.Image = CardFace.artImage(card)
	image.ScaleType = Enum.ScaleType.Crop
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromOffset(from.X - origin.X, from.Y - origin.Y)
	image.Size = UDim2.fromOffset(width, width * 1.4)
	image.ZIndex = 50
	image.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = image
	local stroke = Instance.new("UIStroke")
	stroke.Color = CardFace.getRarityColor(card.rarity)
	stroke.Thickness = 3
	stroke.Parent = image
	local target = button.AbsolutePosition + button.AbsoluteSize / 2 - origin
	local tween = TweenService:Create(image, TweenInfo.new(LOOT.pickup.fly, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromOffset(target.X, target.Y),
		Size = UDim2.fromOffset(width * 0.25, width * 0.35),
		Rotation = -12,
	})
	tween:Play()
	tween.Completed:Connect(function()
		image:Destroy()
		cardsButtonGot()
	end)
end

-- A card dropped for you: it lands under its beam at the ground under `from` (where the monster poofed)
function CardLoot.drop(from: Vector3, dropped: { cardId: string, grade: string?, foil: boolean? })
	local card = Cards.ById[dropped.cardId]
	if not card then
		return
	end
	local grade = if BeastRules.isGrade(dropped.grade) then dropped.grade :: string else BeastRules.DEFAULT_GRADE
	-- a Grade A or S card's light is its grade's colour, the rest their rarity's
	local glow = GradeLook.glow(GradeLookConfig, grade)
	local color = if glow then rgb(glow.color) else CardFace.getRarityColor(card.rarity)
	local ground = groundUnder(from)
	local folder = Instance.new("Folder")
	folder.Name = "CardLoot"
	folder.Parent = workspace

	-- the beam: a soft column and its bright core, from the ground up
	local base = part("LootBase", Vector3.new(0.2, 0.2, 0.2), CFrame.new(ground))
	base.Transparency = 1
	base.Parent = folder
	local bottom = Instance.new("Attachment")
	bottom.Parent = base
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, LOOT.beam.height, 0)
	top.Parent = base
	local beams: { Beam } = {}
	-- clear where the card floats (its face stays bright), the light starting just over it
	local clear = math.clamp((LOOT.hover + LOOT.cardHeight / 2 + 0.3) / LOOT.beam.height, 0.02, 0.5)
	for index, width in { LOOT.beam.width, LOOT.beam.core } do
		local beam = Instance.new("Beam")
		beam.Attachment0 = bottom
		beam.Attachment1 = top
		beam.FaceCamera = true
		beam.Width0 = width
		beam.Width1 = width * 0.55
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(if index == 1 then color else color:Lerp(Color3.new(1, 1, 1), 0.7))
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.85),
			NumberSequenceKeypoint.new(clear, 0.85),
			NumberSequenceKeypoint.new(math.min(clear + 0.08, 0.6), if index == 1 then 0.35 else 0.15),
			NumberSequenceKeypoint.new(0.7, if index == 1 then 0.7 else 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Segments = 1
		beam.Parent = base
		table.insert(beams, beam)
	end
	-- the glow on the ground
	local disc = part("LootGlow", Vector3.new(0.06, LOOT.glow.radius * 2, LOOT.glow.radius * 2), CFrame.new(ground + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)))
	disc.Shape = Enum.PartType.Cylinder
	disc.Material = Enum.Material.Neon
	disc.Color = color
	disc.Transparency = 0.45
	disc.Parent = folder
	-- sparkles rising up the beam
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = AttackFx.TEXTURES.goldStars
	motes.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4))
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Rate = LOOT.motes.rate
	motes.Lifetime = NumberRange.new(LOOT.motes.lifetime[1], LOOT.motes.lifetime[2])
	motes.Speed = NumberRange.new(LOOT.motes.speed[1], LOOT.motes.speed[2])
	motes.SpreadAngle = Vector2.new(12, 12)
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Size = NumberSequence.new(LOOT.motes.size, 0)
	motes.Parent = bottom
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = LOOT.light.brightness
	light.Range = LOOT.light.range
	light.Shadows = false
	light.Parent = base

	local cardBody = cardPart(card, dropped.foil == true, grade)
	cardBody.Parent = folder
	local tag = gradeTag(card, grade, cardBody)
	sound(LOOT.sounds.land, ground, LOOT.landVolume[card.rarity] or 1)

	local started = os.clock()
	local phase = "landing"
	local phaseAt = started
	local turn = math.random() * 360
	local comeFrom: Vector3? = nil
	local finished = false
	local connection: RBXScriptConnection

	local function finish()
		if finished then
			return
		end
		finished = true
		connection:Disconnect()
		folder:Destroy()
	end

	-- Everything fades out (the card stays, or went into Cards)
	local function fadeOut(keepCard: boolean)
		for _, beam in beams do
			TweenService:Create(beam, TweenInfo.new(LOOT.fade), { Width0 = 0, Width1 = 0 }):Play()
		end
		TweenService:Create(disc, TweenInfo.new(LOOT.fade), { Transparency = 1 }):Play()
		TweenService:Create(light, TweenInfo.new(LOOT.fade), { Brightness = 0 }):Play()
		motes.Enabled = false
		if tag then
			tag.Enabled = false
		end
		if not keepCard then
			for _, item in cardBody:GetChildren() do
				if item:IsA("SurfaceGui") then
					item.Enabled = false
				elseif item:IsA("Highlight") then
					item.Enabled = false
				end
			end
			TweenService:Create(cardBody, TweenInfo.new(LOOT.fade), { Transparency = 1 }):Play()
		end
	end

	local function pose(at: Vector3, facing: CFrame?, scale: number?)
		local grow = scale or 1
		local height = LOOT.cardHeight * grow
		cardBody.Size = Vector3.new(height / 1.4, height, 0.05)
		cardBody.CFrame = if facing then CFrame.new(at) * facing else CFrame.new(at) * CFrame.Angles(0, math.rad(turn), 0)
	end

	connection = RunService.RenderStepped:Connect(function(dt)
		if not folder.Parent then
			finish()
			return
		end
		local now = os.clock()
		local me = root()
		local camera = workspace.CurrentCamera
		turn += LOOT.spin * dt
		local glowPulse = math.sin((now - started) * LOOT.glow.speed) * LOOT.glow.pulse
		disc.Transparency = math.clamp(0.45 + glowPulse, 0, 1)
		if phase == "landing" or phase == "waiting" then
			local height = if phase == "landing" then CardLootRules.landing(now - phaseAt, LOOT) else LOOT.hover + math.sin((now - started) * LOOT.bob.speed) * LOOT.bob.studs
			pose(ground + Vector3.new(0, height, 0))
			if phase == "landing" and now - phaseAt >= LOOT.land.seconds then
				phase, phaseAt = "waiting", now
			end
			local spot = ground + Vector3.new(0, LOOT.hover, 0)
			local distance = if me then (me.Position - spot).Magnitude else nil
			local next = CardLootRules.next(now - started, distance, LOOT)
			if next == "pickup" then
				phase, phaseAt = "pickup", now
				comeFrom = cardBody.Position
				fadeOut(true)
				sound(LOOT.sounds.pickup, cardBody.Position)
			elseif next == "come" then
				phase, phaseAt = "come", now
				comeFrom = cardBody.Position
				fadeOut(true)
			elseif next == "fade" and phase == "waiting" then
				fadeOut(false)
				task.delay(LOOT.fade, finish)
				phase = "gone"
			end
			return
		end
		if phase == "come" then
			-- it flies to you, then is picked up
			local share = math.clamp((now - phaseAt) / LOOT.come.seconds, 0, 1)
			-- to just in front of you, toward the camera (not behind your back)
			local target = comeFrom :: Vector3
			if me then
				local toCamera = if camera then camera.CFrame.Position - me.Position else Vector3.zero
				local flat = Vector3.new(toCamera.X, 0, toCamera.Z)
				target = me.Position + Vector3.new(0, 1.2, 0) + (if flat.Magnitude > 0.1 then flat.Unit * 2.5 else Vector3.zero)
			end
			pose((comeFrom :: Vector3):Lerp(target, share * share))
			if share >= 1 then
				phase, phaseAt = "pickup", now
				comeFrom = cardBody.Position
				sound(LOOT.sounds.pickup, cardBody.Position)
			end
			return
		end
		if phase == "pickup" and camera then
			-- it pops up facing you, a little bigger, showing its face
			local spec = LOOT.pickup
			local share = math.clamp((now - phaseAt) / spec.seconds, 0, 1)
			local eased = 1 - (1 - share) ^ 3
			local at = (comeFrom :: Vector3) + Vector3.new(0, spec.rise * eased, 0)
			-- its face (the part's front, along its look) toward the camera
			local toCamera = camera.CFrame.Position - at
			local flat = Vector3.new(toCamera.X, 0, toCamera.Z)
			local facing = if flat.Magnitude > 0.1 then CFrame.lookAt(Vector3.zero, flat.Unit) else nil
			pose(at, facing, 1 + (spec.grow - 1) * eased)
			if now - phaseAt >= spec.seconds + spec.hold then
				-- screen points in the HUD's own space (WorldToScreenPoint leaves out Roblox's top bar, as gui positions do)
				local point, onScreen = camera:WorldToScreenPoint(cardBody.Position)
				if onScreen then
					-- its size on the screen: its height's span seen from the camera
					local topPoint = camera:WorldToScreenPoint(cardBody.Position + Vector3.new(0, cardBody.Size.Y / 2, 0))
					local width = math.clamp(math.abs(point.Y - topPoint.Y) * 2 / 1.4, 30, 220)
					flyToCards(card, Vector2.new(point.X, point.Y), width)
				else
					cardsButtonGot()
				end
				finish()
			end
			return
		end
		if phase == "pickup" then
			finish()
		end
	end)
end

return CardLoot
