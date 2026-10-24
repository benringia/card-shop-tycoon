--!strict
-- Draws an icon by name (Config/UIIcons) into a holder frame: the picture if the name has one, else the text
-- itself (an emoji such as "❌"). Swapping keeps the holder, so layouts and sizes stay put.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIIcons"))

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
	local glyph: GuiObject
	if image then
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
	glyph.ZIndex = holder.ZIndex
	glyph.Parent = holder
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

return Icon
