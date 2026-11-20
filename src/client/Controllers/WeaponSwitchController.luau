--!strict
-- The quick weapon switch (spec 2026-11-07-weapons-round2-design 6), the medallion dial (owner 2026-11-14 pick C; the
-- carousel before it, owner 2026-11-12): the weapon in hand in a medallion on the right edge, its rarity's ring with a
-- shine going round, its inside the element's colour, its grade on its corner; the one before on a curved track to its
-- left (Z), the next on top (Q) and the one after that between them, faded. Tap one on the track (or swipe the
-- medallion, or Q / Z) and the dial rolls a step. It steps through every weapon you own (Util/WeaponSwitch) and asks
-- the server to equip it (EquipWeapon; in a fight a switch costs Weapons.SWAP_SECONDS with no cut or skill). Shown with
-- two weapons or more, never over a window; the name and its line (WeaponText.switchLine) show for a moment after a
-- switch (owner: "only briefly"), the stats tip under a mouse on the medallion.
-- Phones (owner 2026-11-13, pick A: "the UI on phone is really crowded"; UIController.OnCompact): the medallion alone,
-- bigger (tap it for the next weapon, swipe it back), "1/6" on its corner (CompactHud.weaponCount), its name beside it;
-- out of a fight it sits at the end of your row in the party dock (PartyBarController.GetWeaponSpot, owner 2026-11-13).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Weapons = require(Config:WaitForChild("Weapons"))
local Cards = require(Config:WaitForChild("Cards"))
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
local PickWheel = require(ClientUtil:WaitForChild("PickWheel"))
local UIController = require(Controllers:WaitForChild("UIController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))
local RegisterController = require(Controllers:WaitForChild("RegisterController"))
local PartyBarController = require(Controllers:WaitForChild("PartyBarController"))

local WeaponSwitchController = {}

local player = Players.LocalPlayer
local LOOK = HudLayout.WEAPON_SWITCH
-- the dial's box: the medallion in its bottom-right corner, the track up and to the left of its middle
local DIAL = LOOK.arc + LOOK.hit / 2 + LOOK.chip / 2
local CENTER = Vector2.new(DIAL - LOOK.chip / 2, DIAL - LOOK.chip / 2)
local NO_ELEMENT = Color3.fromRGB(110, 120, 150)
local PRISM = Color3.fromRGB(200, 170, 255)

local owned: { [string]: any } = {}
local equipped: string? = nil
local locked: { [string]: boolean } = {} -- weapons in the Forge: out of the switch till they're back
local list: { string } = {}
local holder: Frame
local holderScale: UIScale
local chipButton: ImageButton -- the medallion
local portrait: ImageLabel
local shine: UIGradient -- the ring's colour, its bright spot going round
local inside: UIGradient -- the medallion's inside: the element's colour
local gradeBadge: Frame
local gradeLabel: TextLabel
type Orb = { button: ImageButton, picture: ImageLabel, ring: UIStroke, scale: UIScale, fade: number }
local orbs: { [string]: Orb } = {} -- before, after, later on the track
local SPOTS = { "before", "after", "later" }
local STEPS = { before = -1, after = 1, later = 2 }
local nameFrame: Frame
local nameLabel: TextLabel
local lineLabel: TextLabel
local nameUntil = 0
local tip: Frame
local compact = false -- the phone's medallion alone (UIController.OnCompact)
local countLabel: TextLabel -- the phone's "1/6" on the medallion's corner
local rollTween: Tween? = nil
-- A phone shows the weapon chip out of town only, where you fight (owner 2026-11-17, "go A"; CompactHud.phonePieces);
-- a fight anywhere still shows it
local weaponHere = true
local weaponHints: Frame? = nil -- a phone's chevrons over and under the medallion (it swipes up and down)

local function refreshHere()
	weaponHere = CompactHud.phonePieces(compact, Hud.inTown(), false, false).weaponChip
end

local function unlocked(): boolean
	local level = player:GetAttribute("Level")
	return (typeof(level) == "number" and level >= Swords.UNLOCK_SHOP_LEVEL) or player:GetAttribute("SwordGiven") == true
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

-- A spot on the track: its offset from the medallion's middle, rolled `t` of the way from where it was
local function spotOffset(spot: string, from: string?, t: number): Vector2
	local angle = LOOK.angles[spot]
	local fromAngle, fromRadius = angle, LOOK.arc
	if from == "center" then
		fromRadius = 0
	elseif from then
		fromAngle = LOOK.angles[from]
	end
	local x, y = WeaponSwitch.arcPoint(fromAngle + (angle - fromAngle) * t, fromRadius + (LOOK.arc - fromRadius) * t)
	return Vector2.new(x, y)
end

-- The track's weapons and the medallion's picture `t` of the way through a roll (1: at rest)
local function placeRoll(roll: any, t: number)
	for spot, orb in orbs do
		local from = if roll then (roll :: any)[spot] else spot
		local at = CENTER + spotOffset(spot, from, t)
		orb.button.Position = UDim2.fromOffset(at.X, at.Y)
		-- one that wasn't showing fades in where it lands
		local seen = if from == nil then t else 1
		local fade = 1 - (1 - orb.fade) * seen
		orb.button.BackgroundTransparency = fade
		orb.picture.ImageTransparency = fade
		orb.ring.Transparency = fade
	end
	-- the new weapon in hand slides into the medallion from where it was, growing
	local from = if roll then roll.current else "center"
	local start = if from and from ~= "center" then spotOffset(from, nil, 1) else Vector2.zero
	local offset = start * (1 - t)
	local size = 0.86 * (if from and from ~= "center" then LOOK.side / LOOK.chip + (1 - LOOK.side / LOOK.chip) * t else 1)
	portrait.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
	portrait.Size = UDim2.fromScale(size, size)
end

-- The medallion shows your equipped weapon, the track the ones before and after
local function render()
	list = WeaponSwitch.list(Weapons, owned, unlocked(), locked)
	local id = current()
	local weapon = if id then Weapons.ById[id] else nil
	local color
	portrait.Image, color = looksOf(id)
	shine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.4, color),
		ColorSequenceKeypoint.new(0.5, color:Lerp(Color3.new(1, 1, 1), 0.85)),
		ColorSequenceKeypoint.new(0.6, color),
		ColorSequenceKeypoint.new(1, color),
	})
	local element = if weapon and weapon.prism then PRISM elseif weapon and weapon.element then Cards.ELEMENTS[weapon.element] or NO_ELEMENT else NO_ELEMENT
	inside.Color = ColorSequence.new(element:Lerp(Color3.new(1, 1, 1), 0.45), element:Lerp(Color3.new(0, 0, 0), 0.35))
	local entry = if id then owned[id] else nil
	local grade = if typeof(entry) == "table" and typeof(entry.grade) == "string" then entry.grade else nil
	gradeLabel.Text = grade or ""
	gradeBadge.Visible = grade ~= nil
	nameLabel.Text = if weapon then weapon.name else ""
	nameLabel.TextColor3 = color
	lineLabel.Text = if id then WeaponText.switchLine(Weapons, id, if typeof(entry) == "table" then entry else nil) else ""
	lineLabel.Visible = lineLabel.Text ~= ""
	local track = WeaponSwitch.track(list, id)
	for spot, orb in orbs do
		local spotId = (track :: any)[spot]
		orb.button.Visible = spotId ~= nil and not compact
		orb.picture.Image, orb.ring.Color = looksOf(spotId)
	end
	-- the phone's count on the medallion's corner, edged in the weapon's rarity colour
	local count = CompactHud.weaponCount(list, id)
	countLabel.Text = count
	countLabel.Visible = compact and count ~= ""
	local edge = countLabel:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = color
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
	-- left of the dial, its middle level with the medallion
	local at = holder.AbsolutePosition
	local middle = if compact then LOOK.compactChip / 2 else CENTER.Y
	tip.Position = UDim2.fromOffset(at.X - LOOK.gap, at.Y + middle * holderScale.Scale)
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

