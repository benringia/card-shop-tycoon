--!strict
-- A weapon's card view (weapons round 1, Task 10), over the binder's Armory: its card (Util/WeaponFace), its stats in
-- words (WeaponText.stats), where it comes from and the progress toward forging it, and Equip (Remotes.EquipWeapon;
-- the server checks it's yours and you're not fighting). Upgrades and reforges are the Forge's, in your shop.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Combat = require(Config:WaitForChild("Combat"))
local Swords = require(Config:WaitForChild("Swords"))
local Items = require(Config:WaitForChild("Items"))
local Weapons = require(Config:WaitForChild("Weapons"))
local WeaponRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponRules"))
local WeaponText = require(Shared:WaitForChild("Util"):WaitForChild("WeaponText"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local WeaponFace = require(ClientUtil:WaitForChild("WeaponFace"))
local UIController = require(Controllers:WaitForChild("UIController"))

export type State = { owned: { [string]: WeaponRules.Owned }, equipped: string, items: { [string]: number } }

local WeaponDetailController = {}

local Z_INDEX = 8 -- over the binder, like the rarity guide
local CARD_HEIGHT = 250 -- at most; shorter windows (phones) get a smaller card so Equip stays in view
local MIN_CARD_HEIGHT = 140
local CARD_ASPECT = 0.7
local ROW_HEIGHT = 26
local MAX_SIZE = Vector2.new(760, 460)
local DESKTOP_SCALE, PHONE_SCALE = Vector2.new(0.86, 0.82), Vector2.new(0.97, 0.96)

local panel: Frame? = nil
local list: ScrollingFrame
local row: Frame
local cardFrame: Frame
local cardStroke: UIStroke
local side: Frame
local rows: ScrollingFrame
local equip: TextButton
local note: TextLabel
local current: string? = nil
local getState: () -> State = function()
	return { owned = {}, equipped = Weapons.STARTER, items = {} }
end

local function build(): Frame
	local frame, scroll = UIKit.panel(UIController.GetScreenGui(), "WeaponDetail", "⚔️ Weapon")
	frame:SetAttribute("Overlay", true) -- opens over the binder without closing it
	frame.ZIndex = Z_INDEX
	local limit = frame:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = MAX_SIZE
	end
	list = scroll
	local colors = UIKit.colorsFor(frame)
	row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Parent = list
	cardFrame = Instance.new("Frame")
	cardFrame.Name = "Card"
	cardFrame.BackgroundTransparency = 1
	cardFrame.Parent = row
	cardStroke = Instance.new("UIStroke")
	cardStroke.Transparency = 1
	cardStroke.Parent = cardFrame
	side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.Parent = row
	-- The stats scroll when they don't fit (a short phone), so Equip under them always shows
	rows = Instance.new("ScrollingFrame")
	rows.Name = "Stats"
	rows.BackgroundTransparency = 1
	rows.BorderSizePixel = 0
	rows.ScrollBarThickness = 4
	rows.CanvasSize = UDim2.new()
	rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rows.Size = UDim2.new(1, 0, 1, -76)
	rows.Parent = side
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = rows
	equip = UIKit.button(side, "Equip", UIKit.Colors.Success)
	equip.AnchorPoint = Vector2.new(0, 1)
	equip.Position = UDim2.new(0, 0, 1, -22)
	equip.Size = UDim2.new(0.6, 0, 0, 48) -- tap targets are 48 px or more
	note = UIKit.label(side, "Upgrade and reforge it at the Forge in your shop.", Enum.Font.GothamBold, 13, colors.inkSoft)
	note.AnchorPoint = Vector2.new(0, 1)
	note.Position = UDim2.new(0, 0, 1, 0)
	note.Size = UDim2.new(1, 0, 0, 18)
	equip.Activated:Connect(function()
		if current then
			Remotes.EquipWeapon:FireServer(current)
		end
	end)
	return frame
end

local function addRow(order: number, label: string, value: string)
	local colors = UIKit.colorsFor(rows)
	local line = UIKit.label(rows, `{label}: {value}`, Enum.Font.GothamBold, 15, colors.ink)
	line.LayoutOrder = order
	line.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	line.TextWrapped = true
	line.TextYAlignment = Enum.TextYAlignment.Center
end

-- Redraws the open card from the latest state (an equip, an upgrade, new materials)
function WeaponDetailController.Refresh()
	local frame = panel
	local weaponId = current
	if not frame or not frame.Visible or not weaponId then
		return
	end
	local weapon = Weapons.ById[weaponId]
	if not weapon then
		return
	end
	local state = getState()
	local record = state.owned[weaponId]
	local mine = record ~= nil or weaponId == Weapons.STARTER
	local have, need = WeaponRules.makeProgress(Weapons, weaponId, state.items)
	local progress = if have and need then { have = have, need = need } else nil
	WeaponFace.render(cardFrame, cardStroke, weaponId, record, progress)
	local title = frame:FindFirstChild("Title", true)
	if title and title:IsA("TextLabel") then
		title.Text = `⚔️ {weapon.name}`
	end
	for _, child in rows:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	addRow(1, "Rarity", weapon.rarity)
	for index, stat in WeaponText.stats(Weapons, weaponId, if mine then (record or { grade = "C", level = 0 }) else nil, Combat) do
		addRow(1 + index, stat.label, stat.value)
	end
	if not mine then
		addRow(20, "Where", if weapon.ready then WeaponText.source(Weapons, Bosses, weaponId) else "Coming soon")
		local cost = WeaponRules.makeCost(Weapons, weaponId)
		if cost then
			local lines = {}
			for _, line in WeaponText.cost(cost, state.items, 0, Items) do
				if not string.match(line.text, "^%$") then
					table.insert(lines, line.text)
				end
			end
			addRow(21, "Forge it with", `{table.concat(lines, ", ")} (and cash)`)
		end
	end
	local equipped = state.equipped == weaponId
	-- Before the first sword's shop level there's nothing to equip yet: say when it comes instead
	local level = Players.LocalPlayer:GetAttribute("Level")
	local blocked = WeaponRules.equipBlock(if typeof(level) == "number" then level else 0, Swords.UNLOCK_SHOP_LEVEL, false)
	equip.Visible = mine and weapon.ready and blocked == nil
	equip.Text = if equipped then "Equipped" else "Equip"
	equip.Active = not equipped
	equip.AutoButtonColor = not equipped
	note.Text = blocked or "Upgrade and reforge it at the Forge in your shop."
	note.Visible = blocked ~= nil or (weapon.ready and weaponId ~= Weapons.STARTER)
end

function WeaponDetailController.IsOpen(): boolean
	return panel ~= nil and (panel :: Frame).Visible
end

-- Sized for this screen: nearly all of a phone's, and the card as tall as the window leaves room for (from the screen's
-- size, not the window's, which is still popping in)
local function fit(frame: Frame)
	local phone = UIKit.isPhone()
	local scale = if phone then PHONE_SCALE else DESKTOP_SCALE
	frame.Size = UDim2.fromScale(scale.X, scale.Y)
	local screen = UIController.GetScreenGui().AbsoluteSize
	local windowHeight = math.min(screen.Y * scale.Y, MAX_SIZE.Y)
	local height = math.clamp(windowHeight - (UIKit.HEADER_HEIGHT + 24) - 12, MIN_CARD_HEIGHT, CARD_HEIGHT)
	local width = height * CARD_ASPECT
	row.Size = UDim2.new(1, -8, 0, height)
	cardFrame.Size = UDim2.fromOffset(width, height)
	side.Position = UDim2.fromOffset(width + 16, 0)
	side.Size = UDim2.new(1, -(width + 16), 1, 0)
end

function WeaponDetailController.Open(weaponId: string)
	if not Weapons.ById[weaponId] then
		return
	end
	local frame = panel
	if not frame then
		frame = build()
		panel = frame
	end
	current = weaponId
	fit(frame)
	frame.Visible = true
	WeaponDetailController.Refresh()
end

function WeaponDetailController.Close()
	if panel then
		(panel :: Frame).Visible = false
	end
	current = nil
end

-- The binder hands in where the owned weapons, the equipped one and the Bag's counts come from
function WeaponDetailController.SetSource(source: () -> State)
	getState = source
end

return WeaponDetailController
