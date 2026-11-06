--!strict
-- The boss board (HUD tile "Bosses"; spec 2026-10-29-collection-screens-ui-design.md 4.7, reworked in round 5: spec
-- 2026-11-04-round5-design section 5, owner pick A "List and detail, like the Condenser"). Left: the ladder
-- (Config/Bosses) top to bottom, one row per boss: a disc with its icon in its state's ring (BossRules.stepState: gold
-- beaten, green ready, red too weak, grey locked), "N. Name" and a status chip (phones: a small badge on the disc),
-- "Next" on the first boss still to beat. Right: the chosen boss. A banner in its element's baby colour
-- (BossRules.bannerColor) with a big disc, its name, title and status; its element, where it lives and the element to
-- bring; two columns: To fight it (a checklist: shop level, its key fragments, the Power it's built for; then its tricks,
-- BossRules.watchOut) and Rewards (when full loot is ready again, what each win can drop with its odds, shrunk by the
-- soft cap and the over-power rule as the server rolls them, the first-win and daily chests, cash and XP, full-drop
-- wins left today); and a footer always in view: what to do next (BossRules.nextStep) with its button, and "Take me
-- there" (its gate here, BossTravel) or the way to its place. Icons have tooltips (items: what they do and their odds).
-- Data comes from BossService (BossesChanged); the loot timer counts down here between updates.
-- Also: the leader of a group forming at a gate sees "Start now" on its group prompt.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Cards = require(Config:WaitForChild("Cards"))
local Combat = require(Config:WaitForChild("Combat"))
local Items = require(Config:WaitForChild("Items"))
local Weapons = require(Config:WaitForChild("Weapons"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local BabyColors = require(Config:WaitForChild("BabyColors"))
local WildConfig = require(Config:WaitForChild("Wild"))
local FrontierConfig = require(Config:WaitForChild("Frontier"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local BossRules = require(Shared:WaitForChild("Util"):WaitForChild("BossRules"))
local ItemRules = require(Shared:WaitForChild("Util"):WaitForChild("ItemRules"))
local WeaponRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponRules"))
local SoftColors = require(Shared:WaitForChild("Util"):WaitForChild("SoftColors"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local BossTints = require(ClientUtil:WaitForChild("BossTints"))
local Tooltip = require(ClientUtil:WaitForChild("Tooltip"))
local WeaponFace = require(ClientUtil:WaitForChild("WeaponFace"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))
local PartyController = require(Controllers:WaitForChild("PartyController"))

type BossState = { unlocked: boolean, cleared: boolean, lootIn: number, rewardedToday: number, fragments: number, bonusReady: boolean, weaponPity: number? }
type StepState = "beaten" | "ready" | "tooWeak" | "locked"
type Mark = "ok" | "no" | "warn"
type Line = string | { text: string, color: Color3 }

local MAX_SIZE = Vector2.new(900, 600)
local LOCKED_FADE = 0.55
local LIST_WIDTH = 270 -- the bosses' list on the left (phones: PHONE_LIST_WIDTH)
local PHONE_LIST_WIDTH = 168
local ROW_HEIGHT = 52 -- a boss's row (phones: a tap target, PHONE_ROW_HEIGHT)
local PHONE_ROW_HEIGHT = 48
local DISC_SIZE = 38
local BANNER_HEIGHT = 92 -- the chosen boss's banner (phones: PHONE_BANNER_HEIGHT)
local PHONE_BANNER_HEIGHT = 64
local GAP = 8
local STEP_BADGES: { [StepState]: string? } = { beaten = "Trophy", ready = "Check", locked = "Lock" }
local STEP_WORDS: { [StepState]: string } = { beaten = "Beaten", ready = "Ready", tooWeak = "Too weak", locked = "Locked" }
local STATUS_ICONS: { [StepState]: string } = { beaten = "Trophy", ready = "Check", tooWeak = "Power", locked = "Lock" }
local STATUS_FILLS: { [StepState]: Color3 } = { beaten = UIStyle.GOLD, ready = UIStyle.GREEN, tooWeak = UIStyle.RED, locked = UIStyle.PANEL }
local TRICK_ICONS: { [string]: string } = { phases = "Gem", shield = "Lock", thunderclap = "Volt", adds = "Customer", heal = "Heart", enrage = "Angry" }
local DROP_SIZE = 46
local WEAPON_CARD = 112 -- the boss's weapon card's height in Rewards (phones: PHONE_WEAPON_CARD)
local PHONE_WEAPON_CARD = 88
local PHONE_DROP_SIZE = 38
local CHEST_SIZE = 32

local BossBoardController = {}

local panel: Frame
local palette: UIKit.Palette -- the cream window's colours (UIKit.colorsFor), set in Start
local stepColors: { [StepState]: Color3 } -- a step's ring: gold beaten, green ready, red too weak, grey locked (Start)
local markColors: { [Mark]: Color3 } -- a checklist row's mark and value (Start)
local list: ScrollingFrame -- the bosses, top to bottom
local details: Frame -- the chosen boss
local states: { [string]: BossState } = {}
local ownedWeapons: { [string]: WeaponRules.Owned } = {} -- from WeaponsChanged: the boss weapons you have
local bagItems: { [string]: number } = {} -- from ItemsChanged: the forge progress on its weapon

-- Each boss's own weapon (Config/Weapons, built ones): bossId -> weapon id
local weaponOf: { [string]: string } = {}
for _, weapon in Weapons.WEAPONS do
	if weapon.ready and weapon.source.kind == "boss" and weapon.source.boss then
		weaponOf[weapon.source.boss] = weapon.id
	end
end
local receivedAt = 0 -- os.clock() when `states` arrived (lootIn counts down from then)
local partyIds: { string } = {}
local selected = 1 -- the boss shown beside the list
local lootPill: TextLabel? = nil -- the shown boss's loot timer

local function clock(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- The strongest party card's Power (what the over-power rule and the recommended Power compare)
local function bestPower(): number
	local beasts = BinderController.GetBeasts()
	local best = 0
	for _, beastId in partyIds do
		local beast = beasts[beastId]
		local card = if beast then Cards.ById[beast.cardId] else nil
		if beast and card then
			best = math.max(best, BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade))
		end
	end
	return math.floor(best)
end

local function shopLevel(): number
	local level = Players.LocalPlayer:GetAttribute("Level")
	return if typeof(level) == "number" then level else 1
end

local function here(): string
	return if Place.isDungeon() then "Dungeon" elseif Place.isFrontier() then "Frontier" else "Main"
end

-- This boss as the board's rules see it now
local function stepData(index: number, power: number): BossRules.Step
	local bossId = Bosses.LADDER[index]
	local boss = Bosses.BOSSES[bossId]
	local state = states[bossId]
	return {
		cleared = state ~= nil and state.cleared,
		unlocked = state ~= nil and state.unlocked,
		keyNeeded = if boss.unlock then boss.unlock.count else 0,
		fragments = if state then state.fragments else 0,
		shopLevel = shopLevel(),
		needLevel = boss.shopLevel,
		power = power,
		recommended = boss.recommended,
	}
end

local function stepOf(index: number, power: number): StepState
	return BossRules.stepState(stepData(index, power))
end

-- The timer pill: green when full loot is ready, dark while it counts down
local function lootStatus(state: BossState): (string, Color3)
	local left = math.max(0, math.ceil(state.lootIn - (os.clock() - receivedAt)))
	return if left > 0 then `Loot in {clock(left)}` else "Loot ready", if left > 0 then UIStyle.PANEL else UIStyle.GREEN
end

local function tinted(holder: Instance?, color: Color3)
	local glyph = if holder then holder:FindFirstChild("Glyph") else nil
	if glyph and glyph:IsA("ImageLabel") then
		glyph.ImageColor3 = color
	end
end

local function text(parent: Instance, value: string, size: number, color: Color3, bold: boolean?): TextLabel
	local label = UIKit.label(parent, value, if bold then Enum.Font.FredokaOne else Enum.Font.Gotham, size, color)
	label.TextWrapped = false
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, size + 4)
	label.ZIndex = (parent :: GuiObject).ZIndex + 1
	if bold and UIKit.themeOf(parent) ~= "cream" then
		UIKit.outlined(label, 2) -- outlined light text on dark windows; cream windows' brown text needs none
	end
	return label
end

-- Words that wrap to the column's width (rich: coloured names inside)
local function wrapped(parent: Instance, order: number, value: string, color: Color3, rich: boolean?): TextLabel
	local label = UIKit.label(parent, value, Enum.Font.GothamBold, UIKit.textSize("small"), color)
	label.LayoutOrder = order
	label.RichText = rich == true
	label.TextWrapped = true
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, -6, 0, 0)
	label.ZIndex = (parent :: GuiObject).ZIndex + 1
	return label
end

local function heading(parent: Instance, order: number, value: string): TextLabel
	local label = text(parent, value, UIKit.textSize("small"), palette.hint, true)
	label.LayoutOrder = order
	return label
end

local function strip(parent: Instance, order: number, height: number, gap: number): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, -6, 0, height)
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

-- A strip whose children wrap onto more lines when they don't fit
local function wrappingStrip(parent: Instance, order: number, height: number, gap: number): Frame
	local frame = strip(parent, order, height, gap)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	local layout = frame:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	layout.Wraps = true
	layout.Padding = UDim.new(0, gap)
	return frame
end

-- An icon line: icon then words
local function iconLine(parent: Instance, order: number, icon: string, words: string, color: Color3): Frame
	local line = strip(parent, order, 24, 6)
	Icon.make(line, icon, UDim2.fromOffset(22, 22)).ZIndex = line.ZIndex + 1
	local label = text(line, words, UIKit.textSize("small"), color, true)
	label.LayoutOrder = 2
	return line
end

-- A column of the details: scrolls when it doesn't fit (phones), padded so outlines aren't clipped
local function scroller(parent: Instance, position: UDim2, size: UDim2, gap: number): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = position
	frame.Size = size
	frame.ScrollBarThickness = 4
	frame.ScrollBarImageColor3 = UIKit.Colors.Accent
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.ZIndex = (parent :: GuiObject).ZIndex + 1
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 3)
	padding.PaddingBottom = UDim.new(0, 3)
	padding.PaddingLeft = UDim.new(0, 3)
	padding.Parent = frame
	return frame
end

local function whereText(bossId: string): string
	local boss = Bosses.BOSSES[bossId]
	if boss.place == "Dungeon" then
		return "The Dungeon"
	end
	local zone = (if boss.place == "Frontier" then FrontierConfig else WildConfig).ZONES[boss.zone]
	local prefix = if boss.place == "Frontier" then "The Frontier" else "The Wild"
	return if zone then `{prefix} · {zone.name}` else prefix
end

local function whereTip(bossId: string): string
	local boss = Bosses.BOSSES[bossId]
	if boss.place == "Dungeon" then
		return "At the end of a Dungeon run. The portal is in the Frontier."
	end
	local zone = (if boss.place == "Frontier" then FrontierConfig else WildConfig).ZONES[boss.zone]
	local world = if boss.place == "Frontier" then "the Frontier" else "the Wild"
	return if zone then `Its arena is at the end of {zone.name}, in {world}.` else `Its arena is in {world}.`
end

-- What the step's tooltip says about it
local function stepWords(index: number, step: StepState, power: number): string
	local boss = Bosses.BOSSES[Bosses.LADDER[index]]
	if step == "beaten" then
		return `{boss.name}: beaten`
	elseif step == "ready" then
		return `{boss.name}: ready to fight`
	elseif step == "tooWeak" then
		return `{boss.name}: built for {boss.recommended} Power`
	end
	local reason = BossRules.lockReason(stepData(index, power))
	if reason == "level" then
		return `{boss.name}: opens at shop level {boss.shopLevel}`
	end
	return `{boss.name}: needs {if boss.unlock then boss.unlock.count else 0} keys`
end

-- The first boss not beaten yet (nil when all are), and how many in a row from the bottom are beaten
local function climb(power: number): (number?, number)
	local beaten = 0
	for index = 1, #Bosses.LADDER do
		if stepOf(index, power) ~= "beaten" then
			return index, beaten
		end
		beaten = index
	end
	return nil, beaten
end

local render: () -> ()

local function choose(index: number)
	selected = index
	render()
end

-- A disc with the boss's icon in its state's ring (faded when locked); phones add the state's small badge
local function bossDisc(parent: Instance, bossId: string, step: StepState, size: number, badge: boolean): Frame
	local disc = Instance.new("Frame")
	disc.Size = UDim2.fromOffset(size, size)
	disc.BackgroundColor3 = palette.row
	disc.BackgroundTransparency = if step == "locked" then LOCKED_FADE else 0
	disc.ZIndex = (parent :: GuiObject).ZIndex + 1
	disc.Parent = parent
	UIKit.corner(disc, size)
	UIKit.outline(disc, stepColors[step], 3)
	local picture = Icon.make(disc, BossTints.icon(bossId), UDim2.fromScale(0.62, 0.62))
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	picture.ZIndex = disc.ZIndex + 1
	local glyph = picture:FindFirstChild("Glyph")
	if step == "locked" and glyph and glyph:IsA("ImageLabel") then
		glyph.ImageTransparency = LOCKED_FADE
	end
	local badgeIcon = STEP_BADGES[step]
	if badge and badgeIcon then
		local badgeSize = math.floor(size * 0.45)
		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(1, 1)
		holder.Position = UDim2.new(1, 4, 1, 4)
		holder.Size = UDim2.fromOffset(badgeSize, badgeSize)
		holder.BackgroundColor3 = palette.row
		holder.ZIndex = disc.ZIndex + 2
		holder.Parent = disc
		UIKit.corner(holder, badgeSize)
		UIKit.outline(holder, stepColors[step], 2)
		local mark = Icon.make(holder, badgeIcon, UDim2.fromScale(0.8, 0.8))
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(0.5, 0.5)
		mark.ZIndex = holder.ZIndex + 1
	end
	return disc
end

-- A boss's status in words, in its colour (the chip on its row and in the banner)
local function statusChip(parent: Instance, step: StepState, height: number): TextLabel
	local chip = UIKit.pill(parent, STEP_WORDS[step], STATUS_FILLS[step], nil, STATUS_ICONS[step])
	chip.Size = UDim2.fromOffset(0, height)
	chip.ZIndex = (parent :: GuiObject).ZIndex + 2
	return chip
end

-- One boss in the list: its disc, "N. Name", its status chip (phones: the disc's badge) and "Next" on the first boss
-- still to beat; the chosen one wears the gold ring. No layout on the row itself (the window's hover adds its pieces
-- to the row: UIKit noGreyHover).
local function buildRow(index: number, step: StepState, phone: boolean, isNext: boolean, power: number)
	local bossId = Bosses.LADDER[index]
	local boss = Bosses.BOSSES[bossId]
	local height = if phone then PHONE_ROW_HEIGHT else ROW_HEIGHT
	local row = Instance.new("TextButton")
	row.Name = `Boss{index}`
	row.LayoutOrder = index
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundColor3 = palette.row
	row.Text = ""
	row.ZIndex = list.ZIndex + 1
	row.Parent = list
	UIKit.corner(row, 14)
	UIKit.outline(row, if index == selected then UIStyle.GOLD else palette.rowEdge, if index == selected then 3 else 2)
	row.Activated:Connect(function()
		choose(index)
	end)
	Tooltip.attach(row, stepWords(index, step, power))

	local disc = bossDisc(row, bossId, step, DISC_SIZE, phone)
	disc.AnchorPoint = Vector2.new(0, 0.5)
	disc.Position = UDim2.new(0, 8, 0.5, 0)
	if isNext then
		local tag = UIKit.pill(row, "Next", UIStyle.GOLD)
		tag.AnchorPoint = Vector2.new(0.5, 0.5)
		tag.Position = UDim2.new(0, 8 + DISC_SIZE / 2, 0, 6)
		tag.Size = UDim2.fromOffset(0, 16)
		tag.TextSize = UIKit.textSize("small") - 3
		tag.ZIndex = row.ZIndex + 5
	end
	local chipRoom = if phone then 8 else 118 -- the widest chip ("Too weak" with its icon) never covers the name
	local name = UIKit.label(row, `{index}. {boss.name}`, Enum.Font.FredokaOne, UIKit.textSize("small") - (if phone then 2 else 0), if index == selected then palette.hint else palette.ink)
	name.AnchorPoint = Vector2.new(0, 0.5)
	name.Position = UDim2.new(0, 8 + DISC_SIZE + 8, 0.5, 0)
	name.Size = UDim2.new(1, -(8 + DISC_SIZE + 8 + chipRoom), 1, -6)
	name.TextWrapped = true
	name.ZIndex = row.ZIndex + 1
	if not phone then
		local chip = statusChip(row, step, 22)
		chip.AnchorPoint = Vector2.new(1, 0.5)
		chip.Position = UDim2.new(1, -8, 0.5, 0)
	end
end

-- A met, missing or warning mark at the start of a checklist row
local function markBadge(parent: Instance, mark: Mark): GuiObject
	if mark ~= "warn" then
		local picture = Icon.make(parent, if mark == "ok" then "Check" else "Close", UDim2.fromOffset(20, 20))
		picture.ZIndex = (parent :: GuiObject).ZIndex + 1
		return picture
	end
	local dot = UIKit.label(parent, "!", Enum.Font.FredokaOne, 15, UIKit.Colors.Ink)
	dot.Size = UDim2.fromOffset(20, 20)
	dot.BackgroundColor3 = UIStyle.HINT
	dot.BackgroundTransparency = 0
	dot.TextXAlignment = Enum.TextXAlignment.Center
	dot.ZIndex = (parent :: GuiObject).ZIndex + 1
	UIKit.corner(dot, 10)
	UIKit.outline(dot, palette.rowEdge, 2)
	return dot
end

-- One "to fight it" row: a mark, its icon (the "Picture" child), what it needs, and what you have on the right; with
-- `share`, a thin bar under it. A button, so a row can lead somewhere.
local function needRow(parent: Instance, order: number, mark: Mark, icon: string, words: string, have: string, share: number?): TextButton
	local line = 32
	local row = Instance.new("TextButton")
	row.Name = "Need"
	row.LayoutOrder = order
	row.Text = ""
	row.AutoButtonColor = false
	row.Size = UDim2.new(1, -6, 0, if share then line + 12 else line)
	row.BackgroundColor3 = palette.row
	row.ZIndex = (parent :: GuiObject).ZIndex + 1
	row.Parent = parent
	UIKit.corner(row, 10)
	UIKit.outline(row, palette.rowEdge, 2)
	local badge = markBadge(row, mark)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.fromOffset(8, line / 2)
	local picture = Icon.make(row, icon, UDim2.fromOffset(22, 22))
	picture.Name = "Picture" -- the mark is an icon too
	picture.AnchorPoint = Vector2.new(0, 0.5)
	picture.Position = UDim2.fromOffset(34, line / 2)
	picture.ZIndex = row.ZIndex + 1
	local label = text(row, words, UIKit.textSize("small"), palette.ink, true)
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.fromOffset(62, line / 2)
	local value = text(row, have, UIKit.textSize("small"), markColors[mark], true)
	value.AnchorPoint = Vector2.new(1, 0.5)
	value.Position = UDim2.new(1, -10, 0, line / 2)
	if share then
		local track = UIKit.bar(row, share, if mark == "ok" then nil else markColors[mark])
		track.Position = UDim2.fromOffset(34, line + 1)
		track.Size = UDim2.new(1, -44, 0, 7)
	end
	return row
end

-- An item in a slot: its icon (a boss item in its boss's tint), a count badge, and a tooltip with what it does
local function itemCell(parent: Instance, order: number, itemId: string, size: number, count: string, lines: { Line }, faded: boolean?): Frame
	local item = Items.ITEMS[itemId]
	local cell = Instance.new("Frame")
	cell.LayoutOrder = order
	cell.Size = UDim2.fromOffset(size, size)
	cell.BackgroundColor3 = palette.row
	cell.BackgroundTransparency = if faded then 0.5 else 0
	cell.ZIndex = (parent :: GuiObject).ZIndex + 1
	cell.Parent = parent
	UIKit.corner(cell, 10)
	UIKit.outline(cell, palette.rowEdge, 2)
	local picture = Icon.make(cell, item.icon, UDim2.fromScale(0.7, 0.7))
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.45)
	picture.ZIndex = cell.ZIndex + 1
	local boss = ItemRules.bossOf(itemId, Bosses.LADDER)
	if boss then
		tinted(picture, BossTints.key(Bosses.LADDER[boss]))
	end
	local glyph = picture:FindFirstChild("Glyph")
	if faded and glyph and glyph:IsA("ImageLabel") then
		glyph.ImageTransparency = LOCKED_FADE
	end
	local badge = text(cell, count, math.max(11, math.floor(size / 3.6)), palette.ink, true)
	badge.AnchorPoint = Vector2.new(1, 1)
	badge.Position = UDim2.new(1, -2, 1, 0)
	badge.ZIndex = cell.ZIndex + 2
	Tooltip.rich(cell, item.name, lines)
	return cell
end

-- A drop each win may give: the item over its chance for your next win
local function dropCell(parent: Instance, order: number, drop: Bosses.Drop, factor: number, size: number)
	local item = Items.ITEMS[drop.item]
	-- A fragment for a boss you've opened doesn't drop any more (BossService)
	local opens, kind = ItemRules.bossOf(drop.item, Bosses.LADDER)
	local opened = kind == "fragment" and opens ~= nil and states[Bosses.LADDER[opens]] ~= nil and states[Bosses.LADDER[opens]].unlocked
	local holder = Instance.new("Frame")
	holder.LayoutOrder = order
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size + 18)
	holder.ZIndex = (parent :: GuiObject).ZIndex
	holder.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	local chance = BossRules.chanceText(drop.chance * factor)
	local count = BossRules.countText(drop.min, drop.max)
	local odds: Line = if opened
		then { text = "That boss is open: this won't drop any more.", color = UIKit.Colors.Subtext }
		else { text = `{chance} chance a win · {count}`, color = if factor < 1 then UIStyle.HINT else UIStyle.GOOD }
	itemCell(holder, 1, drop.item, size, count, { item.description, odds }, opened)
	local label = text(holder, if opened then "-" else chance, UIKit.textSize("small") - 1, if factor < 1 then palette.hint else palette.good, true)
	label.LayoutOrder = 2
end

-- A chest's items in a row after its title (the first win, the day's first win): the title in `color` on the window,
-- the tooltip's line in `tipColor` (tooltips stay dark)
local function chestRow(parent: Instance, order: number, title: string, color: Color3, tipColor: Color3, grants: { Bosses.Grant }, when: string)
	local row = wrappingStrip(parent, order, CHEST_SIZE, 6)
	text(row, title, UIKit.textSize("small"), color, true).LayoutOrder = 0
	for index, grant in grants do
		local item = Items.ITEMS[grant.item]
		if item then
			itemCell(row, index, grant.item, CHEST_SIZE, `x{grant.count}`, { item.description, { text = `{when} · x{grant.count}`, color = tipColor } })
		end
	end
end

-- One "watch out" line: an icon, the trick's name in gold, what it does
local function trickLine(column: ScrollingFrame, order: number, icon: string, name: string, words: string)
	local line = strip(column, order, 0, 6)
	line.AutomaticSize = Enum.AutomaticSize.Y
	local layout = line:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	Icon.make(line, icon, UDim2.fromOffset(20, 20)).ZIndex = line.ZIndex + 1
	local label = wrapped(line, 2, `<font color="#{palette.hint:ToHex()}">{name}</font> {words}`, palette.ink, true)
	label.Size = UDim2.new(1, -26, 0, 0)
end

-- Left column: can I fight it? The checklist, then its tricks. reveal false (a locked boss past the next one,
-- BossRules.revealTricks): its tricks stay a surprise
local function renderNeeds(column: ScrollingFrame, index: number, power: number, reveal: boolean)
	local bossId = Bosses.LADDER[index]
	local boss = Bosses.BOSSES[bossId]
	local state = states[bossId]
	local previous = Bosses.BOSSES[Bosses.LADDER[index - 1] or ""]

	-- The checklist: shop level, key fragments, Power
	heading(column, 4, "TO FIGHT IT")
	local level, need = shopLevel(), boss.shopLevel
	local levelRow = needRow(column, 5, if level >= need then "ok" else "no", "Level", `Shop level {need}`, `You: {level}`)
	Tooltip.attach(levelRow, "Your shop level. Sell cards to level up your shop.")
	local unlock = boss.unlock
	local have = if state then state.fragments else 0
	if unlock then
		local item = Items.ITEMS[unlock.item]
		local opened = state ~= nil and state.unlocked
		local keyRow = needRow(column, 6, if opened or have >= unlock.count then "ok" else "no", "KeyFragment", `{unlock.count} {item.name}s`, if opened then "Opened" else `{have}/{unlock.count}`)
		tinted(keyRow:FindFirstChild("Picture"), BossTints.key(bossId))
		local lines: { Line } = { item.description, if opened then "Used up: this boss is open for good." else "Used up the first time you fight it." }
		if previous and not opened then
			table.insert(lines, { text = `Drops from the {previous.name}. Tap to see it.`, color = UIStyle.GOOD })
			keyRow.Activated:Connect(function()
				choose(index - 1)
			end)
		end
		Tooltip.rich(keyRow, item.name, lines)
	else
		local keyRow = needRow(column, 6, "ok", "KeyFragment", "No key needed", "Open")
		Tooltip.attach(keyRow, "The first boss is open from the start.")
	end
	local strong = power >= boss.recommended
	local powerRow = needRow(column, 7, if strong then "ok" else "warn", "Power", `Power {boss.recommended}`, `Your best: {power}`, power / math.max(boss.recommended, 1))
	Tooltip.attach(powerRow, "Your strongest party card's Power against the Power this boss is built for. Under it, the fight is hard.")

	-- Its tricks, spelled out (no hovering needed), or a surprise until you can reach it
	heading(column, 9, "WATCH OUT")
	local tricks = BossRules.watchOut(boss)
	if not reveal then
		trickLine(column, 10, "Lock", "???", "Reach it to find out.")
	elseif #tricks == 0 then
		wrapped(column, 10, "No tricks: a good first boss.", UIKit.Colors.Subtext)
	else
		for order, trick in tricks do
			trickLine(column, 10 + order, TRICK_ICONS[trick.kind] or "Info", `{trick.name}:`, trick.text)
		end
	end
end

-- How to get to a boss's place when there's no travel button from here (nil: there is one, or nothing to say)
local function travelHint(bossId: string): string?
	local choice = BossRules.travelChoice(Bosses.BOSSES[bossId].place, here())
	if choice == "viaPortal" then
		return "Enter the Dungeon portal in the Frontier."
	elseif choice == "walkToFrontier" then
		return "Walk to the Frontier portal at Frostpeak (follow the blue line from the plaza)."
	end
	return nil
end

-- Right column: what do I get? The loot timer, each win's drops with odds, the chests, cash and XP, the soft cap,
-- and the way there
local function renderRewards(column: ScrollingFrame, index: number, power: number)
	local bossId = Bosses.LADDER[index]
	local boss = Bosses.BOSSES[bossId]
	local state = states[bossId]
	local phone = UIKit.isPhone()

	local top = strip(column, 1, 28, 8)
	heading(top, 1, "REWARDS")
	if state then
		local words, fill = lootStatus(state)
		local pill = UIKit.pill(top, words, fill, nil, "Hourglass")
		pill.LayoutOrder = 2
		pill.Size = UDim2.fromOffset(0, 26)
		pill.ZIndex = top.ZIndex + 1
		Tooltip.attach(pill, `A boss drops loot once every {Bosses.LOOT_COOLDOWN // 60} min. Wins before then give cash and XP only.`)
		lootPill = pill
	end

	-- Each win's drops, at the chances your next win rolls them (soft cap and over-power included)
	local factor = if state then BossRules.softCapFactor(Bosses, state.rewardedToday) * BossRules.overPowerFactor(Bosses, power, boss.recommended) else 1
	text(column, "Each win can drop", UIKit.textSize("small"), UIKit.Colors.Subtext).LayoutOrder = 2
	local size = if phone then PHONE_DROP_SIZE else DROP_SIZE
	local drops = wrappingStrip(column, 3, size + 18, 8)
	for order, drop in boss.drops do
		if Items.ITEMS[drop.item] then
			dropCell(drops, order, drop, factor, size)
		end
	end

	-- Its weapon (weapons round 1): its card, the chance your next full-loot win drops it (it grows every full-loot
	-- win without it), its material's odds and the forge progress
	local weaponId = weaponOf[bossId]
	if weaponId then
		local cardHeight = if phone then PHONE_WEAPON_CARD else WEAPON_CARD
		local row = strip(column, 4, cardHeight + 6, 10)
		local card = Instance.new("Frame")
		card.Name = "WeaponCard"
		card.LayoutOrder = 1
		card.BackgroundTransparency = 1
		card.Size = UDim2.fromOffset(math.floor(cardHeight * 0.7), cardHeight)
		card.ZIndex = row.ZIndex + 1
		card.Parent = row
		local record = ownedWeapons[weaponId]
		local have, need = WeaponRules.makeProgress(Weapons, weaponId, bagItems)
		WeaponFace.render(card, nil, weaponId, record, if not record and have and need then { have = have, need = need } else nil)
		local words = Instance.new("Frame")
		words.LayoutOrder = 2
		words.BackgroundTransparency = 1
		words.Size = UDim2.new(1, -(math.floor(cardHeight * 0.7) + 10), 1, 0)
		words.ZIndex = row.ZIndex
		words.Parent = row
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 2)
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Parent = words
		local weapon = Weapons.ById[weaponId]
		wrapped(words, 1, `Its weapon: {weapon.name}{if record then " (yours)" else ""}`, palette.ink)
		local pity = if state then state.weaponPity or 0 else 0
		local share = WeaponRules.dropChance(Weapons, weaponId, pity)
		local chance = wrapped(words, 2, string.format(if share < 0.01 then "Drop chance now: %.2f%%" else "Drop chance now: %.1f%%", share * 100), palette.good)
		Tooltip.attach(chance, "Each win with full loot can drop it. Every one that doesn't makes the next more likely.")
		local material = WeaponRules.material(Weapons, weaponId)
		for _, drop in boss.drops do
			if drop.item == material and Items.ITEMS[material] then
				wrapped(words, 3, `Its material: {Items.ITEMS[material].name}, {math.round(drop.chance * 100)}% with full loot`, palette.inkSoft)
			end
		end
		if not record and have and need then
			wrapped(words, 4, `Or forge it: {have}/{need}`, palette.inkSoft)
		end
	end

	if not (state and state.cleared) then
		chestRow(column, 5, "First win", palette.hint, UIStyle.HINT, boss.firstClear, "Once, on your first win")
	end
	if not state or state.bonusReady then
		chestRow(column, 6, "First win today", palette.good, UIStyle.GOOD, boss.dailyBonus, "Your first win each day")
	else
		iconLine(column, 6, "Gift", "Daily bonus collected: back tomorrow", UIKit.Colors.Subtext)
	end

	local pay = strip(column, 7, 24, 6)
	Icon.make(pay, "Cash", UDim2.fromOffset(22, 22)).ZIndex = pay.ZIndex + 1
	local cash = text(pay, `{boss.cash}`, UIKit.textSize("small"), palette.good, true)
	cash.LayoutOrder = 2
	local xpIcon = Icon.make(pay, "Xp", UDim2.fromOffset(22, 22))
	xpIcon.LayoutOrder = 3
	xpIcon.ZIndex = pay.ZIndex + 1
	local xp = text(pay, `{boss.xp} XP`, UIKit.textSize("small"), palette.ink, true) -- the light XP blue doesn't read on cream
	xp.LayoutOrder = 4
	local every = text(pay, "every win", UIKit.textSize("small"), UIKit.Colors.Subtext)
	every.LayoutOrder = 5
	Tooltip.attach(pay, "Every win pays cash and XP, loot or not. Your party shares the XP.")

	if state then
		local left = BossRules.fullDropsLeft(Bosses, state.rewardedToday)
		local line = iconLine(column, 8, "Trophy", if left > 0 then `Full drops: {left} more {if left == 1 then "win" else "wins"} today` else "Fewer drops today: full again tomorrow", if left > 0 then palette.ink else palette.hint)
		Tooltip.attach(line, `After {Bosses.SOFT_CAP_AFTER} loot wins in a day, drops get rarer. Every day starts fresh.`)
	end
	local threshold = math.floor(boss.recommended * Bosses.OVERPOWER_RATIO)
	if power > threshold then
		local line = iconLine(column, 9, "Power", "Party very strong: fewer drops", palette.hint)
		Tooltip.attach(line, `Over {threshold} Power this boss drops less. Climb to the next boss, or fight it with weaker cards.`)
	end
	-- Phones: the way to its place sits at the end of the column (BossRules.detailsLayout), not in the footer
	local hint = travelHint(bossId)
	if hint and BossRules.detailsLayout(UIKit.isPhone()).hintInRewards then
		wrapped(column, 10, hint, palette.hint)
	end
