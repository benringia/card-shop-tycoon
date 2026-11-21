--!strict
-- Managing your own card case (Glass Showcase or Collector Case): the case itself (owner 2026-11-21: "in glass
-- cases make sure grades are noticeable too. redesign glass cases window", his pick A of three mockups; "also do the
-- same for collector case"; words and sizes in Util/CaseWindow). Every slot is a big card with its grade across it
-- in the grade's colour, a yellow price tag under it and two words on how it sells; an empty slot is a "+". One bar
-- under them is for the tapped card: its name and grade, what it is worth, - price +, Done for a card that still
-- waits for its price, and Take out. Hover a card with a mouse for its stats. Empty slots open the card picker
-- (with rarity filters). Opened from the case's Edit menu. The server checks every change; this reads the case's
-- card parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Pricing = require(Config:WaitForChild("Pricing"))
local Rarities = require(Config:WaitForChild("Rarities"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local Shelves = require(Config:WaitForChild("Shelves"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local PriceRules = require(Shared:WaitForChild("Util"):WaitForChild("PriceRules"))
local PriceTaps = require(Shared:WaitForChild("Util"):WaitForChild("PriceTaps"))
local CaseWindow = require(Shared:WaitForChild("Util"):WaitForChild("CaseWindow"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local ElementBadge = require(ClientUtil:WaitForChild("ElementBadge"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local Beasts = require(Config:WaitForChild("Beasts"))
local DefeatRules = require(Shared:WaitForChild("Util"):WaitForChild("DefeatRules"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type Card = typeof(Cards.List[1])
-- "All", "Foil", or a rarity name (exactly that rarity)
type PickerFilter = string

local ALL_FILTER = "All"
local FOIL_FILTER = "Foil"
local FRONTIER_FILTER = "Frontier"
local FILTER_CHIP_WIDTH = 96
local PICKER_TILE_SIZE = Vector2.new(92, 168) -- card face on top, grade/count and value underneath
local PICKER_FACE_HEIGHT = 118
local PANEL_MAX_SIZE = Vector2.new(820, 520)
local PICKER_LIST_SCALE = 0.55 -- the card picker's list's share of its width; its card sheet gets the rest
local DETAIL_FACE_SIZE = Vector2.new(120, 171)
local TOOLTIP_WIDTH = 240
local TOP = 84 -- under the title and its line
local EDGE = 12
local DESK_HEIGHT = 92 -- the bar under the cards: the tapped card's price
local DESK_WIDTH = 772 -- its pieces fit this; a narrower window scales them down
local STEP_SIZE = 48 -- the - and + buttons (tap targets)
local PRICE_WIDTH = 132
-- A phone (owner 2026-11-21, the night's device check: on a 705 x 338 phone the bar under the cards left them a
-- 40 px strip): the window takes nearly the whole screen, its line under the title goes, and the tapped card's bar
-- stands beside the cards as a column (SIDE wide), its pieces stacked
local SIDE = { width = 204, inner = Vector2.new(196, 184), price = 84 }
-- The window is a lit display case (owner 2026-11-21, an hour after the flat first build: "make glass cas/collection
-- cases window more immersive. right now it's flat"): a dark stage with a trim and a bed in the case's own colours
-- (the Collector Case's navy and gold, the Glass Showcase's plum and silver: Config/Shelves propColors, Town.CASE_LOOK),
-- and on it every card floats over a glowing pad in a light beam of its rarity colour, like the cards in the shop
local STAGE = {
	CollectorCase = { top = Color3.fromRGB(18, 22, 48), bottom = Color3.fromRGB(34, 52, 124), trim = Color3.fromRGB(212, 175, 85), bed = Color3.fromRGB(40, 70, 170) },
	default = { top = Color3.fromRGB(26, 20, 54), bottom = Color3.fromRGB(72, 56, 128), trim = Color3.fromRGB(214, 218, 228), bed = Color3.fromRGB(104, 90, 168) },
}
local STAGE_TEXT = Color3.fromRGB(236, 228, 255)
local STAGE_GOOD = Color3.fromRGB(126, 232, 156) -- how a card sells, bright enough for the dark stage
local STAGE_FAIR = Color3.fromRGB(255, 204, 96)
local STAGE_BAD = Color3.fromRGB(255, 128, 140)
local PAD_RING = Color3.fromRGB(214, 218, 228) -- the pads' metal ring (Showcase SPIN.RING_COLOR)
local BOB = { pixels = 4, seconds = 1.3 } -- a card's float over its pad
local HEADROOM = 12 -- the beam shows this far over a card
local TAG_COLOR = Color3.fromRGB(255, 214, 50) -- the yellow price tag (the shelves': Town.SHELF_STOCK.TAG)
local TAG_EDGE = Color3.fromRGB(220, 160, 10)
local TAG_TEXT = Color3.fromRGB(45, 25, 10)

local SEND_DELAY = 0.4 -- price taps are sent together once tapping stops
local KIND_DESCRIPTIONS = {
	CustomerCards = "Customers may buy these at your price.",
	PlayerCards = "Other players can buy these at your price.",
}

local ShowcaseController = {}

local panel: Frame
local palette: UIKit.Palette -- the cream window's colours (UIKit.colorsFor), set when it's built
local list: ScrollingFrame
local grid: UIGridLayout -- the slots' cards in `list`
local stage: Frame -- the lit case behind them
local desk: Frame -- the bar under the cards
local tooltip: Frame
local tooltipText: TextLabel
local selectedSlot: number? = nil -- the tapped card: the bar under the cards is its
local titleLabel: TextLabel
local subtitle: TextLabel
local picker: Frame
local pickerList: ScrollingFrame
local pickerTitle: TextLabel
local pickerPane: ScrollingFrame
local pickerSelectedKey: string? = nil
local filterButtons: { [PickerFilter]: TextButton } = {}
local pickerFilter: PickerFilter = ALL_FILTER

local casePart: BasePart? = nil
local caseConnections: { RBXScriptConnection } = {}
-- slot → the price tapped and sent, shown until the card's own price says the same (Util/PriceTaps)
local taps = PriceTaps.new(Pricing.ECHO_SECONDS)
local sendToken = 0
local pickerSlot: number? = nil
local justListed: number? = nil -- the slot a card was just put in: it is the tapped card as it arrives
-- Where each price shows, so a price tap changes the words in place (owner 2026-11-18, a phone: the window rebuilt on
-- every tap scrolled back up): each card's price tag and its words, and the bar's worth line and price
local rowPrices: { [number]: { price: TextLabel, tag: TextLabel } } = {}
local detailPrice: { slot: number, info: TextLabel, editor: GuiObject? }? = nil

local function clearChildren(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function getCardPart(slot: number): BasePart?
	local part = casePart
	if not part then
		return nil
	end
	for _, child in part:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("Slot") == slot then
			return child
		end
	end
	return nil
end

-- A card face drawn into a new frame (the same look as the binder and pack reveal)
local function makeCardFace(parent: Instance, card: Card, foil: boolean, showValue: boolean, growth: CardFace.Growth?): Frame
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.Parent = parent
	UIKit.corner(face, 8)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = face
	CardFace.render(face, stroke, card, foil, showValue, growth)
	return face
end

-- A displayed card's level, stars and grade (1, 0, C for a plain Grade C copy)
local function getGrowthFromPart(part: BasePart): (number, number, string)
	local level, stars, grade = part:GetAttribute("Level"), part:GetAttribute("Stars"), part:GetAttribute("Grade")
	return if typeof(level) == "number" then level else 1,
		if typeof(stars) == "number" then stars else BeastRules.START_STARS,
		if BeastRules.isGrade(grade) then grade :: string else BeastRules.DEFAULT_GRADE
end

-- All, every rarity from Common up (read from the config, so new tiers show up here), then Foil
local function getPickerFilters(): { PickerFilter }
	local rarities: { string } = {}
	for name in Rarities.Tiers do
		table.insert(rarities, name)
	end
	table.sort(rarities, function(a, b)
		return Rarities.Tiers[a].order < Rarities.Tiers[b].order
	end)
	local filters: { PickerFilter } = { ALL_FILTER, FRONTIER_FILTER }
	for _, name in rarities do
		table.insert(filters, name)
	end
	table.insert(filters, FOIL_FILTER)
	return filters
end

local function passesFilter(card: Card, foil: boolean): boolean
	if pickerFilter == ALL_FILTER then
		return true
	elseif pickerFilter == FOIL_FILTER then
		return foil
	elseif pickerFilter == FRONTIER_FILTER then
		return card.set == "Frontier"
	end
	return card.rarity == pickerFilter
end

local STEP_BUTTON_COLOR = UIKit.Colors.Secondary -- other choices (sky in the cotton candy look)

local function flush(token: number)
	local part = casePart
	local tapped = if token == sendToken and part then PriceTaps.flush(taps, os.clock()) else nil
	if not tapped or not part then
		return
	end
	local changes = {}
	for slot, price in tapped do
		table.insert(changes, { slot = slot, price = price })
	end
	Remotes.SetCardPrice:FireServer(part:GetAttribute("ShelfUid"), changes)
end

local render: () -> ()
local showPrice: (slot: number) -> ()

local function queuePrice(slot: number, price: number)
	PriceTaps.tap(taps, slot, price)
	showPrice(slot)
	sendToken += 1
	local token = sendToken
	task.delay(SEND_DELAY, flush, token)
end

-- Sends the price taps not sent yet, then puts the case's new cards that wait for their price on sale: one (`slot`,
-- Done) or all of them (the window closed). Server Util/ListingHold (owner 2026-11-17: a new card was bought at
-- 100% market before its price was set)
local function releaseListings(slot: number?)
	local part = casePart
	if not part then
		return
	end
	sendToken += 1
	flush(sendToken)
	Remotes.ReleaseListings:FireServer(part:GetAttribute("ShelfUid"), slot)
end

-- One copy's growth, so price maths use its real value
type CopyGrowth = { level: number, stars: number, grade: string }

local function nudge(slot: number, card: Card, foil: boolean, growth: CopyGrowth, current: number, direction: number)
	local step = CardRules.getPriceStep(card, foil, growth.level, growth.stars, growth.grade)
	queuePrice(slot, CardRules.clampPrice(current + direction * step, card, foil, growth.level, growth.stars, growth.grade))
end

-- Accepts "275", "$275.50" or "1,200"; anything else puts the current price back.
-- Clamped here for display; the server clamps again.
local function setTypedPrice(slot: number, card: Card, foil: boolean, growth: CopyGrowth, box: TextBox)
	local cleaned = string.gsub(box.Text, "[%$,%s]", "")
	local typed = tonumber(cleaned)
	if not typed or typed ~= typed then
		showPrice(slot)
		return
	end
	queuePrice(slot, CardRules.clampPrice(typed, card, foil, growth.level, growth.stars, growth.grade))
end

-- Everything about one listed card, read from its part
type Listing = {
	slot: number,
	card: Card,
	foil: boolean,
	growth: CopyGrowth,
	price: number,
	market: number,
	stats: { hp: number, atk: number, spd: number },
	power: number,
	held: boolean, -- new, waiting for its price: nobody buys it yet (server Util/ListingHold)
}

local function readListing(slot: number, cardPart: BasePart): Listing?
	local card = Cards.ById[cardPart:GetAttribute("CardId") :: string]
	if not card then
		return nil
	end
	local foil = cardPart:GetAttribute("Foil") == true
	local serverPrice = cardPart:GetAttribute("Price")
	local level, stars, grade = getGrowthFromPart(cardPart)
	return {
		slot = slot,
		card = card,
		foil = foil,
		growth = { level = level, stars = stars, grade = grade },
		price = PriceTaps.shown(taps, slot, if typeof(serverPrice) == "number" then serverPrice else 0, os.clock()),
		market = CardRules.getMarketValue(card, foil, level, stars, grade),
		stats = BeastRules.getStats(card, foil, level, stars, grade),
		power = BeastRules.getPower(card, foil, level, stars, grade),
		held = cardPart:GetAttribute("PricingHold") == true,
	}
end

local function getMarketRatio(listing: Listing): number
	return if listing.market > 0 then listing.price / listing.market else math.huge
end

-- A card's words under its price tag and their colour (CaseWindow.sells): in a Glass Showcase how many customers buy
-- at this price ("Always buy", "33% buy", "Won't buy"), which falls with every step up like a product's (owner
-- 2026-11-20: "also do the same with glass prices"; PriceRules.getTag); in a Collector Case, where players buy, the
-- price against what the card is worth; "Set its price" while a new card waits
local function sellWords(listing: Listing, kind: string): (string, Color3)
	local tag = if kind == "CustomerCards" then PriceRules.getTag(listing.price, listing.market) else ""
	local text, tone = CaseWindow.sells(kind, tag, getMarketRatio(listing), listing.held)
	local color = if tone == "good" then STAGE_GOOD elseif tone == "fair" then STAGE_FAIR elseif tone == "bad" then STAGE_BAD else TAG_COLOR
	return text, color
end

local function describeGrowth(listing: Listing): string
	return `{BeastRules.describeGrade(listing.growth.grade)} · {BeastRules.describeGrowth(listing.growth.level, listing.growth.stars)}`
end

-- The full details: the tooltip's words
local function describeDetails(listing: Listing, kind: string): string
	local stats = listing.stats
	local lines = {
		`{listing.card.name}{if listing.foil then " (FOIL)" else ""}`,
		`{listing.card.rarity} · {ElementBadge.name(listing.card.element)} · #{listing.card.number}`,
		describeGrowth(listing),
		`Power {listing.power} · HP {stats.hp}  ATK {stats.atk}  SPD {stats.spd}`,
		`Worth {CaseWindow.money(listing.market)} · asking {math.round(getMarketRatio(listing) * 100)}%`,
	}
	if kind == "CustomerCards" then
		local band = PriceRules.getBand(listing.price, listing.market)
		-- past the first band, how many buy at this price too (it slides inside a band: PriceRules.getChance)
		local first = band == Pricing.BUY_BANDS[1]
		local share = math.max(1, math.round(PriceRules.getChance(listing.price, listing.market) * 100))
		table.insert(lines, `Customers: {if not band then Pricing.NEVER_LABEL elseif first then band.label else `{band.label} ({share}%)`}`)
	end
	return table.concat(lines, "\n")
end

-- Tooltip (mouse only) -------------------------------------------------------------------------------

local function showTooltip(row: GuiObject, listing: Listing, kind: string)
	-- Cards under the open card picker still get mouse events; no tooltip through it
	if not UserInputService.MouseEnabled or picker.Visible then
		return
	end
	tooltipText.Text = describeDetails(listing, kind)
	-- Just right of the card, kept on screen
	local screen = (tooltip.Parent :: GuiObject?)
	local origin = if screen and screen:IsA("GuiBase2d") then (screen :: any).AbsolutePosition else Vector2.zero
	local screenSize = if screen and screen:IsA("GuiBase2d") then (screen :: any).AbsoluteSize else Vector2.new(1920, 1080)
	local x = row.AbsolutePosition.X - origin.X + row.AbsoluteSize.X + 8
	local y = row.AbsolutePosition.Y - origin.Y
	tooltip.Position = UDim2.fromOffset(
		math.clamp(x, 0, math.max(0, screenSize.X - TOOLTIP_WIDTH)),
		math.clamp(y, 0, math.max(0, screenSize.Y - tooltip.AbsoluteSize.Y))
	)
	tooltip.Visible = true
end

local function hideTooltip()
	tooltip.Visible = false
end

-- The case's slots ---------------------------------------------------------------------------------------

local openPicker: (slot: number) -> ()
type Tile = { w: number, face: number, h: number }

-- The grade's colour (Config/CardDesign GRADE_COLORS)
local function gradeColor(grade: string): Color3
	return CardDesign.GRADE_COLORS[grade] or CardDesign.GRADE_COLORS.C
end

-- The grade as a pill in its colour, white-edged: across a card ("GRADE S") or beside its name in the bar
local function gradePill(parent: Instance, text: string, grade: string, textSize: number): TextLabel
	local pill = Instance.new("TextLabel")
	pill.Name = "Grade"
	pill.BackgroundColor3 = gradeColor(grade)
	pill.Font = Enum.Font.FredokaOne
	pill.TextSize = textSize
	pill.TextColor3 = Color3.new(1, 1, 1)
	pill.Text = text
	pill.Parent = parent
	UIKit.corner(pill, 999)
	UIKit.outline(pill, Color3.new(1, 1, 1), 2)
	return pill
end

-- A slot's light: a glowing pad with its metal ring under where the card floats, and a beam rising from it
-- (`color`: the card's rarity colour; an empty slot's is dim)
local function slotLight(tile: Instance, size: Tile, cardWidth: number, color: Color3, strength: number)
	local beam = Instance.new("Frame")
	beam.Name = "Beam"
	beam.AnchorPoint = Vector2.new(0.5, 1)
	beam.Position = UDim2.fromOffset(size.w / 2, size.face - 6)
	beam.Size = UDim2.fromOffset(cardWidth + 14, size.face - 6)
	beam.BackgroundColor3 = color
	beam.BorderSizePixel = 0
	beam.Parent = tile
	UIKit.corner(beam, 10)
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 1 - 0.3 * strength),
		NumberSequenceKeypoint.new(1, 1 - 0.62 * strength),
	})
	fade.Parent = beam
	local pad = Instance.new("Frame")
	pad.Name = "Pad"
	pad.AnchorPoint = Vector2.new(0.5, 0.5)
	pad.Position = UDim2.fromOffset(size.w / 2, size.face - 7)
	pad.Size = UDim2.fromOffset(math.floor(cardWidth * 0.92), 14)
	pad.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35 * strength)
	pad.BackgroundTransparency = 1 - 0.85 * strength
	pad.Parent = tile
	UIKit.corner(pad, 999)
	UIKit.outline(pad, PAD_RING, 2).Transparency = 1 - 0.9 * strength
end

-- One slot's card: floating in its beam over its pad, its grade across its foot, the yellow price tag under it, then
-- how it sells
local function buildCardTile(listing: Listing, kind: string, size: Tile)
	local selected = listing.slot == selectedSlot
	local tile = Instance.new("TextButton")
	tile.Name = `Slot{listing.slot}`
	tile.LayoutOrder = listing.slot
	tile.BackgroundTransparency = 1
	tile.Text = ""
	tile.AutoButtonColor = false
	tile.Parent = list
	-- the card, a little smaller than its slot: the beam shows over and beside it
	local cardHeight = math.min(size.face - HEADROOM - 12, math.floor((size.w - 14) / CaseWindow.LOOK.shape))
	local cardWidth = math.floor(cardHeight * CaseWindow.LOOK.shape)
	local tier = Rarities.Tiers[listing.card.rarity]
	slotLight(tile, size, cardWidth, if tier then tier.color else PAD_RING, if selected then 1 else 0.8)
	local rest = HEADROOM + (if selected then -4 else 0) -- the tapped card floats a little higher
	local holder = Instance.new("Frame")
	holder.Name = "Card"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.fromOffset(size.w / 2, rest)
	holder.Size = UDim2.fromOffset(cardWidth, cardHeight)
	holder.BackgroundTransparency = 1
	holder.Parent = tile
	makeCardFace(holder, listing.card, listing.foil, false, listing.growth)
	if selected then
		-- the tapped card: a gold ring round it
		local ring = Instance.new("Frame")
		ring.Name = "Ring"
		ring.Size = UDim2.fromScale(1, 1)
		ring.BackgroundTransparency = 1
		ring.ZIndex = holder.ZIndex + 5
		ring.Parent = holder
		UIKit.corner(ring, 8)
		UIKit.outline(ring, UIKit.Colors.Accent, 4)
	end
	local grade = listing.growth.grade
	local banner = gradePill(holder, CaseWindow.gradeWords(grade, cardWidth), grade, if cardWidth >= 96 then 14 elseif cardWidth >= CaseWindow.LOOK.wordsFrom then 11 else 13)
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.new(0.5, 0, 1, -16)
	banner.Size = UDim2.fromOffset(math.floor(cardWidth * 0.86), if cardWidth >= 96 then 24 else 20)
	banner.ZIndex = holder.ZIndex + 6
	if grade == "S" then
		-- the best grade shines: its banner's edge pulses gold
		local edge = banner:FindFirstChildOfClass("UIStroke")
		if edge then
			edge.Color = Color3.fromRGB(255, 244, 190)
			TweenService:Create(edge, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 4 }):Play()
		end
	end
	-- it floats: up and down over its pad, each slot a little out of step with the next
	task.delay((listing.slot % 4) * 0.22, function()
		if holder.Parent then
			TweenService:Create(holder, TweenInfo.new(BOB.seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Position = UDim2.fromOffset(size.w / 2, rest - BOB.pixels),
			}):Play()
		end
	end)

	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.AnchorPoint = Vector2.new(0.5, 0)
	price.Position = UDim2.fromOffset(size.w / 2, size.face + 6)
	price.Size = UDim2.fromOffset(size.w - 8, 24)
	price.BackgroundColor3 = TAG_COLOR
	price.Font = Enum.Font.FredokaOne
	price.TextSize = 16
	price.TextColor3 = TAG_TEXT
	price.Text = CaseWindow.money(listing.price)
	price.Parent = tile
	UIKit.corner(price, 7)
	UIKit.outline(price, TAG_EDGE, 2)
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 16
	fit.MinTextSize = 9
	fit.Parent = price
	price.TextScaled = true
	local words, color = sellWords(listing, kind)
	local tag = UIKit.label(tile, words, Enum.Font.FredokaOne, 12, color)
	tag.Name = "Sells"
	tag.Position = UDim2.fromOffset(0, size.face + 33)
	tag.Size = UDim2.fromOffset(size.w, 16)
	tag.TextXAlignment = Enum.TextXAlignment.Center
	tag.TextWrapped = false
	rowPrices[listing.slot] = { price = price, tag = tag }

	tile.Activated:Connect(function()
		selectedSlot = listing.slot
		render()
	end)
	tile.MouseEnter:Connect(function()
		showTooltip(tile, listing, kind)
	end)
	tile.MouseLeave:Connect(hideTooltip)
end

-- An empty slot: a dim pad waiting for a card, a + over it (a tap opens the card picker)
local function buildEmptyTile(slot: number, size: Tile)
	local tile = Instance.new("TextButton")
	tile.Name = `Slot{slot}`
	tile.LayoutOrder = slot
	tile.BackgroundTransparency = 1
	tile.Text = ""
	tile.AutoButtonColor = false
	tile.Parent = list
	local cardHeight = math.min(size.face - HEADROOM - 12, math.floor((size.w - 14) / CaseWindow.LOOK.shape))
	local cardWidth = math.floor(cardHeight * CaseWindow.LOOK.shape)
	slotLight(tile, size, cardWidth, STAGE_TEXT, 0.2)
	local plus = UIKit.label(tile, "+", Enum.Font.FredokaOne, 40, STAGE_TEXT)
	plus.Name = "Plus"
	plus.AnchorPoint = Vector2.new(0.5, 0.5)
	plus.Position = UDim2.fromOffset(size.w / 2, size.face * 0.42)
	plus.Size = UDim2.fromOffset(44, 44)
	plus.TextXAlignment = Enum.TextXAlignment.Center
	plus.TextTransparency = 0.25
	local words = UIKit.label(tile, "Add card", Enum.Font.FredokaOne, 13, STAGE_TEXT)
	words.AnchorPoint = Vector2.new(0.5, 0)
	words.Position = UDim2.fromOffset(size.w / 2, size.face * 0.42 + 22)
	words.Size = UDim2.fromOffset(size.w, 18)
	words.TextXAlignment = Enum.TextXAlignment.Center
	words.TextTransparency = 0.25
	tile.Activated:Connect(function()
		openPicker(slot)
	end)
end

-- The bar under the cards ---------------------------------------------------------------------------------

-- The tapped card: its name and grade, what it is worth, - price + (a typed price on a Collector Case), Done while it
-- waits for its price, Take out
local function renderDesk(listings: { [number]: Listing }, kind: string, isEmpty: boolean)
	clearChildren(desk)
	detailPrice = nil
	-- its pieces are laid out DESK_WIDTH wide (a phone: stacked in its column); less room scales them down to fit
	local side = UIKit.isShort()
	local scaler = panel:FindFirstChildOfClass("UIScale")
	local windowScale = if scaler and scaler.Scale > 0 then scaler.Scale else 1
	local room = desk.AbsoluteSize / windowScale
	local want = if side then SIDE.inner else Vector2.new(DESK_WIDTH, DESK_HEIGHT)
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromOffset(want.X, want.Y)
	inner.Parent = desk
	local fit = Instance.new("UIScale")
	fit.Scale = if room.X > 0 and room.Y > 0 then math.min(1, room.X / want.X, room.Y / want.Y) else 1
	fit.Parent = inner

	local listing = if selectedSlot then listings[selectedSlot] else nil
	if not listing then
		local message = if isEmpty then "This case is empty. Tap a + to put a card from your binder in it." else "Tap a card to set its price."
		local empty = UIKit.label(inner, message, Enum.Font.FredokaOne, if side then 14 else 16, palette.inkSoft)
		empty.Position = UDim2.fromOffset(8, 0)
		empty.Size = UDim2.new(1, -16, 1, 0)
		empty.TextXAlignment = Enum.TextXAlignment.Center
		return
	end

	-- left: its name and grade, then what it is worth
	local title = Instance.new("Frame")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = if side then UDim2.fromOffset(8, 6) else UDim2.fromOffset(14, 10)
	title.Size = if side then UDim2.fromOffset(182, 24) else UDim2.fromOffset(274, 26)
	title.Parent = inner
	local titleLayout = Instance.new("UIListLayout")
	titleLayout.FillDirection = Enum.FillDirection.Horizontal
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	titleLayout.SortOrder = Enum.SortOrder.LayoutOrder
	titleLayout.Padding = UDim.new(0, 8)
	titleLayout.Parent = title
	local name = UIKit.label(title, `{listing.card.name}{if listing.foil then " FOIL" else ""}`, Enum.Font.FredokaOne, 18, palette.ink)
	name.Name = "Name"
	name.LayoutOrder = 1
	name.Size = UDim2.fromOffset(0, 24)
	name.AutomaticSize = Enum.AutomaticSize.X
	name.TextWrapped = false
	local pill = gradePill(title, BeastRules.describeGrade(listing.growth.grade), listing.growth.grade, 13)
	pill.LayoutOrder = 2
	pill.Size = UDim2.fromOffset(74, 22)
	local worth = UIKit.label(inner, CaseWindow.worthLine({ market = listing.market, rarity = listing.card.rarity, foil = listing.foil, level = listing.growth.level, stars = listing.growth.stars }), Enum.Font.GothamBold, 12, palette.inkSoft)
	worth.Name = "Worth"
	worth.Position = if side then UDim2.fromOffset(8, 32) else UDim2.fromOffset(14, 40)
	worth.Size = if side then UDim2.fromOffset(182, 16) else UDim2.fromOffset(274, 16)
	worth.TextTruncate = Enum.TextTruncate.AtEnd
	worth.TextWrapped = false
	local hint = UIKit.label(inner, CaseWindow.hint(kind, listing.held), Enum.Font.GothamBold, 11, if listing.held then palette.good else palette.hint)
	hint.Name = if listing.held then "PricingHold" else "Hint"
	hint.Position = if side then UDim2.fromOffset(8, 50) else UDim2.fromOffset(14, 60)
	hint.Size = if side then UDim2.fromOffset(182, 28) else UDim2.fromOffset(330, 16)
	hint.TextWrapped = side
	hint.TextYAlignment = Enum.TextYAlignment.Top

	-- middle: - price +. A tap changes the price where it shows (showPrice), so each one starts from the price as it is
	local function tapStep(direction: number)
		local cardPart = getCardPart(listing.slot)
		local now = if cardPart then readListing(listing.slot, cardPart) else nil
		if now then
			nudge(now.slot, now.card, now.foil, now.growth, now.price, direction)
		end
	end
	local stepX = if side then 4 else 296 -- clear of Done and Take out on its right
	local stepY = if side then 84 else 10
	local priceWidth = if side then SIDE.price else PRICE_WIDTH
	local minus = UIKit.button(inner, "-", STEP_BUTTON_COLOR)
	minus.Name = "Less"
	minus.Position = UDim2.fromOffset(stepX, stepY)
	minus.Size = UDim2.fromOffset(STEP_SIZE, STEP_SIZE)
	minus.TextSize = 26
	minus.Activated:Connect(function()
		tapStep(-1)
	end)
	local priceText = CaseWindow.money(listing.price)
	local priceBox: GuiObject
	if kind == "PlayerCards" then
		local box = Instance.new("TextBox")
		box.ClearTextOnFocus = false
		box.PlaceholderText = "Type a price"
		box.Text = priceText
		box.Font = Enum.Font.FredokaOne
		box.TextSize = 22
		box.TextColor3 = palette.good
		box.FocusLost:Connect(function()
			setTypedPrice(listing.slot, listing.card, listing.foil, listing.growth, box)
		end)
		box.Parent = inner
		priceBox = box
	else
		local label = UIKit.label(inner, priceText, Enum.Font.FredokaOne, 22, palette.good)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextWrapped = false
		priceBox = label
	end
	priceBox.Name = "Price"
	priceBox.Position = UDim2.fromOffset(stepX + STEP_SIZE + 4, stepY)
	priceBox.Size = UDim2.fromOffset(priceWidth, STEP_SIZE)
	priceBox.BackgroundTransparency = 0
	priceBox.BackgroundColor3 = palette.row
	UIKit.corner(priceBox, 8)
	UIKit.outline(priceBox, palette.rowEdge, 2)
	local plus = UIKit.button(inner, "+", STEP_BUTTON_COLOR)
	plus.Name = "More"
	plus.Position = UDim2.fromOffset(stepX + STEP_SIZE + 4 + priceWidth + 4, stepY)
	plus.Size = UDim2.fromOffset(STEP_SIZE, STEP_SIZE)
	plus.TextSize = 26
	plus.Activated:Connect(function()
		tapStep(1)
	end)
	detailPrice = { slot = listing.slot, info = worth, editor = priceBox }

	-- right: Done (a new card goes on sale) and Take out
	local right = if side then SIDE.inner.X - 4 else DESK_WIDTH - 12
	local buttonY = if side then 138 else 10
	local buttonHeight = if side then 42 else STEP_SIZE
	local remove = UIKit.button(inner, "Take out", UIKit.Colors.Danger)
	remove.Name = "TakeOut"
	remove.AnchorPoint = Vector2.new(1, 0)
	remove.Position = UDim2.fromOffset(right, buttonY)
	remove.Size = UDim2.fromOffset(if side then 92 else 104, buttonHeight)
	remove.TextSize = 16
	remove.Activated:Connect(function()
		PriceTaps.forget(taps, listing.slot)
		Remotes.RemoveDisplayedCard:FireServer(casePart and casePart:GetAttribute("ShelfUid"), listing.slot)
	end)
	if listing.held then
		local done = UIKit.button(inner, "Done", UIKit.Colors.Accent)
		done.Name = "Done"
		done.AnchorPoint = Vector2.new(1, 0)
		done.Position = UDim2.fromOffset(if side then right - 92 - 4 else right - 104 - 8, buttonY)
		done.Size = UDim2.fromOffset(92, buttonHeight)
		done.TextSize = 18
		done.Activated:Connect(function()
			releaseListings(listing.slot)
			render()
		end)
	end
end

-- One card's price changed (a tap, a typed price, the server's echo): its tag, and the bar while it's the tapped card,
-- show it where they are; nothing is rebuilt, so a phone's scrolled window stays put (owner 2026-11-18)
showPrice = function(slot: number)
	local part = casePart
	local cardPart = getCardPart(slot)
	local listing = if cardPart then readListing(slot, cardPart) else nil
	if not part or not listing then
		render()
		return
	end
	local def = Shelves.ById[part.Name]
	local kind = if def then def.kind else ""
	local row = rowPrices[slot]
	if row and row.price.Parent then
		row.price.Text = CaseWindow.money(listing.price)
		local words, color = sellWords(listing, kind)
		row.tag.Text = words
		row.tag.TextColor3 = color
	end
	local detail = detailPrice
	if detail and detail.slot == slot and detail.info.Parent then
		local editor = detail.editor
		if editor and editor.Parent and not (editor:IsA("TextBox") and editor:IsFocused()) then
			(editor :: any).Text = CaseWindow.money(listing.price)
		end
	end
end

-- Each pane back where the player had scrolled it after a rebuild, and once more a moment later (a phone's scroll
-- settling after the tapped button was rebuilt under the finger)
local function keepScroll(pane: ScrollingFrame, at: Vector2)
	pane.CanvasPosition = at
	RunService.Heartbeat:Once(function()
		if pane.Parent then
			pane.CanvasPosition = at
		end
	end)
end

render = function()
	local part = casePart
	if not part then
		return
	end
	local def = Shelves.ById[part.Name]
	if not def then
		return
	end
	hideTooltip()
	local listAt = list.CanvasPosition
	clearChildren(list)
	rowPrices = {}
	local listings: { [number]: Listing } = {}
	local firstFilled: number? = nil
	for slot = 1, def.capacity do
		local cardPart = getCardPart(slot)
		local listing = if cardPart then readListing(slot, cardPart) else nil
		if listing then
			listings[slot] = listing
			firstFilled = firstFilled or slot
		end
	end
	-- A card just put out is the tapped one: it waits for its price until Done
	if justListed and listings[justListed] then
		selectedSlot = justListed
		justListed = nil
	end
	-- Keep the selection on a listed card; a sold or removed one falls back to the first listing
	if not (selectedSlot and listings[selectedSlot]) then
		selectedSlot = firstFilled
	end
	-- the stage in this case's colours
	local look = STAGE[def.id] or STAGE.default
	local sky = stage:FindFirstChildOfClass("UIGradient")
	if sky then
		sky.Color = ColorSequence.new(look.top, look.bottom)
	end
	local trim = stage:FindFirstChildOfClass("UIStroke")
	if trim then
		trim.Color = look.trim
	end
	local bed = stage:FindFirstChild("Bed")
	if bed and bed:IsA("Frame") then
		bed.BackgroundColor3 = look.bed
	end
	-- the slots as cards, as big as the pane lets them (Util/CaseWindow), the window's own scale taken out
	local scaler = panel:FindFirstChildOfClass("UIScale")
	local windowScale = if scaler and scaler.Scale > 0 then scaler.Scale else 1
	local columns = CaseWindow.columns(def.capacity)
	local rows = math.ceil(def.capacity / columns)
	local size = CaseWindow.tile(list.AbsoluteSize.X / windowScale - 16, list.AbsoluteSize.Y / windowScale - 12, columns, rows)
	grid.CellSize = UDim2.fromOffset(size.w, size.h)
	grid.FillDirectionMaxCells = columns
	-- in the middle of the pane while they fit; from the top once they scroll
	local tall = rows * size.h + (rows - 1) * CaseWindow.LOOK.gap
	grid.VerticalAlignment = if tall <= list.AbsoluteSize.Y / windowScale - 12 then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top
	for slot = 1, def.capacity do
		local listing = listings[slot]
		if listing then
			buildCardTile(listing, def.kind, size)
		else
			buildEmptyTile(slot, size)
		end
	end
	renderDesk(listings, def.kind, firstFilled == nil)
	keepScroll(list, listAt)
end

local function refreshFilterButtons()
	for filter, button in filterButtons do
		button.BackgroundColor3 = if filter == pickerFilter then UIKit.Colors.Accent else palette.row
	end
end

-- One choice in the picker: a stack of plain copies (card, grade, foil) or one levelled card
type PickerEntry = {
	key: string,
	card: Card,
	foil: boolean,
	growth: CopyGrowth,
	beastId: string?,
	count: number,
}

local function listEntry(entry: PickerEntry)
	local part, slot = casePart, pickerSlot
	picker.Visible = false
	if not part or not slot then
		return
	end
	justListed = slot
	if entry.beastId then
		Remotes.DisplayCard:FireServer(part:GetAttribute("ShelfUid"), slot, entry.card.id, entry.foil, entry.beastId)
	else
		Remotes.DisplayCard:FireServer(part:GetAttribute("ShelfUid"), slot, entry.card.id, entry.foil, nil, entry.growth.grade)
	end
end

-- The picker's card sheet (owner 2026-11-18: "Choose a card for slot 2: Design the card details. right now it's just a
-- bunch of text. make it more detailed and easier to understand"; option A of three mockups, the stat sheet): the card
-- large, its name, chips for rarity, element and grade, its stars and level, four stat tiles with their icons, what it's
-- worth in a gold box, how many you have, then List
local SHEET_GOLD = Color3.fromRGB(255, 243, 201)
local SHEET_GOLD_TEXT = Color3.fromRGB(138, 90, 0)
local SHEET_WHITE = Color3.new(1, 1, 1)
local SHEET_INK = Color3.fromRGB(74, 63, 92)

local function sheetChip(parent: Instance, text: string, fill: Color3, ink: Color3, order: number): TextLabel
	local chip = UIKit.label(parent, text, Enum.Font.FredokaOne, 13, ink)
	chip.LayoutOrder = order
	chip.TextWrapped = false
	chip.TextXAlignment = Enum.TextXAlignment.Center
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, 22)
	chip.BackgroundTransparency = 0
	chip.BackgroundColor3 = fill
	UIKit.corner(chip, 11)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = chip
	return chip
end

-- The element's chip: its icon, then its name, on a soft lilac pill
local SHEET_LILAC = Color3.fromRGB(232, 222, 250)

local function elementChip(parent: Instance, key: string, order: number)
	local chip = Instance.new("Frame")
	chip.LayoutOrder = order
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, 22)
	chip.BackgroundColor3 = SHEET_LILAC
	chip.Parent = parent
	UIKit.corner(chip, 11)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 5), UDim.new(0, 8)
	pad.Parent = chip
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Padding = UDim.new(0, 3)
	row.Parent = chip
	local image = ElementBadge.image(key)
	if image ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.LayoutOrder = 1
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(16, 16)
		icon.Image = image
		icon.Parent = chip
	end
	local text = UIKit.label(chip, ElementBadge.name(key), Enum.Font.FredokaOne, 13, SHEET_INK)
	text.LayoutOrder = 2
	text.TextWrapped = false
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromOffset(0, 22)
end

-- A stat as it reads: whole numbers with commas, attack speed with one decimal
local function statText(value: number): string
	return if value ~= math.floor(value) then string.format("%.1f", value) else DefeatRules.number(value)
end

local function listFrame(parent: Instance, order: number, height: number?): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height or 0)
	frame.AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y
	frame.Parent = parent
	return frame
end

local function stack(parent: Instance, horizontal: boolean, gap: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
	return layout
end

-- Right side of the picker: the chosen card's sheet and the List button
local function renderPickerPane(entry: PickerEntry?)
	clearChildren(pickerPane)
	if not pickerPane:FindFirstChild("SheetLayout") then
		stack(pickerPane, false, 8).Name = "SheetLayout"
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		pad.Parent = pickerPane
	end
	if not entry then
		local hint = UIKit.label(pickerPane, "Tap a card to see its details.", Enum.Font.GothamBold, 15, UIKit.Colors.Subtext)
		hint.Size = UDim2.new(1, 0, 0, 40)
		return
	end
	local card, growth = entry.card, entry.growth
	local stats = BeastRules.getStats(card, entry.foil, growth.level, growth.stars, growth.grade)
	local power = BeastRules.getPower(card, entry.foil, growth.level, growth.stars, growth.grade)
	local market = CardRules.getMarketValue(card, entry.foil, growth.level, growth.stars, growth.grade)

	-- The card, and beside it its name, chips, stars and stats
	local top = listFrame(pickerPane, 1)
	local faceHolder = Instance.new("Frame")
	faceHolder.Size = UDim2.fromOffset(DETAIL_FACE_SIZE.X, DETAIL_FACE_SIZE.Y)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = top
	makeCardFace(faceHolder, card, entry.foil, true, growth)
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.Position = UDim2.fromOffset(DETAIL_FACE_SIZE.X + 10, 0)
	column.Size = UDim2.new(1, -(DETAIL_FACE_SIZE.X + 10), 0, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.Parent = top
	stack(column, false, 6)

	local name = UIKit.label(column, `{card.name}{if entry.foil then " FOIL" else ""}`, Enum.Font.FredokaOne, 20, UIKit.Colors.Text)
	name.LayoutOrder = 1
	name.Size = UDim2.new(1, 0, 0, 24)
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local chips = listFrame(column, 2)
	stack(chips, true, 4).Wraps = true
	sheetChip(chips, card.rarity, CardFace.getRarityColor(card.rarity), SHEET_WHITE, 1)
	elementChip(chips, card.element, 2)
	sheetChip(chips, BeastRules.describeGrade(growth.grade), CardDesign.GRADE_COLORS[growth.grade] or CardDesign.GRADE_COLORS.C, SHEET_WHITE, 3)

	local starsRow = listFrame(column, 3)
	local starsFlow = stack(starsRow, true, 2)
	starsFlow.VerticalAlignment = Enum.VerticalAlignment.Center
	starsFlow.Wraps = true -- a narrow phone pane: the level goes under the stars
	for star = 1, Beasts.MAX_STARS do
		local icon = Icon.make(starsRow, "Star", UDim2.fromOffset(16, 16))
		icon.LayoutOrder = star
		if star > growth.stars then
			for _, image in icon:GetDescendants() do
				if image:IsA("ImageLabel") then
					image.ImageTransparency = 0.75 -- a star not earned yet
				end
			end
		end
	end
	local level = UIKit.label(starsRow, `  Lv {growth.level} · #{card.number}`, Enum.Font.GothamBold, 12, UIKit.Colors.Subtext)
	level.LayoutOrder = Beasts.MAX_STARS + 1
	level.TextWrapped = false
	level.AutomaticSize = Enum.AutomaticSize.X
	level.Size = UDim2.fromOffset(0, 18)

	local grid = listFrame(column, 4, 82)
	local cells = Instance.new("UIGridLayout")
	cells.CellSize = UDim2.new(0.5, -3, 0, 38)
	cells.CellPadding = UDim2.fromOffset(6, 6)
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.Parent = grid
	for order, stat in { { "Power", "Power", power }, { "Hp", "HP", stats.hp }, { "Atk", "ATK", stats.atk }, { "Spd", "SPD", stats.spd } } do
		local tile = Instance.new("Frame")
		tile.LayoutOrder = order
		tile.BackgroundColor3 = palette.row
		tile.Parent = grid
		UIKit.corner(tile, 8)
		local icon = Icon.make(tile, stat[1], UDim2.fromOffset(20, 20))
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 6, 0.5, 0)
		local value = UIKit.label(tile, statText(stat[3]), Enum.Font.FredokaOne, 17, UIKit.Colors.Text)
		value.Position = UDim2.fromOffset(30, 2)
		value.Size = UDim2.new(1, -34, 0, 20)
		value.TextWrapped = false
		local word = UIKit.label(tile, stat[2], Enum.Font.GothamBold, 10, UIKit.Colors.Subtext)
		word.Position = UDim2.fromOffset(30, 21)
		word.Size = UDim2.new(1, -34, 0, 14)
	end

	-- What it's worth, in gold
	local worth = listFrame(pickerPane, 2, 44)
	worth.BackgroundTransparency = 0
	worth.BackgroundColor3 = SHEET_GOLD
	UIKit.corner(worth, 10)
	local cash = Icon.make(worth, "Cash", UDim2.fromOffset(22, 22))
	cash.AnchorPoint = Vector2.new(0, 0.5)
	cash.Position = UDim2.new(0, 10, 0.5, 0)
	local worthWord = UIKit.label(worth, "Worth", Enum.Font.GothamBold, 14, SHEET_GOLD_TEXT)
	worthWord.Position = UDim2.fromOffset(38, 0)
	worthWord.Size = UDim2.new(0.5, -38, 1, 0)
	local worthValue = UIKit.label(worth, string.format("$%.2f", market), Enum.Font.FredokaOne, 24, SHEET_GOLD_TEXT)
	worthValue.AnchorPoint = Vector2.new(1, 0)
	worthValue.Position = UDim2.new(1, -12, 0, 0)
	worthValue.Size = UDim2.new(0.5, 0, 1, 0)
	worthValue.TextXAlignment = Enum.TextXAlignment.Right
	worthValue.TextWrapped = false

	local owned = if entry.beastId
		then "Your levelled card: its own level, stars and grade"
		else `You have {entry.count} of this copy`
	local hint = UIKit.label(pickerPane, owned, Enum.Font.GothamBold, 12, UIKit.Colors.Subtext)
	hint.LayoutOrder = 3
	hint.Size = UDim2.new(1, 0, 0, 16)

	local listButton = UIKit.button(pickerPane, `List in slot {pickerSlot or 0}`, UIKit.Colors.Accent)
	listButton.LayoutOrder = 4
	listButton.Size = UDim2.new(1, 0, 0, 48)
	listButton.TextSize = 17
	listButton.Activated:Connect(function()
		listEntry(entry)
	end)
end

local renderPicker: () -> ()

-- Card face with grade/count and value underneath, so the grid stays readable
local function buildPickerTile(entry: PickerEntry, order: number, selected: PickerEntry?, choose: (PickerEntry) -> ())
	local tile = Instance.new("TextButton")
	tile.Name = entry.key
	tile.LayoutOrder = order
	tile.BackgroundColor3 = palette.row
	tile.Text = ""
	tile.Parent = pickerList
	UIKit.corner(tile, 8)
	if selected and selected.key == entry.key then
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = UIKit.Colors.Accent
		stroke.Thickness = 2
		stroke.Parent = tile
	end

	local faceHolder = Instance.new("Frame")
	faceHolder.Position = UDim2.fromOffset(4, 4)
	faceHolder.Size = UDim2.new(1, -8, 0, PICKER_FACE_HEIGHT)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = tile
	-- the copy's own grade on its face (owner 2026-11-16: the tiles said Grade A under a face showing C)
	makeCardFace(faceHolder, entry.card, entry.foil, false, entry.growth)

	local growth = entry.growth
	local detail = if entry.beastId then `{growth.grade} · Lv {growth.level}` else `Grade {growth.grade} · x{entry.count}`
	local line = UIKit.label(tile, detail, Enum.Font.GothamBold, 12, UIKit.Colors.Text)
	line.Position = UDim2.fromOffset(2, PICKER_FACE_HEIGHT + 6)
	line.Size = UDim2.new(1, -4, 0, 16)
	line.TextXAlignment = Enum.TextXAlignment.Center
	line.TextTruncate = Enum.TextTruncate.AtEnd
	local market = CardRules.getMarketValue(entry.card, entry.foil, growth.level, growth.stars, growth.grade)
	local value = UIKit.label(tile, string.format("$%.2f", market), Enum.Font.FredokaOne, 15, palette.good)
	value.Position = UDim2.fromOffset(2, PICKER_FACE_HEIGHT + 24)
	value.Size = UDim2.new(1, -4, 0, 18)
	value.TextXAlignment = Enum.TextXAlignment.Center

	tile.Activated:Connect(function()
		choose(entry)
	end)
end

-- Every copy the player can list: levelled cards (most valuable first), then plain stacks rarest first,
-- best grade and foil first
local function getPickerEntries(): { PickerEntry }
	local entries: { PickerEntry } = {}
	local raised = {}
	local working = BinderController.GetWorking()
	local partied = BinderController.GetPartied()
	for id, beast in BinderController.GetBeasts() do
		if not working[id] and not partied[id] then -- working and party cards stay where they are
			table.insert(raised, beast)
		end
	end
	table.sort(raised, function(a, b)
		local cardA, cardB = Cards.ById[a.cardId], Cards.ById[b.cardId]
		return BeastRules.getValue(cardA, a.foil, a.level, a.stars, a.grade) > BeastRules.getValue(cardB, b.foil, b.level, b.stars, b.grade)
	end)
	for _, beast in raised do
		local card = Cards.ById[beast.cardId]
		if card and passesFilter(card, beast.foil) then
			table.insert(entries, {
				key = beast.id,
				card = card,
				foil = beast.foil,
				growth = { level = beast.level, stars = beast.stars, grade = beast.grade },
				beastId = beast.id,
				count = 1,
			})
		end
	end
	local graded = BinderController.GetGradedStacks()
	for _, card in Cards.RarestFirst do
		local byGrade = graded[card.id] or {}
		for index = #BeastRules.GRADES, 1, -1 do
			local grade = BeastRules.GRADES[index]
			local owned = byGrade[grade]
			for _, foil in { true, false } do
				local count = if owned then (if foil then owned.foil else owned.normal) else 0
				if count > 0 and passesFilter(card, foil) then
					table.insert(entries, {
						key = `{card.id}:{grade}:{foil}`,
						card = card,
						foil = foil,
						growth = { level = 1, stars = BeastRules.START_STARS, grade = grade },
						count = count,
					})
				end
			end
		end
	end
	return entries
end

-- Grid of cards on the left, details and the List button on the right
renderPicker = function()
	clearChildren(pickerList)
	refreshFilterButtons()
	local entries = getPickerEntries()
	local selected: PickerEntry? = nil
	for _, entry in entries do
		if entry.key == pickerSelectedKey then
			selected = entry
		end
	end
	selected = selected or entries[1]
	pickerSelectedKey = if selected then selected.key else nil

	for order, entry in entries do
		buildPickerTile(entry, order, selected, function(chosen)
			pickerSelectedKey = chosen.key
			renderPicker()
		end)
	end
	if #entries == 0 then
		local binderEmpty = next(BinderController.GetCollection()) == nil and next(BinderController.GetBeasts()) == nil
		local message = if binderEmpty then "Your binder is empty. Rip some packs first." else "No cards match this filter."
		local empty = UIKit.label(pickerList, message, Enum.Font.GothamBold, 16, UIKit.Colors.Subtext)
		empty.Size = UDim2.fromOffset(300, 60)
	end
	renderPickerPane(selected)
end

openPicker = function(slot: number)
	pickerSlot = slot
	pickerSelectedKey = nil
	pickerTitle.Text = `Choose a card for slot {slot}`
	renderPicker()
	picker.Visible = true
end

local function buildPicker(parent: Instance)
	picker, pickerList = UIKit.panel(parent, "CardPicker", "Pick a card", "Cards")
	picker:SetAttribute("Overlay", true) -- opens over the case's panel
	picker.ZIndex = UIKit.PANEL_Z_INDEX + 1 -- over the case manager it opens from
	-- Same size as the case manager so it covers it completely
	picker.Size = UDim2.fromScale(0.94, 0.86)
	local sizeLimit = picker:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	pickerTitle = picker:FindFirstChild("Title") :: TextLabel
	pickerTitle.TextSize = 22

	-- Rarity filter chips; the row scrolls sideways when it's wider than the panel (phones)
	local chips = Instance.new("ScrollingFrame")
	chips.Position = UDim2.fromOffset(12, 60)
	chips.Size = UDim2.new(1, -24, 0, 52)
	chips.BackgroundTransparency = 1
	chips.BorderSizePixel = 0
	chips.ScrollBarThickness = 3
	chips.ScrollingDirection = Enum.ScrollingDirection.X
	chips.CanvasSize = UDim2.new()
	chips.AutomaticCanvasSize = Enum.AutomaticSize.X
	chips.Parent = picker
	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.Padding = UDim.new(0, 8)
	chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chipLayout.Parent = chips
	-- room for the chips' rings and lips, which the row would clip (owner 2026-11-16: "some borders are cutoff")
	UIKit.padList(chips, { side = 4, right = 4, top = 4, bottom = 6 })
	for index, filter in getPickerFilters() do
		local chip = UIKit.button(chips, filter, palette.row)
		chip.LayoutOrder = index
		chip.Size = UDim2.fromOffset(FILTER_CHIP_WIDTH, 40)
		chip.TextSize = 15
		-- A rarity's chip (and the Frontier's) wears its colour as the ring: as text it doesn't read on white
		local tier = Rarities.Tiers[filter]
		local ringColor = if tier then tier.color elseif filter == FRONTIER_FILTER then CardEffects.FRONTIER.AURORA[1] else nil
		for _, ring in chip:GetChildren() do
			if ringColor and ring:IsA("UIStroke") and ring.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
				ring.Color = ringColor
			end
		end
		chip.Activated:Connect(function()
			pickerFilter = filter
			renderPicker()
		end)
		filterButtons[filter] = chip
	end

	-- Grid of card tiles on the left
	pickerList.Position = UDim2.fromOffset(12, 116)
	pickerList.Size = UDim2.new(PICKER_LIST_SCALE, -18, 1, -128)
	UIKit.padList(pickerList, { side = 6, right = 10, top = 6, bottom = 8 }) -- the chosen tile's gold ring, unclipped
	local listLayout = pickerList:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		listLayout:Destroy()
	end
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(PICKER_TILE_SIZE.X, PICKER_TILE_SIZE.Y)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = pickerList

	-- Details of the chosen card on the right
	pickerPane = Instance.new("ScrollingFrame")
	pickerPane.Name = "Details"
	pickerPane.Position = UDim2.new(PICKER_LIST_SCALE, 6, 0, 116)
	pickerPane.Size = UDim2.new(1 - PICKER_LIST_SCALE, -18, 1, -128)
	pickerPane.BackgroundColor3 = palette.slotEmpty -- a deeper cream
	pickerPane.BackgroundTransparency = 0
	pickerPane.BorderSizePixel = 0
	pickerPane.ScrollBarThickness = 4
	pickerPane.CanvasSize = UDim2.new()
	pickerPane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pickerPane.Parent = picker
	UIKit.corner(pickerPane, 10)
end

local function disconnectCase()
	for _, connection in caseConnections do
		connection:Disconnect()
	end
	table.clear(caseConnections)
end

-- The window's pieces for this screen: a computer's bar under the cards, or a phone's bigger window with the bar as a
-- column beside them
local function layout()
	local phone = UIKit.isShort()
	panel.Size = if phone then UDim2.fromScale(0.97, 0.96) else UDim2.fromScale(0.94, 0.86)
	subtitle.Visible = not phone
	local top = if phone then UIKit.HEADER_HEIGHT + 8 else TOP
	if phone then
		list.Position = UDim2.fromOffset(EDGE, top)
		list.Size = UDim2.new(1, -(2 * EDGE + SIDE.width + 8), 1, -(top + EDGE))
		desk.AnchorPoint = Vector2.new(1, 0)
		desk.Position = UDim2.new(1, -EDGE, 0, top)
		desk.Size = UDim2.new(0, SIDE.width, 1, -(top + EDGE))
	else
		list.Position = UDim2.fromOffset(EDGE, top)
		list.Size = UDim2.new(1, -2 * EDGE, 1, -(top + EDGE + DESK_HEIGHT + 8))
		desk.AnchorPoint = Vector2.new(0, 1)
		desk.Position = UDim2.new(0, EDGE, 1, -EDGE)
		desk.Size = UDim2.new(1, -2 * EDGE, 0, DESK_HEIGHT)
	end
	stage.Position = list.Position
	stage.Size = list.Size
end

-- Opens the manager for one of your own card cases
function ShowcaseController.Open(part: BasePart)
	local def = Shelves.ById[part.Name]
	if not def or (def.kind ~= "CustomerCards" and def.kind ~= "PlayerCards") then
		return
	end
	if casePart and casePart ~= part then
		releaseListings(nil) -- another case: the last one's new cards go on sale
	end
	disconnectCase()
	casePart = part
	PriceTaps.forget(taps, nil)
	selectedSlot = nil
	justListed = nil
	titleLabel.Text = def.name
	subtitle.Text = KIND_DESCRIPTIONS[def.kind] or ""
	layout()

	-- Re-render whenever cards arrive, leave (sold or removed) or wait for their price; a new price only changes its words
	local function watchCard(child: Instance)
		if child:IsA("BasePart") then
			table.insert(caseConnections, child:GetAttributeChangedSignal("Price"):Connect(function()
				local slot = child:GetAttribute("Slot")
				if typeof(slot) == "number" then
					showPrice(slot)
				else
					render()
				end
			end))
			table.insert(caseConnections, child:GetAttributeChangedSignal("PricingHold"):Connect(render))
		end
	end
	for _, child in part:GetChildren() do
		watchCard(child)
	end
	table.insert(caseConnections, part.ChildAdded:Connect(function(child)
		watchCard(child)
		render()
	end))
	table.insert(caseConnections, part.ChildRemoved:Connect(render))
	table.insert(caseConnections, part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) then
			panel.Visible = false
		end
	end))

	render()
	picker.Visible = false
	panel.Visible = true
