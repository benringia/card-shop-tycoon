--!strict
-- The supporter aura on the character window's stage (owner 2026-11-13: "supporter glow should also be visible in
-- character model inside character menu"; Config/Support STAGE). The stage is a ViewportFrame, which draws no particles,
-- so the aura is drawn in 2D around it: a soft glow behind the character (stacked circles, fainter outward: a flat
-- image of the 3D glow texture barely shows), breathing, in the tier's colour, and the real aura's own sparkles
-- (Support.SPARKLE, owner 2026-11-13: "show the actual effects") rising and fading in front of it in the tier's
-- colours, more for a higher tier. Only while the stage shows.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Support = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Support"))

local StageAura = {}

export type Aura = { set: (tier: number) -> () }

local STAGE = Support.STAGE

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function round(frame: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
end

-- The aura on `holder` (the stage's frame): the glow at ZIndex `behind`, twinkles at `front`; `shown` says whether the
-- stage is on screen now (no twinkles made while it isn't)
function StageAura.attach(holder: GuiObject, behind: number, front: number, shown: () -> boolean): Aura
	local glow = Instance.new("Frame")
	glow.Name = "SupporterGlow"
	glow.BackgroundTransparency = 1
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, STAGE.centre)
	glow.Size = UDim2.fromScale(STAGE.glow, STAGE.glow)
	glow.ZIndex = behind
	glow.Visible = false
	glow.Parent = holder
	local square = Instance.new("UIAspectRatioConstraint")
	square.DominantAxis = Enum.DominantAxis.Height
	square.Parent = glow
	local rings: { Frame } = {}
	for _, ring in STAGE.rings do
		local circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = UDim2.fromScale(0.5, 0.5)
		circle.Size = UDim2.fromScale(ring.size, ring.size)
		circle.BackgroundTransparency = ring.fade
		circle.BorderSizePixel = 0
		circle.ZIndex = behind
		circle.Parent = glow
		round(circle)
		table.insert(rings, circle)
	end
	local swell = Instance.new("UIScale")
	swell.Parent = glow
	local breathe = TweenService:Create(
		swell,
		TweenInfo.new(STAGE.breathe, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = STAGE.swell }
	)

	local tier = 0
	local running = false
	local rng = Random.new()

	-- One sparkle (the 3D aura's own texture), popping in, drifting up and turning, then shrinking away
	local function sparkle(look: any)
		local size = rng:NextInteger(STAGE.sparkSize[1], STAGE.sparkSize[2])
		local star = Instance.new("ImageLabel")
		star.Name = "Sparkle"
		star.BackgroundTransparency = 1
		star.Image = Support.SPARKLE
		star.ImageColor3 = rgb(look.colors[rng:NextInteger(1, #look.colors)])
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(rng:NextNumber(STAGE.spread[1], STAGE.spread[2]), rng:NextNumber(STAGE.rise[1], STAGE.rise[2]))
		star.Size = UDim2.fromOffset(size, size)
		star.Rotation = rng:NextNumber(0, 45)
		star.ZIndex = front
		local grow = Instance.new("UIScale")
		grow.Scale = 0
		grow.Parent = star
		star.Parent = holder
		local seconds = rng:NextNumber(STAGE.life[1], STAGE.life[2])
		local drift = UDim2.new(star.Position.X.Scale, rng:NextInteger(-12, 12), star.Position.Y.Scale, -rng:NextInteger(STAGE.climb[1], STAGE.climb[2]))
		TweenService:Create(grow, TweenInfo.new(seconds * 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(star, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Position = drift, Rotation = star.Rotation + 90 }):Play()
		task.delay(seconds * 0.6, function()
			TweenService:Create(grow, TweenInfo.new(seconds * 0.4), { Scale = 0 }):Play()
		end)
		task.delay(seconds + 0.1, function()
			star:Destroy()
		end)
	end

	local function run()
		if running then
			return
		end
		running = true
		task.spawn(function()
			while tier > 0 and holder.Parent do
				local look = Support.AURA[tier]
				if look and shown() then
					sparkle(look)
				end
				task.wait(1 / STAGE.rate[tier])
			end
			running = false
		end)
	end

	local function set(value: number)
		tier = value
		local look = Support.AURA[tier]
		glow.Visible = look ~= nil
		if not look then
			breathe:Cancel()
			return
		end
		for _, circle in rings do
			circle.BackgroundColor3 = rgb(STAGE.glowColors[tier])
		end
		local size = STAGE.glow + (tier - 1) * STAGE.glowGrow
		glow.Size = UDim2.fromScale(size, size)
		breathe:Play()
		run()
	end

	return { set = set }
end

return StageAura