end

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- Its element (the Hydra changes element with each phase), where it lives, the element that hits it harder; reveal
-- false: the Hydra's elements stay a surprise
local function renderPills(parent: Instance, index: number, reveal: boolean): Frame
	local bossId = Bosses.LADDER[index]
	local boss = Bosses.BOSSES[bossId]
	local pills = wrappingStrip(parent, 0, 26, 6)
	local secret = boss.phases ~= nil and not reveal -- the Hydra's element changes are one of its tricks
	local element = UIKit.pill(pills, if secret then "???" elseif boss.phases then "All elements" else boss.element, if boss.phases then UIStyle.PANEL else Cards.ELEMENTS[boss.element] or UIStyle.PANEL, nil, BossTints.icon(bossId))
	element.LayoutOrder = 1
	Tooltip.attach(element, if secret then "Reach it to find out." elseif boss.phases then "It changes element as it gets hurt." else `Its element: {boss.element}`)
	local where = UIKit.pill(pills, whereText(bossId), UIStyle.PANEL, nil, "Travel")
	where.LayoutOrder = 2
	Tooltip.attach(where, whereTip(bossId))
	if not secret then
		local counters = if boss.phases then {} else BossRules.counterElements(Combat.BEATS, boss.element)
		local bring = UIKit.pill(pills, if counters[1] then `Bring {table.concat(counters, " or ")}` else "Bring a mix", UIStyle.PANEL, UIStyle.GOOD, counters[1] or "Cards")
		bring.LayoutOrder = 3
		Tooltip.attach(bring, if counters[1] then `{table.concat(counters, " and ")} cards hit it {Combat.STRONG}x harder.` else "Bring cards of different elements: each part of the fight has its own.")
	end
	return pills
