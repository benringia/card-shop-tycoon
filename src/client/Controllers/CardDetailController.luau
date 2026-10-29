--!strict
-- The binder's card view (spec 2026-10-29-collection-screens-ui-design.md 4.2): the 3D card on the left
-- (CardInspectorController: tilt, Flip, Legendary aura, a BEST COPY ribbon while your best copy shows), and right
-- beside it (the pair centred on the screen) a panel in the style kit: the name in a blue band with the worth, rarity / element / number / copies
-- pills, "Your copies" best first (the first one wears a gold BEST ribbon), the chosen copy's Power, HP, ATK and SPD
-- tiles, its XP and next-star bars, and Add to party / Give a job / Back (a disabled button says why). Icons without
-- a label have word tooltips (Util/Tooltip). Add to party opens a chooser: "Who should X replace?" over the three
-- slot cards (each saying how much more or less Power X has), then the comparison for a filled slot. The binder
-- owns the data (Source) and builds this once into its panel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Beasts = require(Config:WaitForChild("Beasts"))
local Jobs = require(Config:WaitForChild("Jobs"))
local Party = require(Config:WaitForChild("Party"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CondenseRules = require(Shared:WaitForChild("Util"):WaitForChild("CondenseRules"))
local CompareRules = require(Shared:WaitForChild("Util"):WaitForChild("CompareRules"))
local PartyRules = require(Shared:WaitForChild("Util"):WaitForChild("PartyRules"))
local UiLayout = require(Shared:WaitForChild("Util"):WaitForChild("UiLayout"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local CardTips = require(ClientUtil:WaitForChild("CardTips"))
local CopyCompare = require(ClientUtil:WaitForChild("CopyCompare"))
local Tooltip = require(ClientUtil:WaitForChild("Tooltip"))
local CardInspectorController = require(Controllers:WaitForChild("CardInspectorController"))

type Card = typeof(Cards.List[1])
type Owned = { normal: number, foil: number }
export type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string }
-- One row: a stack of plain copies (one grade, foil or not) or a levelled card
export type Entry = { key: string, power: number, value: number, beast: Beast?, grade: string, foil: boolean, count: number }
type Target = string | { cardId: string, foil: boolean, grade: string }

-- What the binder lends the card view
export type Source = {
	getEntries: (card: Card) -> { Entry }, -- strongest first
	displayedCount: (cardId: string) -> number, -- copies on display in your cases
	stacks: (cardId: string) -> { [string]: Owned }, -- plain copies by grade
	working: () -> { [string]: string }, -- beastId -> job
	partied: () -> { [string]: boolean },
	beasts: () -> { [string]: Beast },
	setInspecting: (on: boolean) -> (), -- the binder hides its book, tabs and buttons while the card is up
}

local WHITE = Color3.new(1, 1, 1)
local HOW_TO_SELL = "To sell: put it in a Glass Showcase or Collector Case (walk up, F, then Cards)."
local PANEL_TOP = 84 -- below the binder's close button
local PHONE_RIGHT = 76 -- phones: the binder's close button keeps the top right corner
local GAP = 8
local ROW_HEIGHT = 52
local PHONE_ROW_HEIGHT = 48 -- a tap target, never smaller
local PHONE_HEADER = 44 -- phones: a slimmer band, no pills row (the card face shows rarity and element) and no list title
local LIST_TOP = 54 -- the copies list starts under the pills and its title
local CARD_GAP = 16 -- between the 3D card and the panel
local LIST_PAD = 4 -- room inside the copies list for the chosen row's outline
local CHOOSER_BUTTON = 130 -- the chooser's Cancel / Back: compact, on the right
local SLOT_ART_MIN, SLOT_ART_MAX = 52, 150 -- the chooser's slot card heights
local ART_ASPECT = 1.4

local player = Players.LocalPlayer

local CardDetailController = {}

local source: Source
local panel: Frame
local header: Frame
local body: Frame
local copiesTitle: TextLabel
local rowHeight = ROW_HEIGHT
local listTop = LIST_TOP
local nameLabel: TextLabel
local worthLabel: TextLabel
local pillRow: Frame
local copiesList: ScrollingFrame
local selectedBox: Frame
local buttonRow: Frame
local partyButton: TextButton
local jobButton: TextButton
local flipButton: TextButton
local partyChooser: Frame
local jobChooser: Frame
local chooserTitle: TextLabel
local slotsHolder: Frame -- the three party slots, each with what swapping in would do
local compareHolder: Frame -- the comparison against one slot's card
local swapButton: TextButton
local chooserCancel: TextButton
local chooserHint: TextLabel
local compareSlot: number? = nil
local selectedEntry: Entry? = nil
local partySlots: { [number]: string } = {}
local currentCard: Card? = nil
local selectedKey: string? = nil
local partyTarget: Target? = nil
local jobTarget: Target? = nil

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function text(parent: Instance, value: string, size: number, color: Color3, bold: boolean?, outlined: boolean?): TextLabel
	local label = UIKit.label(parent, value, if bold then Enum.Font.FredokaOne else Enum.Font.Gotham, size, color)
	label.TextWrapped = false
	label.Size = UDim2.fromOffset(0, size + 4)
	label.ZIndex = (parent :: GuiObject).ZIndex + 1
	if outlined then
		UIKit.outlined(label, 2)
	end
	return label
end

local function hList(parent: Instance, height: number, gap: number): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.ZIndex = (parent :: GuiObject).ZIndex
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

local function money(value: number): string
	return string.format("$%.2f", value)
end

local function growthOf(entry: Entry): CardFace.Growth
	local beast = entry.beast
	return {
		level = if beast then beast.level else 1,
		stars = if beast then beast.stars else BeastRules.START_STARS,
		grade = entry.grade,
	}
end

-- Panel on the right, as wide as the screen allows; the 3D card's right edge goes just left of it
local function layout()
	local camera = workspace.CurrentCamera
	if not camera or not panel then
		return
	end
	local screen = panel:FindFirstAncestorOfClass("ScreenGui")
	local view = if screen then screen.AbsoluteSize else camera.ViewportSize
	local phone = UIKit.isPhone()
	local width = if phone then math.min(440, view.X * 0.56) else math.min(520, view.X * 0.52)
	local right = if phone then PHONE_RIGHT else 16
	local top = if phone then 8 else PANEL_TOP
	-- The 3D card and the panel centred as a pair (wide screens had an empty half on the left)
	local left = UiLayout.detailPanelLeft(view.X, CardInspectorController.GetCardWidth(), CARD_GAP, width, right)
	local parentX = (panel.Parent :: GuiObject).AbsolutePosition.X - (if screen then screen.AbsolutePosition.X else 0)
	panel.Position = UDim2.new(0, left + width - parentX, 0, top)
	panel.Size = UDim2.new(0, width, 1, -(top + 12))
	local band = if phone then PHONE_HEADER else UIKit.HEADER_HEIGHT
	header.Size = UDim2.new(1, 0, 0, band)
	body.Position = UDim2.fromOffset(12, band + GAP)
	body.Size = UDim2.new(1, -24, 1, -(band + GAP + 66))
	pillRow.Visible = not phone
	copiesTitle.Visible = not phone
	listTop = if phone then 0 else LIST_TOP
	rowHeight = if phone then PHONE_ROW_HEIGHT else ROW_HEIGHT
	copiesList.Position = UDim2.fromOffset(0, listTop)
	copiesList.Size = UDim2.new(1, 0, 1, -(listTop + selectedBox.AbsoluteSize.Y + GAP))
end

-- The disabled look for a button that can't be used now (its text says why)
local function setReady(button: TextButton, ready: boolean, readyColor: Color3)
	button.BackgroundColor3 = if ready then readyColor else UIKit.Colors.Locked
	button.AutoButtonColor = ready
end

local function targetOf(entry: Entry): Target
	local beast = entry.beast
	if beast then
		return beast.id
	end
	return { cardId = (currentCard :: Card).id, foil = entry.foil, grade = entry.grade }
end

-- Add to party / Give a job for the chosen copy, or why not (an open chooser stays open: Refresh redraws it)
local function refreshButtons(selected: Entry?)
	local beast = if selected then selected.beast else nil
	local job = if beast then source.working()[beast.id] else nil
	local inParty = beast ~= nil and source.partied()[beast.id] == true

	local partyText, partyReady = "Add to party", selected ~= nil
	if inParty then
		partyText, partyReady = "In party", false
	elseif job then
		partyText, partyReady = "Working", false
	end
	partyButton.Text = partyText
	setReady(partyButton, partyReady, UIKit.Colors.Accent)
	partyTarget = if partyReady and selected then targetOf(selected) else nil

	local slots = player:GetAttribute("JobSlots")
	local used = player:GetAttribute("JobsUsed")
	local slotCount = if typeof(slots) == "number" then slots else 0
	local usedCount = if typeof(used) == "number" then used else 0
	local jobText, jobReady = "Give a job", selected ~= nil
	if job then
		jobText, jobReady = `Working: {job}`, false
	elseif inParty then
		jobText, jobReady = "In party", false
	elseif slotCount == 0 then
		jobText, jobReady = `Jobs at shop Lv {Jobs.UNLOCK_LEVEL}`, false
	elseif usedCount >= slotCount then
		jobText, jobReady = `Slots full ({usedCount}/{slotCount})`, false
	end
	jobButton.Text = jobText
	setReady(jobButton, jobReady, UIKit.Colors.Secondary)
	jobTarget = if jobReady and selected then targetOf(selected) else nil
end

-- One copy in "Your copies": grade, level, stars, foil or count; Power and value on the right
local function addCopyRow(entry: Entry, order: number, best: boolean)
	local row = Instance.new("TextButton")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, rowHeight)
	row.BackgroundColor3 = UIStyle.ROW
	row.AutoButtonColor = true
	row.Text = ""
	row.ZIndex = copiesList.ZIndex + 1
	row.Parent = copiesList
	UIKit.corner(row, 10)
	local edge = UIKit.outline(row, if entry.key == selectedKey then UIStyle.HINT else UIStyle.EDGE, if entry.key == selectedKey then 3 else 2)
	edge.Name = "Edge"
	row.Activated:Connect(function()
		selectedKey = entry.key
		CardDetailController.Refresh()
	end)

	local left = hList(row, rowHeight, 6)
	left.Position = UDim2.fromOffset(10, 0)
	left.Size = UDim2.new(1, -150, 1, 0)
	left.ZIndex = row.ZIndex
	if best then
		local ribbon = UIKit.pill(left, "BEST", UIStyle.GOLD, nil, "Best")
		ribbon.LayoutOrder = 0
		Tooltip.icon(ribbon, "Best")
	end
	local grade = UIKit.pill(left, entry.grade, UIStyle.GRADES[entry.grade] or UIStyle.GRADES.C)
	grade.LayoutOrder = 1
	Tooltip.attach(grade, CardTips.gradeText(entry.grade))
	local growth = growthOf(entry)
	local level = text(left, `Lv {growth.level}`, UIKit.textSize("body"), WHITE, true, true)
	level.AutomaticSize = Enum.AutomaticSize.X
	level.LayoutOrder = 2
	local stars = UIKit.stars(left, growth.stars, Beasts.MAX_STARS, 14)
	stars.LayoutOrder = 3
	Tooltip.icon(stars, "Star")
	if entry.foil then
		UIKit.pill(left, "FOIL", Color3.fromRGB(150, 110, 255)).LayoutOrder = 4
	end
	if entry.count > 1 then
		local count = text(left, `x{entry.count}`, UIKit.textSize("body"), UIKit.Colors.Subtext, true)
		count.AutomaticSize = Enum.AutomaticSize.X
		count.LayoutOrder = 5
	end

	local powerLine = hList(row, 22, 4)
	powerLine.AnchorPoint = Vector2.new(1, 0)
	powerLine.Position = UDim2.new(1, -12, 0, 5)
	powerLine.Size = UDim2.fromOffset(130, 22)
	powerLine.ZIndex = row.ZIndex;
	(powerLine:FindFirstChildOfClass("UIListLayout") :: UIListLayout).HorizontalAlignment = Enum.HorizontalAlignment.Right
	local powerIcon = Icon.make(powerLine, "Power", UDim2.fromOffset(18, 18))
	powerIcon.ZIndex = row.ZIndex + 1
	Tooltip.icon(powerIcon, "Power")
	text(powerLine, tostring(math.floor(entry.power)), UIKit.textSize("body") + 2, UIStyle.POWER, true, true).AutomaticSize = Enum.AutomaticSize.X
	local value = text(row, money(entry.value), UIKit.textSize("small"), UIStyle.MONEY, true, true)
	value.AnchorPoint = Vector2.new(1, 1)
	value.Position = UDim2.new(1, -12, 1, -6)
	value.Size = UDim2.fromOffset(110, 18)
	value.TextXAlignment = Enum.TextXAlignment.Right
end

-- A labelled bar row: icon, bar, and the words on the right
local function barRow(parent: Instance, order: number, icon: string, share: number, fill: Color3, words: string, wordsColor: Color3)
	local line = Instance.new("Frame")
	line.LayoutOrder = order
	line.BackgroundTransparency = 1
	line.Size = UDim2.new(1, 0, 0, 22)
	line.ZIndex = (parent :: GuiObject).ZIndex
	line.Parent = parent
	local picture = Icon.make(line, icon, UDim2.fromOffset(20, 20))
	picture.AnchorPoint = Vector2.new(0, 0.5)
	picture.Position = UDim2.fromScale(0, 0.5)
	picture.ZIndex = line.ZIndex + 1
	Tooltip.icon(picture, icon)
	local track = UIKit.bar(line, share, fill)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 26, 0.5, 0)
	track.Size = UDim2.new(0.5, -26, 0, track.Size.Y.Offset)
	local label = text(line, words, UIKit.textSize("small"), wordsColor, true, true)
	label.Position = UDim2.new(0.5, 8, 0, 0)
	label.Size = UDim2.new(0.5, -8, 1, 0)
	label.TextTruncate = Enum.TextTruncate.AtEnd
end

-- The chosen copy: four stat tiles, XP and next-star bars, and whether it's busy
local function renderSelected(card: Card, entry: Entry?)
	clear(selectedBox)
	if not entry then
		local none = text(selectedBox, "All your copies are on display.", UIKit.textSize("body"), UIKit.Colors.Subtext)
		none.Size = UDim2.new(1, 0, 0, 24)
		return
	end
	local growth = growthOf(entry)
	local stats = BeastRules.getStats(card, entry.foil, growth.level, growth.stars, entry.grade)

	local tiles = Instance.new("Frame")
	tiles.LayoutOrder = 1
	tiles.BackgroundTransparency = 1
	tiles.Size = UDim2.new(1, 0, 0, 36)
	tiles.ZIndex = selectedBox.ZIndex
	tiles.Parent = selectedBox
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.25, -5, 1, 0)
	grid.CellPadding = UDim2.fromOffset(6, 0)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = tiles
	for index, stat in {
		{ "Power", math.floor(entry.power), UIStyle.POWER },
		{ "Hp", stats.hp, WHITE },
		{ "Atk", stats.atk, WHITE },
		{ "Spd", stats.spd, WHITE },
	} do
		local cell = Instance.new("Frame")
		cell.LayoutOrder = index
		cell.BackgroundColor3 = UIStyle.PANEL
		cell.ZIndex = tiles.ZIndex + 1
		cell.Parent = tiles
		UIKit.corner(cell, 8)
		UIKit.outline(cell, UIStyle.EDGE, 2)
		Tooltip.icon(cell, stat[1] :: string)
		local picture = Icon.make(cell, stat[1] :: string, UDim2.fromOffset(20, 20))
		picture.AnchorPoint = Vector2.new(0, 0.5)
		picture.Position = UDim2.new(0, 5, 0.5, 0)
		picture.ZIndex = cell.ZIndex + 1
		local value = text(cell, tostring(stat[2]), UIKit.textSize("body"), stat[3] :: Color3, true, true)
		value.Position = UDim2.fromOffset(28, 0)
		value.Size = UDim2.new(1, -30, 1, 0)
		value.TextTruncate = Enum.TextTruncate.AtEnd
	end

	local beast = entry.beast
	local toNext = BeastRules.getXpToNext(growth.level)
	if toNext > 0 then
		local xp = if beast then beast.xp else 0
		barRow(selectedBox, 2, "Xp", xp / toNext, UIStyle.XP, `Lv {growth.level} -> {growth.level + 1}: {xp}/{toNext}`, WHITE)
	else
		barRow(selectedBox, 2, "Xp", 1, UIStyle.GOLD, "MAX LEVEL", UIStyle.HINT)
	end

	local cost = BeastRules.getCondenseCost(growth.stars)
	if cost then
		local main = { beast = beast ~= nil, foil = entry.foil, grade = entry.grade, stars = growth.stars }
		local have = CondenseRules.countDuplicates(source.stacks(card.id), main)
		local short = have < cost
		barRow(selectedBox, 3, "Star", math.min(have / cost, 1), UIStyle.GOLD, `Next star: {have}/{cost} copies`, if short then UIStyle.BAD else UIStyle.GOOD)
	else
		barRow(selectedBox, 3, "Star", 1, UIStyle.GOLD, "Max stars", UIStyle.HINT)
	end

	local job = if beast then source.working()[beast.id] else nil
	local busy = if job then `Working: {job}` elseif beast and source.partied()[beast.id] then "In your party" else nil
	if busy and not UIKit.isPhone() then -- phones: the disabled buttons already say it, the copies list needs the room
		local line = hList(selectedBox, 22, 6)
		line.LayoutOrder = 4
		Icon.make(line, if job then "Job" else "Party", UDim2.fromOffset(20, 20)).ZIndex = line.ZIndex + 1
		text(line, busy, UIKit.textSize("small"), UIStyle.HINT, true, true).AutomaticSize = Enum.AutomaticSize.X
	end
