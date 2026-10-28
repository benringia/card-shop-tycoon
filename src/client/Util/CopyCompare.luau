--!strict
-- The swap comparison a kid reads at a glance (spec 2026-10-29-collection-screens-ui-design.md 4.3): a big
-- STRONGER / WEAKER verdict, the two cards (IN with a green border -> OUT faded), three rows of paired bars for HP,
-- ATK and SPD where the longer green bar wins (hover a bar for its number), and one line for the element and perk.
-- Rules: Util/CompareRules (Lune-tested).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local CompareRules = require(Shared:WaitForChild("Util"):WaitForChild("CompareRules"))

local ClientUtil = script.Parent :: Instance
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CardTips = require(ClientUtil:WaitForChild("CardTips"))

type Card = typeof(Cards.List[1])
export type Side = {
	card: Card,
	foil: boolean,
	power: number,
	stats: { hp: number, atk: number, spd: number },
	perk: string?,
}

local WHITE = Color3.new(1, 1, 1)
local LOSER = Color3.fromRGB(74, 82, 104)
local SAME = Color3.fromRGB(110, 118, 140)

local CopyCompare = {}

local function label(parent: Instance, value: string, size: number, color: Color3): TextLabel
	local text = UIKit.label(parent, value, Enum.Font.FredokaOne, size, color)
	text.TextWrapped = false
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromOffset(0, size + 4)
	text.ZIndex = (parent :: GuiObject).ZIndex + 1
	UIKit.outlined(text, 2)
	return text
end

local function hRow(parent: Instance, order: number, height: number, gap: number): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, height)
	row.ZIndex = (parent :: GuiObject).ZIndex
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	return row
end

-- One side of a paired bar: grows from the middle outwards (the left one right-to-left); hovering shows the number
local function halfBar(parent: Instance, order: number, share: number, wins: boolean, fromRight: boolean, value: number)
	local track, fill = UIKit.bar(parent, share, if wins then nil else LOSER)
	track.LayoutOrder = order
	track.Size = UDim2.new(0.5, -22, 0, track.Size.Y.Offset + 4)
	if fromRight then
		fill.AnchorPoint = Vector2.new(1, 0)
		fill.Position = UDim2.fromScale(1, 0)
	end
	local number = UIKit.label(track, tostring(math.floor(value)), Enum.Font.FredokaOne, UIKit.textSize("small"), WHITE)
	number.Size = UDim2.fromScale(1, 1)
	number.TextXAlignment = Enum.TextXAlignment.Center
	number.ZIndex = track.ZIndex + 2
	number.Visible = false
	UIKit.outlined(number, 1.5)
	track.MouseEnter:Connect(function()
		number.Visible = true
	end)
	track.MouseLeave:Connect(function()
		number.Visible = false
	end)
end

