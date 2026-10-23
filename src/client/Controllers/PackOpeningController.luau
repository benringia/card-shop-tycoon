--!strict
-- Pack opening: the "Rip a pack" button (while carrying a box of packs) and the opening screen.
-- A light stage with the pack floating in the middle: drag across it (or tap it) to tear the top off, and the
-- cards rise out as a stack. They are revealed one at a time, big in the middle; a tap (Space, T or the Next
-- button) slides the card away and shows the next. The hit slot comes last. Better pulls tease first (the
-- face-down card glows in its rarity colour and shakes), then celebrate: sparks, a banner, rays and confetti
-- for Epic and up (Config/CardReveal). After the last card, all of them line up in a summary row. The server already rolled the cards; this only plays the reveal.
local ContextActionService = game:GetService("ContextActionService")
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
local Hud = require(ClientUtil:WaitForChild("Hud"))
local AnnouncementController = require(Controllers:WaitForChild("AnnouncementController"))

type Card = typeof(Cards.List[1])
type Pack = typeof(Packs.ById[""])
type PullResult = { cardId: string, foil: boolean, grade: string }
type Plan = RevealRules.Plan
type Phase = "closed" | "pack" | "tearing" | "reveal" | "summary"

type CardView = {
	card: Card,
	foil: boolean,
	grade: string,
	slot: Frame, -- the card's place on the stage
	inner: Frame,
	stroke: UIStroke,
	glow: ImageLabel, -- the tease glow behind the card
	pop: UIScale,
	plan: Plan,
	revealed: boolean,
	announced: boolean,
}

local RIP_WAIT_SECONDS = 3 -- re-enable the button if the server never answers
local RIP_KEY = Enum.KeyCode.T -- rips a pack while the screen is closed
local ADVANCE_ACTION = "PackOpeningAdvance"
local CARD_ASPECT = 0.7
local ROUND_BUTTON = 76 -- pixels: the Next button
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local INK = Color3.fromRGB(28, 36, 66)
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(120, 230, 120),
	Color3.fromRGB(200, 120, 255),
}
local LOGO_COLORS = ColorSequence.new(Color3.fromRGB(255, 245, 150), Color3.fromRGB(255, 175, 40))

local player = Players.LocalPlayer

local PackOpeningController = {}

local ripButton: TextButton
local gui: ScreenGui
local stage: Frame
local dimmer: Frame
local raysLayer: Frame -- light rays behind the card being revealed
local cardLayer: Frame
local fxLayer: Frame -- sparks, confetti and banners float here, above the cards
local hintPill: Frame
local hintLabel: TextLabel
local summaryRow: Frame
local valueLabel: TextLabel
local doneButton: TextButton
local oddsButton: TextButton
local oddsPanel: TextLabel
local boxLabel: TextLabel
local flash: Frame

-- The pack
local packFrame: Frame
local packCap: Frame
local packBody: Frame
local packArt: ImageLabel
local packLogo: TextLabel
local tearLine: Frame
local packBob: Tween? = nil

local phase: Phase = "closed"
local waitingForServer = false
local busy = false -- a card is being revealed
local tapsLockedUntil = 0
local pendingResults: { PullResult }? = nil
local views: { CardView } = {}
local current = 0

-- Dragging across the pack
local dragging = false
local dragMinX = 0
local dragMaxX = 0
local dragStart = Vector2.zero

