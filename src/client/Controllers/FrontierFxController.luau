--!strict
-- The Frontier valley's effects on this client (spec docs/superpowers/specs/2026-11-10-frontier-valley-design.md: darker
-- and more dangerous than the Wild; numbers in Config/FrontierValley FX, maths in Util/FrontierFxRules): snow falling
-- round you in Frostwood; pairs of red eyes in its fog that fade as you come close and blink now and then; lightning
-- over Stormpeak (a flash and thunder) and a tornado turning far past its east cliffs; a violet vortex turning over the
-- Rift, its floating rocks bobbing, and now and then a tremor (a small camera shake and a rumble). Looks and sounds
-- only: nothing hurts anyone. Everything is built here, on this client; the Frontier place only.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SharedUtil = Shared:WaitForChild("Util")
local Bosses = require(Shared:WaitForChild("Config"):WaitForChild("Bosses"))
local Place = require(SharedUtil:WaitForChild("Place"))
local WildValley = require(SharedUtil:WaitForChild("WildValley"))
local FrontierFxRules = require(SharedUtil:WaitForChild("FrontierFxRules"))

local player = Players.LocalPlayer

local FrontierFxController = {}

local CHECK_SECONDS = 0.5 -- how often the area you're in is checked
local SNOW_FOLLOW = 0.25 -- seconds between moves of the snow box over you

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function anchored(parent: Instance, name: string, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function sound(parent: Instance, id: string, volume: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = parent
	return s
end

function FrontierFxController.Start()
	if not Place.isFrontier() then
		return
	end
	local valley = Place.getValley()
	local fx = valley.FX
	local folder = Instance.new("Folder")
	folder.Name = "FrontierFx"
	folder.Parent = workspace
	local rng = Random.new()
	local function roll(): number
		return rng:NextNumber()
	end
	local zone: number? = nil -- the area you're in (nil: the camp's passes, an arena)

	-- Snow round you in Frostwood: a box of falling flakes kept over your head
	local snowBox = anchored(folder, "Snow", Vector3.new(fx.snow.size, 1, fx.snow.size), CFrame.new(0, -500, 0))
	local snow = Instance.new("ParticleEmitter")
	snow.Shape = Enum.ParticleEmitterShape.Box
	snow.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.LightEmission = 0.6
	snow.Lifetime = NumberRange.new(8, 12)
	snow.Speed = NumberRange.new(1, 2)
	snow.Acceleration = Vector3.new(0.6, -2.5, 0)
	snow.Size = NumberSequence.new(0.35)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Rate = 0
	snow.Parent = snowBox

	-- Red eyes in Frostwood's fog: two small glowing dots each, turned toward you, fading as you come close
	type Eyes = { parts: { Part }, at: Vector3, blinkAt: number }
	local eyes: { Eyes } = {}
	for _, spot in fx.eyes do
		local ground = 0 -- Frostwood's ground
		local at = Vector3.new(spot.x, ground + spot.y, spot.z)
		local pair = {}
		for _, side in { -1, 1 } do
			local dot = anchored(folder, "Eye", Vector3.new(0.35, 0.22, 0.1), CFrame.new(at))
			dot.Material = Enum.Material.Neon
			dot.Color = rgb(fx.eyeColor)
			dot:SetAttribute("Side", side)
			table.insert(pair, dot)
		end
		table.insert(eyes, { parts = pair, at = at, blinkAt = os.clock() + FrontierFxRules.nextFlash(roll, fx.eyeBlink) })
	end

	-- The tornado past Stormpeak: stacked dark rings widening upward, turning
	local tornado = fx.tornado
	local funnel: { Part } = {}
	for index = 0, 7 do
		local t = index / 7
		local radius = tornado.radius * (0.25 + t)
		local ring = anchored(folder, "Tornado", Vector3.new(tornado.height / 8, radius * 2, radius * 2), CFrame.new(tornado.x, 30 + t * tornado.height, tornado.z) * CFrame.Angles(0, 0, math.rad(90)))
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.SmoothPlastic
		ring.Color = rgb(tornado.color)
		ring.Transparency = 0.35 + t * 0.3
		table.insert(funnel, ring)
	end

	-- The vortex over the Rift: the Wild portal's swirl, huge and violet, turning slowly overhead
	local vortex = fx.vortex
	local vortexPart = anchored(folder, "Vortex", Vector3.new(vortex.size, 1, vortex.size), CFrame.new(vortex.x, vortex.y, vortex.z))
	local swirl = Instance.new("Decal")
	swirl.Face = Enum.NormalId.Bottom
	swirl.Texture = vortex.image
	swirl.Color3 = rgb(vortex.color)
	swirl.Transparency = vortex.transparency
	swirl.Parent = vortexPart

	-- Lightning: a flash on the whole screen and thunder
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "FrontierFlash"
	flash.Brightness = 0
	flash.Parent = Lighting
	local thunder: { Sound } = {}
	for _, id in fx.lightning.sounds do
		table.insert(thunder, sound(folder, id, fx.lightning.volume))
	end
	local rumble = sound(folder, fx.tremor.sound, fx.tremor.volume)
	local nextFlash = os.clock() + FrontierFxRules.nextFlash(roll, fx.lightning.every)
	local nextTremor = os.clock() + FrontierFxRules.nextFlash(roll, fx.tremor.every)
	local tremorFrom: number? = nil

	local function lightning()
		flash.Brightness = 0.6
		TweenService:Create(flash, TweenInfo.new(fx.lightning.flash, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
		local clap = thunder[rng:NextInteger(1, #thunder)]
		task.delay(0.3 + roll() * 0.8, function()
			clap:Play()
		end)
	end

	-- The Rift's floating rocks (SceneryService's LANDMARKS) bob in place
	type Floating = { model: Model, home: CFrame, phase: number }
	local floating: { Floating } = {}
	local function findFloating()
		local scenery = workspace:FindFirstChild("Scenery")
		local holder = scenery and scenery:FindFirstChild("WildValley")
		if not holder then
			return
		end
		for _, model in holder:GetChildren() do
			if model:IsA("Model") and model.Name == "FloatingRock" and not model:GetAttribute("Bobbing") then
				model:SetAttribute("Bobbing", true)
				table.insert(floating, { model = model, home = model:GetPivot(), phase = roll() * math.pi * 2 })
			end
		end
	end

	local sinceCheck, sinceSnow = math.huge, math.huge
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local at = rootPosition()
		sinceCheck += dt
		if at and sinceCheck >= CHECK_SECONDS then
			sinceCheck = 0
			local inArena = WildValley.arenaZoneAt(valley, Bosses.ARENA_COPIES, at.X, at.Z) ~= nil
			zone = if inArena then nil else WildValley.zoneAt(valley, { x = at.X, z = at.Z })
			snow.Rate = if zone == fx.snow.zone then fx.snow.rate else 0
			if #floating < 4 then
				findFloating()
			end
		end
		sinceSnow += dt
		if at and sinceSnow >= SNOW_FOLLOW then
			sinceSnow = 0
			snowBox.CFrame = CFrame.new(at + Vector3.new(0, fx.snow.height, 0))
		end
		-- the eyes: turned toward you, fading as you near, now and then a blink
		local camera = workspace.CurrentCamera
		for _, pair in eyes do
			local distance = if at then (pair.at - at).Magnitude else math.huge
			local alpha = if zone == fx.snow.zone then FrontierFxRules.eyeAlpha(distance, fx.eyeFade) else 0
			local blinking = now >= pair.blinkAt and now < pair.blinkAt + 0.15
			if now >= pair.blinkAt + 0.15 then
				pair.blinkAt = now + FrontierFxRules.nextFlash(roll, fx.eyeBlink)
			end
			local facing = CFrame.lookAt(pair.at, Vector3.new(camera.CFrame.Position.X, pair.at.Y, camera.CFrame.Position.Z))
			for _, dot in pair.parts do
				dot.CFrame = facing * CFrame.new((dot:GetAttribute("Side") :: number) * 0.45, 0, 0)
				dot.Transparency = if blinking then 1 else 1 - alpha
			end
		end
		-- the tornado and the vortex turn
		for index, ring in funnel do
			ring.CFrame = ring.CFrame * CFrame.Angles(math.rad(tornado.turn * dt * (1 + index * 0.05)), 0, 0)
		end
		vortexPart.CFrame = vortexPart.CFrame * CFrame.Angles(0, math.rad(vortex.turn * dt), 0)
		-- lightning on Stormpeak
		if now >= nextFlash then
			nextFlash = now + FrontierFxRules.nextFlash(roll, fx.lightning.every)
			if zone == fx.lightning.zone then
				lightning()
			end
		end
		-- the Rift's floating rocks bob; now and then the ground trembles
		for _, rock in floating do
			if rock.model.Parent then
				local lift = math.sin(now * fx.floating.speed * math.pi * 2 + rock.phase) * fx.floating.bob
				rock.model:PivotTo(rock.home + Vector3.new(0, lift, 0))
			end
		end
		if now >= nextTremor then
			nextTremor = now + FrontierFxRules.nextFlash(roll, fx.tremor.every)
			if zone == fx.tremor.zone then
				tremorFrom = now
				rumble:Play()
			end
		end
	end)
	-- The tremor's shake, after the camera has moved this frame (so the camera scripts don't undo it)
	RunService:BindToRenderStep("FrontierTremor", Enum.RenderPriority.Camera.Value + 1, function()
		if not tremorFrom then
			return
		end
		local t = os.clock() - tremorFrom
		local amount = FrontierFxRules.shake(t, fx.tremor.length, fx.tremor.shake)
		if t >= fx.tremor.length then
			tremorFrom = nil
		elseif amount > 0 then
			local camera = workspace.CurrentCamera
			camera.CFrame = camera.CFrame * CFrame.new((roll() - 0.5) * 2 * amount, (roll() - 0.5) * 2 * amount, 0)
		end
	end)
end

return FrontierFxController
