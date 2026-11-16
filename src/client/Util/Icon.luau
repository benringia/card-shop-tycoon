--!strict
-- Draws an icon by name (Config/UIIcons) into a holder frame: the picture if the name has one, a stack of pictures
-- for a Config/IconStacks name (To Bag), else the text itself (an emoji such as "❌"). Swapping keeps the holder, so
-- layouts and sizes stay put.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local UIIcons = require(Config:WaitForChild("UIIcons"))
local IconStacks = require(Config:WaitForChild("IconStacks"))

local Icon = {}

-- Fetch every icon up front and keep each one drawn, tiny and nearly invisible, in a corner: Roblox only
-- finishes loading an image once something draws it, so hidden tiles (the Manage tray) would open blank
task.spawn(function()
	local cache = Instance.new("ScreenGui")
	cache.Name = "IconCache"
	cache.ResetOnSpawn = false
	cache.DisplayOrder = -10
	local images = {}
	for name, id in UIIcons do
		table.insert(images, id)
		local keep = Instance.new("ImageLabel")
		keep.Name = name
		keep.BackgroundTransparency = 1
		keep.Size = UDim2.fromOffset(2, 2)
		keep.Image = id
		keep.ImageTransparency = 0.98
		keep.Parent = cache
	end
	cache.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	ContentProvider:PreloadAsync(images)
end)

function Icon.set(holder: GuiObject, name: string)
	for _, child in holder:GetChildren() do
		if child.Name == "Glyph" then
			child:Destroy()
		end
	end
	local image = UIIcons[name]
	local stack = IconStacks[name]
	local glyph: GuiObject
	if stack then
		-- its pictures in a frame, the first layer at the back
		local frame = Instance.new("Frame")
		for index, layer in stack do
			local picture = Instance.new("ImageLabel")
			picture.Name = `Layer{index}`
			picture.BackgroundTransparency = 1
			picture.Image = UIIcons[layer.icon] or ""
			picture.ScaleType = Enum.ScaleType.Fit
			picture.AnchorPoint = Vector2.new(0.5, 0.5)
			picture.Position = UDim2.fromScale(layer.x, layer.y)
			picture.Size = UDim2.fromScale(layer.size, layer.size)
			picture.Rotation = layer.rotation
			picture:SetAttribute("Layer", index - 1)
			picture.Parent = frame
		end
		glyph = frame
	elseif image then
		local picture = Instance.new("ImageLabel")
		picture.Image = image
		picture.ScaleType = Enum.ScaleType.Fit
		glyph = picture
	else
		local text = Instance.new("TextLabel")
		text.Font = Enum.Font.FredokaOne
		text.Text = name
		text.TextScaled = true
		glyph = text
	end
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.Parent = holder
	Icon.layer(holder, holder.ZIndex)
end

-- Puts a holder's icon at `z` (a stack's layers just above it, in their order); call it after changing the holder's
-- ZIndex
function Icon.layer(holder: GuiObject, z: number)
	local glyph = holder:FindFirstChild("Glyph")
	if not glyph or not glyph:IsA("GuiObject") then
		return
	end
	glyph.ZIndex = z
	for _, picture in glyph:GetChildren() do
		local offset = picture:GetAttribute("Layer")
		if picture:IsA("GuiObject") and typeof(offset) == "number" then
			picture.ZIndex = z + offset
		end
	end
end

-- A transparent holder with the icon in it
function Icon.make(parent: Instance, name: string, size: UDim2): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.Size = size
	holder.Parent = parent
	Icon.set(holder, name)
	return holder
end

-- An icon before a UIKit.panel's title (headerHeight: UIKit.HEADER_HEIGHT); the title moves over to make room
function Icon.header(panel: Frame, name: string, headerHeight: number): Frame
	local title = panel:FindFirstChild("Title", true) :: TextLabel
	local icon = Icon.make(title.Parent :: Instance, name, UDim2.fromOffset(40, 40))
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromOffset(14, headerHeight / 2)
	icon.ZIndex = title.ZIndex
	title.Position = UDim2.fromOffset(60, 0)
	return icon
end

return Icon
