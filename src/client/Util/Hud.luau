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
local PhoneForm = require(Shared:WaitForChild("Config"):WaitForChild("PhoneForm"))
local Music = require(Shared:WaitForChild("Config"):WaitForChild("Music"))
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local MusicRules = require(Shared:WaitForChild("Util"):WaitForChild("MusicRules"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local UIMotion = require(Shared:WaitForChild("Config"):WaitForChild("UIMotion"))
local CompactHud = require(Shared:WaitForChild("Util"):WaitForChild("CompactHud"))
local HudGrowConfig = require(Shared:WaitForChild("Config"):WaitForChild("HudGrow"))
local HudGrow = require(Shared:WaitForChild("Util"):WaitForChild("HudGrow"))

local SoftHud = require(Shared:WaitForChild("Config"):WaitForChild("SoftHud"))
local BabyColors = require(Shared:WaitForChild("Config"):WaitForChild("BabyColors"))

local Util = script.Parent :: Instance
local PhoneNotice = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("PhoneNotice"))
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
	phoneBottom: boolean?, -- on a phone screen: in the bottom-centre row, clear of the thumbstick (Gift)
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
local apps: ScrollingFrame -- the home screen's app grid (its rows past the screen scroll)
local phoneScreen: Frame -- inside the bezel: the status bar, the home screen and the app pages
local homeScreen: Frame
local statusRight: TextLabel
local clockLabel: TextLabel
local pages: { [string]: Frame } = {}
local openPage: string? = nil
local badges: { [string]: TextLabel } = {}
local badgeCounts: { [string]: number } = {} -- what waits in each app (Hud.setBadge): the Phone tile shows their sum
local phoneBadge: TextLabel? = nil
local manageTile: TextButton? = nil
local fanOpen = false
local tiles: { [string]: TextButton } = {}
-- Every tile and app with where it may go (CompactHud.spot): its home frame, its order there, in the Phone, at the side
type Entry = {
	button: TextButton,
	rule: { app: boolean?, everywhere: boolean?, phone: boolean?, side: boolean?, always: boolean?, bottom: boolean? },
	home: GuiObject,
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
local scaled: { { scale: UIScale, min: number, grow: boolean } } = {}
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

-- The icon's shadow is a dark, faded copy of its picture or of each picture in a stack (an emoji icon gets none)
local function shadeIcon(holder: GuiObject)
	local glyph = holder:FindFirstChild("Glyph")
	local pictures: { ImageLabel } = {}
	if glyph and glyph:IsA("ImageLabel") then
		table.insert(pictures, glyph)
	elseif glyph and glyph:IsA("Frame") then
		for _, picture in glyph:GetChildren() do
			if picture:IsA("ImageLabel") then
				table.insert(pictures, picture)
			end
		end
	end
	for _, picture in pictures do
		picture.ImageColor3 = Color3.new(0, 0, 0)
		picture.ImageTransparency = TILE.iconShadow.transparency
	end
	holder.Visible = #pictures > 0
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
		Icon.layer(picture, picture.ZIndex)
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
	Icon.layer(picture, picture.ZIndex)

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

-- A Config/BabyColors colour by name as a tile's candy (grey-lilac for a name it doesn't know)
local function candyNamed(name: string): Candy
	local shades = BabyColors.COLORS[name] or BabyColors.COLORS.greyLilac
	return { top = rgbOf(shades.light), bottom = rgbOf(shades.fill), deep = rgbOf(shades.deep) }
end

-- A tile in the HUD's own look for a bar of its own (the Edit bar, EditBarController), outside the HUD's rows. Made
-- once and repainted (Hud.paintTile): each tile keeps its motion's connections for good
function Hud.candyTile(parent: Instance, id: string, order: number, onClick: () -> ()): TextButton
	return makeTile(parent, { id = id, icon = "Box", label = "", group = "Bottom", order = order, onClick = onClick }, candyNamed("greyLilac"))
end

-- A candy tile's picture, words and colour (a Config/BabyColors name) again; `fade` makes its picture that see-through
-- (a tile with nothing to do)
function Hud.paintTile(tile: GuiObject, icon: string, label: string, color: string, fade: number?)
	local candy = candyNamed(color)
	setTileIcon(tile, icon)
	local body = tile:FindFirstChild("Body")
	local picture = body and body:FindFirstChild("Icon")
	if picture then
		for _, image in picture:GetDescendants() do
			if image:IsA("ImageLabel") then
				image.ImageTransparency = fade or 0
			end
		end
	end
	local shadow = body and body:FindFirstChild("IconShadow")
	if shadow and shadow:IsA("GuiObject") and (fade or 0) > 0 then
		shadow.Visible = false -- no shadow under a faded picture (setTileIcon puts it back for a full one)
	end
	local face = body and body:FindFirstChild("Face")
	local fill = face and face:FindFirstChild("Fill")
	if fill and fill:IsA("UIGradient") then
		fill.Color = gradientOf(candy, 0)
	end
	local words = body and body:FindFirstChild("Label")
	if words and words:IsA("TextLabel") then
		words.Text = label
		local edge = words:FindFirstChildOfClass("UIStroke")
		if edge then
			edge.Color = candy.deep
		end
	end
	local glow = tile:FindFirstChild("Glow")
	if glow and glow:IsA("ImageLabel") then
		glow.ImageColor3 = candy.bottom
	end
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
	Hud.refreshTiles() -- a phone's bottom row hides under the open Phone
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
		-- one thing at a time: the windows open now close (a window stayed open behind the Phone and its pages until
		-- 2026-11-19); only UIKit.panel windows (they carry a Theme), never the fight bar or the register's screens
		for _, frame in UIKit.openPanelList() do
			if frame:GetAttribute("Theme") ~= nil then
				frame.Visible = false
			end
		end
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

-- A red count on a tile's corner, hidden at 0
local function makeBadge(button: GuiObject): TextLabel
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
	return badge
end

-- A tile's or app's own count (Hud.setBadge), hidden at 0; one set before it was made shows at once
local function attachBadge(id: string, button: GuiObject)
	local badge = makeBadge(button)
	badges[id] = badge
	local waiting = badgeCounts[id]
	if waiting and waiting > 0 then
		badge.Visible = true
		badge.Text = PhoneNotice.text(waiting)
	end
end

local function ensureManageTile()
	if manageTile then
		return
	end
	local tile = makeTile(side, {
		id = "Manage", -- the Phone tile keeps the Manage id (the tutorial points at it by that name)
		icon = PHONE.icon,
		label = PHONE.label,
		group = "Side",
		order = 0,
		onClick = function()
			setFan(not fanOpen)
		end,
	}, HudLayout.CANDY.Manage)
	manageTile = tile
	-- everything waiting in its apps, added up (Hud.setBadge; owner 2026-11-21)
	local badge = makeBadge(tile)
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = badge
	phoneBadge = badge
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
		local parent = if spot == "phone" then apps elseif spot == "side" then side elseif spot == "bottom" then bottom else entry.home
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

-- How much bigger a growing piece draws on a desktop (Config/HudGrow: the party dock, the quest strip; owner
-- 2026-11-21: "small on the laptops"); 1 on a touch screen
function Hud.growFor(): number
	local height = if screen then screen.AbsoluteSize.Y else HudGrowConfig.REFERENCE
	return HudGrow.scale(height, UserInputService.TouchEnabled, HudGrowConfig)
end

-- Gives a HUD frame a UIScale that follows the screen's height (kept up to date when the screen resizes). `grow`: it
-- also grows on a desktop's bigger screens (Hud.growFor)
function Hud.scaleWith(frame: GuiObject, min: number?, grow: boolean?): UIScale
	local scale = Instance.new("UIScale")
	scale.Scale = Hud.scaleFor(min) * (if grow then Hud.growFor() else 1)
	scale.Parent = frame
	-- its scale at rest, for anything else that animates this UIScale (the quest strip's bump: Util/HudGrow.rest)
	frame:SetAttribute(HudGrowConfig.ATTRIBUTE, scale.Scale)
	table.insert(scaled, { scale = scale, min = min or HudLayout.SCALE.MIN, grow = grow == true })
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
	dogs.Size = UDim2.new(1, -60, 0, PHONE.pictureHeight.tall)
	dogs.ZIndex = 34
	dogs.Parent = homeScreen
	-- rows past the screen scroll, like a real phone's (owner 2026-11-27: "make sure no overlapping elements": a fourth
	-- row, the owner's Admin app, ran under the home bar)
	apps = Instance.new("ScrollingFrame")
	apps.Name = "Apps"
	apps.BackgroundTransparency = 1
	apps.BorderSizePixel = 0
	apps.ScrollingDirection = Enum.ScrollingDirection.Y
	apps.AutomaticCanvasSize = Enum.AutomaticSize.Y
	apps.CanvasSize = UDim2.new()
	apps.ScrollBarThickness = 4
	apps.ScrollBarImageColor3 = ink
	apps.ScrollBarImageTransparency = 0.5
	local appsTop = 50 + PHONE.pictureHeight.tall -- under the name and the dogs
	apps.Position = UDim2.fromOffset(10, appsTop)
	apps.Size = UDim2.new(1, -20, 1, -(appsTop + 30))
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

	-- Its form for this screen (Config/PhoneForm, CompactHud.phoneForm): standing up while its app tiles stay
	-- finger-sized, else lying on its side with the name and the dogs on the left and the apps beside them (they were
	-- 31 px on a Galaxy A06 standing up: pre-launch QA 2026-11-19)
	local function shapePhone()
		local wide, scale = CompactHud.phoneForm(screenGui.AbsoluteSize.Y, PhoneForm, HudLayout.TILE_SIZE.X)
		fit.Scale = scale
		if wide then
			local side = PhoneForm.wideSide
			phone.Size = UDim2.fromOffset(PhoneForm.wide.w, PhoneForm.wide.h)
			name.Position = UDim2.fromOffset(14, 14)
			name.Size = UDim2.fromOffset(side, 26)
			dogs.Position = UDim2.fromOffset(14 + side / 2, 52)
			dogs.Size = UDim2.fromOffset(side - 16, PHONE.pictureHeight.wide)
			apps.Position = UDim2.fromOffset(side + 24, 8)
			apps.Size = UDim2.new(1, -(side + 34), 1, -44)
			grid.FillDirectionMaxCells = PhoneForm.wideColumns
		else
			phone.Size = UDim2.fromOffset(PhoneForm.tall.w, PhoneForm.tall.h)
			name.Position = UDim2.fromOffset(12, 4)
			name.Size = UDim2.new(1, -24, 0, 26)
			dogs.Position = UDim2.new(0.5, 0, 0, 34)
			dogs.Size = UDim2.new(1, -60, 0, PHONE.pictureHeight.tall)
			apps.Position = UDim2.fromOffset(10, appsTop)
			apps.Size = UDim2.new(1, -20, 1, -(appsTop + 30))
			grid.FillDirectionMaxCells = PhoneForm.columns
		end
	end
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(shapePhone)
	shapePhone()

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
			entry.scale.Scale = Hud.scaleFor(entry.min) * (if entry.grow then Hud.growFor() else 1)
			local owner = entry.scale.Parent
			if owner then
				owner:SetAttribute(HudGrowConfig.ATTRIBUTE, entry.scale.Scale)
			end
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
		Hud.scaleWith(frame, nil, true) -- bigger on a desktop with the rest of the HUD (Config/HudGrow)
	end
	ensureManageTile() -- the Phone tile, shown once it holds an app (layout)
	layout()
end

-- The bottom row's place: centred (nil), or its left edge `left` px from the screen's left (a computer's bar, where it
-- follows your creatures and the weapon dial: UIController, Config/DesktopHud)
function Hud.placeBottom(left: number?)
	if not bottom then
		return
	end
	if left then
		bottom.AnchorPoint = Vector2.new(0, 1)
		bottom.Position = UDim2.new(0, left, 1, -HudLayout.BOTTOM_MARGIN)
	else
		bottom.AnchorPoint = Vector2.new(0.5, 1)
		bottom.Position = UDim2.new(0.5, 0, 1, -HudLayout.BOTTOM_MARGIN)
	end
end

-- The bottom row's top on the screen (AbsolutePosition's space), its tiles' icons included (they pop out over the
-- tiles); nil while it shows no tile, or on a phone's slim HUD (the row hides under any open window there). The order
-- computer's tablet sits above it (OrderController, OrderRules.fit).
function Hud.bottomTop(): number?
	if not bottom or compact or not bottom.Visible or bottom.AbsoluteSize.Y <= 0 then
		return nil
	end
	for _, child in bottom:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			return bottom.AbsolutePosition.Y - bottom.AbsoluteSize.Y * TILE.iconRise
		end
	end
	return nil