end

-- The banner across the top in the boss's baby colour (BossRules.bannerColor): a big disc with its icon, its name and
-- title, its status and "Next"; plum text on light fills, white outlined in the deep shade on bright ones
local function renderBanner(index: number, step: StepState, isNext: boolean, height: number): Frame
	local bossId = Bosses.LADDER[index]
	local boss = Bosses.BOSSES[bossId]
	local shades = BabyColors.COLORS[BossRules.bannerColor(BabyColors.ELEMENTS, boss)]
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.Size = UDim2.new(1, 0, 0, height)
	banner.BackgroundColor3 = Color3.new(1, 1, 1)
	banner.ZIndex = details.ZIndex + 1
	banner.Parent = details
	UIKit.corner(banner, 14)
	local fill = Instance.new("UIGradient")
	fill.Rotation = 20
	fill.Color = ColorSequence.new(rgb(shades.light), rgb(shades.fill))
	fill.Parent = banner

	local discSize = height - 24
	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0, 0.5)
	disc.Position = UDim2.new(0, 14, 0.5, 0)
	disc.Size = UDim2.fromOffset(discSize, discSize)
	disc.BackgroundColor3 = Color3.new(1, 1, 1)
	disc.ZIndex = banner.ZIndex + 1
	disc.Parent = banner
	UIKit.corner(disc, discSize)
	UIKit.outline(disc, Color3.new(1, 1, 1), 3)
	local picture = Icon.make(disc, BossTints.icon(bossId), UDim2.fromScale(0.64, 0.64))
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	picture.ZIndex = disc.ZIndex + 1

	local white = SoftColors.textOn(shades.fill, BabyColors.LIGHT_LUMA) == "white"
	local ink = if white then Color3.new(1, 1, 1) else UIStyle.BABY_INK
	local textLeft = 14 + discSize + 12
	local function bannerText(value: string, font: Enum.Font, size: number, y: number): TextLabel
		local label = UIKit.label(banner, value, font, size, ink)
		label.Position = UDim2.fromOffset(textLeft, y)
		label.Size = UDim2.new(1, -(textLeft + 120), 0, size + 6)
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.ZIndex = banner.ZIndex + 1
		if white then
			UIKit.outlined(label, 2).Color = rgb(shades.deep)
		end
		return label
	end
	local nameSize = UIKit.textSize("name") + (if UIKit.isPhone() then 0 else 6)
	local nameY = math.max(4, height / 2 - nameSize + (if UIKit.isPhone() then 0 else -4))
	bannerText(boss.name, Enum.Font.FredokaOne, nameSize, nameY)
	bannerText(boss.title, Enum.Font.GothamBold, UIKit.textSize("small"), nameY + nameSize + 6)
	local chip = statusChip(banner, step, 24)
	chip.AnchorPoint = Vector2.new(1, 0)
	chip.Position = UDim2.new(1, -12, 0, 12)
	if isNext then
		local tag = UIKit.pill(banner, "Next", UIStyle.GOLD)
		tag.AnchorPoint = Vector2.new(1, 0)
		tag.Position = UDim2.new(1, -12, 0, 42)
		tag.Size = UDim2.fromOffset(0, 20)
		tag.ZIndex = banner.ZIndex + 2
	end
	return banner
