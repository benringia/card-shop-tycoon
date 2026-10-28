--!strict
-- Draws every wild monster on this client. WildService moves an invisible marker per monster in
-- workspace.Monsters (attributes MonsterId, Species, Level, Elite, Element, Fighting); here each marker gets a
-- model (ReplicatedStorage.MonsterModels[Species], or a placeholder shape in its element colour), the same
-- motion as summoned creatures (CreatureVisuals) and a name tag. Elites are bigger with a gold tag; bosses (attribute
-- Boss, a Config/Bosses id) are drawn from their config at its scale with a red tag; a boss model with PetRig bones
-- moves them (Util/PetAnimator), and one with heads (Config/Bosses heads: the Prism Hydra) lights the head of its
-- current phase (marker attribute Phase) and drops its heads one by one when it falls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Cards = require(Config:WaitForChild("Cards"))
local Party = require(Config:WaitForChild("Party"))
-- The server wild map in the main game, the Frontier in the Frontier place
local Wild = require(Shared:WaitForChild("Util"):WaitForChild("Place")).getWorld()
local CreatureVisuals = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("CreatureVisuals"))

local MonsterController = {}

local ELITE_TAG_COLOR = Color3.fromRGB(255, 205, 60)
local TAG_COLOR = Color3.fromRGB(235, 235, 235)
local BOSS_TAG_COLOR = Color3.fromRGB(255, 90, 80)

type Head = { element: string, light: PointLight, sparks: ParticleEmitter }
type Aura = { highlight: Highlight, light: PointLight }
type Monster = {
	marker: BasePart,
	body: CreatureVisuals.Body,
	tag: TextLabel,
	connections: { RBXScriptConnection },
	heads: { Head }, -- a boss with heads: one per Hydra_<n>_3 bone, n = index - 1
	fallenAt: number?, -- os.clock() its death began (heads dropping)
	aura: Aura?, -- a boss with a rainbow aura
}

local monsters: { [BasePart]: Monster } = {}

local BALL, BLOCK = Enum.PartType.Ball, Enum.PartType.Block

-- Simple part-built stand-ins, one look per species shape, all facing -Z
local function makePlaceholder(shape: string, color: Color3): Model
	local model = Instance.new("Model")
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.4)
	local light = color:Lerp(Color3.new(1, 1, 1), 0.35)
	local eye = Color3.new(0.08, 0.08, 0.1)
	local function add(shapeType: Enum.PartType, size: Vector3, x: number, y: number, z: number, partColor: Color3)
		CreatureVisuals.addPart(model, "Part", shapeType, size, CFrame.new(x, y, z), partColor)
	end
	local function eyes(y: number, z: number, spread: number)
		for _, side in { -1, 1 } do
			add(BALL, Vector3.new(0.3, 0.3, 0.3), spread * side, y, z, eye)
		end
	end
	if shape == "slime" then
		add(BLOCK, Vector3.new(2.4, 1.6, 2.4), 0, 0.8, 0, color)
		add(BLOCK, Vector3.new(1.6, 0.4, 1.6), 0, 1.75, 0, light)
		eyes(1.1, -1.22, 0.45)
	elseif shape == "crab" then
		add(BLOCK, Vector3.new(2.6, 1, 1.8), 0, 0.9, 0, color)
		for _, side in { -1, 1 } do
			add(BLOCK, Vector3.new(0.7, 0.6, 0.9), 1.7 * side, 1, -0.9, dark)
			add(BLOCK, Vector3.new(0.2, 0.6, 0.2), 0.4 * side, 1.6, -0.6, dark)
			add(BALL, Vector3.new(0.3, 0.3, 0.3), 0.4 * side, 2, -0.6, eye)
			for leg = -1, 1 do
				add(BLOCK, Vector3.new(0.9, 0.2, 0.2), 1.4 * side, 0.3, leg * 0.6, dark)
			end
		end
	elseif shape == "bat" then
		add(BALL, Vector3.new(1.6, 1.6, 1.6), 0, 1, 0, color)
		for _, side in { -1, 1 } do
			add(BLOCK, Vector3.new(1.8, 0.12, 1), 1.6 * side, 1.2, 0.1, dark)
			add(BLOCK, Vector3.new(0.3, 0.5, 0.2), 0.4 * side, 1.9, 0, dark)
		end
		eyes(1.15, -0.75, 0.3)
	elseif shape == "beetle" then
		add(BALL, Vector3.new(2.4, 1.6, 2.6), 0, 0.8, 0.2, color)
		add(BLOCK, Vector3.new(0.1, 1.2, 2.4), 0, 1.1, 0.2, dark)
		add(BALL, Vector3.new(1.1, 0.9, 1), 0, 0.7, -1.3, dark)
		eyes(0.85, -1.75, 0.3)
		for _, side in { -1, 1 } do
			add(BLOCK, Vector3.new(0.1, 0.1, 0.8), 0.25 * side, 1.1, -1.9, light)
		end
	elseif shape == "golem" then
		add(BLOCK, Vector3.new(2.4, 2, 1.6), 0, 2.2, 0, color)
		add(BLOCK, Vector3.new(1.4, 1.1, 1.2), 0, 3.75, -0.1, dark)
		for _, side in { -1, 1 } do
			add(BLOCK, Vector3.new(0.8, 2, 0.8), 1.65 * side, 1.9, 0, dark)
			add(BLOCK, Vector3.new(0.8, 1.2, 0.8), 0.6 * side, 0.6, 0, dark)
		end
		add(BLOCK, Vector3.new(1, 0.25, 0.1), 0, 3.85, -0.72, light)
	else -- wolf
		add(BLOCK, Vector3.new(1.2, 1.1, 2.6), 0, 1.4, 0, color)
		add(BLOCK, Vector3.new(1, 0.9, 1), 0, 1.9, -1.6, color)
		add(BLOCK, Vector3.new(0.6, 0.4, 0.6), 0, 1.7, -2.3, dark)
		for _, side in { -1, 1 } do
			add(BLOCK, Vector3.new(0.25, 0.5, 0.2), 0.3 * side, 2.55, -1.5, dark)
			add(BLOCK, Vector3.new(0.3, 0.9, 0.3), 0.4 * side, 0.45, -0.9, dark)
			add(BLOCK, Vector3.new(0.3, 0.9, 0.3), 0.4 * side, 0.45, 0.9, dark)
		end
		add(BLOCK, Vector3.new(0.3, 0.3, 1.2), 0, 1.8, 1.7, dark)
		eyes(2.05, -2.12, 0.25)
	end
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