local function tween(instance: Instance, seconds: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
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
	ripButton.Visible = carryingPacks and phase == "closed"
	Hud.setLabel("Rip", `Rip · {left}`)
	boxLabel.Text = if carryingPacks then `{left} packs left in box` else "Box empty"
end

local function onRip()
	if waitingForServer or phase ~= "closed" then
		return
	end
	waitingForServer = true
	Remotes.RipPack:FireServer()
	task.delay(RIP_WAIT_SECONDS, function()
		waitingForServer = false
	end)
end

-- The dark hint pill: at the top over the pack, at the bottom while cards are revealed (clear of the banners)
local function setHint(text: string?, bottom: boolean?)
	hintPill.Visible = text ~= nil
	hintLabel.Text = text or ""
	hintPill.AnchorPoint = Vector2.new(0.5, if bottom then 1 else 0)
	hintPill.Position = if bottom then UDim2.new(0.5, 0, 1, -PackOpening.EDGE) else UDim2.new(0.5, 0, 0, PackOpening.TOP)
end

local function getRevealColor(view: CardView): Color3
	return if CardFace.isFrontier(view.card) then CardEffects.FRONTIER.AURORA[1] else CardFace.getRarityColor(view.card.rarity)
end

local function renderFace(view: CardView)
	CardFace.render(view.inner, view.stroke, view.card, view.foil, true, { level = 1, stars = BeastRules.START_STARS, grade = view.grade })
end

local function flipCard(view: CardView)
	playSound(PackOpening.FLIP_SOUND_ID)
	tween(view.inner, PackOpening.FLIP_SECONDS, { Size = UDim2.fromScale(0, 1) }).Completed:Wait()
	renderFace(view)
	tween(view.inner, PackOpening.FLIP_SECONDS, { Size = UDim2.fromScale(1, 1) }).Completed:Wait()
end

local function flashScreen()
	flash.BackgroundTransparency = 0
	flash.Visible = true
	tween(flash, PackOpening.FLASH_SECONDS, { BackgroundTransparency = 1 }).Completed:Wait()
	flash.Visible = false
end

local function setDim(dim: number, seconds: number)
	tween(dimmer, seconds, { BackgroundTransparency = 1 - PackOpening.STAGE.DIM * dim })
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
local function showBanner(text: string, color: Color3, bottom: Vector2, width: number, height: number, parent: Instance): TextLabel
	local banner = Instance.new("TextLabel")
	banner.BackgroundTransparency = 1
	banner.AnchorPoint = Vector2.new(0.5, 1)
	banner.Position = UDim2.fromOffset(bottom.X, bottom.Y)
	banner.Size = UDim2.fromOffset(math.max(width, 220), height)
	banner.Font = Enum.Font.FredokaOne
	banner.Text = text
	banner.TextColor3 = color:Lerp(WHITE, 0.25)
	banner.TextScaled = true
	banner.Parent = parent
	local outline = Instance.new("UIStroke")
	outline.Color = color:Lerp(BLACK, 0.6)
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
	holder.Parent = parent
	for index = 1, CardReveal.RAY_COUNT do
		local pivot = Instance.new("Frame")
		pivot.BackgroundTransparency = 1
		pivot.AnchorPoint = Vector2.new(0.5, 0.5)
		pivot.Position = UDim2.fromScale(0.5, 0.5)
		pivot.Size = UDim2.fromScale(1, 1)
		pivot.Rotation = index * 360 / CardReveal.RAY_COUNT
		pivot.Parent = holder

		local ray = Instance.new("Frame")
		ray.BorderSizePixel = 0
		ray.AnchorPoint = Vector2.new(0.5, 1)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromScale(0.12, 0.5)
		ray.BackgroundColor3 = color:Lerp(WHITE, 0.3)
		ray.Parent = pivot
		local fade = Instance.new("UIGradient")
		fade.Rotation = -90
		fade.Transparency = NumberSequence.new(0.35, 1)
		fade.Parent = ray
	end
	local info = TweenInfo.new(CardReveal.RAY_TURN_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)
	TweenService:Create(holder, info, { Rotation = 360 }):Play()
end

-- Removes what was drawn on a layer, keeping its layout objects
local function clearLayer(layer: Frame)
	for _, child in layer:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- An object's centre in the stage's own coordinates (the rays and effects layers fill the stage)
local function getCenter(object: GuiObject): Vector2
	return object.AbsolutePosition - stage.AbsolutePosition + object.AbsoluteSize / 2
end

-- Big pulls go to chat only once they're revealed: ours locally, everyone else via the server
local function announce(view: CardView)
	if view.announced then
		return
	end
	view.announced = true
	if CardRules.shouldAnnounce(view.card, view.foil) then
		AnnouncementController.Show(player.DisplayName, view.card, view.foil)
		Remotes.PullRevealed:FireServer(view.card.id, view.foil)
	end
end

-- After the flip: sparks and a banner by the card; rays, confetti and a pop for big pulls
local function celebrate(view: CardView)
	local plan = view.plan
	if plan.flash then
		task.spawn(flashScreen)
	end
	if plan.tease > 0 then
		-- The glow stays behind the card, softer
		tween(view.glow, 0.4, { ImageTransparency = 0.3, Size = UDim2.fromScale(1.5, 1.5) })
	end
	local color = getRevealColor(view)
	local center = getCenter(view.slot)
	local size = view.slot.AbsoluteSize
	if plan.rays then
		addRays(raysLayer, center, size.Y * 1.1, color)
	end
	if plan.spotlight then
		tween(view.pop, 0.35, { Scale = CardReveal.SPOTLIGHT_POP }, Enum.EasingStyle.Back)
		tapsLockedUntil = os.clock() + CardReveal.SPOTLIGHT_TAP_DELAY
	end
	burst(center, plan.burst, color, fxLayer)
	if plan.confetti > 0 then
		confetti(plan.confetti, fxLayer)
	end
	if plan.banner then
		-- Above the card, but never under Roblox's top bar: on short (phone) screens it overlaps the card's top
		local layout = PackOpening.BANNER
		local height = math.clamp(size.Y * layout.SCALE, layout.MIN, layout.MAX)
		local bottom = math.max(center.Y - size.Y / 2 + 6, PackOpening.TOP + height)
		local banner = showBanner(plan.banner, color, Vector2.new(center.X, bottom), size.X * 1.3, height, fxLayer)
		task.delay(CardReveal.BANNER_HOLD_SECONDS, function()
			tween(banner, 0.3, { TextTransparency = 1 })
			task.delay(0.3, function()
				banner:Destroy()
			end)
		end)
	end
	setDim(0, 0.4)
end

-- The pack's crimped edge: rotated squares half over the edge, so their outer halves read as teeth
local function addTeeth(parent: Frame, edge: number, color: Color3)
	local teeth = PackOpening.PACK.TEETH
	for index = 1, teeth do
		local tooth = Instance.new("Frame")
		tooth.Name = "Tooth"
		tooth.AnchorPoint = Vector2.new(0.5, 0.5)
		tooth.Position = UDim2.fromScale((index - 0.5) / teeth, edge)
		tooth.Size = UDim2.fromScale(0.72 / teeth, 0.72 / teeth)
		tooth.SizeConstraint = Enum.SizeConstraint.RelativeXX
		tooth.Rotation = 45
		tooth.BackgroundColor3 = color
		tooth.BorderSizePixel = 0
		tooth.ZIndex = 0
		tooth.Parent = parent
		local square = Instance.new("UIAspectRatioConstraint")
		square.AspectRatio = 1
		square.DominantAxis = Enum.DominantAxis.Width
		square.Parent = tooth
	end
end

local function startBob()
	if packBob then
		packBob:Cancel()
	end
	packFrame.Position = UDim2.new(0.5, 0, PackOpening.PACK.Y, 0)
	local info = TweenInfo.new(PackOpening.PACK.BOB_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	packBob = TweenService:Create(packFrame, info, { Position = UDim2.new(0.5, 0, PackOpening.PACK.Y, -PackOpening.PACK.BOB_PIXELS) })
	;(packBob :: Tween):Play()
end

-- The pack: an illustrated front with the logo, a crimped strip on top that tears off along the dashed line
local function buildPack(parent: Instance)
	local look = PackOpening.PACK
	packFrame = Instance.new("Frame")
	packFrame.Name = "Pack"
	packFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	packFrame.Position = UDim2.fromScale(0.5, PackOpening.PACK.Y)
	packFrame.Size = UDim2.fromScale(1, look.HEIGHT)
	packFrame.BackgroundTransparency = 1
	packFrame.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = look.ASPECT
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = packFrame

	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.BackgroundTransparency = 1
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.fromScale(0.5, 0.55)
	shadow.Size = UDim2.fromScale(1.6, 1.3)
	shadow.Image = CardDesign.IMAGES.GLOW
	shadow.ImageColor3 = WHITE
	shadow.ImageTransparency = 0.2
	shadow.ZIndex = 0
	shadow.Parent = packFrame

	packBody = Instance.new("Frame")
	packBody.Name = "Body"
	packBody.Position = UDim2.fromScale(0, look.CAP)
	packBody.Size = UDim2.fromScale(1, 1 - look.CAP)
	packBody.BorderSizePixel = 0
	packBody.ZIndex = 1
	packBody.Parent = packFrame

	packArt = Instance.new("ImageLabel")
	packArt.Name = "Art"
	packArt.BackgroundTransparency = 1
	packArt.Size = UDim2.fromScale(1, 1)
	packArt.ScaleType = Enum.ScaleType.Crop
	packArt.ZIndex = 2
	packArt.Parent = packBody

	-- A soft glossy sheen down the left side, like foil catching the light
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.Size = UDim2.fromScale(1, 1)
	gloss.BackgroundColor3 = WHITE
	gloss.BorderSizePixel = 0
	gloss.ZIndex = 3
	gloss.Parent = packBody
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 20
	sheen.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75),
		NumberSequenceKeypoint.new(0.18, 1),
		NumberSequenceKeypoint.new(0.8, 1),
		NumberSequenceKeypoint.new(1, 0.85),
	})
	sheen.Parent = gloss

	packLogo = Instance.new("TextLabel")
	packLogo.Name = "Logo"
	packLogo.BackgroundTransparency = 1
	packLogo.AnchorPoint = Vector2.new(0.5, 0)
	packLogo.Position = UDim2.fromScale(0.5, 0.04)
	packLogo.Size = UDim2.fromScale(0.9, 0.14)
	packLogo.Font = Enum.Font.FredokaOne
	packLogo.TextColor3 = WHITE
	packLogo.TextScaled = true
	packLogo.ZIndex = 4
	packLogo.Parent = packBody
	local logoColor = Instance.new("UIGradient")
	logoColor.Color = LOGO_COLORS
	logoColor.Rotation = 90
	logoColor.Parent = packLogo
	local logoEdge = Instance.new("UIStroke")
	logoEdge.Color = Color3.fromRGB(90, 30, 10)
	logoEdge.Thickness = 3
	logoEdge.Parent = packLogo

	local tagline = UIKit.label(packBody, "TRADING CARD GAME", Enum.Font.FredokaOne, 14, WHITE)
	tagline.Name = "Tagline"
	tagline.AnchorPoint = Vector2.new(0.5, 0)
	tagline.Position = UDim2.fromScale(0.5, 0.185)
	tagline.Size = UDim2.fromScale(0.62, 0.045)
	tagline.TextScaled = true
	tagline.TextXAlignment = Enum.TextXAlignment.Center
	tagline.BackgroundColor3 = INK
	tagline.BackgroundTransparency = 0.15
	tagline.ZIndex = 4
	UIKit.corner(tagline, 8)

	packCap = Instance.new("Frame")
	packCap.Name = "Cap"
	packCap.Size = UDim2.fromScale(1, look.CAP)
	packCap.BorderSizePixel = 0
	packCap.ZIndex = 1
	packCap.Parent = packFrame

	local perforation = Instance.new("Frame")
	perforation.Name = "Perforation"
	perforation.AnchorPoint = Vector2.new(0, 0.5)
	perforation.Position = UDim2.fromScale(0, look.CAP)
	perforation.Size = UDim2.new(1, 0, 0, 2)
	perforation.BackgroundColor3 = WHITE
	perforation.BackgroundTransparency = 0.4
	perforation.BorderSizePixel = 0
	perforation.ZIndex = 5
	perforation.Parent = packFrame

	tearLine = Instance.new("Frame")
	tearLine.Name = "TearLine"
	tearLine.AnchorPoint = Vector2.new(0, 0.5)
	tearLine.Position = UDim2.fromScale(0, look.CAP)
	tearLine.Size = UDim2.fromOffset(0, 6)
	tearLine.BackgroundColor3 = WHITE
	tearLine.BorderSizePixel = 0
	tearLine.ZIndex = 6
	tearLine.Parent = packFrame
	UIKit.corner(tearLine, 3)
	local tearGlow = Instance.new("UIStroke")
	tearGlow.Color = Color3.fromRGB(255, 230, 140)
	tearGlow.Thickness = 2
	tearGlow.Parent = tearLine

	-- Taps and drags land here
	local grab = Instance.new("TextButton")
	grab.Name = "Grab"
	grab.Text = ""
	grab.BackgroundTransparency = 1
	grab.Size = UDim2.fromScale(1, 1)
	grab.ZIndex = 7
	grab.Parent = packFrame
	grab.InputBegan:Connect(function(input)
		local press = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		if not press or phase ~= "pack" then
			return
		end
		dragging = true
		dragStart = Vector2.new(input.Position.X, input.Position.Y)
		dragMinX = input.Position.X
		dragMaxX = input.Position.X
	end)
