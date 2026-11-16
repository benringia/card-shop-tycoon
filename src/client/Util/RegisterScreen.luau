--!strict
-- The register's screen when you man it (owner 2026-11-16: "improve the registers UI. add some design to it. it must be
-- immersive. it is also currently confusing for the kids"; round 2 mockup approved; Config/RegisterStation SAY,
-- SCREEN, SCREEN_COLORS): a dark POS screen with a lilac bar (its name and the town's clock) and one big line saying
-- what to do now, the number to use shown big (the step pills under the bar went, owner 2026-11-16: "remove these").
-- Drawn on the register's screen part (a SurfaceGui in PlayerGui, so its buttons take taps). RegisterStationController
-- feeds it a State and reacts to its buttons
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local RegisterStation = require(Config:WaitForChild("RegisterStation"))
local Cards = require(Config:WaitForChild("Cards"))
local CardArtConfig = require(Config:WaitForChild("CardArt"))
local Packs = require(Config:WaitForChild("Packs"))
local Products = require(Config:WaitForChild("Products"))
local ProductPictures = require(Config:WaitForChild("ProductPictures"))
local UIIcons = require(Config:WaitForChild("UIIcons"))
local CardArt = require(Shared:WaitForChild("Util"):WaitForChild("CardArt"))
local PaymentRules = require(Shared:WaitForChild("Util"):WaitForChild("PaymentRules"))
local ProductPictureRules = require(Shared:WaitForChild("Util"):WaitForChild("ProductPictureRules"))
local RegisterStationRules = require(Shared:WaitForChild("Util"):WaitForChild("RegisterStationRules"))

local RegisterScreen = {}

-- `product` its product id, or `card` a single card's id (its picture beside it)
export type Line = { name: string, price: number, done: boolean, product: string?, card: string? }
export type State = {
	situation: RegisterStationRules.Situation,
	clock: string,
	sales: number,
	taken: number, -- dollars sold this visit
	lines: { Line },
	total: number, -- cents scanned so far (or the price agreed)
	remaining: number,
	payTotal: number, -- cents to pay
	given: number, -- cents the customer handed over (cash)
	giving: number, -- cents you're giving back
	error: string, -- what was wrong, or ""
}
-- `sold(words)`: a sale's flash over the whole screen ("SOLD! +$12.50", Config/RegisterStation SALE_FX)
export type Screen = { gui: SurfaceGui, set: (State) -> (), sold: (words: string) -> () }

local SAY = RegisterStation.SAY
local WORDS = RegisterStation.SCREEN
local C = RegisterStation.SCREEN_COLORS
-- The face is laid out 570 wide whatever the part's size (read from the cashier's step, so few things, big)
local SCREEN_SIZE = RegisterStation.UNIT.screen.size
local WIDTH = 570
local HEIGHT = math.floor(WIDTH * SCREEN_SIZE[2] / SCREEN_SIZE[1])
local BODY_TOP = 72
local ROW_HEIGHT = 54
local PICTURE = 46 -- px: an item's picture at the left of its row
local LIST_ROWS = 2

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function corner(object: GuiObject, radius: number)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, radius)
	round.Parent = object
end

