--!strict
-- Draws card faces into a Frame: pack opening, binder, cases, the Condenser, jobs and the party.
-- Full-art TCG look: the art fills the card and a frame image per rarity sits on top (thick metal border,
-- rarity ribbon, level hex, name panel with an element socket); the text is drawn over the frame.
-- The frame should keep a ~0.7 width/height ratio and have a UIStroke (hidden on drawn faces; the pack
-- opening tweens it). Everything is drawn in a "Face" child, so callers keep their own children.
-- Layout, colours and image ids: Config/CardDesign (frames: assets/ui/card-frames, tools/card-frames).
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local PackOpening = require(Config:WaitForChild("PackOpening"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))

type Card = typeof(Cards.List[1])
type Box = CardDesign.Box
-- A copy's level, stars and grade; nil means a plain Grade C copy (level 1, 0 stars)
export type Growth = { level: number, stars: number, grade: string }

local BACK_COLOR = Color3.fromRGB(40, 40, 60)
local MISSING_COLOR = Color3.fromRGB(55, 55, 65)
local NEUTRAL_STROKE = Color3.fromRGB(120, 120, 140)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local MAX_TEXT = 48

local AURORA = CardEffects.FRONTIER.AURORA

local CardFace = {}

CardFace.BACK_COLOR = BACK_COLOR

-- Fetch the frame, glow and back images up front, so the first cards don't show without their border
task.spawn(function()
	local images = { CardDesign.IMAGES.GLOW, CardDesign.IMAGES.BACK }
	for _, id in CardDesign.IMAGES.FRAMES do
		table.insert(images, id)
	end
	ContentProvider:PreloadAsync(images)
end)

function CardFace.getRarityColor(rarity: string): Color3
	local tier = Rarities.Tiers[rarity]
	return if tier then tier.color else WHITE
end

function CardFace.isFrontier(card: Card): boolean
	return card.set == "Frontier"
end

-- Text label positioned by fractions of the card's height, so it scales with the card
function CardFace.addLabel(parent: Instance, text: string, y: number, height: number, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, y)
	label.Size = UDim2.fromScale(0.9, height)
	label.Font = font
	label.Text = text
	label.TextColor3 = WHITE
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Parent = parent

	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = MAX_TEXT
	limit.Parent = label
	return label
end

-- The aurora colours as a looping sequence (for borders, text and the drop reveal)
function CardFace.getAuroraSequence(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, AURORA[1]),
		ColorSequenceKeypoint.new(0.33, AURORA[2]),
		ColorSequenceKeypoint.new(0.66, AURORA[3]),
		ColorSequenceKeypoint.new(1, AURORA[1]),
	})
end

-- A slowly turning aurora gradient on a border (or any GuiObject / UIStroke)
function CardFace.addAurora(target: Instance)
	local old = target:FindFirstChild("Aurora")
	if old then
		old:Destroy()
	end
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Aurora"
	gradient.Color = CardFace.getAuroraSequence()
	gradient.Parent = target
	local info = TweenInfo.new(CardEffects.FRONTIER.AURORA_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)
	TweenService:Create(gradient, info, { Rotation = 360 }):Play()
end

local function removeAurora(stroke: UIStroke)
	local old = stroke:FindFirstChild("Aurora")
	if old then
		old:Destroy()
	end
end

-- Removes the last drawing (and labels or gradients older code put straight on the frame)
local function clear(frame: Frame)
	for _, child in frame:GetChildren() do
		if child.Name == "Face" or child:IsA("TextLabel") or child:IsA("UIGradient") then
			child:Destroy()
		end
	end
end

local function newFace(frame: Frame): Frame
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundTransparency = 1
	face.Parent = frame
	return face
end

-- Parts are given ZIndex offsets while drawing; this lifts them above the card frame's own ZIndex, so cards
-- in Global ZIndex screens (high ZIndex overlays) still draw in order
local function lift(frame: Frame, face: Frame)
	face.ZIndex = frame.ZIndex
	for _, item in face:GetDescendants() do
		if item:IsA("GuiObject") then
			item.ZIndex += frame.ZIndex
		end
	end
end

