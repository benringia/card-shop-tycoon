--!strict
-- The HUD layout, in one place: controllers register their buttons here instead of positioning them.
--   Side:    blue icon tiles down the left middle; the Manage tile slides out a tray of tiles to its right.
--   Bottom:  blue icon tiles in a centred row (Cards, Bag); Context tiles (orange) join the row while visible.
-- Rows use list layouts, so a controller can simply show or hide its tile and the row re-centres.
-- Numbers: Config/HudLayout. Motion: Util/Motion.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudLayout = require(Shared:WaitForChild("Config"):WaitForChild("HudLayout"))
local UIMotion = require(Shared:WaitForChild("Config"):WaitForChild("UIMotion"))

local Util = script.Parent :: Instance
local UIKit = require(Util:WaitForChild("UIKit"))
local Motion = require(Util:WaitForChild("Motion"))
local Icon = require(Util:WaitForChild("Icon"))

export type Group = "Side" | "Bottom" | "Context"
export type TileSpec = {
	id: string,
	icon: string, -- a Config/UIIcons name (or an emoji)
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
local fan: Frame
local manageTile: TextButton? = nil
local fanOpen = false
local tiles: { [string]: TextButton } = {}
local fanButtons: { { order: number, button: TextButton } } = {}

local function iconAndLabel(button: GuiButton, icon: string, label: string, iconHeight: number)
	local holder = Icon.make(button, icon, UDim2.fromScale(1, iconHeight))
	holder.Position = UDim2.fromScale(0, 0.05)

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

-- A blue (or given colour) square with a soft top-to-bottom gradient, icon above the label
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

-- Opens or folds the Manage tray: its tiles pop in one after another, left to right
local function setFan(open: boolean)
	fanOpen = open
	local tile = manageTile
	if tile then
		local icon = tile:FindFirstChild("Icon") :: Frame?
		local label = tile:FindFirstChild("Label") :: TextLabel?
		tile.BackgroundColor3 = if open then HudLayout.TILE_DARK else HudLayout.TILE
		if icon then
			Icon.set(icon, if open then "❌" else "Manage")
		end
		if label then
			label.Text = if open then "Close" else "Manage"
		end
	end
	table.sort(fanButtons, function(a, b)
		return a.order < b.order
	end)
	if open then
		fan.Visible = true
		Motion.popIn(fan)
	end
	for index, entry in fanButtons do
		local button = entry.button
		if open then
			button.Visible = false
			task.delay((index - 1) * UIMotion.FAN_STAGGER, function()
				if fanOpen then
					button.Visible = true
					Motion.popIn(button)
				end
			end)
		end
	end
	if not open then
		Motion.popOut(fan, function()
			fan.Visible = false
		end)
	end
end

local function ensureManageTile()
	if manageTile then
		return
	end
	manageTile = makeTile(side, {
		id = "Manage",
		icon = "Manage",
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

	-- The Manage tray: a soft white bar right of the Manage tile holding its tiles in a row
	fan = Instance.new("Frame")
	fan.Name = "HudFan"
	fan.AnchorPoint = Vector2.new(0, 0.5)
	fan.Size = UDim2.fromOffset(0, HudLayout.TILE_SIZE.Y + HudLayout.TRAY.PADDING * 2)
	fan.AutomaticSize = Enum.AutomaticSize.X
	fan.BackgroundColor3 = Color3.new(1, 1, 1)
	fan.BackgroundTransparency = HudLayout.TRAY.TRANSPARENCY
	fan.Visible = false
	fan.ZIndex = 3
	fan.Parent = screenGui
	UIKit.corner(fan, 18)
	UIKit.outline(fan, Color3.new(1, 1, 1), 2)
	local padding = Instance.new("UIPadding")
	for _, side_ in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		(padding :: any)[side_] = UDim.new(0, HudLayout.TRAY.PADDING)
	end
	padding.Parent = fan
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, HudLayout.GAP)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = fan
	local function placeFan()
		local tile = manageTile
		if tile then
			local left = tile.AbsolutePosition.X + tile.AbsoluteSize.X + HudLayout.GAP
			local middle = tile.AbsolutePosition.Y + tile.AbsoluteSize.Y / 2
			fan.Position = UDim2.fromOffset(left, middle)
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

-- A blue tile in the Manage tray; tapping it also folds the tray away
function Hud.fanButton(spec: FanSpec): TextButton
	ensureManageTile()
	local button = makeTile(fan, {
		id = spec.id,
		icon = spec.icon,
		label = spec.label,
		group = "Side",
		order = spec.order,
		onClick = function()
			setFan(false)
			spec.onClick()
		end,
	})
	button.ZIndex = fan.ZIndex + 1
	table.insert(fanButtons, { order = spec.order, button = button })
	return button
end

function Hud.setLabel(id: string, text: string)
	local tile = tiles[id]
	local label = if tile then tile:FindFirstChild("Label") else nil
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

-- Full-screen views (the binder) hide the side and bottom HUD while they show; each caller has its own reason
local hiddenBy: { [string]: boolean } = {}
local hideWithHud: { GuiObject } = {}

-- Other HUD pieces that hide along with the tiles (the status corner and its money toasts)
function Hud.hideWith(object: GuiObject)
	table.insert(hideWithHud, object)
end

function Hud.setHidden(reason: string, hidden: boolean)
	hiddenBy[reason] = if hidden then true else nil
	local show = next(hiddenBy) == nil
	side.Visible = show
	bottom.Visible = show
	for _, object in hideWithHud do
		object.Visible = show
	end
	if not show and fanOpen then
		setFan(false)
	end
end

return Hud
