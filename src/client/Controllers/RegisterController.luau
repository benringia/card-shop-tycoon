--!strict
-- Checkout panel: shows the running total and how many items are left to scan,
-- and the Charge button once everything is scanned. Scanning itself is tapping items on the counter.
-- It only shows while you're at your register: elsewhere (or while a cashier card serves) it stays hidden.
-- The offer panel takes its place while a kid offers you their pull or a bargain hunter haggles (OfferService, spec
-- 2026-11-06-customers-design, mockup option A): Buy / Deal, Counter, No, and the counter's view: - / + steps, quick
-- chips, your price and their face (from the server's edges, so the exact price they'd take never reaches here).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CustomerConfig = require(Config:WaitForChild("Customers"))
local RegisterConfig = require(Config:WaitForChild("Register"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local NEAR_CHECK_SECONDS = 0.25

type Offer = {
	id: number,
	kind: string, -- "kid" | "haggle"
	card: { cardId: string, foil: boolean, grade: string }?,
	asking: number?,
	worth: number?,
	offer: number?,
	total: number?,
	range: { number },
	step: number,
	edges: { sure: number, maybe: number },
	triesLeft: number,
}

local player = Players.LocalPlayer

local RegisterController = {}

local panel: Frame
local statusLabel: TextLabel
local chargeButton: TextButton
local checkoutOpen = false -- the server says a customer is being checked out

local offerPanel: Frame
local mainView: Frame
local counterView: Frame
local titleLabel: TextLabel
local cardHolder: Frame
local cardFace: Frame
local cardStroke: UIStroke
local nameLabel: TextLabel
local priceLabel: TextLabel
local mainHint: TextLabel
local yesButton: TextButton
local counterPriceLabel: TextLabel
local faceLabel: TextLabel
local counterHint: TextLabel
local counterTitle: TextLabel
local chipButtons: { TextButton } = {}
local current: Offer? = nil -- the open offer, nil when there's none
local counterPrice = 0

-- Your own plot's register, if you have a plot
local function getRegister(): BasePart?
	local plotId = player:GetAttribute("PlotId")
	local plots = workspace:FindFirstChild("Plots")
	local plot = if typeof(plotId) == "number" and plots then plots:FindFirstChild("Plot" .. plotId) else nil
	local register = if plot then plot:FindFirstChild("Register", true) else nil
	return if register and register:IsA("BasePart") then register else nil
end

local function isAtRegister(): boolean
	local register = getRegister()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return register ~= nil and root ~= nil and (root.Position - register.Position).Magnitude <= RegisterConfig.REACH
end

-- Middle-right on bigger screens; on phones below the cash row and left of the jump button
local function placeOfferPanel()
	local look = CustomerConfig.PANEL
	if UIKit.isPhone() then
		offerPanel.AnchorPoint = Vector2.new(1, 0)
		offerPanel.Position = UDim2.new(1, -look.phoneRight, 0, look.phoneTop)
	else
		offerPanel.AnchorPoint = Vector2.new(1, 0.5)
		offerPanel.Position = UDim2.new(1, -12, 0.5, look.topOffset)
	end
end

local function updateVisible()
	local here = isAtRegister()
	offerPanel.Visible = current ~= nil and here
	panel.Visible = checkoutOpen and here and current == nil
end

local function onUpdate(total: number?, remaining: number)
	checkoutOpen = total ~= nil
	updateVisible()
	if total == nil then
		return
	end
	if remaining > 0 then
		statusLabel.Text = string.format("Tap items on the counter\n%d left · $%.2f", remaining, total)
		chargeButton.Visible = false
	else
		statusLabel.Text = "All scanned!"
		chargeButton.Text = string.format("Charge $%.2f", total)
		chargeButton.Visible = true
	end
end

local function buildPanel(parent: Instance)
	panel = Instance.new("Frame")
	panel.Name = "Checkout"
	-- Middle-right, clear of the Build/Prices buttons and the mobile jump button
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -12, 0.5, 0)
	panel.Size = UDim2.fromOffset(200, 140)
	panel.BackgroundColor3 = UIKit.Colors.Panel
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = parent
	UIKit.corner(panel, 12)

	statusLabel = UIKit.label(panel, "", Enum.Font.GothamBold, 16, UIKit.Colors.Text)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center
	statusLabel.Position = UDim2.fromOffset(10, 8)
	statusLabel.Size = UDim2.new(1, -20, 0, 52)

	chargeButton = UIKit.button(panel, "", UIKit.Colors.Accent)
	chargeButton.Name = "Charge"
	chargeButton.AnchorPoint = Vector2.new(0.5, 1)
	chargeButton.Position = UDim2.new(0.5, 0, 1, -10)
	chargeButton.Size = UDim2.new(1, -20, 0, 56)
	chargeButton.Visible = false
	chargeButton.Activated:Connect(function()
		Remotes.Charge:FireServer()
	end)
end

-- Offer panel ---------------------------------------------------------------------------------------------------

local function cents(value: number): number
	return math.round(value * 100) / 100
end

local function money(value: number): string
	return string.format("$%.2f", value)
end

-- How they feel about `price`: a kid wants more, a bargain hunter less
local function moodFor(offer: Offer, price: number): string
	local edges = offer.edges
	if offer.kind == "kid" then
		return if price >= edges.sure - 1e-9 then "sure" elseif price >= edges.maybe - 1e-9 then "maybe" else "no"
	end
	return if price <= edges.sure + 1e-9 then "sure" elseif price <= edges.maybe + 1e-9 then "maybe" else "no"
end

local function setCounterPrice(price: number)
	local offer = current
	if not offer then
		return
	end
	counterPrice = math.clamp(cents(price), offer.range[1], offer.range[2])
	counterPriceLabel.Text = money(counterPrice)
	faceLabel.Text = CustomerConfig.FACES[moodFor(offer, counterPrice)]
end

-- The hint under the price: a kid who turned a counter down gives you one more go
local function hintFor(offer: Offer): string
	if offer.kind == "kid" and offer.triesLeft < CustomerConfig.OFFER.retries + 1 then
		return if offer.triesLeft == 1 then "They said no. One more try!" else ""
	end
	return ""
end

local function showView(counter: boolean)
	mainView.Visible = not counter
	counterView.Visible = counter
end

local function render(offer: Offer)
	local card = offer.card
	if offer.kind == "kid" and card then
		local info = Cards.ById[card.cardId]
		titleLabel.Text = "A kid wants to sell!"
		cardHolder.Visible = true
		CardFace.render(cardFace, cardStroke, info, card.foil, false, { level = 1, stars = BeastRules.START_STARS, grade = card.grade })
		nameLabel.Visible = true
		nameLabel.Text = `{info.name} · {info.rarity} · {BeastRules.describeGrade(card.grade)}`
		priceLabel.Text = `{money(offer.asking or 0)} (worth {money(offer.worth or 0)})`
		yesButton.Text = "Buy"
	else
		local total = offer.total or 0
		local off = if total > 0 then math.round((1 - (offer.offer or 0) / total) * 100) else 0
		titleLabel.Text = "Bargain hunter"
		cardHolder.Visible = false
		nameLabel.Visible = false
		priceLabel.Text = `Offers {money(offer.offer or 0)} for {money(total)} (-{off}%)`
		yesButton.Text = "Deal"
	end
	local chipNames = if offer.kind == "kid" then { "-20%", "-15%", "-10%", "Worth" } else { "-20%", "-15%", "-10%", "Full" }
	for index, chip in chipButtons do
		chip.Text = chipNames[index] or ""
	end
	counterTitle.Text = if offer.kind == "kid" then "Your offer" else "Your price"
	local hint = hintFor(offer)
	mainHint.Text = hint
	mainHint.Visible = hint ~= ""
	counterHint.Text = hint
	counterHint.Visible = hint ~= ""
end

local function onOffer(payload: unknown)
	if typeof(payload) ~= "table" then
		current = nil
		updateVisible()
		return
	end
	local offer = payload :: Offer
	local sameOffer = current ~= nil and (current :: Offer).id == offer.id
	current = offer
	placeOfferPanel()
	render(offer)
	if sameOffer and counterView.Visible then
		setCounterPrice(counterPrice) -- a turned-down counter: stay on it to try again
	else
		showView(false)
	end
	updateVisible()
end

local function send(action: string, price: number?)
	local offer = current
	if offer then
		Remotes.OfferAction:FireServer(offer.id, action, price)
	end
end

local function list(parent: Instance, gap: number, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
	return layout
end

local function holder(parent: Instance, order: number, height: number): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.LayoutOrder = order
	frame.Parent = parent
	return frame
end

local function text(parent: Instance, order: number, height: number, size: number, color: Color3): TextLabel
	local label = UIKit.label(parent, "", Enum.Font.GothamBold, size, color)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Size = UDim2.new(1, 0, 0, height)
	label.LayoutOrder = order
	return label
end

-- A row of equal buttons filling the width
local function buttonRow(parent: Instance, order: number, specs: { { text: string, color: Color3, onTap: () -> () } }): { TextButton }
	local look = CustomerConfig.PANEL
	local row = holder(parent, order, look.buttonHeight)
	list(row, look.gap, true)
	local inner = look.width - look.padding * 2
	local width = math.floor((inner - look.gap * (#specs - 1)) / #specs)
	local buttons = {}
	for index, spec in specs do
		local button = UIKit.button(row, spec.text, spec.color)
		button.Size = UDim2.fromOffset(width, look.buttonHeight)
		button.LayoutOrder = index
		button.TextSize = UIKit.textSize("body")
		button.Activated:Connect(spec.onTap)
		table.insert(buttons, button)
	end
	return buttons
end

local function view(parent: Instance, order: number): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	frame.Parent = parent
	list(frame, CustomerConfig.PANEL.gap)
	return frame
end

local function buildMainView(parent: Instance, colors: UIKit.Palette)
	local look = CustomerConfig.PANEL
	mainView = view(parent, 1)
	titleLabel = text(mainView, 1, 24, UIKit.textSize("name"), colors.ink)
	titleLabel.Font = Enum.Font.FredokaOne

	cardHolder = holder(mainView, 2, look.cardHeight)
	cardFace = Instance.new("Frame")
	cardFace.AnchorPoint = Vector2.new(0.5, 0)
	cardFace.Position = UDim2.fromScale(0.5, 0)
	cardFace.Size = UDim2.fromOffset(look.cardWidth, look.cardHeight)
	cardFace.Parent = cardHolder
	cardStroke = Instance.new("UIStroke")
	cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cardStroke.Parent = cardFace

	nameLabel = text(mainView, 3, 18, UIKit.textSize("small"), colors.inkSoft)
	priceLabel = text(mainView, 4, 22, UIKit.textSize("body"), colors.ink)
	mainHint = text(mainView, 5, 18, UIKit.textSize("small"), colors.bad)
	local buttons = buttonRow(mainView, 6, {
		{ text = "Buy", color = UIKit.Colors.Success, onTap = function()
			send("accept")
		end },
		{ text = "Counter", color = UIKit.Colors.Secondary, onTap = function()
			local offer = current
			if offer then
				-- Start from their price (a kid's asking, a bargain hunter's offer)
				setCounterPrice(if offer.kind == "kid" then offer.asking or offer.range[2] else offer.offer or offer.range[1])
				showView(true)
			end
		end },
		{ text = "No", color = UIKit.Colors.Danger, onTap = function()
			send("decline")
		end },
	})
	yesButton = buttons[1]
end

local function buildCounterView(parent: Instance, colors: UIKit.Palette)
	local look = CustomerConfig.PANEL
	counterView = view(parent, 2)
	counterView.Visible = false
	counterTitle = text(counterView, 1, 24, UIKit.textSize("name"), colors.ink)
	counterTitle.Font = Enum.Font.FredokaOne

	-- - $price +
	local stepper = holder(counterView, 2, look.buttonHeight)
	list(stepper, look.gap, true)
	local minus = UIKit.button(stepper, "-", UIKit.Colors.Secondary)
	minus.Size = UDim2.fromOffset(look.buttonHeight, look.buttonHeight)
	minus.LayoutOrder = 1
	counterPriceLabel = UIKit.label(stepper, "", Enum.Font.FredokaOne, UIKit.textSize("title"), colors.ink)
	counterPriceLabel.TextXAlignment = Enum.TextXAlignment.Center
	counterPriceLabel.Size = UDim2.fromOffset(look.width - look.padding * 2 - look.buttonHeight * 2 - look.gap * 2, look.buttonHeight)
	counterPriceLabel.LayoutOrder = 2
	local plus = UIKit.button(stepper, "+", UIKit.Colors.Secondary)
	plus.Size = UDim2.fromOffset(look.buttonHeight, look.buttonHeight)
	plus.LayoutOrder = 3
	minus.Activated:Connect(function()
		local offer = current
		if offer then
			setCounterPrice(counterPrice - offer.step)
		end
	end)
	plus.Activated:Connect(function()
		local offer = current
		if offer then
			setCounterPrice(counterPrice + offer.step)
		end
	end)

	-- Quick chips: under the card's worth (a kid) or the total (a bargain hunter)
	local chips = holder(counterView, 3, look.buttonHeight)
	list(chips, 4, true)
	local chipValues = CustomerConfig.OFFER.chips
	local chipWidth = math.floor((look.width - look.padding * 2 - 4 * (#chipValues - 1)) / #chipValues)
	for index, share in chipValues do
		local chip = UIKit.button(chips, "", UIKit.Colors.Accent)
		chip.Size = UDim2.fromOffset(chipWidth, look.buttonHeight)
		chip.LayoutOrder = index
		chip.TextSize = UIKit.textSize("small")
		chip.Activated:Connect(function()
			local offer = current
			if offer then
				local base = if offer.kind == "kid" then offer.worth or 0 else offer.total or 0
				setCounterPrice(base * (1 + share))
			end
		end)
		table.insert(chipButtons, chip)
	end

	faceLabel = text(counterView, 4, 24, UIKit.textSize("body"), colors.ink)
	counterHint = text(counterView, 5, 18, UIKit.textSize("small"), colors.bad)
	buttonRow(counterView, 6, {
		{ text = "Offer", color = UIKit.Colors.Success, onTap = function()
			send("counter", counterPrice)
		end },
		{ text = "Back", color = UIKit.Colors.Secondary, onTap = function()
			showView(false)
		end },
	})
end

local function buildOfferPanel(parent: Instance)
	local look = CustomerConfig.PANEL
	offerPanel = Instance.new("Frame")
	offerPanel.Name = "Offer"
	offerPanel.Size = UDim2.fromOffset(look.width, 200)
	offerPanel.ZIndex = 10 -- over the HUD tiles it can touch on small phones
	offerPanel.Visible = false
	offerPanel.Parent = parent
	UIKit.creamWindow(offerPanel)
	local colors = UIKit.colorsFor(offerPanel)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = offerPanel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, look.padding)
	padding.PaddingRight = UDim.new(0, look.padding)
	padding.PaddingTop = UDim.new(0, look.padding)
	padding.PaddingBottom = UDim.new(0, look.padding)
	padding.Parent = content
	local layout = list(content, 0)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	buildMainView(content, colors)
	buildCounterView(content, colors)
	-- The window fits whichever view is showing
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		offerPanel.Size = UDim2.fromOffset(look.width, layout.AbsoluteContentSize.Y + look.padding * 2)
	end)
end

function RegisterController.Start()
	local screen = UIController.GetScreenGui()
	buildPanel(screen)
	buildOfferPanel(screen)
	Remotes.CheckoutUpdate.OnClientEvent:Connect(onUpdate)
	Remotes.OfferUpdate.OnClientEvent:Connect(onOffer)
	task.spawn(function()
		while true do
			task.wait(NEAR_CHECK_SECONDS)
			if checkoutOpen or current then
				updateVisible()
			end
		end
	end)
end

return RegisterController
