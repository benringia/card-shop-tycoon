--!strict
-- Petting Pish or Chikin, the reward you see (owner 2026-11-23, mockup A; Config/PetReward): the dog hands you its
-- painted card. It pops up in the middle of the screen over a soft dim, a glow and turning rays behind it, with what you
-- got under it ("Pish's Luck!", "Better pulls for 3 minutes", "Very Rare and up: +25% chance"), holds a moment, then
-- shrinks and flies into your buffs (the party dock's buff icons), which bump as it lands. Only on the petter's screen.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local PetRewardConfig = require(Config:WaitForChild("PetReward"))
local Pish = require(Config:WaitForChild("Pish"))
local Chikin = require(Config:WaitForChild("Chikin"))
local PetRewardRules = require(Shared:WaitForChild("Util"):WaitForChild("PetRewardRules"))

local ClientUtil = script.Parent :: Instance
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local ScreenCover = require(ClientUtil:WaitForChild("ScreenCover"))

local PetReward = {}

local INK = Color3.fromRGB(74, 47, 99)
local WHITE = Color3.new(1, 1, 1)
local SIZES = PetRewardConfig.SIZES
local TIMES = PetRewardConfig.TIMES
local DESIGN_HEIGHT = 1080 -- SIZES are for a screen this tall
local MIN_SCALE = PetRewardConfig.MIN_SCALE -- a phone's short screen still gets words big enough to read

local player = Players.LocalPlayer
local current: ScreenGui? = nil

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local made = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	made:Play()
	return made
end

local function chime()
	local sound = Instance.new("Sound")
	sound.SoundId = PetRewardConfig.SOUND.id
	sound.Volume = PetRewardConfig.SOUND.volume
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
end

-- The rays turning behind the card: eight soft bars from the middle
local function rays(parent: Frame, color: Color3, size: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Rays"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size, size)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	for index = 0, 7 do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.new(0, size * 0.07, 1, 0)
		bar.Rotation = index * 22.5
		bar.BackgroundColor3 = color
		bar.BackgroundTransparency = 0.35
		bar.BorderSizePixel = 0
		bar.Parent = holder
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.2),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = bar
	end
	return holder
end

-- A soft round glow
local function glow(parent: Frame, color: Color3, size: number): Frame
	local made = Instance.new("Frame")
	made.Name = "Glow"
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	made.Position = UDim2.fromScale(0.5, 0.5)
	made.Size = UDim2.fromOffset(size, size)
	made.BackgroundColor3 = color
	made.BorderSizePixel = 0
	made.Parent = parent
	UIKit.corner(made, size / 2)
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.45, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = made
	return made
end

-- The words under the card: the title in a cream pill, the line, the chip
local function words(parent: Frame, dog: string, style: any, top: number): Frame
	local said = PetRewardRules.words(dog, PetRewardConfig, Pish.LUCK, Chikin.COURAGE)
	local column = Instance.new("Frame")
	column.Name = "Words"
	column.AnchorPoint = Vector2.new(0.5, 0)
	column.Position = UDim2.new(0.5, 0, 0, top)
	column.Size = UDim2.fromOffset(760, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.BackgroundTransparency = 1
	column.Parent = parent
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = column

	local pill = Instance.new("Frame")
	pill.Name = "Title"
	pill.Size = UDim2.fromOffset(0, SIZES.title + 22)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = Color3.fromRGB(255, 247, 252)
	pill.LayoutOrder = 1
	pill.Parent = column
	UIKit.corner(pill, (SIZES.title + 22) / 2)
	UIKit.outline(pill, rgb(style.edge), 4)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 26)
	padding.PaddingRight = UDim.new(0, 26)
	padding.Parent = pill
	local title = UIKit.label(pill, style.icon .. "  " .. (if said then said.title else style.title), Enum.Font.FredokaOne, SIZES.title, INK)
	title.Size = UDim2.fromScale(0, 1)
	title.AutomaticSize = Enum.AutomaticSize.X
	title.TextWrapped = false

	local line = UIKit.label(column, if said then said.line else "", Enum.Font.GothamBold, SIZES.line, INK)
	line.Name = "Line"
	line.LayoutOrder = 2
	line.Size = UDim2.fromOffset(0, SIZES.line + 16)
	line.AutomaticSize = Enum.AutomaticSize.X
	line.TextWrapped = false
	line.BackgroundColor3 = WHITE
	line.BackgroundTransparency = 0.08
	UIKit.corner(line, 12)
	local linePad = Instance.new("UIPadding")
	linePad.PaddingLeft = UDim.new(0, 16)
	linePad.PaddingRight = UDim.new(0, 16)
	linePad.Parent = line

	local chip = UIKit.label(column, if said then said.chip else "", Enum.Font.GothamBold, SIZES.chip, rgb(style.chipText))
	chip.Name = "Chip"
	chip.LayoutOrder = 3
	chip.Size = UDim2.fromOffset(0, SIZES.chip + 12)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.TextWrapped = false
	chip.BackgroundColor3 = rgb(style.chipColor)
	chip.BackgroundTransparency = 0
	UIKit.corner(chip, (SIZES.chip + 12) / 2)
	local chipPad = Instance.new("UIPadding")
	chipPad.PaddingLeft = UDim.new(0, 14)
	chipPad.PaddingRight = UDim.new(0, 14)
	chipPad.Parent = chip
	return column
end

-- Every piece of `root` faded to `alpha` (1 gone) over `seconds`
local function fadeAll(root: Instance, alpha: number, seconds: number)
	for _, item in root:GetDescendants() do
		if item:IsA("TextLabel") then
			tween(item, seconds, { TextTransparency = alpha, BackgroundTransparency = math.max(item.BackgroundTransparency, alpha) })
		elseif item:IsA("ImageLabel") then
			tween(item, seconds, { ImageTransparency = alpha })
		elseif item:IsA("UIStroke") then
			tween(item, seconds, { Transparency = alpha })
		elseif item:IsA("Frame") and item.BackgroundTransparency < 1 then
			tween(item, seconds, { BackgroundTransparency = math.max(item.BackgroundTransparency, alpha) })
		end
	end
end

-- Shows `dog`'s ("Pish" or "Chikin") card and flies it into `target` (the buff icons; nil: off to the bottom left)
function PetReward.show(dog: string, target: GuiObject?)
	local style = PetRewardConfig.DOGS[dog]
	if not style then
		return
	end
	local old = current
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PetReward"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	current = gui

	local dimLayer = ScreenCover.layer(gui, 1)
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(36, 22, 56)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Parent = dimLayer
	tween(dim, 0.2, { BackgroundTransparency = 1 - PetRewardConfig.DIM })

	-- everything else at the screen's middle, sized for its height
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else DESIGN_HEIGHT
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.46)
	stage.Size = UDim2.fromOffset(SIZES.glow, SIZES.glow)
	stage.BackgroundTransparency = 1
	stage.ZIndex = 2
	stage.Parent = gui
	local scale = Instance.new("UIScale")
	local fit = math.max(MIN_SCALE, height / DESIGN_HEIGHT)
	scale.Scale = fit * 0.6
	scale.Parent = stage

	local halo = glow(stage, rgb(style.glow), SIZES.glow)
	local spokes = rays(stage, rgb(style.glow), SIZES.glow * 1.05)
	local card = Instance.new("ImageLabel")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.Size = UDim2.fromOffset(SIZES.card[1], SIZES.card[2])
	card.Image = style.card
	card.ScaleType = Enum.ScaleType.Crop
	card.Rotation = style.tilt
	card.BackgroundColor3 = WHITE
	card.Parent = stage
	UIKit.corner(card, 14)
	UIKit.outline(card, rgb(style.glow), 5)
	local said = words(stage, dog, style, SIZES.glow * 0.42 + SIZES.card[2] / 2 + 14)

	chime()
	tween(scale, TIMES.popIn, { Scale = fit }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local spin = tween(spokes, TIMES.popIn + TIMES.hold + TIMES.fly, { Rotation = 90 }, Enum.EasingStyle.Linear)

	task.delay(TIMES.popIn + TIMES.hold, function()
		if current ~= gui then
			return
		end
		-- off it goes: words and glow fade, the card shrinks into the buff icons
		fadeAll(said, 1, 0.2)
		fadeAll(halo, 1, 0.2)
		spokes.Visible = false
		spin:Cancel()
		tween(dim, TIMES.fly, { BackgroundTransparency = 1 })
		local goal = UDim2.new(0, 40, 1, -60)
		if target and target.Visible and target.AbsoluteSize.X > 0 then
			local centre = target.AbsolutePosition + target.AbsoluteSize / 2
			local inset = gui.AbsolutePosition
			goal = UDim2.fromOffset(centre.X - inset.X, centre.Y - inset.Y)
		end
		tween(stage, TIMES.fly, { Position = goal }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(scale, TIMES.fly, { Scale = fit * 0.12 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(card, TIMES.fly, { Rotation = style.tilt + 25 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(TIMES.fly, function()
			if target then
				-- the buff icons bump as the card lands
				-- (a GuiObject takes one UIScale: use the one it has)
				local bump = target:FindFirstChildOfClass("UIScale")
				if not bump then
					local made = Instance.new("UIScale")
					made.Name = "PetRewardBump"
					made.Parent = target
					bump = made
				end
				local landing = bump :: UIScale
				landing.Scale = 1.35
				tween(landing, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			end
			if current == gui then
				current = nil
			end
			gui:Destroy()
		end)
	end)
end

return PetReward
