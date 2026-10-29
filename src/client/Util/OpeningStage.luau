--!strict
-- The 3D pack opening's stage (UI project 3 spec section 4): client-only parts far above the world (a violet glow
-- backdrop and two lights), a Scriptable camera looking along +Z at the stage's middle, and the cinema on top: black
-- letterbox bars, a white flash, a dim (ColorCorrection), bloom and a push-in blur on the camera. Built once and kept;
-- show() takes the camera (saving it, like the binder) and hide() gives it back. Numbers: Config/PackOpening.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local PackOpening = require(Config:WaitForChild("PackOpening"))
local CardDesign = require(Config:WaitForChild("CardDesign"))

local ClientUtil = script.Parent :: Instance
local Hud = require(ClientUtil:WaitForChild("Hud"))
local ListenAtCharacter = require(ClientUtil:WaitForChild("ListenAtCharacter"))
local WorldTags = require(ClientUtil:WaitForChild("WorldTags"))

local REASON = "PackOpening"

local OpeningStage = {}

local root = CFrame.new(PackOpening.STAGE_POSITION)
-- The camera sits in front of the stage's middle (at -Z) and looks along +Z, so models whose fronts face -Z face it
local home = CFrame.lookAt(PackOpening.STAGE_POSITION - Vector3.new(0, 0, PackOpening.CAMERA_DISTANCE), PackOpening.STAGE_POSITION)

local folder: Folder? = nil
local gui: ScreenGui? = nil
local barTop: Frame
local barBottom: Frame
local flashFrame: Frame
local bloom: BloomEffect
local grade: ColorCorrectionEffect
local blur: DepthOfFieldEffect
local base: CFrameValue
local shown = false
local saved: { cameraType: Enum.CameraType, cframe: CFrame, fov: number }? = nil
local render: RBXScriptConnection? = nil
local shakeUntil, shakeAmount, shakeSeconds, nextShake = 0, 0, 1, 0
local shakeOffset = CFrame.new()
local live: { [Sound]: string } = {} -- sounds playing now, by their SOUNDS name

local function tween(instance: Instance, seconds: number, goals: { [string]: any }, style: Enum.EasingStyle?): Tween
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local t = TweenService:Create(instance, info, goals)
	t:Play()
	return t
end