-- Fills `holder` (its old content goes) with the comparison of `incoming` replacing `outgoing`
function CopyCompare.build(holder: Frame, incoming: Side, outgoing: Side)
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local phone = UIKit.isPhone()
	-- One column; phones (short) get two side by side: the verdict and cards left, the bars and perk right
	local function column(position: UDim2, size: UDim2): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Position = position
		frame.Size = size
		frame.ZIndex = holder.ZIndex
		frame.Parent = holder
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, if phone then 4 else 6)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = if phone then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top
		list.Parent = frame
		return frame
	end
	local top = if phone then column(UDim2.new(), UDim2.fromScale(0.42, 1)) else column(UDim2.new(), UDim2.fromScale(1, 1))
	local bottom = if phone then column(UDim2.fromScale(0.42, 0), UDim2.fromScale(0.58, 1)) else top

	-- The verdict badge
	local kind = CompareRules.verdict(incoming.power, outgoing.power)
	local badge = UIKit.pill(
		hRow(top, 1, if phone then 32 else 40, 0),
		CompareRules.verdictText(incoming.power, outgoing.power),
		if kind == "stronger" then UIStyle.GREEN elseif kind == "weaker" then UIStyle.RED else SAME,
		nil,
		if kind == "stronger" then "Check" elseif kind == "weaker" then "Remove" else nil
	)
	badge.Size = UDim2.fromOffset(0, if phone then 28 else 36)
	badge.TextSize = UIKit.textSize(if phone then "body" else "name")

	-- IN -> OUT
	local artSize = if phone then Vector2.new(44, 62) else Vector2.new(62, 88)
	local pair = hRow(top, 2, artSize.Y + 24, if phone then 6 else 14)
	local function side(order: number, card: Side, tag: string, inside: boolean)
		local column = Instance.new("Frame")
		column.LayoutOrder = order
		column.BackgroundTransparency = 1
		column.Size = UDim2.fromOffset(artSize.X + 20, artSize.Y + 24)
		column.ZIndex = pair.ZIndex
		column.Parent = pair
		local art = CardTips.art(column, card.card, card.foil, artSize)
		art.AnchorPoint = Vector2.new(0.5, 0)
		art.Position = UDim2.fromScale(0.5, 0)
		local edge = art:FindFirstChildOfClass("UIStroke") :: UIStroke
		edge.Color = if inside then UIStyle.GOOD else LOSER
		edge.Thickness = 3
		if not inside then
			-- Faded: a dark veil over the card leaving
			local veil = Instance.new("Frame")
			veil.Name = "Veil"
			veil.Size = UDim2.fromScale(1, 1)
			veil.BackgroundColor3 = UIStyle.EDGE
			veil.BackgroundTransparency = 0.45
			veil.ZIndex = art.ZIndex + 20
			veil.Parent = art
			UIKit.corner(veil, 8)
		end
		local chip = UIKit.pill(column, tag, if inside then UIStyle.GREEN else LOSER)
		chip.AnchorPoint = Vector2.new(0.5, 1)
		chip.Position = UDim2.fromScale(0.5, 1)
		chip.Size = UDim2.fromOffset(0, 20)
	end
	side(1, incoming, "IN", true)
	local arrow = Icon.make(pair, "Next", UDim2.fromOffset(30, 30))
	arrow.LayoutOrder = 2
	arrow.ZIndex = pair.ZIndex + 1
	side(3, outgoing, "OUT", false)

	-- HP, ATK, SPD: paired bars
	for index, stat in { { "Hp", "hp" }, { "Atk", "atk" }, { "Spd", "spd" } } do
		local row = hRow(bottom, 2 + index, 24, 6)
		local inValue = (incoming.stats :: any)[stat[2]] :: number
		local outValue = (outgoing.stats :: any)[stat[2]] :: number
		local inShare, outShare, winner = CompareRules.pair(inValue, outValue)
		halfBar(row, 1, inShare, winner == "in", true, inValue)
		local picture = Icon.make(row, stat[1], UDim2.fromOffset(24, 24))
		picture.LayoutOrder = 2
		picture.ZIndex = row.ZIndex + 1
		halfBar(row, 3, outShare, winner == "out", false, outValue)
	end

	-- One line: the elements, then the perk
	local line = hRow(bottom, 6, 24, 5)
	Icon.make(line, incoming.card.element, UDim2.fromOffset(22, 22)).LayoutOrder = 1
	if incoming.card.element ~= outgoing.card.element then
		local word = UIKit.label(line, "replaces", Enum.Font.Gotham, UIKit.textSize("small"), UIKit.Colors.Subtext)
		word.LayoutOrder = 2
		word.AutomaticSize = Enum.AutomaticSize.X
		word.Size = UDim2.fromOffset(0, 20)
		Icon.make(line, outgoing.card.element, UDim2.fromOffset(22, 22)).LayoutOrder = 3
	end
	local perkText = if incoming.perk then `perk: {incoming.perk}` elseif outgoing.perk then "you lose its perk" else "no perk"
	local perkColor = if incoming.perk then UIStyle.HINT else UIStyle.BAD
	if not phone then
		label(line, `· {perkText}`, UIKit.textSize("small"), perkColor).LayoutOrder = 4
		return
	end
	-- Phones: the perk on its own wrapped line under the elements
	local perk = label(bottom, perkText, UIKit.textSize("small"), perkColor)
	perk.LayoutOrder = 7
	perk.AutomaticSize = Enum.AutomaticSize.None
	perk.TextWrapped = true
	perk.TextXAlignment = Enum.TextXAlignment.Center
	perk.Size = UDim2.new(1, 0, 0, 2 * UIKit.textSize("small") + 6)
end

return CopyCompare