local function box(parent: Instance, name: string, x: number, y: number, w: number, h: number, color: { number }?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(w, h)
	frame.BackgroundColor3 = if color then rgb(color) else Color3.new()
	frame.BackgroundTransparency = if color then 0 else 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function text(parent: Instance, words: string, x: number, y: number, w: number, h: number, size: number, color: { number }, align: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.fromOffset(w, h)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = size
	label.TextColor3 = rgb(color)
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Text = words
	label.Parent = parent
	return label
end

local function button(parent: Instance, name: string, y: number, h: number): TextButton
	local made = Instance.new("TextButton")
	made.Name = name
	made.AutoButtonColor = true
	made.Position = UDim2.fromOffset(18, y)
	made.Size = UDim2.fromOffset(WIDTH - 36, h)
	made.Font = Enum.Font.FredokaOne
	made.TextSize = 34
	made.Parent = parent
	corner(made, 14)
	return made
end

-- An item's picture: a pack's or deck box's real picture (Config/ProductPictures), another product's icon, a card's
-- painting (its small copy: drawn PICTURE tall)
local function pictureFor(line: Line): string
	if line.card then
		local card = Cards.ById[line.card]
		return if card then CardArt.pick(card.name, PICTURE, CardArtConfig) or "" else ""
	end
	local product = if line.product then Products.ById[line.product] else nil
	if not product then
		return ""
	end
	local pack = Packs.ById[product.id]
	if pack then
		local image, fallback = ProductPictureRules.pick(ProductPictures, pack.look, if pack.kind == "Deck" then "Deck" else "Pack")
		return image or UIIcons[fallback] or ""
	end
	return UIIcons[product.icon] or ""
end

-- A soft pulse round a button to press now (the charge button, the give button once it's exact)
local function pulse(target: GuiObject): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(C.go)
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = target
	TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 9, Transparency = 0.75 }):Play()
	return stroke
end

function RegisterScreen.build(parent: Instance, onCharge: () -> (), onGive: () -> ()): Screen
	local gui = Instance.new("SurfaceGui")
	gui.Name = "RegisterScreenGui"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = WIDTH / SCREEN_SIZE[1]
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = parent

	-- rounded like the bezel round it (the screen part itself is clear)
	local back = box(gui, "Back", 0, 0, WIDTH, HEIGHT, C.back)
	back.Size = UDim2.fromScale(1, 1)
	corner(back, math.floor(RegisterStation.UNIT.screen.corner * WIDTH / SCREEN_SIZE[1]))

	-- The bar: the register's name and the town's clock, a rounded band inside the top edge
	local bar = box(gui, "Bar", 8, 6, WIDTH - 16, 52, C.barTo)
	corner(bar, 16)
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new(rgb(C.barFrom), rgb(C.barTo))
	shine.Parent = bar
	text(bar, "🛒 " .. WORDS.title, 14, 0, 320, 52, 36, C.ink)
	local clock = text(bar, "", WIDTH - 16 - 234, 0, 220, 52, 36, C.ink, Enum.TextXAlignment.Right)

	local views: { [string]: Frame } = {}
	local function view(name: string): Frame
		local frame = box(gui, name, 0, 0, WIDTH, HEIGHT)
		frame.Size = UDim2.fromScale(1, 1)
		frame.Visible = false
		views[name] = frame
		return frame
	end

	-- Idle: waiting, and how this visit is going
	local idle = view("idle")
	text(idle, "🛒", 0, 76, WIDTH, 100, 90, C.ink, Enum.TextXAlignment.Center)
	text(idle, SAY.idle, 16, 180, WIDTH - 32, 70, 50, C.ink, Enum.TextXAlignment.Center)
	local today = text(idle, "", 16, 262, WIDTH - 32, 50, 34, C.soft, Enum.TextXAlignment.Center)

	-- 1 Scan: every item, ticked as it beeps
	local scan = view("scan")
	text(scan, SAY.scan, 18, BODY_TOP, WIDTH - 36, 52, 40, C.now)
	local rows: { { frame: Frame, picture: ImageLabel, name: TextLabel, price: TextLabel } } = {}
	for index = 1, LIST_ROWS do
		local row = box(scan, "Row" .. index, 18, BODY_TOP + 58 + (index - 1) * (ROW_HEIGHT + 6), WIDTH - 36, ROW_HEIGHT, C.panel)
		corner(row, 10)
		-- the item's picture (owner 2026-11-16: "add icons beside the items")
		local picture = Instance.new("ImageLabel")
		picture.Name = "Picture"
		picture.BackgroundTransparency = 1
		picture.ScaleType = Enum.ScaleType.Fit
		picture.AnchorPoint = Vector2.new(0, 0.5)
		picture.Position = UDim2.new(0, 8, 0.5, 0)
		picture.Size = UDim2.fromOffset(PICTURE, PICTURE)
		picture.Parent = row
		local name = text(row, "", 16 + PICTURE, 0, WIDTH - 236 - PICTURE, ROW_HEIGHT, 30, C.ink)
		local price = text(row, "", WIDTH - 220, 0, 170, ROW_HEIGHT, 30, C.ink, Enum.TextXAlignment.Right)
		-- a long name shrinks to fit ("First Spark Booster Pack"), at most the row's size
		name.TextWrapped = false
		name.TextScaled = true
		local most = Instance.new("UITextSizeConstraint")
		most.MaxTextSize = 30
		most.MinTextSize = 16
		most.Parent = name
		name.TextTruncate = Enum.TextTruncate.AtEnd
		table.insert(rows, { frame = row, picture = picture, name = name, price = price })
	end
	text(scan, WORDS.totalSoFar, 18, HEIGHT - 66, 280, 56, 32, C.soft)
	local scanTotal = text(scan, "", WIDTH - 298, HEIGHT - 70, 280, 64, 54, C.ink, Enum.TextXAlignment.Right)

	-- 2 Charge: one big pulsing button
	local charge = view("charge")
	text(charge, "✔️ " .. SAY.charge, 18, BODY_TOP, WIDTH - 36, 48, 38, C.doneInk)
	text(charge, WORDS.total, 18, BODY_TOP + 50, 200, 76, 36, C.soft)
	local chargeTotal = text(charge, "", WIDTH - 358, BODY_TOP + 46, 340, 84, 76, C.ink, Enum.TextXAlignment.Right)
	local chargeButton = button(charge, "ChargeOnScreen", BODY_TOP + 138, HEIGHT - BODY_TOP - 150)
	chargeButton.BackgroundColor3 = rgb(C.go)
	chargeButton.TextColor3 = rgb(C.goInk)
	chargeButton.TextSize = 50
	pulse(chargeButton)
	chargeButton.Activated:Connect(onCharge)

	-- A deal on the table (the offer window does the talking)
	local offer = view("offer")
	text(offer, "🤝", 0, BODY_TOP + 6, WIDTH, 96, 80, C.ink, Enum.TextXAlignment.Center)
	text(offer, SAY.offer, 16, BODY_TOP + 108, WIDTH - 32, 100, 46, C.now, Enum.TextXAlignment.Center)

	-- 3 Pay, card: the number to type, huge, an arrow toward the machine
	local card = view("card")
	text(card, SAY.card, 18, BODY_TOP, WIDTH - 36, 50, 42, C.now)
	text(card, WORDS.cardType, 18, BODY_TOP + 50, WIDTH - 36, 40, 32, C.soft)
	local typeBox = box(card, "TypeThis", 18, BODY_TOP + 96, WIDTH - 36, HEIGHT - BODY_TOP - 108, C.gold)
	corner(typeBox, 14)
	local dashed = Instance.new("UIStroke")
	dashed.Color = rgb(C.now)
	dashed.Thickness = 3
	dashed.Parent = typeBox
	local typeThis = text(typeBox, "", 0, 0, WIDTH - 36, HEIGHT - BODY_TOP - 108, 100, C.now, Enum.TextXAlignment.Center)

	-- 3 Pay, cash: give back in gold, a bar filling as you tap money; the button only lights up when exact
	local cash = view("cash")
	local gave = text(cash, "", 18, BODY_TOP, 340, 38, 32, C.ink)
	local cashTotal = text(cash, "", WIDTH - 238, BODY_TOP, 220, 38, 28, C.soft, Enum.TextXAlignment.Right)
	local giveBox = box(cash, "GiveBack", 18, BODY_TOP + 40, WIDTH - 36, 66, C.gold)
	corner(giveBox, 12)
	local goldEdge = Instance.new("UIStroke")
	goldEdge.Color = rgb(C.now)
	goldEdge.Thickness = 3
	goldEdge.Parent = giveBox
	text(giveBox, WORDS.giveBack, 16, 0, 260, 66, 38, C.ink)
	local giveBack = text(giveBox, "", WIDTH - 36 - 276, 0, 260, 66, 58, C.now, Enum.TextXAlignment.Right)
	local givingOf = text(cash, "", 18, BODY_TOP + 110, 400, 32, 28, C.soft)
	text(cash, WORDS.drawer, WIDTH - 198, BODY_TOP + 110, 180, 32, 28, C.soft, Enum.TextXAlignment.Right)
	local meter = box(cash, "Meter", 18, BODY_TOP + 144, WIDTH - 36, 14, C.panel)
	corner(meter, 7)
	local fill = box(meter, "Fill", 0, 0, 0, 14, C.go)
	corner(fill, 7)
	local giveTop = BODY_TOP + 166
	local giveButton = button(cash, "GiveChange", giveTop, HEIGHT - giveTop - 10)
	giveButton.Text = WORDS.give
	giveButton.TextSize = 40
	local givePulse = pulse(giveButton)
	giveButton.Activated:Connect(onGive)

	-- a wrong answer: a red banner over the first line for a moment
	local errorLabel = text(gui, "", 14, BODY_TOP - 2, WIDTH - 28, 48, 28, C.ink, Enum.TextXAlignment.Center)
	errorLabel.Name = "Error"
	errorLabel.BackgroundColor3 = rgb(C.bad)
	errorLabel.ZIndex = 5
	corner(errorLabel, 22)

	local function set(state: State)
		local now = state.situation
		for name, frame in views do
			frame.Visible = name == now
		end
		clock.Text = state.clock

		today.Text = string.format(WORDS.today, state.sales, if state.sales == 1 then "sale" else "sales", PaymentRules.money(math.round(state.taken * 100)))

		-- the scan list: what's still to scan first, then what's done; the rest counted
		local ordered: { Line } = {}
		for _, line in state.lines do
			if not line.done then
				table.insert(ordered, line)
			end
		end
		for _, line in state.lines do
			if line.done then
				table.insert(ordered, line)
			end
		end
		local count = #ordered
		for index, row in rows do
			local line = ordered[index]
			local shown = line ~= nil and (index < LIST_ROWS or count <= LIST_ROWS)
			row.frame.Visible = shown or (index == LIST_ROWS and count > LIST_ROWS)
			if shown and line then
				row.name.Text = (if line.done then "✔️ " else "") .. line.name
				row.name.TextColor3 = rgb(if line.done then C.doneInk else C.ink)
				row.picture.Image = pictureFor(line)
				row.picture.ImageTransparency = if line.done then 0.45 else 0
				row.price.Text = PaymentRules.money(math.round(line.price * 100))
			elseif index == LIST_ROWS and count > LIST_ROWS then
				row.picture.Image = ""
				row.name.Text = string.format(WORDS.more, count - (LIST_ROWS - 1))
				row.name.TextColor3 = rgb(C.soft)
				row.price.Text = ""
			end
		end
		scanTotal.Text = PaymentRules.money(state.total)
		chargeTotal.Text = PaymentRules.money(state.total)
		chargeButton.Text = string.format(WORDS.charge, PaymentRules.money(state.total))

		typeThis.Text = string.format("%d.%02d", state.payTotal // 100, state.payTotal % 100)

		local change = state.given - state.payTotal
		gave.Text = "💵 " .. string.format(WORDS.gave, PaymentRules.money(state.given))
		cashTotal.Text = string.format(WORDS.cashTotal, PaymentRules.money(state.payTotal))
		giveBack.Text = PaymentRules.money(change)
		givingOf.Text = string.format(WORDS.givingOf, PaymentRules.money(state.giving), PaymentRules.money(change))
		givingOf.TextColor3 = rgb(if state.giving > change then C.bad elseif state.giving == change then C.doneInk else C.soft)
		local share = if change > 0 then math.clamp(state.giving / change, 0, 1) else 0
		fill.Size = UDim2.new(share, 0, 1, 0)
		fill.BackgroundColor3 = rgb(if state.giving > change then C.bad else C.go)
		local exact = state.giving == change
		giveButton.BackgroundColor3 = rgb(if exact then C.go else C.off)
		giveButton.TextColor3 = rgb(if exact then C.goInk else C.soft)
		giveButton.Text = if exact then WORDS.exact else WORDS.give -- exact change gives itself (RegisterStationController)
		givePulse.Enabled = exact

		errorLabel.Text = state.error
		errorLabel.Visible = state.error ~= ""
		errorLabel.BackgroundTransparency = if state.error ~= "" then 0 else 1
	end

	-- a sale: "SOLD! +$12.50" in green over everything, popping in and fading (owner 2026-11-16)
	local soldBox = box(gui, "Sold", 10, 10, WIDTH - 20, HEIGHT - 20, RegisterStation.SALE_FX.soldColor)
	soldBox.ZIndex = 8
	soldBox.Visible = false
	corner(soldBox, 26)
	local soldWords = text(soldBox, "", 0, 0, WIDTH - 20, HEIGHT - 20, 64, { 255, 255, 255 }, Enum.TextXAlignment.Center)
	soldWords.ZIndex = 9
	local soldEdge = Instance.new("UIStroke")
	soldEdge.Color = Color3.fromRGB(27, 107, 58)
	soldEdge.Thickness = 4
	soldEdge.Parent = soldWords
	local soldScale = Instance.new("UIScale")
	soldScale.Parent = soldBox
	local soldAt = 0
	local function sold(words: string)
		soldAt = os.clock()
		local mine = soldAt
		soldWords.Text = words
		soldBox.BackgroundTransparency = 0.05
		soldWords.TextTransparency = 0
		soldEdge.Transparency = 0
		soldScale.Scale = 0.6
		soldBox.Visible = true
		TweenService:Create(soldScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(RegisterStation.SALE_FX.soldSeconds, function()
			if soldAt ~= mine then
				return
			end
			local fade = TweenInfo.new(0.3)
			TweenService:Create(soldBox, fade, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(soldWords, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(soldEdge, fade, { Transparency = 1 }):Play()
			task.delay(0.3, function()
				if soldAt == mine then
					soldBox.Visible = false
				end
			end)
		end)
	end

	return { gui = gui, set = set, sold = sold }
end

return RegisterScreen
