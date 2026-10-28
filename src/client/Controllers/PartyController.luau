--!strict
-- Party panel (spec 2026-10-29-collection-screens-ui-design.md 4.4): your 3 party cards side by side, no scrolling.
-- Each column: the card, name, grade, level and stars, its Power, HP / ATK / SPD bars, the perk it gives while
-- summoned, a resting timer after fainting, and Summon (or the green Summoned, which unsummons), XP Tonic (with how
-- many you hold) and Remove. The summoned card's column glows green with a SUMMONED tag. The header shows who is
-- summoned and your PvP record. One card is summoned at a time: it follows you around and its perk works. Cards are
-- added from the binder card view. The server sends PartyChanged on every change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Beasts = require(Config:WaitForChild("Beasts"))
local Cards = require(Config:WaitForChild("Cards"))
local Party = require(Config:WaitForChild("Party"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local PartyRules = require(Shared:WaitForChild("Util"):WaitForChild("PartyRules"))
local CompareRules = require(Shared:WaitForChild("Util"):WaitForChild("CompareRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local RestTimers = require(ClientUtil:WaitForChild("RestTimers"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CardTips = require(ClientUtil:WaitForChild("CardTips"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type PartyState = {
	slots: { { slot: number, beastId: string } },
	summoned: number?,
	perk: { kind: string, value: number, text: string }?,
}

local WHITE = Color3.new(1, 1, 1)
local MAX_SIZE = Vector2.new(780, 500)
local GAP = 8
local CHIP_HEIGHT = 28

local PartyController = {}

local panel: Frame
local columns: Frame
local chips: Frame
local state: PartyState? = nil
local restLabels: { [string]: TextLabel } = {} -- beastId -> its column's resting line
local tonicCount = 0 -- XP Tonics held (from ItemsChanged)

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function text(parent: Instance, value: string, size: number, color: Color3, bold: boolean?): TextLabel
	local label = UIKit.label(parent, value, if bold then Enum.Font.FredokaOne else Enum.Font.Gotham, size, color)
	label.TextWrapped = false
	label.Size = UDim2.fromOffset(0, size + 4)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.ZIndex = (parent :: GuiObject).ZIndex + 1
	if bold then
		UIKit.outlined(label, 2)
	end
	return label
end

local function list(parent: Instance, horizontal: boolean, gap: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

local function strip(parent: Instance, order: number, height: number, gap: number): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.ZIndex = (parent :: GuiObject).ZIndex
	frame.Parent = parent
	list(frame, true, gap)
	return frame
end

-- "PvP 12 - 5" (and " - 1" when there are draws), from the attributes ArenaService keeps on the player
local function describeRecord(): string
	local player = Players.LocalPlayer
	local function count(name: string): number
		local value = player:GetAttribute(name)
		return if typeof(value) == "number" then value else 0
	end
	local draws = count("PvpDraws")
	return `PvP {count("PvpWins")} - {count("PvpLosses")}{if draws > 0 then ` - {draws}` else ""}`
end

local function makeColumn(slot: number): Frame
	local column = Instance.new("Frame")
	column.Name = `Slot{slot}`
	column.LayoutOrder = slot
	column.Size = UDim2.new(1 / Party.PARTY_SIZE, -GAP * (Party.PARTY_SIZE - 1) / Party.PARTY_SIZE, 1, 0)
	column.BackgroundColor3 = UIStyle.ROW
	column.ZIndex = columns.ZIndex + 1
	column.Parent = columns
	UIKit.corner(column, 12)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = column
	return column
end

local function buildEmptyColumn(slot: number)
	local column = makeColumn(slot)
	UIKit.outline(column, UIStyle.EDGE, 2)
	local word = text(column, `Slot {slot} is empty`, UIKit.textSize("body"), UIKit.Colors.Subtext, true)
	word.AnchorPoint = Vector2.new(0.5, 0)
	word.Position = UDim2.new(0.5, 0, 0.3, 0)
	local add = UIKit.iconButton(column, "Add a card", "Cards", UIKit.Colors.Secondary)
	add.AnchorPoint = Vector2.new(0.5, 0.5)
	add.Position = UDim2.fromScale(0.5, 0.55)
	add.Size = UDim2.new(1, -8, 0, 50)
	add.TextSize = UIKit.textSize("body")
	add.ZIndex = column.ZIndex + 1
	add.Activated:Connect(function()
		panel.Visible = false
		BinderController.Open("Tap a card, then Add to party.")
	end)
end

local function buildCardColumn(slot: number, beastId: string, summoned: boolean)
	local column = makeColumn(slot)
	local beast = BinderController.GetBeasts()[beastId]
	local card = if beast then Cards.ById[beast.cardId] else nil
	if not beast or not card then
		UIKit.outline(column, UIStyle.EDGE, 2)
		text(column, `Slot {slot}`, UIKit.textSize("body"), WHITE, true)
		return
	end
	UIKit.outline(column, if summoned then UIStyle.GOOD else UIStyle.EDGE, if summoned then 4 else 2)
	local phone = UIKit.isPhone()
	local stack = Instance.new("Frame")
	stack.BackgroundTransparency = 1
	stack.Size = UDim2.new(1, 0, 1, -56)
	stack.ZIndex = column.ZIndex
	stack.Parent = column
	list(stack, false, if phone then 3 else 6)

	-- The card beside its name, grade, level, stars and Power
	local artSize = if phone then Vector2.new(40, 56) else Vector2.new(72, 100)
	local top = strip(stack, 1, artSize.Y, 8)
	CardTips.art(top, card, beast.foil, artSize).LayoutOrder = 1
	local info = Instance.new("Frame")
	info.LayoutOrder = 2
	info.BackgroundTransparency = 1
	info.Size = UDim2.new(1, -(artSize.X + 8), 1, 0)
	info.ZIndex = top.ZIndex
	info.Parent = top
	local infoList = list(info, false, 2)
	infoList.VerticalAlignment = Enum.VerticalAlignment.Center
	local name = text(info, card.name, UIKit.textSize(if phone then "body" else "name"), WHITE, true)
	name.LayoutOrder = 1
	name.AutomaticSize = Enum.AutomaticSize.None
	name.Size = UDim2.new(1, 0, 0, UIKit.textSize(if phone then "body" else "name") + 4)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local meta = strip(info, 2, 20, 4)
	UIKit.pill(meta, beast.grade, UIStyle.GRADES[beast.grade] or UIStyle.GRADES.C).Size = UDim2.fromOffset(0, 18)
	text(meta, `Lv {beast.level}`, UIKit.textSize("small"), WHITE, true).LayoutOrder = 2
	if not phone then
		UIKit.stars(info, beast.stars, Beasts.MAX_STARS, 14).LayoutOrder = 3
	end
	local power = strip(info, 4, UIKit.textSize("number") + 4, 4)
	Icon.make(power, "Power", UDim2.fromOffset(22, 22)).ZIndex = power.ZIndex + 1
	text(power, tostring(math.floor(BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade))), UIKit.textSize(if phone then "body" else "number"), UIStyle.POWER, true).LayoutOrder = 2

	-- HP, ATK, SPD against the strongest card's
	local stats = BeastRules.getStats(card, beast.foil, beast.level, beast.stars, beast.grade)
	local reference = CardTips.reference()
	for index, stat in { { "Hp", stats.hp, reference.hp }, { "Atk", stats.atk, reference.atk }, { "Spd", stats.spd, reference.spd } } do
		local row = UIKit.statRow(stack, stat[1] :: string, CompareRules.share(stat[2] :: number, stat[3] :: number))
		row.LayoutOrder = 1 + index
		if phone then -- short screens: slimmer rows so the perk still fits above the buttons
			row.Size = UDim2.new(1, 0, 0, 16)
			local picture = row:FindFirstChild("Icon") :: Frame
			picture.Size = UDim2.fromOffset(16, 16)
		end
	end

	-- The perk while summoned, then the resting line (filled by updateRest)
	local perk = PartyRules.getPerk(Party, card.element, card.rarity, beast.stars)
	local perkLine = strip(stack, 6, if phone then 26 else 36, 5)
	Icon.make(perkLine, card.element, UDim2.fromOffset(20, 20)).ZIndex = perkLine.ZIndex + 1
	local perkText = text(perkLine, if perk then PartyRules.describe(perk) else "No perk", UIKit.textSize("small"), if perk then UIStyle.HINT else UIKit.Colors.Subtext)
	perkText.LayoutOrder = 2
	perkText.AutomaticSize = Enum.AutomaticSize.None
	perkText.TextWrapped = true
	perkText.Size = UDim2.new(1, -26, 1, 0)
	local rest = text(stack, "", UIKit.textSize("small"), UIStyle.BAD, true)
	rest.LayoutOrder = 7
	rest.Visible = false
	restLabels[beastId] = rest

	-- Summon / Summoned, XP Tonic, Remove
	local buttons = Instance.new("Frame")
	buttons.AnchorPoint = Vector2.new(0, 1)
	buttons.Position = UDim2.fromScale(0, 1)
	buttons.Size = UDim2.new(1, 0, 0, 48)
	buttons.BackgroundTransparency = 1
	buttons.ZIndex = column.ZIndex
	buttons.Parent = column
	list(buttons, true, 6)
	local canTonic = tonicCount > 0 and beast.level < Beasts.MAX_LEVEL
	local small = 48
	local summon = UIKit.iconButton(buttons, if summoned then "Summoned" else "Summon", if summoned then "Check" else "Party", if summoned then UIStyle.GREEN else UIKit.Colors.Accent)
	summon.LayoutOrder = 1
	summon.Size = UDim2.new(1, -(small + 6) * (if canTonic then 2 else 1), 1, 0)
	summon.TextSize = UIKit.textSize("body")
	summon.ZIndex = buttons.ZIndex + 1
	summon.Activated:Connect(function()
		Remotes.Summon:FireServer(if summoned then nil else slot)
	end)
	if canTonic then
		local tonic = UIKit.iconButton(buttons, "", "XpTonic", UIKit.Colors.Secondary)
		tonic.LayoutOrder = 2
		tonic.Size = UDim2.fromOffset(small, small)
		tonic.ZIndex = buttons.ZIndex + 1
		local count = UIKit.pill(tonic, tostring(tonicCount), UIStyle.GOLD)
		count.AnchorPoint = Vector2.new(1, 1)
		count.Position = UDim2.new(1, 6, 1, 4)
		count.Size = UDim2.fromOffset(0, 18)
		count.ZIndex = tonic.ZIndex + 3
		tonic.Activated:Connect(function()
			Remotes.UseXpTonic:FireServer(beastId)
		end)
	end
	local remove = UIKit.iconButton(buttons, "", "Remove", UIKit.Colors.Danger)
	remove.LayoutOrder = 3
	remove.Size = UDim2.fromOffset(small, small)
	remove.ZIndex = buttons.ZIndex + 1
	remove.Activated:Connect(function()
		Remotes.SetPartySlot:FireServer(slot, nil)
	end)

	if summoned then
		local tag = UIKit.pill(column, "SUMMONED", UIStyle.GREEN, nil, "Party")
		tag.AnchorPoint = Vector2.new(0.5, 0.5)
		tag.Position = UDim2.new(0.5, 0, 0, -10)
		tag.ZIndex = column.ZIndex + 6
	end
end

-- Each column's resting countdown after fainting (nothing while it's ready)
local function updateRest()
	for beastId, label in restLabels do
		local seconds = RestTimers.GetSeconds(beastId)
		label.Visible = seconds > 0
		if seconds > 0 then
			label.Text = `Resting {RestTimers.Format(seconds)}{if RestTimers.IsNearSpring() then " · healing faster" else ""}`
		end
	end
end

-- The header chips: who is summoned, and the PvP record
local function renderChips(current: PartyState?)
	clear(chips)
	local summonedName = "Nobody summoned"
	if current and current.summoned then
		for _, entry in current.slots do
			if entry.slot == current.summoned then
				local beast = BinderController.GetBeasts()[entry.beastId]
				local card = if beast then Cards.ById[beast.cardId] else nil
				summonedName = if card then `Summoned: {card.name}` else summonedName
			end
		end
	end
	UIKit.pill(chips, summonedName, UIStyle.ROW, nil, "Party").Size = UDim2.fromOffset(0, CHIP_HEIGHT)
	local record = UIKit.pill(chips, describeRecord(), UIStyle.ROW, nil, "Pvp")
	record.Size = UDim2.fromOffset(0, CHIP_HEIGHT)
	record.LayoutOrder = 2
end

local function render()
	if not panel.Visible then
		return
	end
	clear(columns)
	restLabels = {}
	local current = state
	renderChips(current)
	if not current then
		local wait = text(columns, "Loading...", UIKit.textSize("body"), UIKit.Colors.Subtext)
		wait.LayoutOrder = 1
		return
	end
	local bySlot: { [number]: string } = {}
	for _, entry in current.slots do
		bySlot[entry.slot] = entry.beastId
	end
	for slot = 1, Party.PARTY_SIZE do
		local beastId = bySlot[slot]
		if beastId then
			buildCardColumn(slot, beastId, current.summoned == slot)
		else
			buildEmptyColumn(slot)
		end
	end
	updateRest()
end

-- Big on desktops (up to MAX_SIZE), nearly the whole screen on phones
local function layout()
	local phone = UIKit.isPhone()
	panel.Size = if phone then UDim2.fromScale(0.97, 0.98) else UDim2.fromScale(0.92, 0.86)
	local top = if phone then 10 else 18
	columns.Position = UDim2.fromOffset(12, UIKit.HEADER_HEIGHT + top)
	columns.Size = UDim2.new(1, -24, 1, -(UIKit.HEADER_HEIGHT + top + (if phone then 10 else 16)))
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = MAX_SIZE
	end
end

local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		layout()
		Remotes.RequestParty:FireServer()
		render()
	end
end

-- Opens or closes the Party panel (also from the avatar in the party bar)
function PartyController.Toggle()
	toggle()
end

function PartyController.Start()
	local screenGui = UIController.GetScreenGui()
	local scroller: ScrollingFrame
	panel, scroller = UIKit.panel(screenGui, "Party", "Party", "Party")
	scroller:Destroy() -- three columns, no scrolling
	Icon.header(panel, "Party", UIKit.HEADER_HEIGHT)

	chips = Instance.new("Frame")
	chips.Name = "Chips"
	chips.BackgroundTransparency = 1
	chips.Position = UDim2.new(0, 150, 0, (UIKit.HEADER_HEIGHT - CHIP_HEIGHT) / 2)
	chips.Size = UDim2.new(1, -220, 0, CHIP_HEIGHT)
	chips.ZIndex = panel.ZIndex + 3
	chips.Parent = panel
	list(chips, true, 6)

	columns = Instance.new("Frame")
	columns.Name = "Columns"
	columns.BackgroundTransparency = 1
	columns.Position = UDim2.fromOffset(12, UIKit.HEADER_HEIGHT + 18)
	columns.Size = UDim2.new(1, -24, 1, -(UIKit.HEADER_HEIGHT + 18 + 16))
	columns.ZIndex = panel.ZIndex + 1
	columns.Parent = panel
	list(columns, true, GAP)

	Hud.fanButton({ id = "Party", icon = "Party", label = "Party", order = 4, onClick = toggle })

	Remotes.PartyChanged.OnClientEvent:Connect(function(payload: PartyState)
		if typeof(payload) ~= "table" or typeof(payload.slots) ~= "table" then
			return
		end
		state = payload
		render()
	end)
	local sinceRest = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceRest += dt
		if sinceRest >= 0.5 and panel.Visible then
			sinceRest = 0
			updateRest()
		end
	end)
	-- Levels and stars change perks; redraw with the new binder
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		task.defer(render)
	end)
	Remotes.ItemsChanged.OnClientEvent:Connect(function(items)
		local count = if typeof(items) == "table" then items.xpTonic else nil
		tonicCount = if typeof(count) == "number" then count else 0
		if panel.Visible then
			render()
		end
	end)
	for _, name in { "PvpWins", "PvpLosses", "PvpDraws" } do
		Players.LocalPlayer:GetAttributeChangedSignal(name):Connect(function()
			if panel.Visible then
				renderChips(state)
			end
		end)
	end
	Remotes.RequestItems:FireServer() -- our own copy of the tonic count, whatever order the controllers start in
end

return PartyController
