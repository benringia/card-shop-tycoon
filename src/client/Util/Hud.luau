--!strict
-- The HUD layout, in one place: controllers register their buttons here instead of positioning them.
--   Side:    candy icon tiles down the left middle; the Phone tile (it was Manage, and its id still is) opens the
--            phone: it rises in the middle with the world dimmed behind, its apps on the home screen (owner
--            2026-11-13: "no more manage button. replace it with a phone"; HudLayout.PHONE). An app may open a page
--            inside the phone (Hud.phonePage: the Reviews feed) instead of its own window.
--   Bottom:  candy icon tiles in a centred row (Cards, Bag, Bosses); Context tiles (orange) join the row while visible.
--   Phones (owner 2026-11-13, round 2 pick A: "move the admin tile inside phone and move binder tile under phone"):
--            Bag, Bosses and Admin become Phone apps, Cards moves to the side column under the Phone, and the Phone
--            shows everywhere with its shop apps (Shop, Prices, Jobs, Reviews) only in town (Util/CompactHud.spot;
--            UIController calls Hud.setCompact).
-- Each tile in the cotton candy look (Config/SoftHud, HudLayout.CANDY; spec 2026-11-03-cotton-candy-ui-design): a
-- squircle in a baby colour with its icon popping out over the top edge and a squishy hover.
-- Rows use list layouts, so a controller can simply show or hide its tile and the row re-centres.
-- Numbers: Config/HudLayout. Motion: Util/Motion.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudLayout = require(Shared:WaitForChild("Config"):WaitForChild("HudLayout"))
local Music = require(Shared:WaitForChild("Config"):WaitForChild("Music"))
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local MusicRules = require(Shared:WaitForChild("Util"):WaitForChild("MusicRules"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local UIMotion = require(Shared:WaitForChild("Config"):WaitForChild("UIMotion"))
local CompactHud = require(Shared:WaitForChild("Util"):WaitForChild("CompactHud"))

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
	phoneApp: number?, -- on a phone screen: a Phone app at this order (Bag, Bosses, Admin)
	phoneAlways: boolean?, -- with phoneApp: a Phone app on a computer too (Bosses, Admin)
	phoneSide: number?, -- on a phone screen: in the side column under the Phone at this order (Cards)
}
-- An app on the phone; `stay`: tapping it keeps the phone open (it shows a page inside it); `everywhere`: shown away
-- from town too (Party), where the other apps (the shop's) hide
export type FanSpec = { id: string, icon: string, label: string, order: number, onClick: () -> (), stay: boolean?, everywhere: boolean? }

local Hud = {}

local side: Frame
local bottom: Frame
local fan: Frame -- the phone's layer: the dim and the phone (still named HudFan: fights hide it by that name)
local phone: Frame
local dim: TextButton
local apps: Frame -- the home screen's app grid
local phoneScreen: Frame -- inside the bezel: the status bar, the home screen and the app pages
local homeScreen: Frame
local statusRight: TextLabel
local clockLabel: TextLabel
local pages: { [string]: Frame } = {}
local openPage: string? = nil
local badges: { [string]: TextLabel } = {}
local manageTile: TextButton? = nil
local fanOpen = false
local tiles: { [string]: TextButton } = {}
-- Every tile and app with where it may go (CompactHud.spot): its home frame, its order there, in the Phone, at the side
type Entry = {
	button: TextButton,
	rule: { app: boolean?, everywhere: boolean?, phone: boolean?, side: boolean?, always: boolean? },
	home: Frame,
	order: number,
	appOrder: number,
	sideOrder: number,
}
local entries: { Entry } = {}
local compact = false -- the phone's slim HUD (UIController: touch screens)
-- In town (Hud.inTown): the Frontier and the Dungeon never are; the main place checks where you stand (watchTown)
local townShown = not (Place.isFrontier() or Place.isDungeon())
local townListeners: { (boolean) -> () } = {}
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

local PHONE = HudLayout.PHONE

local function rgbOf(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function spotOf(entry: Entry): CompactHud.Spot
	return CompactHud.spot(entry.rule, compact, townShown)
end

-- The apps inside the phone now, in order
local function phoneApps(): { Entry }
	local list = {}
	for _, entry in entries do
		if spotOf(entry) == "phone" then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		return a.appOrder < b.appOrder
	end)
	return list
end

-- Back to the home screen (an app's page closes)
local function showHome()
	openPage = nil
	for _, page in pages do
		page.Visible = false
	end
	homeScreen.Visible = true
end

-- Opens or puts away the phone: it rises from the bottom into the middle as the world dims, its apps popping in one
-- after another; put away, it drops back down
local function setFan(open: boolean)
	if open == fanOpen then
		return
	end
	fanOpen = open
	local tile = manageTile
	if tile then
		local label = tile:FindFirstChild("Label", true) :: TextLabel?
		local face = tile:FindFirstChild("Face", true)
		local fill = if face then face:FindFirstChild("Fill") else nil
		if fill and fill:IsA("UIGradient") then
			fill.Color = gradientOf(HudLayout.CANDY.Manage, if open then HudLayout.CANDY_OPEN_SHADE else 0)
		end
		setTileIcon(tile, if open then "Close" else PHONE.icon)
		if label then
			label.Text = if open then "Close" else PHONE.label
		end
	end
	local slide = TweenInfo.new(PHONE.slide, Enum.EasingStyle.Back, if open then Enum.EasingDirection.Out else Enum.EasingDirection.In)
	if open then
		showHome()
		clockLabel.Text = os.date("%H:%M") :: string
		fan.Visible = true
		dim.BackgroundTransparency = 1
		phone.Position = UDim2.fromScale(0.5, 1.6)
		TweenService:Create(dim, TweenInfo.new(PHONE.slide), { BackgroundTransparency = PHONE.dim }):Play()
		TweenService:Create(phone, slide, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
		for _, entry in entries do
			if entry.rule.app and spotOf(entry) ~= "phone" then
				entry.button.Visible = false -- a shop app away from town
			end
		end
		for index, entry in phoneApps() do
			local button = entry.button
			button.Visible = false
			task.delay(PHONE.slide * 0.6 + (index - 1) * UIMotion.FAN_STAGGER, function()
				if fanOpen then
					button.Visible = true
					Motion.popIn(button)
				end
			end)
		end
		return
	end
	TweenService:Create(dim, TweenInfo.new(PHONE.slide), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(phone, slide, { Position = UDim2.fromScale(0.5, 1.6) }):Play()
	task.delay(PHONE.slide, function()
		if not fanOpen then
			fan.Visible = false
		end
	end)
end

local function ensureManageTile()
	if manageTile then
		return
	end
	manageTile = makeTile(side, {
		id = "Manage", -- the Phone tile keeps the Manage id (the tutorial points at it by that name)
		icon = PHONE.icon,
		label = PHONE.label,
		group = "Side",
		order = 0,
		onClick = function()
			setFan(not fanOpen)
		end,
	}, HudLayout.CANDY.Manage)
end

-- Puts every tile and app where it goes now (CompactHud.spot: a phone screen or not, in town or not) and shows the
-- Phone tile where it holds an app (CompactHud.phoneTile)
local function layout()
	local spots: { CompactHud.Spot } = {}
	for _, entry in entries do
		local spot = spotOf(entry)
		table.insert(spots, spot)
		local button = entry.button
		if entry.rule.app then
			if fanOpen then
				button.Visible = spot == "phone"
			end
			continue
		end
		local parent = if spot == "phone" then apps elseif spot == "side" then side else entry.home
		button.LayoutOrder = if spot == "phone" then entry.appOrder elseif spot == "side" then entry.sideOrder else entry.order
		if button.Parent ~= parent then
			local wasInPhone = button.Parent == apps
			button.Parent = parent
			button.ZIndex = if spot == "phone" then 35 else 1
			if wasInPhone then
				button.Visible = true -- the phone's pop-in may have left it hidden
			end
		end
	end
	local tile = manageTile
	if tile then
		tile.Visible = CompactHud.phoneTile(spots)
		if not tile.Visible and fanOpen then
			setFan(false)
		end
	end
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
-- Town-only buttons (the Phone's shop apps: Shop, Prices, Jobs, Reviews) show only in town (owner 2026-11-12: "remove
-- unnecessary buttons when it's only needed in town"): in the main place they hide in the Wild valley
-- (MusicRules.inTown, the music's own town edge); the Frontier and the Dungeon never make them. The Phone itself stays
-- with its other apps (Party, Support, Bosses, Admin; on a phone Bag too) (layout)
local function watchTown()
	if Place.isFrontier() or Place.isDungeon() then
		return
	end
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < HudLayout.TOWN_CHECK then
			return
		end
		since = 0
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not root or not root:IsA("BasePart") then
			return
		end
		local inTown = MusicRules.inTown(root.Position.X, root.Position.Z, Town.BOUNDS, Music.TOWN.margin)
		if inTown ~= townShown then
			townShown = inTown
			layout()
			for _, listener in townListeners do
				task.spawn(listener, inTown)
			end
		end
	end)
end

-- The phone (HudLayout.PHONE): a layer over the HUD with the dim (tapping it puts the phone away) and the phone in the
-- middle: its bezel, the screen with a status bar (the time, and what Hud.setPhoneStatus says: the shop rating), the
-- home screen (the shop's name, Pish and Chikin, the app grid) and the app pages (Hud.phonePage)
local function buildPhone(screenGui: ScreenGui)
	fan = Instance.new("Frame")
	fan.Name = "HudFan"
	fan.BackgroundTransparency = 1
	fan.Size = UDim2.fromScale(1, 1)
	fan.ZIndex = 30 -- over the HUD and the windows
	fan.Visible = false
	fan.Parent = screenGui

	dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Position = UDim2.fromOffset(0, -80) -- up under Roblox's top bar too (the screen starts below its inset)
	dim.Size = UDim2.new(1, 0, 1, 80)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.ZIndex = 30
	dim.Parent = fan
	dim.Activated:Connect(function()
		setFan(false)
	end)

	phone = Instance.new("Frame")
	phone.Name = "Phone"
	phone.AnchorPoint = Vector2.new(0.5, 0.5)
	phone.Position = UDim2.fromScale(0.5, 1.6)
	phone.Size = UDim2.fromOffset(PHONE.size[1], PHONE.size[2])
	phone.BackgroundColor3 = rgbOf(PHONE.bezel)
	phone.ZIndex = 31
	phone.Parent = fan
	UIKit.corner(phone, 38)
	UIKit.outline(phone, Color3.new(1, 1, 1), 4)
	local fit = Instance.new("UIScale")
	fit.Parent = phone
	local function scaleToScreen()
		fit.Scale = math.min(1, (screenGui.AbsoluteSize.Y * PHONE.fit) / PHONE.size[2])
	end
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(scaleToScreen)
	scaleToScreen()

	phoneScreen = Instance.new("Frame")
	phoneScreen.Name = "Screen"
	phoneScreen.Position = UDim2.fromOffset(10, 10)
	phoneScreen.Size = UDim2.new(1, -20, 1, -20)
	phoneScreen.BackgroundColor3 = Color3.new(1, 1, 1)
	phoneScreen.ClipsDescendants = true
	phoneScreen.ZIndex = 32
	phoneScreen.Parent = phone
	UIKit.corner(phoneScreen, 30)
	local wall = Instance.new("UIGradient")
	wall.Rotation = 120
	wall.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgbOf(PHONE.wall[1])),
		ColorSequenceKeypoint.new(0.6, rgbOf(PHONE.wall[2])),
		ColorSequenceKeypoint.new(1, rgbOf(PHONE.wall[3])),
	})
	wall.Parent = phoneScreen
	local ink = rgbOf(PHONE.ink)

	-- the status bar: the time on the left, the shop rating on the right, the notch between
	local notch = Instance.new("Frame")
	notch.AnchorPoint = Vector2.new(0.5, 0)
	notch.Position = UDim2.new(0.5, 0, 0, 6)
	notch.Size = UDim2.fromOffset(84, 20)
	notch.BackgroundColor3 = rgbOf(PHONE.bezel)
	notch.ZIndex = 40
	notch.Parent = phoneScreen
	UIKit.corner(notch, 10)
	clockLabel = UIKit.label(phoneScreen, "", Enum.Font.FredokaOne, 16, ink)
	clockLabel.Position = UDim2.fromOffset(22, 6)
	clockLabel.Size = UDim2.fromOffset(70, 22)
	clockLabel.ZIndex = 40
	statusRight = UIKit.label(phoneScreen, "", Enum.Font.FredokaOne, 15, ink)
	statusRight.AnchorPoint = Vector2.new(1, 0)
	statusRight.Position = UDim2.new(1, -20, 0, 6)
	statusRight.Size = UDim2.fromOffset(80, 22)
	statusRight.TextXAlignment = Enum.TextXAlignment.Right
	statusRight.ZIndex = 40

	-- the home screen: the shop's name, Pish and Chikin, the apps
	homeScreen = Instance.new("Frame")
	homeScreen.Name = "Home"
	homeScreen.BackgroundTransparency = 1
	homeScreen.Position = UDim2.fromOffset(0, 34)
	homeScreen.Size = UDim2.new(1, 0, 1, -34)
	homeScreen.ZIndex = 33
	homeScreen.Parent = phoneScreen
	local name = UIKit.label(homeScreen, string.format(PHONE.title, Players.LocalPlayer.DisplayName), Enum.Font.FredokaOne, 20, ink)
	name.Position = UDim2.fromOffset(12, 4)
	name.Size = UDim2.new(1, -24, 0, 26)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.ZIndex = 34
	local dogs = Instance.new("ImageLabel")
	dogs.BackgroundTransparency = 1
	dogs.Image = PHONE.picture
	dogs.ScaleType = Enum.ScaleType.Fit
	dogs.AnchorPoint = Vector2.new(0.5, 0)
	dogs.Position = UDim2.new(0.5, 0, 0, 34)
	dogs.Size = UDim2.new(1, -60, 0, 110)
	dogs.ZIndex = 34
	dogs.Parent = homeScreen
	apps = Instance.new("Frame")
	apps.Name = "Apps"
	apps.BackgroundTransparency = 1
	apps.Position = UDim2.fromOffset(10, 160)
	apps.Size = UDim2.new(1, -20, 1, -190)
	apps.ZIndex = 34
	apps.Parent = homeScreen
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(HudLayout.TILE_SIZE.X, HudLayout.TILE_SIZE.Y)
	grid.CellPadding = UDim2.fromOffset(12, 26)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.FillDirectionMaxCells = PHONE.columns
	grid.Parent = apps
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 22) -- room for the icons popping over their tiles' top edge
	pad.Parent = apps

	-- the home bar along the bottom: tapping it goes back home (or puts the phone away from home)
	local home = Instance.new("TextButton")
	home.Name = "HomeBar"
	home.Text = ""
	home.AutoButtonColor = false
	home.AnchorPoint = Vector2.new(0.5, 1)
	home.Position = UDim2.new(0.5, 0, 1, -6)
	home.Size = UDim2.fromOffset(110, 8)
	home.BackgroundColor3 = ink
	home.BackgroundTransparency = 0.4
	home.ZIndex = 41
	home.Parent = phoneScreen
	UIKit.corner(home, 4)
	home.Activated:Connect(function()
		if openPage then
			showHome()
		else
			setFan(false)
		end
	end)
end

function Hud.mount(screenGui: ScreenGui)
	screen = screenGui
	watchTown()
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

	buildPhone(screenGui)
	for _, frame in { side, bottom } do
		Hud.scaleWith(frame)
	end
	ensureManageTile() -- the Phone tile, shown once it holds an app (layout)
	layout()
end

-- Lifts the side column (the Phone, Cards) `px` up from the screen's middle: the party dock under it on a short PC
-- window (UIController)
function Hud.liftSide(px: number)
	if side then
		side.Position = UDim2.new(0, HudLayout.SIDE_X, 0.5, -px)
	end
end

function Hud.tile(spec: TileSpec): TextButton
	local parent = if spec.group == "Side" then side else bottom
	local onClick = spec.onClick
	local tile: TextButton
	-- inside the Phone (spec.phoneApp on a phone screen) a tap puts the phone away first, like any app
	local made = table.clone(spec)
	made.onClick = function()
		if tile.Parent == apps then
			setFan(false)
		end
		onClick()
	end
	tile = makeTile(parent, made, HudLayout.CANDY[spec.id] or HudLayout.CANDY.Manage)
	tiles[spec.id] = tile
	if spec.phoneApp then
		ensureManageTile()
	end
	table.insert(entries, {
		button = tile,
		rule = { phone = spec.phoneApp ~= nil, side = spec.phoneSide ~= nil, always = spec.phoneAlways },
		home = parent,
		order = spec.order,
		appOrder = spec.phoneApp or spec.order,
		sideOrder = spec.phoneSide or spec.order,
	})
	layout()
	return tile
end

-- An app on the phone's home screen (HudLayout.CANDY_FAN colours by its order); tapping it puts the phone away and
-- opens its window, or (`stay`) keeps the phone open for a page inside it
function Hud.fanButton(spec: FanSpec): TextButton
	ensureManageTile()
	local button = makeTile(apps, {
		id = spec.id,
		icon = spec.icon,
		label = spec.label,
		group = "Side",
		order = spec.order,
		onClick = function()
			if not spec.stay then
				setFan(false)
			end
			spec.onClick()
		end,
	}, HudLayout.CANDY_FAN[(math.max(spec.order, 1) - 1) % #HudLayout.CANDY_FAN + 1])
	button.ZIndex = 35
	-- a red count on its corner (Hud.setBadge), hidden at 0
	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -6, 0, -10)
	badge.Size = UDim2.fromOffset(24, 24)
	badge.BackgroundColor3 = rgbOf(PHONE.badge)
	badge.Font = Enum.Font.FredokaOne
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.TextSize = 15
	badge.ZIndex = 20
	badge.Visible = false
	badge.Parent = button
	UIKit.corner(badge, 12)
	UIKit.outline(badge, Color3.new(1, 1, 1), 2)
	badges[spec.id] = badge
	table.insert(entries, {
		button = button,
		rule = { app = true, everywhere = spec.everywhere },
		home = apps,
		order = spec.order,
		appOrder = spec.order,
		sideOrder = spec.order,
	})
	layout()
	return button
end

-- The phone's slim HUD on or off (UIController, touch screens): tiles move into the Phone or under it, and back
function Hud.setCompact(on: boolean)
	if on == compact then
		return
	end
	compact = on
	layout()
end

-- Whether you're in town now (the main place's town; never in the Frontier or the Dungeon), and told when it changes
function Hud.inTown(): boolean
	return townShown
end

function Hud.onTown(listener: (boolean) -> ())
	table.insert(townListeners, listener)
end

-- Whether a tile or app sits inside the Phone now (the tutorial points at the Phone tile while it's shut)
function Hud.inPhone(id: string): boolean
	for _, entry in entries do
		if entry.button.Name == id then
			return spotOf(entry) == "phone"
		end
	end
	return false
end

-- An app's page inside the phone (made once): a header with a back arrow and its title, and the content frame it
-- returns. Hud.showPhonePage opens it
function Hud.phonePage(id: string, title: string): Frame
	local made = pages[id]
	if not made then
		made = Instance.new("Frame")
		made.Name = `Page_{id}`
		made.BackgroundTransparency = 1
		made.Position = UDim2.fromOffset(0, 34)
		made.Size = UDim2.new(1, 0, 1, -34)
		made.ZIndex = 33
		made.Visible = false
		made.Parent = phoneScreen
		local ink = rgbOf(PHONE.ink)
		local back = Instance.new("TextButton")
		back.Name = "Back"
		back.BackgroundTransparency = 1
		back.Position = UDim2.fromOffset(8, 0)
		back.Size = UDim2.fromOffset(48, 48)
		back.Font = Enum.Font.FredokaOne
		back.Text = "<"
		back.TextSize = 30
		back.TextColor3 = ink
		back.ZIndex = 36
		back.Parent = made
		back.Activated:Connect(showHome)
		local heading = UIKit.label(made, title, Enum.Font.FredokaOne, 22, ink)
		heading.Position = UDim2.fromOffset(56, 8)
		heading.Size = UDim2.new(1, -112, 0, 32)
		heading.TextXAlignment = Enum.TextXAlignment.Center
		heading.ZIndex = 36
		local content = Instance.new("Frame")
		content.Name = "Content"
		content.BackgroundTransparency = 1
		content.Position = UDim2.fromOffset(10, 50)
		content.Size = UDim2.new(1, -20, 1, -70)
		content.ZIndex = 34
		content.Parent = made
		pages[id] = made
	end
	return made:FindFirstChild("Content") :: Frame
end

-- Shows an app's page (the phone opens if it isn't)
function Hud.showPhonePage(id: string)
	local page = pages[id]
	if not page then
		return
	end
	setFan(true)
	homeScreen.Visible = false
	for other, frame in pages do
		frame.Visible = other == id
	end
	openPage = id
end

-- The red count on an app's icon (0 hides it)
function Hud.setBadge(id: string, count: number)
	local badge = badges[id]
	if badge then
		badge.Visible = count > 0
		badge.Text = if count > 9 then "9+" else tostring(count)
	end
end

-- The words on the right of the phone's status bar (the shop rating)
function Hud.setPhoneStatus(text: string)
	if statusRight then
		statusRight.Text = text
	end
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
	for _, entry in entries do
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

-- The calm HUD (Pish's first visit, round 3 pick A; Chikin's tour's focus mode, 2026-11-11): named pieces the tour
-- doesn't use ("party", "weapons", "bosses", "buffs", "mascot") hide while a guide asks for it; each guide (a source)
-- names the pieces it keeps, and a piece hides while any guide on doesn't keep it
local calmPieces: { [GuiObject]: string } = {}
local focusBy: { [string]: { [string]: boolean } } = {}
local calmListeners: { () -> () } = {}

local function hides(name: string?): boolean
	if not name then
		return false
	end
	for _, kept in focusBy do
		if not kept[name] then
			return true
		end
	end
	return false
end

local function apply(show: boolean)
	side.Visible = show
	bottom.Visible = show
	for _, object in hideWithHud do
		object.Visible = show and not hides(calmPieces[object])
	end
	for object, name in calmPieces do
		if not table.find(hideWithHud, object) then
			object.Visible = not hides(name)
		end
	end
end

-- A piece of the HUD a tour may not use (the party bar, the weapon switch, the Bosses tile), by name
function Hud.calmPiece(object: GuiObject, name: string)
	calmPieces[object] = name
	if next(focusBy) then
		apply(next(hiddenBy) == nil)
	end
end

-- `source` (a guide: "pish", "chikin") asks for the calm HUD keeping only the pieces named in `keep`; nil lets go.
-- Pieces that show and hide themselves (the buff chips, the peeking Pish) ask Hud.hides and listen with Hud.onCalm
function Hud.setFocus(source: string, keep: { string }?)
	local before = focusBy[source]
	local after: { [string]: boolean }? = nil
	if keep then
		after = {}
		for _, name in keep do
			(after :: { [string]: boolean })[name] = true
		end
	end
	local same = (before == nil) == (after == nil)
	if same and before and after then
		for name in before do
			same = same and after[name] == true
		end
		for name in after do
			same = same and before[name] == true
		end
	end
	if same then
		return
	end
	focusBy[source] = after
	apply(next(hiddenBy) == nil)
	for _, callback in calmListeners do
		callback()
	end
end

-- Calm on while Pish's first visit runs (TutorialController): every piece hidden
function Hud.setCalm(on: boolean)
	Hud.setFocus("pish", if on then {} else nil)
end

-- Whether the calm HUD hides the piece `name` now
function Hud.hides(name: string): boolean
	return hides(name)
end

function Hud.isCalm(): boolean
	return next(focusBy) ~= nil
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
