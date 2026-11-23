--!strict
-- Party panel (spec 2026-10-29-collection-screens-ui-design.md 4.4; trading cards, owner 2026-11-23 pick A of
-- artifact VSged5WBCtnhC9mcjegfiu): your 3 party cards side by side, no scrolling. Each column is a card: its painting
-- across the top with the grade, level, stars and element over it, then the name and Power, Health / Attack / Speed
-- with their names, bars and numbers, the perks it gives (in town while summoned, and in fights) in a cream box, how
-- far it is to its next level, a resting timer after fainting, and Summon (or the green Summoned, which unsummons), XP
-- Tonic (with how many you hold) and a small Remove. The summoned card's column glows green with a SUMMONED tag. The
-- header shows the party's Power and your PvP record. Every icon has a word tooltip (Util/Tooltip: hover, or hold a
-- finger on it). One card is summoned at a time: it follows you around and its perk works. Cards are added from the
-- binder card view. The server sends PartyChanged on every change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Beasts = require(Config:WaitForChild("Beasts"))
local CardArt = require(Config:WaitForChild("CardArt"))
local Cards = require(Config:WaitForChild("Cards"))
local Items = require(Config:WaitForChild("Items"))
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
local Tooltip = require(ClientUtil:WaitForChild("Tooltip"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type PartyState = {
	slots: { { slot: number, beastId: string } },
	summoned: number?,
	perk: { kind: string, value: number, text: string }?,
}

local MAX_SIZE = Vector2.new(780, 500)
local GAP = 8
local CHIP_HEIGHT = 28
-- The card's parts (px): its painting's height (a computer, a short window, a phone), a stat line's height and the
-- room for its name and number, the perk box, the XP bar's colour and the shade under the painting's stars
local ART_HEIGHT = { full = 112, slim = 70, phone = 50 }
local STAT_HEIGHT = { full = 18, slim = 15, phone = 13 }
local STAT_NAME_WIDTH = 46
local STAT_NUMBER_WIDTH = 34
local STAT_NAMES: { [string]: string } = { Hp = "Health", Atk = "Attack", Spd = "Speed" }
local PERK_HEIGHT = { full = 44, slim = 36 }
local XP_FILL = Color3.fromRGB(169, 139, 243)
local ART_BACK = Color3.fromRGB(43, 33, 64)
local ART_SHADE = Color3.fromRGB(20, 12, 36)
-- A window shorter than this uses the phone's slim cards too: between UIKit.PHONE_HEIGHT and here the full card was
-- 16 px taller than its column, so a three-line perk ran under the Summon button (found 2026-11-19)
local TIGHT_HEIGHT = 560

-- Whether the party cards use the slim (phone) layout: a phone, or a desktop window too short for the full card
local function slim(): boolean
	local camera = workspace.CurrentCamera
	return UIKit.isPhone() or (camera ~= nil and camera.ViewportSize.Y < TIGHT_HEIGHT)
end

local PartyController = {}

local panel: Frame
local palette: UIKit.Palette -- the cream window's colours (UIKit.colorsFor), set in Start
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
	if bold and UIKit.themeOf(parent) ~= "cream" then
		UIKit.outlined(label, 2) -- outlined light text on dark windows; cream windows' brown text needs none
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
	column.BackgroundColor3 = palette.row
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
	UIKit.outline(column, palette.rowEdge, 2)
	local word = text(column, `Slot {slot} is empty`, UIKit.textSize("body"), UIKit.Colors.Subtext, true)
	-- its bottom just over the button's top (the button: 50 tall, centred at 55%), so a short phone's column never
	-- puts the button over the words (owner 2026-11-17: "make sure nothing is cutoff/overlapping")
	word.AnchorPoint = Vector2.new(0.5, 1)
	word.Position = UDim2.new(0.5, 0, 0.55, -25 - 6)
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

-- 1982 -> "1,982"
local function commas(value: number): string
	local grouped = string.reverse((string.gsub(string.reverse(tostring(math.floor(value))), "(%d%d%d)", "%1,")))
	return (string.gsub(grouped, "^,", ""))
end

type Beast = { cardId: string, foil: boolean, level: number, xp: number?, stars: number, grade: string }
type Card = typeof(Cards.List[1])
type Perk = PartyRules.Perk

-- The card's painting across the column's top, its grade and level over the top corners, its stars and element along
-- the bottom (a phone's slim card leaves the stars to the card view)
local function artBanner(parent: Instance, card: Card, beast: Beast, height: number, phone: boolean)
	local banner = Instance.new("Frame")
	banner.Name = "Art"
	banner.LayoutOrder = 1
	banner.Size = UDim2.new(1, 0, 0, height)
	banner.BackgroundColor3 = ART_BACK
	banner.ClipsDescendants = true
	banner.ZIndex = (parent :: GuiObject).ZIndex
	banner.Parent = parent
	UIKit.corner(banner, 10)
	local picture = Instance.new("ImageLabel")
	picture.Name = "Painting"
	picture.BackgroundTransparency = 1
	picture.Size = UDim2.fromScale(1, 1)
	picture.ScaleType = Enum.ScaleType.Crop
	picture.Image = CardArt.SMALL[card.name] or CardArt.FULL[card.name] or ""
	picture.ZIndex = banner.ZIndex + 1
	picture.Parent = banner
	-- a soft dark fade along the bottom, so the stars and the element read on any painting
	local fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.AnchorPoint = Vector2.new(0, 1)
	fade.Position = UDim2.fromScale(0, 1)
	fade.Size = UDim2.fromScale(1, 0.45)
	fade.BackgroundColor3 = ART_SHADE
	fade.BorderSizePixel = 0
	fade.ZIndex = banner.ZIndex + 2
	fade.Parent = banner
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new(1, 0.3)
	gradient.Parent = fade
	local grade = UIKit.pill(banner, beast.grade, UIStyle.GRADES[beast.grade] or UIStyle.GRADES.C)
	grade.Position = UDim2.fromOffset(6, 6)
	grade.Size = UDim2.fromOffset(0, 22)
	grade.ZIndex = banner.ZIndex + 3
	Tooltip.attach(grade, CardTips.gradeText(beast.grade))
	local level = UIKit.pill(banner, `Lv {beast.level}`, Color3.new(1, 1, 1))
	level.AnchorPoint = Vector2.new(1, 0)
	level.Position = UDim2.new(1, -6, 0, 6)
	level.Size = UDim2.fromOffset(0, 22)
	level.ZIndex = banner.ZIndex + 3
	if not phone then
		local stars = UIKit.stars(banner, beast.stars, Beasts.MAX_STARS, 15)
		stars.AnchorPoint = Vector2.new(0, 1)
		stars.Position = UDim2.new(0, 8, 1, -6)
		stars.ZIndex = banner.ZIndex + 3
		for _, star in stars:GetChildren() do
			if star:IsA("GuiObject") then
				star.ZIndex = stars.ZIndex
			end
		end
		Tooltip.icon(stars, "Star")
	end
	local element = Icon.make(banner, card.element, UDim2.fromOffset(24, 24))
	element.AnchorPoint = Vector2.new(1, 1)
	element.Position = UDim2.new(1, -6, 1, -5)
	element.ZIndex = banner.ZIndex + 3
	Tooltip.icon(element, card.element)
end

-- One stat: its icon and name, a bar `share` full against the strongest card's, and its number
local function statLine(parent: Instance, order: number, icon: string, value: number, share: number, height: number)
	local row = Instance.new("Frame")
	row.Name = "Stat" .. icon
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, height)
	row.ZIndex = (parent :: GuiObject).ZIndex
	row.Parent = parent
	local picture = Icon.make(row, icon, UDim2.fromOffset(height, height))
	picture.ZIndex = row.ZIndex + 1
	Tooltip.icon(picture, icon)
	local size = UIKit.textSize("small")
	local name = UIKit.label(row, STAT_NAMES[icon] or icon, Enum.Font.GothamBold, size, UIKit.Colors.Subtext)
	name.Position = UDim2.fromOffset(height + 5, 0)
	name.Size = UDim2.new(0, STAT_NAME_WIDTH, 1, 0)
	name.TextWrapped = false
	name.ZIndex = row.ZIndex + 1
	local number = UIKit.label(row, commas(value), Enum.Font.GothamBold, size, palette.ink)
	number.AnchorPoint = Vector2.new(1, 0)
	number.Position = UDim2.fromScale(1, 0)
	number.Size = UDim2.new(0, STAT_NUMBER_WIDTH, 1, 0)
	number.TextXAlignment = Enum.TextXAlignment.Right
	number.TextWrapped = false
	number.ZIndex = row.ZIndex + 1
	local left = height + 5 + STAT_NAME_WIDTH + 2
	local track = UIKit.bar(row, share)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, left, 0.5, 0)
	track.Size = UDim2.new(1, -(left + STAT_NUMBER_WIDTH + 6), 0, math.min(track.Size.Y.Offset, height - 6))
	track.ZIndex = row.ZIndex + 1
end

-- The perks in a cream box: what it does in town while summoned (its element's icon), and in fights (the sword)
local function perkBox(parent: Instance, order: number, card: Card, perk: Perk?, fightPerk: Perk?, height: number)
	local box = Instance.new("Frame")
	box.Name = "Perks"
	box.LayoutOrder = order
	box.BackgroundColor3 = palette.slotEmpty
	box.Size = UDim2.new(1, 0, 0, height)
	box.ZIndex = (parent :: GuiObject).ZIndex
	box.Parent = parent
	UIKit.corner(box, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = box
	local layout = list(box, false, 2)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local lines: { { icon: string, words: string, tip: string } } = {
		{
			icon = card.element,
			words = if perk then PartyRules.effect(perk) else "No perk",
			tip = if perk then `While summoned: {PartyRules.describe(perk)}` else "This card gives no perk",
		},
	}
	if fightPerk then
		table.insert(lines, { icon = "Atk", words = PartyRules.fightEffect(fightPerk), tip = `In fights: {PartyRules.describeFight(fightPerk)}` })
	end
	for index, entry in lines do
		local line = Instance.new("Frame")
		line.Name = "Perk" .. index
		line.LayoutOrder = index
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, 0, 1 / #lines, -2)
		line.ZIndex = box.ZIndex + 1
		line.Parent = box
		local icon = Icon.make(line, entry.icon, UDim2.fromOffset(16, 16))
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.fromScale(0, 0.5)
		icon.ZIndex = line.ZIndex + 1
		local words = UIKit.label(line, entry.words, Enum.Font.GothamBold, UIKit.textSize("small"), if perk then palette.hint else UIKit.Colors.Subtext)
		words.Position = UDim2.fromOffset(22, 0)
		words.Size = UDim2.new(1, -22, 1, 0)
		words.TextWrapped = false
		words.TextScaled = true -- a long perk shrinks to fit, never cut off
		words.ZIndex = line.ZIndex + 1
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = UIKit.textSize("small")
		limit.MinTextSize = 9
		limit.Parent = words
		Tooltip.attach(line, entry.tip)
	end
end

-- How far it is to its next level (Max level at the top)
local function xpLine(parent: Instance, order: number, beast: Beast)
	local row = Instance.new("Frame")
	row.Name = "Xp"
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 14)
	row.ZIndex = (parent :: GuiObject).ZIndex
	row.Parent = parent
	local atMax = beast.level >= Beasts.MAX_LEVEL
	local label = UIKit.label(row, if atMax then "Max level" else `XP to Lv {beast.level + 1}`, Enum.Font.GothamBold, UIKit.textSize("small") - 2, UIKit.Colors.Subtext)
	label.Size = UDim2.new(0, 76, 1, 0)
	label.TextWrapped = false
	label.ZIndex = row.ZIndex + 1
	local share = if atMax then 1 else BeastRules.levelProgress(beast.level, beast.xp or 0)
	local track = UIKit.bar(row, share, XP_FILL)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 80, 0.5, 0)
	track.Size = UDim2.new(1, -80, 0, 8)
	track.ZIndex = row.ZIndex + 1
	Tooltip.attach(row, if atMax then "This card is at its highest level." else `{math.floor(share * 100)}% of the way to level {beast.level + 1}`)
end

local function buildCardColumn(slot: number, beastId: string, summoned: boolean)
	local column = makeColumn(slot)
	local beast = BinderController.GetBeasts()[beastId]
	local card = if beast then Cards.ById[beast.cardId] else nil
	if not beast or not card then
		UIKit.outline(column, palette.rowEdge, 2)
		text(column, `Slot {slot}`, UIKit.textSize("body"), palette.ink, true)
		return
	end
	UIKit.outline(column, if summoned then palette.good else palette.rowEdge, if summoned then 4 else 2)
	local phone = slim()
	local tiny = UIKit.isPhone()
	local gap = if phone then 3 else 6
	local stack = Instance.new("Frame")
	stack.BackgroundTransparency = 1
	stack.Size = UDim2.new(1, 0, 1, -56)
	stack.ZIndex = column.ZIndex
	stack.Parent = column
	list(stack, false, gap)
	local artHeight = if tiny then ART_HEIGHT.phone elseif phone then ART_HEIGHT.slim else ART_HEIGHT.full
	local nameSize = UIKit.textSize(if phone then "body" else "name")
	local statHeight = if tiny then STAT_HEIGHT.phone elseif phone then STAT_HEIGHT.slim else STAT_HEIGHT.full
	local perkHeight = if phone then PERK_HEIGHT.slim else PERK_HEIGHT.full
	-- A phone's card shows the stat lines only where they fit over the buttons (found 2026-11-19: a Galaxy A06's column
	-- leaves 96 px there, and the perk hid under the buttons; checked 2026-11-23: an iPhone 17 Pro's has room for them,
	-- and without them a band stood empty). Power sums them up and the card view has them either way.
	local statsFit = not tiny or stack.AbsoluteSize.Y >= artHeight + (nameSize + 6) + 3 * statHeight + perkHeight + 5 * gap

	-- The painting with its grade, level, stars and element, then the name and Power
	artBanner(stack, card, beast, artHeight, tiny)
	local nameRow = Instance.new("Frame")
	nameRow.Name = "NameRow"
	nameRow.LayoutOrder = 2
	nameRow.BackgroundTransparency = 1
	nameRow.Size = UDim2.new(1, 0, 0, nameSize + 6)
	nameRow.ZIndex = stack.ZIndex
	nameRow.Parent = stack
	local power = Instance.new("Frame")
	power.Name = "Power"
	power.AnchorPoint = Vector2.new(1, 0)
	power.Position = UDim2.fromScale(1, 0)
	power.Size = UDim2.fromScale(0, 1)
	power.AutomaticSize = Enum.AutomaticSize.X
	power.BackgroundTransparency = 1
	power.ZIndex = nameRow.ZIndex
	power.Parent = nameRow
	list(power, true, 3)
	local powerIcon = Icon.make(power, "Power", UDim2.fromOffset(nameSize, nameSize))
	powerIcon.ZIndex = power.ZIndex + 1
	Tooltip.icon(powerIcon, "Power")
	text(power, commas(math.floor(BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade))), nameSize, palette.power, true).LayoutOrder = 2
	local name = text(nameRow, card.name, nameSize, palette.ink, true)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.Size = UDim2.new(1, -(nameSize * 4 + 12), 1, 0)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	-- Health, Attack, Speed: each named, a bar against the strongest card's, and its number
	local stats = BeastRules.getStats(card, beast.foil, beast.level, beast.stars, beast.grade)
	local reference = CardTips.reference()
	local bars: { { any } } = if statsFit then { { "Hp", stats.hp, reference.hp }, { "Atk", stats.atk, reference.atk }, { "Spd", stats.spd, reference.spd } } else {}
	for index, stat in bars do
		statLine(stack, 2 + index, stat[1] :: string, stat[2] :: number, CompareRules.share(stat[2] :: number, stat[3] :: number), statHeight)
	end

	-- The perks it gives, in town while summoned and in fights; the resting line (filled by updateRest); its next level
	local perk = PartyRules.getPerk(Party, card.element, card.rarity, beast.stars)
	local fightPerk = PartyRules.getFightPerk(Party, card.element, card.rarity, beast.stars)
	perkBox(stack, 6, card, perk, fightPerk, perkHeight)
	if not phone then
		xpLine(stack, 8, beast)
	end
	local rest = text(stack, "", UIKit.textSize("small"), palette.bad, true)
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
	local removeWidth = 40 -- Remove is the quiet one: a narrow neutral (sky) button, not the big pink one
	local summon = UIKit.iconButton(buttons, if summoned then "Summoned" else "Summon", if summoned then "Check" else "Party", if summoned then UIStyle.GREEN else UIKit.Colors.Accent)
	summon.LayoutOrder = 1
	summon.Size = UDim2.new(1, -(removeWidth + 6) - (if canTonic then small + 6 else 0), 1, 0)
	summon.TextSize = UIKit.textSize("body")
	summon.ZIndex = buttons.ZIndex + 1
	summon.Activated:Connect(function()
		Remotes.Summon:FireServer(if summoned then nil else slot)
	end)
	if canTonic then
		local tonic = UIKit.iconButton(buttons, "", "XpTonic", UIKit.Colors.Secondary)
		tonic.LayoutOrder = 2
		tonic.Size = UDim2.fromOffset(small, small)
		tonic.ZIndex = buttons.ZIndex + 2 -- above Remove, so the count badge poking out isn't hidden under it
		local tonicInfo = Items.ITEMS.xpTonic
		Tooltip.attach(tonic, `{tonicInfo.name}: {tonicInfo.description}`)
		-- How many you hold: a badge on the top right corner
		local count = UIKit.pill(tonic, tostring(tonicCount), UIStyle.GOLD)
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, 6, 0, -6)
		count.Size = UDim2.fromOffset(0, 18)
		count.ZIndex = tonic.ZIndex + 3
		tonic.Activated:Connect(function()
			Remotes.UseXpTonic:FireServer(beastId)
		end)
	end
	local remove = UIKit.iconButton(buttons, "", "Remove", palette.row)
	remove.LayoutOrder = 3
	remove.Size = UDim2.fromOffset(removeWidth, small)
	remove.ZIndex = buttons.ZIndex + 1
	Tooltip.icon(remove, "Remove")
	remove.Activated:Connect(function()
		Remotes.SetPartySlot:FireServer(slot, nil)
	end)

	if summoned then
		local tag = UIKit.pill(column, "SUMMONED", UIStyle.GREEN, nil, "Party")
		-- on a phone the name sits right under the column's top edge: the tag goes to the right corner, clear of it
		tag.AnchorPoint = if tiny then Vector2.new(1, 0.5) else Vector2.new(0.5, 0.5)
		tag.Position = if tiny then UDim2.new(1, 4, 0, -10) else UDim2.new(0.5, 0, 0, -10)
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

