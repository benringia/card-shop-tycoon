--!strict
-- The picture recipe the station windows share (owner 2026-11-20: the Condenser's "make this window easier to
-- understand and more immersive. a kid wouldnt understand this", pick A; then "redesign it like the condenser" for the
-- Grading Station and the Forge): what goes in as little spots in a grid, an arrow, the thing that comes out, and one
-- big button with a small line under its words. The spots a stand-in item could fill are tapped (Star Shards, Grading
-- Seals). On the button's press the spots fly into the thing. Pixels are before the window's own scale.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ARROW = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("StationLook")).ARROW

local ClientUtil = script.Parent :: Instance
local Icon = require(ClientUtil:WaitForChild("Icon"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

local Recipe = {}

Recipe.LOOK = {
	top = 58, -- under the sentence
	slots = Vector2.new(150, 137), -- the spots' area, as tall as a card
	gap = 5, -- between spots
	spotTall = 62, -- a spot's height at the most
	spotShape = 0.69, -- a spot's width for its height (a card's)
	arrow = ARROW.room, -- the arrow's room between what goes in and what comes out (it sits in its middle)
	under = 30, -- the row under them (a chip, the stars)
	fly = 0.32, -- seconds the spots take to fly in
	button = 58, -- the big button's height
}

export type SpotView = {
	order: number,
	palette: UIKit.Palette,
	image: string?, -- "copy": its picture
	foil: boolean?, -- "copy": a gold edge
	icon: string?, -- "item" / "offer": the stand-in's icon (Config/UIIcons name); "copy" without an image: its icon
	count: string?, -- small words on its bottom edge ("12 / 20")
	short: boolean?, -- its count is red: not enough of it
	onTap: (() -> ())?, -- "item" / "offer": a tap
}

-- The grid the spots sit in, `columns` across for `need` of them, in an area LOOK.slots (or `size`) big: its cells as
-- big as fit, LOOK.spotTall (or `spotTall`) tall at the most. The grid is only as wide as its spots (the area's height),
-- so the arrow after it sits in the middle between them and what comes out (owner 2026-11-26: "put the arrow on the
-- center"); that width is the second result
function Recipe.grid(parent: Instance, need: number, columns: number, size: Vector2?, spotTall: number?): (Frame, number)
	local look = Recipe.LOOK
	local area = size or look.slots
	local rows = math.max(1, math.ceil(need / columns))
	local tall = math.min(spotTall or look.spotTall, math.floor((area.Y - (rows - 1) * look.gap) / rows))
	local across = math.min(math.floor(tall * look.spotShape), math.floor((area.X - (columns - 1) * look.gap) / columns))
	tall = math.floor(across / look.spotShape)
	local used = math.min(columns, math.max(1, need))
	local wide = used * across + (used - 1) * look.gap
	local grid = Instance.new("Frame")
	grid.Name = "Spots"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromOffset(wide, area.Y)
	grid.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(across, tall)
	layout.CellPadding = UDim2.fromOffset(look.gap, look.gap)
	layout.FillDirectionMaxCells = columns
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	return grid, wide
end

-- One spot. `kind`: "copy" (something going in: its picture or icon), "item" (a stand-in item in a spot: a tap takes
-- it out), "offer" (an empty spot a stand-in could fill: a tap puts it in), "empty"
function Recipe.spot(parent: Instance, kind: string, view: SpotView): GuiObject
	local palette = view.palette
	local spot: GuiObject
	if (kind == "item" or kind == "offer") and view.onTap then
		local button = Instance.new("TextButton")
		button.Text = ""
		button.AutoButtonColor = false
		button.Activated:Connect(view.onTap)
		spot = button
	else
		spot = Instance.new("Frame")
	end
	spot.Name = kind
	spot.LayoutOrder = view.order
	spot.BackgroundColor3 = if kind == "item" then Color3.fromRGB(255, 240, 196) elseif kind == "empty" then palette.track else palette.row
	spot.BackgroundTransparency = if kind == "empty" then 0.45 else 0
	spot.Parent = parent
	UIKit.corner(spot, 5)
	local gold = kind == "item" or (kind == "copy" and view.foil == true)
	UIKit.outline(spot, if view.short then palette.bad elseif gold then UIKit.Colors.Accent elseif kind == "offer" then palette.hint else palette.rowEdge, 2)
	if kind == "copy" and view.image then
		local art = Instance.new("ImageLabel")
		art.BackgroundTransparency = 1
		art.Size = UDim2.fromScale(1, 1)
		art.ScaleType = Enum.ScaleType.Crop
		art.Image = view.image
		art.Parent = spot
		UIKit.corner(art, 5)
	elseif kind ~= "empty" and view.icon then
		local icon = Icon.make(spot, view.icon, UDim2.fromScale(0.78, 0.54))
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, if view.count then 0.4 else 0.5)
		Icon.set(icon, view.icon)
		local glyph = icon:FindFirstChild("Glyph")
		if kind == "offer" and glyph and glyph:IsA("ImageLabel") then
			glyph.ImageTransparency = 0.55 -- one that could go here
		end
	end
	if view.count then
		local count = UIKit.label(spot, view.count, Enum.Font.FredokaOne, 11, if view.short then palette.bad else palette.ink)
		count.AnchorPoint = Vector2.new(0.5, 1)
		count.Position = UDim2.new(0.5, 0, 1, -2)
		count.Size = UDim2.new(1, -2, 0, 13)
		count.TextXAlignment = Enum.TextXAlignment.Center
		count.TextScaled = true
	end
	return spot
end

-- The arrow between what goes in and what comes out, its middle at (x, y) (put it in the middle of LOOK.arrow's room):
-- drawn as a line with a chevron head, the mockups' arrow (owner 2026-11-26: "use a different arrow, not an emoji
-- arrow"; Config/StationLook ARROW). `color`: another colour (the empty recipe's pale one)
function Recipe.arrow(parent: Instance, x: number, y: number, color: Color3?): Frame
	local arrow = Instance.new("Frame")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromOffset(x, y)
	arrow.Size = UDim2.fromOffset(ARROW.wide, ARROW.tall)
	arrow.Parent = parent
	local tint = color or Color3.fromRGB(ARROW.color[1], ARROW.color[2], ARROW.color[3])
	local thick = ARROW.thick
	local function stroke(name: string, centre: Vector2, length: number, rotation: number)
		local bar = Instance.new("Frame")
		bar.Name = name
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = tint
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromOffset(centre.X, centre.Y)
		bar.Size = UDim2.fromOffset(length, thick)
		bar.Rotation = rotation
		bar.Parent = arrow
		UIKit.corner(bar, thick / 2)
	end
	-- the tip on the right, the head's two strokes reaching back to the top and the bottom (each turned 45 degrees about
	-- its middle, its end on the tip), the shaft from the left to the tip
	local middle = ARROW.tall / 2
	local tip = ARROW.wide - thick / 2
	local head = (middle - thick / 2) * math.sqrt(2)
	local back = head / (2 * math.sqrt(2))
	stroke("Shaft", Vector2.new((thick / 2 + tip) / 2, middle), tip - thick / 2, 0)
	stroke("HeadTop", Vector2.new(tip - back, middle - back), head, 45)
	stroke("HeadBottom", Vector2.new(tip - back, middle + back), head, -45)
	return arrow
end

-- A button with a small line under its words ("Add a star!" over "takes 30 seconds"); `sub` nil: its words alone
function Recipe.words(button: TextButton, text: string, sub: string?)
	if sub then
		button.RichText = true
		button.Text = `{text}\n<font size="13">{sub}</font>`
	else
		button.RichText = false
		button.Text = text
		button.TextSize = 17
	end
end

-- Something that beats (the star or grade this adds)
function Recipe.beat(target: GuiObject)
	local scale = Instance.new("UIScale")
	scale.Parent = target
	TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.3 }):Play()
