--!strict
-- "Support the dev" (owner 2026-11-12; picks: tap Pish to open it and he asks now and then): tapping the HUD's Pish
-- (when no tour leads) opens the card: Pish and Chikin's medallion, the three gifts (Config/Support TIERS: their title
-- and aura, "R$ X" from the product's price, "Yours!" on the tiers you have), how many times you gave, and "Replay a
-- tour" (the main game, after Pish's first visit; TutorialController). After a good moment (a boss win, your own big
-- pull) Pish asks once a session from his bubble (Util/SupportRules.nudge). Server/Services/SupportService grants the
-- gifts.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Chikin = require(Config:WaitForChild("Chikin"))
local Monetization = require(Config:WaitForChild("Monetization"))
local Support = require(Config:WaitForChild("Support"))
local SupportRules = require(Shared:WaitForChild("Util"):WaitForChild("SupportRules"))
local TutorialRules = require(Shared:WaitForChild("Util"):WaitForChild("TutorialRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local HudMascotView = require(ClientUtil:WaitForChild("HudMascotView"))
local ProductPrice = require(ClientUtil:WaitForChild("ProductPrice"))
local ScreenClear = require(ClientUtil:WaitForChild("ScreenClear"))
local UIController = require(Controllers:WaitForChild("UIController"))
local TutorialController = require(Controllers:WaitForChild("TutorialController"))

local SupportController = {}

local ROW_HEIGHT = 64
local player = Players.LocalPlayer

local panel: Frame
local gifts = 0
local asked = false -- Pish asked this session
local tierRows: { { tag: TextLabel, button: TextButton, id: number } } = {}
local giftsLabel: TextLabel
local replayButton: TextButton

local function stepOf(name: string): string
	local value = player:GetAttribute(name)
	return if typeof(value) == "string" then value else ""
end

local function touring(): boolean
	return TutorialRules.tourLeading(stepOf("TutorialStep"), stepOf("CombatStep"), Chikin.WAIT_STEP)
end

local function best(): number
	return tonumber(player:GetAttribute("SupporterTier")) or 0
end

local function productId(key: string): number
	local id = Monetization.PRODUCTS[key]
	return if typeof(id) == "number" then id else 0
end

local function render()
	for index, row in tierRows do
		local price = ProductPrice.of(row.id)
		row.button.Text = if row.id == 0 then "Soon" elseif price then `R$ {price}` else "Give"
		row.tag.Visible = best() >= index
	end
	giftsLabel.Text = if gifts > 0 then string.format(Support.CARD.gifts, gifts, if gifts == 1 then "" else "s") else ""
	replayButton.Visible = TutorialController.CanReplay()
end

local function open()
	render()
	panel.Visible = true
	Remotes.SupportState:FireServer() -- the latest count
	task.delay(1, function()
		if panel.Visible then
			render() -- the prices, once Roblox answers
		end
	end)
end

local function build()
	local list: ScrollingFrame
	panel, list = UIKit.panel(UIController.GetScreenGui(), "Support", Support.CARD.title)
	panel.Size = UDim2.fromScale(0.92, 0.92) -- the three gifts in view on a desktop (UIKit.panel's 520 high at most)
	local palette = UIKit.colorsFor(panel)

	local picture = Instance.new("ImageLabel")
	picture.Name = "Dogs"
	picture.LayoutOrder = 1
	picture.BackgroundTransparency = 1
	picture.Size = UDim2.new(1, 0, 0, Support.CARD.pictureHeight)
	picture.Image = Support.CARD.picture
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Parent = list

	local line = UIKit.label(list, Support.CARD.line, Enum.Font.GothamBold, 15, palette.inkSoft)
	line.LayoutOrder = 2
	line.Size = UDim2.new(1, 0, 0, 22)
	line.TextXAlignment = Enum.TextXAlignment.Center
	line.TextWrapped = true

	for index, tier in Support.TIERS do
		local row = Instance.new("Frame")
		row.Name = `Tier{index}`
		row.LayoutOrder = 2 + index
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.BackgroundColor3 = palette.row
		row.Parent = list
		UIKit.corner(row, 14)
		UIKit.outline(row, palette.rowEdge, 2)
		local name = UIKit.label(row, `{tier.icon} {tier.name}`, Enum.Font.FredokaOne, 19, palette.ink)
		name.Position = UDim2.fromOffset(12, 8)
		name.Size = UDim2.new(1, -140, 0, 26)
		local perk = UIKit.label(row, tier.perk, Enum.Font.GothamBold, 13, palette.inkSoft)
		perk.Position = UDim2.fromOffset(12, 34)
		perk.Size = UDim2.new(1, -140, 0, 20)
		local tag = UIKit.pill(row, Support.CARD.yours, UIKit.Colors.Success)
		tag.AnchorPoint = Vector2.new(1, 0)
		tag.Position = UDim2.new(1, -124, 0, 8)
		local id = productId(tier.product)
		local button = UIKit.button(row, "", UIKit.Colors.Accent)
		button.Name = "Give"
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -10, 0.5, 0)
		button.Size = UDim2.fromOffset(104, 48)
		button.Activated:Connect(function()
			if id ~= 0 then
				ScreenClear.prompt()
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
		table.insert(tierRows, { tag = tag, button = button, id = id })
	end

	giftsLabel = UIKit.label(list, "", Enum.Font.GothamBold, 14, palette.inkSoft)
	giftsLabel.LayoutOrder = 10
	giftsLabel.Size = UDim2.new(1, 0, 0, 20)
	giftsLabel.TextXAlignment = Enum.TextXAlignment.Center

	local footer = Instance.new("Frame")
	footer.LayoutOrder = 11
	footer.BackgroundTransparency = 1
	footer.Size = UDim2.new(1, 0, 0, 48)
	footer.Parent = list
	replayButton = UIKit.button(footer, Support.CARD.replay, UIKit.Colors.Secondary)
	replayButton.Name = "ReplayTour"
	replayButton.AnchorPoint = Vector2.new(0.5, 0)
	replayButton.Position = UDim2.fromScale(0.5, 0)
	replayButton.Size = UDim2.fromOffset(200, 44)
	replayButton.Activated:Connect(function()
		UIKit.closePanel(panel)
		TutorialController.OfferReplay()
	end)
end

-- After a good moment: Pish asks from his bubble, once a session (Util/SupportRules.nudge)
local function nudgeSoon()
	task.delay(Support.NUDGE.delay, function()
		local ready = workspace:GetAttribute("PlaceKind") ~= "Main" or player:GetAttribute("TutorialDone") == true
		if SupportRules.nudge({ asked = asked, best = best(), touring = touring(), ready = ready }) then
			asked = true
			UIController.Notify(Support.NUDGE.text, false)
		end
	end)
end

function SupportController.Start()
	build()
	HudMascotView.onTap(function()
		if not touring() then
			open() -- a tour's own taps (Pish's goodbye) are TutorialController's
		end
	end)
	Remotes.SupportState.OnClientEvent:Connect(function(state: unknown)
		if typeof(state) == "table" and typeof((state :: any).gifts) == "number" then
			gifts = (state :: any).gifts
			if panel.Visible then
				render()
			end
		end
	end)
	player:GetAttributeChangedSignal("SupporterTier"):Connect(function()
		if panel.Visible then
			render()
		end
	end)
	Remotes.BattleEnded.OnClientEvent:Connect(function(summary: unknown)
		if typeof(summary) == "table" and (summary :: any).result == "win" and (summary :: any).boss ~= nil then
			nudgeSoon()
		end
	end)
	Remotes.PullAnnouncement.OnClientEvent:Connect(function(displayName: unknown)
		if displayName == player.DisplayName then
			nudgeSoon() -- your own big pull
		end
	end)
	Remotes.SupportState:FireServer()
end

return SupportController
