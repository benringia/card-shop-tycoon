--!strict
-- Hit feel for the player's fight (spec 2026-11-02-you-in-the-fight-design): sparks where a sword hit lands and a
-- quick glow over what was hit (Config/SwordFx). Hit-stop, shake and the damage numbers are the callers' (SwordAnims,
-- BattleController).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SwordFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SwordFx"))

local HitFx = {}

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- A burst of sparks at a point
function HitFx.sparks(position: Vector3)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARK_TEXTURE
	emitter.Color = ColorSequence.new(color(SwordFx.SPARK_COLOR))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.15, 0.35)
	emitter.Speed = NumberRange.new(12, 22)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 6
	emitter.Rate = 0
	emitter.Parent = holder
	holder.Parent = workspace
	emitter:Emit(SwordFx.SPARKS)
	Debris:AddItem(holder, 1)
end

-- A glow over a model (or part) fading from `strongest` (fill transparency) to nothing over `seconds`
function HitFx.flash(target: Instance, tint: Color3, seconds: number, strongest: number)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = tint
	highlight.OutlineTransparency = 1
	highlight.FillTransparency = strongest
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = target
	highlight.Parent = target
	TweenService:Create(highlight, TweenInfo.new(seconds), { FillTransparency = 1 }):Play()
	Debris:AddItem(highlight, seconds + 0.05)
end

return HitFx
