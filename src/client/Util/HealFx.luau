--!strict
-- Your creature being healed at the spring (owner 2026-11-04; looks in Config/Party HEAL_FX, CreatureController turns it
-- on while you stand at the spring): a "+ Healing" pill above its name tag, green plus signs float up off it and fade,
-- sparkles rise round it, a green light breathes on it and a ring ripples out at its feet now and then. Client-side,
-- only your own creature.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Party = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Party"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))

local HealFx = {}

local CFG = Party.HEAL_FX
local GREEN = Color3.fromRGB(CFG.color[1], CFG.color[2], CFG.color[3])
local PALE = GREEN:Lerp(Color3.new(1, 1, 1), 0.25)

-- One "+" that floats up from somewhere round the creature and fades
local function plus(root: BasePart, height: number)
	local gui = Instance.new("BillboardGui")
	gui.LightInfluence = 0
	local angle = math.random() * math.pi * 2
	local spread = math.max(1, height * 0.45)
	local from = Vector3.new(math.cos(angle) * spread, height * (0.3 + math.random() * 0.5), math.sin(angle) * spread)
	gui.StudsOffsetWorldSpace = from
	gui.Adornee = root
	gui.Parent = root
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "+"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = if math.random() < 0.5 then GREEN else PALE
	label.TextStrokeColor3 = Color3.fromRGB(20, 80, 40)
	label.TextStrokeTransparency = 0.3
	label.TextTransparency = 1
	label.Parent = gui
	local size = CFG.plusSize * (0.75 + math.random() * 0.5)
	gui.Size = UDim2.fromOffset(size, size)
	local info = TweenInfo.new(CFG.plusLife, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = from + Vector3.new(0, CFG.plusRise, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(CFG.plusLife * 0.25), { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	task.delay(CFG.plusLife * 0.55, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(CFG.plusLife * 0.45), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
	Debris:AddItem(gui, CFG.plusLife + 0.1)
end

-- "+ Healing" in a green pill just above the creature's name tag (CreatureVisuals.makeTag sits at `height` + 1)
local function pill(root: BasePart, height: number): (BillboardGui, UIScale)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealTag"
	gui.Size = UDim2.fromOffset(160, 92) -- the tag's 44 px in the middle, the pill on top
	gui.StudsOffset = Vector3.new(0, height + 1, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Adornee = root
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0)
	label.Size = UDim2.fromOffset(0, 22)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundColor3 = GREEN:Lerp(Color3.new(0, 0, 0), 0.25)
	label.Text = "  + Healing  "
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 15
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.6
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = label
	local scale = Instance.new("UIScale")
	scale.Parent = label
	gui.Parent = root
	return gui, scale
end

-- Starts the effect on a drawn creature (its root part and its spot on the ground), `height` studs tall; returns a stop
function HealFx.start(body: { root: BasePart, cframe: CFrame }, height: number): () -> ()
	local root = body.root
	local sparkles = ElementFx.emitter(root, "spark", GREEN, {
		size = { 0.35, 0 },
		life = { 0.9, 1.4 },
		speed = { 1.5, 3 },
		spread = 25,
		accel = Vector3.new(0, 2, 0),
		light = 1,
	})
	sparkles.Rate = CFG.sparkleRate
	local light = Instance.new("PointLight")
	light.Color = GREEN
	light.Range = math.max(8, height * 3)
	light.Brightness = 0
	light.Shadows = false
	light.Parent = root

	local tag, tagScale = pill(root, height)

	local started = os.clock()
	local sincePlus, sinceRing = CFG.plusEvery, CFG.ringEvery * 0.5
	local connection = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - started
		local breath = math.sin(t * math.pi * 2 / CFG.pulse)
		light.Brightness = CFG.light * (0.55 + 0.45 * breath)
		tagScale.Scale = 1 + 0.06 * breath
		sincePlus += dt
		if sincePlus >= CFG.plusEvery then
			sincePlus = 0
			plus(root, height)
		end
		sinceRing += dt
		if sinceRing >= CFG.ringEvery then
			sinceRing = 0
			ElementFx.ring(body.cframe.Position + Vector3.new(0, 0.2, 0), GREEN, math.max(2.5, height * 0.9), 0.9)
		end
	end)

	local stopped = false
	return function()
		if stopped then
			return
		end
		stopped = true
		connection:Disconnect()
		tag:Destroy()
		sparkles.Rate = 0
		Debris:AddItem(sparkles, 1.5)
		TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()
		Debris:AddItem(light, 0.5)
	end
end

return HealFx