local function updateTag(monster: Monster)
	local marker = monster.marker
	local species = marker:GetAttribute("Species")
	local level = marker:GetAttribute("Level")
	local elite = marker:GetAttribute("Elite") == true
	local boss = marker:GetAttribute("Boss") ~= nil
	local fighting = marker:GetAttribute("Fighting") == true
	local name = if typeof(species) == "string" then species else "Monster"
	monster.tag.Text = `{if fighting then "⚔ " else ""}{if boss then "BOSS " elseif elite then "ELITE " else ""}{name}\nLv {if typeof(level) == "number" then level else 1}`
	monster.tag.TextColor3 = if boss then BOSS_TAG_COLOR elseif elite then ELITE_TAG_COLOR else TAG_COLOR
end

-- Only the current phase's head glows (marker attribute Phase, set by BattleService); none once it has fallen
local function lightHeads(monster: Monster)
	local phase = monster.marker:GetAttribute("Phase")
	for _, head in monster.heads do
		local on = monster.fallenAt == nil and head.element == phase
		head.light.Enabled = on
		head.sparks.Enabled = on
	end
end

-- A light and sparks on each head bone, in that head's element colour (off until its phase)
local function makeHeads(model: Model, elements: { string }): { Head }
	local heads = {}
	for index, element in elements do
		local bone = model:FindFirstChild(`Hydra_{index - 1}_3`, true)
		if bone and bone:IsA("Bone") then
			local color = Cards.ELEMENTS[element] or Color3.new(1, 1, 1)
			local light = Instance.new("PointLight")
			light.Color = color
			light.Brightness = Bosses.HEAD_GLOW.brightness
			light.Range = Bosses.HEAD_GLOW.range
			light.Enabled = false
			light.Parent = bone
			local sparks = Instance.new("ParticleEmitter")
			sparks.Color = ColorSequence.new(color)
			sparks.LightEmission = 1
			sparks.Rate = Bosses.HEAD_GLOW.particles
			sparks.Lifetime = NumberRange.new(0.5, 0.9)
			sparks.Speed = NumberRange.new(1, 3)
			sparks.SpreadAngle = Vector2.new(180, 180)
			sparks.Size = NumberSequence.new(0.5, 0)
			sparks.Enabled = false
			sparks.Parent = bone
			table.insert(heads, { element = element, light = light, sparks = sparks })
		end
	end
	return heads
end

-- A rainbow aura on a boss (Bosses.RAINBOW_AURA): the model itself glows, a coloured outline round it and a faint
-- colour wash over it (the model always shows through), and a light; MonsterController's frame loop turns the colour
local function makeAura(body: CreatureVisuals.Body): Aura
	local look = Bosses.RAINBOW_AURA
	local highlight = Instance.new("Highlight")
	highlight.Name = "RainbowAura"
	highlight.Adornee = body.model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded -- not through walls
	highlight.OutlineTransparency = look.outlineTransparency
	highlight.FillTransparency = look.fillTransparency
	highlight.Parent = body.model
	local light = Instance.new("PointLight")
	light.Brightness = look.lightBrightness
	light.Range = look.lightRange
	light.Parent = body.root
	return { highlight = highlight, light = light }
end