end

function ShowcaseController.Start()
	local screenGui = UIController.GetScreenGui()

	panel, list = UIKit.panel(screenGui, "CardCase", "Cards", "Cards")
	palette = UIKit.colorsFor(panel)
	titleLabel = panel:FindFirstChild("Title") :: TextLabel
	subtitle = UIKit.label(panel, "", Enum.Font.Gotham, 14, UIKit.Colors.Subtext)
	subtitle.Position = UDim2.fromOffset(16, 56)
	subtitle.Size = UDim2.new(1, -32, 0, 22)
	-- The case itself: its slots as cards, the tapped card's bar under them
	panel.Size = UDim2.fromScale(0.94, 0.86)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	list.Position = UDim2.fromOffset(EDGE, TOP)
	list.Size = UDim2.new(1, -2 * EDGE, 1, -(TOP + EDGE + DESK_HEIGHT + 8))
	-- room for the tapped card's gold ring, which the list clipped (owner 2026-11-17: "some cut off border here")
	UIKit.padList(list, { side = 8, right = 8, top = 6, bottom = 6 })
	for _, child in list:GetChildren() do
		if child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(CaseWindow.LOOK.gap, CaseWindow.LOOK.gap)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	-- The lit case behind the cards (its colours set per case in render): a dark stage with the case's trim, a bed
	-- along its foot where the pads stand and a soft shine across its glass
	stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.Position = list.Position
	stage.Size = list.Size
	stage.BackgroundColor3 = Color3.new(1, 1, 1)
	stage.ZIndex = list.ZIndex - 1
	stage.Parent = panel
	UIKit.corner(stage, 14)
	UIKit.outline(stage, STAGE.default.trim, 3)
	local sky = Instance.new("UIGradient")
	sky.Rotation = 90
	sky.Color = ColorSequence.new(STAGE.default.top, STAGE.default.bottom)
	sky.Parent = stage
	local bed = Instance.new("Frame")
	bed.Name = "Bed"
	bed.AnchorPoint = Vector2.new(0.5, 1)
	bed.Position = UDim2.new(0.5, 0, 1, -6)
	bed.Size = UDim2.new(1, -12, 0.34, 0)
	bed.BackgroundColor3 = STAGE.default.bed
	bed.BorderSizePixel = 0
	bed.ZIndex = stage.ZIndex
	bed.Parent = stage
	UIKit.corner(bed, 10)
	local bedFade = Instance.new("UIGradient")
	bedFade.Rotation = 90
	bedFade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.55), NumberSequenceKeypoint.new(1, 0.25) })
	bedFade.Parent = bed
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Position = UDim2.fromOffset(6, 6)
	shine.Size = UDim2.new(1, -12, 0.3, 0)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BorderSizePixel = 0
	shine.ZIndex = stage.ZIndex
	shine.Parent = stage
	UIKit.corner(shine, 10)
	local shineFade = Instance.new("UIGradient")
	shineFade.Rotation = 90
	shineFade.Transparency = NumberSequence.new(0.88, 1)
	shineFade.Parent = shine
	list.BackgroundTransparency = 1

	desk = Instance.new("Frame")
	desk.Name = "Desk"
	desk.AnchorPoint = Vector2.new(0, 1)
	desk.Position = UDim2.new(0, EDGE, 1, -EDGE)
	desk.Size = UDim2.new(1, -2 * EDGE, 0, DESK_HEIGHT)
	desk.BackgroundColor3 = palette.row
	desk.ClipsDescendants = true
	desk.Parent = panel
	UIKit.corner(desk, 14)
	UIKit.outline(desk, palette.rowEdge, 2)

	tooltip = Instance.new("Frame")
	tooltip.Name = "CardTooltip"
	tooltip.Size = UDim2.fromOffset(TOOLTIP_WIDTH, 0)
	tooltip.AutomaticSize = Enum.AutomaticSize.Y
	tooltip.BackgroundColor3 = UIKit.Colors.Panel
	tooltip.ZIndex = 50
	tooltip.Visible = false
	tooltip.Parent = screenGui
	UIKit.corner(tooltip, 8)
	local tooltipStroke = Instance.new("UIStroke")
	tooltipStroke.Color = UIKit.Colors.Accent
	tooltipStroke.Parent = tooltip
	local tooltipPadding = Instance.new("UIPadding")
	tooltipPadding.PaddingTop = UDim.new(0, 8)
	tooltipPadding.PaddingBottom = UDim.new(0, 8)
	tooltipPadding.PaddingLeft = UDim.new(0, 10)
	tooltipPadding.PaddingRight = UDim.new(0, 10)
	tooltipPadding.Parent = tooltip
	tooltipText = UIKit.label(tooltip, "", Enum.Font.GothamBold, 13, UIKit.Colors.Text)
	tooltipText.Size = UDim2.fromScale(1, 0)
	tooltipText.AutomaticSize = Enum.AutomaticSize.Y
	tooltipText.ZIndex = 51

	buildPicker(screenGui)

	-- Binder changes (a card going on display) refresh the picker if it's open
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		if picker.Visible then
			renderPicker()
		end
	end)
	-- Walking away from the case is Done (owner 2026-11-20: "it should be considered done when the player walks away
	-- even if they did not press DONE"): its window closes, which puts its new cards on sale with the prices set (the
	-- server lets them go by itself too: ShowcaseService)
	task.spawn(function()
		local Showcase = require(Config:WaitForChild("Showcase")) :: any
		local localPlayer = game:GetService("Players").LocalPlayer
		while true do
			task.wait(Showcase.WALK_CHECK)
			local part = casePart
			local character = localPlayer.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if panel.Visible and part and root and root:IsA("BasePart") and (root.Position - part.Position).Magnitude > Showcase.WALK_AWAY then
				panel.Visible = false
			end
		end
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			releaseListings(nil) -- the window closed: its new cards go on sale with the prices set
			picker.Visible = false
			hideTooltip()
			disconnectCase()
			casePart = nil
			justListed = nil
		end
	end)
end

return ShowcaseController