end

-- A copy as the comparison sees it: card, Power, stats and the perk it would give
local function sideOf(card: Card, foil: boolean, growth: CardFace.Growth): CopyCompare.Side
	local perk = PartyRules.getPerk(Party, card.element, card.rarity, growth.stars)
	return {
		card = card,
		foil = foil,
		power = BeastRules.getPower(card, foil, growth.level, growth.stars, growth.grade),
		stats = BeastRules.getStats(card, foil, growth.level, growth.stars, growth.grade),
		perk = if perk then PartyRules.describe(perk) else nil,
	}
end

local function incomingSide(): CopyCompare.Side?
	local card, entry = currentCard, selectedEntry
	if not card or not entry then
		return nil
	end
	return sideOf(card, entry.foil, growthOf(entry))
end

-- The card in a party slot, as a comparison side (nil: empty)
local function slotSide(slot: number): CopyCompare.Side?
	local beast = source.beasts()[partySlots[slot] or ""]
	local card = if beast then Cards.ById[beast.cardId] else nil
	if not beast or not card then
		return nil
	end
	return sideOf(card, beast.foil, { level = beast.level, stars = beast.stars, grade = beast.grade })
end

local function addToSlot(slot: number)
	partyChooser.Visible = false
	if partyTarget then
		Remotes.SetPartySlot:FireServer(slot, partyTarget)
	end
