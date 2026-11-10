--!strict
-- The HUD layout, in one place: controllers register their buttons here instead of positioning them.
--   Side:    candy icon tiles down the left middle; the Manage tile slides out a tray of tiles to its right.
--   Bottom:  candy icon tiles in a centred row (Cards, Bag, Bosses); Context tiles (orange) join the row while visible.
-- Each tile in the cotton candy look (Config/SoftHud, HudLayout.CANDY; spec 2026-11-03-cotton-candy-ui-design): a
-- squircle in a baby colour with its icon popping out over the top edge and a squishy hover.
-- Rows use list layouts, so a controller can simply show or hide its tile and the row re-centres.
-- Numbers: Config/HudLayout. Motion: Util/Motion.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudLayout = require(Shared:WaitForChild("Config"):WaitForChild("HudLayout"))
local UIMotion = require(Shared:WaitForChild("Config"):WaitForChild("UIMotion"))

local SoftHud = require(Shared:WaitForChild("Config"):WaitForChild("SoftHud"))

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
local screen: ScreenGui
local scaled: { { scale: UIScale, min: number } } = {}
local TILE = SoftHud.TILE
local SQUISH = SoftHud.SQUISH
local resets: { () -> () } = {} -- each tile's way back to rest (Hud.setHidden: hidden rows get no MouseLeave)

-- The key letter in a small white circle on the tile's bottom-right corner
local function addKeyChip(button: GuiObject, key: string)
	local chip = Instance.new("TextLabel")
	chip.Name = "Key"
	chip.AnchorPoint = Vector2.new(0.5, 0.5)
	chip.Position = UDim2.new(1, -TILE.keyInset, 1, -TILE.keyInset)
	chip.Size = UDim2.fromOffset(HudLayout.KEY_SIZE, HudLayout.KEY_SIZE)
	chip.BackgroundColor3 = Color3.new(1, 1, 1)
	chip.Font = Enum.Font.FredokaOne
	chip.Text = key
	chip.TextSize = 14
	chip.TextColor3 = HudLayout.KEY_CHIP
	chip.ZIndex = 7
	chip.Parent = button
	UIKit.corner(chip, HudLayout.KEY_SIZE / 2)
end

type Candy = { top: Color3, bottom: Color3, deep: Color3 }

local function gradientOf(candy: Candy, shade: number): ColorSequence
	local black = Color3.new(0, 0, 0)
	return ColorSequence.new(candy.top:Lerp(black, shade), candy.bottom:Lerp(black, shade))
end

