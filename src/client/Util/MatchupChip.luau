--!strict
-- The matchup chip in your creature's status row (owner 2026-11-25 picked "A" of three mockups; spec
-- 2026-11-25-element-callouts-design): a soft pill in the binder's matchup colours with the foe's element icon,
-- "Weak vs Fire" and a strength tag ("0.75x"); green when you're strong, hidden in an even fight. Look in
-- Config/CombatHud MATCHUP, words from Util/MatchupRules; CombatHud puts it in its ChipRow and sets it on every update.
-- It pops in like the perk chip whenever it shows or changes (a swap, a boss changing element).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local CombatHudConfig = require(Config:WaitForChild("CombatHud"))
local UIFonts = require(Config:WaitForChild("UIFonts"))
local Combat = require(Config:WaitForChild("Combat"))
local ElementNames = require(Config:WaitForChild("ElementNames"))
local MatchupRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("MatchupRules"))

local ElementBadge = require((script.Parent :: Instance):WaitForChild("ElementBadge"))

local MatchupChip = {}

-- set: show this chip (nil: hide); show: the chip for your creature's element against the foe's
export type Handle = { set: (chip: MatchupRules.Chip?) -> (), show: (mine: string?, foe: string?) -> () }

local POP = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out) -- the perk chip's pop
local LOOK = CombatHudConfig.MATCHUP

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function corner(frame: GuiObject, radius: number)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, radius)
	round.Parent = frame
end

-- A row of children centred on the line, `left` / `right` px in from the edges
local function row(frame: GuiObject, left: number, right: number)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, LOOK.GAP)
	list.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, left)
	pad.PaddingRight = UDim.new(0, right)
	pad.Parent = frame
end

local function text(parent: Instance, font: Font, size: number, ink: Color3, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = font
	label.TextSize = size
	label.TextColor3 = ink
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, size + 4)
	label.LayoutOrder = order
	label.Parent = parent
	return label
end

-- The chip as the `order`th child of `parent` (a horizontal list), hidden until set
function MatchupChip.new(parent: Instance, order: number): Handle
	local height = LOOK.HEIGHT
	local frame = Instance.new("Frame")
	frame.Name = "MatchupChip"
	frame.LayoutOrder = order
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.Size = UDim2.fromOffset(0, height)
	frame.Visible = false
	frame.Parent = parent
	corner(frame, height // 2)
	local edge = Instance.new("UIStroke")
	edge.Thickness = LOOK.EDGE
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = frame
	row(frame, LOOK.PAD.left, LOOK.PAD.right)
	local scale = Instance.new("UIScale")
	scale.Parent = frame

	local icon = Instance.new("ImageLabel")
	icon.Name = "Element"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(height - 10, height - 10)
	icon.LayoutOrder = 1
	icon.Parent = frame
	local words = text(frame, UIFonts.BODY, math.floor(height * LOOK.WORDS), color(LOOK.INK), 2)
	words.Name = "Words"

	local tagHeight = height - 12
	local tag = Instance.new("Frame")
	tag.Name = "Tag"
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.Size = UDim2.fromOffset(0, tagHeight)
	tag.LayoutOrder = 3
	tag.Parent = frame
	corner(tag, tagHeight // 2)
	row(tag, LOOK.TAG_PAD.left, LOOK.TAG_PAD.right)
	local tagText = text(tag, UIFonts.BOLD, math.floor(tagHeight * LOOK.TAG_TEXT), Color3.new(1, 1, 1), 1)

	local shown = "" -- what it shows now ("" when hidden), so an unchanged matchup doesn't pop again
	local function set(chip: MatchupRules.Chip?)
		local key = if chip then chip.element .. "|" .. chip.words .. "|" .. chip.tag else "" -- never shown
		if key == shown then
			return
		end
		shown = key
		frame.Visible = chip ~= nil
		if not chip then
			return
		end
		local look = if chip.good then LOOK.GOOD else LOOK.BAD
		frame.BackgroundColor3 = color(look.fill)
		edge.Color = color(look.edge)
		tag.BackgroundColor3 = color(look.tag)
		icon.Image = ElementBadge.image(chip.element)
		words.Text = chip.words
		tagText.Text = chip.tag
		scale.Scale = 0.5
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
	end
	local function show(mine: string?, foe: string?)
		set(MatchupRules.chip(Combat, mine, foe, ElementNames))
	end
	return { set = set, show = show }
end

return MatchupChip
