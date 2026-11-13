--!strict
-- The shop rating on the HUD (spec 2026-11-06-customers-design): a chip in the status column (between cash and XP) with
-- five stars filled by quarters and the number, from RatingService's RatingUpdate. Tapping it opens a cotton candy tips
-- window: a line per rating part that counts (✅ good, ⚠️ what to fix, Config/Customers RATING_TIPS) and how often
-- customers come. It hides with the rest of the status column.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Customers = require(Config:WaitForChild("Customers"))
local CreamTheme = require(Config:WaitForChild("CreamTheme"))
local UIIcons = require(Config:WaitForChild("UIIcons"))
local RatingRules = require(Shared:WaitForChild("Util"):WaitForChild("RatingRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local UIKit = require((Controllers.Parent :: Instance):WaitForChild("Util"):WaitForChild("UIKit"))
local Tooltip = require((Controllers.Parent :: Instance):WaitForChild("Util"):WaitForChild("Tooltip"))
local UIController = require(Controllers:WaitForChild("UIController"))

type Part = { name: string, score: number, weight: number, known: boolean? }
type Update = { rating: number, parts: { Part } }

local RatingController = {}

local chip: TextButton
local fills: { Frame } = {}
local numberLabel: TextLabel
local window: Frame
local list: ScrollingFrame
local latest: Update? = nil

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function addStar(parent: Instance, order: number, size: number): Frame
	local slot = Instance.new("Frame")
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.fromOffset(size, size)
	slot.LayoutOrder = order
	slot.Parent = parent
	local dim = Instance.new("ImageLabel")
	dim.BackgroundTransparency = 1
	dim.Size = UDim2.fromScale(1, 1)
	dim.Image = UIIcons.Star
	dim.ImageTransparency = Customers.RATING.sign.dim
	dim.Parent = slot
	local clip = Instance.new("Frame")
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(0, 1)
	clip.Parent = slot
	local star = Instance.new("ImageLabel")
	star.BackgroundTransparency = 1
	star.Size = UDim2.fromOffset(size, size)
	star.Image = UIIcons.Star
	star.ImageColor3 = rgb(Customers.RATING.sign.color)
	star.Parent = clip
	return clip
end

local function buildChip()
	local look = Customers.RATING.chip
	chip = Instance.new("TextButton")
	chip.Name = "Rating"
	chip.LayoutOrder = 3 -- between cash (2) and XP (4)
	chip.Text = ""
	chip.AutoButtonColor = false
	chip.BackgroundTransparency = 1
	chip.Size = UDim2.fromOffset(0, look.hit)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Visible = false
	chip.Parent = UIController.GetStatusFrame()

	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0, 0.5)
	pill.Position = UDim2.fromScale(0, 0.5)
	pill.Size = UDim2.fromOffset(0, look.height)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = rgb(CreamTheme.row)
	pill.Parent = chip
	UIKit.corner(pill, look.height / 2)
	UIKit.outline(pill, rgb(CreamTheme.rowEdge), 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = pill
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 2)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = pill
	for index = 1, 5 do
		table.insert(fills, addStar(pill, index, look.star))
	end
	numberLabel = UIKit.label(pill, "", Enum.Font.FredokaOne, look.text, rgb(CreamTheme.ink))
	numberLabel.LayoutOrder = 6
	numberLabel.TextWrapped = false
	numberLabel.AutomaticSize = Enum.AutomaticSize.X
	numberLabel.Size = UDim2.fromOffset(0, look.height)
	local gap = Instance.new("UIPadding")
	gap.PaddingLeft = UDim.new(0, 6)
	gap.Parent = numberLabel
end

-- Its tooltip under a mouse (owner 2026-11-13: "Add tool tip on the shop rating on the bottom right")
local function addTooltip()
	Tooltip.rich(chip, "Shop rating", {
		"How customers rate your shop: stock, prices, cards on display, service and decor.",
		"A higher rating brings customers more often.",
		"Click it for what to fix.",
	})
end

local function addLine(order: number, text: string, color: Color3)
	local label = UIKit.label(list, text, Enum.Font.GothamBold, UIKit.textSize("body"), color)
	label.LayoutOrder = order
	label.Size = UDim2.new(1, -8, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
end

local function fillWindow()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local update = latest
	if not update then
		return
	end
	local colors = UIKit.colorsFor(list)
	local scale = RatingRules.spawnScale(Customers, update.rating)
	local pace = if scale < 0.97 then "Customers come more often." elseif scale > 1.03 then "Customers come less often." else "Customers come at the usual pace."
	addLine(1, string.format("%.1f stars · %s", update.rating, pace), colors.ink)
	local parts: { [string]: number } = {}
	local weights: { [string]: number } = {}
	for _, part in update.parts do
		-- A part with nothing to score yet (no prices with nothing stocked) gets no tip
		if part.known ~= false then
			parts[part.name] = part.score
			weights[part.name] = part.weight
		end
	end
	for index, tip in RatingRules.tips(parts, weights, Customers.RATING.goodFrom) do
		local words = Customers.RATING_TIPS[tip.name]
		if words then
			addLine(index + 1, if tip.good then `✅ {words.good}` else `⚠️ {words.fix}`, if tip.good then colors.good else colors.inkSoft)
		end
	end
end

local function onUpdate(payload: unknown)
	if typeof(payload) ~= "table" or typeof((payload :: any).rating) ~= "number" then
		return
	end
	local update = payload :: Update
	latest = update
	chip.Visible = not UIController.IsCompact() -- phones: the rating is on the Phone (its status bar, Reviews)
	numberLabel.Text = string.format("%.1f", update.rating)
	for index, clip in fills do
		clip.Size = UDim2.fromScale(math.floor(math.clamp(update.rating - (index - 1), 0, 1) * 4) / 4, 1)
	end
	if window.Visible then
		fillWindow()
	end
end

function RatingController.Start()
	buildChip()
	addTooltip()
	window, list = UIKit.panel(UIController.GetScreenGui(), "RatingTips", "Shop rating")
	window.Size = UDim2.new(0.92, 0, 0, Customers.RATING.tipsHeight) -- a few lines, not a full list
	chip.Activated:Connect(function()
		fillWindow()
		window.Visible = not window.Visible
	end)
	Remotes.RatingUpdate.OnClientEvent:Connect(onUpdate)
	UIController.OnCompact(function(compact: boolean)
		if compact then
			chip.Visible = false
		elseif latest then
			chip.Visible = true
		end
	end)
end

return RatingController
