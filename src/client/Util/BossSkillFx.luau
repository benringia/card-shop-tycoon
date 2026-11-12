--!strict
-- A boss's heal and enrage, made big (owner 2026-11-12: "shield, heal, and enrage should be noticeable"; looks in
-- Config/AttackFx BOSS_SKILLS). Util/FightFx plays them on any boss with those mechanics (a shield is the Frost Tyrant's
-- ice bubble, Util/IceFx):
--   heal    a green ring spreading from its feet, a pillar of light rising through it, motes spiralling up, its whole
--           body glowing green for a moment, a soft swell
--   enrage  a red burst and a shockwave, its roar, then its aura for the rest of the fight: a red glow pulsing on its
--           body, embers rising off it, a red light round it (stop() when the fight ends)
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AttackFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AttackFx"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))

local BossSkillFx = {}

export type Aura = { stop: () -> () }

local SKILLS = AttackFx.BOSS_SKILLS
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function flat(color: Color3, at: Vector3, radius: number, height: number): Part
	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Material = Enum.Material.Neon
	disc.Color = color
	disc.Size = Vector3.new(height, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	disc.Parent = ElementFx.folder()
	return disc
end

-- A ring of light spreading out from `at` to `radius`, fading
local function spreadingRing(color: Color3, at: Vector3, radius: number, seconds: number)
	local ring = flat(color, at + Vector3.new(0, 0.15, 0), radius * 0.2, 0.2)
	ring.Transparency = 0.2
	TweenService:Create(ring, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, seconds + 0.1)
end

-- The boss's body glowing `color` (a Highlight on its model, starting unseen; the caller fades it in)
local function glowOn(root: BasePart, color: Color3): Highlight?
	local body = root:FindFirstAncestorOfClass("Model")
	if not body then
		return nil
	end
	local glow = Instance.new("Highlight")
	glow.FillColor = color
	glow.OutlineColor = color
	glow.FillTransparency = 1
	glow.OutlineTransparency = 1
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Adornee = body
	glow.Parent = body
	return glow
end

local function emitter(parent: Instance, texture: string, color: Color3, rate: number, life: { number }, speed: { number }, size: { number }): ParticleEmitter
	local made = Instance.new("ParticleEmitter")
	made.Texture = texture
	made.Color = ColorSequence.new(color)
	made.LightEmission = 1
	made.Rate = rate
	made.Lifetime = NumberRange.new(life[1], life[2])
	made.Speed = NumberRange.new(speed[1], speed[2])
	made.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size[1]), NumberSequenceKeypoint.new(1, size[2]) })
	made.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	made.SpreadAngle = Vector2.new(25, 25)
	made.EmissionDirection = Enum.NormalId.Top
	made.Shape = Enum.ParticleEmitterShape.Box
	made.Parent = parent
	return made
end

-- An invisible box round the boss's body, following it (emitters and lights hang on it)
local function bodyBox(root: BasePart, height: number, life: number?): (Part, RBXScriptConnection)
	local box = Instance.new("Part")
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Transparency = 1
	box.Size = Vector3.new(height * 0.7, height * 0.8, height * 0.7)
	box.CFrame = CFrame.new(root.Position + Vector3.new(0, height * 0.35, 0))
	box.Parent = ElementFx.folder()
	local follow = RunService.Heartbeat:Connect(function()
		if not root.Parent then
			return
		end
		box.CFrame = CFrame.new(root.Position + Vector3.new(0, height * 0.35, 0))
	end)
	if life then
		Debris:AddItem(box, life)
		task.delay(life, function()
			follow:Disconnect()
		end)
	end
	return box, follow
end

