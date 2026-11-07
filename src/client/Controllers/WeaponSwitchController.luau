--!strict
-- The quick weapon switch (spec 2026-11-07-weapons-round2-design 6; the owner's pick A, 2026-11-07): a round chip on the
-- right edge with your weapon's picture in its rarity's ring, < and > either side (or swipe the chip, or Q / Shift+Q). It
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

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIController = require(Controllers:WaitForChild("UIController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))

local WeaponSwitchController = {}

local player = Players.LocalPlayer
local LOOK = HudLayout.WEAPON_SWITCH

local owned: { [string]: any } = {}
local equipped: string? = nil
local list: { string } = {}
local holder: Frame
local portrait: ImageLabel
local ring: UIStroke
local nameLabel: TextLabel
local keyBadge: Frame
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
	Remotes.EquipWeapon:FireServer(nextId)
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
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Position = UDim2.new(1, -LOOK.right, 0.5, 0)
	holder.Size = UDim2.fromOffset(LOOK.chip + 2 * (LOOK.arrow + LOOK.gap), LOOK.chip + 22)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = layer
	Hud.scaleWith(holder)

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

	-- Q on keyboards, in its white circle like the HUD tiles' keys
	keyBadge = Instance.new("Frame")
	keyBadge.Name = "Key"
	keyBadge.AnchorPoint = Vector2.new(1, 1)
	keyBadge.Position = UDim2.new(1, 2, 1, 2)
	keyBadge.Size = UDim2.fromOffset(HudLayout.KEY_SIZE, HudLayout.KEY_SIZE)
	keyBadge.BackgroundColor3 = Color3.new(1, 1, 1)
	keyBadge.Visible = UserInputService.KeyboardEnabled
	keyBadge.Parent = chip
	UIKit.corner(keyBadge, HudLayout.KEY_SIZE // 2)
	local key = UIKit.label(keyBadge, "Q", Enum.Font.GothamBold, 13, HudLayout.KEY_CHIP)
	key.Size = UDim2.fromScale(1, 1)
	key.TextXAlignment = Enum.TextXAlignment.Center

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
		if typeof(data.equipped) == "string" then
			equipped = data.equipped
		end
		render()
	end)
	player:GetAttributeChangedSignal("Level"):Connect(render)
	Remotes.WeaponsChanged:FireServer() -- the weapons now, if their first send came before this listened

	-- Q: the next weapon, Shift+Q: the one before (not while typing, placing something or with a window open)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		local layer = holder.Parent :: GuiObject
		if gameProcessed or input.KeyCode ~= Enum.KeyCode.Q or not holder.Visible or not layer.Visible then
			return
		end
		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		step(if shift then -1 else 1)
	end)

	RunService.Heartbeat:Connect(function()
		holder.Visible = WeaponSwitch.visible(list) and not UIKit.anyPanelOpen() and not PlacementController.IsActive()
		nameLabel.Visible = os.clock() < nameUntil
	end)
end

return WeaponSwitchController
