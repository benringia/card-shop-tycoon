--!strict
-- Draws card faces into a Frame: pack opening, binder, cases, the Condenser, jobs and the party.
-- Full-art look: the art fills the card inside a thin rim in the rarity colour (rainbow on foil, aurora on
-- Frontier cards); the element and name sit top left, the grade's medal top right (Config/GradeLook: bigger the
-- better the grade, A and S cards glowing), the value at the bottom, all in outlined text. The frame should keep a
-- ~0.7 width/height ratio and have a UIStroke (hidden on drawn faces; the pack opening tweens it). Everything is
-- drawn in a "Face" child, so callers keep their own children. Layout, colours and art ids: Config/CardDesign.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local CardArtConfig = require(Config:WaitForChild("CardArt"))
local PackOpening = require(Config:WaitForChild("PackOpening"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local Rarities = require(Config:WaitForChild("Rarities"))
local GradeLookConfig = require(Config:WaitForChild("GradeLook"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardArt = require(Shared:WaitForChild("Util"):WaitForChild("CardArt"))
local GradeLook = require(Shared:WaitForChild("Util"):WaitForChild("GradeLook"))

type Card = typeof(Cards.List[1])
type Box = CardDesign.Box
-- A copy's level, stars and grade; nil means a plain Grade C copy (level 1, 0 stars)
-- `fresh`: a card just pulled (the pack opening): no level chip or stars, every pull has Lv 1 and none (owner
-- 2026-11-13: "clean up cards, remove excess borders, make it look clean/premium/polished/immersive")
export type Growth = { level: number, stars: number, grade: string, fresh: boolean? }

local NEUTRAL_STROKE = Color3.fromRGB(120, 120, 140)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local BACKDROP = Color3.fromRGB(40, 40, 60)

local AURORA = CardEffects.FRONTIER.AURORA

local CardFace = {}

-- Fetch the art up front, so the first cards don't show without their picture: the small copies most faces draw
-- (Config/CardArt) first, then the full paintings the big views draw
task.spawn(function()
	local images = { CardDesign.IMAGES.GLOW, GradeLookConfig.IMAGES.glow, GradeLookConfig.IMAGES.sparkle }
	for _, id in GradeLookConfig.IMAGES.medal do
		table.insert(images, id)
	end
	for _, id in CardDesign.SCENES do
		table.insert(images, id)
	end
	for _, id in CardArtConfig.SMALL do
		table.insert(images, id)
	end
	ContentProvider:PreloadAsync(images)
	local full = {}
	for _, id in CardArtConfig.FULL do
		table.insert(full, id)
	end
	ContentProvider:PreloadAsync(full)
end)

function CardFace.getRarityColor(rarity: string): Color3
	local tier = Rarities.Tiers[rarity]
	return if tier then tier.color else WHITE
end

function CardFace.isFrontier(card: Card): boolean
	return card.set == "Frontier"
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

local function spin(gradient: UIGradient, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)
	TweenService:Create(gradient, info, { Rotation = 360 }):Play()
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
	spin(gradient, CardEffects.FRONTIER.AURORA_SECONDS)
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

-- The card's art (its small copy: drawn small), else its element's scene, else "" (light cards on a turning binder
-- page, the party bar's portraits)
function CardFace.artImage(card: Card): string
	local own = CardArt.pick(card.name, 0, CardArtConfig)
	if own and own ~= "" then
		return own
	end
	return CardDesign.SCENES[card.element] or ""
end

-- The card's own painting at the size its art window is drawn (Util/CardArt), kept right if that size changes
local function ownArt(art: Frame, card: Card, name: string, zIndex: number): ImageLabel?
	local id = CardArt.pick(card.name, art.AbsoluteSize.Y, CardArtConfig)
	if not id or id == "" then
		return nil
	end
	local picture = Instance.new("ImageLabel")
	picture.Name = name
	picture.BackgroundTransparency = 1
	picture.Size = UDim2.fromScale(1, 1)
	picture.Image = id
	picture.ScaleType = Enum.ScaleType.Crop
	picture.ZIndex = zIndex
	picture.Parent = art
	art:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		picture.Image = CardArt.pick(card.name, art.AbsoluteSize.Y, CardArtConfig) or picture.Image
	end)
	return picture
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

-- A vertical two-colour gradient (top colour first)
local function shade(target: Instance, top: Color3, bottom: Color3)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = target
end

-- A thick dark outline that keeps its weight at any card size (it follows the drawn text's height)
local function outline(label: TextLabel)
	local stroke = Instance.new("UIStroke")
	stroke.Color = CardDesign.OUTLINE_COLOR
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	local function fit()
		stroke.Thickness = math.max(1, label.TextBounds.Y * CardDesign.OUTLINE)
	end
	label:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	fit()
end

-- Outlined text filling part of its parent, so it reads on any art
local function text(parent: Instance, value: string, area: Box, color: Color3, zIndex: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	place(label, area)
	label.Font = Enum.Font.FredokaOne
	label.Text = value
	label.TextColor3 = color
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = zIndex
	label.Parent = parent
	outline(label)
	return label
end

-- A small rounded chip with centred text (grade letter, level, foil)
local function chip(parent: Instance, name: string, value: string, area: Box, color: Color3, transparency: number): Frame
	local pill = Instance.new("Frame")
	pill.Name = name
	place(pill, area)
	pill.BackgroundColor3 = color
	pill.BackgroundTransparency = transparency
	pill.ZIndex = 7
	pill.Parent = parent
	round(pill, 0.5)
	local edge = Instance.new("UIStroke")
	edge.Color = WHITE
	edge.Transparency = 0.2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = pill
	local label = text(pill, value, { x = 0.1, y = 0.1, w = 0.8, h = 0.8 }, WHITE, 8)
	label.TextXAlignment = Enum.TextXAlignment.Center
	return pill
end

-- The rim: the whole card in the rim colours; the art sits inside it
local function addRim(face: Frame, colors: { Color3 }): Frame
	local rim = Instance.new("Frame")
	rim.Name = "Rim"
	rim.Size = UDim2.fromScale(1, 1)
	rim.BackgroundColor3 = WHITE
	rim.BorderSizePixel = 0
	rim.ZIndex = 1
	rim.Parent = face
	round(rim, CardDesign.CORNER)
	shade(rim, colors[1], colors[2])
	return rim
end

-- A turning gradient on the rim, replacing its plain colours (foil rainbow, Frontier aurora)
local function spinRim(rim: Frame, colors: ColorSequence, seconds: number)
	local old = rim:FindFirstChildOfClass("UIGradient")
	if old then
		old:Destroy()
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = colors
	gradient.Parent = rim
	spin(gradient, seconds)
end

-- The art window, inset by the rim width (the inset is the same on all four sides)
local function addArtWindow(face: Frame): Frame
	local inset = CardDesign.RIM_WIDTH
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.new(1 - inset * 2, 0, 1, 0)
	art.BackgroundColor3 = BACKDROP
	art.BorderSizePixel = 0
	art.ClipsDescendants = true
	art.ZIndex = 2
	art.Parent = face
	round(art, CardDesign.ART_CORNER)
	-- Height: the card's height less the same pixel inset as the sides
	local function fit()
		local gap = face.AbsoluteSize.X * inset * 2
		art.Size = UDim2.new(1 - inset * 2, 0, 1, -gap)
	end
	face:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return art
end

local function image(parent: Instance, name: string, id: string, zIndex: number): ImageLabel
	local picture = Instance.new("ImageLabel")
	picture.Name = name
	picture.BackgroundTransparency = 1
	picture.Size = UDim2.fromScale(1, 1)
	picture.Image = id
	picture.ScaleType = Enum.ScaleType.Crop
	picture.ZIndex = zIndex
	picture.Parent = parent
	return picture
end

-- The picture: the card's own art, else its element's scene (or gradient) with the element emoji on a glow
local function addArt(art: Frame, card: Card)
	if ownArt(art, card, "Picture", 3) then
		return
	end
	local elementColor = Cards.ELEMENTS[card.element] or BACKDROP
	local scene = CardDesign.SCENES[card.element]
	if scene and scene ~= "" then
		image(art, "Scene", scene, 3)
	else
		art.BackgroundColor3 = WHITE
		shade(art, elementColor:Lerp(WHITE, 0.45), elementColor:Lerp(BLACK, 0.35))
	end

	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, CardDesign.EMOJI_CENTER)
	glow.Size = UDim2.fromScale(1.2, 1.2)
	glow.SizeConstraint = Enum.SizeConstraint.RelativeXX
	glow.Image = CardDesign.IMAGES.GLOW
	glow.ImageColor3 = elementColor:Lerp(WHITE, 0.6)
	glow.ImageTransparency = 0.2
	glow.ZIndex = 3
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
	emoji.ZIndex = 4
	emoji.Parent = art
end

-- Soft dark bands behind the top and bottom text, fading into the art
local function addTextShade(art: Frame)
	for _, band in { { name = "TopShade", y = 0, h = 0.26, rotation = 90 }, { name = "BottomShade", y = 0.68, h = 0.32, rotation = -90 } } do
		local strip = Instance.new("Frame")
		strip.Name = band.name
		strip.Position = UDim2.fromScale(0, band.y)
		strip.Size = UDim2.fromScale(1, band.h)
		strip.BackgroundColor3 = BLACK
		strip.BorderSizePixel = 0
		strip.ZIndex = 5
		strip.Parent = art
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = band.rotation
		gradient.Transparency = NumberSequence.new(1 - CardDesign.SHADE, 1)
		gradient.Parent = strip
	end
end

-- A see-through overlay on the art with a moving gradient band (foil holo, rare shine)
local function sweep(art: Frame, colors: ColorSequence, transparency: NumberSequence, seconds: number, pause: number)
	local overlay = Instance.new("Frame")
	overlay.Name = "Sweep"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = WHITE
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 6
	overlay.Parent = art

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
	local sheen = CardDesign.FOIL_TRANSPARENCY
	local transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.5, sheen),
		NumberSequenceKeypoint.new(0.75, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sweep(art, CardDesign.FOIL_RIM, transparency, PackOpening.FOIL_SHIMMER_SECONDS, 0)
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
	spin(gradient, CardDesign.SUPREME_RIM.SECONDS)
end

-- Stars as a row of slots: earned ones bright, the rest faint (MAX_STARS slots)
local function addStars(parent: Instance, stars: number, area: Box)
	local row = Instance.new("Frame")
	row.Name = "Stars"
	row.BackgroundTransparency = 1
	place(row, area)
	row.ZIndex = 7
	row.Parent = parent
	local slot = 1 / BeastRules.MAX_STARS
	for index = 1, BeastRules.MAX_STARS do
		local star = Instance.new("TextLabel")
		star.BackgroundTransparency = 1
		place(star, { x = (index - 1) * slot, y = 0, w = slot, h = 1 })
		star.Font = Enum.Font.FredokaOne
		star.Text = "⭐"
		star.TextScaled = true
		star.TextTransparency = if index <= stars then 0 else CardDesign.EMPTY_STAR_TRANSPARENCY
		star.ZIndex = 7
		star.Parent = row
	end
end

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- The name's box: top left, stopping short of the grade's medal (Shared/Util/GradeLook)
local function nameBox(grade: string): Box
	local name = CardDesign.TEXT.NAME
	return { x = GradeLookConfig.NAME.x, y = name.y, w = GradeLook.nameWidth(GradeLookConfig, grade), h = name.h }
end

-- The grade's medal in the card's top-right corner, bigger the better the grade, and the Level chip (`level`: its
-- words; nil, none) hanging under it (owner 2026-11-26, pick A "Medal + glow"; Config/GradeLook). They sit in a square
-- one card wide at the card's top, so across and down are both shares of the card's width there
local function addGrade(face: Frame, grade: string, level: string?)
	local square = Instance.new("Frame")
	square.Name = "Top"
	square.BackgroundTransparency = 1
	square.Size = UDim2.fromScale(1, 1)
	square.SizeConstraint = Enum.SizeConstraint.RelativeXX
	square.ZIndex = 7
	square.Parent = face
	local box = GradeLook.picture(GradeLookConfig, grade)
	local medal = Instance.new("ImageLabel")
	medal.Name = "Grade"
	medal.BackgroundTransparency = 1
	medal.Image = GradeLookConfig.IMAGES.medal[grade] or GradeLookConfig.IMAGES.medal.C
	medal.AnchorPoint = Vector2.new(0.5, 0.5) -- a pop grows it about its middle (a pulled A or S, Util/OpeningCards)
	medal.Position = UDim2.fromScale(box.x + box.size / 2, box.y + box.size / 2)
	medal.Size = UDim2.fromScale(box.size, box.size)
	medal.ZIndex = 8
	medal.Parent = square
	if level then
		chip(square, "Level", level, GradeLook.level(GradeLookConfig, grade), CardDesign.LEVEL_CHIP, CardDesign.LEVEL_CHIP_TRANSPARENCY)
	end
end

-- An S card's two sparkles twinkling on its edges (Config/GradeLook SPARKLES); `inside`: on a card that is its own 3D
-- surface, which can't draw past its edges
local function addSparkles(face: Frame, inside: boolean)
	local twinkle = GradeLookConfig.TWINKLE
	for index, spot in GradeLookConfig.SPARKLES do
		local at = GradeLook.sparkle(GradeLookConfig, index, inside)
		local sparkle = Instance.new("ImageLabel")
		sparkle.Name = "GradeSparkle"
		sparkle.BackgroundTransparency = 1
		sparkle.Image = GradeLookConfig.IMAGES.sparkle
		sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
		sparkle.Position = UDim2.fromScale(at.x, at.y)
		sparkle.Size = UDim2.fromScale(at.size, at.size)
		sparkle.SizeConstraint = Enum.SizeConstraint.RelativeXX
		sparkle.ZIndex = 9
		sparkle.Parent = face
		local scale = Instance.new("UIScale")
		scale.Parent = sparkle
		local info = TweenInfo.new(twinkle.seconds / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, spot.delay)
		TweenService:Create(scale, info, { Scale = twinkle.low }):Play()
		TweenService:Create(sparkle, info, { Rotation = 45, ImageTransparency = 0.35 }):Play()
	end
end

-- An A or S card glows (Config/GradeLook GLOW): on a screen, a ring round it and a soft glow past its edges, breathing
-- on S; a card that is its own 3D surface (the pack opening's, a case's, a dropped one: nothing past its edges shows)
-- gets the ring inside its rim instead, unless a Legendary S's electric rim is already there. S cards twinkle. Sizes
-- are shares of the card, so a window's UIScale scales them once
local function addGradeGlow(frame: Frame, face: Frame, art: Frame, grade: string, supreme: boolean)
	local glow = GradeLook.glow(GradeLookConfig, grade)
	if not glow then
		return
	end
	local parent = frame.Parent
	local own = parent ~= nil and (parent:IsA("SurfaceGui") or parent:IsA("BillboardGui"))
	if own and not supreme then
		local ring = Instance.new("UIStroke")
		ring.Name = "GradeRing"
		ring.Color = rgb(glow.ring)
		ring.Parent = art
		local function fit()
			ring.Thickness = math.max(1, face.AbsoluteSize.X * glow.width)
		end
		face:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		fit()
	elseif not own then
		local halo = Instance.new("ImageLabel")
		halo.Name = "GradeGlow"
		halo.BackgroundTransparency = 1
		halo.Image = GradeLookConfig.IMAGES.glow
		halo.ImageColor3 = rgb(glow.color)
		halo.ImageTransparency = glow.transparency
		halo.AnchorPoint = Vector2.new(0.5, 0.5)
		halo.Position = UDim2.fromScale(0.5, 0.5)
		halo.ZIndex = 0
		halo.Parent = face
		local ring = Instance.new("Frame")
		ring.Name = "GradeRing"
		ring.BackgroundColor3 = rgb(glow.ring)
		ring.BorderSizePixel = 0
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.ZIndex = 0
		ring.Parent = face
		local corner = Instance.new("UICorner")
		corner.Parent = ring
		-- its shape follows the card's (its width over its height)
		local function fit()
			local size = face.AbsoluteSize
			local aspect = if size.Y > 0 then size.X / size.Y else 1 / 1.4
			local glowWide, glowTall = GradeLook.glowSize(GradeLookConfig, aspect)
			halo.Size = UDim2.fromScale(glowWide, glowTall)
			local ringWide, ringTall, cornerShare = GradeLook.ring(GradeLookConfig, grade, aspect, CardDesign.CORNER)
			ring.Size = UDim2.fromScale(ringWide, ringTall)
			corner.CornerRadius = UDim.new(cornerShare, 0)
		end
		face:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		fit()
		if glow.pulse > 0 and glow.breath > 0 then
			local info = TweenInfo.new(glow.pulse / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			TweenService:Create(halo, info, { ImageTransparency = glow.transparency + glow.breath }):Play()
		end
	end
	if glow.twinkle then
		addSparkles(face, own)
	end
end

-- Face-down card: Pish and Chikin's card back (Config/CardDesign BACK), the whole card one picture
function CardFace.renderBack(frame: Frame, stroke: UIStroke)
	clear(frame)
	removeAurora(stroke)
	frame.BackgroundTransparency = 1
	stroke.Color = NEUTRAL_STROKE
	stroke.Transparency = 1
	stroke.Thickness = 2
	local face = newFace(frame)
	local back = image(face, "Back", CardDesign.BACK.IMAGE, 1)
	back.ScaleType = Enum.ScaleType.Stretch
	back.BackgroundColor3 = CardDesign.BACK.INSIDE[2] -- while the picture loads
	back.BackgroundTransparency = 0
	round(back, CardDesign.CORNER)
	lift(frame, face)
end

-- Binder slot for a card the player doesn't own yet: its art as a dark silhouette, with a "?"
function CardFace.renderMissing(frame: Frame, stroke: UIStroke, card: Card)
	clear(frame)
	removeAurora(stroke)
	frame.BackgroundTransparency = 1
	stroke.Transparency = 1
	local face = newFace(frame)
	local look = CardDesign.MISSING
	local rim = addRim(face, look.RIM)
	local art = addArtWindow(face)
	art.BackgroundColor3 = look.INSIDE
	local silhouette = ownArt(art, card, "Silhouette", 3)
	if silhouette then
		silhouette.ImageColor3 = BLACK
		silhouette.ImageTransparency = 0.35
	end
	local mark = text(art, "?", { x = 0.25, y = 0.28, w = 0.5, h = 0.3 }, look.MARK, 4)
	mark.TextXAlignment = Enum.TextXAlignment.Center
	local markEdge = mark:FindFirstChildOfClass("UIStroke")
	if markEdge then
		markEdge.Transparency = 1 -- soft grey on the light slot, no dark outline
	end
	if CardFace.isFrontier(card) then
		-- A mystery from the Frontier: the aurora rim and where to look (Frontier Packs since 2026-11-23, and its monsters)
		spinRim(rim, CardFace.getAuroraSequence(), CardEffects.FRONTIER.AURORA_SECONDS)
		local hint = text(art, "Frontier packs & monsters", { x = 0.08, y = 0.7, w = 0.84, h = 0.14 }, AURORA[1], 4)
		hint.TextXAlignment = Enum.TextXAlignment.Center
	else
		local number = text(art, string.format("#%02d", card.number), { x = 0.25, y = 0.72, w = 0.5, h = 0.12 }, look.MARK, 4)
		number.TextXAlignment = Enum.TextXAlignment.Center
		local numberEdge = number:FindFirstChildOfClass("UIStroke")
		if numberEdge then
			numberEdge.Transparency = 1
		end
	end
	lift(frame, face)
end

-- detail = false for the plain face (shelves and small tiles: name, grade, value); otherwise stars, level and
-- a foil tag show too. growth = nil for a plain Grade C copy (level 1, 0 stars).
-- price: a case's asking price, shown in gold instead of the card's market value.
-- Plain text only: Roblox's built-in fonts have no glyphs for symbols like ✦ (emoji are fine)
function CardFace.render(frame: Frame, stroke: UIStroke, card: Card, foil: boolean, detail: boolean?, growth: Growth?, price: number?)
	clear(frame)
	removeAurora(stroke)
	local frontier = CardFace.isFrontier(card)
	local level = if growth then growth.level else 1
	local stars = if growth then growth.stars else BeastRules.START_STARS
	local grade = if growth then growth.grade else BeastRules.DEFAULT_GRADE

	-- The rim draws the border; the caller's stroke stays hidden (the pack opening still tweens it)
	frame.BackgroundTransparency = 1
	stroke.Color = CardFace.getRarityColor(card.rarity)
	stroke.Thickness = PackOpening.STROKE_THICKNESS[card.rarity] or 2
	stroke.Transparency = 1

	local face = newFace(frame)
	local rim = addRim(face, CardDesign.RIMS[card.rarity] or CardDesign.RIMS.Common)
	local art = addArtWindow(face)
	addArt(art, card)
	addTextShade(art)

	-- Effects, all on the art and rim so they stay inside the card
	if frontier then
		spinRim(rim, CardFace.getAuroraSequence(), CardEffects.FRONTIER.AURORA_SECONDS)
		addFoilHolo(art)
	elseif foil then
		spinRim(rim, CardDesign.FOIL_RIM, CardDesign.FOIL_RIM_SECONDS)
		addFoilHolo(art)
	end
	local supreme = not frontier and card.rarity == "Legendary" and grade == "S"
	if supreme then
		addSupremeRim(art)
	end
	local shineFrom = Rarities.Tiers[CardDesign.SHINE_FROM]
	local tier = Rarities.Tiers[card.rarity]
	if not frontier and tier and shineFrom and tier.order >= shineFrom.order then
		addShine(art)
	end
	addGradeGlow(frame, face, art, grade, supreme)

	local layout = CardDesign.TEXT
	local emoji = CardDesign.EMOJI[card.element] or ""
	local name = text(face, `{emoji}{card.name}`, nameBox(grade), WHITE, 7)
	name.Name = "Name"
	local growing = detail ~= false and not (growth and growth.fresh)
	addGrade(face, grade, if growing then `Lv {level}` else nil)

	local value = BeastRules.getValue(card, foil, level, stars, grade)
	local valueText = if price then string.format("$%.2f", price) else string.format("$%.2f", value)
	local valueLabel = text(face, valueText, layout.VALUE, if price then CardDesign.PRICE_TEXT else CardDesign.VALUE_TEXT, 7)
	valueLabel.Name = "Value"
	valueLabel.TextXAlignment = Enum.TextXAlignment.Center

	if detail ~= false then
		if growing then
			addStars(face, stars, layout.STARS)
		end
		if foil or frontier then
			local tag = chip(face, "Foil", if frontier then "FRONTIER" else "FOIL", layout.FOIL, BLACK, 0.4)
			local gradient = Instance.new("UIGradient")
			gradient.Color = if frontier then CardFace.getAuroraSequence() else CardDesign.FOIL_RIM
			gradient.Parent = tag:FindFirstChildOfClass("UIStroke")
		end
	end
	lift(frame, face)
end

-- The cards' drawing pieces, for other faces in the same style (Util/WeaponFace: weapon cards look like creature
-- cards, the owner's pick 2026-11-06)
CardFace.parts = {
	clear = clear,
	removeAurora = removeAurora,
	newFace = newFace,
	addRim = addRim,
	addArtWindow = addArtWindow,
	image = image,
	text = text,
	chip = chip,
	addTextShade = addTextShade,
	addShine = addShine,
	addSupremeRim = addSupremeRim,
	addGrade = addGrade,
	nameBox = nameBox,
	lift = lift,
}

return CardFace