end

-- The footer, always in view: what to do next (BossRules.nextStep) on a light tint of its colour, with its button,
-- and the way to the boss: "Take me there" (its gate here) / "Go home", or how to get to its place
local function renderFooter(index: number, step: StepState, power: number): Frame
	local bossId = Bosses.LADDER[index]
	local boss = Bosses.BOSSES[bossId]
	local state = states[bossId]
	local previous = Bosses.BOSSES[Bosses.LADDER[index - 1] or ""]
	local unlock = boss.unlock
	local have = if state then state.fragments else 0
	local phone = UIKit.isPhone()
	local kind = BossRules.nextStep(step, BossRules.lockReason(stepData(index, power)), unlock ~= nil and previous ~= nil)
	local words, color = "", palette.rowEdge
	local action: { label: string, icon: string, run: () -> () }? = nil
	if kind == "beaten" then
		words, color = "Beaten! Fight it again for more loot.", UIStyle.GOLD
	elseif kind == "ready" then
		words, color = "You're ready! Go to its arena and press Fight.", palette.good
	elseif kind == "tooWeak" then
		words, color = "Too weak for now: level up your cards or put stronger ones in your party.", palette.bad
		action = { label = "Party", icon = "Party", run = PartyController.Toggle }
	elseif kind == "level" then
		words, color = `Reach shop level {boss.shopLevel}: sell cards to level up.`, palette.bad
	elseif kind == "keys" and unlock and previous then
		words, color = `Beat the {previous.name} to collect {unlock.count - have} more keys.`, palette.bad
		action = {
			label = "See it",
			icon = "Next",
			run = function()
				choose(index - 1)
			end,
		}
	end
	local choice = BossRules.travelChoice(boss.place, here())
	local hint = if BossRules.detailsLayout(phone).hintInRewards then nil else travelHint(bossId)
	local travel = choice == "gate" or choice == "toMain"

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, GAP, 1, -GAP)
	footer.Size = UDim2.new(1, -GAP * 2, 0, 0)
	footer.AutomaticSize = Enum.AutomaticSize.Y
	footer.BackgroundColor3 = color:Lerp(palette.row, 0.85) -- a light tint of its colour
	footer.ZIndex = details.ZIndex + 1
	footer.Parent = details
	UIKit.corner(footer, 12)
	UIKit.outline(footer, color, 2)
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 8)
	end
	padding.Parent = footer
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = footer
	local actionWidth = if action then 104 else 0
	local travelWidth = if travel then (if phone then 128 else 160) else 0
	local buttonsWidth = actionWidth + travelWidth + (if action then 8 else 0) + (if travel then 8 else 0)
	local lines = words
	if hint then
		lines = (if words ~= "" then words .. "\n" else "") .. `<font color="#{palette.hint:ToHex()}">{hint}</font>`
	end
	local label = wrapped(footer, 1, lines, palette.ink, true)
	label.Size = UDim2.new(1, -buttonsWidth, 0, 0)
	local buttonHeight = if phone then UIStyle.MIN_TAP else 42
	if action then
		local button = UIKit.iconButton(footer, action.label, action.icon, UIKit.Colors.Secondary)
		button.LayoutOrder = 2
		button.Size = UDim2.fromOffset(actionWidth, buttonHeight)
		button.TextSize = UIKit.textSize("small")
		button.ZIndex = footer.ZIndex + 1
		button.Activated:Connect(action.run)
	end
	if travel then
		local go = UIKit.iconButton(footer, if choice == "gate" then "Take me there" else "Go home", "Travel", if choice == "gate" then UIKit.Colors.Accent else UIKit.Colors.Secondary)
		go.LayoutOrder = 3
		go.Size = UDim2.fromOffset(travelWidth, buttonHeight)
		go.TextSize = UIKit.textSize("small")
		go.ZIndex = footer.ZIndex + 1
		go.Activated:Connect(function()
			if choice == "gate" then
				Remotes.BossTravel:FireServer(index)
			else
				Remotes.FrontierTravel:FireServer("home")
			end
			UIKit.closePanel(panel)
		end)
	end
	return footer
