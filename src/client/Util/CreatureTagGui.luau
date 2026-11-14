--!strict
-- Draws a summoned creature's name tag (owner 2026-11-14, the gacha title; Util/CreatureTag decides what it says and
-- where it sits, Party.TAG its sizes): a billboard over the creature with, from the bottom up, a dark pill (element
-- icon, level, grade chip), the name big in its rarity colour with a dark outline (a rainbow for a foil), the stars
-- (earned bright, the rest faint) and, on other players' creatures, the owner's name.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Party = require(Config:WaitForChild("Party"))
local Beasts = require(Config:WaitForChild("Beasts"))
local UIIcons = require(Config:WaitForChild("UIIcons"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local CreatureTag = require(Shared:WaitForChild("Util"):WaitForChild("CreatureTag"))

local TAG = Party.TAG
local INK = Color3.fromRGB(TAG.INK[1], TAG.INK[2], TAG.INK[3])
local WHITE = Color3.new(1, 1, 1)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.55, 1)),
	ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.15, 0.55, 1)),
	ColorSequenceKeypoint.new(0.66, Color3.fromHSV(0.5, 0.55, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromHSV(0.8, 0.55, 1)),
})

local CreatureTagGui = {}

local function label(parent: Instance, name: string, font: Enum.Font): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Font = font
	text.TextColor3 = WHITE
	text.Text = ""
	text.Parent = parent
	return text
end

-- A full-width row of the tag, its children side by side in the middle
local function row(parent: Instance, name: string, height: number, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.LayoutOrder = order
	frame.Parent = parent
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = frame
	return frame
end

local function round(parent: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = parent
end

function CreatureTagGui.build(root: BasePart, above: number, rarityColor: Color3, element: string): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "CreatureTag"
	gui.Size = UDim2.fromOffset(TAG.WIDTH, CreatureTag.height(TAG))
	gui.SizeOffset = Vector2.new(0, CreatureTag.lift(TAG))
	gui.StudsOffset = Vector3.new(0, above + 1, 0)
	gui.MaxDistance = TAG.MAX_DISTANCE
	gui.LightInfluence = 0
	gui:SetAttribute("NameColor", rarityColor:Lerp(WHITE, TAG.NAME_LIGHTEN))
	local rows = Instance.new("UIListLayout")
	rows.FillDirection = Enum.FillDirection.Vertical
	rows.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rows.VerticalAlignment = Enum.VerticalAlignment.Bottom -- a hidden owner line leaves room on top, not a gap
	rows.SortOrder = Enum.SortOrder.LayoutOrder
	rows.Padding = UDim.new(0, TAG.GAP)
	rows.Parent = gui

	local owner = label(gui, "Owner", Enum.Font.GothamBold)
	owner.Size = UDim2.new(1, 0, 0, TAG.OWNER)
	owner.TextScaled = true
	owner.TextTransparency = 0.1
	owner.TextStrokeColor3 = INK
	owner.TextStrokeTransparency = 0.2
	owner.LayoutOrder = 1
	owner.Visible = false

	local stars = row(gui, "Stars", TAG.STARS, 2)
	;(stars:FindFirstChildOfClass("UIListLayout") :: UIListLayout).Padding = UDim.new(0, 0)
	for index = 1, Beasts.MAX_STARS do
		local star = label(stars, `Star{index}`, Enum.Font.FredokaOne)
		star.Size = UDim2.fromOffset(TAG.STARS, TAG.STARS)
		star.Text = "⭐"
		star.TextScaled = true
		star.LayoutOrder = index
	end

	local name = label(gui, "Name", Enum.Font.FredokaOne)
	name.Size = UDim2.new(1, 0, 0, TAG.NAME)
	name.TextScaled = true
	name.LayoutOrder = 3
	local outline = Instance.new("UIStroke")
	outline.Color = INK
	outline.Thickness = 2
	outline.Parent = name
	local foil = Instance.new("UIGradient")
	foil.Name = "Foil"
	foil.Color = RAINBOW
	foil.Enabled = false
	foil.Parent = name

	local pillRow = row(gui, "PillRow", TAG.PILL, 4)
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.BackgroundColor3 = INK
	pill.BackgroundTransparency = TAG.PILL_TRANSPARENCY
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, TAG.PILL)
	pill.Parent = pillRow
	round(pill)
	local inside = Instance.new("UIListLayout")
	inside.FillDirection = Enum.FillDirection.Horizontal
	inside.VerticalAlignment = Enum.VerticalAlignment.Center
	inside.SortOrder = Enum.SortOrder.LayoutOrder
	inside.Padding = UDim.new(0, 4)
	inside.Parent = pill
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 3)
	padding.PaddingRight = UDim.new(0, 3)
	padding.Parent = pill
	local icon = Instance.new("ImageLabel")
	icon.Name = "Element"
	icon.BackgroundTransparency = 1
	icon.Image = (UIIcons :: any)[element] or ""
	icon.Visible = icon.Image ~= ""
	icon.Size = UDim2.fromOffset(TAG.ICON, TAG.ICON)
	icon.LayoutOrder = 1
	icon.Parent = pill
	local level = label(pill, "Level", Enum.Font.GothamBold)
	level.AutomaticSize = Enum.AutomaticSize.X
	level.Size = UDim2.fromOffset(0, TAG.PILL)
	level.TextSize = TAG.PILL - 7
	level.LayoutOrder = 2
	local chip = Instance.new("Frame")
	chip.Name = "Grade"
	chip.Size = UDim2.fromOffset(TAG.PILL - 4, TAG.PILL - 4)
	chip.LayoutOrder = 3
	chip.Parent = pill
	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0.3, 0)
	chipCorner.Parent = chip
	local letter = label(chip, "Letter", Enum.Font.FredokaOne)
	letter.Size = UDim2.fromScale(1, 1)
	letter.TextScaled = true
	letter.TextColor3 = INK

	gui.Parent = root
	return gui
end

-- Fills a tag from what Util/CreatureTag.info says
function CreatureTagGui.set(gui: BillboardGui, info: CreatureTag.Info)
	local owner = gui:FindFirstChild("Owner") :: TextLabel?
	if owner then
		owner.Text = info.owner or ""
		owner.Visible = info.owner ~= nil
	end
	local stars = gui:FindFirstChild("Stars")
	if stars then
		for index = 1, Beasts.MAX_STARS do
			local star = stars:FindFirstChild(`Star{index}`) :: TextLabel?
			if star then
				star.TextTransparency = if index <= info.stars then 0 else TAG.EMPTY_STAR
			end
		end
	end
	local name = gui:FindFirstChild("Name") :: TextLabel?
	if name then
		name.Text = info.name
		name.TextColor3 = if info.foil then WHITE else gui:GetAttribute("NameColor") :: Color3? or WHITE
		local foil = name:FindFirstChild("Foil") :: UIGradient?
		if foil then
			foil.Enabled = info.foil
		end
	end
	local pill = gui:FindFirstChild("Pill", true)
	if pill then
		local level = pill:FindFirstChild("Level") :: TextLabel?
		if level then
			level.Text = info.level
		end
		local chip = pill:FindFirstChild("Grade") :: Frame?
		if chip then
			chip.BackgroundColor3 = (UIStyle.GRADES :: any)[info.grade] or WHITE
			local letter = chip:FindFirstChild("Letter") :: TextLabel?
			if letter then
				letter.Text = info.grade
			end
		end
	end
end

return CreatureTagGui