end

-- The button pressed: the spots fly into `target` (copies of them laid over `panel`, so the pane can redraw under them)
function Recipe.flyIn(panel: Frame, spots: { GuiObject }, target: GuiObject)
	local scaler = panel:FindFirstChildOfClass("UIScale")
	local scale = if scaler and scaler.Scale > 0 then scaler.Scale else 1
	local goal = (target.AbsolutePosition + target.AbsoluteSize / 2 - panel.AbsolutePosition) / scale
	for index, spot in spots do
		local copy = spot:Clone()
		local at = (spot.AbsolutePosition + spot.AbsoluteSize / 2 - panel.AbsolutePosition) / scale
		local size = spot.AbsoluteSize / scale
		copy.AnchorPoint = Vector2.new(0.5, 0.5)
		copy.Position = UDim2.fromOffset(at.X, at.Y)
		copy.Size = UDim2.fromOffset(size.X, size.Y)
		copy.ZIndex = 80
		copy.Parent = panel
		local tween = TweenService:Create(copy, TweenInfo.new(Recipe.LOOK.fly + index * 0.012, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(goal.X, goal.Y),
			Size = UDim2.fromOffset(size.X * 0.35, size.Y * 0.35),
		})
		tween.Completed:Once(function()
			copy:Destroy()
		end)
		tween:Play()
	end
end

return Recipe
