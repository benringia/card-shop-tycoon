--!strict
-- A weapon's card view (weapons round 1, Task 10; relaid out 2026-11-09, the owner's pick A: the creature card view's
-- twin), over the binder's Armory or the Forge: its card (Util/WeaponFace) on the left, and beside it its rarity /
-- family / element pills; for a weapon you have, a gold "Your weapon" box (Power against what you hold now, grade,
-- level); for one you don't, "How to get it" (the boss that drops it, the forge materials as bars); then its sword
-- skill, its perk and its element bond (or its Power range) with their icons. Equip sits in a bar under them
-- (Remotes.EquipWeapon; the server checks it's yours and you're not fighting) with a hint that upgrades are the Forge's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Cards = require(Config:WaitForChild("Cards"))
local Combat = require(Config:WaitForChild("Combat"))
local CombatHud = require(Config:WaitForChild("CombatHud"))
local Swords = require(Config:WaitForChild("Swords"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local Weapons = require(Config:WaitForChild("Weapons"))
local WeaponLookRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponLookRules"))
local WeaponRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponRules"))
local WeaponText = require(Shared:WaitForChild("Util"):WaitForChild("WeaponText"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local Icon = require(ClientUtil:WaitForChild("Icon"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local WeaponFace = require(ClientUtil:WaitForChild("WeaponFace"))
local UIController = require(Controllers:WaitForChild("UIController"))

export type State = { owned: { [string]: WeaponRules.Owned }, equipped: string, items: { [string]: number } }

local WeaponDetailController = {}

local Z_INDEX = 8 -- over the binder, like the rarity guide
local CARD_HEIGHT = 250 -- at most; shorter windows (phones) get a smaller card so Equip stays in view
local MIN_CARD_HEIGHT = 140
local CARD_ASPECT = 0.7
local NOTE_HEIGHT = 34 -- under the card: where it came from
local MAX_SIZE = Vector2.new(760, 460)
local DESKTOP_SCALE, PHONE_SCALE = Vector2.new(0.86, 0.82), Vector2.new(0.97, 0.96)
local BAR_HEIGHT = 54 -- Equip and the Forge hint, under the scrolling side
local GAP = 8
local BADGE = 36 -- an icon's coloured square
local TILE_HEIGHT = 58
local FACT_HEIGHT = 62
local PROGRESS_ROW = 24
local HOW_TO_GET_EDGE = Color3.fromRGB(196, 176, 238)
local SKILL_BADGE = Color3.fromRGB(122, 92, 200)
local PERK_BADGE = Color3.fromRGB(255, 132, 170)
local DROP_BADGE = Color3.fromRGB(90, 62, 150)
local POWER_BADGE = Color3.fromRGB(255, 205, 96)
local WHITE = Color3.new(1, 1, 1)

local panel: Frame? = nil
local row: Frame
local cardFrame: Frame
local cardStroke: UIStroke
local cardNote: TextLabel
local side: Frame
local rows: ScrollingFrame
local bar: Frame
local equip: TextButton
local note: TextLabel
local titleIcon: Frame
local palette: UIKit.Palette
local current: string? = nil
local getState: () -> State = function()
	return { owned = {}, equipped = Weapons.STARTER, items = {} }
end

local function cash(): number
	local value = Players.LocalPlayer:GetAttribute("Cash")
	return if typeof(value) == "number" then value else 0
end

local function text(parent: Instance, value: string, size: number, color: Color3, bold: boolean?): TextLabel
	local label = UIKit.label(parent, value, if bold then Enum.Font.FredokaOne else Enum.Font.GothamBold, size, color)
	label.Size = UDim2.new(1, 0, 0, size + 4)
	return label
end

-- A frame laid out by `layout`: "column" (rows stacked, grows to fit) or "row" (left to right, fixed height)
local function holder(parent: Instance, order: number, layout: "column" | "row", height: number?): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height or 0)
	if layout == "column" then
		frame.AutomaticSize = Enum.AutomaticSize.Y
	end
	frame.Parent = parent
	local list = Instance.new("UIListLayout")
	list.FillDirection = if layout == "row" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	list.VerticalAlignment = if layout == "row" then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, if layout == "row" then 6 else 4)
	list.Parent = frame
	return frame
end

-- A rounded box with an edge colour, padded, its rows stacked (the card view's section boxes)
local function box(parent: Instance, order: number, edge: Color3): Frame
	local frame = holder(parent, order, "column")
	frame.BackgroundTransparency = 0
	frame.BackgroundColor3 = palette.row
	UIKit.corner(frame, 12)
	UIKit.outline(frame, edge, 3)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	padding.Parent = frame
	return frame
end

local function heading(parent: Instance, order: number, words: string, color: Color3?)
	local label = text(parent, string.upper(words), UIKit.textSize("small"), color or palette.hint, true)
	label.LayoutOrder = order
end

-- An icon on a coloured square
local function badge(parent: Instance, icon: string, color: Color3, size: number): Frame
	local square = Instance.new("Frame")
	square.Name = "Badge"
	square.Size = UDim2.fromOffset(size, size)
	square.BackgroundColor3 = color
	square.Parent = parent
	UIKit.corner(square, 10)
	local picture = Icon.make(square, icon, UDim2.fromOffset(size * 0.72, size * 0.72))
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	return square
end

-- A badge, a small heading and words beside it (the skill, the perk, the bond, the drop); grows with its words
local function ability(parent: Instance, order: number, icon: string, color: Color3, title: string, name: string?, words: string): Frame
	local line = Instance.new("Frame")
	line.LayoutOrder = order
	line.BackgroundTransparency = 1
	line.Size = UDim2.new(1, 0, 0, BADGE)
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.Parent = parent
	badge(line, icon, color, BADGE)
	local column = holder(line, 0, "column")
	column.Position = UDim2.fromOffset(BADGE + 9, 0)
	column.Size = UDim2.new(1, -(BADGE + 9), 0, 0)
	local list = column:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	list.Padding = UDim.new(0, 1)
	if title ~= "" then
		heading(column, 1, title)
	end
	if name then
		text(column, name, UIKit.textSize("body") + 1, palette.ink, true).LayoutOrder = 2
	end
	local detail = text(column, words, UIKit.textSize("small"), if name then palette.inkSoft else palette.ink)
	detail.LayoutOrder = 3
	detail.AutomaticSize = Enum.AutomaticSize.Y
	detail.Size = UDim2.new(1, 0, 0, 0)
	return line
end

-- A round badge in a colour with a letter on it (the grade)
local function letterBadge(parent: Instance, letter: string, color: Color3): Frame
	local circle = Instance.new("Frame")
	circle.Name = "Badge"
	circle.AnchorPoint = Vector2.new(0, 0.5)
	circle.Position = UDim2.new(0, 7, 0.5, 0)
	circle.Size = UDim2.fromOffset(28, 28)
	circle.BackgroundColor3 = color
	circle.Parent = parent
	UIKit.corner(circle, 14)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 18
	label.TextColor3 = WHITE
	label.Text = letter
	label.Parent = circle
	UIKit.outlined(label, 1.5)
	return circle
end

-- One stat tile in the gold box: an icon (or `letter` on a round badge of `badgeColor`), a small heading, the value,
-- and an optional line under it
local function tile(parent: Instance, order: number, grow: number, icon: string?, title: string, value: string, under: string?, underColor: Color3?, badgeColor: Color3?): Frame
	local cell = Instance.new("Frame")
	cell.LayoutOrder = order
	cell.BackgroundColor3 = palette.slotEmpty
	cell.Size = UDim2.new(grow, -6, 0, TILE_HEIGHT)
	cell.Parent = parent
	UIKit.corner(cell, 10)
	UIKit.outline(cell, palette.rowEdge, 2)
	local left = 8
	if badgeColor then
		letterBadge(cell, value, badgeColor)
		left = 41
	elseif icon then
		local picture = Icon.make(cell, icon, UDim2.fromOffset(28, 28))
		picture.AnchorPoint = Vector2.new(0, 0.5)
		picture.Position = UDim2.new(0, 7, 0.5, 0)
		left = 41
	end
	local column = holder(cell, 0, "column")
	column.Position = UDim2.fromOffset(left, 5)
	column.Size = UDim2.new(1, -(left + 6), 0, 0)
	local list = column:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	list.Padding = UDim.new(0, 0)
	heading(column, 1, title)
	local big = text(column, value, UIKit.textSize("name") - 2, palette.ink, true)
	big.LayoutOrder = 2
	big.TextTruncate = Enum.TextTruncate.AtEnd
	if under then
		local small = text(column, under, UIKit.textSize("small") - 2, underColor or palette.hint, true)
		small.LayoutOrder = 3
		small.TextTruncate = Enum.TextTruncate.AtEnd
	end
	return cell
end

-- A material's (or the cash's) progress: icon, name, a bar, have/need
local function progressRow(parent: Instance, order: number, line: WeaponText.Progress)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, PROGRESS_ROW)
	frame.Parent = parent
	if line.icon ~= "" then
		local picture = Icon.make(frame, line.icon, UDim2.fromOffset(22, 22))
		picture.AnchorPoint = Vector2.new(0, 0.5)
		picture.Position = UDim2.fromScale(0, 0.5)
	end
	local name = text(frame, line.name, UIKit.textSize("small"), palette.ink, true)
	name.AnchorPoint = Vector2.new(0, 0.5)
	name.Position = UDim2.new(0, 28, 0.5, 0)
	name.Size = UDim2.new(0.34, -28, 1, 0)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local enough = line.have >= line.need
	local track = UIKit.bar(frame, line.have / math.max(line.need, 1), if enough then palette.good else nil)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0.34, 4, 0.5, 0)
	track.Size = UDim2.new(0.66, -82, 0, track.Size.Y.Offset)
	local count = text(frame, line.text, UIKit.textSize("small"), if enough then palette.good else palette.ink, true)
	count.AnchorPoint = Vector2.new(1, 0.5)
	count.Position = UDim2.new(1, 0, 0.5, 0)
	count.Size = UDim2.new(0, 72, 1, 0)
	count.TextXAlignment = Enum.TextXAlignment.Right
end

-- Small facts side by side (the perk, the bond; the Power range for a weapon you don't have)
local function facts(parent: Instance, order: number, list: { { icon: string, color: Color3, title: string, words: string } })
	if #list == 0 then
		return
	end
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = parent
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(if #list == 1 then 1 else 0.5, if #list == 1 then 0 else -4, 0, FACT_HEIGHT)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = frame
	for index, fact in list do
		local cell = box(frame, index, palette.rowEdge)
		cell.AutomaticSize = Enum.AutomaticSize.None
		local line = ability(cell, 1, fact.icon, fact.color, fact.title, nil, fact.words)
		line.AutomaticSize = Enum.AutomaticSize.None
		line.Size = UDim2.fromScale(1, 1)
	end
end

local function rarityColor(rarity: string): Color3
	local tier = (Rarities.Tiers :: any)[rarity]
	return if tier then tier.color else UIStyle.HINT
end

local function pills(weapon: Weapons.Weapon)
	local line = holder(rows, 1, "row", 26)
	UIKit.pill(line, weapon.rarity, rarityColor(weapon.rarity), nil, "Crown").LayoutOrder = 1
	local family = string.upper(string.sub(weapon.family, 1, 1)) .. string.sub(weapon.family, 2)
	UIKit.pill(line, family, palette.slotEmpty, nil, WeaponLookRules.familyIcon(WeaponLooks, weapon.family)).LayoutOrder = 2
	if weapon.prism then
		UIKit.pill(line, "Every element", palette.slotEmpty, nil, "Elements").LayoutOrder = 3
	elseif weapon.element then
		UIKit.pill(line, weapon.element, Cards.ELEMENTS[weapon.element] or palette.slotEmpty, nil, weapon.element).LayoutOrder = 3
	end
end

-- Yours: Power (against what you hold now), grade, level with a bar to +10
local function yourWeapon(weapon: Weapons.Weapon, record: WeaponRules.Owned, state: State)
	local section = box(rows, 2, UIStyle.GOLD)
	heading(section, 0, "Your weapon")
	local tiles = holder(section, 1, "row", TILE_HEIGHT)
	local power = WeaponRules.shownPower(Weapons, Combat, weapon.id, record.grade, record.level)
	local versus = WeaponText.versus(Weapons, Combat, weapon.id, record, state.equipped, state.owned[state.equipped])
	local underColor = if versus and versus.sign > 0 then palette.good elseif versus and versus.sign < 0 then palette.bad else palette.hint
	tile(tiles, 1, 0.44, "Power", "Power", string.format("x%.2f", power), if versus then versus.text else nil, underColor)
	if weapon.id == Weapons.STARTER then
		return -- everyone's sword: no grade roll, no upgrades
	end
	tile(tiles, 2, 0.22, nil, "Grade", record.grade, nil, nil, UIStyle.GRADES[record.grade] or UIStyle.GRADES.C)
	local levelTile = tile(tiles, 3, 0.34, "Upgrade", "Level", `+{record.level} / {Weapons.MAX_LEVEL}`)
	local track = UIKit.bar(levelTile, record.level / Weapons.MAX_LEVEL, UIStyle.GOLD)
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.new(0, 41, 1, -7)
	track.Size = UDim2.new(1, -49, 0, 8)
end

-- Not yours: the boss that drops it, then its forge materials as bars
local function howToGet(weapon: Weapons.Weapon, state: State)
	local how = WeaponText.howToGet(Weapons, Bosses, weapon.id)
	local cost = WeaponRules.makeCost(Weapons, weapon.id)
	if not how.drop and not (how.forge and cost) then
		return
	end
	local section = box(rows, 2, HOW_TO_GET_EDGE)
	heading(section, 0, "How to get it")
	if how.drop then
		ability(section, 1, "Skull", DROP_BADGE, "", nil, how.drop)
	end
	if how.forge and cost then
		text(section, how.forge, UIKit.textSize("small"), palette.inkSoft, true).LayoutOrder = 2
		for index, line in WeaponText.progress(cost, state.items, cash(), Items) do
			progressRow(section, 2 + index, line)
		end
	end
end

local function clearRows()
	for _, child in rows:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function build(): Frame
	local frame, scroll = UIKit.panel(UIController.GetScreenGui(), "WeaponDetail", "Weapon")
	frame:SetAttribute("Overlay", true) -- opens over the binder (or the Forge) without closing it
	frame.ZIndex = Z_INDEX
	frame.Active = true -- taps on it never reach the window under it (the Forge's Upgrade button)
	local limit = frame:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = MAX_SIZE
	end
	palette = UIKit.colorsFor(frame)
	titleIcon = Icon.header(frame, "Sword", UIKit.HEADER_HEIGHT)
	row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Parent = scroll
	cardFrame = Instance.new("Frame")
	cardFrame.Name = "Card"
	cardFrame.BackgroundTransparency = 1
	cardFrame.Parent = row
	cardStroke = Instance.new("UIStroke")
	cardStroke.Transparency = 1
	cardStroke.Parent = cardFrame
	cardNote = UIKit.label(row, "", Enum.Font.GothamBold, UIKit.textSize("small") - 1, palette.hint)
	cardNote.Name = "Source"
	cardNote.TextXAlignment = Enum.TextXAlignment.Center
	cardNote.TextYAlignment = Enum.TextYAlignment.Top
	side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.Parent = row
	-- The facts scroll when they don't fit (a short phone), so the bar under them always shows
	rows = Instance.new("ScrollingFrame")
	rows.Name = "Facts"
	rows.BackgroundTransparency = 1
	rows.BorderSizePixel = 0
	rows.ScrollBarThickness = 4
	rows.ScrollBarImageColor3 = palette.hint
	rows.CanvasSize = UDim2.new()
	rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rows.Size = UDim2.new(1, 0, 1, -BAR_HEIGHT)
	rows.Parent = side
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = rows
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 3), UDim.new(0, 3)
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 3), UDim.new(0, 8) -- the boxes' outlines and the scroll bar
	padding.Parent = rows
	bar = Instance.new("Frame")
	bar.Name = "Actions"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	bar.Size = UDim2.new(1, 0, 0, BAR_HEIGHT - 6)
	bar.Parent = side
	equip = UIKit.button(bar, "Equip", UIKit.Colors.Success)
	equip.Size = UDim2.new(0.5, -6, 0, 48) -- tap targets are 48 px or more
	note = UIKit.label(bar, "", Enum.Font.GothamBold, UIKit.textSize("small"), palette.inkSoft)
	note.Name = "Hint"
	note.AnchorPoint = Vector2.new(1, 0.5)
	note.Position = UDim2.fromScale(1, 0.5)
	note.TextYAlignment = Enum.TextYAlignment.Center
	equip.Activated:Connect(function()
		if current then
			Remotes.EquipWeapon:FireServer(current)
		end
	end)
	return frame
end

-- The bar under the facts, for a weapon you have: Equip (ready, once swords are unlocked) and a hint beside it, or the
-- hint alone. A weapon you don't have gets no bar (How to get it says where it comes from): the facts take its room.
local function renderBar(weapon: Weapons.Weapon, mine: boolean, equipped: boolean)
	bar.Visible = mine
	rows.Size = if mine then UDim2.new(1, 0, 1, -BAR_HEIGHT) else UDim2.fromScale(1, 1)
	local level = Players.LocalPlayer:GetAttribute("Level")
	local blocked = WeaponRules.equipBlock(if typeof(level) == "number" then level else 0, Swords.UNLOCK_SHOP_LEVEL)
	equip.Visible = mine and weapon.ready and blocked == nil
	equip.Text = if equipped then "Equipped" else "Equip"
	equip.Active = not equipped
	equip.AutoButtonColor = not equipped
	local hint = if blocked and mine then blocked
		elseif mine and weapon.id ~= Weapons.STARTER then "Upgrade and reforge it at the Forge in your shop."
		else ""
	note.Text = hint
	note.Visible = hint ~= ""
	note.Size = if equip.Visible then UDim2.new(0.5, -6, 1, 0) else UDim2.fromScale(1, 1)
	note.TextXAlignment = if equip.Visible then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
end

-- Redraws the open card from the latest state (an equip, an upgrade, new materials)
function WeaponDetailController.Refresh()
	local frame = panel
	local weaponId = current
	if not frame or not frame.Visible or not weaponId then
		return
	end
	local weapon = Weapons.ById[weaponId]
	if not weapon then
		return
	end
	local state = getState()
	local record = state.owned[weaponId] or (if weaponId == Weapons.STARTER then { grade = "C", level = 0 } else nil)
	local mine = record ~= nil
	local have, need = WeaponRules.makeProgress(Weapons, weaponId, state.items)
	local progress = if have and need then { have = have, need = need } else nil
	WeaponFace.render(cardFrame, cardStroke, weaponId, state.owned[weaponId], progress)
	local title = frame:FindFirstChild("Title", true)
	if title and title:IsA("TextLabel") then
		title.Text = weapon.name
	end
	Icon.set(titleIcon, WeaponLookRules.familyIcon(WeaponLooks, weapon.family))
	cardNote.Text = if mine then WeaponText.source(Weapons, Bosses, weaponId) else ""

	clearRows()
	pills(weapon)
	if record then
		yourWeapon(weapon, record, state)
	else
		howToGet(weapon, state)
	end
	local skill = WeaponText.skill(CombatHud, Weapons, weaponId)
	local skillBox = box(rows, 3, palette.rowEdge)
	ability(skillBox, 1, skill.icon, SKILL_BADGE, "Skill", skill.name, skill.text)
	local list = {}
	if not record then
		table.insert(list, { icon = "Power", color = POWER_BADGE, title = "Power", words = WeaponText.powerRange(Weapons, Combat, weaponId) })
	end
	local perk = WeaponRules.perk(Weapons, weaponId, if record then record.grade else "C")
	if perk then
		local words = WeaponText.stats(Weapons, weaponId, record, Combat)
		for _, stat in words do
			if stat.label == "Perk" then
				table.insert(list, { icon = WeaponLookRules.perkIcon(WeaponLooks, perk), color = PERK_BADGE, title = "Perk", words = stat.value })
			end
		end
	end
	local bond = WeaponText.bond(Weapons, weaponId)
	if bond then
		local tint = if weapon.element then (Cards.ELEMENTS[weapon.element] or palette.slotEmpty):Lerp(WHITE, 0.6) else palette.slotEmpty
		table.insert(list, { icon = if weapon.prism then "Elements" else weapon.element :: string, color = tint, title = "Bond", words = bond })
	end
	facts(rows, 4, list)
	renderBar(weapon, mine, state.equipped == weaponId)
end

function WeaponDetailController.IsOpen(): boolean
	return panel ~= nil and (panel :: Frame).Visible
end

-- Sized for this screen: nearly all of a phone's, and the card as tall as the window leaves room for (from the screen's
-- size, not the window's, which is still popping in)
local function fit(frame: Frame)
	local phone = UIKit.isPhone()
	local scale = if phone then PHONE_SCALE else DESKTOP_SCALE
	frame.Size = UDim2.fromScale(scale.X, scale.Y)
	local screen = UIController.GetScreenGui().AbsoluteSize
	local windowHeight = math.min(screen.Y * scale.Y, MAX_SIZE.Y)
	local room = windowHeight - (UIKit.HEADER_HEIGHT + 24) - 12
	local height = math.clamp(room - NOTE_HEIGHT, MIN_CARD_HEIGHT, CARD_HEIGHT)
	local width = height * CARD_ASPECT
	row.Size = UDim2.new(1, -8, 0, math.max(room, height))
	cardFrame.Size = UDim2.fromOffset(width, height)
	cardNote.Position = UDim2.fromOffset(0, height + 6)
	cardNote.Size = UDim2.fromOffset(width, NOTE_HEIGHT)
	side.Position = UDim2.fromOffset(width + 16, 0)
	side.Size = UDim2.new(1, -(width + 16), 1, 0)
end

function WeaponDetailController.Open(weaponId: string)
	if not Weapons.ById[weaponId] then
		return
	end
	local frame = panel
	if not frame then
		frame = build()
		panel = frame
	end
	current = weaponId
	fit(frame)
	frame.Visible = true
	WeaponDetailController.Refresh()
end

function WeaponDetailController.Close()
	if panel then
		(panel :: Frame).Visible = false
	end
	current = nil
end

-- The binder hands in where the owned weapons, the equipped one and the Bag's counts come from
function WeaponDetailController.SetSource(source: () -> State)
	getState = source
end

return WeaponDetailController
