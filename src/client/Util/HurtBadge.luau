--!strict
-- A summoned creature hurt after fainting (owner 2026-11-15: "if the players summon fainted, add noticeable indicator
-- ON the pet that it's injured"; Config/Party HURT): while its card rests (the marker's RestUntil, os.time, set by the
-- server so everyone sees it) a red "Hurt 4:41" pill with a beating heart sits where the "+ Healing" pill goes, over its
-- name tag, and dizzy stars circle its head. CreatureController makes one per creature and steps it every frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Party = require(Shared:WaitForChild("Config"):WaitForChild("Party"))
local CreatureTag = require(Shared:WaitForChild("Util"):WaitForChild("CreatureTag"))

local Icon = require((script.Parent :: Instance):WaitForChild("Icon"))

local HurtBadge = {}

local HURT = Party.HURT

export type Badge = {
	pill: BillboardGui,
	words: TextLabel,
	heart: UIScale,
	ring: BillboardGui,
	stars: { GuiObject },
	untilTime: number?,
	shownText: string,
}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- The pill and the ring of stars on `root`, a creature `height` studs tall; hidden until `set`
function HurtBadge.new(root: BasePart, height: number): Badge
	local pill = Instance.new("BillboardGui")
	pill.Name = "HurtTag"
	pill.Size = UDim2.fromOffset(HURT.width, Party.TAG.HEAL_PILL + 4)
	pill.SizeOffset = Vector2.new(0, CreatureTag.healLift(Party.TAG))
	pill.StudsOffset = Vector3.new(0, height + 1, 0)
	pill.MaxDistance = Party.TAG.MAX_DISTANCE
	pill.LightInfluence = 0
	pill.Enabled = false
	pill.Adornee = root
	local body = Instance.new("Frame")
	body.Name = "Pill"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.new(0, 0, 1, 0)
	body.AutomaticSize = Enum.AutomaticSize.X
	body.BackgroundColor3 = rgb(HURT.fill)
	body.Parent = pill
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = body
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(1, 1, 1)
	edge.Thickness = 2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = body
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = body
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	local heart = Icon.make(body, HURT.icon, UDim2.fromOffset(Party.TAG.HEAL_PILL, Party.TAG.HEAL_PILL))
	heart.LayoutOrder = 1
	local beat = Instance.new("UIScale")
	beat.Parent = heart
	local words = Instance.new("TextLabel")
	words.Name = "Words"
	words.LayoutOrder = 2
	words.BackgroundTransparency = 1
	words.Size = UDim2.new(0, 0, 1, 0)
	words.AutomaticSize = Enum.AutomaticSize.X
	words.Font = Enum.Font.FredokaOne
	words.TextSize = 16
	words.TextColor3 = Color3.new(1, 1, 1)
	words.TextStrokeColor3 = rgb(HURT.ink)
	words.TextStrokeTransparency = 0.4
	words.Text = HURT.text
	words.Parent = body
	pill.Parent = root

	local width = math.clamp(height * HURT.ringWidth, HURT.ringMin, HURT.ringMax)
	local ring = Instance.new("BillboardGui")
	ring.Name = "DizzyStars"
	ring.Size = UDim2.new(width, 0, width * 0.6, 0)
	ring.StudsOffset = Vector3.new(0, height * HURT.ringHeight, 0)
	ring.MaxDistance = Party.TAG.MAX_DISTANCE
	ring.LightInfluence = 0
	ring.Enabled = false
	ring.Adornee = root
	local stars: { GuiObject } = {}
	for index = 1, HURT.stars do
		local star = Icon.make(ring, "Star", UDim2.fromScale(HURT.starSize, HURT.starSize / 0.6))
		star.Name = `Star{index}`
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		table.insert(stars, star)
	end
	ring.Parent = root
	return { pill = pill, words = words, heart = beat, ring = ring, stars = stars, untilTime = nil, shownText = "" }
end

-- Shows it until `untilTime` (os.time; nil or past: hidden)
function HurtBadge.set(badge: Badge, untilTime: number?)
	badge.untilTime = untilTime
	local shown = untilTime ~= nil and untilTime > workspace:GetServerTimeNow()
	badge.pill.Enabled = shown
	badge.ring.Enabled = shown
end

-- Hidden for now without forgetting its time (the "+ Healing" pill takes the spot at the spring)
function HurtBadge.hide(badge: Badge, hidden: boolean)
	local shown = not hidden and badge.untilTime ~= nil and (badge.untilTime :: number) > workspace:GetServerTimeNow()
	badge.pill.Enabled = shown
	badge.ring.Enabled = shown
end

-- Each frame: the heart beats, the stars circle, the time counts down (hidden once it's rested)
function HurtBadge.step(badge: Badge, now: number)
	if not badge.pill.Enabled then
		return
	end
	local left = (badge.untilTime or 0) - workspace:GetServerTimeNow()
	if left <= 0 then
		HurtBadge.set(badge, nil)
		return
	end
	local seconds = math.ceil(left)
	local text = string.format("%s %d:%02d", HURT.text, seconds // 60, seconds % 60)
	if text ~= badge.shownText then
		badge.shownText = text
		badge.words.Text = text
	end
	local beat = (now * HURT.beatsPerSecond) % 1
	badge.heart.Scale = 1 + HURT.beat * math.max(0, math.sin(beat * math.pi * 2)) ^ 4
	local spin = now * HURT.spin
	for index, star in badge.stars do
		local angle = spin + (index - 1) * math.pi * 2 / #badge.stars
		local front = math.sin(angle) -- toward the camera at its lowest point
		star.Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.38, 0.5 + front * 0.22)
		star.ZIndex = if front > 0 then 3 else 1
		star.Rotation = math.deg(angle) * 0.5
	end
end

function HurtBadge.destroy(badge: Badge)
	badge.pill:Destroy()
	badge.ring:Destroy()
end

return HurtBadge
