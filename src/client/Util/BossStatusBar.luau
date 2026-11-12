--!strict
-- What's on a boss now, under its HP bar (owner 2026-11-12: "every boss debuff should be shown below their healthbar
-- with tooltips"; Config/BossStatus, Util/BossStatusRules; BattleSim.statusesOf sends them in each snapshot): a chip
-- each (its icon and a small number: seconds left, a shield's size, a percentage) and, under them, the tooltip of the
-- chip hovered (or tapped: for a few seconds). BattleController puts it under the boss plate and feeds it each snapshot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossStatus = require(Shared:WaitForChild("Config"):WaitForChild("BossStatus"))
local BossStatusRules = require(Shared:WaitForChild("Util"):WaitForChild("BossStatusRules"))
local UIKit = require((script.Parent :: Instance):WaitForChild("UIKit"))

local BossStatusBar = {}

export type Bar = { holder: Frame, update: (list: { BossStatusRules.Status }?) -> (), reset: () -> () }

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- The chips' row (LayoutOrder `order`) and the tooltip (the next) in `parent` (a vertical list); `back`: their panel
-- colour, `words`: the tooltip's text colour
function BossStatusBar.new(parent: Frame, phone: boolean, order: number, back: Color3, words: Color3): Bar
	local size = if phone then BossStatus.PHONE_CHIP else BossStatus.CHIP
	local row = Instance.new("Frame")
	row.Name = "BossStatus"
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, size)
	row.BackgroundTransparency = 1
	row.Visible = false
	row.Parent = parent
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Padding = UDim.new(0, 6)
	rowList.Parent = row

	local tip = Instance.new("Frame")
	tip.Name = "BossStatusTip"
	tip.LayoutOrder = order + 1
	tip.Size = UDim2.fromOffset(BossStatus.TOOLTIP_WIDTH, 0)
	tip.AutomaticSize = Enum.AutomaticSize.Y
	tip.BackgroundColor3 = back
	tip.BackgroundTransparency = 0.06
	tip.Visible = false
	tip.Parent = parent
	UIKit.corner(tip, 10)
	local tipEdge = Instance.new("UIStroke")
	tipEdge.Thickness = 2
	tipEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tipEdge.Parent = tip
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 8)
	pad.Parent = tip
	local tipList = Instance.new("UIListLayout")
	tipList.SortOrder = Enum.SortOrder.LayoutOrder
	tipList.Padding = UDim.new(0, 2)
	tipList.Parent = tip
	local title = UIKit.label(tip, "", Enum.Font.FredokaOne, 15, Color3.new(1, 1, 1))
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 18)
	local about = UIKit.label(tip, "", Enum.Font.GothamBold, 12, words)
	about.LayoutOrder = 2
	about.Size = UDim2.new(1, 0, 0, 0)
	about.AutomaticSize = Enum.AutomaticSize.Y
	about.TextWrapped = true

	local key = ""
	local badges: { [string]: TextLabel } = {}
	local shown: { [string]: BossStatusRules.Status } = {}
	local tipKind: string? = nil
	local tipUntil = 0 -- a tapped tooltip's end (os.clock); math.huge while hovered

	local function showTip(kind: string?, seconds: number?)
		local status = if kind then shown[kind] else nil
		if not kind or not status then
			tipKind = nil
			tip.Visible = false
			return
		end
		tipKind = kind
		tipUntil = if seconds then os.clock() + seconds else math.huge
		local heading, words2 = BossStatusRules.text(status, BossStatus)
		title.Text = heading
		about.Text = words2
		tipEdge.Color = rgb(BossStatus.KINDS[kind].color)
		tip.Visible = true
	end

	local function build(list: { BossStatusRules.Status })
		for _, child in row:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		badges = {}
		for index, status in list do
			local look = BossStatus.KINDS[status.kind]
			local chip = Instance.new("TextButton")
			chip.Name = `Status_{status.kind}`
			chip.LayoutOrder = index
			chip.AutoButtonColor = false
			chip.Text = ""
			chip.Size = UDim2.fromOffset(size, size)
			chip.BackgroundColor3 = back
			chip.BackgroundTransparency = 0.1
			chip.Parent = row
			UIKit.corner(chip, 10)
			local edge = Instance.new("UIStroke")
			edge.Color = rgb(look.color)
			edge.Thickness = 2
			edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			edge.Parent = chip
			local icon = UIKit.label(chip, look.icon, Enum.Font.GothamBold, math.round(size * 0.5), Color3.new(1, 1, 1))
			icon.Size = UDim2.fromScale(1, 1)
			icon.TextXAlignment = Enum.TextXAlignment.Center
			local badge = UIKit.label(chip, "", Enum.Font.GothamBold, math.max(10, math.round(size * 0.3)), Color3.new(1, 1, 1))
			badge.AnchorPoint = Vector2.new(1, 1)
			badge.Position = UDim2.new(1, -2, 1, 0)
			badge.Size = UDim2.new(1, 0, 0, math.round(size * 0.36))
			badge.TextXAlignment = Enum.TextXAlignment.Right
			badge.TextStrokeTransparency = 0.2
			local kind = status.kind
			chip.MouseEnter:Connect(function()
				showTip(kind)
			end)
			chip.MouseLeave:Connect(function()
				if tipKind == kind and tipUntil == math.huge then
					showTip(nil)
				end
			end)
			chip.Activated:Connect(function()
				if tipKind == kind and tipUntil ~= math.huge then
					showTip(nil)
				else
					showTip(kind, BossStatus.TOOLTIP_SECONDS)
				end
			end)
			badges[kind] = badge
		end
	end

	local function update(list: { BossStatusRules.Status }?)
		local sorted = BossStatusRules.sorted(list, BossStatus)
		shown = {}
		for _, status in sorted do
			shown[status.kind] = status
		end
		local now = BossStatusRules.key(sorted)
		if now ~= key then
			key = now
			build(sorted)
		end
		row.Visible = #sorted > 0
		for _, status in sorted do
			local badge = badges[status.kind]
			if badge then
				badge.Text = BossStatusRules.badge(status)
			end
		end
		-- the open tooltip: gone with its state or its time, else its numbers refreshed
		if tipKind and (not shown[tipKind] or os.clock() > tipUntil) then
			showTip(nil)
		elseif tipKind then
			showTip(tipKind, if tipUntil == math.huge then nil else tipUntil - os.clock())
		end
	end

	local function reset()
		key = ""
		shown = {}
		tipKind = nil
		tip.Visible = false
		build({})
		row.Visible = false
	end

	return { holder = parent, update = update, reset = reset }
end

return BossStatusBar
