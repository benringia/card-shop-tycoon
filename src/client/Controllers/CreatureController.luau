--!strict
-- Draws every summoned creature on this client. The server only moves an invisible marker part in
-- workspace.Creatures; here each marker gets a model (ReplicatedStorage.CreatureModels, or a placeholder
-- blob), smooth following, a motion kit (breathing, hop-and-waddle, hover for flyers) or the model's own
-- Idle/Walk animations, a rarity glow and a name tag. Everything is local: nothing here replicates.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Party = require(Config:WaitForChild("Party"))
local Rarities = require(Config:WaitForChild("Rarities"))
local CreatureMotion = require(Shared:WaitForChild("Util"):WaitForChild("CreatureMotion"))

local CreatureController = {}

local SMOOTHING = 10 -- higher follows the marker more tightly
local NEAR_DISTANCE = 80 -- studs from the camera: breathing (rescaling) only this close
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local STRIPPED = { "LuaSourceContainer", "ProximityPrompt", "ClickDetector", "Sound", "Tool" }

type Creature = {
	marker: BasePart,
	model: Model,
	root: BasePart,
	baseScale: number,
	flying: boolean,
	rigged: boolean,
	cframe: CFrame,
	speed: number,
	walked: number,
	frame: number,
	foil: boolean,
	rarity: string,
	outline: boolean,
	highlight: Highlight?,
	light: PointLight?,
	tracks: { idle: AnimationTrack?, walk: AnimationTrack? },
	tag: TextLabel,
	connections: { RBXScriptConnection },
}

local creatures: { [BasePart]: Creature } = {}

local function rarityColor(rarity: string): Color3
	local tier = Rarities.Tiers[rarity]
	return if tier then tier.color else Color3.new(1, 1, 1)
end

local function rarityOrder(rarity: string): number
	local tier = Rarities.Tiers[rarity]
	return if tier then tier.order else 0
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

-- A round blob in its element colour with eyes (and wings for flyers): used until a model is imported
local function makePlaceholder(color: Color3, flying: boolean): Model
	local model = Instance.new("Model")
	local function part(name: string, shape: Enum.PartType, size: Vector3, position: Vector3, partColor: Color3)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.CFrame = CFrame.new(position)
		p.Color = partColor
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.35)
	part("Body", Enum.PartType.Ball, Vector3.new(2.2, 2.2, 2.2), Vector3.new(0, 1.1, 0), color)
	part("Belly", Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 0.95, -0.5), color:Lerp(Color3.new(1, 1, 1), 0.45))
	for _, side in { -1, 1 } do
		part("Eye", Enum.PartType.Ball, Vector3.new(0.38, 0.38, 0.38), Vector3.new(0.4 * side, 1.45, -0.95), Color3.new(0.08, 0.08, 0.1))
		part("Shine", Enum.PartType.Ball, Vector3.new(0.12, 0.12, 0.12), Vector3.new(0.4 * side + 0.07, 1.53, -1.1), Color3.new(1, 1, 1))
		part("Ear", Enum.PartType.Block, Vector3.new(0.4, 0.6, 0.3), Vector3.new(0.6 * side, 2.2, 0), dark)
		if flying then
			part("Wing", Enum.PartType.Block, Vector3.new(1.3, 0.12, 0.8), Vector3.new(1.5 * side, 1.4, 0.2), dark)
		end
	end
	model.WorldPivot = CFrame.new(0, 0, 0) -- facing -Z, like every Roblox model should
	return model
end

-- Finds the model for this card: its own (by card name) or a shared one (Party.MODEL_FOR_CARD)
local function getTemplate(cardName: string): (Model?, boolean)
	local folder = ReplicatedStorage:FindFirstChild("CreatureModels")
	local shared = Party.MODEL_FOR_CARD[cardName]
	local template = if folder then folder:FindFirstChild(shared or cardName) else nil
	if not template or not template:IsA("Model") or countParts(template) > Party.MAX_MODEL_PARTS then
		return nil, false
	end
	return template, shared ~= nil