end

-- The chooser's first view: three slot cards (card, name, grade, level, Power and stat bars), each saying how much
-- more or less Power the card coming in has; a filled slot opens the comparison, an empty one fills straight away
local function showSlots()
	compareSlot = nil
	compareHolder.Visible = false
	slotsHolder.Visible = true
	swapButton.Visible = false
	chooserHint.Visible = true
	chooserCancel.Text = "Cancel"
	local incoming = incomingSide()
	local name = if currentCard then (currentCard :: Card).name else "this card"
	local free, filled = false, false
	for slot = 1, Party.PARTY_SIZE do
		if slotSide(slot) then
			filled = true
		else
			free = true
		end
	end
	chooserTitle.Text = if free then `Pick a spot for {name}` else `Who should {name} replace?`
	chooserHint.Text = if free and filled then "Tap the free spot, or a card to compare"
		elseif filled then "Tap a card to compare before you swap"
		else "Tap a spot"
	clear(slotsHolder)
	local phone = UIKit.isPhone()
	-- The card as big as the room under the details allows (phones skip the stat bars)
	local details = if phone then 120 else 210
	local artHeight = math.clamp(slotsHolder.AbsoluteSize.Y - details, SLOT_ART_MIN, SLOT_ART_MAX)
	local art = Vector2.new(math.floor(artHeight / ART_ASPECT), artHeight)
	local reference = CardTips.reference()
	for slot = 1, Party.PARTY_SIZE do
		local outgoing = slotSide(slot)
		local button = Instance.new("TextButton")
		button.LayoutOrder = slot
		button.Size = UDim2.new(1 / Party.PARTY_SIZE, -4, 1, 0)
		button.BackgroundColor3 = UIStyle.ROW
		button.Text = ""
		button.AutoButtonColor = true
		button.ZIndex = slotsHolder.ZIndex + 1
		button.Parent = slotsHolder
		UIKit.corner(button, 10)
		UIKit.outline(button, UIStyle.EDGE, 2)
		-- One column, centred: the card, its name, grade and level, Power, stat bars, then what the swap would do
		local column = Instance.new("Frame")
		column.BackgroundTransparency = 1
		column.Position = UDim2.fromOffset(8, 8)
		column.Size = UDim2.new(1, -16, 1, -16)
		column.ZIndex = button.ZIndex
		column.Parent = button
		local stack = Instance.new("UIListLayout")
		stack.Padding = UDim.new(0, if phone then 3 else 5)
		stack.HorizontalAlignment = Enum.HorizontalAlignment.Center
		stack.VerticalAlignment = Enum.VerticalAlignment.Center
		stack.SortOrder = Enum.SortOrder.LayoutOrder
		stack.Parent = column
		local function centredRow(order: number): Frame
			local line = hList(column, 20, 4)
			line.LayoutOrder = order;
			(line:FindFirstChildOfClass("UIListLayout") :: UIListLayout).HorizontalAlignment = Enum.HorizontalAlignment.Center
			return line
		end
		local beast = source.beasts()[partySlots[slot] or ""]
		if outgoing and beast then
			CardTips.art(column, outgoing.card, outgoing.foil, art).LayoutOrder = 0
			local cardName = text(column, outgoing.card.name, UIKit.textSize("body"), WHITE, true, true)
			cardName.LayoutOrder = 1
			cardName.TextXAlignment = Enum.TextXAlignment.Center
			cardName.TextTruncate = Enum.TextTruncate.AtEnd
			cardName.Size = UDim2.new(1, 0, 0, UIKit.textSize("body") + 4)
			local meta = centredRow(2)
			local grade = UIKit.pill(meta, beast.grade, UIStyle.GRADES[beast.grade] or UIStyle.GRADES.C)
			grade.Size = UDim2.fromOffset(0, 18)
			Tooltip.attach(grade, CardTips.gradeText(beast.grade))
			text(meta, `Lv {beast.level}`, UIKit.textSize("small"), WHITE, true, true).AutomaticSize = Enum.AutomaticSize.X
			local power = centredRow(3)
			local powerIcon = Icon.make(power, "Power", UDim2.fromOffset(18, 18))
			powerIcon.ZIndex = power.ZIndex + 1
			Tooltip.icon(powerIcon, "Power")
			text(power, tostring(math.floor(outgoing.power)), UIKit.textSize("body"), UIStyle.POWER, true, true).AutomaticSize = Enum.AutomaticSize.X
			if not phone then
				for index, stat in { { "Hp", outgoing.stats.hp, reference.hp }, { "Atk", outgoing.stats.atk, reference.atk }, { "Spd", outgoing.stats.spd, reference.spd } } do
					local row = UIKit.statRow(column, stat[1] :: string, CompareRules.share(stat[2] :: number, stat[3] :: number))
					row.LayoutOrder = 3 + index
					row.ZIndex = column.ZIndex + 1
					Tooltip.icon(row:FindFirstChild("Icon") :: Frame, stat[1] :: string)
				end
			end
		else
			local plus = text(column, "+", art.Y / 2, UIKit.Colors.Subtext, true)
			plus.LayoutOrder = 0
			plus.TextXAlignment = Enum.TextXAlignment.Center
			plus.Size = UDim2.new(1, 0, 0, art.Y / 2 + 4)
			local empty = text(column, `Slot {slot} is free`, UIKit.textSize("body"), UIKit.Colors.Subtext, true)
			empty.LayoutOrder = 1
			empty.TextXAlignment = Enum.TextXAlignment.Center
			empty.Size = UDim2.new(1, 0, 0, UIKit.textSize("body") + 4)
		end
		if incoming then
			-- What swapping would do, in words, on a tinted strip at the bottom of the card
			local outPower = if outgoing then outgoing.power else nil
			local kind = CompareRules.verdict(incoming.power, outPower)
			local good = outgoing == nil or kind ~= "weaker"
			local strip = Instance.new("Frame")
			strip.LayoutOrder = 9
			strip.Size = UDim2.new(1, 0, 0, 2 * UIKit.textSize("small") + 12)
			strip.BackgroundColor3 = if good then UIStyle.GOOD else UIStyle.BAD
			strip.BackgroundTransparency = 0.8
			strip.ZIndex = column.ZIndex + 1
			strip.Parent = column
			UIKit.corner(strip, 8)
			local swap = text(strip, CompareRules.swapText(incoming.card.name, incoming.power, outPower), UIKit.textSize("small"), if good then UIStyle.GOOD else UIStyle.BAD, true, true)
			swap.TextXAlignment = Enum.TextXAlignment.Center
			swap.TextWrapped = true
			swap.Size = UDim2.fromScale(1, 1)
		end
		button.Activated:Connect(function()
			if outgoing then
				CardDetailController.ShowCompare(slot)
			else
				addToSlot(slot) -- an empty slot fills straight away
			end
		end)
	end
