--!strict
-- Pack opening: the "Rip a pack" button (while carrying a box of packs) and the opening screen.
-- Tap the pack to tear it, then tap each face-down card to flip it. The hit slot flips last. Better pulls
-- tease first (the card glows in its rarity colour and shakes), then celebrate: sparks, confetti, a banner,
-- and a big spotlight for Epic and up (Config/CardReveal). The server already rolled the cards; this only
-- plays the reveal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CardDesign = require(Config:WaitForChild("CardDesign"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local CardReveal = require(Config:WaitForChild("CardReveal"))
local Cards = require(Config:WaitForChild("Cards"))
local Packs = require(Config:WaitForChild("Packs"))
local PackOpening = require(Config:WaitForChild("PackOpening"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local RevealRules = require(Shared:WaitForChild("Util"):WaitForChild("RevealRules"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))
local AnnouncementController = require(Controllers:WaitForChild("AnnouncementController"))

type Card = typeof(Cards.List[1])
type Pack = typeof(Packs.ById[""])
type PullResult = { cardId: string, foil: boolean, grade: string }
type Plan = RevealRules.Plan

type CardView = {
	card: Card,
	foil: boolean,
	grade: string,
	button: TextButton,
	inner: Frame,
	stroke: UIStroke,
	glow: ImageLabel, -- the tease glow behind the card
	plan: Plan,
	flipped: boolean,
}

local RIP_WAIT_SECONDS = 3 -- re-enable the button if the server never answers
local RIP_KEY = Enum.KeyCode.T -- rips a pack, then advances the opening screen (tear → flip → done)
local BACKDROP_TRANSPARENCY = 0.25
local WHITE = Color3.new(1, 1, 1)
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(120, 230, 120),
	Color3.fromRGB(200, 120, 255),
}

local player = Players.LocalPlayer

local PackOpeningController = {}

local ripButton: TextButton
local gui: ScreenGui
local boxLabel: TextLabel
local packButton: TextButton
local cardRow: Frame
local statusLabel: TextLabel
local doneButton: TextButton
local oddsPanel: TextLabel
local flash: Frame
local backdrop: Frame
local fxLayer: Frame -- sparks, confetti and banners float here, above the cards
local spotlight: Instance? = nil -- the big card view; a tap (or T) closes it
local closeSpotlight: (() -> ())? = nil

local isOpening = false
local waitingForServer = false
local tearing = false
local busy = false -- a flip is animating
local pendingResults: { PullResult }? = nil
local views: { CardView } = {}
local flippedCount = 0

local function tween(instance: Instance, seconds: number, goals: { [string]: any }, style: Enum.EasingStyle?): Tween
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t = TweenService:Create(instance, info, goals)
	t:Play()
	return t
end

local function playSound(soundId: string)
	if soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Parent = SoundService
	SoundService:PlayLocalSound(sound)
	task.delay(5, function()
		sound:Destroy()
	end)
end

local function getCardValue(view: CardView): number
	return CardRules.getMarketValue(view.card, view.foil, 1, BeastRules.START_STARS, view.grade)
end

local function buildOddsText(pack: Pack): string
	local lines = { `{pack.name} pack odds` }
	for index, slot in pack.slots do
		local total = 0
		for _, option in slot do
			total += option.weight
		end
		local parts = {}
		for _, option in slot do
			table.insert(parts, string.format("%s %g%%", option.rarity, option.weight / total * 100))
		end
		table.insert(lines, `Card {index}: {table.concat(parts, " / ")}`)
	end
	table.insert(lines, string.format("Any card can be Foil (%gx value): %g%%", Rarities.FOIL_MULTIPLIER, Rarities.FOIL_CHANCE * 100))
	return table.concat(lines, "\n")
end

local function getPacksLeft(): number
	local units = player:GetAttribute("CarryUnits")
	return if typeof(units) == "number" then units else 0
end

-- Ripping is offered while carrying a box whose product is a pack
local function refreshRipButton()
	local productId = player:GetAttribute("CarryProductId")
	local carryingPacks = typeof(productId) == "string" and Packs.ById[productId] ~= nil
	local left = getPacksLeft()
	ripButton.Visible = carryingPacks and not isOpening
	ripButton.Text = `Rip a pack (T)\n{left} left`
	boxLabel.Text = if carryingPacks then `{left} packs left in box` else "Box empty"
end

local function onRip()
	if waitingForServer or isOpening then
		return
	end
	waitingForServer = true
	Remotes.RipPack:FireServer()
	task.delay(RIP_WAIT_SECONDS, function()
		waitingForServer = false
	end)
end

local function flipCard(view: CardView)
	playSound(PackOpening.FLIP_SOUND_ID)
	tween(view.inner, PackOpening.FLIP_SECONDS, { Size = UDim2.fromScale(0, 1) }).Completed:Wait()
	CardFace.render(view.inner, view.stroke, view.card, view.foil, true, { level = 1, stars = BeastRules.START_STARS, grade = view.grade })
	tween(view.inner, PackOpening.FLIP_SECONDS, { Size = UDim2.fromScale(1, 1) }).Completed:Wait()
end

local function getRevealColor(view: CardView): Color3
	return if CardFace.isFrontier(view.card) then CardEffects.FRONTIER.AURORA[1] else CardFace.getRarityColor(view.card.rarity)
end

local function flashScreen()
	flash.BackgroundTransparency = 0
	flash.Visible = true
	tween(flash, PackOpening.FLASH_SECONDS, { BackgroundTransparency = 1 }).Completed:Wait()
	flash.Visible = false
end

local function setDim(dim: number, seconds: number)
	tween(backdrop, seconds, { BackgroundTransparency = BACKDROP_TRANSPARENCY * (1 - dim) })
end

-- Before the flip: the face-down card glows in its rarity colour, breathes and shakes, building up
local function tease(view: CardView)
	local plan = view.plan
	if plan.tease <= 0 then
		return
	end
	local color = getRevealColor(view)
	view.glow.ImageColor3 = color
	view.glow.Visible = true
	view.stroke.Color = color
	setDim(plan.dim, plan.tease / 2)

	local breath = CardReveal.TEASE_PULSE_SECONDS
	local elapsed = 0
	local wobble = 1
	while elapsed < plan.tease do
		local strength = 0.4 + 0.6 * elapsed / plan.tease
		local glowSize = 1.5 + 0.5 * strength
		tween(view.glow, breath, { ImageTransparency = 0.6 - 0.5 * strength, Size = UDim2.fromScale(glowSize, glowSize) })
		tween(view.inner, breath / 2, { Rotation = plan.shake * strength * wobble })
		tween(view.stroke, breath, { Thickness = 3 + 5 * strength })
		wobble = -wobble
		task.wait(breath)
		elapsed += breath
	end
	tween(view.inner, 0.08, { Rotation = 0 })
	playSound(PackOpening.HIT_SOUND_IDS[view.card.rarity] or "")
end

-- Sparks flying out from a point on the screen
local function burst(center: Vector2, count: number, color: Color3, parent: Instance)
	for _ = 1, count do
		local spark = Instance.new("ImageLabel")
		spark.BackgroundTransparency = 1
		spark.Image = CardDesign.IMAGES.GLOW
		spark.ImageColor3 = if math.random() < 0.35 then WHITE else color
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		local size = math.random(14, 34)
		spark.Size = UDim2.fromOffset(size, size)
		spark.Position = UDim2.fromOffset(center.X, center.Y)
		spark.ZIndex = 30
		spark.Parent = parent
		local angle = math.random() * math.pi * 2
		local goal = center + Vector2.new(math.cos(angle), math.sin(angle)) * math.random(120, 320)
		tween(spark, CardReveal.BURST_SECONDS, { Position = UDim2.fromOffset(goal.X, goal.Y), ImageTransparency = 1, Size = UDim2.fromOffset(4, 4) })
		task.delay(CardReveal.BURST_SECONDS, function()
			spark:Destroy()
		end)
	end
end

local function confetti(count: number, parent: GuiObject)
	local width = parent.AbsoluteSize.X
	local height = parent.AbsoluteSize.Y
	for _ = 1, count do
		local piece = Instance.new("Frame")
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)]
		piece.Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22))
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		local x = math.random() * width
		piece.Position = UDim2.fromOffset(x, -20 - math.random() * height * 0.3)
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 29
		piece.Parent = parent
		local seconds = CardReveal.CONFETTI_SECONDS * (0.7 + math.random() * 0.5)
		local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(piece, info, {
			Position = UDim2.fromOffset(x + math.random(-120, 120), height + 30),
			Rotation = piece.Rotation + math.random(-540, 540),
		}):Play()
		task.delay(seconds, function()
			piece:Destroy()
		end)
	end
