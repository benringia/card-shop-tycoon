--!strict
-- The picture recipe the station windows share (owner 2026-11-20: the Condenser's "make this window easier to
-- understand and more immersive. a kid wouldnt understand this", pick A; then "redesign it like the condenser" for the
-- Grading Station and the Forge): what goes in as little spots in a grid, an arrow, the thing that comes out, and one
-- big button with a small line under its words. The spots a stand-in item could fill are tapped (Star Shards, Grading
-- Seals). On the button's press the spots fly into the thing. Pixels are before the window's own scale.
local TweenService = game:GetService("TweenService")

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
	arrow = 36,
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

-- The grid the spots sit in, `columns` across for `need` of them: sized LOOK.slots (or `size`), its cells as big as
-- fit, LOOK.spotTall (or `spotTall`) tall at the most
function Recipe.grid(parent: Instance, need: number, columns: number, size: Vector2?, spotTall: number?): Frame
	local look = Recipe.LOOK
	local area = size or look.slots
	local rows = math.max(1, math.ceil(need / columns))
	local tall = math.min(spotTall or look.spotTall, math.floor((area.Y - (rows - 1) * look.gap) / rows))
	local across = math.min(math.floor(tall * look.spotShape), math.floor((area.X - (columns - 1) * look.gap) / columns))
	tall = math.floor(across / look.spotShape)
	local grid = Instance.new("Frame")
	grid.Name = "Spots"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromOffset(area.X, area.Y)
	grid.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(across, tall)
	layout.CellPadding = UDim2.fromOffset(look.gap, look.gap)
	layout.FillDirectionMaxCells = columns
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	return grid
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

-- The arrow between what goes in and what comes out, its middle at (x, y)
function Recipe.arrow(parent: Instance, x: number, y: number): Frame
	local arrow = Icon.make(parent, "Next", UDim2.fromOffset(26, 26))
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromOffset(x, y)
	Icon.set(arrow, "Next")
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