end

-- The chosen boss: the banner, its pills, the two columns (To fight it, Rewards; each scrolls) and the footer
local function renderDetails(index: number, step: StepState, power: number, isNext: boolean)
	clear(details)
	lootPill = nil
	local phone = UIKit.isPhone()
	local gap = if phone then 5 else 7
	local bannerHeight = if phone then PHONE_BANNER_HEIGHT else BANNER_HEIGHT
	local reveal = BossRules.revealTricks(step, isNext)
	renderBanner(index, step, isNext, bannerHeight)
	local plan = BossRules.detailsLayout(phone)
	local footer = renderFooter(index, step, power)
	local left = scroller(details, UDim2.new(), UDim2.new(), gap)
	local right = scroller(details, UDim2.new(), UDim2.new(), gap)
	-- Phones: the pills scroll with the left column (BossRules.detailsLayout) so the columns keep their room
	local pills = renderPills(if plan.pillsInColumn then left else details, index, reveal)
	if not plan.pillsInColumn then
		pills.Position = UDim2.fromOffset(GAP, bannerHeight + GAP)
		pills.Size = UDim2.new(1, -GAP * 2, 0, 26)
	end
	local divider = Instance.new("Frame")
	divider.BackgroundColor3 = palette.rowEdge
	divider.BorderSizePixel = 0
	divider.ZIndex = details.ZIndex + 1
	divider.Parent = details
	local function placeColumns()
		local top = bannerHeight + GAP + (if plan.pillsInColumn then 0 else pills.AbsoluteSize.Y + GAP)
		local bottom = footer.AbsoluteSize.Y + GAP * 2
		left.Position = UDim2.fromOffset(GAP, top)
		left.Size = UDim2.new(0.5, -GAP * 1.5, 1, -(top + bottom))
		right.Position = UDim2.new(0.5, GAP / 2, 0, top)
		right.Size = UDim2.new(0.5, -GAP * 1.5, 1, -(top + bottom))
		divider.Position = UDim2.new(0.5, -1, 0, top + 4)
		divider.Size = UDim2.new(0, 2, 1, -(top + bottom + 8))
	end
	pills:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeColumns)
	footer:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeColumns)
	placeColumns()
	renderNeeds(left, index, power, reveal)
	renderRewards(right, index, power)
