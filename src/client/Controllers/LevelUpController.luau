--!strict
-- Plays the level-up pillar (Util/LevelUpFx; spec 2026-11-04-round4-design section 9) when the server says someone
-- levelled up (remote LevelUpFx): a shop level-up on that player's character, a creature's on its drawn model (the
-- summoned creature or a shop worker). Your own always plays; someone else's only within Config/LevelUpFx RANGE of your
-- camera, quieter. Your own creature's level-up from a won fight waits for its XP sparks to land on its portrait
-- (PartyBarController.OnLanded), at most SPARK_WAIT seconds. The server holds shop level-ups while their player fights.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local LevelUpConfig = require(Config:WaitForChild("LevelUpFx"))
local Levels = require(Config:WaitForChild("Levels"))
local LevelUpRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelUpRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local LevelUpFx = require(ClientUtil:WaitForChild("LevelUpFx"))
local CreatureController = require(Controllers:WaitForChild("CreatureController"))
local WorkerVisualController = require(Controllers:WaitForChild("WorkerVisualController"))
local PartyBarController = require(Controllers:WaitForChild("PartyBarController"))

local LevelUpController = {}

local waitingForSparks: { [string]: () -> () } = {} -- beastId -> plays its pillar (once)

local function near(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= LevelUpConfig.RANGE
end

local function whole(value: unknown): number?
	return if typeof(value) == "number" and value == value and value >= 1 and value < math.huge then math.floor(value) else nil
end

local function onShop(player: Player, from: number, to: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	local own = player == Players.LocalPlayer
	if not own and not near(root.Position) then
		return
	end
	LevelUpFx.playShop(character, from, to, LevelUpRules.isMilestone(Levels, to), not own)
end

local function playCreature(beastId: string, element: string, from: number, to: number, quiet: boolean)
	local root, height = CreatureController.GetRootForBeast(beastId)
	if not root then
		root, height = WorkerVisualController.GetRootForBeast(beastId)
	end
	if not root or not height then
		return -- not drawn here: the portrait's level roll shows it
	end
	if quiet and not near(root.Position) then
		return
	end
	LevelUpFx.playCreature(root, height, element, from, to, quiet)
end

local function onCreature(player: Player, beastId: string, element: string, from: number, to: number, fromFight: boolean)
	local own = player == Players.LocalPlayer
	if not own or not fromFight then
		playCreature(beastId, element, from, to, not own)
		return
	end
	-- Your own after a fight: when its sparks land (or SPARK_WAIT runs out), together with the portrait's roll
	local played = false
	local function go()
		if played then
			return
		end
		played = true
		waitingForSparks[beastId] = nil
		playCreature(beastId, element, from, to, false)
	end
	waitingForSparks[beastId] = go
	task.delay(LevelUpConfig.SPARK_WAIT, go)
end

local function onEvent(payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local data = payload :: any
	local player = if typeof(data.userId) == "number" then Players:GetPlayerByUserId(data.userId) else nil
	local from, to = whole(data.from), whole(data.to)
	if not player or not from or not to or to <= from then
		return
	end
	if data.kind == "shop" then
		onShop(player, from, to)
	elseif data.kind == "creature" and typeof(data.beastId) == "string" then
		local element = if typeof(data.element) == "string" then data.element else "Ember"
		onCreature(player, data.beastId, element, from, to, data.fromFight == true)
	end
end

function LevelUpController.Start()
	Remotes.LevelUpFx.OnClientEvent:Connect(onEvent)
	PartyBarController.OnLanded(function(beastId)
		local go = waitingForSparks[beastId]
		if go then
			go()
		end
	end)
end

return LevelUpController
