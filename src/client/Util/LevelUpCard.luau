--!strict
-- The middle card after your own shop's level-up pillar (owner 2026-11-16: "there should be some sort of reward every
-- level up ... and an immersive notification at the center of the screen"; mockup picked; Config/LevelUpFx CARD):
-- "LEVEL UP!" on a lilac ribbon, the new level in a gold badge, then what it gave in a row of chips popping in one
-- after another (the cash every level, the gift every 5th: Config/Levels via LevelUpRules.rewards), any title it
-- earned, and what it unlocked in the shop. Over soft turning rays on a dimmed screen; closes on its button or by
-- itself. Several level-ups at once show as one card (from the first to the last).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Levels = require(Config:WaitForChild("Levels"))
local LevelUpFx = require(Config:WaitForChild("LevelUpFx"))
local Titles = require(Config:WaitForChild("Titles"))
local UIIcons = require(Config:WaitForChild("UIIcons"))
local LevelRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelRules"))
local LevelUpRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelUpRules"))
local UIKit = require((script.Parent :: Instance):WaitForChild("UIKit"))

local LevelUpCard = {}

local CARD = LevelUpFx.CARD
local COLORS = CARD.colors
-- The gifts' order on the card (Config/Items ids); anything else after them
local ITEM_ORDER = { "sparkPack", "goldSeal", "wildOre", "xpTonic" }

type Chip = { icon: string, text: string, new: boolean? }

local showing: { gui: ScreenGui, from: number }? = nil

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function gradient(parent: GuiObject, top: { number }, bottom: { number })
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(rgb(top), rgb(bottom))
	shade.Parent = parent
end

local function stroke(parent: GuiObject, color: Color3, thickness: number, contextual: boolean?)
	local edge = Instance.new("UIStroke")
	edge.Color = color
	edge.Thickness = thickness
	edge.LineJoinMode = Enum.LineJoinMode.Round
	if not contextual then
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	edge.Parent = parent
end

local function text(parent: Instance, words: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.FredokaOne
	label.Text = words
	label.TextColor3 = color
	label.TextSize = size
	label.TextWrapped = true
	label.Parent = parent
	return label
end

-- What the card lists: the cash, then each item, then any title earned
local function chipsFor(from: number, to: number): { Chip }
	local rewards = LevelUpRules.rewards(Levels, from, to)
	local chips: { Chip } = { { icon = "Coin", text = `+${rewards.cash}` } }
	local order = table.clone(ITEM_ORDER)
	for item in rewards.items do
		if not table.find(order, item) then
			table.insert(order, item)
		end
	end
	for _, item in order do
		local count = rewards.items[item]
		local info = Items.ITEMS[item]
		if count and info then
			table.insert(chips, { icon = info.icon, text = if count > 1 then `{info.name} x{count}` else info.name })
		end
	end
	for _, name in LevelUpRules.titlesReached(Titles, from, to) do
		table.insert(chips, { icon = "Crown", text = `Title: {name}`, new = true })
	end
	return chips
end

-- The line under the chips: what's new in the shop, else where a pack went
local function noteFor(from: number, to: number): string
	local unlocks: { string } = {}
	for level = from + 1, to do
		for _, name in LevelRules.getUnlocks(level) do
			table.insert(unlocks, name)
		end
	end
	if #unlocks > 0 then
		return `New in your shop: {table.concat(unlocks, ", ")}`
	end
	if LevelUpRules.rewards(Levels, from, to).items.sparkPack then
		return "Open your pack from the Bag!"
	end
	return ""
end

local function close()
	local current = showing
	showing = nil
	if not current then
		return
	end
	local gui = current.gui
	for _, piece in gui:GetDescendants() do
		if piece:IsA("UIScale") and piece.Name == "CardScale" then
			TweenService:Create(piece, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.4 }):Play()
		end
	end
	task.delay(0.2, function()
		gui:Destroy()
	end)
end