end

render = function()
	if not panel.Visible then
		return
	end
	clear(list)
	local power = bestPower()
	local phone = UIKit.isPhone()
	local nextIndex = climb(power)
	for index = 1, #Bosses.LADDER do
		buildRow(index, stepOf(index, power), phone, index == nextIndex, power)
	end
	renderDetails(selected, stepOf(selected, power), power, selected == nextIndex)
end

-- The first step still to beat that isn't locked, else the last one beaten, else the first
local function defaultStep(): number
	local power = bestPower()
	local lastBeaten = 1
	for index = 1, #Bosses.LADDER do
		local step = stepOf(index, power)
		if step == "ready" or step == "tooWeak" then
			return index
		elseif step == "beaten" then
			lastBeaten = index
		end
	end
	return lastBeaten
end

-- Big on desktops (up to MAX_SIZE), nearly the whole screen on phones: the bosses' list on the left, the chosen one
-- beside it
local function layout()
	local phone = UIKit.isPhone()
	panel.Size = if phone then UDim2.fromScale(0.97, 0.98) else UDim2.fromScale(0.92, 0.88)
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = MAX_SIZE
	end
	local top = UIKit.HEADER_HEIGHT + (if phone then 8 else 12)
	local bottom = if phone then 10 else 14
	local width = if phone then PHONE_LIST_WIDTH else LIST_WIDTH
	list.Position = UDim2.fromOffset(12, top)
	list.Size = UDim2.new(0, width, 1, -(top + bottom))
	details.Position = UDim2.fromOffset(12 + width + 10, top)
	details.Size = UDim2.new(1, -(12 + width + 10 + 12), 1, -(top + bottom))
