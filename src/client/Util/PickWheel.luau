--!strict
-- The hold column (owner 2026-11-17, the phone HUD's round 2: "when a player long presses. it should display her
-- pets/weapons at the top and bottom so that player can choose", placement 2 of artifact GtT4bM87otu1aayFVANr7z;
-- Util/PairRules, Config/Party BAR.PAIR): the screen dims and a column opens on the button held, the one you have now on
-- it (highlighted), the others above and below with their names (PairRules.wheel: five rows at most, wrapping round).
-- Slide onto one and let go to pick it; let go without sliding and tap one instead; a tap anywhere else closes it. A
-- finger held past an end, or a swipe on the column once let go, rolls on to the rest. PickWheel.hints: the chevrons
-- that say a button swipes up and down.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Party = require(Shared:WaitForChild("Config"):WaitForChild("Party"))
local PairRules = require(Shared:WaitForChild("Util"):WaitForChild("PairRules"))
local UIKit = require((script.Parent :: Instance):WaitForChild("UIKit"))

local PickWheel = {}

export type Item = { image: string, tint: Color3?, fit: boolean?, title: string, line: string? } -- fit: a cut-out picture
export type Options = {
	anchor: GuiObject, -- the button held: the column's middle row sits on it
	items: { Item },
	current: number, -- the one you have now
	held: InputObject?, -- the finger still down from the hold: sliding and letting go picks
	onPick: (index: number) -> (), -- a different one picked
}

local PAIR = Party.BAR.PAIR
local SIZE = 54 -- each row's picture, px
local GOLD = Color3.fromRGB(255, 207, 63)
local WHITE = Color3.new(1, 1, 1)
local DIM = Color3.fromRGB(20, 12, 34)
local Z = 90 -- over the HUD and its windows

local overlay: TextButton? = nil
local connections: { RBXScriptConnection } = {}

local function close()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	local open = overlay
	overlay = nil
	if open then
		open:Destroy()
	end
end

-- One chevron, two short white bars making a "^" (no arrow glyph in the fonts), turned over for "v"
local function chevron(parent: GuiObject, up: boolean, offset: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = if up then "Up" else "Down"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, if up then -offset else offset)
	frame.Size = UDim2.fromOffset(14, 8)
	frame.Rotation = if up then 0 else 180
	frame.ZIndex = 9
	frame.Parent = parent
	for _, side in { -1, 1 } do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = WHITE
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.new(0.5, side * 3, 0.5, 0)
		bar.Size = UDim2.fromOffset(3, 9)
		bar.Rotation = -side * 45
		bar.ZIndex = 9
		bar.Parent = frame
		UIKit.corner(bar, 1.5)
		local edge = Instance.new("UIStroke")
		edge.Color = DIM
		edge.Transparency = 0.5
		edge.Thickness = 1
		edge.Parent = bar
	end
	return frame
end

