--!strict
-- The boss board (HUD tile "Bosses"; spec 2026-10-29-collection-screens-ui-design.md 4.7): the ladder (Config/Bosses)
-- as a path of seven steps, each a disc with the boss's icon and a badge for its state (BossRules.stepState): beaten
-- (gold ring, trophy), ready (green glow, check), too weak (red ring) or locked (faded, lock). Tapping a step shows
-- it below: where it lives, your strongest party card's Power against the Power it needs with a big verdict, or what
-- is missing as bars (shop level, key fragments); when full loot is ready again, today's rewarded wins, what it drops,
-- and "Take me there" (its gate in this place, BossTravel) or the normal travel to the place it's in. Data comes
-- from BossService (BossesChanged); the loot timers count down here between updates.
-- Also: the leader of a group forming at a gate sees "Start now" on its group prompt.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Cards = require(Config:WaitForChild("Cards"))
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
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type BossState = { unlocked: boolean, cleared: boolean, lootIn: number, rewardedToday: number, fragments: number }
type StepState = "beaten" | "ready" | "tooWeak" | "locked"

local WHITE = Color3.new(1, 1, 1)
local MAX_SIZE = Vector2.new(860, 540)
local LOCKED_FADE = 0.55
local STEP_COLORS: { [StepState]: Color3 } = {
	beaten = UIStyle.GOLD,
	ready = UIStyle.GOOD,
	tooWeak = UIStyle.BAD,
	locked = UIStyle.EDGE,
}
local STEP_BADGES: { [StepState]: string? } = { beaten = "Trophy", ready = "Check", locked = "Lock" }

local BossBoardController = {}

local panel: Frame
local ladder: Frame
local path: Frame -- the line the steps sit on
local details: Frame
local states: { [string]: BossState } = {}
local receivedAt = 0 -- os.clock() when `states` arrived (lootIn counts down from then)
local partyIds: { string } = {}
local selected = 1 -- the step shown below the ladder
local lootLabel: TextLabel? = nil -- the shown boss's loot timer line

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

-- Where this boss's step stands for you now
local function stepOf(index: number, power: number): StepState
	local bossId = Bosses.LADDER[index]
	local boss = Bosses.BOSSES[bossId]
	local state = states[bossId]
	return BossRules.stepState({
		cleared = state ~= nil and state.cleared,
		unlocked = state ~= nil and state.unlocked,
		keyNeeded = if boss.unlock then boss.unlock.count else 0,
		fragments = if state then state.fragments else 0,
		shopLevel = shopLevel(),
		needLevel = boss.shopLevel,
		power = power,
		recommended = boss.recommended,
	})
end

local function lootText(state: BossState): (string, Color3)
	local left = math.max(0, math.ceil(state.lootIn - (os.clock() - receivedAt)))
	return if left > 0 then `Full loot in {clock(left)}` else "Full loot ready now", if left > 0 then UIKit.Colors.Subtext else UIStyle.GOOD
end

local function tinted(holder: Frame, color: Color3)
	local glyph = holder:FindFirstChild("Glyph")
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

local function column(parent: Instance, position: UDim2, size: UDim2, gap: number): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Position = position
	frame.Size = size
	frame.ZIndex = (parent :: GuiObject).ZIndex
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

local function strip(parent: Instance, order: number, height: number, gap: number): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
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

-- An icon line: icon then words
local function iconLine(parent: Instance, order: number, icon: string, words: string, color: Color3): Frame
	local line = strip(parent, order, 24, 6)
	Icon.make(line, icon, UDim2.fromOffset(22, 22)).ZIndex = line.ZIndex + 1
	local label = text(line, words, UIKit.textSize("small"), color, true)
	label.LayoutOrder = 2
	return line
end

-- A labelled bar: icon, a bar `share` full, the words on the right
local function barLine(parent: Instance, order: number, icon: string, share: number, fill: Color3?, words: string, color: Color3): Frame
	local line = Instance.new("Frame")
	line.LayoutOrder = order
	line.BackgroundTransparency = 1
	line.Size = UDim2.new(1, 0, 0, 24)
	line.ZIndex = (parent :: GuiObject).ZIndex
	line.Parent = parent
	local picture = Icon.make(line, icon, UDim2.fromOffset(22, 22))
	picture.AnchorPoint = Vector2.new(0, 0.5)
	picture.Position = UDim2.fromScale(0, 0.5)
	picture.ZIndex = line.ZIndex + 1
	local track = UIKit.bar(line, share, fill)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 28, 0.5, 0)
	track.Size = UDim2.new(0.55, -28, 0, track.Size.Y.Offset)
	local label = text(line, words, UIKit.textSize("small"), color, true)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.Position = UDim2.new(0.55, 8, 0, 0)
	label.Size = UDim2.new(0.45, -8, 1, 0)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return line
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

