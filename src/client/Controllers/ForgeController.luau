--!strict
-- The Forge window (weapons round 1, Task 7; owner's pick B 2026-11-06: pick on the left, the weapon big on the
-- right; relaid out 2026-11-08, the owner's pick A): tabs Forge / Upgrade / Reforge with a line saying what the tab
-- does (WeaponText.tabLine); the left lists the weapons for that tab as slim rows, the right shows the chosen one: its
-- card (Util/WeaponFace; tap it for its stats, WeaponDetailController), what it is now and what it becomes in two
-- boxes with an arrow picture between them, what it costs as picture chips (WeaponText.costChips), and one big
-- button that says what it does or what's missing (WeaponText.button). The Forge Sword is one row with its five
-- elements as buttons. The server re-checks everything (ForgeService); its result plays the reveal
-- (WeaponRevealController) with this window out of the way. Opened from your own Forge's prompt (BuildController);
-- closes when you walk away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BabyColors = require(Config:WaitForChild("BabyColors"))
local Bosses = require(Config:WaitForChild("Bosses"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local Combat = require(Config:WaitForChild("Combat"))
local ForgeLayout = require(Config:WaitForChild("ForgeLayout"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local UIIcons = require(Config:WaitForChild("UIIcons"))
local Weapons = require(Config:WaitForChild("Weapons"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local WeaponRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponRules"))
local WeaponText = require(Shared:WaitForChild("Util"):WaitForChild("WeaponText"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local WeaponFace = require(ClientUtil:WaitForChild("WeaponFace"))
local UIController = require(Controllers:WaitForChild("UIController"))
local WeaponRevealController = require(Controllers:WaitForChild("WeaponRevealController"))
local WeaponDetailController = require(Controllers:WaitForChild("WeaponDetailController"))

type Owned = WeaponRules.Owned
-- A row in the list: one weapon, or the Forge Sword's five (ids in element order)
type Entry = { key: string, name: string, rarity: string, ids: { string } }

local FORGE, UPGRADE, REFORGE = "Forge", "Upgrade", "Reforge"
local PANEL_MAX_SIZE = Vector2.new(820, 540)
local LIST_WIDTH_SCALE = 0.42
local ROW_HEIGHT = 66
local THUMBNAIL_SIZE = Vector2.new(40, 56)
local CARD_SIZE = Vector2.new(84, 120) -- the pane's card on desktops (phones: Config/ForgeLayout CARD)
local ELEMENT_BUTTON = 48 -- tap targets are 48 px or more
local ACTION_HEIGHT = 52
local EDGE = 12
local TOOLBAR_TOP = UIKit.HEADER_HEIGHT + 8
local TAB_LINE_HEIGHT = 34 -- under the tabs (desktops): what the tab does, two lines at most
local TAB_LINE_TOP = TOOLBAR_TOP + BabyColors.SEGMENTED.hit + 6
local LIST_TOP = TAB_LINE_TOP + TAB_LINE_HEIGHT + 4
local BOX_GAP = 8
local ARROW_SIZE = 36 -- the blue arrow picture between the Now and After boxes (UIIcons.Next)
local CHIP_ICON = 24
-- Phones: the tabs sit up in the header band, between the title and the close button
local PHONE_TITLE_ROOM = 150
local PHONE_CLOSE_ROOM = 66
local PHONE_LIST_TOP = UIKit.HEADER_HEIGHT + 8
local USE_DISTANCE = Weapons.FORGE_DISTANCE
local DISTANCE_CHECK_SECONDS = 0.5
local IN_FLIGHT_TIMEOUT = 3 -- a request with no answer (the server said no in a toast) unlocks the button again

local player = Players.LocalPlayer

local ForgeController = {}

local panel: Frame
local palette: UIKit.Palette
local switchHolder: Frame
local tabLine: TextLabel -- what the tab does, under the tabs on desktops (phones: the pane's first line)
local list: ScrollingFrame
local pane: ScrollingFrame
local actionBar: Frame -- under the pane: the one button stays in view on short screens
local setTab: (string) -> () = function() end
local machine: BasePart? = nil
local tab = FORGE
local selectedKey: string? = nil
local selectedElement = "Ember" -- the Forge Sword's element picked
local owned: { [string]: Owned } = {}
local items: { [string]: number } = {}
local inFlight = false
local inFlightToken = 0
local reopenAfterReveal = false
local shown: { weaponId: string, view: string }? = nil -- the pane's weapon and what it drew from the cash
local render: () -> ()

local ELEMENTS = { "Ember", "Tide", "Bloom", "Volt", "Shade" }

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function cash(): number
	local value = player:GetAttribute("Cash")
	return if typeof(value) == "number" then value else 0
end

local function shopLevel(): number
	local value = player:GetAttribute("Level")
	return if typeof(value) == "number" then value else 1
end

local function rarityOrder(rarity: string): number
	local tier = (Rarities.Tiers :: any)[rarity]
	return if tier then tier.order else 0
end

-- The rows a tab lists: Forge, every built weapon you don't have yet that can be made (each Forge weapon, the Forge
-- Sword and the Forge Spear, as one row while any element is missing; its key `forge<Family>`, its ids' prefix);
-- Upgrade and Reforge, the ones you have (not the Steel Sword)
local function entries(): { Entry }
	local found: { Entry } = {}
	local forgeIds: { [string]: { string } } = {} -- by family
	for _, weapon in Weapons.WEAPONS do
		if not weapon.ready or weapon.id == Weapons.STARTER then
			continue
		end
		local have = owned[weapon.id] ~= nil
		if weapon.source.kind == "forge" then
			if (tab == FORGE) ~= have then
				local ids = forgeIds[weapon.family] or {}
				forgeIds[weapon.family] = ids
				table.insert(ids, weapon.id)
			end
		elseif tab == FORGE and not have and WeaponRules.makeCost(Weapons, weapon.id) then
			table.insert(found, { key = weapon.id, name = weapon.name, rarity = weapon.rarity, ids = { weapon.id } })
		elseif tab ~= FORGE and have then
			table.insert(found, { key = weapon.id, name = weapon.name, rarity = weapon.rarity, ids = { weapon.id } })
		end
	end
	for family, ids in forgeIds do
		if tab == FORGE then
			local title = string.upper(string.sub(family, 1, 1)) .. string.sub(family, 2)
			table.insert(found, { key = `forge{title}`, name = `Forge {title}`, rarity = "Common", ids = ids })
		else
			for _, id in ids do
				local weapon = Weapons.ById[id]
				table.insert(found, { key = id, name = weapon.name, rarity = weapon.rarity, ids = { id } })
			end
		end
	end
	table.sort(found, function(a, b)
		if rarityOrder(a.rarity) ~= rarityOrder(b.rarity) then
			return rarityOrder(a.rarity) < rarityOrder(b.rarity)
		end
		return a.name < b.name
	end)
	return found
end

-- The weapon an entry stands for now (a Forge weapon's row: the element picked, if it's one still listed)
local function weaponOf(entry: Entry): string
	if #entry.ids == 1 then
		return entry.ids[1]
	end
	local wanted = `{entry.key}_{selectedElement}`
	return if table.find(entry.ids, wanted) then wanted else entry.ids[1]
end

local function costFor(weaponId: string): WeaponRules.Cost?
	if tab == FORGE then
		return WeaponRules.makeCost(Weapons, weaponId)
	elseif tab == REFORGE then
		return WeaponRules.reforgeCost(Weapons, weaponId)
	end
	local record = owned[weaponId]
	return if record then WeaponRules.upgradeCost(Weapons, weaponId, record.level + 1) else nil
end

-- The one button for this tab: what it does when everything's there, else what's missing (WeaponText.button)
local function buttonFor(weapon: Weapons.Weapon, record: Owned?, cost: WeaponRules.Cost?): (string, boolean)
	local action = if tab == FORGE then "forge" elseif tab == UPGRADE then "upgrade" else "reforge"
	local text, ready = WeaponText.button(action, cost, items, cash(), Items, {
		level = if record then record.level + 1 else nil,
		unlockLevel = if weapon.source.cost then weapon.source.cost.unlockLevel else nil,
		shopLevel = shopLevel(),
	})
	if tab == REFORGE and record and not WeaponRules.canReforge(record) then
		return "Already Grade S", false
	end
	return text, ready
end

-- What a weapon's pane draws from the cash (its cost lines' colours and its button): a cash change redraws the window
-- only when this changes (in a staffed shop sales land every few seconds; a redraw then could swallow a tap)
local function cashView(weaponId: string): string
	local weapon = Weapons.ById[weaponId]
	local cost = costFor(weaponId)
	if not weapon then
		return ""
	end
	local parts = {}
	if cost then
		for _, line in WeaponText.cost(cost, items, cash(), Items) do
			table.insert(parts, if line.enough then "1" else "0")
		end
	end
	local text, ready = buttonFor(weapon, owned[weaponId], cost)
	table.insert(parts, text)
	table.insert(parts, tostring(ready))
	return table.concat(parts, "|")
end

local function addLabel(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3, order: number?): TextLabel
	local label = UIKit.label(parent, text, font, size, color)
	label.TextWrapped = true
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, 0, 0, size + 4)
	if order then
		label.LayoutOrder = order
	end
	return label
end

local function buildRow(entry: Entry, order: number)
	local weaponId = weaponOf(entry)
	local record = owned[weaponId]
	local row = Instance.new("TextButton")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = palette.row
	row.Text = ""
	row.Parent = list
	UIKit.corner(row, 12)
	local selected = entry.key == selectedKey
	UIKit.outline(row, if selected then UIKit.Colors.Accent else palette.rowEdge, if selected then 3 else 2)
	local thumbnail = Instance.new("Frame")
	thumbnail.Position = UDim2.fromOffset(8, 5)
	thumbnail.Size = UDim2.fromOffset(THUMBNAIL_SIZE.X, THUMBNAIL_SIZE.Y)
	thumbnail.BackgroundTransparency = 1
	thumbnail.Parent = row
	-- The Forge tab shows what it will look like (Grade C, +0); the others, yours
	WeaponFace.render(thumbnail, nil, weaponId, record or { grade = "C", level = 0 }, nil)
	local textX = THUMBNAIL_SIZE.X + 18
	local name = UIKit.label(row, entry.name, Enum.Font.FredokaOne, 16, palette.ink)
	name.Position = UDim2.fromOffset(textX, 8)
	name.Size = UDim2.new(1, -(textX + 10), 0, 20)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local sub = if tab == FORGE then `{entry.rarity} · {WeaponText.source(Weapons, Bosses, weaponId)}`
		elseif record then `{entry.rarity} · Grade {record.grade} · +{record.level}`
		else entry.rarity
	local line = UIKit.label(row, sub, Enum.Font.GothamBold, 12, palette.inkSoft)
	line.Position = UDim2.fromOffset(textX, 30)
	line.Size = UDim2.new(1, -(textX + 10), 0, 30)
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.TextWrapped = true
	row.Activated:Connect(function()
		selectedKey = entry.key
		render()
	end)
end

-- A Forge weapon's element buttons: an emoji each, the picked one ringed, the ones you have greyed out
local function elementButtons(parent: Instance, entry: Entry, order: number)
	local holder = Instance.new("Frame")
	holder.Name = "Elements"
	holder.LayoutOrder = order
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, ELEMENT_BUTTON + 4)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Wraps = true -- a second row on a narrow phone
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	for index, element in ELEMENTS do
		local id = `{entry.key}_{element}`
		local open = table.find(entry.ids, id) ~= nil
		local look = WeaponLooks.BY_ELEMENT[element]
		local button = UIKit.button(holder, CardDesign.EMOJI[element] or element, if open then Color3.fromRGB(look.glow[1], look.glow[2], look.glow[3]) else UIKit.Colors.Locked)
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(ELEMENT_BUTTON, ELEMENT_BUTTON)
		button.TextSize = 22
		button.AutoButtonColor = open
		-- The picked one stands out bigger; the others keep the 48 px tap size
		local scale = Instance.new("UIScale")
		scale.Scale = if weaponOf(entry) == id then 1.12 else 1
		scale.Parent = button
		button.Activated:Connect(function()
			if open then
				selectedElement = element
				render()
			end
		end)
	end
end

-- A box of the before/after row: a small title, a big value, its lines (`good`: the After box, in green)
type Box = { title: string, big: string, lines: { string }, good: boolean? }

-- `compact` (phones): Config/ForgeLayout's fonts and padding, its first `lines` lines only
local function box(parent: Instance, spec: Box, order: number, width: UDim, compact: boolean)
	local frame = Instance.new("Frame")
	frame.Name = spec.title
	frame.LayoutOrder = order
	frame.BackgroundColor3 = palette.row
	frame.Size = UDim2.new(width, UDim.new(0, 0))
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = parent
	UIKit.corner(frame, 10)
	UIKit.outline(frame, if spec.good then palette.good else palette.rowEdge, 2)
	local look = ForgeLayout.BOX
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, if compact then look.pad / 2 else 6)
	padding.PaddingBottom = UDim.new(0, if compact then look.pad / 2 else 8)
	padding.PaddingLeft = UDim.new(0, if compact then look.side else 10)
	padding.PaddingRight = UDim.new(0, if compact then look.side else 10)
	padding.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, look.gap)
	layout.Parent = frame
	-- a label is its font size + 4 px tall (addLabel), so the compact fonts are ForgeLayout's heights less 4
	addLabel(frame, spec.title, Enum.Font.GothamBold, if compact then look.title - 4 else 12, palette.inkSoft, 1)
	addLabel(frame, spec.big, Enum.Font.FredokaOne, if compact then look.big - 4 else 22, if spec.good then palette.good else palette.ink, 2)
	for index, line in spec.lines do
		if compact and index > look.lines then
			break
		end
		addLabel(frame, line, Enum.Font.GothamBold, if compact then look.line - 4 else 13, if spec.good then palette.good else palette.ink, 2 + index)
	end
end

-- Two boxes side by side with the arrow picture between them, the same height; one box alone fills the row
local function compare(parent: Instance, order: number, boxes: { Box }, compact: boolean)
	local row = Instance.new("Frame")
	row.Name = "Compare"
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.ItemLineAlignment = Enum.ItemLineAlignment.Stretch
	layout.Padding = UDim.new(0, BOX_GAP)
	layout.Parent = row
	if #boxes == 1 then
		box(row, boxes[1], 1, UDim.new(1, 0), compact)
		return
	end
	local arrowSize = if compact then ARROW_SIZE * 0.7 else ARROW_SIZE
	local half = UDim.new(0.5, -(arrowSize / 2 + BOX_GAP))
	box(row, boxes[1], 1, half, compact)
	local arrow = Instance.new("ImageLabel")
	arrow.Name = "Arrow"
	arrow.LayoutOrder = 2
	arrow.BackgroundTransparency = 1
	arrow.Image = UIIcons.Next
	arrow.ScaleType = Enum.ScaleType.Fit
	arrow.Size = UDim2.fromOffset(arrowSize, arrowSize)
	arrow.Parent = row
	box(row, boxes[2], 3, half, compact)
end

-- What this tab shows: Upgrade, now and after the next level (or Awakened at +10); Reforge, the grade now and the
-- roll (or Grade S, done); Forge, what comes out
local function boxesFor(weaponId: string, weapon: Weapons.Weapon, record: Owned?): { Box }
	if tab == UPGRADE and record then
		local now = WeaponRules.shownPower(Weapons, Combat, weaponId, record.grade, record.level)
		if record.level >= Weapons.MAX_LEVEL then
			return { { title = "Fully upgraded", big = `+{record.level}`, lines = { "Awakened!", string.format("Power x%.2f", now) }, good = true } }
		end
		local after = WeaponRules.shownPower(Weapons, Combat, weaponId, record.grade, record.level + 1)
		return {
			{ title = "Now", big = `+{record.level}`, lines = { string.format("Power x%.2f", now) } },
			{
				title = "After",
				big = `+{record.level + 1}`,
				lines = { string.format("Power x%.2f", after), WeaponText.ladderStep(WeaponLooks, record.level + 1, weapon.rarity) },
				good = true,
			},
		}
	elseif tab == REFORGE and record then
		if not WeaponRules.canReforge(record) then
			return { { title = "Grade S", big = "S", lines = { "The best grade: nothing to reforge" }, good = true } }
		end
		return {
			{ title = "Now", big = `Grade {record.grade}`, lines = { "its grade today" } },
			{ title = "After", big = "C to S", lines = { "you keep the better" }, good = true },
		}
	end
	return { { title = "You get", big = "Grade C to S", lines = { "a random grade, at +0" }, good = true } }
end

-- The cost as chips: the cash or item picture and its words, green when you have enough, red when not (wrapping)
local function costChips(parent: Instance, order: number, cost: WeaponRules.Cost)
	local holder = Instance.new("Frame")
	holder.Name = "Costs"
	holder.LayoutOrder = order
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Wraps = true
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = holder
	for index, chip in WeaponText.costChips(cost, items, cash(), Items) do
		local color = if chip.enough then palette.good else palette.bad
		local frame = Instance.new("Frame")
		frame.Name = "Chip"
		frame.LayoutOrder = index
		frame.BackgroundColor3 = palette.row
		frame.AutomaticSize = Enum.AutomaticSize.XY
		frame.Size = UDim2.fromOffset(0, CHIP_ICON)
		frame.Parent = holder
		UIKit.corner(frame, 10)
		UIKit.outline(frame, color, 2)
		local padding = Instance.new("UIPadding")
		padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 5), UDim.new(0, 5)
		padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 8), UDim.new(0, 10)
		padding.Parent = frame
		local inner = Instance.new("UIListLayout")
		inner.FillDirection = Enum.FillDirection.Horizontal
		inner.VerticalAlignment = Enum.VerticalAlignment.Center
		inner.SortOrder = Enum.SortOrder.LayoutOrder
		inner.Padding = UDim.new(0, 6)
		inner.Parent = frame
		if chip.icon ~= "" then
			local picture = Icon.make(frame, chip.icon, UDim2.fromOffset(CHIP_ICON, CHIP_ICON))
			picture.LayoutOrder = 1
		end
		local label = UIKit.label(frame, chip.text, Enum.Font.GothamBold, 14, color)
		label.LayoutOrder = 2
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, CHIP_ICON)
	end
end

local function renderPane(entry: Entry?)
	clear(pane)
	clear(actionBar)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = pane
	local phone = UIKit.isPhone()
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, if phone then 6 else 10)
	padding.PaddingBottom = UDim.new(0, if phone then 6 else 10)
	padding.PaddingLeft = UDim.new(0, EDGE)
	padding.PaddingRight = UDim.new(0, EDGE)
	padding.Parent = pane
	if not entry then
		shown = nil
		local message = if tab == FORGE then "You have every weapon you can make. Upgrade them!"
			else "No weapons yet. Forge one, or win one from a boss."
		addLabel(pane, message, Enum.Font.GothamBold, 15, palette.inkSoft, 1)
		return
	end
	local weaponId = weaponOf(entry)
	local weapon = Weapons.ById[weaponId]
	local record = owned[weaponId]
	local cost = costFor(weaponId)

	local hasElements = tab == FORGE and (#entry.ids > 1 or weapon.source.kind == "forge")
	local done = tab == REFORGE and record ~= nil and not WeaponRules.canReforge(record) -- nothing to pay for
	local cardSize = if phone then Vector2.new(ForgeLayout.CARD.w, ForgeLayout.CARD.h) else CARD_SIZE
	local besideX = cardSize.X + (if phone then 8 else 12)

	-- The header: its card (tap it for its stats) and beside it, on desktops its name, grade and level, rarity and
	-- element; on phones (short screens: Config/ForgeLayout; the list's row already names it) the Now / After boxes,
	-- or a Forge weapon's element buttons
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.LayoutOrder = 1
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, 0, 0, cardSize.Y)
	top.AutomaticSize = Enum.AutomaticSize.Y
	top.Parent = pane
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(cardSize.X, cardSize.Y)
	card.BackgroundTransparency = 1
	card.Parent = top
	WeaponFace.render(card, nil, weaponId, record or (if tab == FORGE then { grade = "C", level = 0 } else nil), nil)
	local openCard = Instance.new("TextButton")
	openCard.Name = "OpenCard"
	openCard.Text = ""
	openCard.BackgroundTransparency = 1
	openCard.Size = UDim2.fromScale(1, 1)
	openCard.ZIndex = card.ZIndex + 10
	openCard.Parent = card
	openCard.Activated:Connect(function()
		WeaponDetailController.Open(weaponId)
	end)
	local beside = Instance.new("Frame")
	beside.BackgroundTransparency = 1
	beside.Position = UDim2.fromOffset(besideX, 0)
	beside.Size = UDim2.new(1, -besideX, 0, 0)
	beside.AutomaticSize = Enum.AutomaticSize.Y
	beside.Parent = top
	if phone then
		if hasElements then
			elementButtons(beside, entry, 1)
		else
			compare(beside, 1, boxesFor(weaponId, weapon, record), true)
		end
	else
		local wordsLayout = Instance.new("UIListLayout")
		wordsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		wordsLayout.Padding = UDim.new(0, 4)
		wordsLayout.Parent = beside
		addLabel(beside, weapon.name, Enum.Font.FredokaOne, 20, palette.ink, 1)
		local gradeLine = if tab == FORGE then "Grade C to S · +0" elseif record then `Grade {record.grade} · +{record.level}` else nil
		if gradeLine then
			addLabel(beside, gradeLine, Enum.Font.FredokaOne, 15, palette.ink, 2)
		end
		local kind = if weapon.prism then `{weapon.rarity} · every element` elseif weapon.element then `{weapon.rarity} · {weapon.element}` else weapon.rarity
		addLabel(beside, kind, Enum.Font.GothamBold, 13, palette.inkSoft, 3)
		addLabel(beside, "Tap the card for its stats", Enum.Font.GothamBold, 11, palette.hint, 4)
		-- a Forge weapon's element first, then what it is now and what it becomes
		if hasElements then
			elementButtons(pane, entry, 2)
			addLabel(pane, "Pick its element: it bonds with creatures of that element.", Enum.Font.GothamBold, 12, palette.hint, 3)
		end
		compare(pane, 4, boxesFor(weaponId, weapon, record), false)
	end

	-- What it costs: a picture chip each, green when you have enough, red when not
	if cost and not done then
		if not phone then
			addLabel(pane, "You pay", Enum.Font.FredokaOne, 15, palette.ink, 5)
		end
		costChips(pane, 6, cost)
	end
	-- Phones: what the tab does last, under the fold if need be
	if phone then
		addLabel(pane, WeaponText.tabLine(tab), Enum.Font.GothamBold, 12, palette.hint, 20)
	end

	-- The one button
	local text, ready = buttonFor(weapon, record, cost)
	shown = { weaponId = weaponId, view = cashView(weaponId) }
	local canPress = ready and not inFlight
	local button = UIKit.button(actionBar, if inFlight then "Working..." else text, if canPress then UIKit.Colors.Accent else UIKit.Colors.Locked)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.Size = UDim2.new(1, -2 * EDGE, 0, ACTION_HEIGHT)
	button.TextSize = 17
	button.AutoButtonColor = canPress
	button.Activated:Connect(function()
		local part = machine
		if not canPress or inFlight or not part then
			return
		end
		inFlight = true
		inFlightToken += 1
		local token = inFlightToken
		task.delay(IN_FLIGHT_TIMEOUT, function()
			if token == inFlightToken and inFlight then
				inFlight = false
				render()
			end
		end)
		local remote = if tab == FORGE then Remotes.ForgeWeapon elseif tab == UPGRADE then Remotes.UpgradeWeapon else Remotes.ReforgeWeapon
		remote:FireServer(part:GetAttribute("ShelfUid"), weaponId)
		render()
	end)
end

render = function()
	if not panel.Visible then
		return
	end
	clear(list)
	setTab(tab)
	tabLine.Text = WeaponText.tabLine(tab)
	local found = entries()
	local selected: Entry? = nil
	for _, entry in found do
		if entry.key == selectedKey then
			selected = entry
		end
	end
	selected = selected or found[1]
	selectedKey = if selected then selected.key else nil
	for order, entry in found do
		buildRow(entry, order)
	end
	if #found == 0 then
		local empty = UIKit.label(list, if tab == FORGE then "Nothing left to forge." else "No weapons yet.", Enum.Font.GothamBold, 15, palette.inkSoft)
		empty.Size = UDim2.new(1, -10, 0, 40)
	end
	renderPane(selected)
end

local function close()
	panel.Visible = false
	machine = nil
end

-- Opens the window for your own Forge
-- Desktops: the tabs under the header. Phones (short screens): nearly the whole screen, the tabs up in the header
-- band, so the weapon, its cost and its button keep the room.
local function layout()
	local phone = UIKit.isPhone()
	panel.Size = if phone then UDim2.fromScale(0.97, 0.96) else UDim2.fromScale(0.94, 0.86)
	local listTop = if phone then PHONE_LIST_TOP else LIST_TOP
	if phone then
		switchHolder.Position = UDim2.fromOffset(PHONE_TITLE_ROOM, (UIKit.HEADER_HEIGHT - BabyColors.SEGMENTED.hit) / 2)
		switchHolder.Size = UDim2.new(1, -(PHONE_TITLE_ROOM + PHONE_CLOSE_ROOM), 0, BabyColors.SEGMENTED.hit)
	else
		switchHolder.Position = UDim2.fromOffset(16, TOOLBAR_TOP)
		switchHolder.Size = UDim2.new(1, -32, 0, BabyColors.SEGMENTED.hit)
	end
	tabLine.Visible = not phone -- phones: the pane's first line
	tabLine.Position = UDim2.fromOffset(16, TAB_LINE_TOP)
	tabLine.Size = UDim2.new(1, -32, 0, TAB_LINE_HEIGHT)
	list.Position = UDim2.fromOffset(12, listTop)
	list.Size = UDim2.new(LIST_WIDTH_SCALE, -18, 1, -(listTop + 12))
	pane.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 0, listTop)
	pane.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 1, -(listTop + 12 + ACTION_HEIGHT + 16))