-- The chevrons above and below a button `offset` px from its middle (it swipes up and down); their holder to show or
-- hide them
function PickWheel.hints(parent: GuiObject, offset: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "SwipeHints"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 9
	holder.Parent = parent
	chevron(holder, true, offset)
	chevron(holder, false, offset)
	return holder
end

function PickWheel.isOpen(): boolean
	return overlay ~= nil
end

-- A phone button's swipe and hold (while `enabled()`): a swipe up or down calls `onSwipe(1 or -1)` wherever the finger
-- lets go (a button only hears the end of a touch that ends on it, so the end is heard here); held still (within
-- PAIR.still px) for PAIR.hold s calls `onHold(input)` with the finger still down. Returns `consumed()`: whether the
-- last press was a swipe or a hold, so the button's own tap (Activated) skips it.
function PickWheel.gestures(button: GuiButton, enabled: () -> boolean, onSwipe: (number) -> (), onHold: (InputObject) -> ()): () -> boolean
	local consumed = false
	local presses = 0
	button.InputBegan:Connect(function(input)
		local mouse = input.UserInputType == Enum.UserInputType.MouseButton1
		if not enabled() or (input.UserInputType ~= Enum.UserInputType.Touch and not mouse) then
			return
		end
		consumed = false
		presses += 1
		local press = presses
		local from = input.Position
		local settled = false -- a swipe or a hold has taken this press
		local ended: RBXScriptConnection? = nil
		ended = UserInputService.InputEnded:Connect(function(finish)
			if finish ~= input and not (mouse and finish.UserInputType == Enum.UserInputType.MouseButton1) then
				return
			end
			local connection = ended
			if connection then
				connection:Disconnect()
			end
			if settled then
				return
			end
			settled = true
			local step = PairRules.swipeStep(finish.Position.X - from.X, finish.Position.Y - from.Y, PAIR.swipe)
			if step ~= 0 then
				consumed = true
				onSwipe(step)
			end
		end)
		task.delay(PAIR.hold, function()
			if settled or press ~= presses or (input.Position - from).Magnitude >= PAIR.still then
				return -- let go already, a newer press, or moving: a swipe on its way (a slow one too)
			end
			settled = true
			consumed = true
			onHold(input)
		end)
	end)
	return function(): boolean
		return consumed
	end
end

PickWheel.close = close

-- One row: the picture in its ring, its name and line to the left
local function makeRow(column: Frame, item: Item, offset: number): (ImageButton, UIStroke, UIScale)
	local y = offset * PAIR.step
	local button = Instance.new("ImageButton")
	button.Name = `Row{offset}`
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.new(0.5, 0, 0.5, 0)
	button.Size = UDim2.fromOffset(SIZE, SIZE)
	button.BackgroundColor3 = item.tint or Color3.fromRGB(90, 75, 120)
	button.Image = item.image
	button.ScaleType = if item.fit then Enum.ScaleType.Fit else Enum.ScaleType.Crop
	button.ZIndex = Z + 2
	button.Parent = column
	UIKit.corner(button, SIZE / 2)
	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Color = WHITE
	ring.Thickness = 3
	ring.Parent = button
	local scale = Instance.new("UIScale")
	scale.Parent = button
	TweenService:Create(button, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.5, y) }):Play()
	local words = Instance.new("Frame")
	words.Name = `Words{offset}`
	words.BackgroundTransparency = 1
	words.AnchorPoint = Vector2.new(1, 0.5)
	words.Position = UDim2.new(0.5, -(SIZE / 2 + 12), 0.5, y)
	words.Size = UDim2.fromOffset(220, 36)
	words.ZIndex = Z + 2
	words.Parent = column
	local title = UIKit.label(words, item.title, Enum.Font.FredokaOne, 16, WHITE)
	title.Size = UDim2.new(1, 0, 0, 19)
	title.TextXAlignment = Enum.TextXAlignment.Right
	title.TextWrapped = false
	title.ZIndex = Z + 3
	UIKit.outlined(title)
	if item.line and item.line ~= "" then
		local line = UIKit.label(words, item.line, Enum.Font.GothamBold, 12, WHITE)
		line.Position = UDim2.fromOffset(0, 19)
		line.Size = UDim2.new(1, 0, 0, 15)
		line.TextXAlignment = Enum.TextXAlignment.Right
		line.TextWrapped = false
		line.ZIndex = Z + 3
		UIKit.outlined(line)
	end
	return button, ring, scale
end

