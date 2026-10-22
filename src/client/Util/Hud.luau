--!strict
-- The HUD layout, in one place: controllers register their buttons here instead of positioning them.
--   Side:    blue icon tiles down the left middle; the Manage tile opens a fan of round buttons.
--   Bottom:  blue icon tiles in a centred row (Cards, Bag); Context tiles (orange) join the row while visible.
--   Top:     a centred pill bar (cash, level, shards), for UIController.
-- Rows use list layouts, so a controller can simply show or hide its tile and the row re-centres.
-- Numbers: Config/HudLayout. Motion: Util/Motion.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudLayout = require(Shared:WaitForChild("Config"):WaitForChild("HudLayout"))
local UIMotion = require(Shared:WaitForChild("Config"):WaitForChild("UIMotion"))
local FanLayout = require(Shared:WaitForChild("Util"):WaitForChild("FanLayout"))

local Util = script.Parent :: Instance
local UIKit = require(Util:WaitForChild("UIKit"))
local Motion = require(Util:WaitForChild("Motion"))

export type Group = "Side" | "Bottom" | "Context"
export type TileSpec = {
	id: string,
	icon: string,
	label: string,
	key: string?,
	group: Group,
	order: number,
	color: Color3?,
	onClick: () -> (),
}
export type FanSpec = { id: string, icon: string, label: string, order: number, onClick: () -> () }

local Hud = {}

local side: Frame
local bottom: Frame
local top: Frame
local fan: Frame
local manageTile: TextButton? = nil
local fanOpen = false
local tiles: { [string]: TextButton } = {}
local fanButtons: { { order: number, button: TextButton } } = {}

local function iconAndLabel(button: GuiButton, icon: string, label: string, iconHeight: number)
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.BackgroundTransparency = 1
	iconLabel.Position = UDim2.fromScale(0, 0.06)
	iconLabel.Size = UDim2.fromScale(1, iconHeight)
	iconLabel.Font = Enum.Font.FredokaOne
	iconLabel.Text = icon
	iconLabel.TextScaled = true
	iconLabel.Parent = button

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(0, 1)
	text.Position = UDim2.fromScale(0, 0.96)
	text.Size = UDim2.fromScale(1, 0.3)
	text.Font = Enum.Font.FredokaOne
	text.Text = label
	text.TextScaled = true
	text.TextColor3 = button.TextColor3
	text.Parent = button
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 18
	limit.Parent = text
	button:GetPropertyChangedSignal("TextColor3"):Connect(function()
		text.TextColor3 = button.TextColor3
	end)
end

local function addKeyChip(button: GuiButton, key: string)
	local chip = Instance.new("TextLabel")
	chip.Name = "Key"
	chip.AnchorPoint = Vector2.new(1, 1)
	chip.Position = UDim2.new(1, 10, 1, 10) -- just off the corner, clear of the label
	chip.Size = UDim2.fromOffset(24, 24)
	chip.BackgroundColor3 = HudLayout.KEY_CHIP
	chip.Font = Enum.Font.FredokaOne
	chip.Text = key
	chip.TextSize = 14
	chip.TextColor3 = Color3.new(1, 1, 1)
	chip.ZIndex = button.ZIndex + 2
	chip.Parent = button
	UIKit.corner(chip, 6)
	UIKit.outline(chip, Color3.new(1, 1, 1), 1.5)
end

-- A blue (or given colour) square with a soft top-to-bottom gradient, emoji icon above the label
local function makeTile(parent: Instance, spec: TileSpec): TextButton
	local color = spec.color or (if spec.group == "Context" then HudLayout.CONTEXT else HudLayout.TILE)
	local tile = UIKit.button(parent, "", color)
	tile.Name = spec.id
	tile.LayoutOrder = spec.order
	tile.Size = UDim2.fromOffset(HudLayout.TILE_SIZE.X, HudLayout.TILE_SIZE.Y)
	iconAndLabel(tile, spec.icon, spec.label, 0.5)
	if spec.key then
		addKeyChip(tile, spec.key)
	end
	tile.Activated:Connect(spec.onClick)
	if spec.group == "Context" then
		tile.Visible = false
		tile:GetPropertyChangedSignal("Visible"):Connect(function()
			if tile.Visible then
				Motion.popIn(tile)
			end
		end)
	end
	return tile
end