end

-- The chooser's second view: the kid comparison against one slot's card, then Swap or Back
function CardDetailController.ShowCompare(slot: number)
	local incoming, outgoing = incomingSide(), slotSide(slot)
	if not incoming or not outgoing then
		showSlots()
		return
	end
	compareSlot = slot
	slotsHolder.Visible = false
	compareHolder.Visible = true
	chooserHint.Visible = false
	chooserTitle.Text = `Swap {incoming.card.name} for {outgoing.card.name}?`
	CopyCompare.build(compareHolder, incoming, outgoing)
	swapButton.Text = `Swap with {outgoing.card.name}`
	swapButton.Visible = true
	chooserCancel.Text = "Back"
end

function CardDetailController.Refresh()
	local card = currentCard
	if not card or not panel.Visible then
		return
	end
	local entries = source.getEntries(card)
	local onDisplay = source.displayedCount(card.id)
	if #entries + onDisplay == 0 then
		CardDetailController.Close()
		return
	end
	-- Keep the selection valid: if that copy left the binder, show the strongest one
	local selected: Entry? = nil
	for _, entry in entries do
		if entry.key == selectedKey then
			selected = entry
		end
	end
	selected = selected or entries[1]
	selectedKey = if selected then selected.key else nil
	selectedEntry = selected

	if selected then
		CardInspectorController.Show(card, selected.foil, growthOf(selected), if selected == entries[1] and #entries > 1 then "BEST COPY" else nil)
	else
		CardInspectorController.Show(card, false, nil)
	end

	nameLabel.Text = card.name
	local low, high, owned = math.huge, 0, 0
	for _, entry in entries do
		low = math.min(low, entry.value)
		high = math.max(high, entry.value)
		owned += entry.count
	end
	worthLabel.Text = if #entries == 0 then "" elseif low == high then money(high) else `{money(low)} - {money(high)}`

	clear(pillRow)
	UIKit.pill(pillRow, card.rarity, CardFace.getRarityColor(card.rarity)).LayoutOrder = 1
	UIKit.pill(pillRow, card.element, Cards.ELEMENTS[card.element], nil, card.element).LayoutOrder = 2
	UIKit.pill(pillRow, string.format("#%02d", card.number), UIStyle.ROW).LayoutOrder = 3
	local copies = UIKit.pill(pillRow, if onDisplay > 0 then `x{owned} · {onDisplay} shown` else `x{owned}`, UIStyle.ROW, nil, "Copies")
	copies.LayoutOrder = 4
	Tooltip.icon(copies, "Copies")

	clear(copiesList)
	for index, entry in entries do
		addCopyRow(entry, index, index == 1 and #entries > 1)
	end
	local footer = text(copiesList, HOW_TO_SELL, UIKit.textSize("small"), UIKit.Colors.Subtext)
	footer.LayoutOrder = #entries + 1
	footer.TextWrapped = true
	footer.Size = UDim2.new(1, -8, 0, 36)

	renderSelected(card, selected)
	refreshButtons(selected)
	-- A shop sale or a binder update mustn't close a chooser someone is reading: redraw it, or close it if the copy
	-- can no longer go there
	if partyChooser.Visible then
		if not partyTarget then
			partyChooser.Visible = false
		elseif compareSlot then
			CardDetailController.ShowCompare(compareSlot)
		else
			showSlots()
		end
	end
	if jobChooser.Visible and not jobTarget then
		jobChooser.Visible = false
	end
end

function CardDetailController.IsOpen(): boolean
	return panel ~= nil and panel.Visible
end

function CardDetailController.Open(card: Card)
	currentCard = card
	local strongest = source.getEntries(card)[1] -- open on the strongest copy
	selectedKey = if strongest then strongest.key else nil
	layout()
	panel.Visible = true
	CardDetailController.Refresh()
end

function CardDetailController.Close()
	if panel then
		panel.Visible = false
	end
	currentCard = nil
	-- Give the camera back now, not in the (deferred) Visible handler: the binder restores its own camera right after
	-- this when it closes, and must be the last to touch it
	CardInspectorController.Close()
end

function CardDetailController.SetPartySlots(slots: { [number]: string })
	partySlots = slots
	if panel and partyChooser.Visible then
		if compareSlot then
			CardDetailController.ShowCompare(compareSlot)
		else
			showSlots()
		end
	end
end

-- A small window over the panel's button row (party slot or job)
local function chooser(name: string, title: string, height: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -66)
	frame.Size = UDim2.new(1, -24, 0, height)
	frame.BackgroundColor3 = UIStyle.PANEL
	frame.Visible = false
	frame.ZIndex = panel.ZIndex + 10
	frame.Parent = panel
	UIKit.corner(frame, 12)
	UIKit.outline(frame, UIStyle.HINT, UIStyle.EDGE_THICKNESS)
	local label = text(frame, title, UIKit.textSize("body"), WHITE, true, true)
	label.Position = UDim2.fromOffset(12, 8)
	label.Size = UDim2.new(1, -24, 0, 22)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return frame
end

-- A row of equal buttons across a chooser
local function choiceButtons(frame: Frame, labels: { string }, onPick: (index: number) -> ()): { TextButton }
	local buttons = {}
	for index, label in labels do
		local button = UIKit.button(frame, label, UIKit.Colors.Accent)
		button.Position = UDim2.new((index - 1) / #labels, if index == 1 then 12 else 4, 0, 38)
		button.Size = UDim2.new(1 / #labels, -16, 0, 52)
		button.TextSize = UIKit.textSize("small")
		button.TextWrapped = true
		button.ZIndex = frame.ZIndex + 1
		button.Activated:Connect(function()
			frame.Visible = false
			onPick(index)
		end)
		table.insert(buttons, button)
	end
	local cancel = UIKit.iconButton(frame, "Cancel", "Close", UIKit.Colors.Secondary)
	cancel.Position = UDim2.new(0, 12, 1, -56)
	cancel.Size = UDim2.new(1, -24, 0, 48)
	cancel.TextSize = UIKit.textSize("body")
	cancel.ZIndex = frame.ZIndex + 1
	cancel.Activated:Connect(function()
		frame.Visible = false
	end)
	return buttons
end

-- Builds the card view into the binder's panel; `from` lends the binder's data
function CardDetailController.Build(parent: Frame, from: Source)
	source = from
	panel = Instance.new("Frame")
	panel.Name = "CardDetail"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.BackgroundColor3 = UIStyle.PANEL
	panel.ZIndex = 10
	panel.Visible = false
	panel.Active = true
	panel.Parent = parent
	UIKit.corner(panel, 16)
	UIKit.outline(panel, UIStyle.EDGE, UIStyle.EDGE_THICKNESS)

	header, nameLabel = UIKit.header(panel, "", "Cards")
	header.ZIndex = panel.ZIndex + 1
	nameLabel.ZIndex = header.ZIndex + 1
	nameLabel.Size = UDim2.new(0.6, -18, 1, 0)
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	worthLabel = text(header, "", UIKit.textSize("body") + 2, UIStyle.MONEY, true, true)
	worthLabel.AnchorPoint = Vector2.new(1, 0)
	worthLabel.Position = UDim2.new(1, -14, 0, 0)
	worthLabel.Size = UDim2.new(0.4, -40, 1, 0)
	worthLabel.TextXAlignment = Enum.TextXAlignment.Right
	worthLabel.ZIndex = header.ZIndex + 2
	local cashIcon = Icon.make(header, "Cash", UDim2.fromOffset(26, 26))
	cashIcon.AnchorPoint = Vector2.new(1, 0.5)
	cashIcon.ZIndex = header.ZIndex + 2
	Tooltip.icon(cashIcon, "Cash")
	local function placeCash()
		cashIcon.Position = UDim2.new(1, -20 - worthLabel.TextBounds.X, 0.5, 0)
		cashIcon.Visible = worthLabel.Text ~= ""
	end
	worthLabel:GetPropertyChangedSignal("TextBounds"):Connect(placeCash)
	worthLabel:GetPropertyChangedSignal("Text"):Connect(placeCash)

	body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(12, UIKit.HEADER_HEIGHT + GAP)
	body.Size = UDim2.new(1, -24, 1, -(UIKit.HEADER_HEIGHT + GAP + 66))
	body.ZIndex = panel.ZIndex + 1
	body.Parent = panel

	pillRow = hList(body, 26, 6)
	pillRow.Name = "Pills"

	copiesTitle = text(body, "Your copies, best first", UIKit.textSize("small"), UIKit.Colors.Subtext, true)
	copiesTitle.Position = UDim2.fromOffset(0, 32)
	copiesTitle.Size = UDim2.new(1, 0, 0, 18)

	-- The chosen copy sits at the bottom of the body; the list fills what's left above it (and scrolls)
	selectedBox = Instance.new("Frame")
	selectedBox.Name = "Selected"
	selectedBox.AnchorPoint = Vector2.new(0, 1)
	selectedBox.Position = UDim2.fromScale(0, 1)
	selectedBox.Size = UDim2.new(1, 0, 0, 0)
	selectedBox.AutomaticSize = Enum.AutomaticSize.Y
	selectedBox.BackgroundColor3 = UIStyle.ROW
	selectedBox.ZIndex = body.ZIndex + 1
	selectedBox.Parent = body
	UIKit.corner(selectedBox, 10)
	UIKit.outline(selectedBox, UIStyle.EDGE, 2)
	local boxPadding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(boxPadding :: any)[side] = UDim.new(0, 8)
	end
	boxPadding.Parent = selectedBox
	local boxList = Instance.new("UIListLayout")
	boxList.Padding = UDim.new(0, 6)
	boxList.SortOrder = Enum.SortOrder.LayoutOrder
	boxList.Parent = selectedBox

	copiesList = Instance.new("ScrollingFrame")
	copiesList.Name = "Copies"
	copiesList.Position = UDim2.fromOffset(0, LIST_TOP)
	copiesList.BackgroundTransparency = 1
	copiesList.BorderSizePixel = 0
	copiesList.ScrollBarThickness = 5
	copiesList.ScrollBarImageColor3 = UIStyle.HINT
	copiesList.CanvasSize = UDim2.new()
	copiesList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	copiesList.ZIndex = body.ZIndex + 1
	copiesList.Parent = body
	local rows = Instance.new("UIListLayout")
	rows.Padding = UDim.new(0, 6)
	rows.SortOrder = Enum.SortOrder.LayoutOrder
	rows.Parent = copiesList
	-- The chosen row's outline draws outside it: leave room so the list doesn't clip it (and the scroll bar)
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, LIST_PAD)
	listPadding.PaddingBottom = UDim.new(0, LIST_PAD)
	listPadding.PaddingLeft = UDim.new(0, LIST_PAD)
	listPadding.PaddingRight = UDim.new(0, LIST_PAD + copiesList.ScrollBarThickness + 2)
	listPadding.Parent = copiesList
	local function fitList()
		copiesList.Size = UDim2.new(1, 0, 1, -(listTop + selectedBox.AbsoluteSize.Y + GAP))
	end
	selectedBox:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitList)
	fitList()

	buttonRow = Instance.new("Frame")
	buttonRow.Name = "Buttons"
	buttonRow.BackgroundTransparency = 1
	buttonRow.AnchorPoint = Vector2.new(0, 1)
	buttonRow.Position = UDim2.new(0, 12, 1, -10)
	buttonRow.Size = UDim2.new(1, -24, 0, 50)
	buttonRow.ZIndex = panel.ZIndex + 1
	buttonRow.Parent = panel
	local function bottomButton(label: string, icon: string, color: Color3, third: number): TextButton
		local button = UIKit.iconButton(buttonRow, label, icon, color)
		button.Position = UDim2.new(third / 3, if third == 0 then 0 else 4, 0, 0)
		button.Size = UDim2.new(1 / 3, -6, 1, 0)
		button.TextSize = UIKit.textSize("body")
		button.TextWrapped = true
		button.ZIndex = buttonRow.ZIndex + 1
		return button
	end
	partyButton = bottomButton("Add to party", "Party", UIKit.Colors.Accent, 0)
	jobButton = bottomButton("Give a job", "Job", UIKit.Colors.Secondary, 1)
	local back = bottomButton("Back", "Close", UIKit.Colors.Secondary, 2)
	back.Activated:Connect(CardDetailController.Close)

	-- Add to party: covers the panel; slot cards first, then the comparison for a filled slot
	partyChooser = Instance.new("Frame")
	partyChooser.Name = "PartyChooser"
	partyChooser.AnchorPoint = Vector2.new(0.5, 0.5)
	partyChooser.Position = UDim2.fromScale(0.5, 0.5)
	partyChooser.Size = UDim2.new(1, -12, 1, -12)
	partyChooser.BackgroundColor3 = UIStyle.PANEL
	partyChooser.Active = true
	partyChooser.Visible = false
	partyChooser.ZIndex = panel.ZIndex + 10
	partyChooser.Parent = panel
	UIKit.corner(partyChooser, 14)
	UIKit.outline(partyChooser, UIStyle.HINT, UIStyle.EDGE_THICKNESS)
	chooserTitle = text(partyChooser, "", UIKit.textSize("name"), WHITE, true, true)
	chooserTitle.Position = UDim2.fromOffset(14, 8)
	chooserTitle.Size = UDim2.new(1, -28, 0, 30)
	chooserTitle.TextTruncate = Enum.TextTruncate.AtEnd
	slotsHolder = Instance.new("Frame")
	slotsHolder.Name = "Slots"
	slotsHolder.BackgroundTransparency = 1
	slotsHolder.Position = UDim2.fromOffset(10, 44)
	slotsHolder.Size = UDim2.new(1, -20, 1, -(44 + 66))
	slotsHolder.ZIndex = partyChooser.ZIndex + 1
	slotsHolder.Parent = partyChooser
	-- The three slot cards side by side, sharing the width
	local slotList = Instance.new("UIListLayout")
	slotList.FillDirection = Enum.FillDirection.Horizontal
	slotList.Padding = UDim.new(0, 6)
	slotList.SortOrder = Enum.SortOrder.LayoutOrder
	slotList.Parent = slotsHolder
	compareHolder = Instance.new("Frame")
	compareHolder.Name = "Compare"
	compareHolder.BackgroundTransparency = 1
	compareHolder.Position = UDim2.fromOffset(10, 44)
	compareHolder.Size = UDim2.new(1, -20, 1, -(44 + 66))
	compareHolder.ZIndex = partyChooser.ZIndex + 1
	compareHolder.Visible = false
	compareHolder.Parent = partyChooser
	swapButton = UIKit.iconButton(partyChooser, "Swap", "Party", UIKit.Colors.Accent)
	swapButton.AnchorPoint = Vector2.new(0, 1)
	swapButton.Position = UDim2.new(0, 10, 1, -10)
	swapButton.Size = UDim2.new(1, -(CHOOSER_BUTTON + 30), 0, 50)
	swapButton.TextSize = UIKit.textSize("body")
	swapButton.TextTruncate = Enum.TextTruncate.AtEnd
	swapButton.ZIndex = partyChooser.ZIndex + 2
	swapButton.Activated:Connect(function()
		if compareSlot then
			addToSlot(compareSlot)
		end
	end)
	chooserCancel = UIKit.iconButton(partyChooser, "Cancel", "Close", UIKit.Colors.Secondary)
	chooserCancel.AnchorPoint = Vector2.new(1, 1)
	chooserCancel.Position = UDim2.new(1, -10, 1, -10)
	chooserCancel.Size = UDim2.fromOffset(CHOOSER_BUTTON, 50)
	chooserCancel.TextSize = UIKit.textSize("body")
	chooserCancel.ZIndex = partyChooser.ZIndex + 2
	chooserCancel.Activated:Connect(function()
		if compareSlot then
			showSlots()
		else
			partyChooser.Visible = false
		end
	end)
	chooserHint = text(partyChooser, "", UIKit.textSize("small"), UIKit.Colors.Subtext, true)
	chooserHint.AnchorPoint = Vector2.new(0, 1)
	chooserHint.Position = UDim2.new(0, 14, 1, -10)
	chooserHint.Size = UDim2.new(1, -(CHOOSER_BUTTON + 40), 0, 50)
	chooserHint.TextWrapped = true
	jobChooser = chooser("JobChooser", "Which job?", 150)
	choiceButtons(jobChooser, Jobs.JOBS, function(index)
		if jobTarget then
			Remotes.AssignJob:FireServer(jobTarget, Jobs.JOBS[index])
		end
	end)
	partyButton.Activated:Connect(function()
		if partyTarget then
			jobChooser.Visible = false
			partyChooser.Visible = true
			showSlots()
		end
	end)
	jobButton.Activated:Connect(function()
		if jobTarget then
			partyChooser.Visible = false
			jobChooser.Visible = true
		end
	end)

	-- Flip sits under the 3D card (it moves with the panel and the screen)
	flipButton = UIKit.iconButton(parent, "Flip", "Flip", UIKit.Colors.Secondary)
	flipButton.Name = "Flip"
	flipButton.AnchorPoint = Vector2.new(0.5, 0)
	flipButton.Size = UDim2.fromOffset(120, 48)
	flipButton.TextSize = UIKit.textSize("body")
	flipButton.ZIndex = panel.ZIndex
	flipButton.Visible = false
	flipButton.Activated:Connect(CardInspectorController.Flip)
	RunService.RenderStepped:Connect(function()
		local rect = if panel.Visible then CardInspectorController.GetCardRect() else nil
		flipButton.Visible = rect ~= nil
		if rect then
			local origin = (flipButton.Parent :: GuiObject).AbsolutePosition
			flipButton.Position = UDim2.fromOffset(rect.x + rect.w / 2 - origin.X, rect.y + rect.h + 8 - origin.Y)
		end
	end)

	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			currentCard = nil -- so a later collection update can't reopen the 3D card on its own
			partyChooser.Visible = false
			jobChooser.Visible = false
			CardInspectorController.Close()
		end
		source.setInspecting(panel.Visible)
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	-- The 3D card's right edge follows the panel's real left edge on screen (safe areas and notches included)
	local function followPanel()
		CardInspectorController.SetCardRight(panel.AbsolutePosition.X - CARD_GAP)
	end
	panel:GetPropertyChangedSignal("AbsolutePosition"):Connect(followPanel)
	followPanel()
	parent:GetPropertyChangedSignal("AbsolutePosition"):Connect(layout)
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	for _, name in { "JobSlots", "JobsUsed" } do
		player:GetAttributeChangedSignal(name):Connect(CardDetailController.Refresh)
	end
	layout()
end

return CardDetailController