local render: () -> ()

-- One step of the ladder: a disc with the boss's icon, a state badge, its number and name under it
local function buildStep(index: number, step: StepState, phone: boolean)
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
		selected = index
		render()
	end)

	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0)
	disc.Position = UDim2.fromScale(0.5, 0)
	disc.Size = UDim2.fromOffset(discSize, discSize)
	disc.BackgroundColor3 = UIStyle.PANEL
	disc.BackgroundTransparency = if step == "locked" then LOCKED_FADE else 0
	disc.ZIndex = node.ZIndex + 1
	disc.Parent = node
	UIKit.corner(disc, discSize)
	UIKit.outline(disc, STEP_COLORS[step], 4)
	local scale = Instance.new("UIScale")
	scale.Scale = if index == selected then 1.12 else 1
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

	local name = UIKit.label(node, `{index}. {boss.name}`, Enum.Font.FredokaOne, UIKit.textSize("small") - (if phone then 2 else 0), if index == selected then UIStyle.HINT else WHITE)
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.new(0.5, 0, 0, discSize + (if phone then 4 else 8))
	name.Size = UDim2.new(1, 0, 0, if phone then 24 else 34)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.TextWrapped = true
	name.ZIndex = node.ZIndex + 1
	UIKit.outlined(name, 1.5)
end