local function round(target: GuiObject, scale: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(scale, 0)
	corner.Parent = target
end

local function place(target: GuiObject, area: Box)
	target.Position = UDim2.fromScale(area.x, area.y)
	target.Size = UDim2.fromScale(area.w, area.h)
end

-- A label filling part of its parent, white with a dark outline so it reads on any art
local function text(parent: Instance, value: string, area: Box, font: Enum.Font, color: Color3, zIndex: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	place(label, area)
	label.Font = font
	label.Text = value
	label.TextColor3 = color
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextStrokeColor3 = Color3.fromRGB(20, 14, 30)
	label.TextStrokeTransparency = 0.2
	label.ZIndex = zIndex
	label.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = MAX_TEXT
	limit.Parent = label
	return label
end

-- A see-through overlay on the art with a moving gradient band (foil holo, rare shine)
local function sweep(art: Frame, colors: ColorSequence, transparency: NumberSequence, seconds: number, pause: number)
	local overlay = Instance.new("Frame")
	overlay.Name = "Sweep"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = WHITE
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 4
	overlay.Parent = art
	round(overlay, CardDesign.ART_CORNER)

	local gradient = Instance.new("UIGradient")
	gradient.Color = colors
	gradient.Transparency = transparency
	gradient.Rotation = 25
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = overlay

	local info = TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false, pause)
	TweenService:Create(gradient, info, { Offset = Vector2.new(1, 0) }):Play()
end

local function addFoilHolo(art: Frame)
	local colors = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 220)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(150, 255, 255)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(255, 255, 150)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 220)),
	})
	local sheen = CardDesign.FOIL_TRANSPARENCY
	local transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.5, sheen),
		NumberSequenceKeypoint.new(0.75, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sweep(art, colors, transparency, PackOpening.FOIL_SHIMMER_SECONDS, 0)
end

local function addShine(art: Frame)
	local transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sweep(art, ColorSequence.new(WHITE), transparency, CardDesign.SHINE_SECONDS, CardDesign.SHINE_PAUSE)
end

-- Grade S Legendaries: a gold and white electric rim spinning round the art
local function addSupremeRim(art: Frame)
	local rim = Instance.new("UIStroke")
	rim.Name = "SupremeRim"
	rim.Color = WHITE
	rim.Thickness = CardDesign.SUPREME_RIM.THICKNESS
	rim.Parent = art
	local gradient = Instance.new("UIGradient")
	gradient.Color = CardDesign.SUPREME_RIM.COLORS
	gradient.Parent = rim
	local info = TweenInfo.new(CardDesign.SUPREME_RIM.SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)
	TweenService:Create(gradient, info, { Rotation = 360 }):Play()
end

-- The art: element colour backdrop with a soft glow and the element's emoji, until real art exists
local function addArt(face: Frame, card: Card): Frame
	local elementColor = Cards.ELEMENTS[card.element] or BACK_COLOR
	local art = Instance.new("Frame")
	art.Name = "Art"
	place(art, CardDesign.ART)
	art.BackgroundColor3 = WHITE
	art.BorderSizePixel = 0
	art.ZIndex = 1
	art.Parent = face
	round(art, CardDesign.ART_CORNER)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(elementColor:Lerp(WHITE, 0.35), elementColor:Lerp(BLACK, 0.45))
	gradient.Rotation = 90
	gradient.Parent = art

	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, CardDesign.EMOJI_CENTER)
	glow.Size = UDim2.fromScale(1.1, 1.1)
	glow.SizeConstraint = Enum.SizeConstraint.RelativeXX
	glow.Image = CardDesign.IMAGES.GLOW
	glow.ImageTransparency = 0.3
	glow.ZIndex = 2
	glow.Parent = art

	local emoji = Instance.new("TextLabel")
	emoji.Name = "Emoji"
	emoji.BackgroundTransparency = 1
	emoji.AnchorPoint = Vector2.new(0.5, 0.5)
	emoji.Position = UDim2.fromScale(0.5, CardDesign.EMOJI_CENTER)
	emoji.Size = UDim2.fromScale(CardDesign.EMOJI_SIZE, CardDesign.EMOJI_SIZE)
	emoji.SizeConstraint = Enum.SizeConstraint.RelativeXX
	emoji.Font = Enum.Font.FredokaOne
	emoji.Text = CardDesign.EMOJI[card.element] or "?"
	emoji.TextScaled = true
	emoji.ZIndex = 3
	emoji.Parent = art
	return art
end