-- One step through your weapons: the server equips it (and redraws your character); the dial rolls a step and the name
-- shows for a moment
local function step(delta: number)
	if not WeaponSwitch.visible(list) then
		return
	end
	local was = current()
	local nextId = WeaponSwitch.step(list, equipped, delta)
	if not nextId or nextId == equipped then
		return
	end
	local roll = WeaponSwitch.roll(list, was, nextId)
	equipped = nextId -- shown at once; the server's WeaponsChanged confirms or puts it back
	nameUntil = os.clock() + LOOK.nameSeconds
	render()
	if rollTween then
		rollTween:Cancel()
	end
	local progress = Instance.new("NumberValue")
	progress.Changed:Connect(function(t)
		placeRoll(roll, t)
	end)
	placeRoll(roll, 0)
	local tween = TweenService:Create(progress, TweenInfo.new(LOOK.roll, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 })
	rollTween = tween
	tween.Completed:Connect(function()
		progress:Destroy()
		if rollTween == tween then
			rollTween = nil
			placeRoll(nil, 1)
		end
	end)
	tween:Play()
	if tip.Visible then
		showTip()
	end
	send(nextId)
end

-- The column of your weapons on the medallion held (a phone's pair, owner 2026-11-17 placement 2; PickWheel): each
-- one's picture, name and line; one picked goes in hand
local function openWheel(held: InputObject?)
	if not WeaponSwitch.visible(list) then
		return
	end
	local items: { PickWheel.Item } = {}
	for _, id in list do
		local weapon = Weapons.ById[id]
		local entry = owned[id]
		table.insert(items, {
			image = (looksOf(id)),
			tint = Color3.fromRGB(232, 235, 244),
			fit = true,
			title = if weapon then weapon.name else id,
			line = WeaponText.switchLine(Weapons, id, if typeof(entry) == "table" then entry else nil),
		})
	end
	PickWheel.open({
		anchor = chipButton,
		items = items,
		current = table.find(list, current() or "") or 1,
		held = held,
		onPick = function(index: number)
			local from = table.find(list, equipped or "")
			if not from then
				equipped = list[1]
				from = 1
			end
			step(index - from)
		end,
	})
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
-- With the corner empty (the cash at the top, Pish on the quests: Config/DesktopHud) it sits in the corner itself
local function aboveOf(): UiLayout.Rect?
	if UserInputService.TouchEnabled then
		return nil
	end
	local box = columnBox()
	if box then
		return box
	end
	local view = (holder.Parent :: GuiObject).AbsoluteSize
	-- Pish in the corner (the quests are in the Phone): beside him, its foot on the screen's bottom margin
	local main = holder:FindFirstAncestorOfClass("ScreenGui")
	local perch = if main then main:FindFirstChild("PishPerch") else nil
	if perch and perch:IsA("GuiObject") and perch.Visible and perch.AbsoluteSize.X > 0 and perch.AbsolutePosition.Y > view.Y / 2 then
		local origin = (holder.Parent :: GuiObject).AbsolutePosition
		return { x = perch.AbsolutePosition.X - origin.X, y = view.Y - HudLayout.BOTTOM_MARGIN, w = perch.AbsoluteSize.X, h = 0 }
	end
	return { x = view.X - LOOK.right + LOOK.gap, y = view.Y - HudLayout.BOTTOM_MARGIN, w = 0, h = 0 }
end
local function clearKey(): string
	local b = aboveOf() or columnBox()
	return if b then `{math.floor(b.x)},{math.floor(b.y)},{math.floor(b.w)},{math.floor(b.h)}` else ""
end
local laidOutSpot = Vector2.zero
local laidOutBar = ""
local switchLayer: Frame? = nil -- the dial's layer: its Wanted attribute tells UIController the dial is in the bar
-- A computer's bottom bar (owner 2026-11-21, layout A; UIController.GetBarSpot): the dial between your creatures and
-- the tiles while no fight is on
local function barOf(fight: boolean): { x: number, bottom: number, scale: number }?
	return if fight or compact then nil else UIController.GetBarSpot()
end
local function barKey(fight: boolean): string
	local spot = barOf(fight)
	return if spot then `{math.floor(spot.x)},{math.floor(spot.bottom)},{spot.scale}` else ""
end
-- The name after a switch: left of the track; in the bar your creatures are there, so over the dial
local function placeName(inBar: boolean)
	if compact then
		return -- the phone's place (setCompact)
	end
	if inBar then
		nameFrame.AnchorPoint = Vector2.new(1, 1)
		nameFrame.Position = UDim2.fromOffset(DIAL, -6)
	else
		nameFrame.AnchorPoint = Vector2.new(1, 0.5)
		nameFrame.Position = UDim2.fromOffset(CENTER.X - LOOK.arc - LOOK.side / 2 - LOOK.gap, CENTER.Y)
	end
end
local function relayout(view: Vector2, fight: boolean)
	laidOutSize, laidOutFight, laidOutClear = view, fight, clearKey()
	laidOutBar = barKey(fight)
	local inBar = barOf(fight)
	placeName(inBar ~= nil)
	if inBar then
		laidOutSpot = Vector2.zero
		holder.Position = UDim2.fromOffset(inBar.x, view.Y - inBar.bottom - DIAL * inBar.scale)
		holderScale.Scale = inBar.scale
		return
	end
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
	-- in a fight: right over the fight buttons on screen (the combat HUD says which layout it drew)
	local hud = if fight then UIController.GetScreenGui():FindFirstChild("CombatHud") else nil
	local layout = if hud then hud:GetAttribute("Layout") else nil
	local rect = UiLayout.weaponSwitch({ w = view.X, h = view.Y }, LOOK, Hud.scaleFor(), fight, clearOf(), compact, aboveOf(), if typeof(layout) == "string" then layout else nil)
	holder.Position = UDim2.fromOffset(rect.x, rect.y)
	holderScale.Scale = rect.scale
end

local function build()
	-- A full-screen layer the HUD hides with its tiles (the binder, the stages); the dial shows or hides inside it
	local layer = Instance.new("Frame")
	layer.Name = "WeaponSwitch"
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.Parent = UIController.GetScreenGui()
	switchLayer = layer
	Hud.hideWith(layer)
	Hud.calmPiece(layer, "weapons") -- hidden through Pish's first visit (a calm HUD) and Chikin's but his sword step
	holder = Instance.new("Frame")
	holder.Name = "Switch"
	holder.Size = UDim2.fromOffset(DIAL, DIAL)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = layer
	holderScale = Instance.new("UIScale") -- set by relayout (UiLayout.weaponSwitch)
	holderScale.Parent = holder

	-- Q (the next weapon) and Z (the one before, owner 2026-11-09) beside their weapons on the track, on keyboards, each
	-- in its white circle like the HUD tiles' keys
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

	-- the track's weapons: small and round, each with a finger-sized tap area; a tap steps to it
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundTransparency = 1
	track.Size = UDim2.fromScale(1, 1)
	track.Parent = holder
	for _, spot in SPOTS do
		local button = Instance.new("ImageButton")
		button.Name = spot
		button.AutoButtonColor = false
		button.BackgroundColor3 = UIKit.Colors.Panel
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Size = UDim2.fromOffset(LOOK.side, LOOK.side)
		button.Visible = false
		button.Parent = track
		UIKit.corner(button, LOOK.side // 2)
		local ring = UIKit.outline(button, UIKit.Colors.Outline, 3)
		local scale = Instance.new("UIScale")
		scale.Scale = if spot == "later" then LOOK.laterScale else 1
		scale.Parent = button
		local picture = Instance.new("ImageLabel")
		picture.Name = "Portrait"
		picture.BackgroundTransparency = 1
		picture.ScaleType = Enum.ScaleType.Fit
		picture.AnchorPoint = Vector2.new(0.5, 0.5)
		picture.Position = UDim2.fromScale(0.5, 0.5)
		picture.Size = UDim2.fromScale(0.82, 0.82)
		picture.Parent = button
		local hit = Instance.new("TextButton")
		hit.Name = "Hit"
		hit.Text = ""
		hit.BackgroundTransparency = 1
		hit.AnchorPoint = Vector2.new(0.5, 0.5)
		hit.Position = UDim2.fromScale(0.5, 0.5)
		hit.Size = UDim2.fromOffset(LOOK.hit, LOOK.hit)
		hit.ZIndex = button.ZIndex + 3
		hit.Parent = button
		local delta = STEPS[spot]
		hit.Activated:Connect(function()
			step(delta)
		end)
		orbs[spot] = { button = button, picture = picture, ring = ring, scale = scale, fade = if spot == "later" then LOOK.laterFade else LOOK.sideFade }
	end
	badge(orbs.before.button, Weapons.PREVIOUS_KEY, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 1, 2))
	badge(orbs.after.button, "Q", Vector2.new(0, 0.5), UDim2.new(1, 3, 0.5, 0))

	-- the medallion: the element's colour inside, the rarity's ring with its shine
	local chip = Instance.new("ImageButton")
	chip.Name = "Chip"
	chip.AutoButtonColor = false
	chip.BackgroundColor3 = Color3.new(1, 1, 1)
	chip.AnchorPoint = Vector2.new(0.5, 0.5)
	chip.Size = UDim2.fromOffset(LOOK.chip, LOOK.chip)
	chip.Position = UDim2.fromOffset(CENTER.X, CENTER.Y)
	chip.ZIndex = 2
	chip.Parent = holder
	chipButton = chip
	UIKit.corner(chip, LOOK.chip // 2)
	inside = Instance.new("UIGradient")
	inside.Rotation = 90
	inside.Parent = chip
	local ring = UIKit.outline(chip, Color3.new(1, 1, 1), LOOK.ring)
	shine = Instance.new("UIGradient")
	shine.Parent = ring
	portrait = Instance.new("ImageLabel")
	portrait.Name = "Portrait"
	portrait.BackgroundTransparency = 1
	portrait.ScaleType = Enum.ScaleType.Fit
	portrait.AnchorPoint = Vector2.new(0.5, 0.5)
	portrait.Position = UDim2.fromScale(0.5, 0.5)
	portrait.Size = UDim2.fromScale(0.86, 0.86)
	portrait.ZIndex = 3
	portrait.Parent = chip

	-- the grade on the medallion's corner
	gradeBadge = Instance.new("Frame")
	gradeBadge.Name = "Grade"
	gradeBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	gradeBadge.Position = UDim2.fromScale(0.15, 0.15)
	gradeBadge.Size = UDim2.fromOffset(20, 20)
	gradeBadge.BackgroundColor3 = Color3.new(1, 1, 1)
	gradeBadge.ZIndex = 5
	gradeBadge.Parent = chip
	UIKit.corner(gradeBadge, 10)
	gradeLabel = UIKit.label(gradeBadge, "", Enum.Font.FredokaOne, 13, HudLayout.KEY_CHIP)
	gradeLabel.Size = UDim2.fromScale(1, 1)
	gradeLabel.TextXAlignment = Enum.TextXAlignment.Center
	gradeLabel.ZIndex = 6

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

	-- the tip: a small panel left of the dial while a mouse is on the medallion
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

	-- the name in its rarity's colour and its line (upgrade level, element), left of the track for a moment
	nameFrame = Instance.new("Frame")
	nameFrame.Name = "WeaponName"
	nameFrame.BackgroundTransparency = 1
	nameFrame.AnchorPoint = Vector2.new(1, 0.5)
	nameFrame.Size = UDim2.fromOffset(200, 34)
	nameFrame.Visible = false
	nameFrame.Parent = holder
	nameLabel = UIKit.label(nameFrame, "", Enum.Font.FredokaOne, 16, UIKit.Colors.Text)
	nameLabel.Size = UDim2.new(1, 0, 0, 19)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Right
	UIKit.outlined(nameLabel)
	lineLabel = UIKit.label(nameFrame, "", Enum.Font.GothamBold, 11, Color3.new(1, 1, 1))
	lineLabel.Position = UDim2.fromOffset(0, 19)
	lineLabel.Size = UDim2.new(1, 0, 0, 14)
	lineLabel.TextXAlignment = Enum.TextXAlignment.Right
	UIKit.outlined(lineLabel)

	-- A swipe on the medallion steps too: on a phone up for the next weapon and down for the one before, and a hold opens
	-- the column of them all (owner 2026-11-17, placement 2: "add a swipe up/down o both. when a player long presses. it
	-- should display her pets/weapons at the top and bottom"); on a computer left for the next, right for the one before
	local consumed = PickWheel.gestures(chip, function()
		return compact
	end, function(delta: number)
		step(delta)
	end, function(input: InputObject)
		openWheel(input)
	end)
	local pressedAt: Vector3? = nil
	chip.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressedAt = input.Position
		end
	end)
	chip.InputEnded:Connect(function(input)
		local from = pressedAt
		pressedAt = nil
		if compact or not from or (input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1) then
			return
		end
		local dx = input.Position.X - from.X
		if math.abs(dx) >= LOOK.swipe then
			step(if dx < 0 then 1 else -1)
		end
	end)
	-- the phone's medallion: a tap (not a swipe or a hold) is the next weapon; deferred so a swipe's end is seen first
	chip.Activated:Connect(function()
		task.defer(function()
			if compact and not consumed() and not PickWheel.isOpen() then
				step(1)
			end
		end)
	end)
	placeRoll(nil, 1)
end

-- The weapons now (the character window): owned ones' grade and level, and the one in hand
function WeaponSwitchController.GetState(): { owned: { [string]: any }, equipped: string? }
	return { owned = owned, equipped = equipped }
end

-- The phone's medallion alone, or the dial: the track hides, the medallion grows and sits alone, the name goes beside it
local function setCompact(on: boolean)
	compact = on
	refreshHere()
	local size = if on then LOOK.compactChip else LOOK.chip
	chipButton.Size = UDim2.fromOffset(size, size)
	local corner = chipButton:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, size // 2)
	end
	local middle = if on then Vector2.new(size / 2, size / 2) else CENTER
	chipButton.Position = UDim2.fromOffset(middle.X, middle.Y)
	holder.Size = if on then UDim2.fromOffset(size, size) else UDim2.fromOffset(DIAL, DIAL)
	-- the name left of the track, level with the medallion's middle; on a phone over the medallion (the creature sits
	-- left of it in the pair), with chevrons over and under it (it swipes)
	if on then
		nameFrame.AnchorPoint = Vector2.new(1, 1)
		nameFrame.Position = UDim2.fromOffset(size, -26)
	else
		nameFrame.AnchorPoint = Vector2.new(1, 0.5)
		nameFrame.Position = UDim2.fromOffset(CENTER.X - LOOK.arc - LOOK.side / 2 - LOOK.gap, middle.Y)
	end
	local hints = weaponHints
	if hints then
		hints:Destroy()
		weaponHints = nil
	end
	if on then
		weaponHints = PickWheel.hints(chipButton, size / 2 + 12)
	end
	laidOutSize = Vector2.zero -- lay it out again
	render()
end

function WeaponSwitchController.Start()
	build()
	render()
	UIController.OnCompact(setCompact)
	refreshHere()
	Hud.onTown(function()
		refreshHere()
	end)
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
		-- the phone's spot in the party dock: kept while there's a weapon to switch to, out of town
		local spot = PartyBarController.GetWeaponSpot()
		local wantSpot = compact and WeaponSwitch.visible(list) and weaponHere
		if spot and spot.Visible ~= wantSpot then
			spot.Visible = wantSpot
		end
		local spotAt = if spot and spot.Visible and not fight then spot.AbsolutePosition else Vector2.zero
		-- in a computer's bar while there's a weapon to switch to here (UIController makes room for it)
		local wanted = WeaponSwitch.visible(list) and weaponHere and not compact
		if switchLayer and switchLayer:GetAttribute("Wanted") ~= wanted then
			switchLayer:SetAttribute("Wanted", wanted)
		end
		if view ~= laidOutSize or fight ~= laidOutFight or clearKey() ~= laidOutClear or spotAt ~= laidOutSpot or barKey(fight) ~= laidOutBar then
			relayout(view, fight)
		end
		holder.Visible = WeaponSwitch.visible(list)
			and (weaponHere or fight)
			and not UIKit.anyPanelOpen()
			and not PlacementController.IsActive()
			and not RegisterController.IsShowing() -- the checkout sits in the same spot (owner 2026-11-10)
		nameFrame.Visible = os.clock() < nameUntil
		if holder.Visible then
			shine.Rotation = (os.clock() / LOOK.shineSeconds * 360) % 360
		end
		if tip.Visible and not holder.Visible then
			tip.Visible = false
		end
	end)
end

return WeaponSwitchController