-- The chosen step: where it lives, Power or what's missing (left); loot, wins, drops and travel (right)
local function renderDetails(index: number, step: StepState, power: number)
	clear(details)
	lootLabel = nil
	local bossId = Bosses.LADDER[index]
	local boss = Bosses.BOSSES[bossId]
	local state = states[bossId]
	local phone = UIKit.isPhone()
	local left = column(details, UDim2.fromOffset(14, 10), UDim2.new(0.55, -20, 1, -20), if phone then 4 else 8)
	local right = column(details, UDim2.new(0.55, 6, 0, 10), UDim2.new(0.45, -20, 1, -20), if phone then 4 else 8)

	text(left, boss.name, UIKit.textSize("name"), WHITE, true).LayoutOrder = 1
	local pills = strip(left, 2, 24, 6)
	-- The Hydra changes element with each phase: every element, not its config's starting one
	local element = if boss.phases then "All elements" else boss.element
	UIKit.pill(pills, element, if boss.phases then UIStyle.ROW else Cards.ELEMENTS[boss.element] or UIStyle.ROW, nil, BossTints.icon(bossId)).LayoutOrder = 1
	UIKit.pill(pills, whereText(bossId), UIStyle.ROW, nil, "Shop").LayoutOrder = 2

	if step == "locked" then
		local level, need = shopLevel(), boss.shopLevel
		barLine(left, 3, "Level", math.min(level / need, 1), if level >= need then nil else UIStyle.BAD, `Shop level {level}/{need}`, if level >= need then UIStyle.GOOD else UIStyle.BAD)
		local unlock = boss.unlock
		if unlock and not (state and state.unlocked) then
			local have = if state then state.fragments else 0
			local keys = barLine(left, 4, "KeyFragment", math.min(have / unlock.count, 1), if have >= unlock.count then nil else UIStyle.BAD, `Keys {have}/{unlock.count}`, if have >= unlock.count then UIStyle.GOOD else UIStyle.BAD)
			tinted(keys:FindFirstChild("Icon") :: Frame, BossTints.key(bossId))
			local previous = Bosses.BOSSES[Bosses.LADDER[index - 1] or ""]
			if previous and have < unlock.count then
				text(left, `Beat the {previous.name} to collect them.`, UIKit.textSize("small"), UIKit.Colors.Subtext).LayoutOrder = 5
			end
		end
		if level < need then
			text(left, "Sell cards to level up your shop.", UIKit.textSize("small"), UIKit.Colors.Subtext).LayoutOrder = 6
		end
	else
		local top = math.max(power, boss.recommended, 1)
		barLine(left, 3, "Party", power / top, if power >= boss.recommended then nil else UIStyle.BAD, `You {power}`, UIStyle.POWER)
		barLine(left, 4, "Power", boss.recommended / top, UIStyle.POWER, `Needed {boss.recommended}`, UIStyle.POWER)
		local strong = power >= boss.recommended
		local verdict = UIKit.pill(strip(left, 5, 34, 0), if strong then "You're ready!" else "Too weak", if strong then UIStyle.GREEN else UIStyle.RED, nil, if strong then "Check" else "Remove")
		verdict.Size = UDim2.fromOffset(0, 30)
		verdict.TextSize = UIKit.textSize("body")
	end

	if state then
		local words, color = lootText(state)
		local loot = iconLine(right, 1, "Hourglass", words, color)
		lootLabel = loot:FindFirstChildWhichIsA("TextLabel")
		local wins = `Won {state.rewardedToday} {if state.rewardedToday == 1 then "time" else "times"} today`
		if state.rewardedToday >= Bosses.SOFT_CAP_AFTER then
			wins ..= " · fewer drops"
		elseif power > boss.recommended * Bosses.OVERPOWER_RATIO then
			wins ..= " · fewer drops (party too strong)"
		end
		iconLine(right, 2, "Trophy", wins, WHITE)
	end

	-- What it drops, as icons (hover for the name)
	local drops = strip(right, 3, if phone then 30 else 36, 4)
	Icon.make(drops, "Gift", UDim2.fromOffset(22, 22)).ZIndex = drops.ZIndex + 1
	local dropName = text(right, "", UIKit.textSize("small"), UIKit.Colors.Subtext)
	dropName.LayoutOrder = 4
	local seen: { [string]: boolean } = {}
	for order, drop in boss.drops do
		local item = Items.ITEMS[drop.item]
		if item and not seen[drop.item] then
			seen[drop.item] = true
			local cell = Instance.new("Frame")
			cell.LayoutOrder = 1 + order
			cell.Size = UDim2.fromOffset(if phone then 28 else 34, if phone then 28 else 34)
			cell.BackgroundColor3 = UIStyle.PANEL
			cell.ZIndex = drops.ZIndex + 1
			cell.Parent = drops
			UIKit.corner(cell, 8)
			UIKit.outline(cell, UIStyle.EDGE, 2)
			local picture = Icon.make(cell, item.icon, UDim2.fromScale(0.8, 0.8))
			picture.AnchorPoint = Vector2.new(0.5, 0.5)
			picture.Position = UDim2.fromScale(0.5, 0.5)
			picture.ZIndex = cell.ZIndex + 1
			local opens = ItemRules.bossOf(drop.item, Bosses.LADDER)
			if opens then
				tinted(picture, BossTints.key(Bosses.LADDER[opens]))
			end
			cell.MouseEnter:Connect(function()
				dropName.Text = item.name
			end)
			cell.MouseLeave:Connect(function()
				dropName.Text = ""
			end)
		end
	end

	-- Take me there (its gate here), or the normal travel to its place
	local choice = BossRules.travelChoice(boss.place, here())
	if choice == "viaPortal" then
		local line = iconLine(right, 5, "Info", "Enter the Dungeon portal in the Frontier", UIStyle.HINT)
		line.Size = UDim2.new(1, 0, 0, 36)
		local words = line:FindFirstChildWhichIsA("TextLabel") :: TextLabel
		words.AutomaticSize = Enum.AutomaticSize.None
		words.TextWrapped = true
		words.Size = UDim2.new(1, -28, 1, 0)
	elseif choice ~= "none" then
		local label = if choice == "gate" then "Take me there" elseif choice == "toFrontier" then "Go to the Frontier" else "Go home"
		local go = UIKit.iconButton(right, label, "Travel", if choice == "gate" then UIKit.Colors.Accent else UIKit.Colors.Secondary)
		go.LayoutOrder = 5
		go.Size = UDim2.new(1, 0, 0, 50)
		go.TextSize = UIKit.textSize("body")
		go.ZIndex = right.ZIndex + 1
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

render = function()
	if not panel.Visible then
		return
	end
	clear(ladder)
	local power = bestPower()
	local phone = UIKit.isPhone()
	for index = 1, #Bosses.LADDER do
		buildStep(index, stepOf(index, power), phone)
	end
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
	panel.Size = if phone then UDim2.fromScale(0.97, 0.98) else UDim2.fromScale(0.92, 0.86)
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = MAX_SIZE
	end
	local ladderHeight = if phone then 74 else 112
	local ladderTop = UIKit.HEADER_HEIGHT + (if phone then 6 else 14)
	ladder.Position = UDim2.fromOffset(12, ladderTop)
	ladder.Size = UDim2.new(1, -24, 0, ladderHeight)
	path.Position = UDim2.new(0.07, 12, 0, ladderTop + (if phone then 44 else 64) / 2 - 3)
	local top = ladderTop + ladderHeight + (if phone then 4 else 10)
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
	local scroller: ScrollingFrame
	panel, scroller = UIKit.panel(screenGui, "Bosses", "Boss Ladder", "Bosses")
	scroller:Destroy() -- the ladder and one boss's details, no scrolling
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
		local label = lootLabel
		if state and label and label.Parent then
			label.Text, label.TextColor3 = lootText(state)
		end
	end)
end

return BossBoardController
