--!strict
-- The quick weapon switch (spec 2026-11-07-weapons-round2-design 6; the owner's pick A, 2026-11-07): a round chip on the
-- right edge with your weapon's picture in its rarity's ring, < and > either side (or swipe the chip, or Q / Z). It
-- steps through every weapon you own (Util/WeaponSwitch) and asks the server to equip it (EquipWeapon; in a fight a
-- switch costs Weapons.SWAP_SECONDS with no cut or skill). Shown with two weapons or more, never over a window.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Weapons = require(Config:WaitForChild("Weapons"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local Swords = require(Config:WaitForChild("Swords"))
local HudLayout = require(Config:WaitForChild("HudLayout"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local WeaponSwitch = require(Shared:WaitForChild("Util"):WaitForChild("WeaponSwitch"))
local UiLayout = require(Shared:WaitForChild("Util"):WaitForChild("UiLayout"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIController = require(Controllers:WaitForChild("UIController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))
local RegisterController = require(Controllers:WaitForChild("RegisterController"))

local WeaponSwitchController = {}

local player = Players.LocalPlayer
local LOOK = HudLayout.WEAPON_SWITCH

local owned: { [string]: any } = {}
local equipped: string? = nil
local list: { string } = {}
local holder: Frame
local holderScale: UIScale
local portrait: ImageLabel
local ring: UIStroke
local nameLabel: TextLabel
local nameUntil = 0

local function unlocked(): boolean
	local level = player:GetAttribute("Level")
	return typeof(level) == "number" and level >= Swords.UNLOCK_SHOP_LEVEL
end

-- The chip shows your equipped weapon (the first in the list if the server hasn't said yet)
local function render()
	list = WeaponSwitch.list(Weapons, owned, unlocked())
	local id = if equipped and table.find(list, equipped) then equipped else list[1]
	local weapon = if id then Weapons.ById[id] else nil
	local look = if id then WeaponLooks.WEAPONS[id] else nil
	portrait.Image = if look then look.portrait else ""
	ring.Color = if weapon then CardFace.getRarityColor(weapon.rarity) else UIKit.Colors.Outline
	nameLabel.Text = if weapon then string.upper(weapon.name) else ""
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
	send(nextId)
end

-- On the right edge, and in a fight above the fight buttons (UiLayout.weaponSwitch); redone when the screen's size
-- changes or a fight's controls come or go
local laidOutSize = Vector2.zero
local laidOutFight = false
local function relayout(view: Vector2, fight: boolean)
	laidOutSize, laidOutFight = view, fight
	local rect = UiLayout.weaponSwitch({ w = view.X, h = view.Y }, LOOK, Hud.scaleFor(), fight)
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
	holder = Instance.new("Frame")
	holder.Name = "Switch"
	holder.Size = UDim2.fromOffset(LOOK.chip + 2 * (LOOK.arrow + LOOK.gap), LOOK.chip + LOOK.name)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = layer
	holderScale = Instance.new("UIScale") -- set by relayout (UiLayout.weaponSwitch)
	holderScale.Parent = holder

	local previous = UIKit.button(holder, "<", UIKit.Colors.Secondary)
	previous.Name = "Previous"
	previous.Size = UDim2.fromOffset(LOOK.arrow, LOOK.arrow)
	previous.Position = UDim2.fromOffset(0, (LOOK.chip - LOOK.arrow) / 2)
	previous.Activated:Connect(function()
		step(-1)
	end)
	local nextButton = UIKit.button(holder, ">", UIKit.Colors.Secondary)
	nextButton.Name = "Next"
	nextButton.Size = UDim2.fromOffset(LOOK.arrow, LOOK.arrow)
	nextButton.Position = UDim2.fromOffset(LOOK.arrow + 2 * LOOK.gap + LOOK.chip, (LOOK.chip - LOOK.arrow) / 2)
	nextButton.Activated:Connect(function()
		step(1)
	end)

	local chip = Instance.new("ImageButton")
	chip.Name = "Chip"
	chip.AutoButtonColor = false
	chip.BackgroundColor3 = UIKit.Colors.Panel
	chip.Size = UDim2.fromOffset(LOOK.chip, LOOK.chip)
	chip.Position = UDim2.fromOffset(LOOK.arrow + LOOK.gap, 0)
	chip.Parent = holder
	UIKit.corner(chip, LOOK.chip // 2)
	ring = UIKit.outline(chip, UIKit.Colors.Outline, LOOK.ring)
	portrait = Instance.new("ImageLabel")
	portrait.Name = "Portrait"
	portrait.BackgroundTransparency = 1
	portrait.ScaleType = Enum.ScaleType.Fit
	portrait.AnchorPoint = Vector2.new(0.5, 0.5)
	portrait.Position = UDim2.fromScale(0.5, 0.5)
	portrait.Size = UDim2.fromScale(0.86, 0.86)
	portrait.Parent = chip

	-- Q (the next weapon) on the chip and Z (the one before, owner 2026-11-09) on the < button, on keyboards, each in its
	-- white circle like the HUD tiles' keys
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
	badge(chip, "Q", Vector2.new(1, 1), UDim2.new(1, 2, 1, 2))
	badge(previous, Weapons.PREVIOUS_KEY, Vector2.new(0, 1), UDim2.new(0, -6, 1, 6))

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
				step(if dx < 0 then 1 else -1)
			end
		end
	end)
end

function WeaponSwitchController.Start()
	build()
	render()
	Remotes.WeaponsChanged.OnClientEvent:Connect(function(state: unknown)
		if typeof(state) ~= "table" then
			return
		end
		local data = state :: any
		if typeof(data.owned) == "table" then
			owned = data.owned
		end
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
		if view ~= laidOutSize or fight ~= laidOutFight then
			relayout(view, fight)
		end
		holder.Visible = WeaponSwitch.visible(list)
			and not UIKit.anyPanelOpen()
			and not PlacementController.IsActive()
			and not RegisterController.IsShowing() -- the checkout sits in the same spot (owner 2026-11-10)
		nameLabel.Visible = os.clock() < nameUntil
	end)
end

return WeaponSwitchController
