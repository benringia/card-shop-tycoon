--!strict
-- Card tooltips in the style kit (look E): a card's summary for the binder (pills, a 2x2 grid of icons and numbers,
-- worth) and one copy's for the party bar (Power, stat bars, perk, rest). Pictures and bars first, few words. Each
-- fills a holder frame the caller places (UiLayout.beside / above); the holder sizes itself in Y.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Beasts = require(Config:WaitForChild("Beasts"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CompareRules = require(Shared:WaitForChild("Util"):WaitForChild("CompareRules"))

local ClientUtil = script.Parent :: Instance
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CardFace = require(ClientUtil:WaitForChild("CardFace"))

type Card = typeof(Cards.List[1])
type Stats = { hp: number, atk: number, spd: number }

export type CardInfo = {
	card: Card,
	owned: number,
	onDisplay: number,
	bestGrade: string?,
	bestLevel: number?,
	power: number?,
	worthLow: number?,
	worthHigh: number?,
}

export type CopyInfo = {
	card: Card,
	foil: boolean,
	grade: string,
	level: number,
	stars: number,
	power: number,
	stats: Stats,
	reference: Stats,
	perk: string?,
	restSeconds: number?,
}

local WHITE = Color3.new(1, 1, 1)
local GAP = 6
local TILE_HEIGHT = 40

local CardTips = {}

local referenceCache: Stats? = nil

-- The holder's fresh content column (the previous one is removed)
local function column(holder: Frame): Frame
	local old = holder:FindFirstChild("Content")
	if old then
		old:Destroy()
	end
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.ZIndex = holder.ZIndex + 1
	content.Parent = holder
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content
	return content
end

local function text(parent: Instance, value: string, kind: "body" | "small" | "name" | "number" | "title", color: Color3, outlined: boolean?): TextLabel
	local label = UIKit.label(parent, value, if kind == "body" or kind == "small" then Enum.Font.Gotham else Enum.Font.FredokaOne, UIKit.textSize(kind), color)
	label.TextWrapped = false
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, UIKit.textSize(kind) + 4)
	label.ZIndex = (parent :: GuiObject).ZIndex + 1
	if outlined then
		UIKit.outlined(label, 2)
	end
	return label
end

-- A horizontal row of pieces, `height` tall
local function row(parent: Instance, order: number, height: number, gap: number?): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.ZIndex = (parent :: GuiObject).ZIndex
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, gap or GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

local function iconText(parent: Instance, order: number, icon: string, value: string, color: Color3, kind: "body" | "small" | "name" | "number" | "title"): Frame
	local line = row(parent, order, UIKit.textSize(kind) + 6, 5)
	line.AutomaticSize = Enum.AutomaticSize.X
	line.Size = UDim2.fromOffset(0, UIKit.textSize(kind) + 6)
	local picture = Icon.make(line, icon, UDim2.fromOffset(UIKit.textSize(kind) + 4, UIKit.textSize(kind) + 4))
	picture.LayoutOrder = 1
	picture.ZIndex = line.ZIndex + 1
	text(line, value, kind, color, true).LayoutOrder = 2
	return line
end

local function rarityPill(parent: Instance, card: Card): TextLabel
	return UIKit.pill(parent, card.rarity, CardFace.getRarityColor(card.rarity))
end

local function elementPill(parent: Instance, card: Card): TextLabel
	return UIKit.pill(parent, card.element, Cards.ELEMENTS[card.element], nil, card.element)
end

local function gradePill(parent: Instance, grade: string): TextLabel
	return UIKit.pill(parent, `Grade {grade}`, UIStyle.GRADES[grade] or UIStyle.GRADES.C)
end

-- A small card face (CardFace) in a dark edge; `missing` draws the uncollected silhouette instead
local function face(parent: Instance, card: Card, foil: boolean, size: Vector2, missing: boolean?): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Art"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size.X, size.Y)
	holder.ZIndex = (parent :: GuiObject).ZIndex + 1
	holder.Parent = parent
	local inner = Instance.new("Frame")
	inner.Size = UDim2.fromScale(1, 1)
	inner.ZIndex = holder.ZIndex
	inner.Parent = holder
	UIKit.corner(inner, 8)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = inner
	if missing then
		CardFace.renderMissing(inner, stroke, card)
	else
		CardFace.render(inner, stroke, card, foil, false)
	end
	UIKit.outline(holder, UIStyle.EDGE, 2)
	UIKit.corner(holder, 8)
	return holder
end

function CardTips.art(parent: Instance, card: Card, foil: boolean, size: Vector2): Frame
	return face(parent, card, foil, size)
end

-- A grade pill's tooltip: "Grade S: +10% stats", "Grade C: normal stats"
function CardTips.gradeText(grade: string): string
	local bonus = Beasts.GRADE_BONUS[grade] or 0
	return if bonus > 0 then `Grade {grade}: +{math.round(bonus * 100)}% stats` else `Grade {grade}: normal stats`
end

-- What full stat bars mean: the best stats any card reaches (max level, max stars, Grade S, foil)
function CardTips.reference(): Stats
	local cached = referenceCache
	if cached then
		return cached
	end
	local all: { Stats } = {}
	for _, card in Cards.List do
		table.insert(all, BeastRules.getStats(card, true, Beasts.MAX_LEVEL, Beasts.MAX_STARS, "S"))
	end
	local reference = CompareRules.reference(all)
	referenceCache = reference
	return reference
end

-- One tile of the binder tooltip's 2x2 grid: an icon and a number
local function tile(parent: Instance, order: number, icon: string, value: string, color: Color3)
	local cell = Instance.new("Frame")
	cell.LayoutOrder = order
	cell.BackgroundColor3 = UIStyle.ROW
	cell.ZIndex = (parent :: GuiObject).ZIndex + 1
	cell.Parent = parent
	UIKit.corner(cell, 8)
	UIKit.outline(cell, UIStyle.EDGE, 2)
	local picture = Icon.make(cell, icon, UDim2.fromOffset(24, 24))
	picture.AnchorPoint = Vector2.new(0, 0.5)
	picture.Position = UDim2.new(0, 6, 0.5, 0)
	picture.ZIndex = cell.ZIndex + 1
	local label = UIKit.label(cell, value, Enum.Font.FredokaOne, UIKit.textSize("body") + 2, color)
	label.Position = UDim2.fromOffset(36, 0)
	label.Size = UDim2.new(1, -40, 1, 0)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextWrapped = false
	label.ZIndex = cell.ZIndex + 1
	UIKit.outlined(label, 1.5)
end

-- The binder's hover tooltip for a card
function CardTips.card(holder: Frame, info: CardInfo)
	local content = column(holder)
	local card = info.card
	local collected = info.owned + info.onDisplay > 0

	local top = row(content, 1, 72, 8)
	face(top, card, false, Vector2.new(50, 72), not collected).LayoutOrder = 1
	local names = Instance.new("Frame")
	names.LayoutOrder = 2
	names.BackgroundTransparency = 1
	names.Size = UDim2.new(1, -58, 1, 0)
	names.ZIndex = top.ZIndex
	names.Parent = top
	local stack = Instance.new("UIListLayout")
	stack.VerticalAlignment = Enum.VerticalAlignment.Center
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = names
	local name = text(names, card.name, "name", WHITE, true)
	name.LayoutOrder = 1
	text(names, string.format("#%02d", card.number), "small", UIKit.Colors.Subtext).LayoutOrder = 2

	local pills = row(content, 2, 24, 4)
	rarityPill(pills, card).LayoutOrder = 1
	elementPill(pills, card).LayoutOrder = 2
	if info.bestGrade then
		UIKit.pill(pills, info.bestGrade, UIStyle.GRADES[info.bestGrade] or UIStyle.GRADES.C).LayoutOrder = 3
	end

	if not collected then
		text(content, "Not collected yet", "body", UIKit.Colors.Subtext).LayoutOrder = 3
		return
	end

	local grid = Instance.new("Frame")
	grid.LayoutOrder = 3
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, TILE_HEIGHT * 2 + GAP)
	grid.ZIndex = content.ZIndex
	grid.Parent = content
	local cells = Instance.new("UIGridLayout")
	cells.CellSize = UDim2.new(0.5, -GAP / 2, 0, TILE_HEIGHT)
	cells.CellPadding = UDim2.fromOffset(GAP, GAP)
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.Parent = grid
	tile(grid, 1, "Power", if info.power then tostring(math.floor(info.power)) else "-", UIStyle.POWER)
	tile(grid, 2, "Copies", if info.onDisplay > 0 then `{info.owned} +{info.onDisplay}` else tostring(info.owned), WHITE)
	tile(grid, 3, "Level", if info.bestLevel then `Lv {info.bestLevel}` else "Lv 1", WHITE)
	tile(grid, 4, "Best", info.bestGrade or "-", if info.bestGrade then UIStyle.GRADES[info.bestGrade] or WHITE else WHITE)

	if info.worthLow and info.worthHigh then
		local worth = if info.worthLow == info.worthHigh
			then string.format("$%.2f", info.worthHigh)
			else string.format("$%.2f - $%.2f", info.worthLow, info.worthHigh)
		iconText(content, 4, "Cash", worth, UIStyle.MONEY, "body")
	end
	text(content, "Click for details", "small", UIStyle.HINT).LayoutOrder = 5
