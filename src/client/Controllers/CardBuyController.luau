--!strict
-- Buying single cards from other players' Collector Cases: a Buy prompt on each card, then a
-- confirm box. The price shown is sent back to the server, which refuses the buy if it changed.
-- Prompts are created on this client only, and never on your own cards or on Glass Showcases.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local ShowcaseConfig = require(Config:WaitForChild("Showcase"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local UIKit = require((Controllers.Parent :: Instance):WaitForChild("Util"):WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local player = Players.LocalPlayer

local CardBuyController = {}

local confirm: Frame
local confirmText: TextLabel
local pendingPart: BasePart? = nil
local pendingPrice = 0

local function getPrice(part: BasePart): number
	local price = part:GetAttribute("Price")
	return if typeof(price) == "number" then price else 0
end

local function describe(part: BasePart): string
	local card = Cards.ById[part:GetAttribute("CardId") :: string]
	local name = if card then card.name else "card"
	return if part:GetAttribute("Foil") == true then `FOIL {name}` else name
end

local function getOwnerName(part: BasePart): string
	local ownerUserId = part:GetAttribute("OwnerUserId")
	local owner = if typeof(ownerUserId) == "number" then Players:GetPlayerByUserId(ownerUserId) else nil
	return if owner then owner.DisplayName else "another player"
end

local function openConfirm(part: BasePart)
	pendingPart = part
	pendingPrice = getPrice(part)
	confirmText.Text = string.format("Buy %s from %s for $%.2f?", describe(part), getOwnerName(part), pendingPrice)
	confirm.Visible = true
end

local function onConfirmBuy()
	local part = pendingPart
	confirm.Visible = false
	pendingPart = nil
	if not part or not part.Parent then
		UIController.Notify("That card is no longer for sale.", true)
		return
	end
	Remotes.BuyDisplayedCard:FireServer(
		part:GetAttribute("OwnerUserId"),
		part:GetAttribute("ShelfUid"),
		part:GetAttribute("Slot"),
		part:GetAttribute("CardId"),
		part:GetAttribute("Foil"),
		pendingPrice
	)
end

local function isBuyableCard(instance: Instance): boolean
	return instance:IsA("BasePart")
		and instance:GetAttribute("ShelfKind") == "PlayerCards"
		and typeof(instance:GetAttribute("CardId")) == "string"
		and instance:GetAttribute("OwnerUserId") ~= player.UserId
end

local function addBuyPrompt(instance: Instance)
	if not isBuyableCard(instance) then
		return
	end
	local part = instance :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = describe(part)
	prompt.ActionText = string.format("Buy $%.2f", getPrice(part))
	prompt.MaxActivationDistance = ShowcaseConfig.BUY_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	part:GetAttributeChangedSignal("Price"):Connect(function()
		prompt.ActionText = string.format("Buy $%.2f", getPrice(part))
		-- Keep an open confirm box honest: the server would refuse the old price anyway
		if pendingPart == part then
			openConfirm(part)
		end
	end)
	prompt.Triggered:Connect(function()
		openConfirm(part)
	end)
end

local function buildConfirm(parent: Instance)
	confirm = Instance.new("Frame")
	confirm.Name = "BuyCardConfirm"
	confirm.AnchorPoint = Vector2.new(0.5, 0.5)
	confirm.Position = UDim2.fromScale(0.5, 0.5)
	confirm.Size = UDim2.fromOffset(320, 170)
	confirm.BackgroundColor3 = UIKit.Colors.Panel
	confirm.Visible = false
	confirm.ZIndex = 20
	confirm.Parent = parent
	UIKit.corner(confirm, 14)

	confirmText = UIKit.label(confirm, "", Enum.Font.GothamBold, 18, UIKit.Colors.Text)
	confirmText.TextXAlignment = Enum.TextXAlignment.Center
	confirmText.Position = UDim2.fromOffset(16, 16)
	confirmText.Size = UDim2.new(1, -32, 0, 70)

	local buy = UIKit.button(confirm, "Buy", UIKit.Colors.Accent)
	buy.Position = UDim2.new(0, 16, 1, -68)
	buy.Size = UDim2.new(0.5, -24, 0, 52)
	buy.Activated:Connect(onConfirmBuy)

	local cancel = UIKit.button(confirm, "Cancel", UIKit.Colors.Row)
	cancel.AnchorPoint = Vector2.new(1, 0)
	cancel.Position = UDim2.new(1, -16, 1, -68)
	cancel.Size = UDim2.new(0.5, -24, 0, 52)
	cancel.Activated:Connect(function()
		confirm.Visible = false
		pendingPart = nil
	end)
end

function CardBuyController.Start()
	buildConfirm(UIController.GetScreenGui())

	local plots = workspace:WaitForChild("Plots")
	plots.DescendantAdded:Connect(addBuyPrompt)
	for _, instance in plots:GetDescendants() do
		addBuyPrompt(instance)
	end
	-- Close the box if the card sells to someone else while it's open
	plots.DescendantRemoving:Connect(function(instance)
		if instance == pendingPart then
			confirm.Visible = false
			pendingPart = nil
			UIController.Notify("That card just sold.", true)
		end
	end)
end

return CardBuyController
