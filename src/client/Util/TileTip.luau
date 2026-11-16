--!strict
-- A tip bubble pointing at a HUD tile (owner 2026-11-17: "make sure players know you can put packs in the bag"; the
-- mockup approved): Pish's face, the words, a tail down to the tile and a gold ring pulsing round it. It pops in above
-- the tile, keeps on screen and follows the tile while it shows; while the tile is hidden, so is the bubble. One at a
-- time. Look: Config/Tips BUBBLE.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Tips = require(Config:WaitForChild("Tips"))
local HudMascot = require(Config:WaitForChild("HudMascot"))

local TileTip = {}

local LOOK = Tips.BUBBLE

type Shown = { tile: GuiObject, holder: Frame, ring: Frame, follow: RBXScriptConnection, pulse: Tween }

local shown: Shown? = nil

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function round(gui: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = gui
end

local function edge(gui: GuiObject, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = gui
	return stroke
end

-- The tile and every frame it sits in are shown
local function onScreen(tile: GuiObject): boolean
	local node: Instance? = tile
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node ~= nil and node:IsA("ScreenGui") and node.Enabled
end

function TileTip.hide()
	local current = shown
	if not current then
		return
	end
	shown = nil
	current.follow:Disconnect()
	current.pulse:Cancel()
	current.holder:Destroy()
	current.ring:Destroy()
end

function TileTip.show(tile: GuiObject, text: string)
	if shown and shown.tile == tile then
		return
	end
	TileTip.hide()
	local screen = tile:FindFirstAncestorOfClass("ScreenGui")
	if not screen then
		return
	end
	local width, height = LOOK.size[1], LOOK.size[2]

	-- The tail is a turned square behind the bubble's body, so only its lower half shows under the bubble
	local holder = Instance.new("Frame")
	holder.Name = "TileTip"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Size = UDim2.fromOffset(width, height)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 50
	holder.Parent = screen
	local pop = Instance.new("UIScale")
	pop.Scale = 0
	pop.Parent = holder
	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Size = UDim2.fromOffset(LOOK.tail, LOOK.tail)
	tail.Rotation = 45
	tail.BackgroundColor3 = rgb(LOOK.back)
	tail.ZIndex = 51
	tail.Parent = holder
	edge(tail, rgb(LOOK.edge), LOOK.edgeThickness)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = rgb(LOOK.back)
	body.ZIndex = 52
	body.Parent = holder
	round(body, LOOK.corner)
	edge(body, rgb(LOOK.edge), LOOK.edgeThickness)
	local face = Instance.new("ImageLabel")
	face.Name = "Pish"
	face.BackgroundTransparency = 1
	face.Image = HudMascot.images.peek
	face.ScaleType = Enum.ScaleType.Fit
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Size = UDim2.fromOffset(LOOK.face, LOOK.face)
	face.Position = UDim2.new(0, 10, 0.5, -6)
	face.ZIndex = 54
	face.Parent = body
	local words = Instance.new("TextLabel")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Font = Enum.Font.FredokaOne
	words.Text = text
	words.TextSize = LOOK.textSize
	words.TextWrapped = true
	words.TextXAlignment = Enum.TextXAlignment.Left
	words.TextColor3 = rgb(LOOK.ink)
	words.Position = UDim2.fromOffset(46, 4)
	words.Size = UDim2.new(1, -58, 1, -8)
	words.ZIndex = 53
	words.Parent = body

	local ring = Instance.new("Frame")
	ring.Name = "TileTipRing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 49
	ring.Parent = screen
	round(ring, LOOK.ring.corner)
	local ringEdge = edge(ring, rgb(LOOK.ring.color), LOOK.ring.thickness)
	local pulse = TweenService:Create(ringEdge, TweenInfo.new(LOOK.ring.pulse, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.6 })
	pulse:Play()

	-- Over the tile, kept on screen (the tail still points at the tile), following it every frame
	local function place()
		if not tile.Parent then
			TileTip.hide()
			return
		end
		local visible = onScreen(tile)
		holder.Visible = visible
		ring.Visible = visible
		if not visible then
			return
		end
		local screenWidth = screen.AbsoluteSize.X
		local center = tile.AbsolutePosition.X + tile.AbsoluteSize.X / 2
		local x = math.clamp(center, LOOK.margin + width / 2, math.max(LOOK.margin + width / 2, screenWidth - LOOK.margin - width / 2))
		holder.Position = UDim2.fromOffset(x, tile.AbsolutePosition.Y - LOOK.gap)
		local tailX = math.clamp(center - (x - width / 2), LOOK.corner + LOOK.tail, width - LOOK.corner - LOOK.tail)
		tail.Position = UDim2.fromOffset(tailX, height)
		ring.Position = UDim2.fromOffset(center, tile.AbsolutePosition.Y + tile.AbsoluteSize.Y / 2)
		ring.Size = UDim2.fromOffset(tile.AbsoluteSize.X + LOOK.ring.pad * 2, tile.AbsoluteSize.Y + LOOK.ring.pad * 2)
	end
	place()
	shown = { tile = tile, holder = holder, ring = ring, follow = RunService.RenderStepped:Connect(place), pulse = pulse }
	TweenService:Create(pop, TweenInfo.new(LOOK.popSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return TileTip
