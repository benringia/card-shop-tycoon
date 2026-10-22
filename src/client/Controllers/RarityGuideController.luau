--!strict
-- Rarity guide: every rarity from most common to rarest with a sample card, its pull chance from a First
-- Spark pack and "about 1 in N cards", then foil and grade odds, and where Frontier cards come from.
-- The numbers come from the real configs (Util/OddsRules), so the guide can't drift from the rolls.
-- Opened from the binder; built the first time it opens.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Packs = require(Config:WaitForChild("Packs"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Beasts = require(Config:WaitForChild("Beasts"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local Frontier = require(Config:WaitForChild("Frontier"))
local OddsRules = require(Shared:WaitForChild("Util"):WaitForChild("OddsRules"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

type Card = typeof(Cards.List[1])

local PACK_ID = "FirstSparkPack"
local GROUPS = {
	{ title = "Common", note = "The cards you find the most", rarities = { "Common" } },
	{ title = "Rare finds", note = "One in most packs", rarities = { "Rare", "Very Rare" } },
	{ title = "The rarest", note = "The hit slot's big pulls", rarities = { "Epic", "Legendary" } },
}
local ENTRY_HEIGHT = 150
local CARD_SIZE = Vector2.new(96, 137)
local GUIDE_Z_INDEX = 8 -- over the binder

local RarityGuideController = {}

local panel: Frame? = nil

local function percent(chance: number): string
	return if chance >= 0.01 then string.format("%.1f%%", chance * 100) else string.format("%.2f%%", chance * 100)
end

-- "about 1 in 33 cards", or "about 7 in 10 cards" for common ones
local function howOften(chance: number): string
	if chance >= 0.5 then
		return `about {math.floor(chance * 10 + 0.5)} in 10 cards`
	end
	return `about 1 in {OddsRules.oneIn(chance)} cards`
end

local function sampleCard(rarity: string): Card?
	local pool = Cards.ByRarity[rarity]
	return if pool then pool[1] else nil
end

local function addCardFace(parent: Instance, card: Card)
	local face = Instance.new("Frame")
	face.Position = UDim2.fromOffset(8, 7)
	face.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	face.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Parent = face
	CardFace.render(face, stroke, card, false, true)
end

-- One rarity: a sample card, the name in its colour, the chance and "about 1 in N"
local function addEntry(parent: Instance, order: number, card: Card?, name: string, color: Color3, big: string, small: string)
	local entry = Instance.new("Frame")
	entry.LayoutOrder = order
	entry.Size = UDim2.new(0.5, -6, 0, ENTRY_HEIGHT)
	entry.BackgroundColor3 = UIKit.Colors.Row
	entry.Parent = parent
	UIKit.corner(entry, 12)
	UIKit.outline(entry)
	if card then
		addCardFace(entry, card)
	end
	local x = CARD_SIZE.X + 20
	local title = UIKit.label(entry, name, Enum.Font.FredokaOne, 22, color)
	title.Position = UDim2.fromOffset(x, 16)
	title.Size = UDim2.new(1, -(x + 8), 0, 28)
	local chance = UIKit.label(entry, big, Enum.Font.FredokaOne, 30, UIKit.Colors.Text)
	chance.Position = UDim2.fromOffset(x, 50)
	chance.Size = UDim2.new(1, -(x + 8), 0, 38)
	local detail = UIKit.label(entry, small, Enum.Font.GothamBold, 14, UIKit.Colors.Subtext)
	detail.Position = UDim2.fromOffset(x, 92)
	detail.Size = UDim2.new(1, -(x + 8), 0, 44)
end

-- A group box with a title line and a grid of entries
local function addGroup(list: Instance, order: number, title: string, note: string): Frame
	local group = Instance.new("Frame")
	group.LayoutOrder = order
	group.Size = UDim2.new(1, -8, 0, 0)
	group.AutomaticSize = Enum.AutomaticSize.Y
	group.BackgroundColor3 = Color3.fromRGB(232, 240, 252)
	group.Parent = list
	UIKit.corner(group, 14)
	UIKit.outline(group)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = group
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = group
	local heading = UIKit.label(group, `{title}  ·  {note}`, Enum.Font.FredokaOne, 18, UIKit.Colors.Text)
	heading.LayoutOrder = 0
	heading.Size = UDim2.new(1, 0, 0, 24)
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.LayoutOrder = 1
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	grid.Parent = group
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.5, -6, 0, ENTRY_HEIGHT)
	gridLayout.CellPadding = UDim2.fromOffset(10, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	return grid
end

local function addLine(list: Instance, order: number, text: string)
	local line = UIKit.label(list, text, Enum.Font.GothamBold, 15, UIKit.Colors.Text)
	line.LayoutOrder = order
	line.Size = UDim2.new(1, -8, 0, 0)
	line.AutomaticSize = Enum.AutomaticSize.Y
end

local function build(): Frame
	local frame, list = UIKit.panel(UIController.GetScreenGui(), "RarityGuide", "ℹ️ Rarity guide")
	frame.ZIndex = GUIDE_Z_INDEX
	frame.Size = UDim2.fromScale(0.92, 0.88)
	local limit = frame:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(900, 640)
	end
	local pack = Packs.ById[PACK_ID]
	local odds = OddsRules.perCard(pack)

	addLine(list, 1, `The % is the chance for each card you pull from a {pack.name} pack. Common to rarest:`)
	for index, group in GROUPS do
		local grid = addGroup(list, index + 1, group.title, group.note)
		for order, rarity in group.rarities do
			local chance = odds[rarity] or 0
			local tier = Rarities.Tiers[rarity]
			addEntry(grid, order, sampleCard(rarity), rarity, if tier then tier.color else UIKit.Colors.Accent, percent(chance), howOften(chance))
		end
	end

	local frontierGrid = addGroup(list, 10, "Frontier", "Found in the Frontier, never in packs")
	local frontierCard = (Cards.BySet.Frontier or {})[1]
	addEntry(frontierGrid, 1, frontierCard, "Frontier cards", CardEffects.FRONTIER.AURORA[1], "Wild drops", string.format("From Frontier monsters: %s, elites %s", percent(Frontier.CARD_CHANCE), percent(Frontier.ELITE_CARD_CHANCE)))

	addLine(list, 20, string.format("✨ Foil: any card can be foil, %s of cards, worth %dx.", percent(Rarities.FOIL_CHANCE), Rarities.FOIL_MULTIPLIER))
	local gradeParts = {}
	for _, grade in Beasts.GRADES do
		local bonus = Beasts.GRADE_BONUS[grade] or 0
		local extra = if bonus > 0 then string.format(" (+%d%% stats)", math.floor(bonus * 100 + 0.5)) else ""
		table.insert(gradeParts, `{grade} {percent(Beasts.GRADE_CHANCES[grade] or 0)}{extra}`)
	end
	addLine(list, 21, `🏅 Grades: every card gets one when pulled. {table.concat(gradeParts, " · ")}.`)
	return frame
end

function RarityGuideController.Open()
	local frame = panel
	if not frame then
		frame = build()
		panel = frame
	end
	frame.Visible = true
end

return RarityGuideController
