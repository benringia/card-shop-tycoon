--!strict
-- Draws every wild monster on this client. WildService moves an invisible marker per monster in
-- workspace.Monsters (attributes MonsterId, Species, Level, Elite, Element, Fighting); here each marker gets a
-- model (ReplicatedStorage.MonsterModels[Species], or a placeholder shape in its element colour), the same
-- motion as summoned creatures (CreatureVisuals) and a name tag. Elites are bigger with a gold tag; bosses (attribute
-- Boss, a Config/Bosses id) are drawn from their config at its scale with a red tag.
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

type Monster = {
	marker: BasePart,
	body: CreatureVisuals.Body,
	tag: TextLabel,
	connections: { RBXScriptConnection },
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
	local body = CreatureVisuals.build(model, marker, height, flying)
	local monster: Monster = {
		marker = marker,
		body = body,
		tag = CreatureVisuals.makeTag(body.root, height + (if flying then Party.MOTION.HOVER_HEIGHT else 0), TAG_COLOR),
		connections = {},
	}
	if elite or boss then
		local light = Instance.new("PointLight")
		light.Color = if boss then BOSS_TAG_COLOR else ELITE_TAG_COLOR
		light.Brightness = 0.8
		light.Range = 8
		light.Parent = body.root
	end
	updateTag(monster)
	table.insert(monster.connections, marker.AttributeChanged:Connect(function()
		updateTag(monster)
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
		end
	end)
end

return MonsterController
