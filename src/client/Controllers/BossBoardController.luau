--!strict
-- The boss board (HUD tile "Bosses"; spec 2026-10-29-collection-screens-ui-design.md 4.7, reworked in UI feedback
-- round 3): the ladder (Config/Bosses) as a path of seven steps, each a disc with the boss's icon and a badge for its
-- state (BossRules.stepState): beaten (gold ring, trophy), ready (green glow, check), too weak (red ring) or locked
-- (faded, lock). A legend names the badges, the path fills gold as you climb and "Next" marks the first boss still to
-- beat. Tapping a step shows it below in two columns. To fight it: name, title and status, its element, where it
-- lives and the element to bring, a checklist (shop level, its key fragments, the Power it's built for), what to do
-- next, and its tricks (BossRules.watchOut). Rewards: when full loot is ready again, what each win can drop with its
-- odds (shrunk by the soft cap and the over-power rule, as the server rolls them), the first-win and daily chests,
-- cash and XP, full-drop wins left today, and "Take me there" (its gate here, BossTravel) or the normal travel to the
-- place it's in. Icons have tooltips (items: what they do and their odds). Data comes from BossService
-- (BossesChanged); the loot timer counts down here between updates.
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
local UIStyle = require(Config:WaitForChild("UIStyle"))
local WildConfig = require(Config:WaitForChild("Wild"))
local FrontierConfig = require(Config:WaitForChild("Frontier"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local BossRules = require(Shared:WaitForChild("Util"):WaitForChild("BossRules"))
local ItemRules = require(Shared:WaitForChild("Util"):WaitForChild("ItemRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local BossTints = require(ClientUtil:WaitForChild("BossTints"))
local Tooltip = require(ClientUtil:WaitForChild("Tooltip"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))
local PartyController = require(Controllers:WaitForChild("PartyController"))

type BossState = { unlocked: boolean, cleared: boolean, lootIn: number, rewardedToday: number, fragments: number, bonusReady: boolean }
type StepState = "beaten" | "ready" | "tooWeak" | "locked"
type Mark = "ok" | "no" | "warn"
type Line = string | { text: string, color: Color3 }

local WHITE = Color3.new(1, 1, 1)
local MAX_SIZE = Vector2.new(900, 600)
local LOCKED_FADE = 0.55
local SELECTED_SCALE = 1.08 -- the chosen step's disc, grown from its centre so it stays clear of its name
local STEP_ORDER: { StepState } = { "beaten", "ready", "tooWeak", "locked" }
local STEP_COLORS: { [StepState]: Color3 } = {
	beaten = UIStyle.GOLD,
	ready = UIStyle.GOOD,
	tooWeak = UIStyle.BAD,
	locked = UIStyle.EDGE,
}
local STEP_BADGES: { [StepState]: string? } = { beaten = "Trophy", ready = "Check", locked = "Lock" }
local STEP_WORDS: { [StepState]: string } = { beaten = "Beaten", ready = "Ready", tooWeak = "Too weak", locked = "Locked" }
local STATUS_ICONS: { [StepState]: string } = { beaten = "Trophy", ready = "Check", tooWeak = "Power", locked = "Lock" }
local STATUS_FILLS: { [StepState]: Color3 } = { beaten = UIStyle.GOLD, ready = UIStyle.GREEN, tooWeak = UIStyle.RED, locked = UIStyle.PANEL }
local MARK_COLORS: { [Mark]: Color3 } = { ok = UIStyle.GOOD, no = UIStyle.BAD, warn = UIStyle.HINT }
local TRICK_ICONS: { [string]: string } = { phases = "Gem", shield = "Lock", thunderclap = "Volt", adds = "Customer", heal = "Heart", enrage = "Angry" }
local DROP_SIZE = 46
local PHONE_DROP_SIZE = 38
local CHEST_SIZE = 32

local BossBoardController = {}

local panel: Frame
local ladder: Frame
local path: Frame -- the line the steps sit on
local pathFill: Frame -- the part of it you've climbed
local legend: Frame
local details: Frame
local states: { [string]: BossState } = {}
local receivedAt = 0 -- os.clock() when `states` arrived (lootIn counts down from then)
local partyIds: { string } = {}
local selected = 1 -- the step shown below the ladder
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
	if bold then
		UIKit.outlined(label, 2)
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
	local label = text(parent, value, UIKit.textSize("small"), UIStyle.HINT, true)
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

-- One step of the ladder: a disc with the boss's icon, a state badge, its number and name under it
local function buildStep(index: number, step: StepState, phone: boolean, isNext: boolean, power: number)
	local bossId = Bosses.LADDER[index]
	local boss = Bosses.BOSSES[bossId]
	local discSize = if phone then 44 else 64
	local node = Instance.new("TextButton")
	node.Name = `Step{index}`
	node.LayoutOrder = index
	node.BackgroundTransparency = 1
	node.Text = ""
	node.Size = UDim2.new(1 / #Bosses.LADDER, -4, 1, 0)
	node.ZIndex = ladder.ZIndex + 2
	node.Parent = ladder
	node.Activated:Connect(function()
		choose(index)
	end)
	Tooltip.attach(node, stepWords(index, step, power))

	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.new(0.5, 0, 0, discSize / 2)
	disc.Size = UDim2.fromOffset(discSize, discSize)
	disc.BackgroundColor3 = UIStyle.PANEL
	disc.BackgroundTransparency = if step == "locked" then LOCKED_FADE else 0
	disc.ZIndex = node.ZIndex + 1
	disc.Parent = node
	UIKit.corner(disc, discSize)
	UIKit.outline(disc, STEP_COLORS[step], 4)
	local scale = Instance.new("UIScale")
	scale.Scale = if index == selected then SELECTED_SCALE else 1
	scale.Parent = disc
	if step == "ready" then
		local halo = Instance.new("Frame")
		halo.AnchorPoint = Vector2.new(0.5, 0.5)
		halo.Position = UDim2.fromScale(0.5, 0.5)
		halo.Size = UDim2.new(1, 14, 1, 14)
		halo.BackgroundColor3 = UIStyle.GOOD
		halo.BackgroundTransparency = 0.7
		halo.ZIndex = disc.ZIndex - 1
		halo.Parent = disc
		UIKit.corner(halo, discSize)
	end
	local picture = Icon.make(disc, BossTints.icon(bossId), UDim2.fromScale(0.62, 0.62))
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	picture.ZIndex = disc.ZIndex + 1
	local glyph = picture:FindFirstChild("Glyph")
	if step == "locked" and glyph and glyph:IsA("ImageLabel") then
		glyph.ImageTransparency = LOCKED_FADE
	end
	local badgeIcon = STEP_BADGES[step]
	if badgeIcon then
		local badgeSize = if phone then 18 else 24
		local badge = Instance.new("Frame")
		badge.AnchorPoint = Vector2.new(1, 1)
		badge.Position = UDim2.new(1, 4, 1, 4)
		badge.Size = UDim2.fromOffset(badgeSize, badgeSize)
		badge.BackgroundColor3 = UIStyle.EDGE
		badge.ZIndex = disc.ZIndex + 2
		badge.Parent = disc
		UIKit.corner(badge, badgeSize)
		UIKit.outline(badge, STEP_COLORS[step], 2)
		local mark = Icon.make(badge, badgeIcon, UDim2.fromScale(0.8, 0.8))
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(0.5, 0.5)
		mark.ZIndex = badge.ZIndex + 1
	end
	-- The first boss still to beat wears a "Next" tag on its disc
	if isNext then
		local tag = UIKit.pill(node, "Next", UIStyle.GOLD)
		tag.AnchorPoint = Vector2.new(0.5, 0.5)
		tag.Position = UDim2.fromScale(0.5, 0)
		tag.Size = UDim2.fromOffset(0, if phone then 16 else 20)
		tag.TextSize = UIKit.textSize("small") - (if phone then 3 else 1)
		tag.ZIndex = disc.ZIndex + 4
	end

	local name = UIKit.label(node, `{index}. {boss.name}`, Enum.Font.FredokaOne, UIKit.textSize("small") - (if phone then 2 else 0), if index == selected then UIStyle.HINT else WHITE)
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.new(0.5, 0, 0, discSize + (if phone then 6 else 10))
	name.Size = UDim2.new(1, 0, 0, if phone then 24 else 34)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.TextWrapped = true
	name.ZIndex = node.ZIndex + 1
	UIKit.outlined(name, 1.5)
end

-- The badges' meanings, once, under the ladder
local function buildLegend()
	local phone = UIKit.isPhone()
	local size = if phone then 14 else 18
	for order, step in STEP_ORDER do
		local entry = strip(legend, order, size, 5)
		entry.AutomaticSize = Enum.AutomaticSize.X
		entry.Size = UDim2.fromOffset(0, size)
		local disc = Instance.new("Frame")
		disc.Size = UDim2.fromOffset(size, size)
		disc.BackgroundColor3 = UIStyle.PANEL
		disc.ZIndex = entry.ZIndex + 1
		disc.Parent = entry
		UIKit.corner(disc, size)
		UIKit.outline(disc, STEP_COLORS[step], 2)
		local badge = STEP_BADGES[step]
		if badge then
			local mark = Icon.make(disc, badge, UDim2.fromScale(0.8, 0.8))
			mark.AnchorPoint = Vector2.new(0.5, 0.5)
			mark.Position = UDim2.fromScale(0.5, 0.5)
			mark.ZIndex = disc.ZIndex + 1
		end
		text(entry, STEP_WORDS[step], UIKit.textSize("small") - (if phone then 2 else 0), WHITE, true).LayoutOrder = 2
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
	UIKit.outline(dot, UIStyle.EDGE, 2)
	return dot
end

-- One "to fight it" row: a mark, its icon (the "Icon" child), what it needs, and what you have on the right; with
-- `share`, a thin bar under it. A button, so a row can lead somewhere.
local function needRow(parent: Instance, order: number, mark: Mark, icon: string, words: string, have: string, share: number?): TextButton
	local line = 32
	local row = Instance.new("TextButton")
	row.Name = "Need"
	row.LayoutOrder = order
	row.Text = ""
	row.AutoButtonColor = false
	row.Size = UDim2.new(1, -6, 0, if share then line + 12 else line)
	row.BackgroundColor3 = UIStyle.PANEL
	row.ZIndex = (parent :: GuiObject).ZIndex + 1
	row.Parent = parent
	UIKit.corner(row, 10)
	UIKit.outline(row, UIStyle.EDGE, 2)
	local badge = markBadge(row, mark)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.fromOffset(8, line / 2)
	local picture = Icon.make(row, icon, UDim2.fromOffset(22, 22))
	picture.AnchorPoint = Vector2.new(0, 0.5)
	picture.Position = UDim2.fromOffset(34, line / 2)
	picture.ZIndex = row.ZIndex + 1
	local label = text(row, words, UIKit.textSize("small"), WHITE, true)
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.fromOffset(62, line / 2)
	local value = text(row, have, UIKit.textSize("small"), MARK_COLORS[mark], true)
	value.AnchorPoint = Vector2.new(1, 0.5)
	value.Position = UDim2.new(1, -10, 0, line / 2)
	if share then
		local track = UIKit.bar(row, share, if mark == "ok" then nil else MARK_COLORS[mark])
		track.Position = UDim2.fromOffset(34, line + 1)
		track.Size = UDim2.new(1, -44, 0, 7)
	end
	return row
end

-- What to do next: a tinted box with the advice and, when there's somewhere to go, a button
local function nextStep(parent: Instance, order: number, words: string, color: Color3, action: { label: string, icon: string, run: () -> () }?)
	local phone = UIKit.isPhone()
	local box = Instance.new("Frame")
	box.LayoutOrder = order
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.Size = UDim2.new(1, -6, 0, 0)
	box.BackgroundColor3 = color:Lerp(UIStyle.PANEL, 0.78)
	box.ZIndex = (parent :: GuiObject).ZIndex + 1
	box.Parent = parent
	UIKit.corner(box, 10)
	UIKit.outline(box, color, 2)
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 8)
	end
	padding.Parent = box
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = box
	local buttonWidth = if action then 104 else 0
	local label = wrapped(box, 1, words, WHITE)
	label.Size = UDim2.new(1, -(buttonWidth + (if action then 8 else 0)), 0, 0)
	if action then
		local button = UIKit.iconButton(box, action.label, action.icon, UIKit.Colors.Secondary)
		button.LayoutOrder = 2
		button.Size = UDim2.fromOffset(buttonWidth, if phone then UIStyle.MIN_TAP else 38)
		button.TextSize = UIKit.textSize("small")
		button.ZIndex = box.ZIndex + 1
		button.Activated:Connect(action.run)
	end
end

-- An item in a slot: its icon (a boss item in its boss's tint), a count badge, and a tooltip with what it does
local function itemCell(parent: Instance, order: number, itemId: string, size: number, count: string, lines: { Line }, faded: boolean?): Frame
	local item = Items.ITEMS[itemId]
	local cell = Instance.new("Frame")
	cell.LayoutOrder = order
	cell.Size = UDim2.fromOffset(size, size)
	cell.BackgroundColor3 = UIStyle.PANEL
	cell.BackgroundTransparency = if faded then 0.5 else 0
	cell.ZIndex = (parent :: GuiObject).ZIndex + 1
	cell.Parent = parent
	UIKit.corner(cell, 10)
	UIKit.outline(cell, UIStyle.EDGE, 2)
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
	local badge = text(cell, count, math.max(11, math.floor(size / 3.6)), WHITE, true)
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
	local label = text(holder, if opened then "-" else chance, UIKit.textSize("small") - 1, if factor < 1 then UIStyle.HINT else UIStyle.GOOD, true)
	label.LayoutOrder = 2
end

-- A chest's items in a row after its title (the first win, the day's first win)
local function chestRow(parent: Instance, order: number, title: string, color: Color3, grants: { Bosses.Grant }, when: string)
	local row = wrappingStrip(parent, order, CHEST_SIZE, 6)
	text(row, title, UIKit.textSize("small"), color, true).LayoutOrder = 0
	for index, grant in grants do
		local item = Items.ITEMS[grant.item]
		if item then
			itemCell(row, index, grant.item, CHEST_SIZE, `x{grant.count}`, { item.description, { text = `{when} · x{grant.count}`, color = color } })
		end
	end
end

-- Left column: can I fight it? Name, status, where, what to bring, the checklist, what to do next, its tricks
local function renderFight(column: ScrollingFrame, index: number, step: StepState, power: number)
	local bossId = Bosses.LADDER[index]
	local boss = Bosses.BOSSES[bossId]
	local state = states[bossId]
	local data = stepData(index, power)
	local previous = Bosses.BOSSES[Bosses.LADDER[index - 1] or ""]

	local top = strip(column, 1, 32, 8)
	text(top, boss.name, UIKit.textSize("name"), WHITE, true).LayoutOrder = 1
	local status = UIKit.pill(top, STEP_WORDS[step], STATUS_FILLS[step], nil, STATUS_ICONS[step])
	status.LayoutOrder = 2
	status.Size = UDim2.fromOffset(0, 26)
	status.ZIndex = top.ZIndex + 1
	text(column, boss.title, UIKit.textSize("small"), UIKit.Colors.Subtext).LayoutOrder = 2

	-- Its element (the Hydra changes element with each phase), where it lives, the element that hits it harder
	local pills = wrappingStrip(column, 3, 26, 6)
	local element = UIKit.pill(pills, if boss.phases then "All elements" else boss.element, if boss.phases then UIStyle.PANEL else Cards.ELEMENTS[boss.element] or UIStyle.PANEL, nil, BossTints.icon(bossId))
	element.LayoutOrder = 1
	Tooltip.attach(element, if boss.phases then "It changes element as it gets hurt." else `Its element: {boss.element}`)
	local where = UIKit.pill(pills, whereText(bossId), UIStyle.PANEL, nil, "Travel")
	where.LayoutOrder = 2
	Tooltip.attach(where, whereTip(bossId))
	local counters = if boss.phases then {} else BossRules.counterElements(Combat.BEATS, boss.element)
	local bring = UIKit.pill(pills, if counters[1] then `Bring {table.concat(counters, " or ")}` else "Bring a mix", UIStyle.PANEL, UIStyle.GOOD, counters[1] or "Cards")
	bring.LayoutOrder = 3
	Tooltip.attach(bring, if counters[1] then `{table.concat(counters, " and ")} cards hit it {Combat.STRONG}x harder.` else "Bring cards of different elements: each part of the fight has its own.")

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
		tinted(keyRow:FindFirstChild("Icon"), BossTints.key(bossId))
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

	-- What to do next
	local reason = BossRules.lockReason(data)
	if step == "beaten" then
		nextStep(column, 8, "Beaten! Fight it again for more loot.", UIStyle.GOLD, nil)
	elseif step == "ready" then
		nextStep(column, 8, "You're ready! Go to its arena and press Fight.", UIStyle.GOOD, nil)
	elseif step == "tooWeak" then
		nextStep(column, 8, "Too weak for now: level up your cards or put stronger ones in your party.", UIStyle.BAD, { label = "Party", icon = "Party", run = PartyController.Toggle })
	elseif reason == "level" then
		nextStep(column, 8, `Reach shop level {need}: sell cards to level up.`, UIStyle.BAD, nil)
	elseif unlock and previous then
		nextStep(column, 8, `Beat the {previous.name} to collect {unlock.count - have} more keys.`, UIStyle.BAD, {
			label = "See it",
			icon = "Next",
			run = function()
				choose(index - 1)
			end,
		})
	end

	-- Its tricks, spelled out (no hovering needed)
	heading(column, 9, "WATCH OUT")
	local tricks = BossRules.watchOut(boss)
	if #tricks == 0 then
		wrapped(column, 10, "No tricks: a good first boss.", UIKit.Colors.Subtext)
	end
	for order, trick in tricks do
		local line = strip(column, 10 + order, 0, 6)
		line.AutomaticSize = Enum.AutomaticSize.Y
		local layout = line:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		Icon.make(line, TRICK_ICONS[trick.kind] or "Info", UDim2.fromOffset(20, 20)).ZIndex = line.ZIndex + 1
		local words = wrapped(line, 2, `<font color="#{UIStyle.HINT:ToHex()}">{trick.name}:</font> {trick.text}`, WHITE, true)
		words.Size = UDim2.new(1, -26, 0, 0)
	end
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

	if not (state and state.cleared) then
		chestRow(column, 4, "First win", UIStyle.HINT, boss.firstClear, "Once, on your first win")
	end
	if not state or state.bonusReady then
		chestRow(column, 5, "First win today", UIStyle.GOOD, boss.dailyBonus, "Your first win each day")
	else
		iconLine(column, 5, "Gift", "Daily bonus collected: back tomorrow", UIKit.Colors.Subtext)
	end

	local pay = strip(column, 6, 24, 6)
	Icon.make(pay, "Cash", UDim2.fromOffset(22, 22)).ZIndex = pay.ZIndex + 1
	local cash = text(pay, `{boss.cash}`, UIKit.textSize("small"), UIStyle.MONEY, true)
	cash.LayoutOrder = 2
	local xpIcon = Icon.make(pay, "Xp", UDim2.fromOffset(22, 22))
	xpIcon.LayoutOrder = 3
	xpIcon.ZIndex = pay.ZIndex + 1
	local xp = text(pay, `{boss.xp} XP`, UIKit.textSize("small"), UIStyle.XP, true)
	xp.LayoutOrder = 4
	local every = text(pay, "every win", UIKit.textSize("small"), UIKit.Colors.Subtext)
	every.LayoutOrder = 5
	Tooltip.attach(pay, "Every win pays cash and XP, loot or not. Your party shares the XP.")

	if state then
		local left = BossRules.fullDropsLeft(Bosses, state.rewardedToday)
		local line = iconLine(column, 7, "Trophy", if left > 0 then `Full drops: {left} more {if left == 1 then "win" else "wins"} today` else "Fewer drops today: full again tomorrow", if left > 0 then WHITE else UIStyle.HINT)
		Tooltip.attach(line, `After {Bosses.SOFT_CAP_AFTER} loot wins in a day, drops get rarer. Every day starts fresh.`)
	end
	local threshold = math.floor(boss.recommended * Bosses.OVERPOWER_RATIO)
	if power > threshold then
		local line = iconLine(column, 8, "Power", "Party very strong: fewer drops", UIStyle.HINT)
		Tooltip.attach(line, `Over {threshold} Power this boss drops less. Climb to the next boss, or fight it with weaker cards.`)
	end

	-- Take me there (its gate here), or the normal travel to its place
	local choice = BossRules.travelChoice(boss.place, here())
	if choice == "viaPortal" then
		wrapped(column, 9, "Enter the Dungeon portal in the Frontier.", UIStyle.HINT)
	elseif choice ~= "none" then
		local label = if choice == "gate" then "Take me there" elseif choice == "toFrontier" then "Go to the Frontier" else "Go home"
		local go = UIKit.iconButton(column, label, "Travel", if choice == "gate" then UIKit.Colors.Accent else UIKit.Colors.Secondary)
		go.LayoutOrder = 9
		go.Size = UDim2.new(1, -6, 0, if phone then UIStyle.MIN_TAP else 50)
		go.TextSize = UIKit.textSize("body")
		go.ZIndex = column.ZIndex + 1
		go.Activated:Connect(function()
			if choice == "gate" then
				Remotes.BossTravel:FireServer(index)
			else
				Remotes.FrontierTravel:FireServer(if choice == "toFrontier" then "explore" else "home")
			end
			UIKit.closePanel(panel)
		end)
	end
end

local function renderDetails(index: number, step: StepState, power: number)
	clear(details)
	lootPill = nil
	local phone = UIKit.isPhone()
	local gap = if phone then 5 else 7
	local left = scroller(details, UDim2.fromOffset(10, 8), UDim2.new(0.56, -18, 1, -16), gap)
	local divider = Instance.new("Frame")
	divider.Position = UDim2.new(0.56, -1, 0, 12)
	divider.Size = UDim2.new(0, 2, 1, -24)
	divider.BackgroundColor3 = UIStyle.EDGE
	divider.BorderSizePixel = 0
	divider.ZIndex = details.ZIndex + 1
	divider.Parent = details
	local right = scroller(details, UDim2.new(0.56, 10, 0, 8), UDim2.new(0.44, -18, 1, -16), gap)
	renderFight(left, index, step, power)
	renderRewards(right, index, power)
end

render = function()
	if not panel.Visible then
		return
	end
	clear(ladder)
	local power = bestPower()
	local phone = UIKit.isPhone()
	local nextIndex, beaten = climb(power)
	for index = 1, #Bosses.LADDER do
		buildStep(index, stepOf(index, power), phone, index == nextIndex, power)
	end
	pathFill.Size = UDim2.fromScale(math.max(0, beaten - 1) / (#Bosses.LADDER - 1), 1)
	renderDetails(selected, stepOf(selected, power), power)
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

-- Big on desktops (up to MAX_SIZE), nearly the whole screen on phones
local function layout()
	local phone = UIKit.isPhone()
	panel.Size = if phone then UDim2.fromScale(0.97, 0.98) else UDim2.fromScale(0.92, 0.88)
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = MAX_SIZE
	end
	local ladderHeight = if phone then 74 else 110
	local ladderTop = UIKit.HEADER_HEIGHT + (if phone then 10 else 16)
	ladder.Position = UDim2.fromOffset(12, ladderTop)
	ladder.Size = UDim2.new(1, -24, 0, ladderHeight)
	path.Position = UDim2.new(0.07, 12, 0, ladderTop + (if phone then 44 else 64) / 2 - 3)
	local legendHeight = if phone then 14 else 18
	clear(legend)
	legend.Position = UDim2.fromOffset(12, ladderTop + ladderHeight)
	legend.Size = UDim2.new(1, -24, 0, legendHeight)
	buildLegend()
	local top = ladderTop + ladderHeight + legendHeight + (if phone then 6 else 10)
	details.Position = UDim2.fromOffset(12, top)
	details.Size = UDim2.new(1, -24, 1, -(top + (if phone then 10 else 16)))
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
	local list: ScrollingFrame
	panel, list = UIKit.panel(screenGui, "Bosses", "Boss Ladder", "Bosses")
	list:Destroy() -- the ladder and one boss's details, laid out here
	Icon.header(panel, "Trophy", UIKit.HEADER_HEIGHT)

	ladder = Instance.new("Frame")
	ladder.Name = "Ladder"
	ladder.BackgroundTransparency = 1
	ladder.ZIndex = panel.ZIndex + 1
	ladder.Parent = panel
	local steps = Instance.new("UIListLayout")
	steps.FillDirection = Enum.FillDirection.Horizontal
	steps.HorizontalAlignment = Enum.HorizontalAlignment.Center
	steps.Padding = UDim.new(0, 4)
	steps.SortOrder = Enum.SortOrder.LayoutOrder
	steps.Parent = ladder
	-- The path the steps sit on: beside the ladder, under it (a child would join its layout and be cleared)
	path = Instance.new("Frame")
	path.Name = "Path"
	path.Size = UDim2.new(0.86, -24, 0, 6)
	path.BackgroundColor3 = UIKit.Colors.Locked
	path.BorderSizePixel = 0
	path.ZIndex = panel.ZIndex
	path.Parent = panel
	UIKit.corner(path, 3)
	pathFill = Instance.new("Frame")
	pathFill.Name = "Climbed"
	pathFill.Size = UDim2.fromScale(0, 1)
	pathFill.BackgroundColor3 = UIStyle.GOLD
	pathFill.BorderSizePixel = 0
	pathFill.ZIndex = path.ZIndex
	pathFill.Parent = path
	UIKit.corner(pathFill, 3)

	legend = Instance.new("Frame")
	legend.Name = "Legend"
	legend.BackgroundTransparency = 1
	legend.ZIndex = panel.ZIndex + 1
	legend.Parent = panel
	local entries = Instance.new("UIListLayout")
	entries.FillDirection = Enum.FillDirection.Horizontal
	entries.HorizontalAlignment = Enum.HorizontalAlignment.Center
	entries.VerticalAlignment = Enum.VerticalAlignment.Center
	entries.Padding = UDim.new(0, 16)
	entries.SortOrder = Enum.SortOrder.LayoutOrder
	entries.Parent = legend

	details = Instance.new("Frame")
	details.Name = "Details"
	details.BackgroundColor3 = UIStyle.ROW
	details.ZIndex = panel.ZIndex + 1
	details.Parent = panel
	UIKit.corner(details, 14)
	UIKit.outline(details, UIStyle.EDGE, 2)

	Hud.tile({ id = "Bosses", icon = "Trophy", label = "Bosses", key = "K", group = "Bottom", order = 3, onClick = toggle })

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