end

local function strip(model: Model)
	for _, descendant in model:GetDescendants() do
		for _, className in STRIPPED do
			if descendant:IsA(className) then
				descendant:Destroy()
				break
			end
		end
	end
end

local function findRigRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

-- Rigged = an Animations folder with Idle and Walk, and something to play them on
local function getAnimator(model: Model): Animator?
	local animations = model:FindFirstChild("Animations")
	local idle = if animations then animations:FindFirstChild("Idle") else nil
	local walk = if animations then animations:FindFirstChild("Walk") else nil
	if not idle or not idle:IsA("Animation") or not walk or not walk:IsA("Animation") or not findRigRoot(model) then
		return nil -- no rig root to hold it up: treat it as a static model
	end
	local controller = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
	if not controller then
		return nil
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		local created = Instance.new("Animator")
		created.Parent = controller
		animator = created
	end
	return animator
end

-- Adds a root part at the bottom centre facing the model's front, then sizes the model by rarity
local function prepare(model: Model, rarity: string, rigged: boolean): (BasePart, number)
	local rigRoot = findRigRoot(model)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local yaw = model:GetAttribute("YawOffset") -- degrees, for models that don't face -Z
	local root = Instance.new("Part")
	root.Name = "CreatureRoot"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.CFrame = boxCFrame * CFrame.new(0, -boxSize.Y / 2, 0)
		* CFrame.Angles(0, math.rad(if typeof(yaw) == "number" then yaw else 0), 0)
	root.Parent = model

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			-- Rigs: only the root is anchored so their joints can animate; static models: all of it
			descendant.Anchored = descendant == root or not rigged
		end
	end
	if rigged and rigRoot then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = rigRoot
		weld.Parent = root
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.RequiresNeck = false
		humanoid.BreakJointsOnDeath = false
		humanoid.PlatformStand = true
	end
	model.PrimaryPart = root

	local height = Party.CREATURE_HEIGHT * (Party.SIZE_BY_RARITY[rarity] or 1)
	local scale = model:GetScale() * height / math.max(boxSize.Y, 0.1)
	model:ScaleTo(scale)
	return root, scale
end

local function addGlow(creature: Creature, element: string, grade: string, stars: number)
	local glow = Party.GLOW[creature.rarity] or Party.GLOW.Common
	local color = Cards.ELEMENTS[element] or Color3.new(1, 1, 1)
	local _, size = creature.model:GetBoundingBox()

	if glow.light > 0 then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = glow.light
		light.Range = glow.lightRange
		light.Parent = creature.root
		creature.light = light
	end

	local sparkles = glow.sparkles + stars * Party.SPARKLES_PER_STAR + (if grade == "S" then Party.GRADE_S_SPARKLES else 0)
	if sparkles > 0 then
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(0, size.Y / 2, 0)
		attachment.Parent = creature.root
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = SPARKLE_TEXTURE
		emitter.Rate = sparkles
		emitter.Lifetime = NumberRange.new(1, 1.6)
		emitter.Speed = NumberRange.new(0.4, 1)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0) })
		emitter.LightEmission = 1
		emitter.Color = if creature.foil
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.6, 1)),
				ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 0.6, 1)),
				ColorSequenceKeypoint.new(0.66, Color3.fromHSV(0.66, 0.6, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(0.9, 0.6, 1)),
			})
			else ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4))
		emitter.Parent = attachment
	end

	creature.outline = glow.outline or creature.foil
	if creature.outline then
		local highlight = Instance.new("Highlight")
		highlight.Adornee = creature.model
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillTransparency = 1
		highlight.OutlineColor = color
		highlight.Enabled = false -- the outline budget turns it on (updateOutlines)
		highlight.Parent = creature.model
		creature.highlight = highlight
	end
end