local function anchoredPart(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function buildScene(): Folder
	local scene = Instance.new("Folder")
	scene.Name = "PackOpeningStage"
	local look = PackOpening.BACKDROP
	-- The backdrop: near-black with a big violet glow in the middle, ignoring the world's light
	local backdrop = anchoredPart("Backdrop", Vector3.new(look.SIZE, look.SIZE, 0.2), root * CFrame.new(0, 0, look.BEHIND), scene)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.LightInfluence = 0
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 4
	surface.Parent = backdrop
	local dark = Instance.new("Frame")
	dark.Size = UDim2.fromScale(1, 1)
	dark.BackgroundColor3 = look.EDGE
	dark.BorderSizePixel = 0
	dark.Parent = surface
	local glow = Instance.new("ImageLabel")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(look.GLOW, look.GLOW)
	glow.BackgroundTransparency = 1
	glow.Image = CardDesign.IMAGES.GLOW
	glow.ImageColor3 = look.MIDDLE
	glow.Parent = dark
	for name, light in PackOpening.LIGHTS do
		local holder = anchoredPart(`{name}Light`, Vector3.one, root * CFrame.new(light.AT), scene)
		local point = Instance.new("PointLight")
		point.Color = light.COLOR
		point.Brightness = light.BRIGHTNESS
		point.Range = light.RANGE
		point.Shadows = false
		point.Parent = holder
	end
	scene.Parent = workspace
	return scene
end

local function buildCinema(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "PackOpeningCinema"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 40
	screen.Enabled = false
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function bar(name: string, anchorY: number): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.AnchorPoint = Vector2.new(0, anchorY)
		frame.Size = UDim2.fromScale(1, PackOpening.LETTERBOX)
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.Parent = screen
		return frame
	end
	barTop = bar("BarTop", 1) -- hidden above the screen until bars(true)
	barBottom = bar("BarBottom", 0)
	barTop.Position = UDim2.fromScale(0, 0)
	barBottom.Position = UDim2.fromScale(0, 1)
	flashFrame = Instance.new("Frame")
	flashFrame.Name = "Flash"
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.ZIndex = 10
	flashFrame.Parent = screen
	return screen
end

local function buildPost()
	local post = PackOpening.POST
	bloom = Instance.new("BloomEffect")
	bloom.Intensity = post.BLOOM_INTENSITY
	bloom.Size = post.BLOOM_SIZE
	bloom.Threshold = post.BLOOM_THRESHOLD
	grade = Instance.new("ColorCorrectionEffect")
	blur = Instance.new("DepthOfFieldEffect")
	blur.FarIntensity = 0
	blur.NearIntensity = 0
	blur.InFocusRadius = 4
end

function OpeningStage.build()
	if folder then
		return
	end
	folder = buildScene()
	gui = buildCinema()
	buildPost()
	base = Instance.new("CFrameValue")
	base.Value = home
end

-- The world stays away while the stage shows: the camera's own copy of the scene's offset, plus any shake
local function step()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	if now < shakeUntil then
		if now >= nextShake then
			local fade = (shakeUntil - now) / shakeSeconds
			local a = shakeAmount * fade
			shakeOffset = CFrame.new((math.random() - 0.5) * 2 * a, (math.random() - 0.5) * 2 * a, 0)
			nextShake = now + PackOpening.SHAKE_SECONDS_STEP
		end
	else
		shakeOffset = CFrame.new()
	end
	camera.CFrame = base.Value * shakeOffset
end

function OpeningStage.show()
	OpeningStage.build()
	local camera = workspace.CurrentCamera
	if shown or not camera then
		return
	end
	saved = { cameraType = camera.CameraType, cframe = camera.CFrame, fov = camera.FieldOfView }
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = PackOpening.FIELD_OF_VIEW
	base.Value = home
	camera.CFrame = home
	bloom.Parent = camera
	grade.Parent = camera
	blur.Parent = camera
	render = RunService.RenderStepped:Connect(step)
	ListenAtCharacter.hold(REASON)
	WorldTags.hide(REASON)
	Hud.setHidden(REASON, true)
	if gui then
		gui.Enabled = true
	end
	shown = true
end

function OpeningStage.hide()
	if not shown then
		return
	end
	shown = false
	if render then
		render:Disconnect()
		render = nil
	end
	shakeUntil = 0
	for sound in live do
		sound:Destroy()
	end
	table.clear(live)
	barTop.Position = UDim2.fromScale(0, 0)
	barBottom.Position = UDim2.fromScale(0, 1)
	flashFrame.BackgroundTransparency = 1
	grade.Brightness, grade.Contrast = 0, 0
	blur.FarIntensity = 0
	bloom.Parent, grade.Parent, blur.Parent = nil, nil, nil
	if gui then
		gui.Enabled = false
	end
	local camera = workspace.CurrentCamera
	local before = saved
	if camera and before then
		camera.CFrame = before.cframe
		camera.FieldOfView = before.fov
		camera.CameraType = before.cameraType
		-- Roblox doesn't move a Scriptable camera's subject to a respawned character: follow the current one
		local character = Players.LocalPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if before.cameraType == Enum.CameraType.Custom and humanoid then
			camera.CameraSubject = humanoid
		end
	end
	saved = nil
	ListenAtCharacter.release(REASON)
	WorldTags.show(REASON)
	Hud.setHidden(REASON, false)
end

function OpeningStage.isShown(): boolean
	return shown
end

function OpeningStage.root(): CFrame
	return root
end

function OpeningStage.home(): CFrame
	return home
end

function OpeningStage.folder(): Folder
	OpeningStage.build()
	return folder :: Folder
end

-- The stage point at viewport pixel (x, y), `depth` studs in front of the camera's home (shake and push left out)
function OpeningStage.screenPoint(x: number, y: number, depth: number): Vector3
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local halfH = depth * math.tan(math.rad(PackOpening.FIELD_OF_VIEW) / 2)
	local halfW = halfH * view.X / view.Y
	local dx = (x / view.X - 0.5) * 2
	local dy = (0.5 - y / view.Y) * 2
	return (home * CFrame.new(dx * halfW, dy * halfH, -depth)).Position
end

-- The camera moves toward `focus` until it shows `scale` times bigger, the far stage softly blurred
function OpeningStage.push(scale: number, focus: Vector3, seconds: number)
	local away = home.Position - focus
	local target = CFrame.new(focus + away / scale) * home.Rotation
	tween(base, seconds, { Value = target })
	blur.FocusDistance = away.Magnitude / scale
	tween(blur, seconds, { FarIntensity = PackOpening.POST.FOCUS_BLUR / 10 })
end

-- Back to the home view
function OpeningStage.ease(seconds: number)
	tween(base, seconds, { Value = home })
	tween(blur, seconds, { FarIntensity = 0 })
end

function OpeningStage.shake(studs: number, seconds: number)
	shakeAmount = studs
	shakeSeconds = math.max(seconds, 1e-3)
	shakeUntil = os.clock() + seconds
	nextShake = 0
end

function OpeningStage.bars(on: boolean, seconds: number)
	tween(barTop, seconds, { Position = UDim2.fromScale(0, if on then PackOpening.LETTERBOX else 0) })
	tween(barBottom, seconds, { Position = UDim2.fromScale(0, if on then 1 - PackOpening.LETTERBOX else 1) })
end

function OpeningStage.flash(peak: number, seconds: number)
	flashFrame.BackgroundTransparency = 1
	local rise = tween(flashFrame, seconds * 0.15, { BackgroundTransparency = 1 - peak }, Enum.EasingStyle.Linear)
	rise.Completed:Once(function()
		tween(flashFrame, seconds * 0.85, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
	end)
end

-- 0 = the normal stage, 1 = the full dim of a big pull
function OpeningStage.dim(amount: number, seconds: number)
	local post = PackOpening.POST
	tween(grade, seconds, { Brightness = post.DIM_BRIGHTNESS * amount, Contrast = post.DIM_CONTRAST * amount })
end

local function volumeOf(name: string): number
	return (PackOpening.VOLUMES :: any)[name] or 0.5
end

local function silence(sound: Sound)
	live[sound] = nil
	sound:Destroy()
end

-- Plays one of Config/PackOpening SOUNDS (nothing while its id is empty) as a one-shot of its own, so quick repeats
-- (a card per 0.19s) overlap instead of cutting each other off. Made on the client, so only this player hears it.
function OpeningStage.play(name: string)
	local id = (PackOpening.SOUNDS :: any)[name]
	if typeof(id) ~= "string" or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volumeOf(name)
	sound.Parent = SoundService
	live[sound] = name
	sound.Ended:Once(function()
		silence(sound)
	end)
	sound:Play()
end

-- Fades the playing copies of a sound out over `seconds` (the tease's rise at the reveal's hit)
function OpeningStage.fade(name: string, seconds: number)
	for sound, playing in live do
		if playing == name then
			local out = TweenService:Create(sound, TweenInfo.new(seconds), { Volume = 0 })
			out.Completed:Once(function()
				if live[sound] then
					silence(sound)
				end
			end)
			out:Play()
		end
	end
end

-- The sounds to preload (ContentProvider) when the stage first shows
function OpeningStage.soundIds(): { string }
	local ids = {}
	for _, id in PackOpening.SOUNDS do
		if id ~= "" then
			table.insert(ids, id)
		end
	end
	return ids
end

return OpeningStage
