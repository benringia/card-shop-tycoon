--!strict
-- The buffs on you, by your character info in the party dock (owner 2026-11-13, buffs pick A, then "buffs should appear
-- near the character info side"): a summoned creature's perk, Pish's Luck while it lasts (the PishLuckUntil attribute,
-- Server/Services/PishService) and Chikin's Courage (ChikinCourageUntil, Server/Services/TownChikinService), each a
-- round icon without words, two high; a timed one in a ring that empties as it runs out (LuckRules.share). The icons
-- are one target (BuffController.GetStack, which PartyBarController puts in your row: left of your face on a phone,
-- after your bars on a computer): hover it, or tap it, for a tooltip listing every buff.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Chikin = require(Config:WaitForChild("Chikin"))
local Pish = require(Config:WaitForChild("Pish"))
local HudLayout = require(Config:WaitForChild("HudLayout"))
local Party = require(Config:WaitForChild("Party"))
local CompactHud = require(Shared:WaitForChild("Util"):WaitForChild("CompactHud"))
local LuckRules = require(Shared:WaitForChild("Util"):WaitForChild("LuckRules"))
local PartyRules = require(Shared:WaitForChild("Util"):WaitForChild("PartyRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local Hud = require(ClientUtil:WaitForChild("Hud"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type Perk = { kind: string, value: number, text: string }

-- A buff's round icon; `fill` turns a timed one's ring, `time` its "2:41" for the tooltip
type Buff = {
	active: boolean,
	icon: Frame,
	glyph: TextLabel,
	edge: UIStroke,
	pop: UIScale,
	fill: ((number) -> ())?,
	time: string,
}

local TAP_TOOLTIP_SECONDS = 4
local POP_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local LUCK_GREEN = Color3.fromRGB(70, 175, 95)
local COURAGE_RED = Color3.fromRGB(230, 95, 70)
local COURAGE_ICON = "💪"
local LUCK_TICK = 0.25 -- seconds between countdown updates
local ICONS = HudLayout.BUFF_ICONS

local BuffController = {}

local player = Players.LocalPlayer
local stack: TextButton
local creature: Buff
local luck: Buff
local courage: Buff
local tooltip: Frame
local tooltipBody: TextLabel
local perk: Perk? = nil
local sourceBeastId: string? = nil
local tapToken = 0
local running: { [Buff]: boolean } = {} -- a timed buff's countdown is going (one at a time)

-- Icon and element colour for a perk kind ("Hustle" -> the Volt icon and colour)
local function getPerkLook(kind: string): (string, Color3)
	for element, entry in Party.PERKS do
		if entry.kind == kind then
			return entry.icon, Cards.ELEMENTS[element] or UIKit.Colors.Accent
		end
	end
	return "", UIKit.Colors.Accent
end

-- One line per buff on you: what it does, where it's from, how long is left
local function buffLines(): { string }
	local lines: { string } = {}
	local current = perk
	if creature.active and current then
		local icon = getPerkLook(current.kind)
		local beast = if sourceBeastId then BinderController.GetBeasts()[sourceBeastId] else nil
		local card = if beast then Cards.ById[beast.cardId] else nil
		local line = `{icon} {current.text}` .. (if card then ` · from {card.name}` else "")
		local fight = if card and beast then PartyRules.getFightPerk(Party, card.element, card.rarity, beast.stars) else nil
		if fight then
			line ..= ` · in fights: {PartyRules.describeFight(fight)}`
		end
		table.insert(lines, line)
	end
	if luck.active then
		table.insert(lines, `{luck.time} · Pish's Luck: better pulls in your packs`)
	end
	if courage.active then
		table.insert(lines, `{courage.time} · Chikin's Courage: your creatures hit {math.round(Chikin.COURAGE.share * 100)}% harder`)
	end
	return lines
end

-- The tooltip listing every buff: under the icons on a phone (they're at the top), over them on a computer (bottom left)
local function showTooltip(visible: boolean)
	local lines = buffLines()
	local shown = visible and #lines > 0
	if shown then
		local at, size = stack.AbsolutePosition, stack.AbsoluteSize
		if UIController.IsCompact() then
			tooltip.AnchorPoint = Vector2.new(1, 0)
			tooltip.Position = UDim2.fromOffset(at.X + size.X, at.Y + size.Y + 4)
		else
			tooltip.AnchorPoint = Vector2.new(0, 1)
			tooltip.Position = UDim2.fromOffset(at.X, at.Y - 4)
		end
		tooltipBody.Text = table.concat(lines, "\n")
	end
	tooltip.Visible = shown
end

-- The icons show while any buff is on (none leaves no gap in your row); hidden through the tours
local function refresh()
	local any = creature.active or luck.active or courage.active
	stack.Visible = any and not Hud.hides("buffs")
	if not any and tooltip.Visible then
		tooltip.Visible = false
	end
end

-- A small pop instead of a toast: noticeable, not loud
local function pop(buff: Buff)
	buff.pop.Scale = 0.6
	TweenService:Create(buff.pop, POP_TWEEN, { Scale = 1 }):Play()
end

local function setActive(buff: Buff, on: boolean)
	local appeared = on and not buff.active
	buff.active = on
	buff.icon.Visible = on
	if appeared then
		pop(buff)
	end
end

local function update(newPerk: Perk?, newSource: string?)
	perk, sourceBeastId = newPerk, newSource
	if newPerk then
		local icon, color = getPerkLook(newPerk.kind)
		creature.glyph.Text = icon
		creature.edge.Color = color
	end
	setActive(creature, newPerk ~= nil)
	refresh()
	if tooltip.Visible then
		showTooltip(true)
	end
end

-- A timed buff counting down from its attribute (`untilName`), then hidden; `length` its full time (its ring)
local function runTimed(buff: Buff, untilName: string, length: number, icon: string?)
	if running[buff] then
		return
	end
	running[buff] = true
	task.spawn(function()
		while true do
			local untilTime = player:GetAttribute(untilName) :: number?
			local now = workspace:GetServerTimeNow()
			local text = LuckRules.badgeText(untilTime, now, icon)
			setActive(buff, text ~= nil)
			refresh()
			if not text then
				break
			end
			buff.time = text
			local fill = buff.fill
			if fill then
				fill(LuckRules.share(untilTime, now, length))
			end
			task.wait(LUCK_TICK)
		end
		running[buff] = nil
	end)
end

local function runLuck()
	runTimed(luck, "PishLuckUntil", Pish.LUCK.seconds, nil)
end

local function runCourage()
	runTimed(courage, "ChikinCourageUntil", Chikin.COURAGE.seconds, COURAGE_ICON)
end

-- A ring round a round icon that empties as a timed buff runs out: two clipped halves whose strokes' gradients turn
-- (CompactHud.ring); returns its setter (0-1 left)
local function makeRing(parent: GuiObject, color: Color3): (number) -> ()
	local size = ICONS.icon
	local function circle(holder: Instance, name: string, stroke: Color3): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromOffset(size, size)
		frame.Parent = holder
		UIKit.corner(frame, size / 2)
		local edge = Instance.new("UIStroke")
		edge.Color = stroke
		edge.Thickness = ICONS.ring
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Parent = frame
		return frame
	end
	local track = circle(parent, "RingTrack", ICONS.track)
	local trackEdge = track:FindFirstChildOfClass("UIStroke") :: UIStroke
	trackEdge.Transparency = 0.4
	local halves: { UIGradient } = {}
	for index, side in { "Right", "Left" } do
		local half = Instance.new("Frame")
		half.Name = side
		half.BackgroundTransparency = 1
		half.ClipsDescendants = true
		half.Position = UDim2.fromOffset(if side == "Right" then size / 2 else 0, 0)
		half.Size = UDim2.fromOffset(size / 2, size)
		half.ZIndex = 3
		half.Parent = parent
		local ring = circle(half, "Fill", color)
		ring.Position = UDim2.fromOffset(if side == "Right" then -size / 2 else 0, 0)
		local turn = Instance.new("UIGradient")
		turn.Transparency = if side == "Right"
			then NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1) })
			else NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(0.501, 0), NumberSequenceKeypoint.new(1, 0) })
		turn.Parent = ring:FindFirstChildOfClass("UIStroke")
		halves[index] = turn
	end
	return function(share: number)
		local right, left = CompactHud.ring(share)
		halves[1].Rotation = right
		halves[2].Rotation = left
	end