-- A piece of the tile (its body or face), `z` among its siblings
local function piece(parent: Instance, name: string, z: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	frame.Parent = parent
	return frame
end

-- The icon's shadow is a dark, faded copy of its picture (an emoji icon gets none)
local function shadeIcon(holder: GuiObject)
	local glyph = holder:FindFirstChild("Glyph")
	if glyph and glyph:IsA("ImageLabel") then
		glyph.ImageColor3 = Color3.new(0, 0, 0)
		glyph.ImageTransparency = TILE.iconShadow.transparency
		holder.Visible = true
	else
		holder.Visible = false
	end
end

-- Switches a tile's icon (and its shadow) to another picture: Manage turns into Close
local function setTileIcon(tile: GuiObject, icon: string)
	local body = tile:FindFirstChild("Body")
	if not body then
		return
	end
	local picture = body:FindFirstChild("Icon")
	local shadow = body:FindFirstChild("IconShadow")
	if picture and picture:IsA("GuiObject") then
		Icon.set(picture, icon)
		local glyph = picture:FindFirstChild("Glyph")
		if glyph and glyph:IsA("GuiObject") then
			glyph.ZIndex = picture.ZIndex
		end
	end
	if shadow and shadow:IsA("GuiObject") then
		Icon.set(shadow, icon)
		shadeIcon(shadow)
	end
end

-- A tile in the cotton candy look (spec 2026-11-03-cotton-candy-ui-design, tile pick 1): a transparent button holding
-- a soft glow in its colour and a body (anchored at its bottom centre, so it squashes and hops from there) with the
-- squircle face (gradient, white outline), the big icon over the top edge with its shadow, the label and the key
-- circle. `candy` is the tile's colours (HudLayout.CANDY / CANDY_FAN). Hover plays SoftHud.SQUISH (mouse only); a
-- press squashes it flat and springs back; the hovered or pressed tile draws over its neighbours.
local function makeTile(parent: Instance, spec: TileSpec, candy: Candy): TextButton
	local width = HudLayout.TILE_SIZE.X
	local tile = Instance.new("TextButton")
	tile.Name = spec.id
	tile.LayoutOrder = spec.order
	tile.Size = UDim2.fromOffset(width, HudLayout.TILE_SIZE.Y)
	tile.BackgroundTransparency = 1
	tile.AutoButtonColor = false
	tile.Text = ""
	tile.TextColor3 = Color3.new(1, 1, 1)
	tile.Parent = parent

	local glow = UIKit.glow(tile, candy.bottom, width * TILE.corner, TILE.glow.drop, TILE.glow.transparency)
	glow.ZIndex = 1
	local body = piece(tile, "Body", 2)
	body.BackgroundTransparency = 1
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromScale(1, 1)
	local face = piece(body, "Face", 3)
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	UIKit.corner(face, width * TILE.corner)
	local fill = Instance.new("UIGradient")
	fill.Name = "Fill"
	fill.Rotation = 90
	fill.Color = gradientOf(candy, 0)
	fill.Parent = face
	UIKit.outline(face, Color3.new(1, 1, 1), HudLayout.OUTLINE)

	-- The big icon popping out over the top edge, with its shadow just under it
	local iconSize = UDim2.fromScale(TILE.icon, TILE.icon)
	local shadow = Icon.make(body, spec.icon, iconSize)
	shadow.Name = "IconShadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0)
	shadow.Position = UDim2.new(0.5, 0, -TILE.iconRise, TILE.iconShadow.drop)
	shadow.ZIndex = 4
	shadeIcon(shadow)
	local picture = Icon.make(body, spec.icon, iconSize)
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.fromScale(0.5, -TILE.iconRise)
	picture.ZIndex = 5
	local glyph = picture:FindFirstChild("Glyph")
	if glyph and glyph:IsA("GuiObject") then
		glyph.ZIndex = picture.ZIndex
	end

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = UDim2.fromScale(0, 0.95)
	label.Size = UDim2.fromScale(1, TILE.label)
	label.Font = Enum.Font.FredokaOne
	label.Text = spec.label
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.ZIndex = 6
	label.Parent = body
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 18
	limit.Parent = label
	local edge = Instance.new("UIStroke")
	edge.Color = candy.deep -- white words outlined in the tile's deep shade
	edge.Thickness = 1.5
	edge.Parent = label
	if spec.key then
		addKeyChip(body, spec.key)
	end
	tile.Activated:Connect(spec.onClick)

	-- The squishy motion (SoftHud.SQUISH): each newer hover, leave or press cancels what's running, so a tile never
	-- stays squashed or lifted
	local hovered, pressed = false, false
	local token = 0
	local baseZ: number? = nil -- the tile's own ZIndex while it's lifted over its neighbours (the tray sets its later)
	local function lift()
		if not baseZ then
			baseZ = tile.ZIndex
			tile.ZIndex += 1
		end
	end
	local function drop()
		if baseZ then
			tile.ZIndex = baseZ
			baseZ = nil
		end
	end
	local running: Tween? = nil
	local function pose(x: number, y: number, lift: number, seconds: number, style: Enum.EasingStyle): Tween
		local tween = TweenService:Create(body, TweenInfo.new(seconds, style, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(x, y),
			Position = UDim2.new(0.5, 0, 1, -lift),
		})
		running = tween
		tween:Play()
		return tween
	end
	local function settle()
		token += 1
		local last = SQUISH.steps[#SQUISH.steps]
		if hovered then
			pose(last.x, last.y, last.lift, SQUISH.release, Enum.EasingStyle.Back)
		else
			pose(1, 1, 0, SQUISH.release, Enum.EasingStyle.Back)
		end
		if hovered then
			lift()
		else
			drop()
		end
	end
	local function playHover()
		token += 1
		local mine = token
		lift()
		local function step(index: number)
			local frame = SQUISH.steps[index]
			if mine ~= token or not frame then
				return
			end
			pose(frame.x, frame.y, frame.lift, frame.seconds, Enum.EasingStyle.Sine).Completed:Once(function(state)
				if state == Enum.PlaybackState.Completed then
					step(index + 1)
				end
			end)
		end
		step(1)
	end
	tile.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled then
			hovered = true
			if not pressed then
				playHover()
			end
		end
	end)
	tile.MouseLeave:Connect(function()
		hovered = false
		pressed = false -- dragged off while held: the press ends here (its release lands elsewhere)
		settle()
	end)
	tile.MouseButton1Down:Connect(function()
		pressed = true
		token += 1
		lift()
		local press = SQUISH.press
		pose(press.x, press.y, 0, press.seconds, Enum.EasingStyle.Quad)
	end)
	local function release()
		if pressed then
			pressed = false
			settle()
		end
	end
	tile.MouseButton1Up:Connect(release)
	tile.Activated:Connect(release)
	-- A release anywhere ends a press too (a finger lifted off the tile, a mouse let go outside it)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			release()
		end
	end)
	-- Hidden mid-motion (Drop and Rip hide right after a click; the binder hides the whole HUD): back to rest at once,
	-- the running tween cancelled so it can't finish into a hovered pose while nobody sees it
	local function rest()
		hovered, pressed = false, false
		token += 1
		local tween = running
		if tween then
			tween:Cancel()
		end
		body.Size = UDim2.fromScale(1, 1)
		body.Position = UDim2.fromScale(0.5, 1)
		drop()
	end
	table.insert(resets, rest)
	tile:GetPropertyChangedSignal("Visible"):Connect(function()
		if not tile.Visible then
			rest()
		end
	end)
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
		local label = tile:FindFirstChild("Label", true) :: TextLabel?
		local face = tile:FindFirstChild("Face", true)
		local fill = if face then face:FindFirstChild("Fill") else nil
		if fill and fill:IsA("UIGradient") then
			fill.Color = gradientOf(HudLayout.CANDY.Manage, if open then HudLayout.CANDY_OPEN_SHADE else 0)
		end
		setTileIcon(tile, if open then "Close" else "Manage")
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
	}, HudLayout.CANDY.Manage)
