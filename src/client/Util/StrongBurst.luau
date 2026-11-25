--!strict
-- The gold burst behind a strong hit's number (owner 2026-11-25: "bigger" strong hits; spec
-- 2026-11-25-element-callouts-design): rays long and short in turn round the middle, fading toward their tips, over a
-- see-through disc (Config/AttackFx NUMBERS.STRONG_BURST, laid out by Util/DamagePop.burstRays). BattleController's
-- floatText puts it in the number's billboard under the number (ZIndex 0: a BillboardGui sorts by ZIndex and doesn't
-- clip) and steps it with the number's pop and fade.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("Config"):WaitForChild("AttackFx"))
local DamagePop = require(Shared:WaitForChild("Util"):WaitForChild("DamagePop"))

local StrongBurst = {}

export type Handle = { step: (scale: number, alpha: number) -> () }

local BURST = AttackFx.NUMBERS.STRONG_BURST

local function round(frame: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
end

-- The burst in the middle of `parent` (the number's billboard), drawn at `scale` of its size and `alpha` of its colour
function StrongBurst.make(parent: Instance): Handle
	local gold = Color3.fromRGB(BURST.color[1], BURST.color[2], BURST.color[3])
	local holder = Instance.new("Frame")
	holder.Name = "Burst"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(0, 0) -- its children sit round this point
	holder.ZIndex = 0
	holder.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder

	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.BackgroundColor3 = gold
	disc.BorderSizePixel = 0
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Size = UDim2.fromOffset(BURST.disc, BURST.disc)
	disc.ZIndex = 0
	disc.Parent = holder
	round(disc)

	-- the tip (the ray's top before it turns) see-through, the root solid
	local fade = NumberSequence.new({
		NumberSequenceKeypoint.new(0, BURST.fade[1]),
		NumberSequenceKeypoint.new(0.55, BURST.fade[2]),
		NumberSequenceKeypoint.new(1, BURST.fade[3]),
	})
	local rays: { Frame } = {}
	for _, spec in DamagePop.burstRays(BURST) do
		local ray = Instance.new("Frame")
		ray.Name = "Ray"
		ray.BackgroundColor3 = gold
		ray.BorderSizePixel = 0
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromOffset(spec.x, spec.y)
		ray.Size = UDim2.fromOffset(spec.width, spec.length)
		ray.Rotation = spec.rotation
		ray.ZIndex = 0
		ray.Parent = holder
		round(ray)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Transparency = fade
		gradient.Parent = ray
		table.insert(rays, ray)
	end

	local function step(size: number, alpha: number)
		scale.Scale = size
		local clear = 1 - math.clamp(alpha, 0, 1)
		for _, ray in rays do
			ray.BackgroundTransparency = clear
		end
		disc.BackgroundTransparency = 1 - (1 - BURST.discTransparency) * (1 - clear)
	end
	step(0, 1)
	return { step = step }
end

return StrongBurst
