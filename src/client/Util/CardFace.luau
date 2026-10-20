--!strict
-- Draws card faces into a Frame, shared by the pack opening screen and the binder.
-- The frame should keep a ~0.7 width/height ratio and have a UIStroke for the rarity border.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local PackOpening = require(Config:WaitForChild("PackOpening"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))

type Card = typeof(Cards.List[1])
-- A copy's level, stars and grade; nil means a plain Grade C copy (level 1, 0 stars)
export type Growth = { level: number, stars: number, grade: string }

local BACK_COLOR = Color3.fromRGB(40, 40, 60)
local MISSING_COLOR = Color3.fromRGB(55, 55, 65)
local NEUTRAL_STROKE = Color3.fromRGB(120, 120, 140)

local CardFace = {}

CardFace.BACK_COLOR = BACK_COLOR

function CardFace.getRarityColor(rarity: string): Color3
	local tier = Rarities.Tiers[rarity]
	return if tier then tier.color else Color3.new(1, 1, 1)
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
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Parent = parent

	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 28
	limit.Parent = label
	return label
end

local function clear(frame: Frame)
	for _, child in frame:GetChildren() do
		if child:IsA("TextLabel") or child:IsA("UIGradient") then
			child:Destroy()
		end
	end
end

local function addFoilShimmer(frame: Frame)
	-- A bright rainbow band sweeping across the card face
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.4, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 150, 220)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 255, 255)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 255, 150)),
		ColorSequenceKeypoint.new(0.6, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	})
	gradient.Rotation = 25
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = frame

	local info = TweenInfo.new(PackOpening.FOIL_SHIMMER_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)
	TweenService:Create(gradient, info, { Offset = Vector2.new(1, 0) }):Play()
end

-- Face-down card
function CardFace.renderBack(frame: Frame, stroke: UIStroke)
	clear(frame)
	frame.BackgroundColor3 = BACK_COLOR
	stroke.Color = NEUTRAL_STROKE
	stroke.Thickness = 2
	CardFace.addLabel(frame, "?", 0.3, 0.4, Enum.Font.FredokaOne)
end

-- Binder slot for a card the player doesn't own yet
function CardFace.renderMissing(frame: Frame, stroke: UIStroke, card: Card)
	clear(frame)
	frame.BackgroundColor3 = MISSING_COLOR
	stroke.Color = NEUTRAL_STROKE
	stroke.Thickness = 1
	CardFace.addLabel(frame, string.format("#%02d", card.number), 0.35, 0.2, Enum.Font.GothamBold).TextTransparency = 0.4
end

-- showValue = false for small tiles (hides value and stats, a count badge sits over the bottom).
-- growth = nil for a plain copy; a levelled card shows its level and stars.
function CardFace.render(frame: Frame, stroke: UIStroke, card: Card, foil: boolean, showValue: boolean?, growth: Growth?)
	clear(frame)
	local level = if growth then growth.level else 1
	local stars = if growth then growth.stars else BeastRules.START_STARS
	local grade = if growth then growth.grade else BeastRules.DEFAULT_GRADE
	frame.BackgroundColor3 = Cards.ELEMENTS[card.element] or BACK_COLOR
	stroke.Color = CardFace.getRarityColor(card.rarity)
	stroke.Thickness = PackOpening.STROKE_THICKNESS[card.rarity] or 2

	CardFace.addLabel(frame, card.name, 0.05, 0.14, Enum.Font.FredokaOne)
	-- Placeholder art until real card art exists: the element's initial, big
	CardFace.addLabel(frame, string.sub(card.element, 1, 1), 0.24, 0.3, Enum.Font.FredokaOne).TextTransparency = 0.3
	if growth then
		local growthText = `{BeastRules.describeGrade(grade)} · {BeastRules.describeGrowth(level, stars)}`
		CardFace.addLabel(frame, growthText, 0.55, 0.08, Enum.Font.GothamBold)
	end
	if showValue ~= false then
		local stats = BeastRules.getStats(card, foil, level, stars, grade)
		local power = BeastRules.getPower(card, foil, level, stars, grade)
		CardFace.addLabel(frame, `Power {power} · HP {stats.hp} ATK {stats.atk} SPD {stats.spd}`, 0.64, 0.07, Enum.Font.GothamBold)
	end
	CardFace.addLabel(frame, card.rarity, 0.72, 0.1, Enum.Font.GothamBold).TextColor3 = CardFace.getRarityColor(card.rarity)
	if showValue ~= false then
		CardFace.addLabel(frame, string.format("$%.2f", BeastRules.getValue(card, foil, level, stars, grade)), 0.84, 0.1, Enum.Font.GothamBold)
	end

	-- Plain text only: Roblox's built-in fonts have no glyphs for symbols like ✦
	if foil then
		CardFace.addLabel(frame, "FOIL", 0.18, 0.06, Enum.Font.GothamBold)
		addFoilShimmer(frame)
	end
end

return CardFace
