--!strict
-- Draws an icon by name (Config/UIIcons) into a holder frame: the picture if the name has one, else the text
-- itself (an emoji such as "❌"). Swapping keeps the holder, so layouts and sizes stay put.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIIcons"))

local Icon = {}

-- Fetch every icon up front, so HUD tiles don't show empty the first time they open
task.spawn(function()
	local images = {}
	for _, id in UIIcons do
		table.insert(images, id)
	end
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
