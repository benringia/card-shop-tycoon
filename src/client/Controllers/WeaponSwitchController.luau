--!strict
-- The quick weapon switch (spec 2026-11-07-weapons-round2-design 6; the owner's pick A, 2026-11-07): a round chip on the
-- right edge with your weapon's picture in its rarity's ring, < and > either side (or swipe the chip, or Q / Z). It
-- steps through every weapon you own (Util/WeaponSwitch) and asks the server to equip it (EquipWeapon; in a fight a
-- switch costs Weapons.SWAP_SECONDS with no cut or skill). Shown with two weapons or more, never over a window.
-- A carousel (owner 2026-11-12: "make the buttons more smaller and add a carousel effect which I can see whats next or
-- previous weapon but smaller. also add tooltips when hovering on the active weapon"): the weapons before and after
-- smaller and faded beside it (tap one to step to it), the strip sliding a step on a switch, small arrows with a
-- finger-sized tap area, the weapon's name, Power, element, perk, grade and level in a tip under a mouse.
-- Phones (owner 2026-11-13, pick A: "the UI on phone is really crowded"; UIController.OnCompact): only the weapon in
-- hand, a bigger chip (tap it for the next weapon, swipe it back), "1/6" on its corner (CompactHud.weaponCount; dots
-- before, owner 2026-11-13 declutter pick A), its name beside it; out of
-- a fight it sits at the end of your row in the party dock (PartyBarController.GetWeaponSpot, owner 2026-11-13).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Weapons = require(Config:WaitForChild("Weapons"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local Swords = require(Config:WaitForChild("Swords"))
local HudLayout = require(Config:WaitForChild("HudLayout"))
local Combat = require(Config:WaitForChild("Combat"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local WeaponSwitch = require(Shared:WaitForChild("Util"):WaitForChild("WeaponSwitch"))
local WeaponText = require(Shared:WaitForChild("Util"):WaitForChild("WeaponText"))
local UiLayout = require(Shared:WaitForChild("Util"):WaitForChild("UiLayout"))
local CompactHud = require(Shared:WaitForChild("Util"):WaitForChild("CompactHud"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIController = require(Controllers:WaitForChild("UIController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))
local RegisterController = require(Controllers:WaitForChild("RegisterController"))
local PartyBarController = require(Controllers:WaitForChild("PartyBarController"))

local WeaponSwitchController = {}

local player = Players.LocalPlayer
local LOOK = HudLayout.WEAPON_SWITCH

local owned: { [string]: any } = {}
local equipped: string? = nil
local locked: { [string]: boolean } = {} -- weapons in the Forge: out of the switch till they're back
local list: { string } = {}
local holder: Frame
local holderScale: UIScale
local track: Frame -- the three weapons, slid a step on a switch
local portrait: ImageLabel
local ring: UIStroke
local sides: { [string]: { button: ImageButton, picture: ImageLabel, ring: UIStroke } } = {}
local nameLabel: TextLabel
local nameUntil = 0
local tip: Frame
local compact = false -- the phone's single chip (UIController.OnCompact)
local chipButton: ImageButton
local arrows: { GuiObject } = {}
local countLabel: TextLabel -- the phone's "1/6" on the chip's corner

local function unlocked(): boolean
	local level = player:GetAttribute("Level")
	return typeof(level) == "number" and level >= Swords.UNLOCK_SHOP_LEVEL
end

-- A weapon's picture and its rarity's colour
local function looksOf(id: string?): (string, Color3)
	local weapon = if id then Weapons.ById[id] else nil
	local look = if id then WeaponLooks.WEAPONS[id] else nil
	return if look then look.portrait else "", if weapon then CardFace.getRarityColor(weapon.rarity) else UIKit.Colors.Outline
end

-- The weapon in hand (the first in the list if the server hasn't said yet)
local function current(): string?
	return if equipped and table.find(list, equipped) then equipped else list[1]
end

-- The chip shows your equipped weapon, the small ones beside it the weapons before and after
local function render()
	list = WeaponSwitch.list(Weapons, owned, unlocked(), locked)
	local id = current()
	local weapon = if id then Weapons.ById[id] else nil
	portrait.Image, ring.Color = looksOf(id)
	nameLabel.Text = if weapon then string.upper(weapon.name) else ""
	local before, after = WeaponSwitch.neighbours(list, id)
	for name, side in sides do
		local sideId = if name == "Before" then before else after
		side.button.Visible = sideId ~= nil and not compact
		side.picture.Image, side.ring.Color = looksOf(sideId)
	end
	-- the phone's count on the chip's corner, edged in the weapon's rarity colour
	if countLabel then
		local count = CompactHud.weaponCount(list, id)
		countLabel.Text = count
		countLabel.Visible = compact and count ~= ""
		local edge = countLabel:FindFirstChildOfClass("UIStroke")
		if edge then
			edge.Color = ring.Color
		end
	end
end

-- The tip under a mouse on the weapon in hand: its name in its rarity's colour, then Power, element, perk, grade, level
local function showTip()
	local id = current()
	local weapon = if id then Weapons.ById[id] else nil
	if not id or not weapon or not UserInputService.MouseEnabled then
		return
	end
	for _, child in tip:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local title = UIKit.label(tip, weapon.name, Enum.Font.FredokaOne, 16, CardFace.getRarityColor(weapon.rarity))
	title.Size = UDim2.new(1, 0, 0, 20)
	title.LayoutOrder = 0
	UIKit.outlined(title)
	for index, row in WeaponText.stats(Weapons, id, owned[id], Combat) do
		local line = UIKit.label(tip, `{row.label}: {row.value}`, Enum.Font.GothamBold, 12, Color3.new(1, 1, 1))
		line.LayoutOrder = index
		line.Size = UDim2.new(1, 0, 0, 0)
		line.AutomaticSize = Enum.AutomaticSize.Y
		line.TextWrapped = true
	end
	-- left of the switch, its middle level with the chip
	local at = holder.AbsolutePosition
	tip.Position = UDim2.fromOffset(at.X - LOOK.gap, at.Y + LOOK.chip * holderScale.Scale / 2)
	tip.Visible = true
end

-- The server drops equips inside its cooldown, so the latest pick goes at once or when the cooldown has passed:
-- quick steps send only the weapon they land on, and the server's replies don't move the chip while one waits
local SEND_GAP = Weapons.EQUIP_COOLDOWN + Weapons.EQUIP_SEND_SLACK
local pendingId: string? = nil
local lastSentAt: number? = nil
local function send(weaponId: string)
	local waiting = pendingId ~= nil
	pendingId = weaponId
	if waiting then
		return
	end
	local now = os.clock()
	task.delay(WeaponSwitch.sendAt(now, lastSentAt, SEND_GAP) - now, function()
		local id = pendingId
		pendingId = nil
		if id then
			lastSentAt = os.clock()
			Remotes.EquipWeapon:FireServer(id)
		end
	end)
end

-- One step through your weapons: the server equips it (and redraws your character); the name shows for a moment
local function step(delta: number)
	if not WeaponSwitch.visible(list) then
		return
	end
	local nextId = WeaponSwitch.step(list, equipped, delta)
	if not nextId or nextId == equipped then
		return
	end
	equipped = nextId -- shown at once; the server's WeaponsChanged confirms or puts it back
	nameUntil = os.clock() + LOOK.nameSeconds
	render()
	-- the carousel slides a step: the new weapon comes in from the side it was on
	local shift = (LOOK.side + LOOK.chip) / 2 + LOOK.gap
	track.Position = UDim2.fromOffset(if delta > 0 then shift else -shift, 0)
	TweenService:Create(track, TweenInfo.new(LOOK.slide, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new() }):Play()
	if tip.Visible then
		showTip()
	end
	send(nextId)
end

-- On the right edge, and in a fight above the fight buttons (UiLayout.weaponSwitch); redone when the screen's size
-- changes or a fight's controls come or go
local laidOutSize = Vector2.zero
local laidOutFight = false
local laidOutClear = ""
-- On touch screens the status column (cash, rating, XP, the party bar under it) hangs from the top right: the switch
-- keeps clear of it (owner 2026-11-13: it sat on the party bar on a short phone)
-- The corner's column (cash, rating, buffs; on a phone your row and the party dock too): what's drawn in it
local function columnBox(): UiLayout.Rect?
	local main = holder.Parent and holder:FindFirstAncestorOfClass("ScreenGui")
	local column = if main then main:FindFirstChild("StatusRow") else nil
	if not column or not column:IsA("GuiObject") or not column.Visible then
		return nil
	end
	-- what's drawn in it (the pills and the party bar), not its whole box, which has room to spare under them
	local origin = (holder.Parent :: GuiObject).AbsolutePosition
	local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
	-- the cash column's own frame (Status) is taller than what it holds on a computer: its pills count, not it
	local pieces: { Instance } = {}
	for _, child in column:GetChildren() do
		if child.Name == "Status" and child:IsA("GuiObject") and child.Visible then
			for _, item in child:GetChildren() do
				table.insert(pieces, item)
			end
		else
			table.insert(pieces, child)
		end
	end
	for _, child in pieces do
		if child:IsA("GuiObject") and child.Visible and child.AbsoluteSize.Y > 0 then
			local at, size = child.AbsolutePosition - origin, child.AbsoluteSize
			left, top = math.min(left, at.X), math.min(top, at.Y)
			right, bottom = math.max(right, at.X + size.X), math.max(bottom, at.Y + size.Y)
		end
	end
	if left == math.huge then
		return nil
	end
	return { x = left, y = top, w = right - left, h = bottom - top }
end
local function clearOf(): { UiLayout.Rect }
	local box = if UserInputService.TouchEnabled then columnBox() else nil
	return if box then { box } else {}
end
-- A computer: the cash column it sits just above (owner 2026-11-13: "move weapon lower to close the gap")
local function aboveOf(): UiLayout.Rect?
	return if UserInputService.TouchEnabled then nil else columnBox()
end
local function clearKey(): string
	local b = columnBox()
	return if b then `{math.floor(b.x)},{math.floor(b.y)},{math.floor(b.w)},{math.floor(b.h)}` else ""
end
local laidOutSpot = Vector2.zero
local function relayout(view: Vector2, fight: boolean)
	laidOutSize, laidOutFight, laidOutClear = view, fight, clearKey()
	local spot = PartyBarController.GetWeaponSpot()
	if compact and not fight and spot and spot.Visible and spot.AbsoluteSize.X > 0 then
		-- the phone's chip on its spot at the end of your row in the party dock
		local origin = (holder.Parent :: GuiObject).AbsolutePosition
		laidOutSpot = spot.AbsolutePosition
		holder.Position = UDim2.fromOffset(spot.AbsolutePosition.X - origin.X, spot.AbsolutePosition.Y - origin.Y)
		holderScale.Scale = spot.AbsoluteSize.X / LOOK.compactChip
		return
	end
	laidOutSpot = Vector2.zero
	local rect = UiLayout.weaponSwitch({ w = view.X, h = view.Y }, LOOK, Hud.scaleFor(), fight, clearOf(), compact, aboveOf())
	holder.Position = UDim2.fromOffset(rect.x, rect.y)
	holderScale.Scale = rect.scale
end

local function build()
	-- A full-screen layer the HUD hides with its tiles (the binder, the stages); the chip shows or hides inside it
	local layer = Instance.new("Frame")
	layer.Name = "WeaponSwitch"
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.Parent = UIController.GetScreenGui()
	Hud.hideWith(layer)
	Hud.calmPiece(layer, "weapons") -- hidden through Pish's first visit (a calm HUD) and Chikin's but his sword step
	holder = Instance.new("Frame")
	holder.Name = "Switch"
	holder.Size = UDim2.fromOffset(LOOK.chip + 2 * (LOOK.side + LOOK.gap) + 2 * (LOOK.arrow + LOOK.gap), LOOK.chip + LOOK.name)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = layer
	holderScale = Instance.new("UIScale") -- set by relayout (UiLayout.weaponSwitch)
	holderScale.Parent = holder

	-- < and >: drawn small, each with a finger-sized tap area round it (UiLayout.weaponSwitch)
	local function arrow(name: string, text: string, x: number, delta: number): TextButton
		local button = UIKit.button(holder, text, UIKit.Colors.Secondary)
		button.Name = name
		button.TextSize = 16
		button.Size = UDim2.fromOffset(LOOK.arrow, LOOK.arrow)
		button.Position = UDim2.fromOffset(x, (LOOK.chip - LOOK.arrow) / 2)
		button.Activated:Connect(function()
			step(delta)
		end)
		local hit = Instance.new("TextButton")
		hit.Name = "Hit"
		hit.Text = ""
		hit.BackgroundTransparency = 1
		hit.AnchorPoint = Vector2.new(0.5, 0.5)
		hit.Position = UDim2.fromScale(0.5, 0.5)
		hit.Size = UDim2.fromOffset(LOOK.hit, LOOK.hit)
		hit.ZIndex = button.ZIndex + 3
		hit.Parent = button
		hit.Activated:Connect(function()
			step(delta)
		end)
		return button
	end
	local previous = arrow("Previous", "<", 0, -1)
	local nextArrow = arrow("Next", ">", LOOK.chip + 2 * (LOOK.side + LOOK.gap) + LOOK.arrow + 2 * LOOK.gap, 1)
	arrows = { previous, nextArrow }

	-- the three weapons on one strip
	track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundTransparency = 1
	track.Size = UDim2.fromScale(1, 1)
	track.Parent = holder
	local function round(name: string, size: number, x: number, edge: number): (ImageButton, ImageLabel, UIStroke)
		local button = Instance.new("ImageButton")
		button.Name = name
		button.AutoButtonColor = false
		button.BackgroundColor3 = UIKit.Colors.Panel
		button.AnchorPoint = Vector2.new(0, 0.5)
		button.Size = UDim2.fromOffset(size, size)
		button.Position = UDim2.fromOffset(x, LOOK.chip / 2)
		button.Parent = track
		UIKit.corner(button, size // 2)
		local stroke = UIKit.outline(button, UIKit.Colors.Outline, edge)
		local picture = Instance.new("ImageLabel")
		picture.Name = "Portrait"
		picture.BackgroundTransparency = 1
		picture.ScaleType = Enum.ScaleType.Fit
		picture.AnchorPoint = Vector2.new(0.5, 0.5)
		picture.Position = UDim2.fromScale(0.5, 0.5)
		picture.Size = UDim2.fromScale(0.86, 0.86)
		picture.Parent = button
		return button, picture, stroke
	end
	local firstSide = LOOK.arrow + LOOK.gap
	local chipX = firstSide + LOOK.side + LOOK.gap
	for _, entry in { { "Before", firstSide, -1 }, { "After", chipX + LOOK.chip + LOOK.gap, 1 } } do
		local name, x, delta = entry[1] :: string, entry[2] :: number, entry[3] :: number
		local button, picture, stroke = round(name, LOOK.side, x, 2)
		button.BackgroundTransparency = LOOK.sideFade
		picture.ImageTransparency = LOOK.sideFade
		stroke.Transparency = LOOK.sideFade
		button.Activated:Connect(function()
			step(delta)
		end)
		sides[name] = { button = button, picture = picture, ring = stroke }
	end
	local chip
	chip, portrait, ring = round("Chip", LOOK.chip, chipX, LOOK.ring)
	chipButton = chip
	countLabel = UIKit.label(chip, "", Enum.Font.FredokaOne, LOOK.countText, Color3.fromRGB(20, 28, 60))
	countLabel.Name = "Count"
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.Position = UDim2.new(1, 4, 1, 2)
	countLabel.Size = UDim2.fromOffset(0, LOOK.countText + 4)
	countLabel.AutomaticSize = Enum.AutomaticSize.X
	countLabel.TextWrapped = false
	countLabel.TextXAlignment = Enum.TextXAlignment.Center
	countLabel.BackgroundColor3 = Color3.new(1, 1, 1)
	countLabel.BackgroundTransparency = 0
	countLabel.ZIndex = 10
	countLabel.Visible = false
	UIKit.corner(countLabel, (LOOK.countText + 4) / 2)
	UIKit.outline(countLabel, Color3.new(1, 1, 1), 1.5)
	local countPad = Instance.new("UIPadding")
	countPad.PaddingLeft = UDim.new(0, 4)
	countPad.PaddingRight = UDim.new(0, 4)
	countPad.Parent = countLabel

	-- the tip: a small panel left of the switch while a mouse is on the weapon in hand
	tip = Instance.new("Frame")
	tip.Name = "WeaponTip"
	tip.AnchorPoint = Vector2.new(1, 0.5)
	tip.Size = UDim2.fromOffset(220, 0)
	tip.AutomaticSize = Enum.AutomaticSize.Y
	tip.BackgroundColor3 = UIStyle.PANEL
	tip.Visible = false
	tip.ZIndex = 20
	tip.Parent = layer
	UIKit.corner(tip, 12)
	UIKit.outline(tip, UIStyle.EDGE, UIStyle.EDGE_THICKNESS)
	local tipPad = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(tipPad :: any)[side] = UDim.new(0, 10)
	end
	tipPad.Parent = tip
	local tipList = Instance.new("UIListLayout")
	tipList.SortOrder = Enum.SortOrder.LayoutOrder
	tipList.Padding = UDim.new(0, 3)
	tipList.Parent = tip
	chip.MouseEnter:Connect(showTip)
	chip.MouseLeave:Connect(function()
		tip.Visible = false
	end)

	-- Q (the next weapon) on the > button (owner 2026-11-13: "put "Q" to the other arrow not on the weapon") and Z (the
	-- one before, owner 2026-11-09) on the < button, on keyboards, each in its white circle like the HUD tiles' keys
	local function badge(parent: GuiObject, text: string, anchor: Vector2, position: UDim2): Frame
		local frame = Instance.new("Frame")
		frame.Name = "Key"
		frame.AnchorPoint = anchor
		frame.Position = position
		frame.Size = UDim2.fromOffset(HudLayout.KEY_SIZE, HudLayout.KEY_SIZE)
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.Visible = UserInputService.KeyboardEnabled
		frame.ZIndex = parent.ZIndex + 2
		frame.Parent = parent
		UIKit.corner(frame, HudLayout.KEY_SIZE // 2)
		local key = UIKit.label(frame, text, Enum.Font.GothamBold, 13, HudLayout.KEY_CHIP)
		key.Size = UDim2.fromScale(1, 1)
		key.TextXAlignment = Enum.TextXAlignment.Center
		key.ZIndex = frame.ZIndex + 1
		return frame
	end
	badge(nextArrow, "Q", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 1, 2))
	badge(previous, Weapons.PREVIOUS_KEY, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 1, 2))

	nameLabel = UIKit.label(holder, "", Enum.Font.FredokaOne, 14, UIKit.Colors.Text)
	nameLabel.Name = "WeaponName"
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.new(0.5, 0, 0, LOOK.chip + 4)
	nameLabel.Size = UDim2.new(1, 40, 0, 18)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.Visible = false
	UIKit.outlined(nameLabel)

	-- A horizontal swipe on the chip steps too: left for the next weapon, right for the one before
	local pressedAt: Vector3? = nil
	local swipedAt = 0
	chip.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressedAt = input.Position
		end
	end)
	chip.InputEnded:Connect(function(input)
		local from = pressedAt
		pressedAt = nil
		if from and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
			local dx = input.Position.X - from.X
			if math.abs(dx) >= LOOK.swipe then
				swipedAt = os.clock()
				step(if dx < 0 then 1 else -1)
			end
		end
	end)
	-- the phone's chip: a tap (not a swipe) is the next weapon; deferred so a swipe's InputEnded is seen first
	chip.Activated:Connect(function()
		task.defer(function()
			if compact and os.clock() - swipedAt > 0.25 then
				step(1)
			end
		end)
	end)
end

-- The weapons now (the character window): owned ones' grade and level, and the one in hand
function WeaponSwitchController.GetState(): { owned: { [string]: any }, equipped: string? }
	return { owned = owned, equipped = equipped }
end

-- The phone's single chip, or the carousel: arrows and the side weapons hide, the chip grows and sits alone, the name
-- goes beside it (left), the dots under it
local function setCompact(on: boolean)
	compact = on
	for _, button in arrows do
		button.Visible = not on
	end
	local size = if on then LOOK.compactChip else LOOK.chip
	chipButton.Size = UDim2.fromOffset(size, size)
	local corner = chipButton:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, size // 2)
	end
	chipButton.Position = UDim2.fromOffset(if on then 0 else LOOK.arrow + LOOK.gap + LOOK.side + LOOK.gap, size / 2)
	holder.Size = if on
		then UDim2.fromOffset(LOOK.compactChip, LOOK.compactChip)
		else UDim2.fromOffset(LOOK.chip + 2 * (LOOK.side + LOOK.gap) + 2 * (LOOK.arrow + LOOK.gap), LOOK.chip + LOOK.name)
	nameLabel.AnchorPoint = if on then Vector2.new(1, 0.5) else Vector2.new(0.5, 0)
	nameLabel.Position = if on then UDim2.new(0, -8, 0, size / 2) else UDim2.new(0.5, 0, 0, LOOK.chip + 4)
	nameLabel.Size = if on then UDim2.fromOffset(200, 18) else UDim2.new(1, 40, 0, 18)
	nameLabel.TextXAlignment = if on then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center
	laidOutSize = Vector2.zero -- lay it out again
	render()
end

function WeaponSwitchController.Start()
	build()
	render()
	UIController.OnCompact(setCompact)
	Remotes.WeaponsChanged.OnClientEvent:Connect(function(state: unknown)
		if typeof(state) ~= "table" then
			return
		end
		local data = state :: any
		if typeof(data.owned) == "table" then
			owned = data.owned
		end
		locked = if typeof(data.locked) == "table" then data.locked else {}
		if typeof(data.equipped) == "string" and not pendingId then -- a waiting send is newer than this reply
			equipped = data.equipped
		end
		render()
	end)
	player:GetAttributeChangedSignal("Level"):Connect(render)
	Remotes.WeaponsChanged:FireServer() -- the weapons now, if their first send came before this listened

	-- Q: the next weapon; Z (owner 2026-11-09: "add a previous button") or Shift+Q: the one before (not while typing,
	-- placing something or with a window open; in a fight Shift is the dodge, so Z is the one to use there)
	local previousKey = (Enum.KeyCode :: any)[Weapons.PREVIOUS_KEY] :: Enum.KeyCode
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		local layer = holder.Parent :: GuiObject
		local key = input.KeyCode
		if gameProcessed or (key ~= Enum.KeyCode.Q and key ~= previousKey) or not holder.Visible or not layer.Visible then
			return
		end
		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		step(if key == previousKey or shift then -1 else 1)
	end)

	local screenGui = UIController.GetScreenGui()
	RunService.Heartbeat:Connect(function()
		local view = (holder.Parent :: GuiObject).AbsoluteSize
		local fight = screenGui:FindFirstChild("CombatHud") ~= nil
		-- the phone's spot in the party dock: kept while there's a weapon to switch to
		local spot = PartyBarController.GetWeaponSpot()
		local wantSpot = compact and WeaponSwitch.visible(list)
		if spot and spot.Visible ~= wantSpot then
			spot.Visible = wantSpot
		end
		local spotAt = if spot and spot.Visible and not fight then spot.AbsolutePosition else Vector2.zero
		if view ~= laidOutSize or fight ~= laidOutFight or clearKey() ~= laidOutClear or spotAt ~= laidOutSpot then
			relayout(view, fight)
		end
		holder.Visible = WeaponSwitch.visible(list)
			and not UIKit.anyPanelOpen()
			and not PlacementController.IsActive()
			and not RegisterController.IsShowing() -- the checkout sits in the same spot (owner 2026-11-10)
		nameLabel.Visible = os.clock() < nameUntil
		if tip.Visible and not holder.Visible then
			tip.Visible = false
		end
	end)
end

return WeaponSwitchController
