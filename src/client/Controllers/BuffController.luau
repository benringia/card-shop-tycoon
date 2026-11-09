--!strict
-- Small buff badges above the cash in the status corner, side by side in one row: a summoned creature's perk
-- ("⚡ +10%") and Pish's Luck while it lasts ("🍀 2:41", from the PishLuckUntil attribute, Server/Services/PishService).
-- Hover one (or tap on a phone) for a tooltip saying what it does and where it comes from.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Party = require(Config:WaitForChild("Party"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local LuckRules = require(Shared:WaitForChild("Util"):WaitForChild("LuckRules"))
local PartyRules = require(Shared:WaitForChild("Util"):WaitForChild("PartyRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type Perk = { kind: string, value: number, text: string }

local TAP_TOOLTIP_SECONDS = 4
local POP_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local LUCK_GREEN = Color3.fromRGB(70, 175, 95)
local LUCK_TICK = 0.25 -- seconds between countdown updates

local BuffController = {}

type Chip = { badge: TextButton, pill: TextLabel, stroke: UIStroke, scale: UIScale }

local player = Players.LocalPlayer
local row: Frame
local creature: Chip
local luck: Chip
local tooltip: Frame
local tooltipTitle: TextLabel
local tooltipBody: TextLabel
local tooltipFor: Chip? = nil
local perk: Perk? = nil
local sourceBeastId: string? = nil
local tapToken = 0
local luckRunning = false

-- Icon and element colour for a perk kind ("Hustle" -> the Volt icon and colour)
local function getPerkLook(kind: string): (string, Color3)
	for element, entry in Party.PERKS do
		if entry.kind == kind then
			return entry.icon, Cards.ELEMENTS[element] or UIKit.Colors.Accent
		end
	end
	return "", UIKit.Colors.Accent
end

local function describeSource(): string
	local beast = if sourceBeastId then BinderController.GetBeasts()[sourceBeastId] else nil
	local card = if beast then Cards.ById[beast.cardId] else nil
	if not beast or not card then
		return "From your summoned party creature."
	end
	local fight = PartyRules.getFightPerk(Party, card.element, card.rarity, beast.stars)
	local fightLine = if fight then `In fights: {PartyRules.describeFight(fight)}. ` else ""
	return `{fightLine}From {card.name} ({BeastRules.describeGrowth(beast.level, beast.stars)}), your summoned party creature. More stars make it stronger. Change it in Party.`
end

-- The tooltip over a chip, right edges lined up: the creature's perk and its card, or Pish's Luck
local function showTooltip(chip: Chip, visible: boolean)
	local current = perk
	local shown = visible and (chip == luck or current ~= nil)
	if shown then
		local badge = chip.badge
		tooltip.Position = UDim2.fromOffset(badge.AbsolutePosition.X + badge.AbsoluteSize.X, badge.AbsolutePosition.Y - 4)
		if chip == luck then
			tooltipTitle.Text = "🍀 Pish's Luck · better pulls"
			tooltipTitle.TextColor3 = LUCK_GREEN:Lerp(Color3.new(1, 1, 1), 0.3)
			tooltipBody.Text = "Petting Pish makes Very Rare, Epic and Legendary cards more likely in your packs for a while."
		elseif current then
			local icon, color = getPerkLook(current.kind)
			tooltipTitle.Text = `{icon} {current.text}`
			tooltipTitle.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3)
			tooltipBody.Text = describeSource()
		end
	end
	tooltipFor = if shown then chip else nil
	tooltip.Visible = shown
end

-- The row shows while either chip does (an empty one would still take a gap in the column)
local function refreshRow()
	row.Visible = creature.badge.Visible or luck.badge.Visible
	if tooltipFor and not tooltipFor.badge.Visible then
		showTooltip(tooltipFor, false)
	end
end

-- A small pop instead of a toast: noticeable, not loud
local function pop(chip: Chip)
	chip.scale.Scale = 0.6
	TweenService:Create(chip.scale, POP_TWEEN, { Scale = 1 }):Play()
end

local function update(newPerk: Perk?, newSource: string?)
	local appeared = newPerk ~= nil and (perk == nil or perk.kind ~= newPerk.kind)
	perk, sourceBeastId = newPerk, newSource
	if not newPerk then
		creature.badge.Visible = false
		refreshRow()
		return
	end
	local icon, color = getPerkLook(newPerk.kind)
	creature.pill.Text = `{icon} +{math.round(newPerk.value * 100)}%`
	creature.pill.TextColor3 = color:Lerp(Color3.new(0, 0, 0), 0.25) -- the perk's colour, a touch darker to read on white
	creature.stroke.Color = color
	creature.badge.Visible = true
	refreshRow()
	if tooltipFor == creature then
		showTooltip(creature, true)
	end
	if appeared then
		pop(creature)
	end
end

-- Pish's Luck counting down to 0:00, then hidden
local function runLuck()
	if luckRunning then
		return
	end
	luckRunning = true
	task.spawn(function()
		local first = true
		while true do
			local text = LuckRules.badgeText(player:GetAttribute("PishLuckUntil") :: number?, workspace:GetServerTimeNow())
			luck.badge.Visible = text ~= nil
			refreshRow()
			if not text then
				break
			end
			luck.pill.Text = text
			if first then
				first = false
				pop(luck)
			end
			task.wait(LUCK_TICK)
		end
		luckRunning = false
	end)
end

-- A 48px tall hit area (phones) with a small white chip drawn inside it (the creature pals look, spec 2026-11-03)
local function makeChip(name: string, order: number): Chip
	local badge = Instance.new("TextButton")
	badge.Name = name
	badge.LayoutOrder = order
	badge.Text = ""
	badge.AutoButtonColor = false
	badge.BackgroundTransparency = 1
	badge.Size = UDim2.fromOffset(48, 48)
	badge.AutomaticSize = Enum.AutomaticSize.X
	badge.Visible = false
	badge.Parent = row

	local pill = UIKit.label(badge, "", Enum.Font.FredokaOne, 14, UIKit.Colors.Text)
	pill.AnchorPoint = Vector2.new(0, 0.5)
	pill.Position = UDim2.fromScale(0, 0.5)
	pill.Size = UDim2.fromOffset(0, 28)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.TextXAlignment = Enum.TextXAlignment.Center
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.BackgroundTransparency = 0
	UIKit.corner(pill, 14)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = pill
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 1.5
	stroke.Transparency = 0.2
	stroke.Parent = pill
	local scale = Instance.new("UIScale")
	scale.Parent = pill
	local chip: Chip = { badge = badge, pill = pill, stroke = stroke, scale = scale }

	badge.MouseEnter:Connect(function()
		showTooltip(chip, true)
	end)
	badge.MouseLeave:Connect(function()
		showTooltip(chip, false)
	end)
	-- Phones have no hover: a tap shows it for a few seconds
	badge.Activated:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		tapToken += 1
		local token = tapToken
		showTooltip(chip, tooltipFor ~= chip)
		task.delay(TAP_TOOLTIP_SECONDS, function()
			if tapToken == token then
				showTooltip(chip, false)
			end
		end)
	end)
	return chip
end

function BuffController.Start()
	local screenGui = UIController.GetScreenGui()

	-- One row above the cash: the creature's chip, then Pish's Luck to its right
	row = Instance.new("Frame")
	row.Name = "BuffRow"
	row.LayoutOrder = 1
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(0, 48)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Visible = false
	row.Parent = UIController.GetStatusFrame()
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = row

	creature = makeChip("BuffBadge", 1)
	luck = makeChip("LuckBadge", 2)
	luck.pill.TextColor3 = LUCK_GREEN:Lerp(Color3.new(0, 0, 0), 0.25)
	luck.stroke.Color = LUCK_GREEN

	tooltip = Instance.new("Frame")
	tooltip.Name = "BuffTooltip"
	tooltip.AnchorPoint = Vector2.new(1, 1)
	tooltip.Size = UDim2.fromOffset(250, 0)
	tooltip.AutomaticSize = Enum.AutomaticSize.Y
	tooltip.BackgroundColor3 = UIKit.Colors.Panel
	tooltip.BackgroundTransparency = 0.05
	tooltip.Visible = false
	tooltip.Parent = screenGui
	UIKit.corner(tooltip, 10)
	local tooltipPadding = Instance.new("UIPadding")
	tooltipPadding.PaddingTop = UDim.new(0, 8)
	tooltipPadding.PaddingBottom = UDim.new(0, 8)
	tooltipPadding.PaddingLeft = UDim.new(0, 10)
	tooltipPadding.PaddingRight = UDim.new(0, 10)
	tooltipPadding.Parent = tooltip
	local tooltipLayout = Instance.new("UIListLayout")
	tooltipLayout.Padding = UDim.new(0, 4)
	tooltipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tooltipLayout.Parent = tooltip
	tooltipTitle = UIKit.label(tooltip, "", Enum.Font.GothamBold, 14, UIKit.Colors.Text)
	tooltipTitle.LayoutOrder = 1
	tooltipTitle.Size = UDim2.new(1, 0, 0, 0)
	tooltipTitle.AutomaticSize = Enum.AutomaticSize.Y
	tooltipTitle.TextWrapped = true
	tooltipBody = UIKit.label(tooltip, "", Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
	tooltipBody.LayoutOrder = 2
	tooltipBody.Size = UDim2.new(1, 0, 0, 0)
	tooltipBody.AutomaticSize = Enum.AutomaticSize.Y
	tooltipBody.TextWrapped = true

	player:GetAttributeChangedSignal("PishLuckUntil"):Connect(runLuck)
	runLuck()

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

return BuffController
