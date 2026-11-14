--!strict
-- The prologue's cinematic Hydra (spec 2026-11-14-prologue-hydra-design; Config/Prologue HYDRA) for acts 1 and 3, drawn
-- on this client only at the fight's size (the real fight's Hydra between them is MonsterController's): the two-headed
-- Hydra (HYDRA.model, the boss's own five-headed model until it's in the game), or `grown`, the Dungeon's five-headed
-- one it becomes from your stolen power. The boss's clips play on it (Util/ClipPlayer; the two-headed model keeps the
-- same bone names).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bosses = require(Shared:WaitForChild("Config"):WaitForChild("Bosses"))
local Prologue = require(Shared:WaitForChild("Config"):WaitForChild("Prologue"))
local MonsterLooks = require(Shared:WaitForChild("Util"):WaitForChild("MonsterLooks"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))

local ClientUtil = script.Parent :: Instance
local ClipPlayer = require(ClientUtil:WaitForChild("ClipPlayer"))

local PrologueHydra = {}

export type Hydra = {
	model: Model,
	height: number,
	play: (clip: string, speed: number?, hold: number?) -> (),
	length: (clip: string) -> number,
	glow: (color: Color3) -> (),
	destroy: () -> (),
}

local HYDRA = Prologue.HYDRA

-- Its height in the fight (the real boss's, MonsterLooks.height), so the swap between the two never shows
local function fightHeight(): number
	local boss = Bosses.BOSSES[HYDRA.boss]
	return MonsterLooks.height(Place.getWorld(), boss.name, false, boss.scale, boss.height)
end

local function template(grown: boolean?): Model
	local models = ReplicatedStorage:WaitForChild("MonsterModels")
	local twin = if grown then nil else models:FindFirstChild(HYDRA.model)
	return (if twin and twin:IsA("Model") then twin else models:WaitForChild(HYDRA.boss)) :: Model
end

-- The Hydra standing on `at` (its feet on that point, facing along its look); `grown`: five-headed
function PrologueHydra.spawn(at: CFrame, grown: boolean?): Hydra
	local model = template(grown):Clone()
	model.Name = "PrologueHydra"
	for _, item in model:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("AnimationController") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * fightHeight() / math.max(size.Y, 0.01))
	model:PivotTo(at)
	local box, boxSize = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() - Vector3.new(0, box.Position.Y - boxSize.Y / 2 - at.Position.Y, 0))
	model.Parent = workspace
	local scale = model:GetScale()
	local clips, clipPlayer = ClipPlayer.loadSet(HYDRA.boss, model)

	local hydra: Hydra = {
		model = model,
		height = boxSize.Y,
		play = function(name: string, speed: number?, hold: number?)
			local clip = clips[name]
			if clip and clipPlayer then
				ClipPlayer.play(clipPlayer, clip, speed, nil, hold)
			end
		end,
		length = function(name: string): number
			local clip = clips[name]
			return if clip then clip.length else 0
		end,
		glow = function(color: Color3)
			for _, item in model:GetDescendants() do
				if item:IsA("SurfaceAppearance") then
					pcall(function()
						item.EmissiveTint = color
					end)
				end
			end
		end,
		destroy = function()
			model:Destroy()
		end,
	}
	local stepping: RBXScriptConnection
	stepping = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent then
			stepping:Disconnect()
			return
		end
		if clipPlayer then
			ClipPlayer.step(clipPlayer, dt, scale)
		end
	end)
	return hydra
end

return PrologueHydra
