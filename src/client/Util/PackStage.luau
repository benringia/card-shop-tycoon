--!strict
-- The premium backdrop behind the pack opening screen (PackOpeningController): slow-turning light rays, soft
-- bokeh sparkles drifting up, a glowing pedestal under the pack and a vignette round the edges. It only moves
-- while the screen is open. Numbers: Config/PackOpening AMBIENT.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local CardDesign = require(Config:WaitForChild("CardDesign"))
local PackOpening = require(Config:WaitForChild("PackOpening"))

export type Stage = {
	setActive: (active: boolean) -> (),
	setTint: (color: Color3) -> (),
}

type Dot = { frame: Frame, x: number, y: number, speed: number, drift: number, phase: number }

local PackStage = {}

local WHITE = Color3.new(1, 1, 1)

local function layer(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = parent
	return frame
end

-- Long soft rays fanning out from behind the pack, turning slowly
local function buildRays(parent: Instance): (Frame, { Frame })
	local look = PackOpening.AMBIENT
	local holder = Instance.new("Frame")
	holder.Name = "AmbientRays"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, PackOpening.PACK.Y)
	holder.Size = UDim2.fromScale(look.RAY_RADIUS * 2, look.RAY_RADIUS * 2)
	holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	holder.Parent = parent
	local rays = {}
	for index = 1, look.RAY_COUNT do
		local pivot = Instance.new("Frame")
		pivot.BackgroundTransparency = 1
		pivot.AnchorPoint = Vector2.new(0.5, 0.5)
		pivot.Position = UDim2.fromScale(0.5, 0.5)
		pivot.Size = UDim2.fromScale(1, 1)
		pivot.Rotation = index * 360 / look.RAY_COUNT
		pivot.Parent = holder
		local ray = Instance.new("Frame")
		ray.BorderSizePixel = 0
		ray.AnchorPoint = Vector2.new(0.5, 1)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		-- Alternate wide and thin rays, like a real light burst
		ray.Size = UDim2.fromScale(if index % 2 == 0 then look.RAY_WIDTH else look.RAY_WIDTH * 0.45, 0.5)
		ray.BackgroundColor3 = WHITE
		ray.Parent = pivot
		local fade = Instance.new("UIGradient")
		fade.Rotation = -90
		fade.Transparency = NumberSequence.new(look.RAY_TRANSPARENCY, 1)
		fade.Parent = ray
		table.insert(rays, ray)
	end
	return holder, rays
end

-- Dark soft edges round the screen, so the middle glows
local function buildVignette(parent: Instance)
	local look = PackOpening.AMBIENT
	local edges = {
		{ anchor = Vector2.new(0.5, 0), position = UDim2.fromScale(0.5, 0), size = UDim2.fromScale(1, look.VIGNETTE_SIZE), rotation = 90 },
		{ anchor = Vector2.new(0.5, 1), position = UDim2.fromScale(0.5, 1), size = UDim2.fromScale(1, look.VIGNETTE_SIZE), rotation = -90 },
		{ anchor = Vector2.new(0, 0.5), position = UDim2.fromScale(0, 0.5), size = UDim2.fromScale(look.VIGNETTE_SIZE * 0.6, 1), rotation = 0 },
		{ anchor = Vector2.new(1, 0.5), position = UDim2.fromScale(1, 0.5), size = UDim2.fromScale(look.VIGNETTE_SIZE * 0.6, 1), rotation = 180 },
	}
	for _, edge in edges do
		local shade = Instance.new("Frame")
		shade.Name = "Vignette"
		shade.BorderSizePixel = 0
		shade.AnchorPoint = edge.anchor
		shade.Position = edge.position
		shade.Size = edge.size
		shade.BackgroundColor3 = look.VIGNETTE_COLOR
		shade.Parent = parent
		local fade = Instance.new("UIGradient")
		fade.Rotation = edge.rotation
		fade.Transparency = NumberSequence.new(look.VIGNETTE_TRANSPARENCY, 1)
		fade.Parent = shade
	end
end

-- Builds the backdrop on stage; everything sits on one layer the caller places behind the pack
function PackStage.build(stage: GuiObject): Stage
	local look = PackOpening.AMBIENT
	local root = layer(stage, "Ambient")
	local rays, rayParts = buildRays(root)

	local pedestal = Instance.new("ImageLabel")
	pedestal.Name = "Pedestal"
	pedestal.BackgroundTransparency = 1
	pedestal.AnchorPoint = Vector2.new(0.5, 0.5)
	pedestal.Position = UDim2.fromScale(0.5, PackOpening.PACK.Y + PackOpening.PACK.HEIGHT / 2 + look.PEDESTAL_GAP)
	pedestal.Size = UDim2.fromScale(look.PEDESTAL_WIDTH, look.PEDESTAL_HEIGHT)
	pedestal.SizeConstraint = Enum.SizeConstraint.RelativeYY
	pedestal.Image = CardDesign.IMAGES.GLOW
	pedestal.ImageTransparency = look.PEDESTAL_TRANSPARENCY
	pedestal.Parent = root

	local bokeh = layer(root, "Bokeh")
	local dots: { Dot } = {}
	local random = Random.new()
	for _ = 1, look.BOKEH_COUNT do
		local size = random:NextNumber(look.BOKEH_SIZE[1], look.BOKEH_SIZE[2])
		local dot = Instance.new("Frame")
		dot.BorderSizePixel = 0
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Size = UDim2.fromOffset(size, size)
		dot.BackgroundColor3 = WHITE
		dot.BackgroundTransparency = random:NextNumber(look.BOKEH_TRANSPARENCY[1], look.BOKEH_TRANSPARENCY[2])
		dot.Parent = bokeh
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = dot
		table.insert(dots, {
			frame = dot,
			x = random:NextNumber(),
			y = random:NextNumber(),
			speed = random:NextNumber(look.BOKEH_SPEED[1], look.BOKEH_SPEED[2]),
			drift = random:NextNumber(0.005, 0.02),
			phase = random:NextNumber(0, math.pi * 2),
		})
	end
	buildVignette(root)

	local turn = TweenService:Create(rays, TweenInfo.new(look.RAY_TURN_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 360 })
	local pulse = TweenService:Create(pedestal, TweenInfo.new(look.PEDESTAL_PULSE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = math.min(look.PEDESTAL_TRANSPARENCY + 0.25, 1) })
	local stepping: RBXScriptConnection? = nil

	local function step(dt: number)
		local height = math.max(stage.AbsoluteSize.Y, 1)
		local t = os.clock()
		for _, dot in dots do
			-- Fractions of the screen; speed is pixels a second, so it feels the same on every screen
			dot.y -= dot.speed * dt / height
			if dot.y < -0.05 then
				dot.y = 1.05
				dot.x = random:NextNumber()
			end
			dot.frame.Position = UDim2.fromScale(dot.x + math.sin(t + dot.phase) * dot.drift, dot.y)
		end
	end

	local handle: Stage = {
		setActive = function(active: boolean)
			if active then
				turn:Play()
				pulse:Play()
				if not stepping then
					stepping = RunService.RenderStepped:Connect(step)
				end
			else
				turn:Pause()
				pulse:Pause()
				if stepping then
					stepping:Disconnect()
					stepping = nil
				end
			end
		end,
		-- The rays and pedestal pick up the pack's colour, softened
		setTint = function(color: Color3)
			local soft = color:Lerp(WHITE, look.TINT_SOFTEN)
			for _, ray in rayParts do
				ray.BackgroundColor3 = soft
			end
			pedestal.ImageColor3 = soft
		end,
	}
	return handle
end

return PackStage