local function stepAura(monster: Monster, now: number)
	local aura = monster.aura :: Aura
	local color = Color3.fromHSV((now / Bosses.RAINBOW_AURA.hueSeconds) % 1, 0.6, 1)
	aura.highlight.OutlineColor = color
	aura.highlight.FillColor = color
	aura.light.Color = color
	if monster.fallenAt then
		aura.highlight.OutlineTransparency = math.min(1, aura.highlight.OutlineTransparency + 0.02)
		aura.highlight.FillTransparency = math.min(1, aura.highlight.FillTransparency + 0.02)
		aura.light.Enabled = false
	end
end

-- Its death: the outer heads first, the middle one last, each neck bowing down over HEAD_DROP.seconds
local function dropHeads(monster: Monster, now: number)
	local pet = monster.body.pet
	local fallenAt = monster.fallenAt
	if not pet or not fallenAt then
		return
	end
	local drop = Bosses.HEAD_DROP
	for _, entry in (pet :: any).bones do
		local head = tonumber(string.match(entry.key, "^hydra:(%d+):0$") or "")
		if head then
			local delay = (#monster.heads - 1 - head) * drop.gap
			local share = math.clamp((now - fallenAt - delay) / drop.seconds, 0, 1)
			entry.bone.Transform = entry.restInverse * CFrame.Angles(-math.rad(drop.angle) * share, 0, 0) * entry.rest
		end
	end
end

local function remove(marker: BasePart)
	local monster = monsters[marker]
	if not monster then
		return
	end
	monsters[marker] = nil
	for _, connection in monster.connections do
		connection:Disconnect()
	end
	monster.body.model:Destroy()
end

local function add(marker: BasePart)
	local species = marker:GetAttribute("Species")
	if monsters[marker] or typeof(species) ~= "string" then
		return
	end
	local bossId = marker:GetAttribute("Boss")
	local boss = if typeof(bossId) == "string" then Bosses.BOSSES[bossId] else nil
	local info: { element: string, shape: string }? = boss or Wild.SPECIES[species]
	if not info then
		return
	end
	local elite = marker:GetAttribute("Elite") == true
	local color = Cards.ELEMENTS[info.element] or Color3.new(0.6, 0.6, 0.6)
	-- A boss model, when it exists, is saved under the boss's id
	local template = CreatureVisuals.getTemplate("MonsterModels", if boss then bossId :: string else species, Wild.MAX_MODEL_PARTS)
	local model = if template then template:Clone() else makePlaceholder(info.shape, color)
	CreatureVisuals.strip(model)
	model.Name = `{species}_{marker:GetAttribute("MonsterId")}`

	local flying = boss == nil and table.find(Wild.FLYING, species) ~= nil
	local height = Wild.MONSTER_HEIGHT * (if boss then boss.scale elseif elite then Wild.ELITE_SIZE else 1)
	-- A boss model's bones move like a creature's (its PetRig names; Party style keyed by the boss id)
	local body = CreatureVisuals.build(model, marker, height, flying, if boss and template then bossId :: string else nil)
	local monster: Monster = {
		marker = marker,
		body = body,
		tag = CreatureVisuals.makeTag(body.root, height + (if flying then Party.MOTION.HOVER_HEIGHT else 0), TAG_COLOR),
		connections = {},
		heads = if boss and boss.heads and template then makeHeads(model, boss.heads) else {},
		fallenAt = nil,
		aura = if boss and boss.rainbowAura then makeAura(body) else nil,
	}
	if elite or boss then
		local light = Instance.new("PointLight")
		light.Color = if boss then BOSS_TAG_COLOR else ELITE_TAG_COLOR
		light.Brightness = 0.8
		light.Range = 8
		light.Parent = body.root
	end
	updateTag(monster)
	lightHeads(monster)
	table.insert(monster.connections, marker.AttributeChanged:Connect(function()
		updateTag(monster)
		if #monster.heads > 0 or monster.aura then
			if marker:GetAttribute("Fainted") == true and not monster.fallenAt then
				monster.fallenAt = os.clock()
			end
			lightHeads(monster)
		end
	end))
	monsters[marker] = monster
end

function MonsterController.Start()
	local folder = workspace:WaitForChild("Monsters")
	local function watch(child: Instance)
		if not child:IsA("BasePart") then
			return
		end
		add(child)
		if not monsters[child] then
			-- Attributes can arrive a moment after the part: try again when the species shows up
			local connection: RBXScriptConnection
			connection = child:GetAttributeChangedSignal("Species"):Connect(function()
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

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local camera = workspace.CurrentCamera
		local origin = if camera then camera.CFrame.Position else Vector3.zero
		for _, monster in monsters do
			CreatureVisuals.step(monster.body, dt, now, origin, Party.MOTION)
			if monster.fallenAt then
				dropHeads(monster, now)
			end
			if monster.aura then
				stepAura(monster, now)
			end
		end
	end)
end

return MonsterController
