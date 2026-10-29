--!strict
-- Word tooltips for icons and buttons shown without a label: hover with a mouse, hold a finger on touch
-- (UIStyle.LONG_PRESS). One shared tip per ScreenGui, drawn over everything in it, centred over the thing it
-- names (under it near the top edge), kept on screen (Util/UiLayout). It hides when the pointer leaves, the
-- finger lifts, or the thing hides or goes away.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local UIStyle = require(Config:WaitForChild("UIStyle"))
local IconTips = require(Config:WaitForChild("IconTips"))
local UiLayout = require(Shared:WaitForChild("Util"):WaitForChild("UiLayout"))

local GAP = 6
local MAX_WIDTH = 240
local TIP_Z_INDEX = 1000 -- over every window in its ScreenGui

local Tooltip = {}

local tips: { [ScreenGui]: TextLabel } = {}
local shownFor: GuiObject? = nil
local shownTip: TextLabel? = nil
local byTouch = false
local watcher: RBXScriptConnection? = nil

local function tipFor(screen: ScreenGui): TextLabel
	local existing = tips[screen]
	if existing and existing.Parent then
		return existing
	end
	local tip = Instance.new("TextLabel")
	tip.Name = "WordTip"
	tip.AutomaticSize = Enum.AutomaticSize.XY
	tip.Size = UDim2.new()
	tip.BackgroundColor3 = UIStyle.EDGE
	tip.Font = Enum.Font.GothamBold
	tip.TextSize = UIStyle.TEXT.small
	tip.TextColor3 = Color3.new(1, 1, 1)
	tip.TextWrapped = true
	tip.Visible = false
	tip.ZIndex = TIP_Z_INDEX
	tip.Parent = screen
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(MAX_WIDTH, math.huge)
	limit.Parent = tip
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = tip
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = UIStyle.HINT
	edge.Thickness = 2
	edge.Parent = tip
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = tip
	tips[screen] = tip
	return tip
end

-- Visible on screen: every ancestor up to its ScreenGui visible, and the ScreenGui enabled
local function isShown(target: GuiObject): boolean
	local node: Instance? = target
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("ScreenGui") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

local function pointerOver(target: GuiObject): boolean
	local mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local spot, size = target.AbsolutePosition, target.AbsoluteSize
	return mouse.X >= spot.X - 2 and mouse.X <= spot.X + size.X + 2 and mouse.Y >= spot.Y - 2 and mouse.Y <= spot.Y + size.Y + 2
end

function Tooltip.hide()
	if shownTip then
		shownTip.Visible = false
	end
	shownFor, shownTip = nil, nil
	if watcher then
		watcher:Disconnect()
		watcher = nil
	end
end

local function place(target: GuiObject, tip: TextLabel)
	local screen = tip.Parent :: ScreenGui
	local origin = screen.AbsolutePosition
	local spot = UiLayout.above(
		{ x = target.AbsolutePosition.X - origin.X, y = target.AbsolutePosition.Y - origin.Y, w = target.AbsoluteSize.X, h = target.AbsoluteSize.Y },
		{ w = tip.AbsoluteSize.X, h = tip.AbsoluteSize.Y },
		{ w = screen.AbsoluteSize.X, h = screen.AbsoluteSize.Y },
		GAP
	)
	tip.Position = UDim2.fromOffset(spot.x, spot.y)
end

local function show(target: GuiObject, text: string, touch: boolean)
	local screen = target:FindFirstAncestorOfClass("ScreenGui")
	if not screen or not isShown(target) then
		return
	end
	Tooltip.hide()
	local tip = tipFor(screen)
	tip.Text = text
	tip.Visible = true
	shownFor, shownTip, byTouch = target, tip, touch
	place(target, tip)
	-- MouseLeave can be missed (fast moves, a window closing under the pointer): check each frame
	watcher = RunService.Heartbeat:Connect(function()
		if not target.Parent or not isShown(target) or (not byTouch and not pointerOver(target)) then
			Tooltip.hide()
			return
		end
		place(target, tip) -- it sizes itself after its text, and windows move
	end)
end

-- Shows `text` while the pointer is over `target` (or a finger is held on it)
function Tooltip.attach(target: GuiObject, text: string)
	target.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled then
			show(target, text, false)
		end
	end)
	target.MouseLeave:Connect(function()
		if shownFor == target and not byTouch then
			Tooltip.hide()
		end
	end)
	local pressed = 0
	target.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		pressed += 1
		local press = pressed
		task.delay(UIStyle.LONG_PRESS, function()
			if pressed == press then
				show(target, text, true)
			end
		end)
	end)
	target.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		pressed += 1 -- cancels a hold still counting
		if shownFor == target then
			Tooltip.hide()
		end
	end)
end

-- The words for a Config/UIIcons icon (Config/IconTips); nothing for an icon without an entry
function Tooltip.icon(target: GuiObject, iconName: string)
	local text = (IconTips :: { [string]: string })[iconName]
	if text then
		Tooltip.attach(target, text)
	end
end

return Tooltip