end

function ForgeController.Open(part: BasePart)
	machine = part
	inFlight = false
	layout()
	panel.Visible = true
	Remotes.WeaponsChanged:FireServer() -- the latest weapons (rate-limited on the server)
	render()
end

-- Closes once the owner walks away or the machine is moved or sold
local function watchDistance()
	while true do
		task.wait(DISTANCE_CHECK_SECONDS)
		local part = machine
		if part and panel.Visible then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not part:IsDescendantOf(workspace) or not root or (root.Position - part.Position).Magnitude > USE_DISTANCE then
				close()
			end
		end
	end
end

-- A result: the window steps aside for the reveal and comes back after it while you're still at the Forge
local function onResult()
	inFlight = false
	if not panel.Visible then
		return
	end
	reopenAfterReveal = true -- before hiding: the Visible handler keeps the machine for the reopen
	panel.Visible = false
	task.spawn(function()
		task.wait(0.5) -- the reveal queues on the same event
		while WeaponRevealController.IsPlaying() do
			task.wait(0.25)
		end
		local part = machine
		if reopenAfterReveal and part and part:IsDescendantOf(workspace) then
			reopenAfterReveal = false
			panel.Visible = true
			render()
		end
	end)
end

function ForgeController.Start()
	local screenGui = UIController.GetScreenGui()
	panel, list = UIKit.panel(screenGui, "Forge", "⚒️ Forge")
	palette = UIKit.colorsFor(panel)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	switchHolder = Instance.new("Frame")
	switchHolder.Name = "Tabs"
	switchHolder.BackgroundTransparency = 1
	switchHolder.ZIndex = panel.ZIndex + 3 -- over the header band and its title on phones
	switchHolder.Parent = panel
	local _, pick = UIKit.segmented(switchHolder, { FORGE, UPGRADE, REFORGE }, function(value)
		tab = value
		selectedKey = nil
		render()
	end)
	setTab = pick
	tabLine = UIKit.label(panel, "", Enum.Font.GothamBold, 13, palette.hint)
	tabLine.Name = "TabLine"
	tabLine.TextWrapped = true
	tabLine.TextYAlignment = Enum.TextYAlignment.Top

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingLeft = UDim.new(0, 6)
	listPadding.PaddingRight = UDim.new(0, EDGE + 6)
	listPadding.PaddingTop = UDim.new(0, 6)
	listPadding.PaddingBottom = UDim.new(0, 6)
	listPadding.Parent = list

	pane = Instance.new("ScrollingFrame")
	pane.Name = "Details"
	pane.BackgroundColor3 = palette.slotEmpty
	pane.BorderSizePixel = 0
	pane.ScrollBarThickness = 4
	pane.CanvasSize = UDim2.new()
	pane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pane.Parent = panel
	UIKit.corner(pane, 12)
	actionBar = Instance.new("Frame")
	actionBar.Name = "Action"
	actionBar.BackgroundTransparency = 1
	actionBar.AnchorPoint = Vector2.new(0, 1)
	actionBar.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 1, -8)
	actionBar.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 0, ACTION_HEIGHT + 8)
	actionBar.Parent = panel

	Remotes.WeaponsChanged.OnClientEvent:Connect(function(state: unknown)
		if typeof(state) == "table" and typeof((state :: any).owned) == "table" then
			owned = (state :: any).owned
			render()
		end
	end)
	Remotes.ItemsChanged.OnClientEvent:Connect(function(newItems: unknown)
		if typeof(newItems) == "table" then
			items = newItems :: any
			render()
		end
	end)
	Remotes.RequestItems:FireServer() -- our own copy of the Bag's counts, whatever order the controllers start in
	Remotes.ForgeResult.OnClientEvent:Connect(onResult)
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		local current = shown
		if panel.Visible and current and cashView(current.weaponId) ~= current.view then
			render()
		end
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible and not reopenAfterReveal then
			machine = nil
		end
	end)
	task.spawn(watchDistance)
end

return ForgeController
