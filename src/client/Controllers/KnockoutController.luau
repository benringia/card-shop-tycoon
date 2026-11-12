--!strict
-- The "Knocked out!" screen (spec 2026-11-12-timed-upgrades-revive-design; Server/Services/KnockoutService sends
-- Remotes.Knockout): the seconds till you wake at the spring, "Revive here · R$ X" (the Revive developer product: up on
-- the spot, cards rested; "Coming soon" while its id is 0) and "Wake at the spring". The countdown stands still while the
-- purchase prompt is open (the server says so). Looks like the locked card (Config/Blocked) it replaces.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Combat = require(Config:WaitForChild("Combat"))
local Monetization = require(Config:WaitForChild("Monetization"))
local CardLook = require(Config:WaitForChild("Blocked"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local ProductPrice = require(ClientUtil:WaitForChild("ProductPrice"))
local ScreenClear = require(ClientUtil:WaitForChild("ScreenClear"))

local KnockoutController = {}

local LOOK = Combat.DANGER.knockout
local player = Players.LocalPlayer

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function reviveId(): number
	local id = Monetization.PRODUCTS.Revive
	return if typeof(id) == "number" then id else 0
end

function KnockoutController.Start()
	local phone = UIKit.isPhone()
	local gui = Instance.new("ScreenGui")
	gui.Name = "KnockoutScreen"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 44 -- under the locked card (45)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.48)
	card.Size = UDim2.fromOffset(if phone then 300 else 400, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = rgb(CardLook.BACK)
	card.BackgroundTransparency = 0.04
	card.Parent = gui
	UIKit.corner(card, 18)
	UIKit.outline(card, rgb(CardLook.EDGE), 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = card
	local scale = Instance.new("UIScale")
	scale.Parent = card

	local function line(text: string, size: number, color: Color3, order: number, font: Enum.Font): TextLabel
		local label = UIKit.label(card, text, font, if phone then math.floor(size * 0.8) else size, color)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextWrapped = true
		label.Size = UDim2.new(1, 0, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.LayoutOrder = order
		UIKit.outlined(label, 2)
		return label
	end
	line(LOOK.icon, 40, Color3.new(1, 1, 1), 1, Enum.Font.FredokaOne)
	line(LOOK.title, 30, rgb(CardLook.EDGE), 2, Enum.Font.FredokaOne)
	line(LOOK.text, 18, Color3.new(1, 1, 1), 3, Enum.Font.GothamBold)
	local clock = line("", 48, Color3.new(1, 1, 1), 4, Enum.Font.FredokaOne)
	local hint = line(LOOK.untilSpring, 15, UIKit.Colors.Subtext, 5, Enum.Font.GothamBold)

	local function button(text: string, color: Color3, order: number): TextButton
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, 0, 0, 54)
		holder.LayoutOrder = order
		holder.Parent = card
		local made = UIKit.button(holder, text, color)
		made.Size = UDim2.fromScale(1, 1)
		return made
	end
	local reviveButton = button(LOOK.revive, UIKit.Colors.Success, 6)
	reviveButton.Name = "ReviveHere"
	local springButton = button(LOOK.spring, UIKit.Colors.Secondary, 7)
	springButton.Name = "WakeAtSpring"

	local endsAt = 0 -- os.clock() when the countdown hits 0
	local pausedLeft: number? = nil -- the prompt is open: the seconds it stands still at

	local function drawRevive()
		local id = reviveId()
		local price = ProductPrice.of(id)
		reviveButton.Text = if id == 0 then `{LOOK.revive} · {LOOK.comingSoon}`
			elseif price then `{LOOK.revive} · R$ {price}`
			else LOOK.revive
		reviveButton.AutoButtonColor = id ~= 0
		reviveButton.BackgroundTransparency = if id == 0 then 0.45 else 0
	end

	reviveButton.Activated:Connect(function()
		if reviveId() ~= 0 then
			ScreenClear.prompt() -- the server opens the Revive dialog
			Remotes.KnockoutChoice:FireServer("revive")
		end
	end)
	springButton.Activated:Connect(function()
		Remotes.KnockoutChoice:FireServer("spring")
	end)

	Remotes.Knockout.OnClientEvent:Connect(function(view: unknown)
		if typeof(view) ~= "table" or typeof((view :: any).left) ~= "number" then
			gui.Enabled = false
			return
		end
		local left = (view :: any).left :: number
		pausedLeft = if (view :: any).paused == true then left else nil
		endsAt = os.clock() + left
		if not gui.Enabled then
			gui.Enabled = true
			dim.BackgroundTransparency = 1
			scale.Scale = 0.4
			TweenService:Create(dim, TweenInfo.new(0.4), { BackgroundTransparency = 0.55 }):Play()
			TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		drawRevive()
	end)

	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		if not gui.Enabled then
			return
		end
		since += dt
		if since < 0.1 then
			return
		end
		since = 0
		local left = pausedLeft or math.max(0, endsAt - os.clock())
		clock.Text = tostring(math.ceil(left))
		hint.Text = if pausedLeft then LOOK.waiting else LOOK.untilSpring
		drawRevive()
	end)
end

return KnockoutController
