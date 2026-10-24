--!strict
-- An element effect on a part: Ember flames, Tide bubbles, Bloom petals, Volt sparks and lightning, Shade
-- smoke, with a light, all scaled by intensity 0..1 (Util/ElementFxRules from grade and stars). Used on
-- displayed Legendaries; built for summoned creatures too. Local only: nothing here replicates.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ElementFx = require(Shared:WaitForChild("Config"):WaitForChild("ElementFx"))
local ElementFxRules = require(Shared:WaitForChild("Util"):WaitForChild("ElementFxRules"))

type Emitter = ElementFx.Emitter
type Bolts = ElementFx.Bolts

local ElementAura = {}

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function addEmitter(parent: Instance, spec: Emitter, intensity: number, scale: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "ElementAura"
	emitter.Texture = spec.texture
	local colors = spec.colors
	emitter.Color = if #colors > 1 then ColorSequence.new(rgb(colors[1]), rgb(colors[#colors])) else ColorSequence.new(rgb(colors[1]))
	emitter.Rate = ElementFxRules.at(spec.rate, intensity)
	local size = ElementFxRules.at(spec.size, intensity) * scale
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	local speed = ElementFxRules.at(spec.speed, intensity) * scale
	emitter.Speed = NumberRange.new(speed * 0.7, speed)
	emitter.Lifetime = NumberRange.new(spec.lifetime[1], spec.lifetime[2])
	emitter.Acceleration = Vector3.new(spec.acceleration[1], spec.acceleration[2], spec.acceleration[3]) * scale
	emitter.SpreadAngle = Vector2.new(spec.spread, spec.spread)
	emitter.LightEmission = spec.lightEmission
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec.transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	local spin = spec.rotation
	if spin then
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-spin, spin)
	end
	emitter.Parent = parent
end

-- One bolt from a random point on the part's edge (in its own X/Y plane), jagged, fading fast
local function strike(part: BasePart, bolts: Bolts, intensity: number, rng: Random)
	local half = part.Size / 2
	local side = rng:NextInteger(1, 4)
	local along = rng:NextNumber(-1, 1)
	local start, out
	if side == 1 then
		start, out = Vector3.new(along * half.X, half.Y, 0), Vector3.new(along * 0.6, 1, 0)
	elseif side == 2 then
		start, out = Vector3.new(along * half.X, -half.Y, 0), Vector3.new(along * 0.6, -1, 0)
	elseif side == 3 then
		start, out = Vector3.new(half.X, along * half.Y, 0), Vector3.new(1, along * 0.6, 0)
	else
		start, out = Vector3.new(-half.X, along * half.Y, 0), Vector3.new(-1, along * 0.6, 0)
	end
	out = out.Unit
	local sideways = Vector3.new(-out.Y, out.X, 0)
	local length = ElementFxRules.at(bolts.length, intensity)
	local points = { part.CFrame:PointToWorldSpace(start) }
	for index = 1, bolts.segments do
		local bend = if index == bolts.segments then 0.4 else 1
		local point = start + out * length * index / bolts.segments + sideways * rng:NextNumber(-bolts.jitter, bolts.jitter) * bend
		-- A touch in front of the part (its front is -Z), so the bolt isn't hidden behind it
		table.insert(points, part.CFrame:PointToWorldSpace(point + Vector3.new(0, 0, -0.05)))
	end

	local color = rgb(bolts.color)
	local info = TweenInfo.new(bolts.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local segment = Instance.new("Part")
		segment.Name = "Lightning"
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.CastShadow = false
		segment.Material = Enum.Material.Neon
		segment.Color = color
		segment.Size = Vector3.new(bolts.width, bolts.width, (b - a).Magnitude)
		segment.CFrame = CFrame.lookAt((a + b) / 2, b)
		segment.Parent = part
		if index == 1 then
			local flash = Instance.new("PointLight")
			flash.Color = color
			flash.Brightness = bolts.flash
			flash.Range = 6
			flash.Shadows = false
			flash.Parent = segment
			TweenService:Create(flash, info, { Brightness = 0 }):Play()
		end
		TweenService:Create(segment, info, { Transparency = 1 }):Play()
		task.delay(bolts.seconds, segment.Destroy, segment)
	end
end

local function startBolts(part: BasePart, bolts: Bolts, intensity: number)
	local rng = Random.new()
	task.spawn(function()
		while part:IsDescendantOf(workspace) do
			task.wait(ElementFxRules.at(bolts.every, intensity) * rng:NextNumber(0.7, 1.3))
			local camera = workspace.CurrentCamera
			if part:IsDescendantOf(workspace) and camera and (camera.CFrame.Position - part.Position).Magnitude <= bolts.maxDistance then
				strike(part, bolts, intensity, rng)
			end
		end
	end)
end

local function addLight(part: BasePart, light: ElementFx.Light, intensity: number)
	local glow = Instance.new("PointLight")
	glow.Name = "ElementLight"
	glow.Color = rgb(light.color)
	local brightness = ElementFxRules.at(light.brightness, intensity)
	glow.Brightness = brightness
	glow.Range = ElementFxRules.at(light.range, intensity)
	glow.Shadows = false
	glow.Parent = part
	if not light.flicker then
		return
	end
	local rng = Random.new()
	task.spawn(function()
		while glow.Parent do
			glow.Brightness = brightness * rng:NextNumber(0.6, 1.15)
			task.wait(ElementFx.FLICKER_SECONDS)
		end
	end)
end

-- Adds the element's effect to the part. scale grows the particles for bigger things (creatures); 1 for cards.
-- Returns false for an element without an effect.
function ElementAura.attach(part: BasePart, element: string, intensity: number, scale: number?): boolean
	local fx = ElementFx.ELEMENTS[element]
	if not fx then
		return false
	end
	local size = scale or 1
	for _, spec in fx.emitters do
		addEmitter(part, spec, intensity, size)
	end
	addLight(part, fx.light, intensity)
	if fx.bolts then
		startBolts(part, fx.bolts, intensity)
	end
	return true
end

return ElementAura
