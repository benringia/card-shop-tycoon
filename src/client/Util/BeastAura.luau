--!strict
-- The big beasts' element aura (Crystal Titan Legendaries), on this client only: fire burning on bones spread
-- over the body (Util/BeastFxRules picks them, so the flames move with the animation), lightning arcing between
-- them, flames licking up from the ground, a flickering light and dust from the feet while it moves.
-- Everything turns off while the camera is far away. Legendaries get all of it; grade S and A copies of other
-- cards a lighter tier (BeastFx.TIERS). Numbers: Config/BeastFx.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BeastFx = require(Shared:WaitForChild("Config"):WaitForChild("BeastFx"))
local BeastFxRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastFxRules"))

export type Aura = {
	model: Model,
	look: BeastFx.Look,
	tier: BeastFx.Tier,
	size: number,
	bones: { Bone },
	emitters: { ParticleEmitter },
	dust: ParticleEmitter?,
	light: PointLight,
	near: boolean,
	nextArc: number,
	nextFlicker: number,
}

local BeastAura = {}

local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local rng = Random.new()

local function rgb(color: BeastFx.Rgb): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function addFlame(parent: Instance, flame: BeastFx.Flame, size: number, tier: BeastFx.Tier): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "BeastFire"
	emitter.Texture = flame.texture
	emitter.Color = ColorSequence.new(rgb(flame.colors[1]), rgb(flame.colors[#flame.colors]))
	emitter.Rate = flame.rate * tier.rate
	local wide = flame.size * size * tier.size
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, wide * 0.6),
		NumberSequenceKeypoint.new(0.35, wide),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(flame.transparency, 1)
	emitter.Lifetime = NumberRange.new(flame.lifetime[1], flame.lifetime[2])
	emitter.Speed = NumberRange.new(flame.speed * size * 0.5, flame.speed * size)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, flame.rise * size, 0)
	emitter.LightEmission = flame.lightEmission
	emitter.Brightness = flame.brightness
	emitter.LightInfluence = 0
	emitter.Rotation = NumberRange.new(0, 360)
	local spin = flame.spin or 30
	emitter.RotSpeed = NumberRange.new(-spin, spin)
	emitter.ZOffset = 0.5
	emitter.Parent = parent
	return emitter
end

-- One lightning arc between two of the burning bones, fading fast, with a flash of the light
local function arc(aura: Aura)
	local count = #aura.bones
	if count < 2 then
		return
	end
	local first = rng:NextInteger(1, count)
	local second = rng:NextInteger(1, count - 1)
	if second >= first then
		second += 1
	end
	local a = aura.bones[first].TransformedWorldCFrame.Position
	local b = aura.bones[second].TransformedWorldCFrame.Position
	local cfg = aura.look.arcs
	local path = BeastFxRules.arc({ a.X, a.Y, a.Z }, { b.X, b.Y, b.Z }, cfg.segments, cfg.jitter, function()
		return rng:NextNumber()
	end)
	local color = rgb(cfg.color)
	local width = cfg.width * aura.size
	local fade = TweenInfo.new(cfg.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for index = 1, #path - 1 do
		local from = Vector3.new(path[index][1], path[index][2], path[index][3])
		local to = Vector3.new(path[index + 1][1], path[index + 1][2], path[index + 1][3])
		local segment = Instance.new("Part")
		segment.Name = "Arc"
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.CastShadow = false
		segment.Material = Enum.Material.Neon
		segment.Color = color
		segment.Size = Vector3.new(width, width, (to - from).Magnitude + width)
		segment.CFrame = CFrame.lookAt((from + to) / 2, to)
		segment.Parent = aura.model
		local tween = TweenService:Create(segment, fade, { Transparency = 1 })
		tween.Completed:Once(function()
			segment:Destroy()
		end)
		tween:Play()
	end
	aura.light.Brightness = aura.look.light.brightness * aura.tier.light * 2.5
end

-- Adds the aura to a creature model standing on `floor`, at a tier (BeastFx.TIERS: Legendary, S, A); nil for an
-- element or tier without one
function BeastAura.attach(model: Model, floor: CFrame, element: string, size: number, tierName: string): Aura?
	local look = BeastFx.ELEMENTS[element]
	local tier = BeastFx.TIERS[tierName]
	if not look or not tier then
		return nil
	end
	local bones: { Bone } = {}
	local points: { BeastFxRules.Point } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") then
			local at = descendant.WorldPosition
			table.insert(bones, descendant)
			table.insert(points, { at.X, at.Y, at.Z })
		end
	end
	local emitters: { ParticleEmitter } = {}
	local burning: { Bone } = {}
	for _, index in BeastFxRules.spread(points, tier.bones) do
		local bone = bones[index]
		table.insert(burning, bone)
		for _, flame in look.flames do
			table.insert(emitters, addFlame(bone, flame, size, tier))
		end
	end

	-- A flat invisible part over the footprint: ground flames rise from all of it, the light and dust sit on it
	local _, extent = model:GetBoundingBox()
	local base = Instance.new("Part")
	base.Name = "AuraBase"
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	base.Transparency = 1
	base.Size = Vector3.new(extent.X * 0.8, 0.2, extent.Z * 0.8)
	base.CFrame = floor * CFrame.new(0, 0.1, 0)
	base.Parent = model
	if tier.ground then
		for _, flame in look.ground do
			table.insert(emitters, addFlame(base, flame, size, tier))
		end
	end

	local light = Instance.new("PointLight")
	light.Color = rgb(look.light.color)
	light.Brightness = look.light.brightness * tier.light
	light.Range = look.light.range * math.sqrt(tier.light)
	light.Shadows = false
	local glow = Instance.new("Attachment")
	glow.Name = "Glow"
	glow.Position = Vector3.new(0, extent.Y * 0.5, 0)
	glow.Parent = base
	light.Parent = glow

	local dust: ParticleEmitter? = nil
	if tier.dust then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Dust"
		emitter.Texture = DUST_TEXTURE
		emitter.Color = ColorSequence.new(Color3.fromRGB(200, 190, 175))
		emitter.Transparency = NumberSequence.new(0.55, 1)
		emitter.Size = NumberSequence.new(size * 0.6, size * 1.6)
		emitter.Lifetime = NumberRange.new(0.6, 1)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.SpreadAngle = Vector2.new(70, 70)
		emitter.Rate = 0
		emitter.Parent = base
		dust = emitter
	end

	return {
		model = model,
		look = look,
		tier = tier,
		size = size,
		bones = burning,
		emitters = emitters,
		dust = dust,
		light = light,
		near = true,
		nextArc = 0,
		nextFlicker = 0,
	}
end

-- One frame. speed: studs a second (dust while moving); far: camera further than BeastFx.FAR (all off)
function BeastAura.step(aura: Aura, dt: number, speed: number, moving: boolean, far: boolean)
	local near = not far
	if near ~= aura.near then
		aura.near = near
		for _, emitter in aura.emitters do
			emitter.Enabled = near
		end
		aura.light.Enabled = near
	end
	local dust = aura.dust
	if dust then
		dust.Rate = if near and moving then math.min(speed * BeastFx.DUST.PER_SPEED, BeastFx.DUST.MAX) else 0
	end
	if not near then
		return
	end
	aura.nextFlicker -= dt
	if aura.nextFlicker <= 0 then
		aura.nextFlicker = BeastFx.FLICKER_SECONDS
		aura.light.Brightness = aura.look.light.brightness * aura.tier.light * rng:NextNumber(BeastFx.FLICKER[1], BeastFx.FLICKER[2])
	end
	if not aura.tier.arcs then
		return
	end
	aura.nextArc -= dt
	if aura.nextArc <= 0 then
		local every = aura.look.arcs.every
		aura.nextArc = rng:NextNumber(every[1], every[2]) * aura.tier.arcSlow
		arc(aura)
	end
end

return BeastAura