end

local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		layout()
		selected = defaultStep()
		Remotes.RequestBosses:FireServer()
		render()
	end
end

-- The server's group prompt text is for everyone else ("Join group"); its leader's copy says "Start now"
local function watchGroupPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local function refresh()
		local members = prompt:GetAttribute("Members")
		if prompt:GetAttribute("LeaderId") == Players.LocalPlayer.UserId and typeof(members) == "number" then
			prompt.ActionText = BossRules.groupPromptText(Bosses, members, true)
		end
	end
	prompt:GetAttributeChangedSignal("LeaderId"):Connect(refresh)
	prompt:GetAttributeChangedSignal("Members"):Connect(refresh)
	prompt:GetPropertyChangedSignal("ActionText"):Connect(refresh)
	refresh()
end

function BossBoardController.Start()
	CollectionService:GetInstanceAddedSignal("BossGroupPrompt"):Connect(watchGroupPrompt)
	for _, prompt in CollectionService:GetTagged("BossGroupPrompt") do
		watchGroupPrompt(prompt)
	end
	local screenGui = UIController.GetScreenGui()
	local panelList: ScrollingFrame
	panel, panelList = UIKit.panel(screenGui, "Bosses", "Boss Ladder", "Bosses")
	palette = UIKit.colorsFor(panel)
	stepColors = { beaten = UIStyle.GOLD, ready = palette.good, tooWeak = palette.bad, locked = UIKit.Colors.Locked }
	markColors = { ok = palette.good, no = palette.bad, warn = palette.hint }
	panelList:Destroy() -- the bosses' list and one boss's details, laid out here
	Icon.header(panel, "Trophy", UIKit.HEADER_HEIGHT)

	list = Instance.new("ScrollingFrame")
	list.Name = "BossList"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = UIKit.Colors.Accent
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ZIndex = panel.ZIndex + 1
	list.Parent = panel
	local rows = Instance.new("UIListLayout")
	rows.Padding = UDim.new(0, 6)
	rows.SortOrder = Enum.SortOrder.LayoutOrder
	rows.Parent = list
	-- Room inside the list for the chosen row's ring and the hover's edge
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 4)
	listPadding.PaddingBottom = UDim.new(0, 4)
	listPadding.PaddingLeft = UDim.new(0, 4)
	listPadding.PaddingRight = UDim.new(0, 10)
	listPadding.Parent = list

	details = Instance.new("Frame")
	details.Name = "Details"
	details.BackgroundColor3 = palette.slotEmpty -- a deeper cream (no big white slab); its rows and slots are white
	details.ZIndex = panel.ZIndex + 1
	details.Parent = panel
	UIKit.corner(details, 14)
	UIKit.outline(details, palette.rowEdge, 2)

	Hud.tile({ id = "Bosses", icon = "Trophy", label = "Bosses", key = "K", group = "Bottom", order = 3, onClick = toggle })

	Remotes.WeaponsChanged.OnClientEvent:Connect(function(state: unknown)
		if typeof(state) == "table" and typeof((state :: any).owned) == "table" then
			ownedWeapons = (state :: any).owned
			render()
		end
	end)
	Remotes.ItemsChanged.OnClientEvent:Connect(function(items: unknown)
		if typeof(items) == "table" then
			bagItems = items :: any
		end
	end)
	Remotes.BossesChanged.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		states = {}
		for bossId, state in payload do
			if Bosses.BOSSES[bossId] and typeof(state) == "table" and typeof(state.lootIn) == "number" then
				state.bonusReady = state.bonusReady == true
				states[bossId] = state
			end
		end
		receivedAt = os.clock()
		render()
	end)
	Remotes.PartyChanged.OnClientEvent:Connect(function(payload)
		partyIds = {}
		if typeof(payload) == "table" and typeof(payload.slots) == "table" then
			for _, entry in payload.slots do
				if typeof(entry) == "table" and typeof(entry.beastId) == "string" then
					table.insert(partyIds, entry.beastId)
				end
			end
		end
		render()
	end)
	-- Levels and stars change your best Power
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		task.defer(render)
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("Level"):Connect(render)
	Remotes.RequestBosses:FireServer()

	local sinceTick = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceTick += dt
		if sinceTick < 1 or not panel.Visible then
			return
		end
		sinceTick = 0
		local state = states[Bosses.LADDER[selected]]
		local pill = lootPill
		if state and pill and pill.Parent then
			pill.Text, pill.BackgroundColor3 = lootStatus(state)
		end
	end)
end

return BossBoardController