-- The frame image (or, if its id is missing, a plain rarity-coloured border so the card still reads)
local function addFrame(frame: Frame, face: Frame, card: Card, frameKey: string)
	local image = CardDesign.IMAGES.FRAMES[frameKey]
	if not image or image == "" then
		frame.BackgroundTransparency = 0
		frame.BackgroundColor3 = CardFace.getRarityColor(card.rarity)
		return
	end
	local overlay = Instance.new("ImageLabel")
	overlay.Name = "Frame"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Image = image
	overlay.ScaleType = Enum.ScaleType.Stretch
	overlay.ZIndex = 5
	overlay.Parent = face
	if overlay.IsLoaded then
		return
	end
	-- Until the image arrives (first download), a rarity-coloured border stands in so the card never looks bare
	local standIn = Instance.new("UIStroke")
	standIn.Name = "LoadingBorder"
	standIn.Color = CardFace.getRarityColor(card.rarity)
	standIn.Thickness = CardDesign.LOADING_BORDER
	standIn.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	standIn.Parent = face:FindFirstChild("Art")
	overlay:GetPropertyChangedSignal("IsLoaded"):Connect(function()
		if overlay.IsLoaded then
			standIn:Destroy()
		end
	end)
end

-- Stars as a row of slots: earned ones bright, the rest faint (MAX_STARS slots)
local function addStars(parent: Instance, stars: number, area: Box)
	local row = Instance.new("Frame")
	row.Name = "Stars"
	row.BackgroundTransparency = 1
	place(row, area)
	row.ZIndex = 6
	row.Parent = parent
	local slot = 1 / BeastRules.MAX_STARS
	for index = 1, BeastRules.MAX_STARS do
		local star = text(row, "⭐", { x = (index - 1) * slot, y = 0, w = slot, h = 1 }, Enum.Font.FredokaOne, WHITE, 6)
		star.TextXAlignment = Enum.TextXAlignment.Center
		star.TextStrokeTransparency = 1
		star.TextTransparency = if index <= stars then 0 else CardDesign.EMPTY_STAR_TRANSPARENCY
	end
end

-- "GRADE S" on a pill in the grade's colour
local function addGradePill(parent: Instance, grade: string, area: Box)
	local pill = Instance.new("Frame")
	pill.Name = "Grade"
	place(pill, area)
	pill.BackgroundColor3 = CardDesign.GRADE_COLORS[grade] or CardDesign.GRADE_COLORS.C
	pill.ZIndex = 6
	pill.Parent = parent
	round(pill, 0.5)
	local label = text(pill, `GRADE {grade}`, { x = 0.08, y = 0.1, w = 0.84, h = 0.8 }, Enum.Font.FredokaOne, WHITE, 7)
	label.TextXAlignment = Enum.TextXAlignment.Center
end

local function getFrameKey(card: Card): string
	if CardFace.isFrontier(card) then
		return "Frontier"
	end
	return card.rarity
end

-- Face-down card
function CardFace.renderBack(frame: Frame, stroke: UIStroke)
	clear(frame)
	removeAurora(stroke)
	frame.BackgroundTransparency = 1
	stroke.Color = NEUTRAL_STROKE
	stroke.Transparency = 1
	stroke.Thickness = 2
	local face = newFace(frame)
	local back = Instance.new("ImageLabel")
	back.Name = "Back"
	back.BackgroundTransparency = 1
	back.Size = UDim2.fromScale(1, 1)
	back.Image = CardDesign.IMAGES.BACK
	back.ScaleType = Enum.ScaleType.Stretch
	back.Parent = face
	round(back, CardDesign.ART_CORNER)
	lift(frame, face)
end

-- Binder slot for a card the player doesn't own yet
function CardFace.renderMissing(frame: Frame, stroke: UIStroke, card: Card)
	clear(frame)
	removeAurora(stroke)
	frame.BackgroundTransparency = 0
	stroke.Transparency = 0
	local face = newFace(frame)
	if CardFace.isFrontier(card) then
		-- A mystery: a dark silhouette with the aurora edge, and where to look
		frame.BackgroundColor3 = Color3.fromRGB(20, 18, 34)
		stroke.Color = WHITE
		stroke.Thickness = 2
		CardFace.addAurora(stroke)
		CardFace.addLabel(face, "?", 0.22, 0.36, Enum.Font.FredokaOne).TextTransparency = 0.25
		local hint = CardFace.addLabel(face, "Found in the Frontier", 0.68, 0.12, Enum.Font.GothamBold)
		hint.TextColor3 = AURORA[1]
		lift(frame, face)
		return
	end
	frame.BackgroundColor3 = MISSING_COLOR
	stroke.Color = NEUTRAL_STROKE
	stroke.Thickness = 1
	CardFace.addLabel(face, string.format("#%02d", card.number), 0.35, 0.2, Enum.Font.GothamBold).TextTransparency = 0.4
	lift(frame, face)