-- The header chips: the party's Power (its cards' together; the column with the SUMMONED tag shows who is out) and
-- the PvP record
local function renderChips(current: PartyState?)
	clear(chips)
	local total = 0
	for _, entry in if current then current.slots else {} do
		local beast = BinderController.GetBeasts()[entry.beastId]
		local card = if beast then Cards.ById[beast.cardId] else nil
		if beast and card then
			total += math.floor(BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade))
		end
	end
	local power = UIKit.pill(chips, `Party Power {commas(total)}`, palette.row, nil, "Power")
	power.Size = UDim2.fromOffset(0, CHIP_HEIGHT)
	Tooltip.attach(power, "Your party's cards' Power together")
	local record = UIKit.pill(chips, describeRecord(), palette.row, nil, "Pvp")
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
	local bottom = if phone then 6 else 12
	-- the stats are named on each card, so no legend under them: the cards take the whole height
	columns.Position = UDim2.fromOffset(12, UIKit.HEADER_HEIGHT + top)
	columns.Size = UDim2.new(1, -24, 1, -(UIKit.HEADER_HEIGHT + top + bottom))
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

-- The party's cards by slot (1-3), as the party bar numbers them: the fight's 1-3 keys (BattleController)
function PartyController.GetSlots(): { [number]: string }
	local out = {}
	for _, entry in (if state then state.slots else {}) do
		out[entry.slot] = entry.beastId
	end
	return out
end

-- The summoned slot (nil: none out)
function PartyController.GetSummoned(): number?
	return if state then state.summoned else nil
end

function PartyController.Start()
	local screenGui = UIController.GetScreenGui()
	local scroller: ScrollingFrame
	panel, scroller = UIKit.panel(screenGui, "Party", "Party", "Party")
	palette = UIKit.colorsFor(panel)
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

	-- a Phone app everywhere: on a computer the Phone shows only in town (the party bar's Party button opens it
	-- elsewhere); on a phone it shows everywhere (owner 2026-11-13: Bag and Bosses live in it too)
	Hud.fanButton({ id = "Party", icon = "Party", label = "Party", order = 4, everywhere = true, onClick = toggle })

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
