--!strict
-- A ParticleEmitter built from a pack effect's plain-data spec (owner 2026-11-08: effects copied from free Creator Store
-- VFX packs, docs/weapons.md "Pack effects"; specs in Config/SwordFx IMPACT and Config/WeaponLooks ELEMENT_AURA).
-- Sizes and speeds are `scale` times the spec's; `color = "deep"` takes `deep`. The emitter comes back unparented at
-- rate 0: the caller places it, then bursts it (Emit) or gives it a rate.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AttackFx"))

local PackEmitter = {}

local FACINGS = {
	camera = Enum.ParticleOrientation.FacingCamera,
	perpendicular = Enum.ParticleOrientation.VelocityPerpendicular,
	parallel = Enum.ParticleOrientation.VelocityParallel,
}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- { { time, value, envelope? } } as a NumberSequence, values and envelopes `scale` times
local function sequence(points: { { number } }, scale: number): NumberSequence
	local keypoints = {}
	for _, point in points do
		table.insert(keypoints, NumberSequenceKeypoint.new(point[1], point[2] * scale, (point[3] or 0) * scale))
	end
	return NumberSequence.new(keypoints)
end

function PackEmitter.make(spec: any, scale: number, deep: Color3?): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = (AttackFx.TEXTURES :: any)[spec.texture] or ""
	emitter.Color = ColorSequence.new(if spec.color == "deep" then deep or Color3.new(1, 1, 1) else rgb(spec.color))
	emitter.LightEmission = spec.emission or 1
	emitter.LightInfluence = 0
	emitter.Brightness = spec.brightness
	emitter.ZOffset = spec.zOffset or 0
	emitter.Lifetime = NumberRange.new(spec.lifetime[1], spec.lifetime[2])
	local speed = spec.speed or { 0, 0 }
	emitter.Speed = NumberRange.new(speed[1] * scale, speed[2] * scale)
	local spread = spec.spread or { 0, 0 }
	emitter.SpreadAngle = Vector2.new(spread[1], spread[2])
	local rotation = spec.rotation or { 0, 0 }
	emitter.Rotation = NumberRange.new(rotation[1], rotation[2])
	local spin = spec.rotSpeed or { 0, 0 }
	emitter.RotSpeed = NumberRange.new(spin[1], spin[2])
	local accel = spec.accel or { 0, 0, 0 }
	emitter.Acceleration = Vector3.new(accel[1], accel[2], accel[3])
	emitter.Drag = spec.drag or 0
	emitter.EmissionDirection = (Enum.NormalId :: any)[spec.direction or "Top"]
	emitter.Orientation = FACINGS[spec.facing or "camera"]
	emitter.Size = sequence(spec.size, scale)
	emitter.Transparency = sequence(spec.transparency, 1)
	if spec.squash then
		emitter.Squash = sequence(spec.squash, 1)
	end
	if spec.flipbook then
		emitter.FlipbookLayout = (Enum.ParticleFlipbookLayout :: any)[spec.flipbook.layout or "Grid4x4"]
		emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		emitter.FlipbookStartRandom = spec.flipbook.random == true
	end
	emitter.TimeScale = spec.timeScale or 1
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.ShapeInOut = if spec.inOut then Enum.ParticleEmitterShapeInOut.InAndOut else Enum.ParticleEmitterShapeInOut.Outward
	emitter.Rate = 0
	return emitter
end

return PackEmitter