end

-- A buff's round icon: a white disc with its emoji, edged in its colour; a timed one (`ring`) in a ring that empties
local function makeBuff(name: string, order: number, color: Color3, glyphText: string, ring: boolean): Buff
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.LayoutOrder = order
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Size = UDim2.fromOffset(ICONS.icon, ICONS.icon)
	frame.Visible = false
	frame.Parent = stack
	UIKit.corner(frame, ICONS.icon / 2)
	local edge = UIKit.outline(frame, color, 2)
	edge.Enabled = not ring
	local glyph = UIKit.label(frame, glyphText, Enum.Font.FredokaOne, 14, UIKit.Colors.Text)
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	glyph.ZIndex = 2
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	return {
		active = false,
		icon = frame,
		glyph = glyph,
		edge = edge,
		pop = scale,
		fill = if ring then makeRing(frame, color) else nil,
		time = "",
	}
end

function BuffController.Start()
	-- The icons: two high (your row's height), a third starts a column; one hover / tap target
	stack = Instance.new("TextButton")
	stack.Name = "BuffStack"
	stack.Text = ""
	stack.AutoButtonColor = false
	stack.BackgroundTransparency = 1
	stack.Size = UDim2.new(0, ICONS.width, 1, 0)
	stack.Visible = false
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(ICONS.icon, ICONS.icon)
	grid.CellPadding = UDim2.fromOffset(ICONS.gap, ICONS.gap)
	grid.FillDirection = Enum.FillDirection.Vertical
	grid.FillDirectionMaxCells = 2
	grid.StartCorner = Enum.StartCorner.TopRight
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Right
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = stack
	-- toward your bars on a computer (the icons come after them), toward your face on a phone (before it)
	UIController.OnCompact(function(on: boolean)
		grid.StartCorner = if on then Enum.StartCorner.TopRight else Enum.StartCorner.TopLeft
		grid.HorizontalAlignment = if on then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
	end)
	stack.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled then
			showTooltip(true)
		end
	end)
	stack.MouseLeave:Connect(function()
		showTooltip(false)
	end)
	stack.Activated:Connect(function()
		tapToken += 1
		local token = tapToken
		showTooltip(not tooltip.Visible)
		task.delay(TAP_TOOLTIP_SECONDS, function()
			if tapToken == token then
				showTooltip(false)
			end
		end)
	end)

	creature = makeBuff("BuffBadge", 1, UIKit.Colors.Accent, "", false)
	luck = makeBuff("LuckBadge", 2, LUCK_GREEN, "🍀", true)
	courage = makeBuff("CourageBadge", 3, COURAGE_RED, COURAGE_ICON, true)

	tooltip = Instance.new("Frame")
	tooltip.Name = "BuffTooltip"
	tooltip.Size = UDim2.fromOffset(260, 0)
	tooltip.AutomaticSize = Enum.AutomaticSize.Y
	tooltip.BackgroundColor3 = UIKit.Colors.Panel
	tooltip.BackgroundTransparency = 0.05
	tooltip.Visible = false
	tooltip.ZIndex = 50 -- over the weapon switch and the dock
	tooltip.Parent = UIController.GetScreenGui()
	UIKit.corner(tooltip, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = tooltip
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tooltip
	local title = UIKit.label(tooltip, "Your buffs", Enum.Font.GothamBold, 14, UIKit.Colors.Text)
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 0)
	title.AutomaticSize = Enum.AutomaticSize.Y
	tooltipBody = UIKit.label(tooltip, "", Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
	tooltipBody.LayoutOrder = 2
	tooltipBody.Size = UDim2.new(1, 0, 0, 0)
	tooltipBody.AutomaticSize = Enum.AutomaticSize.Y
	tooltipBody.TextWrapped = true

	player:GetAttributeChangedSignal("PishLuckUntil"):Connect(runLuck)
	player:GetAttributeChangedSignal("ChikinCourageUntil"):Connect(runCourage)
	Hud.onCalm(refresh)
	runLuck()
	runCourage()

	Remotes.PartyChanged.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local source: string? = nil
		if typeof(payload.slots) == "table" then
			for _, entry in payload.slots do
				if typeof(entry) == "table" and entry.slot == payload.summoned then
					source = entry.beastId
				end
			end
		end
		update(if typeof(payload.perk) == "table" then payload.perk else nil, source)
	end)
end

-- The buffs' icons (the party dock's row holds them: left of your face on a phone, after your bars on a computer)
function BuffController.GetStack(): TextButton
	return stack
end

return BuffController