end

-- How big the HUD draws on this screen (HudLayout.SCALE): 1 on roomy screens, smaller on short ones, at least min
function Hud.scaleFor(min: number?): number
	local look = HudLayout.SCALE
	local height = if screen then screen.AbsoluteSize.Y else look.REFERENCE_HEIGHT
	return math.clamp(height / look.REFERENCE_HEIGHT, min or look.MIN, 1)
end

-- Gives a HUD frame a UIScale that follows the screen's height (kept up to date when the screen resizes)
function Hud.scaleWith(frame: GuiObject, min: number?): UIScale
	local scale = Instance.new("UIScale")
	scale.Scale = Hud.scaleFor(min)
	scale.Parent = frame
	table.insert(scaled, { scale = scale, min = min or HudLayout.SCALE.MIN })
	return scale
end

-- Builds the HUD containers on the main ScreenGui; UIController calls it first thing
function Hud.mount(screenGui: ScreenGui)
	screen = screenGui
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		for _, entry in scaled do
			entry.scale.Scale = Hud.scaleFor(entry.min)
		end
	end)
	side = Instance.new("Frame")
	side.Name = "HudSide"
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(0, 0.5)
	side.Position = UDim2.new(0, HudLayout.SIDE_X, 0.5, 0)
	side.Size = UDim2.fromOffset(HudLayout.TILE_SIZE.X, 0)
	side.AutomaticSize = Enum.AutomaticSize.Y
	side.Parent = screenGui
	local sideList = Instance.new("UIListLayout")
	sideList.Padding = UDim.new(0, HudLayout.SIDE_GAP)
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
	for _, frame in { side, bottom, fan } do
		Hud.scaleWith(frame)
	end
end

function Hud.tile(spec: TileSpec): TextButton
	local parent = if spec.group == "Side" then side else bottom
	local tile = makeTile(parent, spec, HudLayout.CANDY[spec.id] or HudLayout.CANDY.Manage)
	tiles[spec.id] = tile
	return tile
end

-- A tile in the Manage tray (HudLayout.CANDY_FAN colours by its order); tapping it also folds the tray away
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
	}, HudLayout.CANDY_FAN[(math.max(spec.order, 1) - 1) % #HudLayout.CANDY_FAN + 1])
	button.ZIndex = fan.ZIndex + 1
	table.insert(fanButtons, { order = spec.order, button = button })
	return button
end

-- A HUD button by id: a tile, a Manage tray button, or "Manage" (the tray's own tile); nil when there's none. The
-- tutorial points a bouncing paw at it.
function Hud.find(id: string): GuiObject?
	if id == "Manage" then
		return manageTile
	end
	local tile = tiles[id]
	if tile then
		return tile
	end
	for _, entry in fanButtons do
		if entry.button.Name == id then
			return entry.button
		end
	end
	return nil
end

-- Whether the Manage tray is open now, and opening or closing it
function Hud.isTrayOpen(): boolean
	return fanOpen
end

function Hud.openTray(open: boolean)
	setFan(open)
end

function Hud.setLabel(id: string, text: string)
	local tile = tiles[id]
	local label = if tile then tile:FindFirstChild("Label", true) else nil
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

-- The calm HUD (Pish's first visit, round 3 pick A): pieces the tour doesn't use hide while it's on
local calmPieces: { [GuiObject]: boolean } = {}
local calm = false
local calmListeners: { () -> () } = {}

local function apply(show: boolean)
	side.Visible = show
	bottom.Visible = show
	for _, object in hideWithHud do
		object.Visible = show and not (calm and calmPieces[object])
	end
	for object in calmPieces do
		if not table.find(hideWithHud, object) then
			object.Visible = not calm
		end
	end
end

-- A piece of the HUD the first visit doesn't use (the party bar, the weapon switch, the Bosses tile): hidden while calm
function Hud.calmPiece(object: GuiObject)
	calmPieces[object] = true
	if calm then
		apply(next(hiddenBy) == nil)
	end
end

-- Calm on while Pish's first visit runs (TutorialController); pieces that show and hide themselves (the buff chips)
-- ask Hud.isCalm and listen with Hud.onCalm
function Hud.setCalm(on: boolean)
	if calm == on then
		return
	end
	calm = on
	apply(next(hiddenBy) == nil)
	for _, callback in calmListeners do
		callback()
	end
end

function Hud.isCalm(): boolean
	return calm
end

function Hud.onCalm(callback: () -> ())
	table.insert(calmListeners, callback)
end

function Hud.setHidden(reason: string, hidden: boolean)
	hiddenBy[reason] = if hidden then true else nil
	local show = next(hiddenBy) == nil
	apply(show)
	if not show then
		for _, rest in resets do
			rest()
		end
	end
	if not show and fanOpen then
		setFan(false)
	end
end

return Hud