local function popIn(object: GuiObject, delay: number)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = object
	task.delay(delay, function()
		TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end

-- Shows the card for a shop level-up from `from` to `to` (one already up becomes one card from its first level)
function LevelUpCard.show(from: number, to: number)
	if to <= from then
		return
	end
	if showing then
		from = math.min(from, showing.from)
		close()
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "LevelUpCard"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 70
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	showing = { gui = gui, from = from }

	local dim = Instance.new("TextButton") -- tapping outside closes it too
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui
	TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = CARD.dim }):Play()
	dim.Activated:Connect(close)

	-- Everything sized at the reference screen, then scaled to this one
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromOffset(CARD.reference[1], CARD.reference[2])
	stage.Parent = gui
	local fit = Instance.new("UIScale")
	fit.Parent = stage
	local function refit()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(CARD.reference[1], CARD.reference[2])
		fit.Scale = math.clamp(math.min(view.X / CARD.reference[1], view.Y / CARD.reference[2]), CARD.minScale, CARD.maxScale)
	end
	refit()

	local rays = Instance.new("ImageLabel")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.Image = CARD.rays
	rays.ImageColor3 = rgb(COLORS.badgeTop)
	rays.ImageTransparency = 0.35
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromOffset(CARD.raysSize, CARD.raysSize)
	rays.Parent = stage
	local started = os.clock()
	local spin = RunService.RenderStepped:Connect(function()
		rays.Rotation = (os.clock() - started) / CARD.raysTurnSeconds * 360
		refit()
	end)
	gui.Destroying:Connect(function()
		spin:Disconnect()
	end)

	local chips = chipsFor(from, to)
	local note = noteFor(from, to)
	local chipW, chipH = CARD.chip[1], CARD.chip[2]
	local perRow = math.max(1, math.floor((CARD.width - 32) / (chipW + 10)))
	local rows = math.ceil(#chips / perRow)
	local height = 64 + 92 + 40 + rows * (chipH + 10) + (if note ~= "" then 34 else 0) + 70

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.52)
	card.Size = UDim2.fromOffset(CARD.width, height)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.Parent = stage
	UIKit.corner(card, 30)
	gradient(card, COLORS.cardTop, COLORS.cardBottom)
	stroke(card, Color3.new(1, 1, 1), 5)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = card.AnchorPoint
	shadow.Position = card.Position + UDim2.fromOffset(0, 10)
	shadow.Size = card.Size
	shadow.BackgroundColor3 = rgb(COLORS.shadow)
	shadow.ZIndex = 0
	shadow.Parent = stage
	UIKit.corner(shadow, 30)
	local cardScale = Instance.new("UIScale")
	cardScale.Name = "CardScale"
	cardScale.Scale = 0.3
	cardScale.Parent = card
	local shadowScale = cardScale:Clone()
	shadowScale.Parent = shadow
	for _, scale in { cardScale, shadowScale } do
		TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	-- The ribbon over the card's top edge
	local ribbon = Instance.new("Frame")
	ribbon.Name = "Ribbon"
	ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
	ribbon.Position = UDim2.new(0.5, 0, 0, 0)
	ribbon.Size = UDim2.fromOffset(260, 58)
	ribbon.BackgroundColor3 = Color3.new(1, 1, 1)
	ribbon.Parent = card
	UIKit.corner(ribbon, 16)
	gradient(ribbon, COLORS.ribbonTop, COLORS.ribbonBottom)
	local ribbonWords = text(ribbon, "LEVEL UP!", 38, Color3.new(1, 1, 1))
	ribbonWords.Size = UDim2.fromScale(1, 1)
	stroke(ribbonWords, rgb(COLORS.outline), 3.5, true)

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.fromOffset(CARD.width / 2, 44)
	badge.Size = UDim2.fromOffset(92, 92)
	badge.BackgroundColor3 = Color3.new(1, 1, 1)
	badge.Parent = card
	UIKit.corner(badge, 46)
	gradient(badge, COLORS.badgeTop, COLORS.badgeBottom)
	stroke(badge, Color3.new(1, 1, 1), 4)
	local levelWords = text(badge, tostring(to), 48, Color3.new(1, 1, 1))
	levelWords.Size = UDim2.fromScale(1, 1)
	stroke(levelWords, rgb(COLORS.badgeOutline), 3.5, true)
	popIn(badge, 0.15)

	local line = text(card, `Your shop is now Level {to}`, 24, rgb(COLORS.words))
	line.Position = UDim2.fromOffset(16, 142)
	line.Size = UDim2.fromOffset(CARD.width - 32, 34)

	local row = Instance.new("Frame")
	row.Name = "Gifts"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(16, 184)
	row.Size = UDim2.fromOffset(CARD.width - 32, rows * (chipH + 10))
	row.Parent = card
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(chipW, chipH)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = row
	for index, chip in chips do
		local cell = Instance.new("Frame")
		cell.Name = "Gift" .. index
		cell.LayoutOrder = index
		cell.BackgroundColor3 = if chip.new then Color3.fromRGB(255, 251, 232) else Color3.new(1, 1, 1)
		cell.Parent = row
		UIKit.corner(cell, 14)
		stroke(cell, rgb(if chip.new then COLORS.chipNew else COLORS.chipEdge), 3)
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Image = (UIIcons :: any)[chip.icon] or ""
		icon.ScaleType = Enum.ScaleType.Fit
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 8)
		icon.Size = UDim2.fromOffset(48, 48)
		icon.Parent = cell
		local words = text(cell, chip.text, 16, rgb(COLORS.words))
		words.Position = UDim2.fromOffset(4, 58)
		words.Size = UDim2.new(1, -8, 0, 34)
		words.TextScaled = true
		popIn(cell, 0.4 + (index - 1) * CARD.stagger)
	end
	task.delay(0.4 + #chips * CARD.stagger, function()
		if gui.Parent then
			local sound = Instance.new("Sound")
			sound.SoundId = CARD.sound.id
			sound.Volume = CARD.sound.volume
			sound.Parent = SoundService
			sound:Play()
			sound.Ended:Once(function()
				sound:Destroy()
			end)
		end
	end)

	local bottom = 184 + rows * (chipH + 10)
	if note ~= "" then
		local noteWords = text(card, note, 18, rgb(COLORS.soft), Enum.Font.GothamBold)
		noteWords.Position = UDim2.fromOffset(16, bottom)
		noteWords.Size = UDim2.fromOffset(CARD.width - 32, 30)
		bottom += 34
	end

	local button = UIKit.button(card, "Yay!", rgb(COLORS.button))
	button.Name = "Yay"
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 26
	button.TextColor3 = Color3.new(1, 1, 1)
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.fromOffset(CARD.width / 2, bottom + 6)
	button.Size = UDim2.fromOffset(170, 52)
	button.Activated:Connect(close)

	gui.Parent = playerGui
	task.delay(CARD.seconds, function()
		if showing and showing.gui == gui then
			close()
		end
	end)
end

return LevelUpCard
