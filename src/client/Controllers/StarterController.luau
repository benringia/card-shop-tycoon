--!strict
-- The Starter Pack's card (spec 2026-11-28-robux-round-design, Starter A; Config/Starter): when the server says it's due
-- (Remotes.StarterOffer, StarterService), it waits for a calm moment (Util/StarterRules.mayShow: ready, no window, no
-- purchase dialog or Roblox menu, nothing on the stage, no fight, no tour, not at the register), then shows a cotton
-- candy window with Pish peeking over its corner: "A one-time pack to start your shop:", its three things, the gold price
-- button (Remotes.BuyUnlock "StarterPack": the server checks it's for sale here) and "Maybe later". It tells the server
-- it showed, so it never comes again; the Store keeps the offer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Starter = require(Config:WaitForChild("Starter"))
local Monetization = require(Config:WaitForChild("Monetization"))
local HudMascot = require(Config:WaitForChild("HudMascot"))
local Chikin = require(Config:WaitForChild("Chikin"))
local StarterRules = require(Shared:WaitForChild("Util"):WaitForChild("StarterRules"))
local TutorialRules = require(Shared:WaitForChild("Util"):WaitForChild("TutorialRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local ScreenClear = require(ClientUtil:WaitForChild("ScreenClear"))
local OpeningStage = require(ClientUtil:WaitForChild("OpeningStage"))
local ProductPrice = require(ClientUtil:WaitForChild("ProductPrice"))
local RobuxPrice = require(ClientUtil:WaitForChild("RobuxPrice"))
local UIController = require(Controllers:WaitForChild("UIController"))
local WeaponRevealController = require(Controllers:WaitForChild("WeaponRevealController"))

local StarterController = {}

local KEY = "StarterPack"
local CARD = Starter.CARD

local player = Players.LocalPlayer
local waiting = false -- a card is due and waits for a calm moment

-- What's on the screen right now (StarterRules.Facts)
local function facts(): StarterRules.Facts
	local pish, combat = player:GetAttribute("TutorialStep"), player:GetAttribute("CombatStep")
	return {
		ready = player:GetAttribute("LoadingDone") == true
			and player:GetAttribute("SeenPrologue") == true
			and player:GetAttribute("SeenWelcome") == true
			and player:GetAttribute("TutorialDone") == true,
		panelOpen = UIKit.anyPanelOpen(),
		screenClear = ScreenClear.isClear(),
		stageShown = OpeningStage.isShown(),
		revealing = WeaponRevealController.IsPlaying(),
		fighting = player:GetAttribute("FightHud") == true,
		tour = TutorialRules.tourLeading(if typeof(pish) == "string" then pish else "", if typeof(combat) == "string" then combat else "", Chikin.WAIT_STEP),
		register = player:GetAttribute("ManningRegister") == true,
	}
end

-- One of the three things inside: its picture, its name and a short line
local function row(list: Instance, order: number, look: { icon: string, name: string, line: string }, palette: any)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -16, 0, 50)
	frame.BackgroundColor3 = palette.row
	frame.Parent = list
	UIKit.corner(frame, 14)
	UIKit.outline(frame, palette.rowEdge, 2)
	local icon = UIKit.label(frame, look.icon, Enum.Font.FredokaOne, 26, palette.ink)
	icon.Position = UDim2.fromOffset(8, 0)
	icon.Size = UDim2.new(0, 36, 1, 0)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	local name = UIKit.label(frame, look.name, Enum.Font.FredokaOne, 17, palette.ink)
	name.Position = UDim2.fromOffset(52, 6)
	name.Size = UDim2.new(1, -60, 0, 20)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local line = UIKit.label(frame, look.line, Enum.Font.GothamBold, 12, palette.inkSoft)
	line.Position = UDim2.fromOffset(52, 27)
	line.Size = UDim2.new(1, -60, 0, 16)
	line.TextXAlignment = Enum.TextXAlignment.Left
end

local function show()
	local screen = UIController.GetScreenGui()
	local panel, list = UIKit.panel(screen, "StarterOffer", CARD.title, "Quests")
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(CARD.maxSize[1], CARD.maxSize[2])
	end
	local palette = UIKit.colorsFor(panel)
	local layout = list:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Padding = UDim.new(0, 8)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	local peek = Instance.new("ImageLabel")
	peek.Name = "PishPeek"
	peek.BackgroundTransparency = 1
	peek.Image = HudMascot.images.peek
	peek.ScaleType = Enum.ScaleType.Fit
	peek.AnchorPoint = Vector2.new(0, 1)
	peek.Position = UDim2.fromOffset(CARD.peek.left, CARD.peek.overlap)
	peek.Size = UDim2.fromOffset(CARD.peek.size[1], CARD.peek.size[2])
	peek.ZIndex = 60
	peek.Parent = panel

	local line = UIKit.label(list, CARD.line, Enum.Font.GothamBold, 14, palette.inkSoft)
	line.LayoutOrder = 1
	line.Size = UDim2.new(1, -16, 0, 20)
	line.TextXAlignment = Enum.TextXAlignment.Center
	for index, look in CARD.rows do
		row(list, 1 + index, look, palette)
	end

	local buttons = Instance.new("Frame")
	buttons.LayoutOrder = 10
	buttons.BackgroundTransparency = 1
	buttons.Size = UDim2.new(1, -16, 0, 56)
	buttons.Parent = list
	local flow = Instance.new("UIListLayout")
	flow.FillDirection = Enum.FillDirection.Horizontal
	flow.HorizontalAlignment = Enum.HorizontalAlignment.Center
	flow.Padding = UDim.new(0, 12)
	flow.SortOrder = Enum.SortOrder.LayoutOrder
	flow.Parent = buttons
	local id = Monetization.PRODUCTS[KEY] or 0
	local buy = UIKit.button(buttons, if id == 0 then "Coming soon" else "...", UIKit.Colors.Accent)
	buy.Name = "Buy"
	buy.LayoutOrder = 1
	buy.Size = UDim2.fromOffset(150, 52)
	ProductPrice.whenKnown(id, false, function(price: number)
		if buy.Parent then
			RobuxPrice.set(buy, "", price)
		end
	end)
	buy.Activated:Connect(function()
		if id == 0 then
			return
		end
		ScreenClear.prompt()
		Remotes.BuyUnlock:FireServer(KEY)
	end)
	local later = UIKit.button(buttons, CARD.later, UIKit.Colors.Secondary)
	later.Name = "Later"
	later.LayoutOrder = 2
	later.Size = UDim2.fromOffset(140, 52)
	later.Activated:Connect(function()
		panel.Visible = false
	end)

	local foot = UIKit.label(list, CARD.foot, Enum.Font.GothamBold, 12, palette.hint)
	foot.LayoutOrder = 11
	foot.Size = UDim2.new(1, -16, 0, 18)
	foot.TextXAlignment = Enum.TextXAlignment.Center

	-- bought (the win card plays): the card goes
	local bought = player:GetAttributeChangedSignal(`Has{KEY}`):Connect(function()
		if player:GetAttribute(`Has{KEY}`) == true then
			panel.Visible = false
		end
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			bought:Disconnect()
			task.delay(1, panel.Destroy, panel)
		end
	end)
	panel.Visible = true
	Remotes.StarterOffer:FireServer() -- it showed: never again
end

-- Waits for a calm moment, then shows the card (once; the server never sends it to an owner)
local function onOffer()
	if waiting then
		return
	end
	waiting = true
	task.spawn(function()
		while not StarterRules.mayShow(facts()) do
			task.wait(Starter.POLL)
		end
		waiting = false
		if player:GetAttribute(`Has{KEY}`) ~= true then
			show()
		end
	end)
end

function StarterController.Start()
	Remotes.StarterOffer.OnClientEvent:Connect(onOffer)
end

return StarterController