end

-- A word that pops in (RARE!, LEGENDARY!), its bottom centre at a point
local function showBanner(text: string, color: Color3, bottom: Vector2, width: number, parent: Instance): TextLabel
	local banner = Instance.new("TextLabel")
	banner.BackgroundTransparency = 1
	banner.AnchorPoint = Vector2.new(0.5, 1)
	banner.Position = UDim2.fromOffset(bottom.X, bottom.Y)
	banner.Size = UDim2.fromOffset(math.max(width, 220), 64)
	banner.Font = Enum.Font.FredokaOne
	banner.Text = text
	banner.TextColor3 = color:Lerp(WHITE, 0.25)
	banner.TextScaled = true
	banner.ZIndex = 31
	banner.Parent = parent
	local outline = Instance.new("UIStroke")
	outline.Color = color:Lerp(Color3.new(0, 0, 0), 0.6)
	outline.Thickness = 3
	outline.Parent = banner
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = banner
	local info = TweenInfo.new(CardReveal.BANNER_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(scale, info, { Scale = 1 }):Play()
	return banner
end

-- Light rays turning behind a point: thin bars fading outwards, each on its own turned pivot
local function addRays(parent: Instance, center: Vector2, radius: number, color: Color3)
	local holder = Instance.new("Frame")
	holder.Name = "Rays"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(center.X, center.Y)
	holder.Size = UDim2.fromOffset(radius * 2, radius * 2)
	holder.ZIndex = 21
	holder.Parent = parent
	for index = 1, CardReveal.RAY_COUNT do
		local pivot = Instance.new("Frame")
		pivot.BackgroundTransparency = 1
		pivot.AnchorPoint = Vector2.new(0.5, 0.5)
		pivot.Position = UDim2.fromScale(0.5, 0.5)
		pivot.Size = UDim2.fromScale(1, 1)
		pivot.Rotation = index * 360 / CardReveal.RAY_COUNT
		pivot.ZIndex = 21
		pivot.Parent = holder

		local ray = Instance.new("Frame")
		ray.BorderSizePixel = 0
		ray.AnchorPoint = Vector2.new(0.5, 1)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromScale(0.12, 0.5)
		ray.BackgroundColor3 = color:Lerp(WHITE, 0.3)
		ray.ZIndex = 21
		ray.Parent = pivot
		local fade = Instance.new("UIGradient")
		fade.Rotation = -90
		fade.Transparency = NumberSequence.new(0.35, 1)
		fade.Parent = ray
	end
	local info = TweenInfo.new(CardReveal.RAY_TURN_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)
	TweenService:Create(holder, info, { Rotation = 360 }):Play()
end

local function getCenter(object: GuiObject): Vector2
	return object.AbsolutePosition + object.AbsoluteSize / 2
end

-- Epic and up: the card big in the middle with a glow (and rays), until the player taps
local function showSpotlight(view: CardView)
	local plan = view.plan
	local color = getRevealColor(view)
	local overlay = Instance.new("TextButton")
	overlay.Name = "Spotlight"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.25
	overlay.ZIndex = 20
	overlay.Parent = gui

	local cardSize = view.button.AbsoluteSize * CardReveal.SPOTLIGHT_SCALE
	local maxHeight = overlay.AbsoluteSize.Y * CardReveal.SPOTLIGHT_MAX_HEIGHT
	if cardSize.Y > maxHeight then
		cardSize *= maxHeight / cardSize.Y
	end
	local center = overlay.AbsoluteSize / 2 + Vector2.new(0, cardSize.Y * 0.04)
	if plan.rays then
		addRays(overlay, center, cardSize.Y * 1.1, color)
	end

	local glow = Instance.new("ImageLabel")
	glow.BackgroundTransparency = 1
	glow.Image = CardDesign.IMAGES.GLOW
	glow.ImageColor3 = color
	glow.ImageTransparency = 0.15
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromOffset(center.X, center.Y)
	glow.Size = UDim2.fromOffset(cardSize.Y * 1.5, cardSize.Y * 1.5)
	glow.ZIndex = 22
	glow.Parent = overlay

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromOffset(center.X, center.Y)
	card.Size = UDim2.fromOffset(cardSize.X, cardSize.Y)
	card.ZIndex = 23
	card.Parent = overlay
	UIKit.corner(card, 16)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card
	CardFace.render(card, stroke, view.card, view.foil, true, { level = 1, stars = BeastRules.START_STARS, grade = view.grade })
	stroke.Thickness = 6
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = card
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	if plan.banner then
		showBanner(plan.banner, color, center - Vector2.new(0, cardSize.Y / 2 + 8), cardSize.X * 1.4, overlay)
	end
	local hint = UIKit.label(overlay, "Tap to continue", Enum.Font.GothamBold, 20, UIKit.Colors.Subtext)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.fromOffset(center.X, center.Y + cardSize.Y / 2 + 12)
	hint.Size = UDim2.fromOffset(260, 30)
	hint.ZIndex = 31

	burst(center, plan.burst, color, overlay)
	if plan.confetti > 0 then
		confetti(plan.confetti, overlay)
	end

	local closed = Instance.new("BindableEvent")
	local function closeIt()
		if spotlight ~= overlay then
			return
		end
		spotlight = nil
		closeSpotlight = nil
		overlay:Destroy()
		closed:Fire()
	end
	spotlight = overlay
	closeSpotlight = closeIt
	-- A short pause first, so a double tap on the flip doesn't skip the moment
	task.delay(CardReveal.SPOTLIGHT_TAP_DELAY, function()
		overlay.Activated:Connect(closeIt)
	end)
	closed.Event:Wait()
	closed:Destroy()
end

-- After the flip: sparks, confetti and a banner by the card, or the spotlight for big pulls
local function celebrate(view: CardView)
	local plan = view.plan
	if plan.flash then
		task.spawn(flashScreen)
	end
	if plan.tease > 0 then
		-- The glow stays behind the card, softer
		tween(view.glow, 0.4, { ImageTransparency = 0.3, Size = UDim2.fromScale(1.5, 1.5) })
	end
	if plan.spotlight then
		showSpotlight(view)
		setDim(0, 0.3)
		return
	end
	local color = getRevealColor(view)
	local center = getCenter(view.button)
	burst(center, plan.burst, color, fxLayer)
	if plan.confetti > 0 then
		confetti(plan.confetti, fxLayer)
	end
	local text = plan.banner
	if text then
		local size = view.button.AbsoluteSize
		local banner = showBanner(text, color, center - Vector2.new(0, size.Y / 2), size.X * 1.3, fxLayer)
		task.delay(CardReveal.BANNER_HOLD_SECONDS, function()
			tween(banner, 0.3, { TextTransparency = 1 })
			task.delay(0.3, function()
				banner:Destroy()
			end)
		end)
	end
	setDim(0, 0.4)
end

local function finish()
	local total = 0
	for _, view in views do
		total += getCardValue(view)
	end
	statusLabel.Text = string.format("Pack value: $%.2f", total)
	doneButton.Visible = true
end

local function onCardTapped(view: CardView)
	if busy or view.flipped then
		return
	end
	local isHit = view == views[#views]
	if isHit and flippedCount < #views - 1 then
		statusLabel.Text = "Flip the others first!"
		return
	end

	busy = true
	tease(view)
	flipCard(view)
	view.flipped = true
	flippedCount += 1
	celebrate(view)
	-- Big pulls go to chat only now that they're revealed: ours locally, everyone else via the server
	if CardRules.shouldAnnounce(view.card, view.foil) then
		AnnouncementController.Show(player.DisplayName, view.card, view.foil)
		Remotes.PullRevealed:FireServer(view.card.id, view.foil)
	end
	busy = false

	if flippedCount == #views then
		finish()
	elseif not isHit then
		statusLabel.Text = if flippedCount == #views - 1 then "Now the big one..." else "Tap the cards to flip them"
	end
end

local function makeCardView(card: Card, foil: boolean, grade: string, order: number): CardView
	local button = Instance.new("TextButton")
	button.Name = "Card" .. order
	button.LayoutOrder = order
	button.Size = UDim2.fromScale(0.18, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = cardRow

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 0.7
	aspect.Parent = button

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(1, 1)
	inner.Parent = button
	UIKit.corner(inner, 10)

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = inner

	CardFace.renderBack(inner, stroke)
	inner.ZIndex = 2

	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.Image = CardDesign.IMAGES.GLOW
	glow.ImageTransparency = 0.6
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.5, 1.5)
	glow.ZIndex = 1
	glow.Visible = false
	glow.Parent = button

	local view: CardView = {
		card = card,
		foil = foil,
		grade = grade,
		button = button,
		inner = inner,
		stroke = stroke,
		glow = glow,
		plan = RevealRules.plan(CardReveal, card.rarity, foil, CardFace.isFrontier(card)),
		flipped = false,
	}
	button.Activated:Connect(function()
		onCardTapped(view)
	end)
	return view
end

local function clearCards()
	for _, view in views do
		view.button:Destroy()
	end
	table.clear(views)
	flippedCount = 0
end

local function dealCards(results: { PullResult })
	-- No flipping until every card is down, so the last card is really the hit slot
	busy = true
	cardRow.Visible = true
	statusLabel.Text = "Tap the cards to flip them"
	for index, result in results do
		local card = Cards.ById[result.cardId]
		if card then
			local grade = if BeastRules.isGrade(result.grade) then result.grade else BeastRules.DEFAULT_GRADE
			table.insert(views, makeCardView(card, result.foil == true, grade, index))
			task.wait(PackOpening.DEAL_DELAY)
		end
	end
	busy = false
end

local function tearPack()
	local results = pendingResults
	if tearing or not results then
		return
	end
	tearing = true
	pendingResults = nil
	playSound(PackOpening.TEAR_SOUND_ID)

	local shake = PackOpening.TEAR_SECONDS / 4
	tween(packButton, shake, { Rotation = 6 }).Completed:Wait()
	tween(packButton, shake, { Rotation = -6 }).Completed:Wait()
	tween(packButton, shake * 2, {
		Rotation = 0,
		Size = UDim2.fromScale(0.4, 0.75),
		BackgroundTransparency = 1,
		TextTransparency = 1,
	}).Completed:Wait()

	packButton.Visible = false
	packButton.Size = UDim2.fromScale(0.22, 0.55)
	packButton.BackgroundTransparency = 0
	packButton.TextTransparency = 0
	tearing = false
	dealCards(results)
end

local function close()
	if closeSpotlight then
		closeSpotlight()
	end
	setDim(0, 0)
	gui.Enabled = false
	oddsPanel.Visible = false
	clearCards()
	isOpening = false
	refreshRipButton()
end

local function onPackOpened(productId: string, results: { PullResult })
	waitingForServer = false
	local pack = Packs.ById[productId]
	if not pack or typeof(results) ~= "table" then
		return
	end

	clearCards()
	isOpening = true
	refreshRipButton()
	pendingResults = results

	packButton.BackgroundColor3 = pack.color
	packButton.Text = `{string.upper(pack.name)}\n\nTap to open!`
	packButton.Visible = true
	cardRow.Visible = false
	doneButton.Visible = false
	statusLabel.Text = ""
	oddsPanel.Text = buildOddsText(pack)
	gui.Enabled = true
end

local function buildScreen()
	gui = Instance.new("ScreenGui")
	gui.Name = "PackOpening"
	gui.DisplayOrder = 10 -- above the main HUD
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = BACKDROP_TRANSPARENCY
	backdrop.Active = true -- swallow taps so the world behind isn't clicked
	backdrop.Parent = gui

	packButton = UIKit.button(gui, "", Color3.new(1, 1, 1))
	packButton.Name = "Pack"
	packButton.AnchorPoint = Vector2.new(0.5, 0.5)
	packButton.Position = UDim2.fromScale(0.5, 0.48)
	packButton.Size = UDim2.fromScale(0.22, 0.55)
	packButton.Font = Enum.Font.FredokaOne
	packButton.TextScaled = true
	packButton.Activated:Connect(tearPack)
	local packAspect = Instance.new("UIAspectRatioConstraint")
	packAspect.AspectRatio = 0.65
	packAspect.Parent = packButton

	cardRow = Instance.new("Frame")
	cardRow.Name = "Cards"
	cardRow.AnchorPoint = Vector2.new(0.5, 0.5)
	cardRow.Position = UDim2.fromScale(0.5, 0.47)
	cardRow.Size = UDim2.fromScale(0.96, 0.5)
	cardRow.BackgroundTransparency = 1
	cardRow.Visible = false
	cardRow.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.012, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = cardRow

	statusLabel = UIKit.label(gui, "", Enum.Font.GothamBold, 22, UIKit.Colors.Text)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center
	statusLabel.AnchorPoint = Vector2.new(0.5, 0)
	statusLabel.Position = UDim2.new(0.5, 0, 0.73, 0)
	statusLabel.Size = UDim2.new(0.9, 0, 0, 32)

	doneButton = UIKit.button(gui, "Done", UIKit.Colors.Accent)
	doneButton.Name = "Done"
	doneButton.AnchorPoint = Vector2.new(0.5, 0)
	doneButton.Position = UDim2.new(0.5, 0, 0.73, 36)
	doneButton.Size = UDim2.fromOffset(160, 56)
	doneButton.Visible = false
	doneButton.Activated:Connect(close)

	local oddsButton = UIKit.button(gui, "Odds", UIKit.Colors.Row)
	oddsButton.Name = "OddsButton"
	oddsButton.AnchorPoint = Vector2.new(1, 0)
	oddsButton.Position = UDim2.new(1, -16, 0, 60)
	oddsButton.Size = UDim2.fromOffset(88, 48)

	oddsPanel = UIKit.label(gui, "", Enum.Font.Gotham, 16, UIKit.Colors.Text)
	oddsPanel.Name = "Odds"
	oddsPanel.AnchorPoint = Vector2.new(1, 0)
	oddsPanel.Position = UDim2.new(1, -16, 0, 116)
	oddsPanel.Size = UDim2.fromOffset(330, 190)
	oddsPanel.BackgroundTransparency = 0.05
	oddsPanel.BackgroundColor3 = UIKit.Colors.Panel
	oddsPanel.TextYAlignment = Enum.TextYAlignment.Top
	oddsPanel.ZIndex = 5
	oddsPanel.Visible = false
	UIKit.corner(oddsPanel, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 10)
	padding.Parent = oddsPanel
	oddsButton.Activated:Connect(function()
		oddsPanel.Visible = not oddsPanel.Visible
	end)

	boxLabel = UIKit.label(gui, "", Enum.Font.GothamBold, 18, UIKit.Colors.Text)
	boxLabel.Name = "PacksLeft"
	boxLabel.Position = UDim2.fromOffset(16, 64)
	boxLabel.Size = UDim2.fromOffset(260, 40)

	fxLayer = Instance.new("Frame")
	fxLayer.Name = "Fx"
	fxLayer.Size = UDim2.fromScale(1, 1)
	fxLayer.BackgroundTransparency = 1
	fxLayer.ZIndex = 15
	fxLayer.Parent = gui

	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.ZIndex = 40 -- above the spotlight
	flash.Visible = false
	flash.Parent = gui
end

-- T on the opening screen: tear the pack, else flip the next card, else close
local function advance()
	if closeSpotlight then
		closeSpotlight()
	elseif pendingResults then
		tearPack()
	elseif doneButton.Visible then
		close()
	else
		for _, view in views do
			if not view.flipped then
				onCardTapped(view)
				return
			end
		end
	end
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or input.KeyCode ~= RIP_KEY then
		return
	end
	if gui.Enabled then
		task.spawn(advance)
	elseif ripButton.Visible then
		onRip()
	end
end

function PackOpeningController.Start()
	ripButton = UIKit.button(UIController.GetScreenGui(), "", UIKit.Colors.Accent)
	ripButton.Name = "RipButton"
	-- Next to the Drop button on the middle-left
	ripButton.AnchorPoint = Vector2.new(0, 0.5)
	ripButton.Position = UDim2.new(0, 116, 0.5, 140)
	ripButton.Size = UDim2.fromOffset(130, 50)
	ripButton.TextSize = 16
	ripButton.Visible = false
	ripButton.Activated:Connect(onRip)

	buildScreen()
	refreshRipButton()

	player:GetAttributeChangedSignal("CarryProductId"):Connect(refreshRipButton)
	player:GetAttributeChangedSignal("CarryUnits"):Connect(refreshRipButton)
	UserInputService.InputBegan:Connect(onInputBegan)
	Remotes.PackOpened.OnClientEvent:Connect(onPackOpened)
end

return PackOpeningController