end

-- The party bar's hover tooltip for one copy
function CardTips.copy(holder: Frame, info: CopyInfo)
	local content = column(holder)
	local card = info.card

	local top = row(content, 1, 64, 8)
	face(top, card, info.foil, Vector2.new(46, 64)).LayoutOrder = 1
	local names = Instance.new("Frame")
	names.LayoutOrder = 2
	names.BackgroundTransparency = 1
	names.Size = UDim2.new(1, -54, 1, 0)
	names.ZIndex = top.ZIndex
	names.Parent = top
	local stack = Instance.new("UIListLayout")
	stack.VerticalAlignment = Enum.VerticalAlignment.Center
	stack.Padding = UDim.new(0, 2)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = names
	text(names, card.name, "name", WHITE, true).LayoutOrder = 1
	local meta = row(names, 2, 24, 4)
	gradePill(meta, info.grade).LayoutOrder = 1
	text(meta, `Lv {info.level}`, "small", WHITE, true).LayoutOrder = 2
	iconText(names, 3, "Power", tostring(math.floor(info.power)), UIStyle.POWER, "body")

	local bars = Instance.new("Frame")
	bars.LayoutOrder = 2
	bars.BackgroundTransparency = 1
	bars.Size = UDim2.fromScale(1, 0)
	bars.AutomaticSize = Enum.AutomaticSize.Y
	bars.ZIndex = content.ZIndex
	bars.Parent = content
	local barList = Instance.new("UIListLayout")
	barList.Padding = UDim.new(0, 4)
	barList.SortOrder = Enum.SortOrder.LayoutOrder
	barList.Parent = bars
	UIKit.statRow(bars, "Hp", CompareRules.share(info.stats.hp, info.reference.hp)).LayoutOrder = 1
	UIKit.statRow(bars, "Atk", CompareRules.share(info.stats.atk, info.reference.atk)).LayoutOrder = 2
	UIKit.statRow(bars, "Spd", CompareRules.share(info.stats.spd, info.reference.spd)).LayoutOrder = 3

	iconText(content, 3, card.element, info.perk or "No perk", UIKit.Colors.Text, "small")
	local rest = info.restSeconds
	if rest and rest > 0 then
		iconText(content, 4, "Hourglass", `Resting {string.format("%d:%02d", rest // 60, rest % 60)}`, UIStyle.BAD, "small")
	end
end

return CardTips