end

-- Colours and art for this pack
local function dressPack(pack: Pack)
	for _, part in { packCap, packBody } do
		part.BackgroundColor3 = pack.color
		for _, child in part:GetChildren() do
			if child.Name == "Tooth" then
				child:Destroy()
			end
		end
	end
	addTeeth(packCap, 0, pack.color:Lerp(WHITE, 0.35))
	addTeeth(packBody, 1, pack.color)
	local capShade = packCap:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	capShade.Color = ColorSequence.new(pack.color:Lerp(WHITE, 0.35), pack.color)
	capShade.Rotation = 90
	capShade.Parent = packCap
	packArt.Image = pack.art or ""
	packLogo.Text = string.upper(pack.name)
	packCap.Position = UDim2.fromScale(0, 0)
	packCap.Rotation = 0
	packCap.Visible = true
	tearLine.Size = UDim2.fromOffset(0, 6)
	packFrame.Visible = true
	startBob()
end

-- The dashed line under the finger: from the leftmost to the rightmost point dragged over
local function showTear(minX: number, maxX: number)
	local left = packFrame.AbsolutePosition.X
	local width = packFrame.AbsoluteSize.X
	local from = math.clamp(minX - left, 0, width)
	local to = math.clamp(maxX - left, 0, width)
	tearLine.Position = UDim2.new(0, from, PackOpening.PACK.CAP, 0)
	tearLine.Size = UDim2.fromOffset(to - from, 6)