-- Opens the column on `options.anchor` (nothing with fewer than two to choose between)
function PickWheel.open(options: Options)
	close()
	local screen = options.anchor:FindFirstAncestorOfClass("ScreenGui")
	local count = #options.items
	if not screen or count < 2 then
		return
	end
	local center = math.clamp(options.current, 1, count)
	local middle = options.anchor.AbsolutePosition + options.anchor.AbsoluteSize / 2 - screen.AbsolutePosition
	local dim = Instance.new("TextButton")
	dim.Name = "PickWheel"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = DIM
	dim.BackgroundTransparency = 1
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = Z
	dim.Parent = screen
	overlay = dim
	TweenService:Create(dim, TweenInfo.new(0.15), { BackgroundTransparency = 0.45 }):Play()
	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0.5, 0.5)
	column.Position = UDim2.fromOffset(middle.X, middle.Y)
	column.Size = UDim2.fromOffset(SIZE, SIZE)
	column.ZIndex = Z + 1
	column.Parent = dim

	local rows: { PairRules.Row } = {}
	local views: { [number]: { ring: UIStroke, scale: UIScale } } = {}
	local above, below = 0, 0
	local highlight = 0
	local pastEnd = 0
	local held = options.held
	local moved = false
	local swipedAt = 0

	local function paint()
		for offset, view in views do
			local on = offset == highlight
			view.ring.Color = if on then GOLD else WHITE
			view.ring.Thickness = if on then 4 else 3
			view.scale.Scale = if on then 1.12 else 1
		end
	end
	local pick: (number) -> ()
	local function build()
		for _, child in column:GetChildren() do
			child:Destroy()
		end
		table.clear(views)
		rows = PairRules.wheel(count, center, PAIR.visible)
		above, below = -rows[1].offset, rows[#rows].offset
		for _, row in rows do
			local button, ring, scale = makeRow(column, options.items[row.index], row.offset)
			views[row.offset] = { ring = ring, scale = scale }
			local offset = row.offset
			button.Activated:Connect(function()
				if held == nil then
					pick(offset)
				end
			end)
		end
		paint()
	end
	pick = function(offset: number)
		local index: number? = nil
		for _, row in rows do
			if row.offset == offset then
				index = row.index
			end
		end
		close()
		if index and index ~= options.current then
			options.onPick(index)
		end
	end
	build()

	local function middleY(): number
		return column.AbsolutePosition.Y + column.AbsoluteSize.Y / 2
	end
	local function isHeld(input: InputObject, phase: Enum.UserInputType): boolean
		local finger = held
		if not finger then
			return false
		end
		if input == finger then
			return true
		end
		-- a mouse standing in for a finger: its own movement and release
		return finger.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == phase
	end
	if held then
		table.insert(connections, UserInputService.InputChanged:Connect(function(input)
			if not isHeld(input, Enum.UserInputType.MouseMovement) then
				return
			end
			local row, beyond = PairRules.rowAt(input.Position.Y - middleY(), PAIR.step, above, below)
			moved = moved or row ~= 0
			pastEnd = beyond
			if row ~= highlight then
				highlight = row
				paint()
			end
		end))
		table.insert(connections, UserInputService.InputEnded:Connect(function(input)
			if not isHeld(input, Enum.UserInputType.MouseButton1) then
				return
			end
			held = nil -- let go: tap one from here
			pastEnd = 0
			if moved then
				pick(highlight)
			end
		end))
	end
	-- let go, a swipe on the column rolls it (when there are more than it shows); a tap off it closes it
	local swipeFrom: Vector3? = nil
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			swipeFrom = input.Position
		end
	end)
	dim.InputEnded:Connect(function(input)
		local from = swipeFrom
		swipeFrom = nil
		if not from or held ~= nil or count <= PAIR.visible then
			return
		end
		local step = PairRules.swipeStep(input.Position.X - from.X, input.Position.Y - from.Y, PAIR.swipe)
		if step ~= 0 then
			swipedAt = os.clock()
			center = (center - 1 + step) % count + 1
			highlight = 0
			build()
		end
	end)
	dim.Activated:Connect(function()
		task.defer(function()
			if held == nil and os.clock() - swipedAt > 0.2 and overlay == dim then
				close()
			end
		end)
	end)
	-- held past an end with more to show: it rolls on a row at a time
	task.spawn(function()
		while overlay == dim do
			task.wait(PAIR.roll)
			if overlay == dim and held ~= nil and pastEnd ~= 0 and count > PAIR.visible then
				center = (center - 1 + pastEnd) % count + 1
				build()
				highlight = if pastEnd < 0 then -above else below
				paint()
			end
		end
	end)
end

return PickWheel
