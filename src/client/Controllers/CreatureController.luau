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
local CreatureVisuals = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("CreatureVisuals"))

local CreatureController = {}

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

type Creature = {
	marker: BasePart,
	body: CreatureVisuals.Body,
	foil: boolean,
	rarity: string,
	outline: boolean,
	highlight: Highlight?,
	light: PointLight?,
	tag: TextLabel,
	hpBar: BillboardGui?, -- in an arena fight: a bar everyone can see
	hpFill: Frame?,
	height: number,
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

-- A round blob in its element colour with eyes (and wings for flyers): used until a model is imported
local function makePlaceholder(color: Color3, flying: boolean): Model
	local model = Instance.new("Model")
	local function part(name: string, shape: Enum.PartType, size: Vector3, position: Vector3, partColor: Color3)
		CreatureVisuals.addPart(model, name, shape, size, CFrame.new(position), partColor)
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

local function addGlow(creature: Creature, element: string, grade: string, stars: number)
	local glow = Party.GLOW[creature.rarity] or Party.GLOW.Common
	local color = Cards.ELEMENTS[element] or Color3.new(1, 1, 1)
	local _, size = creature.body.model:GetBoundingBox()

	if glow.light > 0 then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = glow.light
		light.Range = glow.lightRange
		light.Parent = creature.body.root
		creature.light = light
	end

	local sparkles = glow.sparkles + stars * Party.SPARKLES_PER_STAR + (if grade == "S" then Party.GRADE_S_SPARKLES else 0)
	if sparkles > 0 then
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(0, size.Y / 2, 0)
		attachment.Parent = creature.body.root
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
		highlight.Adornee = creature.body.model
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillTransparency = 1
		highlight.OutlineColor = color
		highlight.Enabled = false -- the outline budget turns it on (updateOutlines)
		highlight.Parent = creature.body.model
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

local HP_HIGH = Color3.fromRGB(90, 210, 110)
local HP_LOW = Color3.fromRGB(220, 70, 60)

-- Arena fights put Hp / MaxHp attributes on fighting markers: show a small bar over the creature
local function updateHpBar(creature: Creature)
	local hp = creature.marker:GetAttribute("Hp")
	local maxHp = creature.marker:GetAttribute("MaxHp")
	if typeof(hp) ~= "number" or typeof(maxHp) ~= "number" or maxHp <= 0 then
		if creature.hpBar then
			creature.hpBar.Enabled = false
		end
		return
	end
	if not creature.hpBar then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(80, 10)
		gui.StudsOffset = Vector3.new(0, creature.height + 2.6, 0)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		local track = Instance.new("Frame")
		track.Size = UDim2.fromScale(1, 1)
		track.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		track.BorderSizePixel = 0
		track.Parent = gui
		local fill = Instance.new("Frame")
		fill.BorderSizePixel = 0
		fill.Parent = track
		gui.Parent = creature.body.root
		creature.hpBar, creature.hpFill = gui, fill
	end
	local share = math.clamp(hp / maxHp, 0, 1)
	local fill = creature.hpFill :: Frame
	fill.Size = UDim2.fromScale(share, 1)
	fill.BackgroundColor3 = HP_LOW:Lerp(HP_HIGH, share)
	;(creature.hpBar :: BillboardGui).Enabled = true
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
	creature.body.model:Destroy()
end

local function add(marker: BasePart)
	if creatures[marker] or not marker:GetAttribute("CardId") then
		return
	end
	local card = Cards.ById[marker:GetAttribute("CardId") :: string]
	if not card then
		return
	end
	local flying = CreatureVisuals.isFlying(card.name)
	local template = CreatureVisuals.cardTemplate(card.name)
	local model = if template then template:Clone() else makePlaceholder(Cards.ELEMENTS[card.element], flying)
	CreatureVisuals.strip(model)
	model.Name = `{card.name}_{marker:GetAttribute("OwnerUserId")}`
	if template then
		CreatureVisuals.dress(model, card.name)
	end

	local height = CreatureVisuals.cardHeight(card.name, card.rarity)
	local body = CreatureVisuals.build(model, marker, height, flying, if template then template.Name else nil)
	body.fxColor = Cards.ELEMENTS[card.element] or body.fxColor
	-- The element aura: more than all of it on grade S Legendaries (Divine), all of it on other Legendaries, a lighter
	-- touch on grade S and A copies of the rest
	local grade = marker:GetAttribute("Grade")
	local tier = if card.rarity == "Legendary" then (if grade == "S" then "Divine" else "Legendary")
		elseif grade == "S" or grade == "A" then grade
		else nil
	if tier then
		CreatureVisuals.addBeastFx(body, card.element, tier :: string)
	end
	local tagColor = rarityColor(card.rarity):Lerp(Color3.new(1, 1, 1), 0.35)
	local creature: Creature = {
		marker = marker,
		body = body,
		foil = marker:GetAttribute("Foil") == true,
		rarity = card.rarity,
		outline = false,
		highlight = nil,
		light = nil,
		tag = CreatureVisuals.makeTag(body.root, height + (if flying then Party.MOTION.HOVER_HEIGHT else 0), tagColor),
		hpBar = nil,
		hpFill = nil,
		height = height + (if flying then Party.MOTION.HOVER_HEIGHT else 0),
		connections = {},
	}
	local grade = marker:GetAttribute("Grade")
	local stars = marker:GetAttribute("Stars")
	addGlow(creature, card.element, if typeof(grade) == "string" then grade else "C", if typeof(stars) == "number" then stars else 0)
	updateTag(creature)
	updateHpBar(creature)
	table.insert(creature.connections, marker.AttributeChanged:Connect(function()
		updateTag(creature)
		updateHpBar(creature)
	end))
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
		return (a.body.cframe.Position - origin).Magnitude < (b.body.cframe.Position - origin).Magnitude
	end)
	for index, creature in wanting do
		(creature.highlight :: Highlight).Enabled = index <= Party.MAX_OUTLINES
	end
end

local function step(creature: Creature, dt: number, now: number, origin: Vector3)
	CreatureVisuals.step(creature.body, dt, now, origin, Party.MOTION)
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
	-- Every creature model downloads in the background (the party bar starts its own party's first)
	CreatureVisuals.preload({})
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
