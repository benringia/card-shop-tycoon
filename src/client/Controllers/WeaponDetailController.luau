--!strict
-- A weapon's card view (weapons round 1, Task 10; relaid out 2026-11-09, the owner's pick A: the creature card view's
-- twin; layout A of weapons round 4, owner 2026-11-25: "rearrange this UI to be easily understood"), over the binder's
-- Armory or the Forge: its card (Util/WeaponFace) on the left, and beside it its rarity / family / element pills; for a
-- weapon you have, one gold box (its Attack, and against what you hold now; its grade; its level over a gold bar); for
-- one you don't, "How to get it" (the boss that drops it, the forge materials as bars); then one short row each for
-- what it does (WeaponText.rows: its Attack range when it isn't yours, its sword skill, its perk, its element bond; the
-- Prism Blade's ALWAYS STRONG in gold and its Supers instead of a bond). Equip sits in a bar under them
-- (Remotes.EquipWeapon; the server checks it's yours and you're not fighting) with a hint that upgrades are the Forge's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Cards = require(Config:WaitForChild("Cards"))
local Combat = require(Config:WaitForChild("Combat"))
local CombatHud = require(Config:WaitForChild("CombatHud"))
local ElementNamesConfig = require(Config:WaitForChild("ElementNames"))
local Swords = require(Config:WaitForChild("Swords"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local Weapons = require(Config:WaitForChild("Weapons"))
local ElementNames = require(Shared:WaitForChild("Util"):WaitForChild("ElementNames"))
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
local BADGE = 36 -- an icon's coloured square
local PROGRESS_ROW = 24
local HOW_TO_GET_EDGE = Color3.fromRGB(196, 176, 238)
local DROP_BADGE = Color3.fromRGB(90, 62, 150)
local WHITE = Color3.new(1, 1, 1)
-- Layout A's sizes and colours (the owner's pick from the mockup, 2026-11-25)
local GOLD_BOX = 70 -- your copy: its Attack, grade and level
local GOLD_FILL = Color3.fromRGB(255, 248, 228)
local ATTACK_ICON = 38
local ATTACK_NUMBER = 36
local GRADE_BADGE = 34
local GRADE_AT = 0.4 -- the grade badge's middle across the gold box
local LEVEL_AT = 0.59 -- where the level and its bar start
local LEVEL_BAR = 9
local ROW_HEIGHT = 48 -- each thing the weapon does
local ROW_ICON = 30
local ROW_TITLE = 15
local ROW_WORDS = 12
local ROW_GAP = 5
local ROW_FILL_TRANSPARENCY = 0.6 -- the rows barely whiter than the window
local STRONG_FILL = Color3.fromRGB(255, 244, 200) -- the Prism Blade's ALWAYS STRONG row
local STRONG_EDGE = 2.5
local STRONG_INK = Color3.fromRGB(150, 98, 0) -- its title: dark gold, 4.5:1 on its fill
local PRISM_PILL = Color3.fromRGB(150, 120, 225)

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

-- A round badge `size` px in a colour with a letter on it (the grade)
local function letterBadge(parent: Instance, letter: string, color: Color3, size: number): Frame
	local circle = Instance.new("Frame")
	circle.Name = "Badge"
	circle.Size = UDim2.fromOffset(size, size)
	circle.BackgroundColor3 = color
	circle.Parent = parent
	UIKit.corner(circle, size // 2)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = math.floor(size * 0.6)
	label.TextColor3 = WHITE
	label.Text = letter
	label.Parent = circle
	UIKit.outlined(label, 1.5)
	return circle
end

-- A line of words placed at (x, y) in `parent`, `width` across (a UDim), cut short with "..." when it doesn't fit
local function placed(parent: Instance, words: string, font: Enum.Font, size: number, color: Color3, position: UDim2, width: UDim): TextLabel
	local label = UIKit.label(parent, words, font, size, color)
	label.Position = position
	label.Size = UDim2.new(width, UDim.new(0, size + 4))
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return label
end

-- One thing the weapon does (WeaponText.rows): its icon, a bold title and one short line, in a soft-edged row; the
-- Prism Blade's ALWAYS STRONG in gold
local function infoRow(parent: Instance, order: number, info: WeaponText.WindowRow)
	local strong = info.kind == "strong"
	local frame = Instance.new("Frame")
	frame.Name = `Row_{info.kind}`
	frame.LayoutOrder = order
	frame.BackgroundColor3 = if strong then STRONG_FILL else palette.row
	frame.BackgroundTransparency = if strong then 0 else ROW_FILL_TRANSPARENCY
	frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	frame.Parent = parent
	UIKit.corner(frame, 10)
	UIKit.outline(frame, if strong then UIStyle.GOLD else palette.rowEdge, if strong then STRONG_EDGE else 2)
	local picture = Icon.make(frame, info.icon, UDim2.fromOffset(ROW_ICON, ROW_ICON))
	picture.AnchorPoint = Vector2.new(0, 0.5)
	picture.Position = UDim2.new(0, 12, 0.5, 0)
	local left = 12 + ROW_ICON + 10
	local width = UDim.new(1, -(left + 8))
	placed(frame, info.title, Enum.Font.FredokaOne, ROW_TITLE, if strong then STRONG_INK else palette.ink, UDim2.fromOffset(left, 5), width)
	placed(frame, info.words, Enum.Font.GothamBold, ROW_WORDS, palette.inkSoft, UDim2.fromOffset(left, 26), width)
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

local function rarityColor(rarity: string): Color3
	local tier = (Rarities.Tiers :: any)[rarity]
	return if tier then tier.color else UIStyle.HINT
end

-- The rarity, the family and the element (the Prism Blade's "Always strong"), plain words as in the mockup
local function pills(weapon: Weapons.Weapon)
	local line = holder(rows, 1, "row", 26)
	UIKit.pill(line, weapon.rarity, rarityColor(weapon.rarity)).LayoutOrder = 1
	local family = string.upper(string.sub(weapon.family, 1, 1)) .. string.sub(weapon.family, 2)
	UIKit.pill(line, family, palette.slotEmpty).LayoutOrder = 2
	if weapon.prism then
		UIKit.pill(line, "Always strong", PRISM_PILL).LayoutOrder = 3
	elseif weapon.element then
		UIKit.pill(line, ElementNames.display(weapon.element, ElementNamesConfig), Cards.ELEMENTS[weapon.element] or palette.slotEmpty).LayoutOrder = 3
	end
end

-- Yours, one gold box (layout A): the Power fist with ATTACK over the number and, unless it's the one in your hand, how
-- it compares with that one under it; the grade on its round badge; the level over a gold bar to +10. The Steel Sword:
-- its Attack alone (no grade roll, no upgrades)
local function yourWeapon(weapon: Weapons.Weapon, record: WeaponRules.Owned, state: State)
	local section = Instance.new("Frame")
	section.Name = "YourWeapon"
	section.LayoutOrder = 2
	section.BackgroundColor3 = GOLD_FILL
	section.Size = UDim2.new(1, 0, 0, GOLD_BOX)
	section.Parent = rows
	UIKit.corner(section, 12)
	UIKit.outline(section, UIStyle.GOLD, 2)
	local fist = Icon.make(section, "Power", UDim2.fromOffset(ATTACK_ICON, ATTACK_ICON))
	fist.AnchorPoint = Vector2.new(0, 0.5)
	fist.Position = UDim2.new(0, 14, 0.5, 0)
	local left = 14 + ATTACK_ICON + 10
	-- the words stop short of the grade badge
	local width = UDim.new(GRADE_AT, -(left + GRADE_BADGE // 2 + 6))
	local power = WeaponRules.shownPower(Weapons, Combat, weapon.id, record.grade, record.level)
	local versus = WeaponText.versus(Weapons, Combat, weapon.id, record, state.equipped, state.owned[state.equipped])
	local compares = versus ~= nil and weapon.id ~= state.equipped
	-- the number sits lower when nothing goes under it (the mockup's spacing)
	placed(section, "ATTACK", Enum.Font.GothamBold, 11, palette.inkSoft, UDim2.fromOffset(left, if compares then 4 else 9), width)
	placed(section, tostring(WeaponText.attack(power)), Enum.Font.FredokaOne, ATTACK_NUMBER, palette.ink, UDim2.fromOffset(left, if compares then 15 else 25), width)
	if versus and compares then
		local color = if versus.sign > 0 then palette.good elseif versus.sign < 0 then palette.bad else palette.hint
		placed(section, versus.text, Enum.Font.GothamBold, 11, color, UDim2.fromOffset(left, 51), width)
	end
	if weapon.id == Weapons.STARTER then
		return
	end
	local gradeBadge = letterBadge(section, record.grade, UIStyle.GRADES[record.grade] or UIStyle.GRADES.C, GRADE_BADGE)
	gradeBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	gradeBadge.Position = UDim2.fromScale(GRADE_AT, 0.5)
	local grade = placed(section, "Grade", Enum.Font.GothamBold, 12, palette.inkSoft, UDim2.new(GRADE_AT, GRADE_BADGE // 2 + 7, 0.5, 0), UDim.new(LEVEL_AT - GRADE_AT, -(GRADE_BADGE // 2 + 12)))
	grade.AnchorPoint = Vector2.new(0, 0.5)
	local levelWidth = UDim.new(1 - LEVEL_AT, -34)
	placed(section, `Level +{record.level} / {Weapons.MAX_LEVEL}`, Enum.Font.FredokaOne, ROW_TITLE, palette.ink, UDim2.new(LEVEL_AT, 0, 0, 14), levelWidth)
	local track = UIKit.bar(section, record.level / Weapons.MAX_LEVEL, UIStyle.GOLD)
	track.Position = UDim2.new(LEVEL_AT, 0, 0, 40)
	track.Size = UDim2.new(levelWidth, UDim.new(0, LEVEL_BAR))
end

-- Not yours: the boss that drops it, then its forge materials as bars
local function howToGet(weapon: Weapons.Weapon, state: State)
	local how = WeaponText.howToGet(Weapons, Bosses, weapon.id)
	local cost = WeaponRules.makeCost(Weapons, weapon.id, state.owned) -- a first Forge weapon's special price shows here too
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
	layout.Padding = UDim.new(0, ROW_GAP)
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
	local blocked = WeaponRules.equipBlock(if typeof(level) == "number" then level else 0, Swords.UNLOCK_SHOP_LEVEL, Players.LocalPlayer:GetAttribute("SwordGiven") == true)
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
	for index, info in WeaponText.rows(Weapons, CombatHud, WeaponLooks, Combat, weaponId, record) do
		infoRow(rows, 2 + index, info)
	end
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