end

local function makeCardView(card: Card, foil: boolean, grade: string, order: number, total: number): CardView
	local slot = Instance.new("Frame")
	slot.Name = "Card" .. order
	slot.AnchorPoint = Vector2.new(0.5, 0.5)
	slot.Position = UDim2.fromScale(0.5, PackOpening.CARD_Y)
	slot.Size = UDim2.fromScale(1, PackOpening.CARD_HEIGHT)
	slot.BackgroundTransparency = 1
	slot.ZIndex = total - order + 1 -- the first card on top of the stack
	slot.Parent = cardLayer
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = CARD_ASPECT
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = slot
	local pop = Instance.new("UIScale")
	pop.Parent = slot

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
	glow.Parent = slot

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(1, 1)
	inner.ZIndex = 2
	inner.Parent = slot
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = inner
	CardFace.renderBack(inner, stroke)

	return {
		card = card,
		foil = foil,
		grade = grade,
		slot = slot,
		inner = inner,
		stroke = stroke,
		glow = glow,
		pop = pop,
		plan = RevealRules.plan(CardReveal, card.rarity, foil, CardFace.isFrontier(card)),
		revealed = false,
		announced = false,
	}
end

local function clearCards()
	for _, view in views do
		view.slot:Destroy()
	end
	table.clear(views)
	clearLayer(raysLayer)
	clearLayer(fxLayer)
	clearLayer(summaryRow)
	current = 0
