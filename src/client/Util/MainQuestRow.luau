--!strict
-- The main quest's row at the bottom of the quest strip (owner 2026-11-18, look A of artifact Evh8Gx9pN61R5GkodcwR3C;
-- Util/MainQuest picks the goal): a lilac card under the day's quests (and the week's, and "Quests done!") with the
-- item's icon in a floating bubble, "MAIN QUEST", what to do, the cash toward its price and a glossy gold bar (lilac for
-- a level to reach). Paid for: the bar turns mint and a Build! button pulses. A first build's moment: the card flashes
-- gold, "<item> built!", a check stamps in with confetti and "+150 shop XP" rises; the next goal slides in after it.
-- A computer only (a phone's quest chip shows the main quest instead: QuestStrip, CompactHud.phonePieces mainRow).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MainQuests = require(Config:WaitForChild("MainQuests"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local MainQuestRules = require(Shared:WaitForChild("Util"):WaitForChild("MainQuestRules"))

local ClientUtil = script.Parent :: Instance
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))

local MainQuestRow = {}

type Goal = MainQuestRules.Goal

local CREAM = UIStyle.CREAM
local BABY = UIStyle.BABY
local HEIGHT = 50 -- the card (the strip's padding below it adds 8)
local TEXT_LEFT = 42
local SHINE_EVERY = 4.5 -- seconds between the bar's shines

local frame: Frame
local card: Frame
local cardGradient: UIGradient
local bubble: Frame
local picture: Frame
local check: TextLabel
local words: TextLabel
local amount: TextLabel
local fill: Frame
local fillGradient: UIGradient
local sweep: Frame
local buildButton: TextButton
local pulse: Tween? = nil
local shown: Goal? = nil -- the goal on the row now
local pending: Goal? = nil -- the goal to show once the done moment ends
local holding = false
local wanted = false -- the strip wants the row (a computer, not folded, a goal)
local onBuildPressed: ((Goal) -> ())? = nil

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?): Tween
	local playing = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	playing:Play()
	return playing
end

local function scaleOf(object: GuiObject): UIScale
	local scale = object:FindFirstChildOfClass("UIScale")
	if scale then
		return scale
	end
	local made = Instance.new("UIScale")
	made.Parent = object
	return made
end

local function colorsFor(goal: Goal): { light: Color3, fill: Color3 }
	if goal.ready then
		return BABY.mint
	end
	return if goal.kind == "level" then BABY.lilac else BABY.butter
end

local function stopPulse()
	local playing = pulse
	if playing then
		playing:Cancel()
		pulse = nil
	end
	scaleOf(buildButton).Scale = 1
end

local function startPulse()
	if pulse then
		return
	end
	local scale = scaleOf(buildButton)
	scale.Scale = 1
	local playing = TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 })
	playing:Play()
	pulse = playing
end

