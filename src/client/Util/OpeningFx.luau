--!strict
-- The pack opening's effects on the 3D stage (UI project 3 spec section 5), as particles on the Blender flipbooks
-- (Config/PackFx): the rip burst, tumbling foil shards (holo or gold) and glints; plus motes, the light leaking out of
-- the tear (a beam), turning rays and an aura behind the shown card. Counts follow the player's graphics level
-- (RevealRules.scaleCount). Everything lives in the stage's Fx folder; clear() empties it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local PackFx = require(Config:WaitForChild("PackFx"))
local PackOpening = require(Config:WaitForChild("PackOpening"))
local RevealRules = require(Shared:WaitForChild("Util"):WaitForChild("RevealRules"))

local OpeningStage = require((script.Parent :: Instance):WaitForChild("OpeningStage"))

local BURST_FRAMES_SHOWN = 40 -- of the RipBurst sheet's 64 (Config/PackFx)
local LAYOUTS = {
	[2] = Enum.ParticleFlipbookLayout.Grid2x2,
	[4] = Enum.ParticleFlipbookLayout.Grid4x4,
	[8] = Enum.ParticleFlipbookLayout.Grid8x8,
}

local OpeningFx = {}

local fxFolder: Folder? = nil
local raysGui: BillboardGui? = nil
local auraGui: BillboardGui? = nil
local motesEmitter: ParticleEmitter? = nil
local spin: RBXScriptConnection? = nil

local function folder(): Folder
	if not fxFolder or not fxFolder.Parent then
		local made = Instance.new("Folder")
		made.Name = "Fx"
		made.Parent = OpeningStage.folder()
		fxFolder = made
	end
	return fxFolder :: Folder
end

local function quality(): number
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return if ok and typeof(level) == "number" then level else 0
end

local function holder(at: CFrame, size: Vector3?): Part
	local part = Instance.new("Part")
	part.Name = "FxHolder"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size or Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = at
	part.Parent = folder()
	return part
end

local function emitter(parent: Instance, sheetName: string?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	e.LightEmission = 1
	e.Orientation = Enum.ParticleOrientation.FacingCamera
	if sheetName then
		local sheet = PackFx.SHEETS[sheetName]
		e.Texture = sheet.image
		e.FlipbookLayout = LAYOUTS[sheet.grid] or Enum.ParticleFlipbookLayout.None
	end
	e.Parent = parent
	return e
end

-- The rip burst: a flash, streaks, two shockwaves and sparks, white at first then `color`
function OpeningFx.burst(at: Vector3, color: Color3, size: number)
	local part = holder(CFrame.new(at))
	local e = emitter(part, "RipBurst")
	local lifetime = PackOpening.TEAR.BURST_SECONDS * PackFx.SHEETS.RipBurst.frames / BURST_FRAMES_SHOWN
	e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	e.Lifetime = NumberRange.new(lifetime)
	e.Speed = NumberRange.new(0)
	e.Size = NumberSequence.new(size)
	e.Rotation = NumberRange.new(0, 360)
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.25, color),
		ColorSequenceKeypoint.new(1, color),
	})
	e.ZOffset = 1
	e:Emit(1)
	Debris:AddItem(part, lifetime + 0.2)
end

-- Foil shards thrown out from `at` (spread: how hard), tumbling and falling; gold or holo
function OpeningFx.shards(at: Vector3, count: number, gold: boolean, spread: number)
	local amount = RevealRules.scaleCount(count, quality())
	if amount <= 0 then
		return
	end
	local part = holder(CFrame.new(at))
	local e = emitter(part, if gold then "ShardGold" else "ShardHolo")
	e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	e.FlipbookFramerate = NumberRange.new(14, 26)
	e.FlipbookStartRandom = true
	e.LightEmission = 0.2
	e.Lifetime = NumberRange.new(1, 1.8)
	e.Speed = NumberRange.new(3 * spread, 8 * spread)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -12, 0)
	e.Drag = 1.2
	e.Size = NumberSequence.new(0.3, 0.2)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-220, 220)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	e:Emit(amount)
	Debris:AddItem(part, 2.2)
end

-- One four-point twinkle at `at`
function OpeningFx.glint(at: Vector3, size: number, color: Color3?)
	local part = holder(CFrame.new(at))
	local e = emitter(part, "Glint")
	e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	e.Lifetime = NumberRange.new(0.42, 0.6)
	e.Speed = NumberRange.new(0)
	e.Size = NumberSequence.new(size)
	e.Rotation = NumberRange.new(0, 90)
	e.Color = ColorSequence.new(color or Color3.new(1, 1, 1))
	e.ZOffset = 2
	e:Emit(1)
	Debris:AddItem(part, 0.8)
end

