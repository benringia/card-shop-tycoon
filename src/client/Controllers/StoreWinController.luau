--!strict
-- The win card the moment a Store purchase goes through (owner 2026-11-14: "make it feel like a WIN"; Config/Luck WIN,
-- Remotes.StoreWin from LuckService and MonetizationService): once the purchase dialog has closed (Util/ScreenClear),
-- a card pops in the middle of the screen in the purchase's colours: light rays turning behind a big clover (a
-- briefcase for the job slot) swinging in, "2x LUCK!" / "SUPER LUCK!" (rainbow) / "+1 WORKER!" big, its line, the
-- shimmer sound, and clovers bursting round your character; then it fades.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Luck = require(Config:WaitForChild("Luck"))
local BoughtLuck = require(Shared:WaitForChild("Util"):WaitForChild("BoughtLuck"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local ScreenClear = require(ClientUtil:WaitForChild("ScreenClear"))
local SoundBank = require(ClientUtil:WaitForChild("SoundBank"))

local StoreWinController = {}

local player = Players.LocalPlayer
local WIN = Luck.WIN
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 111, 168)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 179, 64)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(95, 220, 140)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(79, 183, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(167, 123, 255)),
})
local showing = false
local queue: { { kind: string, seconds: number } } = {}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- Clovers bursting round your own character (only on your screen; the lucky aura itself everyone sees)
local function burst(colors: { { number } })
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Luck.AURA.CLOVER
	emitter.Color = ColorSequence.new(rgb(colors[1]), rgb(colors[#colors]))
	emitter.LightEmission = 0.3
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(1, 1.6)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -6, 0)
	emitter.Drag = 1.5
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Rate = 0
	emitter.Parent = root
	emitter:Emit(28)
	task.delay(2, emitter.Destroy, emitter)
end

local function show(kind: string, seconds: number)
	local look = WIN[kind]
	if typeof(look) ~= "table" then
		return
	end
	ScreenClear.wait() -- after the purchase dialog's OK
	local gui = Instance.new("ScreenGui")
	gui.Name = "StoreWin"
	gui.DisplayOrder = 60
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.45)
	card.Size = UDim2.fromOffset(300, 300)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.ClipsDescendants = true
	card.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 26)
	round.Parent = card
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(1, 1, 1)
	edge.Thickness = 3
	edge.Transparency = 0.3
	edge.Parent = card
	local fill = Instance.new("UIGradient")
	fill.Color = if look.rainbow then RAINBOW else ColorSequence.new(rgb(look.colors[1]), rgb(look.colors[2]))
	fill.Rotation = if look.rainbow then 30 else 90
	fill.Parent = card
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(300, 300)
	size.Parent = card
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = card

	local rays = Instance.new("ImageLabel")
	rays.BackgroundTransparency = 1
	rays.Image = WIN.RAYS
	rays.ImageTransparency = 0.25
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.4)
	rays.Size = UDim2.fromScale(1.6, 1.6)
	rays.Parent = card

	local picture: GuiObject
	if kind == "jobslot" then
		local glyph = Instance.new("TextLabel")
		glyph.BackgroundTransparency = 1
		glyph.Font = Enum.Font.FredokaOne
		glyph.Text = "💼"
		glyph.TextScaled = true
		picture = glyph
	else
		local clover = Instance.new("ImageLabel")
		clover.BackgroundTransparency = 1
		clover.Image = Luck.AURA.CLOVER
		clover.ImageColor3 = if look.rainbow then Color3.fromRGB(255, 245, 200) else Color3.fromRGB(235, 255, 238)
		picture = clover
	end
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.36)
	picture.Size = UDim2.fromOffset(120, 120)
	picture.Rotation = -30
	picture.Parent = card

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.Text = look.title
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0.63)
	title.Size = UDim2.new(0.9, 0, 0, 46)
	title.Parent = card
	local titleEdge = Instance.new("UIStroke")
	titleEdge.Color = Color3.fromRGB(30, 20, 50)
	titleEdge.Thickness = 3
	titleEdge.Transparency = 0.35
	titleEdge.Parent = title
	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.Font = Enum.Font.GothamBold
	line.Text = BoughtLuck.winText(look.text, seconds)
	line.TextColor3 = Color3.new(1, 1, 1)
	line.TextSize = 15
	line.TextWrapped = true
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.fromScale(0.5, 0.8)
	line.Size = UDim2.new(0.86, 0, 0, 40)
	line.Parent = card

	local sound = SoundBank.make(WIN.SOUND)
	sound.Volume = 0.6
	sound.Parent = gui
	sound:Play()
	if kind ~= "jobslot" then
		burst(look.colors)
	end

	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(picture, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	TweenService:Create(rays, TweenInfo.new(WIN.SECONDS + 1, Enum.EasingStyle.Linear), { Rotation = 90 }):Play()
	TweenService:Create(picture, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0.7), {
		Size = UDim2.fromOffset(132, 132),
	}):Play()
	task.wait(WIN.SECONDS)
	local fade = TweenInfo.new(0.35)
	TweenService:Create(scale, fade, { Scale = 0.85 }):Play()
	TweenService:Create(card, fade, { BackgroundTransparency = 1 }):Play()
	for _, item in card:GetDescendants() do
		if item:IsA("TextLabel") then
			TweenService:Create(item, fade, { TextTransparency = 1 }):Play()
		elseif item:IsA("ImageLabel") then
			TweenService:Create(item, fade, { ImageTransparency = 1 }):Play()
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, fade, { Transparency = 1 }):Play()
		end
	end
	task.wait(0.4)
	gui:Destroy()
end

-- One card at a time: two purchases close together play one after the other
local function play()
	if showing then
		return
	end
	showing = true
	while #queue > 0 do
		local next = table.remove(queue, 1) :: { kind: string, seconds: number }
		show(next.kind, next.seconds)
	end
	showing = false
end

function StoreWinController.Start()
	Remotes.StoreWin.OnClientEvent:Connect(function(kind: unknown, seconds: unknown)
		if typeof(kind) ~= "string" or typeof(WIN[kind]) ~= "table" then
			return
		end
		table.insert(queue, { kind = kind, seconds = if typeof(seconds) == "number" then seconds else 0 })
		task.spawn(play)
	end)
end

return StoreWinController