local function shine()
	sweep.Position = UDim2.fromScale(-0.35, 0)
	sweep.BackgroundTransparency = 1
	tween(sweep, 0.9, { Position = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Sine)
	tween(sweep, 0.3, { BackgroundTransparency = 0.3 })
	task.delay(0.55, function()
		if sweep.Parent then
			tween(sweep, 0.35, { BackgroundTransparency = 1 })
		end
	end)
end

local function confetti()
	local from = check.AbsolutePosition + check.AbsoluteSize / 2 - card.AbsolutePosition
	local palette = { BABY.butter.fill, BABY.pink.fill, BABY.mint.fill, BABY.sky.fill, BABY.lilac.fill, BABY.peach.fill }
	for index = 1, 9 do
		local bit = Instance.new("Frame")
		bit.Name = "Confetti"
		bit.BackgroundColor3 = palette[(index - 1) % #palette + 1]
		bit.BorderSizePixel = 0
		bit.AnchorPoint = Vector2.new(0.5, 0.5)
		bit.Position = UDim2.fromOffset(from.X, from.Y)
		bit.Size = UDim2.fromOffset(5, 5)
		bit.ZIndex = 9
		bit.Parent = card
		UIKit.corner(bit, 2)
		local angle = (index / 9) * math.pi * 2 + math.random() * 0.5
		local reach = 18 + math.random() * 14
		tween(bit, 0.75, { Position = UDim2.fromOffset(from.X + math.cos(angle) * reach, from.Y + math.sin(angle) * reach), Rotation = 180, BackgroundTransparency = 1 })
		task.delay(0.8, bit.Destroy, bit)
	end
end

local function applyVisible()
	frame.Visible = wanted and (shown ~= nil or holding)
end

-- The row as `goal` is now; `fresh`: a new goal slides in
local function draw(goal: Goal, fresh: boolean)
	local before = shown
	shown = goal
	Icon.set(picture, goal.icon)
	Icon.layer(picture, 5)
	words.Text = goal.text
	amount.Text = goal.amount
	amount.Visible = not goal.ready
	local colors = colorsFor(goal)
	fillGradient.Color = ColorSequence.new(colors.light, colors.fill)
	local grew = before ~= nil and before.id == goal.id and goal.progress > before.progress + 0.001
	if fresh then
		fill.Size = UDim2.fromScale(0, 1)
	end
	tween(fill, if fresh then 0.7 else 0.5, { Size = UDim2.fromScale(goal.progress, 1) }, Enum.EasingStyle.Quint)
	if grew then
		shine()
	end
	buildButton.Visible = goal.ready
	if goal.ready then
		startPulse()
	else
		stopPulse()
	end
	check.Visible = false
	cardGradient.Color = ColorSequence.new(BABY.lilac.light, Color3.fromRGB(234, 219, 255))
	if fresh then
		local scale = scaleOf(card)
		scale.Scale = 0.85
		tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	applyVisible()
end

-- Builds the row in the strip (`parent`, its list layout) at `order`, hidden until a goal comes
function MainQuestRow.build(parent: Instance, order: number)
	frame = Instance.new("Frame")
	frame.Name = "MainQuest"
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, HEIGHT + 8)
	frame.Visible = false
	frame.ZIndex = 2
	frame.Parent = parent
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 7)
	pad.PaddingRight = UDim.new(0, 7)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = frame
	card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.Size = UDim2.new(1, 0, 0, HEIGHT)
	card.ZIndex = 3
	card.Parent = frame
	UIKit.corner(card, 11)
	cardGradient = Instance.new("UIGradient")
	cardGradient.Rotation = 90
	cardGradient.Color = ColorSequence.new(BABY.lilac.light, Color3.fromRGB(234, 219, 255))
	cardGradient.Parent = card
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Color = Color3.new(1, 1, 1)
	rim.Thickness = 2
	rim.Parent = card

	bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.BackgroundColor3 = BABY.lilac.fill
	bubble.AnchorPoint = Vector2.new(0, 0.5)
	bubble.Position = UDim2.new(0, 6, 0.5, 0)
	bubble.Size = UDim2.fromOffset(30, 30)
	bubble.ZIndex = 4
	bubble.Parent = card
	UIKit.corner(bubble, 15)
	local bubbleRim = Instance.new("UIStroke")
	bubbleRim.Color = Color3.new(1, 1, 1)
	bubbleRim.Thickness = 2
	bubbleRim.Parent = bubble
	picture = Icon.make(bubble, MainQuests.LEVEL_ICON, UDim2.fromOffset(20, 20))
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	picture.ZIndex = 5
	Icon.layer(picture, 5)
	-- its icon sways like the quests' (Quests.STRIP sway: a 2 px float moved in whole pixels and looked jerky)
	picture.Rotation = -8
	TweenService:Create(picture, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 8 }):Play()
	check = UIKit.label(bubble, "✅", Enum.Font.GothamBold, 13, Color3.new(1, 1, 1))
	check.Name = "Check"
	check.AnchorPoint = Vector2.new(0.5, 0.5)
	check.Position = UDim2.new(1, -1, 1, -3)
	check.Size = UDim2.fromOffset(15, 15)
	check.TextXAlignment = Enum.TextXAlignment.Center
	check.ZIndex = 7
	check.Visible = false

	local tag = UIKit.label(card, "MAIN QUEST", Enum.Font.FredokaOne, 10, BABY.lilac.deep)
	tag.Name = "Tag"
	tag.Position = UDim2.fromOffset(TEXT_LEFT, 4)
	tag.Size = UDim2.new(1, -TEXT_LEFT - 8, 0, 11)
	tag.TextWrapped = false
	tag.ZIndex = 4
	words = UIKit.label(card, "", Enum.Font.GothamBold, 12, CREAM.INK)
	words.Name = "Words"
	words.Position = UDim2.fromOffset(TEXT_LEFT, 16)
	words.Size = UDim2.new(1, -TEXT_LEFT - 6, 0, 15)
	words.TextTruncate = Enum.TextTruncate.AtEnd
	words.TextWrapped = false
	words.ZIndex = 4
	amount = UIKit.label(card, "", Enum.Font.FredokaOne, 11, CREAM.INK_SOFT)
	amount.Name = "Amount"
	amount.AnchorPoint = Vector2.new(1, 0)
	amount.Position = UDim2.new(1, -7, 0, 3)
	amount.Size = UDim2.fromOffset(110, 13)
	amount.TextXAlignment = Enum.TextXAlignment.Right
	amount.TextWrapped = false
	amount.ZIndex = 4

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = CREAM.TRACK
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(TEXT_LEFT, 35)
	track.Size = UDim2.new(1, -TEXT_LEFT - 8, 0, 9)
	track.ZIndex = 4
	track.Parent = card
	UIKit.corner(track, 5)
	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.ClipsDescendants = true
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 5
	fill.Parent = track
	UIKit.corner(fill, 5)
	fillGradient = Instance.new("UIGradient")
	fillGradient.Rotation = 90
	fillGradient.Parent = fill
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.5
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.new(0, 3, 0, 1)
	gloss.Size = UDim2.new(1, -6, 0, 2)
	gloss.ZIndex = 6
	gloss.Parent = fill
	UIKit.corner(gloss, 1)
	sweep = Instance.new("Frame")
	sweep.Name = "Shine"
	sweep.BackgroundColor3 = Color3.new(1, 1, 1)
	sweep.BackgroundTransparency = 1
	sweep.BorderSizePixel = 0
	sweep.Size = UDim2.fromScale(0.35, 1)
	sweep.ZIndex = 6
	sweep.Parent = fill
	local soft = Instance.new("UIGradient")
	soft.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 1) })
	soft.Parent = sweep

	buildButton = Instance.new("TextButton")
	buildButton.Name = "Build"
	buildButton.AutoButtonColor = false
	buildButton.AnchorPoint = Vector2.new(1, 0)
	buildButton.Position = UDim2.new(1, -6, 0, 2)
	buildButton.Size = UDim2.fromOffset(58, 18)
	buildButton.BackgroundColor3 = BABY.mint.fill
	buildButton.Font = Enum.Font.FredokaOne
	buildButton.Text = "Build!"
	buildButton.TextSize = 13
	buildButton.TextColor3 = BABY.mint.deep
	buildButton.Visible = false
	buildButton.ZIndex = 8
	buildButton.Parent = card
	UIKit.corner(buildButton, 9)
	local buttonRim = Instance.new("UIStroke")
	buttonRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	buttonRim.Color = Color3.new(1, 1, 1)
	buttonRim.Thickness = 2
	buttonRim.Parent = buildButton
	buildButton.Activated:Connect(function()
		local goal = shown
		local handler = onBuildPressed
		if goal and goal.ready and handler then
			handler(goal)
		end
	end)
	-- the bar's shine now and then while the row shows
	task.spawn(function()
		while frame.Parent do
			task.wait(SHINE_EVERY)
			if frame.Visible and not holding and fill.Size.X.Scale > 0.15 then
				shine()
			end
		end
	end)
