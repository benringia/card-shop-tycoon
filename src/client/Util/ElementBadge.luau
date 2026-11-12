--!strict
-- An element on screen (owner 2026-11-12: "replace everywhere. use icons not emojis"): its plain name (Fire, Water,
-- Nature, Electric, Dark; Config/ElementNames) and its image icon (Config/UIIcons by the internal key) inside a text
-- label, to the left of its text, or as a crest's picture.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Names = require(Shared:WaitForChild("Config"):WaitForChild("ElementNames"))
local UIIcons = require(Shared:WaitForChild("Config"):WaitForChild("UIIcons"))
local ElementNames = require(Shared:WaitForChild("Util"):WaitForChild("ElementNames"))

local ElementBadge = {}

local ICON = "ElementIcon"
local PAD = "ElementPad"
local GAP = 4 -- px between the icon and the text

-- The element's plain name ("Fire" for Ember)
function ElementBadge.name(key: string?): string
	return ElementNames.display(key, Names)
end

-- Its icon's image id ("" for none or an unknown key)
function ElementBadge.image(key: string?): string
	local id = if key then (UIIcons :: any)[key] else nil
	return if typeof(id) == "string" then id else ""
end

-- The label's text starts with the element's icon (none: no icon). The icon sits at the label's left, its text padded
-- past it; sized to the text
function ElementBadge.prefix(label: TextLabel, key: string?)
	local image = ElementBadge.image(key)
	local icon = label:FindFirstChild(ICON)
	local pad = label:FindFirstChild(PAD)
	if image == "" then
		if icon then
			icon:Destroy()
		end
		if pad and pad:IsA("UIPadding") then
			pad.PaddingLeft = UDim.new(0, 0)
		end
		return
	end
	local size = math.round(label.TextSize * 1.2)
	if not icon or not icon:IsA("ImageLabel") then
		local made = Instance.new("ImageLabel")
		made.Name = ICON
		made.BackgroundTransparency = 1
		made.AnchorPoint = Vector2.new(0, 0.5)
		made.Position = UDim2.new(0, -(size + GAP), 0.5, 0) -- in the padding, left of the text
		made.ZIndex = label.ZIndex + 1
		made.Parent = label
		icon = made
	end
	local iconLabel = icon :: ImageLabel
	iconLabel.Size = UDim2.fromOffset(size, size)
	iconLabel.Position = UDim2.new(0, -(size + GAP), 0.5, 0)
	iconLabel.Image = image
	if not pad or not pad:IsA("UIPadding") then
		local made = Instance.new("UIPadding")
		made.Name = PAD
		made.Parent = label
		pad = made
	end
	;(pad :: UIPadding).PaddingLeft = UDim.new(0, size + GAP)
end

-- A round crest showing the element's icon (its text cleared); none: an empty crest
function ElementBadge.crest(crest: TextLabel, key: string?)
	crest.Text = ""
	local icon = crest:FindFirstChild(ICON)
	if not icon or not icon:IsA("ImageLabel") then
		local made = Instance.new("ImageLabel")
		made.Name = ICON
		made.BackgroundTransparency = 1
		made.AnchorPoint = Vector2.new(0.5, 0.5)
		made.Position = UDim2.fromScale(0.5, 0.5)
		made.Size = UDim2.fromScale(0.72, 0.72)
		made.ZIndex = crest.ZIndex + 1
		made.Parent = crest
		icon = made
	end
	;(icon :: ImageLabel).Image = ElementBadge.image(key)
end

return ElementBadge
