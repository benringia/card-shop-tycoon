--!strict
-- The register's offer panel and its bell (checking out happens on the register itself in first person:
-- RegisterStationController). The offer panel shows while you're at your register and a kid offers you their pull or
-- a bargain hunter haggles (OfferService, spec
-- 2026-11-06-customers-design, mockup option A): Buy / Deal, Counter, No, and the counter's view: - / + steps, quick
-- chips, your price and their face (from the server's edges, so the exact price they'd take never reaches here).
-- Its words are Util/OfferWords' (owner 2026-11-19: "improve bargainers offer UI to be immersive and easily
-- understandable"): the customer's ask in a speech bubble, your price beside theirs, what the difference means, a big
-- Deal button with the price on it, and what No does.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CustomerConfig = require(Config:WaitForChild("Customers"))
local BellConfig = require(Config:WaitForChild("RegisterBell"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local OfferWords = require(Shared:WaitForChild("Util"):WaitForChild("OfferWords"))
local RegisterBell = require(Shared:WaitForChild("Util"):WaitForChild("RegisterBell"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local RegisterSpot = require(ClientUtil:WaitForChild("RegisterSpot"))
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

local offerPanel: Frame
local mainView: Frame
local counterView: Frame
local titleLabel: TextLabel
local cardHolder: Frame
local cardFace: Frame
local cardStroke: UIStroke
local nameLabel: TextLabel
local quoteLabel: TextLabel
local quoteHolder: Frame
local leftLabel: TextLabel
local leftValue: TextLabel
local rightLabel: TextLabel
local rightValue: TextLabel
local deltaLabel: TextLabel
local footLabel: TextLabel
local mainHint: TextLabel
local yesButton: TextButton
local counterButton: TextButton
local noButton: TextButton
local sendButton: TextButton
local palette: UIKit.Palette
local counterPriceLabel: TextLabel
local faceLabel: TextLabel
local counterHint: TextLabel
local counterTitle: TextLabel
local chipButtons: { TextButton } = {}
local current: Offer? = nil -- the open offer, nil when there's none
local counterPrice = 0

-- Middle-right on bigger screens; on phones below the cash row and left of the jump button; on a short window at the
-- top right, clear of the cash in the corner
local function placeOfferPanel()
	local look = CustomerConfig.PANEL
	local screen = offerPanel.Parent
	local short = screen and screen:IsA("LayerCollector") and screen.AbsoluteSize.Y < look.shortScreen
	if UIKit.isPhone() then
		offerPanel.AnchorPoint = Vector2.new(1, 0)
		offerPanel.Position = UDim2.new(1, -look.phoneRight, 0, look.phoneTop)
	elseif short then
		offerPanel.AnchorPoint = Vector2.new(1, 0)
		offerPanel.Position = UDim2.new(1, -12, 0, look.phoneTop)
	else
		offerPanel.AnchorPoint = Vector2.new(1, 0.5)
		offerPanel.Position = UDim2.new(1, -12, 0.5, look.topOffset)
	end
end

local function updateVisible()
	local here = RegisterSpot.at(player)
	offerPanel.Visible = current ~= nil and here
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

-- The offer as Util/OfferWords reads it
local function wordsOf(offer: Offer): OfferWords.Offer
	local card = offer.card
	local info = if card then Cards.ById[card.cardId] else nil
	return {
		kind = offer.kind,
		cardName = if info then info.name else nil,
		asking = offer.asking,
		worth = offer.worth,
		offer = offer.offer,
		total = offer.total,
		triesLeft = offer.triesLeft,
	}
end

local function setCounterPrice(price: number)
	local offer = current
	if not offer then
		return
	end
	counterPrice = math.clamp(cents(price), offer.range[1], offer.range[2])
	counterPriceLabel.Text = money(counterPrice)
	faceLabel.Text = CustomerConfig.FACES[moodFor(offer, counterPrice)]
	-- the button says the price it sends; the hint what a wrong one costs (a bargain hunter: one try)
	local words = OfferWords.counter(CustomerConfig.OFFER_WORDS, wordsOf(offer), counterPrice, CustomerConfig.OFFER.retries)
	counterTitle.Text = words.title
	sendButton.Text = words.send
	counterHint.Text = words.hint
	counterHint.TextColor3 = if words.warn then palette.bad else palette.inkSoft
end

local function showView(counter: boolean)
	mainView.Visible = not counter
	counterView.Visible = counter
end

local function render(offer: Offer)
	local card = offer.card
	local words = OfferWords.main(CustomerConfig.OFFER_WORDS, wordsOf(offer))
	if offer.kind == "kid" and card then
		local info = Cards.ById[card.cardId]
		cardHolder.Visible = true
		CardFace.render(cardFace, cardStroke, info, card.foil, false, { level = 1, stars = BeastRules.START_STARS, grade = card.grade })
		nameLabel.Visible = true
		nameLabel.Text = `{info.name} · {info.rarity} · {BeastRules.describeGrade(card.grade)}`
	else
		cardHolder.Visible = false
		nameLabel.Visible = false
	end
	-- a phone's short screen: a kid's panel (it has their card too) drops the lines the card and the buttons already say
	local compact = UIKit.isPhone() and offer.kind == "kid"
	quoteHolder.Visible = not compact
	footLabel.Visible = not compact
	nameLabel.Visible = nameLabel.Visible and not compact
	titleLabel.Text = words.title
	quoteLabel.Text = words.quote
	leftLabel.Text = words.leftLabel
	leftValue.Text = words.leftValue
	rightLabel.Text = words.rightLabel
	rightValue.Text = words.rightValue
	deltaLabel.Text = words.delta
	deltaLabel.TextColor3 = if words.tone == "good" then palette.good elseif words.tone == "bad" then palette.bad else palette.inkSoft
	yesButton.Text = words.yes
	counterButton.Text = words.counter
	noButton.Text = words.no
	footLabel.Text = words.foot
	local chipNames = if offer.kind == "kid" then { "-20%", "-15%", "-10%", "Worth" } else { "-20%", "-15%", "-10%", "Full" }
	for index, chip in chipButtons do
		chip.Text = chipNames[index] or ""
	end
	-- a kid who turned a counter down gives one more go: said on the first view too
	local refused = offer.kind == "kid" and offer.triesLeft < CustomerConfig.OFFER.retries + 1 and offer.triesLeft == 1
	mainHint.Text = if refused then CustomerConfig.OFFER_WORDS.kid.lastTry else ""
	mainHint.Visible = refused
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

	-- what they say, in a speech bubble (a white row with a little tail up toward the title)
	local quote = holder(mainView, 4, look.quoteHeight)
	quoteHolder = quote
	quote.BackgroundTransparency = 0
	quote.BackgroundColor3 = colors.row
	UIKit.corner(quote, 14)
	local quoteEdge = Instance.new("UIStroke")
	quoteEdge.Color = colors.rowEdge
	quoteEdge.Thickness = 2
	quoteEdge.Parent = quote
	quoteLabel = UIKit.label(quote, "", Enum.Font.FredokaOne, UIKit.textSize("name"), colors.ink)
	quoteLabel.TextXAlignment = Enum.TextXAlignment.Center
	quoteLabel.Size = UDim2.new(1, -12, 1, 0)
	quoteLabel.Position = UDim2.fromOffset(6, 0)
	quoteLabel.TextScaled = true
	local quoteLimit = Instance.new("UITextSizeConstraint")
	quoteLimit.MaxTextSize = UIKit.textSize("name")
	quoteLimit.MinTextSize = 11
	quoteLimit.Parent = quoteLabel

	-- your price beside theirs: two boxes, theirs the one that stands out
	local compare = holder(mainView, 5, look.boxHeight)
	list(compare, look.gap, true)
	local boxWidth = math.floor((look.width - look.padding * 2 - look.gap) / 2)
	local function box(order: number, strong: boolean): (TextLabel, TextLabel)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(boxWidth, look.boxHeight)
		frame.BackgroundColor3 = colors.row
		frame.LayoutOrder = order
		frame.Parent = compare
		UIKit.corner(frame, 12)
		local edge = Instance.new("UIStroke")
		edge.Color = if strong then colors.power else colors.rowEdge
		edge.Thickness = if strong then 3 else 2
		edge.Parent = frame
		local caption = UIKit.label(frame, "", Enum.Font.GothamBold, UIKit.textSize("small"), colors.inkSoft)
		caption.TextXAlignment = Enum.TextXAlignment.Center
		caption.Size = UDim2.new(1, 0, 0, 18)
		caption.Position = UDim2.fromOffset(0, 5)
		local value = UIKit.label(frame, "", Enum.Font.FredokaOne, UIKit.textSize("title"), colors.ink)
		value.TextXAlignment = Enum.TextXAlignment.Center
		value.Size = UDim2.new(1, 0, 0, 30)
		value.Position = UDim2.fromOffset(0, 23)
		return caption, value
	end
	leftLabel, leftValue = box(1, false)
	rightLabel, rightValue = box(2, true)

	deltaLabel = text(mainView, 6, 18, UIKit.textSize("small"), colors.bad)
	mainHint = text(mainView, 7, 18, UIKit.textSize("small"), colors.bad)
	-- the yes on its own row, as wide as the panel, its price on it
	yesButton = buttonRow(mainView, 8, {
		{ text = "", color = UIKit.Colors.Success, onTap = function()
			send("accept")
		end },
	})[1]
	yesButton.TextSize = UIKit.textSize("name") -- the one to read first
	local buttons = buttonRow(mainView, 9, {
		{ text = "", color = UIKit.Colors.Secondary, onTap = function()
			local offer = current
			if offer then
				-- Start from their price (a kid's asking, a bargain hunter's offer)
				setCounterPrice(if offer.kind == "kid" then offer.asking or offer.range[2] else offer.offer or offer.range[1])
				showView(true)
			end
		end },
		{ text = "", color = UIKit.Colors.Danger, onTap = function()
			send("decline")
		end },
	})
	counterButton, noButton = buttons[1], buttons[2]
	-- what No does, so nobody fears pressing it
	footLabel = text(mainView, 10, 30, UIKit.textSize("small"), colors.inkSoft)
	footLabel.TextWrapped = true
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
	sendButton = buttonRow(counterView, 6, {
		{ text = "", color = UIKit.Colors.Success, onTap = function()
			send("counter", counterPrice)
		end },
	})[1]
	sendButton.TextSize = UIKit.textSize("name")
	buttonRow(counterView, 7, {
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
	palette = colors

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

-- The checkout or an offer is up at the right of the screen (the weapon switch steps aside meanwhile)
function RegisterController.IsShowing(): boolean
	return offerPanel ~= nil and offerPanel.Visible
end

-- A customer waits at your register with nobody there (owner 2026-11-12): the desk bell, then the note
local function onBell(ring: unknown)
	local look = BellConfig.sound
	local bell = Instance.new("Sound")
	bell.SoundId = look.id
	bell.Volume = look.volume
	bell.Parent = SoundService
	bell.Ended:Once(function()
		bell:Destroy()
	end)
	bell:Play()
	if RegisterBell.says(if typeof(ring) == "number" then ring else 1, BellConfig) then
		UIController.Notify(BellConfig.text, false)
	end
end

function RegisterController.Start()
	Remotes.RegisterBell.OnClientEvent:Connect(onBell)
	local screen = UIController.GetScreenGui()
	buildOfferPanel(screen)
	Remotes.OfferUpdate.OnClientEvent:Connect(onOffer)
	task.spawn(function()
		while true do
			task.wait(NEAR_CHECK_SECONDS)
			if current then
				updateVisible()
			end
		end
	end)
end

return RegisterController