-- The copy picker (owner 2026-11-21: "Keep a different card is so confusing. can we change wording or anything to make
-- it more understandable. also the next window make it more understandable"; words in Util/CondenseRules): a chip
-- under the big button that says what it does, and the copies as pictures in place of the recipe.

-- The chip: its words and a small line under them, 44 px tall, its top at `y`
function Recipe.pickChip(parent: Instance, y: number, palette: UIKit.Palette, title: string, sub: string, onTap: () -> ()): TextButton
	local chip = Instance.new("TextButton")
	chip.Name = "Change"
	chip.Text = ""
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.new(0.5, 0, 0, y + 2)
	chip.Size = UDim2.fromOffset(250, 40)
	chip.BackgroundColor3 = palette.row
	chip.Parent = parent
	UIKit.corner(chip, 10)
	UIKit.outline(chip, palette.rowEdge, 2)
	local words = UIKit.label(chip, title, Enum.Font.FredokaOne, 14, palette.ink)
	words.Position = UDim2.fromOffset(4, 4)
	words.Size = UDim2.new(1, -8, 0, 17)
	words.TextXAlignment = Enum.TextXAlignment.Center
	local small = UIKit.label(chip, sub, Enum.Font.GothamBold, 11, palette.inkSoft)
	small.Position = UDim2.fromOffset(4, 21)
	small.Size = UDim2.new(1, -8, 0, 14)
	small.TextXAlignment = Enum.TextXAlignment.Center
	chip.Activated:Connect(onTap)
	return chip
end

export type CopyTile = {
	key: string,
	grade: string, -- "Grade A"
	gradeColor: Color3,
	foil: boolean, -- a gold Foil tag on its picture
	label: string, -- "You have 2", "Lv 12"
	stars: number,
	tag: string, -- "Ready!", "3 more"
	gold: boolean, -- its tag is the gold Ready!
	chosen: boolean, -- the one in use now: ringed and lit
	draw: (holder: Frame) -> (), -- draws its card's face into `holder`
}

-- The copies as tiles from `y` down (a small line, then each copy's picture, its grade, its stars, a few words and
-- whether it is ready; a tap picks it), then Back. Returns the y under Back
function Recipe.copyPicker(pane: GuiObject, view: {
	panel: Frame,
	y: number,
	edge: number,
	face: Vector2,
	maxStars: number,
	palette: UIKit.Palette,
	sub: string,
	tiles: { CopyTile },
	columnsFor: (width: number, tile: number, gap: number) -> number,
	onPick: (key: string) -> (),
	onBack: () -> (),
}): number
	local palette, face = view.palette, view.face
	local gap = 6
	local tileWide, tileTall = face.X + 8, face.Y + 90
	local scaler = view.panel:FindFirstChildOfClass("UIScale")
	local scale = if scaler and scaler.Scale > 0 then scaler.Scale else 1
	local room = pane.AbsoluteSize.X / scale - 2 * view.edge
	local columns = math.min(math.max(1, #view.tiles), view.columnsFor(room, tileWide, gap))
	local rowWide = columns * tileWide + (columns - 1) * gap
	local y = view.y

	local small = UIKit.label(pane, view.sub, Enum.Font.GothamBold, 12, palette.inkSoft)
	small.Name = "PickSub"
	small.Position = UDim2.fromOffset(view.edge, y)
	small.Size = UDim2.new(1, -2 * view.edge, 0, 16)
	small.TextXAlignment = Enum.TextXAlignment.Center
	y += 22

	for index, tile in view.tiles do
		local column, row = (index - 1) % columns, (index - 1) // columns
		local button = Instance.new("TextButton")
		button.Name = "Copy_" .. tile.key
		button.Text = ""
		button.Position = UDim2.new(0.5, -rowWide / 2 + column * (tileWide + gap), 0, y + row * (tileTall + gap))
		button.Size = UDim2.fromOffset(tileWide, tileTall)
		button.BackgroundColor3 = if tile.chosen then Color3.fromRGB(255, 240, 196) else palette.row
		button.Parent = pane
		UIKit.corner(button, 10)
		UIKit.outline(button, if tile.chosen then UIKit.Colors.Accent else palette.rowEdge, if tile.chosen then 3 else 2)
		local holder = Instance.new("Frame")
		holder.Name = "Face"
		holder.BackgroundTransparency = 1
		holder.Position = UDim2.fromOffset(4, 4)
		holder.Size = UDim2.fromOffset(face.X, face.Y)
		holder.Parent = button
		tile.draw(holder)
		if tile.foil then
			local foil = UIKit.pill(button, "Foil", UIKit.Colors.Accent, UIKit.Colors.Ink)
			foil.Name = "Foil"
			foil.Position = UDim2.fromOffset(0, math.floor(face.Y * 0.2)) -- on the picture, clear of the card's name
			foil.Size = UDim2.fromOffset(0, 18)
			foil.TextSize = 11
			foil.ZIndex = holder.ZIndex + 10
		end
		local grade = UIKit.pill(button, tile.grade, tile.gradeColor, Color3.new(1, 1, 1))
		grade.Name = "Grade"
		grade.AnchorPoint = Vector2.new(0.5, 0)
		grade.Position = UDim2.new(0.5, 0, 0, face.Y + 8)
		grade.Size = UDim2.fromOffset(0, 20)
		grade.TextSize = 12
		local starSize = 11
		local stars = Instance.new("Frame")
		stars.Name = "Stars"
		stars.BackgroundTransparency = 1
		stars.AnchorPoint = Vector2.new(0.5, 0)
		stars.Position = UDim2.new(0.5, 0, 0, face.Y + 32)
		stars.Size = UDim2.fromOffset(view.maxStars * (starSize + 2) - 2, starSize)
		stars.Parent = button
		for star = 1, view.maxStars do
			local icon = Icon.make(stars, "Star", UDim2.fromOffset(starSize, starSize))
			icon.Position = UDim2.fromOffset((star - 1) * (starSize + 2), 0)
			Icon.set(icon, "Star")
			local glyph = icon:FindFirstChild("Glyph")
			if glyph and glyph:IsA("ImageLabel") then
				glyph.ImageTransparency = if star <= tile.stars then 0 else 0.8
			end
		end
		local label = UIKit.label(button, tile.label, Enum.Font.GothamBold, 11, palette.inkSoft)
		label.Name = "Has"
		label.Position = UDim2.fromOffset(2, face.Y + 46)
		label.Size = UDim2.new(1, -4, 0, 14)
		label.TextXAlignment = Enum.TextXAlignment.Center
		local tag = UIKit.pill(button, tile.tag, if tile.gold then UIKit.Colors.Accent else palette.track, if tile.gold then UIKit.Colors.Ink else palette.inkSoft)
		tag.Name = "Tag"
		tag.AnchorPoint = Vector2.new(0.5, 1)
		tag.Position = UDim2.new(0.5, 0, 1, -6)
		tag.Size = UDim2.fromOffset(0, 20)
		tag.TextSize = 11
		button.Activated:Connect(function()
			view.onPick(tile.key)
		end)
	end
	local rows = math.ceil(#view.tiles / columns)
	y += rows * (tileTall + gap) + 2

	local back = UIKit.button(pane, "Back", UIKit.Colors.Secondary)
	back.Name = "Back"
	back.AnchorPoint = Vector2.new(0.5, 0)
	back.Position = UDim2.new(0.5, 0, 0, y)
	back.Size = UDim2.fromOffset(160, 48)
	back.Activated:Connect(view.onBack)
	return y + 48
end

return Recipe
