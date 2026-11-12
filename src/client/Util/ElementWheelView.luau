--!strict
-- The character window's element wheel (owner 2026-11-12, pick A: "simple graphs instead of a bunch of texts"): the
-- five element icons (Config/CharacterWindow WHEEL), an arrow from each to the ones it beats (Util/ElementWheel), a
-- gold ring round the elements in your party. Drawn in the WHEEL box's px, shown `scale` times that size.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Combat = require(Config:WaitForChild("Combat"))
local Look = require(Config:WaitForChild("CharacterWindow"))
local ElementNames = require(Config:WaitForChild("ElementNames"))
local ElementWheel = require(Shared:WaitForChild("Util"):WaitForChild("ElementWheel"))

local ClientUtil = script.Parent :: Instance
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local ElementBadge = require(ClientUtil:WaitForChild("ElementBadge"))

local ElementWheelView = {}

local WHEEL = Look.WHEEL
local HEAD_ANGLE = math.rad(32) -- between an arrowhead's arm and its line

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- A rounded bar from one point to another, `thick` px
local function bar(parent: Instance, x1: number, y1: number, x2: number, y2: number, thick: number, color: Color3, z: number)
	local dx, dy = x2 - x1, y2 - y1
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
	frame.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + thick, thick)
	frame.Rotation = math.deg(math.atan2(dy, dx))
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	frame.Parent = parent
	UIKit.corner(frame, thick / 2)
end

-- The line and its two-armed head at (x2, y2)
local function arrow(parent: Instance, a: ElementWheel.Arrow, color: Color3)
	bar(parent, a.x1, a.y1, a.x2, a.y2, WHEEL.line, color, 1)
	local angle = math.atan2(a.y2 - a.y1, a.x2 - a.x1) + math.pi -- pointing back along the line
	for _, turn in { HEAD_ANGLE, -HEAD_ANGLE } do
		local x = a.x2 + math.cos(angle + turn) * WHEEL.head
		local y = a.y2 + math.sin(angle + turn) * WHEEL.head
		bar(parent, a.x2, a.y2, x, y, WHEEL.line, color, 1)
	end
end

-- One element: its icon on a white disc (a gold ring and glow when it's in your party), its name under it
local function node(parent: Instance, key: string, mine: boolean, ink: Color3, edge: Color3)
	local at = WHEEL.nodes[key]
	local size = WHEEL.icon
	if mine then
		local glow = Instance.new("Frame")
		glow.Name = `Glow_{key}`
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromOffset(at.x, at.y)
		glow.Size = UDim2.fromOffset(size + 16, size + 16)
		glow.BackgroundColor3 = rgb(WHEEL.glow)
		glow.BackgroundTransparency = 0.55
		glow.ZIndex = 2
		glow.Parent = parent
		UIKit.corner(glow, (size + 16) / 2)
	end
	local disc = Instance.new("Frame")
	disc.Name = key
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromOffset(at.x, at.y)
	disc.Size = UDim2.fromOffset(size, size)
	disc.BackgroundColor3 = Color3.new(1, 1, 1)
	disc.ZIndex = 3
	disc.Parent = parent
	UIKit.corner(disc, size / 2)
	UIKit.outline(disc, if mine then rgb(WHEEL.glow) else edge, if mine then 4 else 2)
	local icon = Instance.new("ImageLabel")
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.78, 0.78)
	icon.BackgroundTransparency = 1
	icon.Image = ElementBadge.image(key)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 4
	icon.Parent = disc
	local name = UIKit.label(parent, ElementBadge.name(key), Enum.Font.FredokaOne, WHEEL.nameText, ink)
	name.AnchorPoint = Vector2.new(0.5, if at.nameAbove then 1 else 0)
	name.Position = UDim2.fromOffset(at.x, if at.nameAbove then at.y - size / 2 - 1 else at.y + size / 2 + 1)
	name.Size = UDim2.fromOffset(96, WHEEL.nameHeight)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.ZIndex = 3
end

-- The wheel, `scale` times its WHEEL.size, in `parent`; `mine`: the elements in your party
function ElementWheelView.new(parent: Instance, mine: { [string]: boolean }, palette: UIKit.Palette, scale: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "ElementWheel"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(WHEEL.size.x * scale, WHEEL.size.y * scale)
	holder.Parent = parent
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromOffset(WHEEL.size.x, WHEEL.size.y)
	box.Parent = holder
	local grow = Instance.new("UIScale")
	grow.Scale = scale
	grow.Parent = box
	local color = rgb(WHEEL.color)
	for _, each in ElementWheel.arrows(Combat.BEATS, WHEEL.nodes, WHEEL.icon / 2 + WHEEL.gap, WHEEL.pairOffset) do
		arrow(box, each, color)
	end
	for _, key in ElementNames.ORDER do
		node(box, key, mine[key] == true, palette.ink, palette.rowEdge)
	end
	return holder
end

return ElementWheelView
