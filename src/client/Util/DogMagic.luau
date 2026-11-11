--!strict
-- A guide dog's magical entrance (the owner 2026-11-11: "change the pish and chicken entrance cinematic. not the same as
-- this but still epic/magical/welcoming"; Config/Pish ARRIVAL.MAGIC; Util/DogArrival runs it): a golden magic circle on
-- the ground calling him (spinning, glowing brighter, motes pulling in, a twinkling), a pop of stars and light he hops
-- out of, his name card popping up with a cheerful sting, sparkles trailing him as he runs, and stars as he arrives.
-- The stars are the Euphoric Games VFX Pack's (vetted 2026-11-08, Util/PackEmitter), like the welcome finale's.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pish = require(Shared:WaitForChild("Config"):WaitForChild("Pish"))
local SwordFx = require(Shared:WaitForChild("Config"):WaitForChild("SwordFx"))
local ClientUtil = script.Parent :: Instance
local ElementFx = require(ClientUtil:WaitForChild("ElementFx"))
local PackEmitter = require(ClientUtil:WaitForChild("PackEmitter"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

local DogMagic = {}

local MAGIC = Pish.ARRIVAL.MAGIC
local GOLD = Color3.fromRGB(255, 205, 90)
local UP = Vector3.yAxis

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- One of its sounds, heard as part of the scene (2D, like the cinematic's)
function DogMagic.sound(key: string)
	local id = (MAGIC.sounds :: any)[key]
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = (MAGIC.volumes :: any)[key] or 0.5
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 8)
end

local function holder(cframe: CFrame, life: number): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = cframe
	part.Parent = ElementFx.folder()
	Debris:AddItem(part, life)
	return part
end

local function burst(at: Vector3, piece: any, scale: number)
	local emitter = PackEmitter.make(piece.emitter, scale, nil)
	emitter.Parent = holder(CFrame.new(at), 2)
	emitter:Emit(piece.count)
end

-- The magic circle calling him at `at` (on the ground) for `seconds`: a gold ring and glow spinning on the ground,
-- brightening, motes pulling in, a light. Returns its stop (it fades).
function DogMagic.circle(at: Vector3, seconds: number): () -> ()
	local cfg = MAGIC.circle
	local across = cfg.radius * 2
	local function flat(image: string, transparency: number, size: number): (Part, Decal)
		local part = holder(CFrame.new(at + UP * cfg.lift), seconds + 2)
		part.Size = Vector3.new(size, 0.05, size)
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Top
		decal.Texture = image
		decal.Color3 = GOLD
		decal.Transparency = transparency
		decal.Parent = part
		return part, decal
	end
	local ring, ringDecal = flat(SwordFx.RING_OUTLINE, 0.1, across)
	local glow, glowDecal = flat(SwordFx.RING_GLOW, 0.75, across * 0.9)
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = cfg.light
	light.Brightness = 0.5
	light.Shadows = false
	light.Parent = ring
	TweenService:Create(light, TweenInfo.new(seconds), { Brightness = 4 }):Play()
	TweenService:Create(glowDecal, TweenInfo.new(seconds), { Transparency = 0.25 }):Play()
	-- motes pulling in from round it
	local well = holder(CFrame.new(at + UP * 1.5), seconds + 2)
	well.Shape = Enum.PartType.Ball
	well.Size = Vector3.one * across * 1.4
	local pull = ElementFx.emitter(well, "spark", GOLD, {
		size = { 0.35, 0.08 },
		life = 0.6,
		speed = { -5, -7 },
		rotation = 0,
		orientation = Enum.ParticleOrientation.VelocityParallel,
		brightness = 2.5,
	})
	pull.Shape = Enum.ParticleEmitterShape.Sphere
	pull.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pull.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	pull.Rate = math.round(60 * ElementFx.detailShare())
	local started = os.clock()
	local spinning = RunService.RenderStepped:Connect(function()
		local turn = math.rad((os.clock() - started) * cfg.spin)
		ring.CFrame = CFrame.new(at + UP * cfg.lift) * CFrame.Angles(0, turn, 0)
		glow.CFrame = CFrame.new(at + UP * cfg.lift) * CFrame.Angles(0, -turn * 0.6, 0)
	end)
	local stopped = false
	return function()
		if stopped then
			return
		end
		stopped = true
		pull.Rate = 0
		local fade = TweenInfo.new(0.6)
		TweenService:Create(ringDecal, fade, { Transparency = 1 }):Play()
		TweenService:Create(glowDecal, fade, { Transparency = 1 }):Play()
		TweenService:Create(light, fade, { Brightness = 0 }):Play()
		task.delay(0.7, function()
			spinning:Disconnect()
		end)
	end
end

-- Its textures downloaded ahead (DogArrival calls this as the circle starts calling)
function DogMagic.preload()
	PackEmitter.preload({ MAGIC.stars.emitter, MAGIC.burst.emitter, MAGIC.glow.emitter })
end

-- He pops out at `at`: stars, a burst of streaks, a flash of light, a twinkle and a pop
function DogMagic.poof(at: Vector3)
	burst(at, MAGIC.burst, 1)
	burst(at, MAGIC.stars, 1)
	burst(at, MAGIC.glow, 1)
	ElementFx.burst(at, GOLD, 1.6)
	DogMagic.sound("poof")
	DogMagic.sound("pop")
end

-- Stars as he arrives in front of you at `at`
function DogMagic.arrive(at: Vector3)
	burst(at, MAGIC.stars, 0.8)
	DogMagic.sound("arrive")
end

-- Sparkles trailing him while he runs; returns its stop
function DogMagic.trail(dog: BasePart): () -> ()
	local cfg = MAGIC.trail
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 0.6, 0)
	attachment.Parent = dog
	local emitter = ElementFx.emitter(attachment, "spark", rgb(cfg.color), {
		size = { cfg.size, 0 },
		life = { cfg.lifetime[1], cfg.lifetime[2] },
		speed = { 0.5, 2 },
		rotation = 0,
		brightness = 2.5,
	})
	emitter.Rate = math.round(cfg.rate * ElementFx.detailShare())
	return function()
		emitter.Rate = 0
		Debris:AddItem(attachment, 1.2)
	end
end

-- His name card: his name big and bouncy over a gold glow, what he is to you under it, a sparkle ding and his sting;
-- it pops in and fades after MAGIC.banner.seconds
function DogMagic.banner(name: string, role: string, color: Color3)
	local player = Players.LocalPlayer
	local screen = Instance.new("ScreenGui")
	screen.Name = "DogArrivalName"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 40
	screen.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0.12)
	frame.Size = UDim2.fromOffset(420, 120)
	frame.BackgroundTransparency = 1
	frame.Parent = screen
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = frame
	local title = UIKit.label(frame, name, Enum.Font.FredokaOne, 72, Color3.new(1, 1, 1))
	title.Size = UDim2.new(1, 0, 0, 80)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local stroke = UIKit.outlined(title, 4)
	if stroke then
		stroke.Color = color
	end
	local sub = UIKit.label(frame, role, Enum.Font.FredokaOne, 28, color)
	sub.Position = UDim2.fromOffset(0, 80)
	sub.Size = UDim2.new(1, 0, 0, 36)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	UIKit.outlined(sub, 2)
	local cfg = MAGIC.banner
	TweenService:Create(scale, TweenInfo.new(cfg.pop, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	DogMagic.sound("ding")
	DogMagic.sound("sting")
	task.delay(cfg.seconds, function()
		local fade = TweenInfo.new(0.4)
		for _, label in { title, sub } do
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			local outline = label:FindFirstChildOfClass("UIStroke")
			if outline then
				TweenService:Create(outline, fade, { Transparency = 1 }):Play()
			end
		end
		TweenService:Create(scale, fade, { Scale = 1.15 }):Play()
		Debris:AddItem(screen, 0.5)
	end)
end

return DogMagic
