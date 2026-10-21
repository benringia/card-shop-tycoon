--!strict
-- Small buff badge above the cash in the bottom-right status corner while a summoned creature gives a perk ("⚡ +10%"). Hover it (or tap
-- on a phone) for a tooltip saying what the buff does and which party card it comes from.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Party = require(Config:WaitForChild("Party"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type Perk = { kind: string, value: number, text: string }

local TAP_TOOLTIP_SECONDS = 4
local POP_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local BuffController = {}

local badge: TextButton
local pill: TextLabel
local pillStroke: UIStroke
local pillScale: UIScale
local tooltip: Frame
local tooltipTitle: TextLabel
local tooltipBody: TextLabel
local perk: Perk? = nil
local sourceBeastId: string? = nil
local tapToken = 0

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
	return `From {card.name} ({BeastRules.describeGrowth(beast.level, beast.stars)}), your summoned party creature. More stars make it stronger. Change it in Party.`
end

local function showTooltip(visible: boolean)
	local current = perk
	if visible and current then
		-- Just above the badge, right edges lined up
		tooltip.Position = UDim2.fromOffset(badge.AbsolutePosition.X + badge.AbsoluteSize.X, badge.AbsolutePosition.Y - 4)
		local icon, color = getPerkLook(current.kind)
		tooltipTitle.Text = `{icon} {current.text}`
		tooltipTitle.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3)
		tooltipBody.Text = describeSource()
	end
	tooltip.Visible = visible and current ~= nil
end

local function update(newPerk: Perk?, newSource: string?)
	local appeared = newPerk ~= nil and (perk == nil or perk.kind ~= newPerk.kind)
	perk, sourceBeastId = newPerk, newSource
	if not newPerk then
		badge.Visible = false
		tooltip.Visible = false
		return
	end
	local icon, color = getPerkLook(newPerk.kind)
	pill.Text = `{icon} +{math.round(newPerk.value * 100)}%`
	pillStroke.Color = color
	badge.Visible = true
	if tooltip.Visible then
		showTooltip(true)
	end
	if appeared then
		-- A small pop instead of a toast: noticeable, not loud
		pillScale.Scale = 0.6
		TweenService:Create(pillScale, POP_TWEEN, { Scale = 1 }):Play()
	end
end

function BuffController.Start()
	local screenGui = UIController.GetScreenGui()

	-- 48px tall hit area (phones), with a smaller pill drawn inside it; sits above the cash
	badge = Instance.new("TextButton")
	badge.Name = "BuffBadge"
	badge.LayoutOrder = 1
	badge.Text = ""
	badge.AutoButtonColor = false
	badge.BackgroundTransparency = 1
	badge.Size = UDim2.fromOffset(48, 48)
	badge.AutomaticSize = Enum.AutomaticSize.X
	badge.Visible = false
	badge.Parent = UIController.GetStatusFrame()

	pill = UIKit.label(badge, "", Enum.Font.GothamBold, 14, UIKit.Colors.Text)
	pill.AnchorPoint = Vector2.new(0, 0.5)
	pill.Position = UDim2.fromScale(0, 0.5)
	pill.Size = UDim2.fromOffset(0, 28)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.TextXAlignment = Enum.TextXAlignment.Center
	pill.BackgroundColor3 = UIKit.Colors.Panel
	pill.BackgroundTransparency = 0.35
	UIKit.corner(pill, 14)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = pill
	pillStroke = Instance.new("UIStroke")
	pillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pillStroke.Thickness = 1.5
	pillStroke.Transparency = 0.2
	pillStroke.Parent = pill
	pillScale = Instance.new("UIScale")
	pillScale.Parent = pill

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

	badge.MouseEnter:Connect(function()
		showTooltip(true)
	end)
	badge.MouseLeave:Connect(function()
		showTooltip(false)
	end)
	-- Phones have no hover: a tap shows it for a few seconds
	badge.Activated:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		tapToken += 1
		local token = tapToken
		showTooltip(not tooltip.Visible)
		task.delay(TAP_TOOLTIP_SECONDS, function()
			if tapToken == token then
				showTooltip(false)
			end
		end)
	end)

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