end

-- Lifts the side column (the Phone, Cards) `px` up from the screen's middle: the party dock under it on a short PC
-- window (UIController). On a phone it hangs from the top instead (HudLayout.SIDE_TOP), clear of the thumbstick's
-- resting spot low on the left (owner 2026-11-17: "make sure nothing is cutoff/overlapping on all devices")
-- `top` (a computer's layout, Config/DesktopHud SIDE): it hangs that many px under the top bar, below Roblox's buttons
function Hud.liftSide(px: number, top: number?)
	if not side then
		return
	end
	if compact then
		side.AnchorPoint = Vector2.new(0, 0)
		side.Position = UDim2.new(0, HudLayout.SIDE_X, 0, HudLayout.SIDE_TOP)
	elseif top then
		side.AnchorPoint = Vector2.new(0, 0)
		side.Position = UDim2.new(0, HudLayout.SIDE_X, 0, top)
	else
		side.AnchorPoint = Vector2.new(0, 0.5)
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
	-- its own red count too, at the bottom or as a Phone app (the Bosses tile's loot come back, owner 2026-11-27)
	attachBadge(spec.id, tile)
	if spec.phoneApp then
		ensureManageTile()
	end
	table.insert(entries, {
		button = tile,
		rule = { phone = spec.phoneApp ~= nil, side = spec.phoneSide ~= nil, always = spec.phoneAlways, bottom = spec.phoneBottom },
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
	attachBadge(spec.id, button) -- a red count on its corner (Hud.setBadge), hidden at 0
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
	Hud.liftSide(0)
	layout()
	Hud.refreshTiles()
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
		-- a wide tap area over the header's left side: the phone draws at under half size on a short phone, where a
		-- 48 px button came out 20 px (owner 2026-11-17: "make sure ... on all devices"); the arrow stays put
		back.Size = UDim2.fromOffset(110, 56)
		back.TextXAlignment = Enum.TextXAlignment.Left
		local arrowPad = Instance.new("UIPadding")
		arrowPad.PaddingLeft = UDim.new(0, 16)
		arrowPad.PaddingBottom = UDim.new(0, 8)
		arrowPad.Parent = back
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
		-- centred and never wider than PhoneForm.pageMax: the pages were made for the standing phone, and stay a
		-- readable column when it lies on its side
		content.AnchorPoint = Vector2.new(0.5, 0)
		content.Position = UDim2.new(0.5, 0, 0, 50)
		content.Size = UDim2.new(1, -20, 1, -70)
		content.ZIndex = 34
		content.Parent = made
		local widest = Instance.new("UISizeConstraint")
		widest.MaxSize = Vector2.new(PhoneForm.pageMax, math.huge)
		widest.Parent = content
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

-- The red count on an app's icon (0 hides it), and on the Phone's own tile the sum of every app's (owner 2026-11-21:
-- "a noticeable notification on the phone everytime there's some changes to ... anything that is inside the phone")
function Hud.setBadge(id: string, count: number)
	badgeCounts[id] = math.max(0, count)
	local badge = badges[id]
	if badge then
		badge.Visible = count > 0
		badge.Text = PhoneNotice.text(count)
	end
	local total = PhoneNotice.total(badgeCounts)
	local whole = phoneBadge
	if whole then
		whole.Visible = total > 0
		whole.Text = PhoneNotice.text(total)
	end
end

-- The Phone's tile tells you something inside it changed (Util/PhoneNotice.kind): "ping" (more waits than before: two
-- rings, its icon rocks, its count pops) or "nudge" (progress only: one small ring). A computer only (nothing pulses
-- on a phone's HUD), and not while the Phone is open or its tile is hidden
function Hud.notice(kind: string?)
	local tile = manageTile
	local look = if kind then (PHONE.notice :: any)[kind] else nil
	if not tile or not look or compact or fanOpen or not tile.Visible or not side.Visible then
		return
	end
	local corner = HudLayout.TILE_SIZE.X * TILE.corner
	for ring = 1, look.rings do
		task.delay((ring - 1) * look.gap, function()
			if not tile.Parent then
				return
			end
			local frame = Instance.new("Frame")
			frame.Name = "Notice"
			frame.BackgroundTransparency = 1
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Position = UDim2.fromScale(0.5, 0.5)
			frame.Size = UDim2.fromScale(1, 1)
			frame.ZIndex = 1
			frame.Parent = tile
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0, corner)
			round.Parent = frame
			local stroke = Instance.new("UIStroke")
			stroke.Color = rgbOf(PHONE.badge)
			stroke.Thickness = PHONE.notice.thickness
			stroke.Parent = frame
			local out = TweenInfo.new(look.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(frame, out, { Size = UDim2.new(1, look.grow * 2, 1, look.grow * 2) }):Play()
			TweenService:Create(round, out, { CornerRadius = UDim.new(0, corner + look.grow) }):Play()
			TweenService:Create(stroke, out, { Transparency = 1 }):Play()
			task.delay(look.seconds + 0.1, function()
				frame:Destroy()
			end)
		end)
	end
	-- its icon rocks side to side and comes to rest upright
	local icon = tile:FindFirstChild("Icon", true)
	if icon and icon:IsA("GuiObject") then
		task.spawn(function()
			local step = TweenInfo.new(0.07, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			for _ = 1, look.rocks do
				for _, angle in { look.wiggle, -look.wiggle } do
					local rock = TweenService:Create(icon, step, { Rotation = angle })
					rock:Play()
					rock.Completed:Wait()
				end
			end
			TweenService:Create(icon, step, { Rotation = 0 }):Play()
		end)
	end
	-- its count pops
	local badge = phoneBadge
	local pop = if badge then badge:FindFirstChild("Pop") else nil
	if pop and pop:IsA("UIScale") then
		pop.Scale = look.pop
		TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
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

-- Everything but these named pieces hidden (manning the register keeps the party dock and the cash: Hud.keepOnly)
local keepOnlyBy: { [string]: { [string]: boolean } } = {}
-- Names a keepOnly can keep beyond the calm pieces (the status corner "cash"), apart from them so the guides' calm HUD
-- never hides what it didn't before
local keepNames: { [GuiObject]: string } = {}

local function keptOnly(name: string?): boolean
	if next(keepOnlyBy) == nil then
		return true
	end
	for _, kept in keepOnlyBy do
		if not name or not kept[name] then
			return false
		end
	end
	return true
end

-- A window is open (UIKit.onPanelsChanged) or the Phone is: on a phone the bottom-centre row (the Gift tile, Drop / Rip
-- / To Bag) hides under it; a short screen's window or Phone reached down over it (owner 2026-11-17: "make sure nothing
-- is cutoff/overlapping")
local panelOpen = false
-- The bottom-centre row alone hidden, by reason (the Edit bar takes its place: EditBarController)
local bottomHiddenBy: { [string]: boolean } = {}

local function apply(show: boolean)
	local showTiles = show and next(keepOnlyBy) == nil
	side.Visible = showTiles
	bottom.Visible = showTiles and not (compact and (panelOpen or fanOpen)) and next(bottomHiddenBy) == nil
	for _, object in hideWithHud do
		object.Visible = show and not hides(calmPieces[object]) and keptOnly(keepNames[object] or calmPieces[object])
	end
	for object, name in calmPieces do
		if not table.find(hideWithHud, object) then
			object.Visible = not hides(name) and keptOnly(name)
		end
	end
end

-- `source` hides every HUD piece but the named ones in `keep` (the tiles, the side column and the status corner too);
-- nil lets go
function Hud.keepOnly(source: string, keep: { string }?)
	if keep then
		local kept = {}
		for _, name in keep do
			kept[name] = true
		end
		keepOnlyBy[source] = kept
	else
		keepOnlyBy[source] = nil
	end
	if fanOpen and keep then
		setFan(false)
	end
	apply(next(hiddenBy) == nil)
	for _, callback in calmListeners do
		callback()
	end
end

-- A name Hud.keepOnly can keep a hideWith piece by (the status corner: "cash"), not a calm piece
function Hud.keepName(object: GuiObject, name: string)
	keepNames[object] = name
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

-- The tile rows' visibility again (a window opened or closed, the layout changed)
function Hud.refreshTiles()
	if side and bottom then
		apply(next(hiddenBy) == nil)
	end
end

-- `reason` hides the bottom-centre row (Cards, Bag, the carry tiles) while something takes its place; false lets go
function Hud.setBottomHidden(reason: string, hidden: boolean)
	bottomHiddenBy[reason] = if hidden then true else nil
	Hud.refreshTiles()
end

UIKit.onPanelsChanged(function(open: boolean)
	panelOpen = open
	Hud.refreshTiles()
end)

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