end

local function makeViews(results: { PullResult })
	for index, result in results do
		local card = Cards.ById[result.cardId]
		if card then
			local grade = if BeastRules.isGrade(result.grade) then result.grade else BeastRules.DEFAULT_GRADE
			table.insert(views, makeCardView(card, result.foil == true, grade, index, #results))
		end
	end
end

-- Every card in a row, popping in one after another, with the pack's value and Done
local function showSummary()
	phase = "summary"
	setHint(nil)
	setDim(0, 0.2)
	-- The row spans the screen, so the Odds button steps aside (it would sit on the last card on small phones)
	oddsButton.Visible = false
	oddsPanel.Visible = false
	clearLayer(raysLayer)
	local total = 0
	for index, view in views do
		announce(view)
		total += getCardValue(view)
		view.slot:Destroy()

		local holder = Instance.new("Frame")
		holder.Name = "Card" .. index
		holder.LayoutOrder = index
		-- Pixel widths: a list layout lines children up by their size before any aspect constraint
		local height = summaryRow.AbsoluteSize.Y
		holder.Size = UDim2.new(0, height * CARD_ASPECT, 1, 0)
		holder.BackgroundTransparency = 1
		holder.Parent = summaryRow
		local scale = Instance.new("UIScale")
		scale.Scale = 0
		scale.Parent = holder
		local face = Instance.new("Frame")
		face.Size = UDim2.fromScale(1, 1)
		face.Parent = holder
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = face
		CardFace.render(face, stroke, view.card, view.foil, true, { level = 1, stars = BeastRules.START_STARS, grade = view.grade })
		task.delay((index - 1) * PackOpening.SUMMARY_STAGGER, function()
			tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
	table.clear(views)
	summaryRow.Visible = true
	valueLabel.Text = string.format("Pack value: $%.2f", total)
	valueLabel.Visible = true
	doneButton.Visible = true
end

-- Shows the card on top of the stack: teased and flipped if it's a good one, face up at once if not
local function revealCard(index: number)
	local view = views[index]
	if not view then
		showSummary()
		return
	end
	busy = true
	current = index
	local step = if index == #views - 1 and #views > 1 then "Now the big one..." else "Tap for the next card"
	setHint(`{index} / {#views} · {step}`, true)
	tween(view.slot, 0.15, { Rotation = 0, Position = UDim2.fromScale(0.5, PackOpening.CARD_Y) })
	if view.plan.tease > 0 then
		tease(view)
		flipCard(view)
	else
		renderFace(view)
	end
	view.revealed = true
	celebrate(view)
	announce(view)
	busy = false
	if index == #views then
		setHint(`{index} / {#views} · Tap to see all your cards`, true)
	end
end

-- The revealed card slides off to the left; the next one comes up
local function nextCard()
	if busy or os.clock() < tapsLockedUntil then
		return
	end
	local view = views[current]
	if view then
		clearLayer(raysLayer)
		tween(view.slot, PackOpening.OUT_SECONDS, { Position = UDim2.fromScale(-0.4, 0.55), Rotation = -20 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	revealCard(current + 1)
end

-- The top flies off, the pack slides down out of view and the cards rise out of it as a stack
local function tearPack()
	local results = pendingResults
	if phase ~= "pack" or not results then
		return
	end
	phase = "tearing"
	pendingResults = nil
	dragging = false
	playSound(PackOpening.TEAR_SOUND_ID)
	if packBob then
		packBob:Cancel()
	end
	setHint(nil)

	local seconds = PackOpening.TEAR_SECONDS
	tween(packCap, seconds, { Position = UDim2.fromScale(0.25, -0.5), Rotation = 28 })
	task.wait(seconds * 0.5)
	makeViews(results)
	for index, view in views do
		view.slot.Position = UDim2.fromScale(0.5, 0.62)
		view.pop.Scale = 0.7
		tween(view.slot, PackOpening.RISE_SECONDS, { Position = UDim2.fromScale(0.5, PackOpening.CARD_Y), Rotation = (index - 1) * 3 }, Enum.EasingStyle.Back)
		tween(view.pop, PackOpening.RISE_SECONDS, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	tween(packFrame, seconds, { Position = UDim2.fromScale(0.5, 1.6) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
	packFrame.Visible = false
	phase = "reveal"
	task.wait(PackOpening.RISE_SECONDS * 0.5)
	revealCard(1)
end

-- A tap (or a key) on the pack: the tear line runs across by itself, then the pack tears
local function autoTear()
	if phase ~= "pack" then
		return
	end
	dragging = false
	local width = packFrame.AbsoluteSize.X
	tearLine.Position = UDim2.fromScale(0, PackOpening.PACK.CAP)
	tween(tearLine, PackOpening.AUTO_TEAR_SECONDS, { Size = UDim2.fromOffset(width, 6) }).Completed:Wait()
	tearPack()
end

local function close()
	phase = "closed"
	busy = false
	dragging = false
	if packBob then
		packBob:Cancel()
	end
	ContextActionService:UnbindAction(ADVANCE_ACTION)
	setDim(0, 0)
	clearCards()
	stage.Visible = false
	gui.Enabled = false
	oddsPanel.Visible = false
	refreshRipButton()
end

-- Space, T, Next or a tap on the stage: tear the pack, else the next card, else close
local function advance()
	if phase == "pack" then
		autoTear()
	elseif phase == "reveal" then
		nextCard()
	elseif phase == "summary" then
		close()
	end
end

local function onPackOpened(productId: string, results: { PullResult })
	waitingForServer = false
	local pack = Packs.ById[productId]
	if not pack or typeof(results) ~= "table" or phase ~= "closed" then
		return
	end

	clearCards()
	phase = "pack"
	tapsLockedUntil = 0
	refreshRipButton()
	pendingResults = results

	dressPack(pack)
	summaryRow.Visible = false
	valueLabel.Visible = false
	doneButton.Visible = false
	setHint("👋 Drag across the top to open!")
	oddsPanel.Text = buildOddsText(pack)
	oddsButton.Visible = true
	stage.Visible = true
	gui.Enabled = true
	ContextActionService:BindActionAtPriority(ADVANCE_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			task.spawn(advance)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, RIP_KEY)
end

-- A round white button on the right with a key chip under it (Next)
local function roundButton(name: string, icon: string, key: string, y: number, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -28, y, 0)
	button.Size = UDim2.fromOffset(ROUND_BUTTON, ROUND_BUTTON)
	button.BackgroundColor3 = WHITE
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.Text = icon
	button.TextSize = 34
	button.TextColor3 = INK
	button.ZIndex = 10
	button.Parent = stage
	UIKit.corner(button, ROUND_BUTTON / 2)
	UIKit.outline(button, Color3.fromRGB(170, 185, 215), 3)
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new(WHITE, Color3.fromRGB(205, 215, 235))
	shine.Rotation = 90
	shine.Parent = button
	local chip = UIKit.label(button, key, Enum.Font.FredokaOne, 15, WHITE)
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.new(0.5, 0, 1, 6)
	chip.Size = UDim2.fromOffset(70, 24)
	chip.TextXAlignment = Enum.TextXAlignment.Center
	chip.BackgroundColor3 = INK
	chip.BackgroundTransparency = 0
	chip.ZIndex = 10
	UIKit.corner(chip, 6)
	button.Activated:Connect(onClick)
	return button
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

	-- The light stage; a tap anywhere on it advances (the pack and buttons take their own taps)
	local stageButton = Instance.new("TextButton")
	stageButton.Name = "Stage"
	stageButton.Text = ""
	stageButton.AutoButtonColor = false
	stageButton.Size = UDim2.fromScale(1, 1)
	stageButton.BackgroundColor3 = WHITE
	stageButton.BorderSizePixel = 0
	stageButton.Visible = false
	stageButton.Parent = gui
	stageButton.Activated:Connect(function()
		if phase == "reveal" then
			nextCard()
		end
	end)
	stage = stageButton
	UIKit.hideTouchControlsWhileVisible(stage)
	local sky = Instance.new("UIGradient")
	sky.Color = ColorSequence.new(PackOpening.STAGE.TOP, PackOpening.STAGE.BOTTOM)
	sky.Rotation = 90
	sky.Parent = stage

	local centreGlow = Instance.new("ImageLabel")
	centreGlow.Name = "Glow"
	centreGlow.BackgroundTransparency = 1
	centreGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	centreGlow.Position = UDim2.fromScale(0.5, 0.5)
	centreGlow.Size = UDim2.fromScale(1.2, 1.2)
	centreGlow.SizeConstraint = Enum.SizeConstraint.RelativeYY
	centreGlow.Image = CardDesign.IMAGES.GLOW
	centreGlow.ImageColor3 = WHITE
	centreGlow.ImageTransparency = PackOpening.STAGE.GLOW_TRANSPARENCY
	centreGlow.Parent = stage

	dimmer = Instance.new("Frame")
	dimmer.Name = "Dim"
	dimmer.Size = UDim2.fromScale(1, 1)
	dimmer.BackgroundColor3 = Color3.fromRGB(10, 12, 30)
	dimmer.BackgroundTransparency = 1
	dimmer.BorderSizePixel = 0
	dimmer.Parent = stage

	raysLayer = Instance.new("Frame")
	raysLayer.Name = "Rays"
	raysLayer.Size = UDim2.fromScale(1, 1)
	raysLayer.BackgroundTransparency = 1
	raysLayer.Parent = stage

	buildPack(stage)

	cardLayer = Instance.new("Frame")
	cardLayer.Name = "Cards"
	cardLayer.Size = UDim2.fromScale(1, 1)
	cardLayer.BackgroundTransparency = 1
	cardLayer.Parent = stage

	summaryRow = Instance.new("Frame")
	summaryRow.Name = "Summary"
	summaryRow.AnchorPoint = Vector2.new(0.5, 0.5)
	summaryRow.Position = UDim2.fromScale(0.5, PackOpening.SUMMARY_Y)
	summaryRow.Size = UDim2.fromScale(0.94, PackOpening.SUMMARY_HEIGHT)
	summaryRow.BackgroundTransparency = 1
	summaryRow.Visible = false
	summaryRow.Parent = stage
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 12)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = summaryRow

	fxLayer = Instance.new("Frame")
	fxLayer.Name = "Fx"
	fxLayer.Size = UDim2.fromScale(1, 1)
	fxLayer.BackgroundTransparency = 1
	fxLayer.Parent = stage

	hintPill = Instance.new("Frame")
	hintPill.Name = "Hint"
	hintPill.AnchorPoint = Vector2.new(0.5, 0)
	hintPill.Position = UDim2.new(0.5, 0, 0, PackOpening.TOP)
	hintPill.Size = UDim2.fromOffset(0, PackOpening.PILL_HEIGHT)
	hintPill.AutomaticSize = Enum.AutomaticSize.X
	hintPill.BackgroundColor3 = INK
	hintPill.BackgroundTransparency = 0.05
	hintPill.Parent = stage
	UIKit.corner(hintPill, PackOpening.PILL_HEIGHT / 2)
	UIKit.outline(hintPill, Color3.fromRGB(110, 125, 170), 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 24)
	pad.PaddingRight = UDim.new(0, 24)
	pad.Parent = hintPill
	hintLabel = UIKit.label(hintPill, "", Enum.Font.FredokaOne, 22, WHITE)
	hintLabel.Size = UDim2.fromScale(0, 1)
	hintLabel.AutomaticSize = Enum.AutomaticSize.X
	hintLabel.TextXAlignment = Enum.TextXAlignment.Center

	valueLabel = UIKit.label(stage, "", Enum.Font.FredokaOne, 26, INK)
	valueLabel.Name = "PackValue"
	valueLabel.AnchorPoint = Vector2.new(0.5, 0)
	valueLabel.Position = UDim2.new(0.5, 0, PackOpening.SUMMARY_Y + PackOpening.SUMMARY_HEIGHT / 2, 14)
	valueLabel.Size = UDim2.fromOffset(360, 36)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Center
	valueLabel.Visible = false

	doneButton = UIKit.button(stage, "✔ Done", UIKit.Colors.Success)
	doneButton.Name = "Done"
	doneButton.AnchorPoint = Vector2.new(0.5, 0)
	doneButton.Position = UDim2.new(0.5, 0, PackOpening.SUMMARY_Y + PackOpening.SUMMARY_HEIGHT / 2, 56)
	doneButton.Size = UDim2.fromOffset(240, 54)
	doneButton.TextSize = 26
	doneButton.Visible = false
	doneButton.Activated:Connect(close)

	roundButton("Next", "➡️", "SPACE", 0.8, function()
		task.spawn(advance)
	end)

	oddsButton = UIKit.button(stage, "❔ Odds", UIKit.Colors.Row)
	oddsButton.Name = "OddsButton"
	oddsButton.AnchorPoint = Vector2.new(1, 0)
	oddsButton.Position = UDim2.new(1, -16, 0, PackOpening.TOP)
	oddsButton.Size = UDim2.fromOffset(110, 48)
	oddsButton.ZIndex = 10

	oddsPanel = UIKit.label(stage, "", Enum.Font.Gotham, 16, UIKit.Colors.Text)
	oddsPanel.Name = "Odds"
	oddsPanel.AnchorPoint = Vector2.new(1, 0)
	oddsPanel.Position = UDim2.new(1, -16, 0, PackOpening.TOP + 56)
	oddsPanel.Size = UDim2.fromOffset(330, 190)
	oddsPanel.BackgroundTransparency = 0.05
	oddsPanel.BackgroundColor3 = UIKit.Colors.Panel
	oddsPanel.TextYAlignment = Enum.TextYAlignment.Top
	oddsPanel.ZIndex = 11
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

	boxLabel = UIKit.label(stage, "", Enum.Font.FredokaOne, 18, INK)
	boxLabel.Name = "PacksLeft"
	boxLabel.Position = UDim2.fromOffset(16, PackOpening.TOP + 4)
	boxLabel.Size = UDim2.fromOffset(260, 40)

	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = WHITE
	flash.ZIndex = 40
	flash.Visible = false
	flash.Parent = gui
end

-- Dragging across the pack: the tear line follows the finger and the pack tears once it's far enough
local function onInputChanged(input: InputObject)
	if not dragging then
		return
	end
	local moving = input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
	if not moving then
		return
	end
	dragMinX = math.min(dragMinX, input.Position.X)
	dragMaxX = math.max(dragMaxX, input.Position.X)
	showTear(dragMinX, dragMaxX)
	if (dragMaxX - dragMinX) >= packFrame.AbsoluteSize.X * PackOpening.PACK.TEAR_DONE then
		task.spawn(tearPack)
	end
end

local function onInputEnded(input: InputObject)
	local release = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	if not dragging or not release then
		return
	end
	dragging = false
	local moved = (Vector2.new(input.Position.X, input.Position.Y) - dragStart).Magnitude
	if moved < PackOpening.PACK.TAP_PIXELS then
		task.spawn(autoTear)
	else
		-- Not far enough: the tear closes up again
		tween(tearLine, 0.2, { Size = UDim2.fromOffset(0, 6) })
	end
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or input.KeyCode ~= RIP_KEY or gui.Enabled then
		return
	end
	if ripButton.Visible then
		onRip()
	end
end

function PackOpeningController.Start()
	-- An orange tile in the bottom row while carrying a box of packs
	ripButton = Hud.tile({ id = "Rip", icon = "🃏", label = "Rip", key = "T", group = "Context", order = 21, onClick = onRip })

	buildScreen()
	refreshRipButton()

	player:GetAttributeChangedSignal("CarryProductId"):Connect(refreshRipButton)
	player:GetAttributeChangedSignal("CarryUnits"):Connect(refreshRipButton)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)
	Remotes.PackOpened.OnClientEvent:Connect(onPackOpened)
end

return PackOpeningController