end

-- What the Build! button does (QuestController: that item's placement, or why not here)
function MainQuestRow.onBuild(handler: (Goal) -> ())
	onBuildPressed = handler
end

-- Shows `goal` (nil: nothing left, the row hides); held while a done moment plays
function MainQuestRow.show(goal: Goal?)
	if holding then
		pending = goal
		return
	end
	if not goal then
		shown = nil
		stopPulse()
		applyVisible()
		return
	end
	local current = shown
	draw(goal, current == nil or current.id ~= goal.id)
end

-- Whether the strip wants the row (a computer, not folded); it shows only with a goal
function MainQuestRow.setWanted(on: boolean)
	wanted = on
	applyVisible()
end

-- A first build's moment: "<name> built!", the bar full, a gold flash, the check stamping in with confetti and the shop
-- XP rising; the next goal slides in after MainQuests.HOLD_SECONDS
function MainQuestRow.done(name: string, xp: number)
	holding = true
	pending = shown
	stopPulse()
	buildButton.Visible = false
	words.Text = `{name} built!`
	amount.Visible = false -- the shop XP rising there says it
	fillGradient.Color = ColorSequence.new(BABY.butter.light, BABY.butter.fill)
	tween(fill, 0.35, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Quint)
	cardGradient.Color = ColorSequence.new(Color3.fromRGB(255, 246, 214), BABY.butter.light)
	applyVisible()
	check.Visible = true
	local scale = scaleOf(check)
	scale.Scale = 2.4
	check.Rotation = -25
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(check, 0.45, { Rotation = 0 }, Enum.EasingStyle.Back)
	if frame.Visible then
		confetti()
		local plus = UIKit.label(card, `+{xp} shop XP`, Enum.Font.FredokaOne, 14, BABY.butter.deep)
		plus.Name = "XpRise"
		plus.AnchorPoint = Vector2.new(1, 1)
		plus.Position = UDim2.new(1, -8, 0, 20)
		plus.Size = UDim2.fromOffset(110, 16)
		plus.TextXAlignment = Enum.TextXAlignment.Right
		plus.ZIndex = 9
		local edge = Instance.new("UIStroke")
		edge.Color = Color3.new(1, 1, 1)
		edge.Thickness = 2
		edge.Parent = plus
		scaleOf(plus).Scale = 0.5
		tween(scaleOf(plus), 0.3, { Scale = 1.15 }, Enum.EasingStyle.Back)
		tween(plus, 1.4, { Position = UDim2.new(1, -8, 0, 0) })
		task.delay(0.9, function()
			if plus.Parent then
				tween(plus, 0.5, { TextTransparency = 1 })
				tween(edge, 0.5, { Transparency = 1 })
			end
		end)
		task.delay(1.5, plus.Destroy, plus)
	end
	task.delay(MainQuests.HOLD_SECONDS, function()
		holding = false
		shown = nil -- whatever comes next slides in
		MainQuestRow.show(pending)
	end)
end

return MainQuestRow
