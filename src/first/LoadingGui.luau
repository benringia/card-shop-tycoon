--!strict
-- Builds and runs the loading screen ("card fan", Config/LoadingScreen): three cards fanning out, the title, a slim
-- gold bar, the step, a note for a slow save and a tip. Lives in ReplicatedFirst so it can show from the first frame;
-- the client also hands a copy to TeleportService so teleports show it, and the next place picks that copy up. Works
-- on the gui's instances by name, so a copy that arrived through a teleport can be driven the same way.
local TweenService = game:GetService("TweenService")

local LoadingGui = {}

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function label(parent: Instance, name: string, font: Enum.Font, size: number, textColor: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Font = font
	text.TextSize = size
	text.TextColor3 = textColor
	text.TextStrokeTransparency = 0.6
	text.Text = ""
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Size = UDim2.new(0.9, 0, 0, size + 6)
	text.TextWrapped = true
	text.Parent = parent
	return text
end

-- A fresh screen at its first step. images: the fan's three card paintings, left to right
function LoadingGui.build(cfg: any, images: { string }, firstStep: string): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.Active = true -- taps and clicks stop here while loading
	back.Parent = gui
	local shade = Instance.new("UIGradient")
	shade.Rotation = 70
	shade.Color = ColorSequence.new(color(cfg.BACKGROUND.top), color(cfg.BACKGROUND.bottom))
	shade.Parent = back

	-- The fan: three cards pivoting at their bottom, centred a bit above the middle
	local fan = Instance.new("Frame")
	fan.Name = "Fan"
	fan.BackgroundTransparency = 1
	fan.AnchorPoint = Vector2.new(0.5, 1)
	fan.Position = UDim2.fromScale(0.5, 0.5)
	fan.Size = UDim2.fromScale(0.09, 0.22)
	fan.Parent = back
	local fanShape = Instance.new("UIAspectRatioConstraint")
	fanShape.AspectRatio = 38 / 56
	fanShape.Parent = fan
	for index = 1, 3 do
		local card = Instance.new("ImageLabel")
		card.Name = `Card{index}`
		card.Image = images[index] or ""
		card.ScaleType = Enum.ScaleType.Crop
		card.BackgroundColor3 = Color3.fromRGB(42, 29, 51)
		card.Size = UDim2.fromScale(1, 1)
		card.ZIndex = if index == 2 then 3 else 2
		card.Parent = fan
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.1, 0)
		corner.Parent = card
		local edge = Instance.new("UIStroke")
		edge.Color = color(cfg.CARD_EDGE)
		edge.Thickness = 2
		edge.Parent = card
	end

	local title = label(back, "Title", Enum.Font.FredokaOne, 30, Color3.new(1, 1, 1))
	title.Position = UDim2.new(0.5, 0, 0.5, 14)
	title.Text = cfg.TITLE
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0.5, 62)
	bar.Size = UDim2.new(0.4, 0, 0, 6)
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BackgroundTransparency = 0.85
	bar.Parent = back
	local barWidth = Instance.new("UISizeConstraint")
	barWidth.MaxSize = Vector2.new(360, 6)
	barWidth.MinSize = Vector2.new(180, 6)
	barWidth.Parent = bar
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color(cfg.BAR_COLOR)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	local step = label(back, "Step", Enum.Font.GothamBold, 15, Color3.new(1, 1, 1))
	step.Position = UDim2.new(0.5, 0, 0.5, 76)
	step.Text = firstStep
	local note = label(back, "Note", Enum.Font.GothamBold, 13, color(cfg.NOTE_COLOR))
	note.Position = UDim2.new(0.5, 0, 0.5, 100)
	local tip = label(back, "Tip", Enum.Font.GothamBold, 13, Color3.new(1, 1, 1))
	tip.AnchorPoint = Vector2.new(0.5, 1)
	tip.Position = UDim2.new(0.5, 0, 1, -16)
	tip.TextTransparency = 0.15
	return gui
end

-- Swings the side cards out and back forever, and cycles the tips; returns a stop
function LoadingGui.animate(gui: ScreenGui, cfg: any): () -> ()
	local fan = gui:FindFirstChild("Fan", true)
	local swing = TweenInfo.new(cfg.FAN_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tweens: { Tween } = {}
	if fan then
		for index, degrees in { -cfg.FAN_DEGREES, 0, cfg.FAN_DEGREES } do
			local card = fan:FindFirstChild(`Card{index}`)
			if card and card:IsA("GuiObject") and degrees ~= 0 then
				card.Rotation = 0
				local tween = TweenService:Create(card, swing, { Rotation = degrees, Position = UDim2.fromScale(degrees / cfg.FAN_DEGREES * 0.45, 0.04) })
				tween:Play()
				table.insert(tweens, tween)
			end
		end
	end
	local running = true
	local tip = gui:FindFirstChild("Tip", true)
	task.spawn(function()
		local index = math.random(1, #cfg.TIPS)
		while running and tip and tip.Parent do
			(tip :: TextLabel).Text = cfg.TIPS[index]
			index = index % #cfg.TIPS + 1
			task.wait(cfg.TIP_SECONDS)
		end
	end)
	return function()
		running = false
		for _, tween in tweens do
			tween:Cancel()
		end
	end
end

-- The step's words, the bar's share and the slow-save note ("" for none)
function LoadingGui.set(gui: ScreenGui, stepText: string, share: number, note: string)
	local step = gui:FindFirstChild("Step", true)
	local fill = gui:FindFirstChild("Fill", true)
	local noteLabel = gui:FindFirstChild("Note", true)
	if step and step:IsA("TextLabel") then
		step.Text = stepText
	end
	if fill and fill:IsA("Frame") then
		TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(share, 0, 1), 1) }):Play()
	end
	if noteLabel and noteLabel:IsA("TextLabel") then
		noteLabel.Text = note
	end
end

-- Fades everything out, then removes the screen
function LoadingGui.fadeOut(gui: ScreenGui, seconds: number)
	local info = TweenInfo.new(seconds)
	for _, item in gui:GetDescendants() do
		if item:IsA("TextLabel") then
			TweenService:Create(item, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		elseif item:IsA("ImageLabel") then
			TweenService:Create(item, info, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif item:IsA("Frame") then
			TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, info, { Transparency = 1 }):Play()
		end
	end
	task.delay(seconds, function()
		gui:Destroy()
	end)
end

return LoadingGui