local function setFan(open: boolean)
	fanOpen = open
	local tile = manageTile
	if tile then
		local icon = tile:FindFirstChild("Icon") :: TextLabel?
		local label = tile:FindFirstChild("Label") :: TextLabel?
		tile.BackgroundColor3 = if open then UIKit.Colors.Row else HudLayout.TILE
		if icon then
			icon.Text = if open then "❌" else "🧰"
		end
		if label then
			label.Text = if open then "Close" else "Manage"
		end
	end
	table.sort(fanButtons, function(a, b)
		return a.order < b.order
	end)
	for index, entry in fanButtons do
		local button = entry.button
		if open then
			task.delay((index - 1) * UIMotion.FAN_STAGGER, function()
				if fanOpen then
					button.Visible = true
					Motion.popIn(button)
				end
			end)
		else
			Motion.popOut(button, function()
				button.Visible = false
			end)
		end
	end
end

local function layoutFan()
	table.sort(fanButtons, function(a, b)
		return a.order < b.order
	end)
	local points = FanLayout.positions(#fanButtons, HudLayout.FAN.RADIUS, HudLayout.FAN.FROM, HudLayout.FAN.TO)
	for index, entry in fanButtons do
		entry.button.Position = UDim2.fromOffset(points[index].x, points[index].y)
	end
end

local function ensureManageTile()
	if manageTile then
		return
	end
	manageTile = makeTile(side, {
		id = "Manage",
		icon = "🧰",
		label = "Manage",
		group = "Side",
		order = 0,
		onClick = function()
			setFan(not fanOpen)
		end,
	})
end

-- Builds the HUD containers on the main ScreenGui; UIController calls it first thing
function Hud.mount(screenGui: ScreenGui)
	side = Instance.new("Frame")
	side.Name = "HudSide"
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(0, 0.5)
	side.Position = UDim2.new(0, HudLayout.SIDE_X, 0.5, 0)
	side.Size = UDim2.fromOffset(HudLayout.TILE_SIZE.X, 0)
	side.AutomaticSize = Enum.AutomaticSize.Y
	side.Parent = screenGui
	local sideList = Instance.new("UIListLayout")
	sideList.Padding = UDim.new(0, HudLayout.GAP)
	sideList.SortOrder = Enum.SortOrder.LayoutOrder
	sideList.Parent = side

	bottom = Instance.new("Frame")
	bottom.Name = "HudBottom"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -HudLayout.BOTTOM_MARGIN)
	bottom.Size = UDim2.fromOffset(0, HudLayout.TILE_SIZE.Y)
	bottom.AutomaticSize = Enum.AutomaticSize.X
	bottom.Parent = screenGui
	local bottomList = Instance.new("UIListLayout")
	bottomList.FillDirection = Enum.FillDirection.Horizontal
	bottomList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bottomList.Padding = UDim.new(0, HudLayout.GAP)
	bottomList.SortOrder = Enum.SortOrder.LayoutOrder
	bottomList.Parent = bottom

	top = Instance.new("Frame")
	top.Name = "HudTop"
	top.BackgroundTransparency = 1
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, HudLayout.TOP_Y)
	top.Size = UDim2.fromOffset(0, 0)
	top.AutomaticSize = Enum.AutomaticSize.XY
	top.Parent = screenGui

	-- The fan grows out of the Manage tile's centre
	fan = Instance.new("Frame")
	fan.Name = "HudFan"
	fan.BackgroundTransparency = 1
	fan.AnchorPoint = Vector2.new(0.5, 0.5)
	fan.Size = UDim2.fromOffset(0, 0)
	fan.ZIndex = 3
	fan.Parent = screenGui
	local function placeFan()
		local tile = manageTile
		if tile then
			local centre = tile.AbsolutePosition + tile.AbsoluteSize / 2
			fan.Position = UDim2.fromOffset(centre.X, centre.Y)
		end
	end
	side:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeFan)
	side:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeFan)
	task.defer(placeFan)
end

function Hud.tile(spec: TileSpec): TextButton
	local parent = if spec.group == "Side" then side else bottom
	local tile = makeTile(parent, spec)
	tiles[spec.id] = tile
	return tile
end

-- A round white button in the Manage fan; tapping it also folds the fan away
function Hud.fanButton(spec: FanSpec): TextButton
	ensureManageTile()
	local button = UIKit.button(fan, "", UIKit.Colors.Row)
	button.Name = spec.id
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Size = UDim2.fromOffset(HudLayout.FAN.BUTTON, HudLayout.FAN.BUTTON)
	button.Visible = false
	button.ZIndex = fan.ZIndex
	local corner = button:FindFirstChildWhichIsA("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0.5, 0)
	end
	iconAndLabel(button, spec.icon, spec.label, 0.48)
	button.Activated:Connect(function()
		setFan(false)
		spec.onClick()
	end)
	table.insert(fanButtons, { order = spec.order, button = button })
	layoutFan()
	return button
end

function Hud.setLabel(id: string, text: string)
	local tile = tiles[id]
	local label = if tile then tile:FindFirstChild("Label") else nil
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

function Hud.getTop(): Frame
	return top
end

return Hud