-- Light leaking out along the tear (a beam from `from` to `to`) growing in over `seconds`; returns a function that
-- fades it out
function OpeningFx.leak(from: Vector3, to: Vector3, seconds: number): (seconds: number) -> ()
	local part = holder(CFrame.new((from + to) / 2))
	local a0 = Instance.new("Attachment")
	a0.WorldPosition = from
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.WorldPosition = to
	a1.Parent = part
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = PackFx.IMAGES.leak
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Width0, beam.Width1 = 0, 0
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 244, 210))
	beam.Parent = part
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(beam, info, { Width0 = 0.45, Width1 = 0.45 }):Play()
	return function(fade: number)
		local out = TweenService:Create(beam, TweenInfo.new(fade), { Width0 = 0, Width1 = 0 })
		out.Completed:Once(function()
			part:Destroy()
		end)
		out:Play()
	end
end

local function billboard(name: string, image: string, size: number): BillboardGui
	local part = holder(OpeningStage.root())
	part.Name = name
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size, size)
	gui.LightInfluence = 0
	gui.Brightness = 1.2
	gui.Adornee = part
	gui.Parent = part
	local label = Instance.new("ImageLabel")
	label.Name = "Image"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Image = image
	label.ImageTransparency = 1
	label.Parent = gui
	return gui
end

local function setBillboard(gui: BillboardGui, on: boolean, color: Color3, at: Vector3?, transparency: number)
	local adornee = gui.Adornee :: BasePart
	adornee.CFrame = CFrame.new(at or OpeningStage.root().Position)
	local label = gui:FindFirstChild("Image") :: ImageLabel
	label.ImageColor3 = color
	TweenService:Create(label, TweenInfo.new(0.35), { ImageTransparency = if on then transparency else 1 }):Play()
end

-- Turning light rays behind the shown card (at: the card's middle, pushed back a little by the caller)
function OpeningFx.rays(on: boolean, color: Color3, at: Vector3?)
	if not raysGui or not raysGui.Parent then
		raysGui = billboard("Rays", PackFx.IMAGES.rays, PackOpening.FLIP.RAYS_SIZE)
	end
	local gui = raysGui :: BillboardGui
	setBillboard(gui, on, color, at, 0.25)
	if on and not spin then
		local label = gui:FindFirstChild("Image") :: ImageLabel
		spin = RunService.RenderStepped:Connect(function(dt)
			label.Rotation = (label.Rotation + dt * 360 / PackOpening.ALIVE.RAYS_TURN_SECONDS) % 360
		end)
	elseif not on and spin then
		spin:Disconnect()
		spin = nil
	end
end

-- A soft glow behind the shown card in its colour (the caller breathes it with auraScale)
function OpeningFx.aura(on: boolean, color: Color3, at: Vector3?)
	if not auraGui or not auraGui.Parent then
		auraGui = billboard("Aura", PackFx.IMAGES.aura, PackOpening.FLIP.AURA_SIZE)
	end
	setBillboard(auraGui :: BillboardGui, on, color, at, 0.15)
end

-- The aura's size, times its normal size (a breath)
function OpeningFx.auraScale(scale: number)
	if auraGui then
		auraGui.Size = UDim2.fromScale(PackOpening.FLIP.AURA_SIZE * scale, PackOpening.FLIP.AURA_SIZE * scale)
	end
end

-- Motes rising past the card at `around` (rate a second, 0 stops them)
function OpeningFx.motes(rate: number, around: CFrame?, color: Color3?)
	local amount = RevealRules.scaleCount(math.floor(rate + 0.5), quality())
	if not motesEmitter or not motesEmitter.Parent then
		local part = holder(OpeningStage.root(), Vector3.new(3.2, 0.4, 1))
		part.Name = "Motes"
		local e = emitter(part, nil)
		e.Texture = PackFx.IMAGES.mote
		e.Shape = Enum.ParticleEmitterShape.Box
		e.EmissionDirection = Enum.NormalId.Top
		e.Speed = NumberRange.new(0.6, 1.4)
		e.Acceleration = Vector3.new(0, 1.2, 0)
		e.Lifetime = NumberRange.new(1.4, 2.3)
		e.Size = NumberSequence.new(0.12, 0.04)
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		motesEmitter = e
	end
	local e = motesEmitter :: ParticleEmitter
	if around then
		(e.Parent :: BasePart).CFrame = around
	end
	e.Color = ColorSequence.new(color or Color3.fromRGB(255, 224, 138))
	e.Rate = amount
	e.Enabled = amount > 0
end

function OpeningFx.clear()
	if spin then
		spin:Disconnect()
		spin = nil
	end
	if fxFolder then
		fxFolder:ClearAllChildren()
	end
	raysGui, auraGui, motesEmitter = nil, nil, nil
end

return OpeningFx