-- The boss heals: its ring, its pillar of light, motes rising round it, its body glowing green, a soft swell
function BossSkillFx.heal(root: BasePart, height: number)
	local look = SKILLS.heal
	local color = rgb(look.color)
	local feet = Vector3.new(root.Position.X, root.Position.Y - height * 0.05, root.Position.Z)
	spreadingRing(color, feet, height * look.ring, look.seconds * 0.6)
	-- the pillar: up through it, widening, then thinning away
	local pillar = flat(color, feet + Vector3.new(0, height * look.pillar / 2, 0), height * 0.15, height * look.pillar)
	pillar.CFrame = CFrame.new(feet + Vector3.new(0, height * look.pillar / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Transparency = 0.55
	TweenService:Create(pillar, TweenInfo.new(look.seconds * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(height * look.pillar, height * 0.7, height * 0.7),
	}):Play()
	task.delay(look.seconds * 0.45, function()
		TweenService:Create(pillar, TweenInfo.new(look.seconds * 0.55), { Size = Vector3.new(height * look.pillar, 0.2, 0.2), Transparency = 1 }):Play()
	end)
	Debris:AddItem(pillar, look.seconds + 0.2)
	-- motes rising round it
	local box = bodyBox(root, height, look.seconds + 1.5)
	local motes = emitter(box, AttackFx.TEXTURES.glow, color, look.motes * ElementFx.detailShare(), { 1, 1.6 }, { 4, 9 }, { height * 0.06, 0 })
	task.delay(look.seconds, function()
		motes.Enabled = false
	end)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = height * 1.5
	light.Brightness = 0
	light.Parent = box
	TweenService:Create(light, TweenInfo.new(look.seconds * 0.3), { Brightness = look.light }):Play()
	task.delay(look.seconds * 0.5, function()
		TweenService:Create(light, TweenInfo.new(look.seconds * 0.5), { Brightness = 0 }):Play()
	end)
	-- its body glowing green: in, held, out
	local glow = glowOn(root, color)
	if glow then
		TweenService:Create(glow, TweenInfo.new(look.seconds * 0.3), { FillTransparency = look.glow, OutlineTransparency = 0 }):Play()
		task.delay(look.seconds * 0.6, function()
			TweenService:Create(glow, TweenInfo.new(look.seconds * 0.4), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
		end)
		Debris:AddItem(glow, look.seconds + 0.2)
	end
	ElementFx.burst(feet + Vector3.new(0, height * 0.6, 0), color, height * 0.12)
	ElementFx.sound(look.sound, root.Position, look.volume)
end

-- The boss enrages: a red burst and shockwave with its roar, then its aura until stop()
function BossSkillFx.enrage(root: BasePart, height: number): Aura
	local look = SKILLS.enrage
	local color = rgb(look.color)
	local fire = rgb(look.fire)
	local feet = Vector3.new(root.Position.X, root.Position.Y - height * 0.05, root.Position.Z)
	spreadingRing(color, feet, height * look.ring, 0.7)
	spreadingRing(fire, feet, height * look.ring * 0.7, 0.5)
	ElementFx.burst(feet + Vector3.new(0, height * 0.5, 0), color, height * 0.2)
	ElementFx.sound(look.sound, root.Position, look.volume)
	-- the aura: embers off its body, a red light, its body pulsing red
	local box, follow = bodyBox(root, height)
	local embers = emitter(box, FIRE_TEXTURE, fire, look.embers * ElementFx.detailShare(), { 0.6, 1.2 }, { 3, 7 }, { height * 0.08, 0 })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = height * 1.3
	light.Brightness = look.light
	light.Parent = box
	local glow = glowOn(root, color)
	local started = os.clock()
	local pulse = RunService.Heartbeat:Connect(function()
		if not glow then
			return
		end
		-- a heartbeat: brighter for a beat every pulse seconds
		local beat = (os.clock() - started) % look.pulse / look.pulse
		local strength = math.max(0, 1 - beat * 3)
		glow.FillTransparency = 1 - (1 - look.glow) * (0.45 + 0.55 * strength)
		glow.OutlineTransparency = 0.3 * (1 - strength)
	end)
	local stopped = false
	return {
		stop = function()
			if stopped then
				return
			end
			stopped = true
			pulse:Disconnect()
			follow:Disconnect()
			embers.Enabled = false
			Debris:AddItem(box, 1.5)
			if glow then
				glow:Destroy()
			end
		end,
	}
end

return BossSkillFx