end

-- Every card shows everything (name, stars, grade, level, stats, value) at any size. showValue is kept for
-- older callers and no longer changes the layout. growth = nil for a plain Grade C copy (level 1, 0 stars).
-- price: a case's asking price, shown in gold ("PRICE $3.00") instead of the card's market value.
-- Plain text only: Roblox's built-in fonts have no glyphs for symbols like ✦ (emoji are fine)
function CardFace.render(frame: Frame, stroke: UIStroke, card: Card, foil: boolean, _showValue: boolean?, growth: Growth?, price: number?)
	clear(frame)
	removeAurora(stroke)
	local frontier = CardFace.isFrontier(card)
	local level = if growth then growth.level else 1
	local stars = if growth then growth.stars else BeastRules.START_STARS
	local grade = if growth then growth.grade else BeastRules.DEFAULT_GRADE

	-- The frame image draws the border; the caller's stroke stays hidden (the pack opening still tweens it)
	frame.BackgroundTransparency = 1
	stroke.Color = CardFace.getRarityColor(card.rarity)
	stroke.Thickness = PackOpening.STROKE_THICKNESS[card.rarity] or 2
	stroke.Transparency = 1

	local face = newFace(frame)
	local art = addArt(face, card)
	addFrame(frame, face, card, getFrameKey(card))

	local layout = CardDesign.TEXT
	local ribbon = text(face, string.upper(if frontier then "Frontier" else card.rarity), layout.RIBBON, Enum.Font.FredokaOne, WHITE, 6)
	ribbon.TextXAlignment = Enum.TextXAlignment.Center
	local hex = text(face, tostring(level), layout.HEX, Enum.Font.FredokaOne, CardDesign.HEX_TEXT, 6)
	hex.TextXAlignment = Enum.TextXAlignment.Center
	local socket = text(face, CardDesign.EMOJI[card.element] or "?", layout.SOCKET, Enum.Font.FredokaOne, WHITE, 6)
	socket.TextXAlignment = Enum.TextXAlignment.Center
	socket.TextStrokeTransparency = 1

	local stats = BeastRules.getStats(card, foil, level, stars, grade)
	local power = BeastRules.getPower(card, foil, level, stars, grade)
	local value = BeastRules.getValue(card, foil, level, stars, grade)
	text(face, card.name, layout.NAME, Enum.Font.FredokaOne, WHITE, 6)
	addStars(face, stars, layout.STARS)
	addGradePill(face, grade, layout.GRADE)
	text(face, `Level {level} · {card.element}`, layout.LEVEL, Enum.Font.GothamBold, CardDesign.SUBTEXT, 6)
	local statLine = text(face, `💪{power}  ❤️{stats.hp}  ⚔️{stats.atk}  💨{stats.spd}`, layout.STATS, Enum.Font.GothamBold, WHITE, 6)
	statLine.TextXAlignment = Enum.TextXAlignment.Center
	local valueText = if price then string.format("PRICE $%.2f", price) else string.format("$%.2f", value)
	local valueLabel = text(face, valueText, layout.VALUE, Enum.Font.FredokaOne, if price then CardDesign.PRICE_TEXT else CardDesign.VALUE_TEXT, 6)
	valueLabel.Name = "Value"
	valueLabel.TextXAlignment = Enum.TextXAlignment.Center

	if foil then
		local tag = text(art, if frontier then "FOIL FRONTIER" else "FOIL", layout.FOIL, Enum.Font.FredokaOne, if frontier then AURORA[3] else WHITE, 6)
		tag.TextXAlignment = Enum.TextXAlignment.Left
	end

	-- Effects, all on the art so they stay inside the frame
	if frontier then
		-- Frontier cards: an aurora rim round the art, always shimmering
		local rim = Instance.new("UIStroke")
		rim.Color = WHITE
		rim.Thickness = 3
		rim.Parent = art
		CardFace.addAurora(rim)
		addFoilHolo(art)
	elseif foil then
		addFoilHolo(art)
	end
	if not frontier and card.rarity == "Legendary" and grade == "S" then
		addSupremeRim(art)
	end
	local shineFrom = Rarities.Tiers[CardDesign.SHINE_FROM]
	local tier = Rarities.Tiers[card.rarity]
	if not frontier and tier and shineFrom and tier.order >= shineFrom.order then
		addShine(art)
	end
	lift(frame, face)
end

return CardFace