local function updateTag(creature: Creature)
	local marker = creature.marker
	local card = Cards.ById[marker:GetAttribute("CardId") :: string]
	local level = marker:GetAttribute("Level")
	local stars = marker:GetAttribute("Stars")
	local owner = Players:GetPlayerByUserId(marker:GetAttribute("OwnerUserId") :: number)
	local name = if card then card.name else "Creature"
	local starText = if typeof(stars) == "number" and stars > 0 then " · " .. string.rep("⭐", stars) else ""
	local ownerText = if owner then `{owner.DisplayName}'s ` else ""
	creature.tag.Text = `{ownerText}{name}\nLv {if typeof(level) == "number" then level else 1}{starText}`
end

local function makeTag(root: BasePart, height: number, rarity: string): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 44)
	gui.StudsOffset = Vector3.new(0, height + 1, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = rarityColor(rarity):Lerp(Color3.new(1, 1, 1), 0.35)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = root
	return label
end

local function remove(marker: BasePart)
	local creature = creatures[marker]
	if not creature then
		return
	end
	creatures[marker] = nil
	for _, connection in creature.connections do
		connection:Disconnect()
	end
	creature.model:Destroy()
end

local function add(marker: BasePart)
	if creatures[marker] or not marker:GetAttribute("CardId") then
		return
	end
	local card = Cards.ById[marker:GetAttribute("CardId") :: string]
	if not card then
		return
	end
	local flying = table.find(Party.FLYING, card.name) ~= nil
	local template, shared = getTemplate(card.name)
	local model = if template then template:Clone() else makePlaceholder(Cards.ELEMENTS[card.element], flying)
	strip(model)
	model.Name = `{card.name}_{marker:GetAttribute("OwnerUserId")}`
	if shared then
		-- One model for several cards: tint untextured parts toward the card's element so they differ
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Color = descendant.Color:Lerp(Cards.ELEMENTS[card.element], 0.35)
			end
		end
	end

	local animator = getAnimator(model)
	local root, scale = prepare(model, card.rarity, animator ~= nil)
	local tracks: { idle: AnimationTrack?, walk: AnimationTrack? } = {}

	local height = Party.CREATURE_HEIGHT * (Party.SIZE_BY_RARITY[card.rarity] or 1)
	local creature: Creature = {
		marker = marker,
		model = model,
		root = root,
		baseScale = scale,
		flying = flying,
		rigged = animator ~= nil,
		cframe = marker.CFrame,
		speed = 0,
		walked = 0,
		frame = 0,
		foil = marker:GetAttribute("Foil") == true,
		rarity = card.rarity,
		outline = false,
		highlight = nil,
		light = nil,
		tracks = tracks,
		tag = makeTag(root, height + (if flying then Party.MOTION.HOVER_HEIGHT else 0), card.rarity),
		connections = {},
	}
	local grade = marker:GetAttribute("Grade")
	local stars = marker:GetAttribute("Stars")
	addGlow(creature, card.element, if typeof(grade) == "string" then grade else "C", if typeof(stars) == "number" then stars else 0)
	updateTag(creature)
	table.insert(creature.connections, marker.AttributeChanged:Connect(function()
		updateTag(creature)
	end))
	model:PivotTo(marker.CFrame)
	model.Parent = workspace
	-- Animators only load animations once they're in the game
	if animator then
		local animations = model:FindFirstChild("Animations") :: Instance
		local idle = animator:LoadAnimation(animations:FindFirstChild("Idle") :: Animation)
		local walk = animator:LoadAnimation(animations:FindFirstChild("Walk") :: Animation)
		idle.Looped = true
		walk.Looped = true
		idle:Play()
		tracks.idle, tracks.walk = idle, walk
	end
	creatures[marker] = creature
end

-- Roblox draws at most 31 outlines: give them to the rarest creatures, nearest first
local function updateOutlines()
	local camera = workspace.CurrentCamera
	local origin = if camera then camera.CFrame.Position else Vector3.zero
	local wanting: { Creature } = {}
	for _, creature in creatures do
		if creature.highlight then
			table.insert(wanting, creature)
		end
	end
	table.sort(wanting, function(a, b)
		if rarityOrder(a.rarity) ~= rarityOrder(b.rarity) then
			return rarityOrder(a.rarity) > rarityOrder(b.rarity)
		end
		return (a.cframe.Position - origin).Magnitude < (b.cframe.Position - origin).Magnitude
	end)
	for index, creature in wanting do
		(creature.highlight :: Highlight).Enabled = index <= Party.MAX_OUTLINES
	end
end

local function step(creature: Creature, dt: number, now: number, origin: Vector3)
	local target = creature.marker.CFrame
	local previous = creature.cframe.Position
	if (target.Position - previous).Magnitude > Party.TELEPORT_DISTANCE then
		creature.cframe = target
	else
		creature.cframe = creature.cframe:Lerp(target, 1 - math.exp(-SMOOTHING * dt))
	end
	local moved = Vector3.new(creature.cframe.X - previous.X, 0, creature.cframe.Z - previous.Z).Magnitude
	if moved < Party.TELEPORT_DISTANCE then
		creature.walked += moved
		creature.speed += (moved / math.max(dt, 1e-3) - creature.speed) * math.min(1, dt * 8)
	end
	creature.frame += 1

	local motion = Party.MOTION
	local near = (creature.cframe.Position - origin).Magnitude <= NEAR_DISTANCE
	if creature.rigged then
		-- Its own animations do the walking and breathing; the kit only lifts flyers
		local walking = creature.speed >= motion.WALK_SPEED_MIN
		local idle, walk = creature.tracks.idle :: AnimationTrack, creature.tracks.walk :: AnimationTrack
		if walking and not walk.IsPlaying then
			walk:Play(0.2)
			idle:Stop(0.2)
		elseif not walking and not idle.IsPlaying then
			idle:Play(0.2)
			walk:Stop(0.2)
		end
		local hover = if creature.flying then CreatureMotion.getPose(motion, now, creature.speed, creature.walked, true).offsetY else 0
		creature.model:PivotTo(creature.cframe * CFrame.new(0, hover, 0))
	else
		local pose = CreatureMotion.getPose(motion, now, creature.speed, creature.walked, creature.flying)
		creature.model:PivotTo(creature.cframe * CFrame.new(0, pose.offsetY, 0) * CFrame.Angles(-pose.pitch, 0, pose.roll))
		-- Model:ScaleTo is uniform: breathing grows and shrinks a little, every other frame, only up close
		if near and creature.frame % 2 == 0 then
			creature.model:ScaleTo(creature.baseScale * pose.scaleY)
		end
	end

	if creature.highlight and creature.highlight.Enabled then
		if creature.foil then
			creature.highlight.OutlineColor = Color3.fromHSV((now * 0.25) % 1, 0.65, 1)
		end
		if (Party.GLOW[creature.rarity] or Party.GLOW.Common).pulse then
			creature.highlight.OutlineTransparency = 0.35 + 0.35 * math.sin(now * 3)
		end
	end
end

function CreatureController.Start()
	local folder = workspace:WaitForChild("Creatures")
	local function watch(child: Instance)
		if not child:IsA("BasePart") then
			return
		end
		add(child)
		if not creatures[child] then
			-- Attributes can arrive a moment after the part: try again when the card id shows up
			local connection: RBXScriptConnection
			connection = child:GetAttributeChangedSignal("CardId"):Connect(function()
				connection:Disconnect()
				add(child)
			end)
		end
	end
	folder.ChildAdded:Connect(watch)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			remove(child)
		end
	end)
	for _, child in folder:GetChildren() do
		watch(child)
	end

	local sinceOutlines = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local camera = workspace.CurrentCamera
		local origin = if camera then camera.CFrame.Position else Vector3.zero
		for _, creature in creatures do
			step(creature, dt, now, origin)
		end
		sinceOutlines += dt
		if sinceOutlines >= 1 then
			sinceOutlines = 0
			updateOutlines()
		end
	end)
end

return CreatureController
