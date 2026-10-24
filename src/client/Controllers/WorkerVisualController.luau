--!strict
-- Shop workers (JobService) walk as invisible R15 rigs on the server, for pathfinding. A worker whose card has a
-- creature model (the rig's CardId attribute) is drawn here, on this client only: the card's model, sized by
-- rarity (at least Jobs.CREATURE_MIN_HEIGHT), following the rig's feet with the motion kit (breathing, hop-and-waddle), like summoned creatures.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Party = require(Config:WaitForChild("Party"))
local Jobs = require(Config:WaitForChild("Jobs"))
local CreatureVisuals = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("CreatureVisuals"))

local WorkerVisualController = {}

type Worker = { rig: Model, root: BasePart, humanoid: Humanoid, feet: Part, body: CreatureVisuals.Body }

local workers: { [Model]: Worker } = {}

-- The point on the ground under the rig, facing where it faces
local function feetCFrame(root: BasePart, humanoid: Humanoid): CFrame
	return root.CFrame * CFrame.new(0, -(humanoid.HipHeight + root.Size.Y / 2), 0)
end

local function remove(rig: Model)
	local worker = workers[rig]
	if not worker then
		return
	end
	workers[rig] = nil
	worker.body.model:Destroy()
	worker.feet:Destroy()
end

local function add(rig: Instance)
	if not rig:IsA("Model") or workers[rig] then
		return
	end
	local cardId = rig:GetAttribute("CardId")
	local card = if typeof(cardId) == "string" then Cards.ById[cardId] else nil
	if not card then
		return
	end
	local root = rig:WaitForChild("HumanoidRootPart", 10)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local template, variant = CreatureVisuals.cardTemplate(card.name)
	if not template or not root or not root:IsA("BasePart") or not humanoid or not rig.Parent then
		return
	end
	local model = template:Clone()
	CreatureVisuals.strip(model)
	if variant then
		CreatureVisuals.applyVariant(model, variant)
	end
	model.Name = `{card.name}_Worker`
	-- A local stand-in marker at the rig's feet, moved every frame
	local feet = Instance.new("Part")
	feet.Name = "WorkerFeet"
	feet.Anchored = true
	feet.CanCollide = false
	feet.CanQuery = false
	feet.CanTouch = false
	feet.Transparency = 1
	feet.Size = Vector3.new(0.2, 0.2, 0.2)
	feet.CFrame = feetCFrame(root, humanoid)
	feet.Parent = workspace
	local height = math.max(Party.CREATURE_HEIGHT * (Party.SIZE_BY_RARITY[card.rarity] or 1), Jobs.CREATURE_MIN_HEIGHT)
	local flying = table.find(Party.FLYING, card.name) ~= nil
	workers[rig] = { rig = rig, root = root, humanoid = humanoid, feet = feet, body = CreatureVisuals.build(model, feet, height, flying, template.Name) }
end

function WorkerVisualController.Start()
	local folder = workspace:WaitForChild("Workers")
	for _, rig in folder:GetChildren() do
		task.spawn(add, rig)
	end
	folder.ChildAdded:Connect(function(rig)
		task.spawn(add, rig)
	end)
	folder.ChildRemoved:Connect(function(rig)
		if rig:IsA("Model") then
			remove(rig)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local origin = if camera then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		for rig, worker in workers do
			if not rig.Parent then
				remove(rig)
			else
				worker.feet.CFrame = feetCFrame(worker.root, worker.humanoid)
				CreatureVisuals.step(worker.body, dt, now, origin, Party.MOTION)
			end
		end
	end)
end

return WorkerVisualController
