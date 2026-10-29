--!strict
-- The cards on the opening stage (UI project 3 spec 4.3 - 4.6). Each card is a part with its face (CardFace, front)
-- and the card back (back) and a glow behind it, built once while the pack tears. They stack up face down one by one
-- out of the pack; each tap flips the top one (Rare and better tease first, then celebrate per its
-- RevealRules plan; a shown Rare-or-better card stays alive until the next tap); the shown card zips into a row along
-- the bottom; at the end the row's cards fly one by one to the results lineup and sparkle as they land. Screen
-- places come from Util/OpeningLayout, turned into stage positions at the right distance. Numbers: Config/PackOpening.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local PackOpening = require(Config:WaitForChild("PackOpening"))
local PackOpeningLayout = require(Config:WaitForChild("PackOpeningLayout"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local OpeningLayout = require(Shared:WaitForChild("Util"):WaitForChild("OpeningLayout"))
local RevealRules = require(Shared:WaitForChild("Util"):WaitForChild("RevealRules"))

local ClientUtil = script.Parent :: Instance
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local OpeningStage = require(ClientUtil:WaitForChild("OpeningStage"))
local OpeningFx = require(ClientUtil:WaitForChild("OpeningFx"))

type Card = typeof(Cards.List[1])
export type Pull = { card: Card, foil: boolean, grade: string, isNew: boolean, plan: RevealRules.Plan }
type Shown = {
	pull: Pull,
	model: Model,
	part: BasePart,
	halo: BasePart,
	back: SurfaceGui,
	shine: UIGradient,
	holo: UIGradient,
	newTag: BillboardGui,
	color: Color3,
	at: CFrame, -- where it rests now
	stopAlive: (() -> ())?,
}

local SIZE = PackOpening.CARD_STAGE
local FLIP = PackOpening.FLIP
local ALIVE = PackOpening.ALIVE
local RESULTS = PackOpening.RESULTS
local CARD_W = SIZE.HEIGHT / 1.4
local FACE_UP = CFrame.new() -- the card's front (-Z) toward the camera
local FACE_DOWN = CFrame.Angles(0, math.pi, 0)

local OpeningCards = {}

local cards: { Shown } = {}
local bannerGui: ScreenGui? = nil
local banner: Frame -- a plate in the pull's colour (gradient) with the word on it
local bannerText: TextLabel
local bannerScale: UIScale
local bannerPulse: Tween? = nil
local results: RBXScriptConnection? = nil

-- Far behind a card on the line from the camera through it: where its rays and aura go (behind the row too)
local function behind(at: CFrame): Vector3
	local eye = OpeningStage.home().Position
	return eye + (at.Position - eye).Unit * FLIP.BACK_DEPTH
end

local function rarityColor(card: Card): Color3
	return if CardFace.isFrontier(card) then CardEffects.FRONTIER.AURORA[1] else CardFace.getRarityColor(card.rarity)
end

local function tweenPivot(model: Model, to: CFrame, seconds: number, style: Enum.EasingStyle, direction: Enum.EasingDirection): Tween
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cframe)
		model:PivotTo(cframe)
	end)
	local t = TweenService:Create(value, TweenInfo.new(seconds, style, direction), { Value = to })
	t.Completed:Once(function()
		value:Destroy()
	end)
	t:Play()
	return t
end

local function surface(part: BasePart, face: Enum.NormalId): (SurfaceGui, Frame, UIStroke)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = SIZE.PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	return gui, frame, stroke
end

-- A sweep of light over the face (shine) or a coloured holo band (holo), both off until played
local function sweepLayer(gui: SurfaceGui, name: string, color: Color3, peak: number): UIGradient
	local layer = Instance.new("Frame")
	layer.Name = name
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundColor3 = color
	layer.BorderSizePixel = 0
	layer.ZIndex = 50
	layer.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 25
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 1 - peak),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = layer
	return gradient
end

local function newTagFor(part: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "NewTag"
	gui.Size = UDim2.fromScale(0.9, 0.36)
	gui.StudsOffset = Vector3.new(-CARD_W / 2 + 0.25, SIZE.HEIGHT / 2, 0)
	gui.LightInfluence = 0
	gui.Enabled = false
	gui.Adornee = part
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(255, 210, 63)
	label.Font = Enum.Font.FredokaOne
	label.Text = "NEW"
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(58, 42, 0)
	label.Rotation = -8
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = label
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Color3.fromRGB(11, 15, 26)
	edge.Thickness = 2
	edge.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = label
	return gui
end

local function buildCard(pull: Pull, index: number): Shown
	local model = Instance.new("Model")
	model.Name = `Card{index}`
	local part = Instance.new("Part")
	part.Name = "Card"
	part.Size = Vector3.new(CARD_W, SIZE.HEIGHT, SIZE.THICKNESS)
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Color = Color3.fromRGB(20, 18, 30)
	part.Parent = model
	local halo = Instance.new("Part")
	halo.Name = "Halo"
	halo.Size = Vector3.new(CARD_W + 0.16, SIZE.HEIGHT + 0.16, 0.01)
	halo.CFrame = CFrame.new(0, 0, SIZE.THICKNESS)
	halo.Anchored, halo.CanCollide, halo.CanQuery, halo.CanTouch, halo.CastShadow = true, false, false, false, false
	halo.Material = Enum.Material.Neon
	halo.Transparency = 1
	halo.Parent = model
	model.PrimaryPart = part
	local faceGui, faceFrame, faceStroke = surface(part, Enum.NormalId.Front)
	CardFace.render(faceFrame, faceStroke, pull.card, pull.foil, true, { level = 1, stars = BeastRules.START_STARS, grade = pull.grade }, nil)
	local backGui, backFrame, backStroke = surface(part, Enum.NormalId.Back)
	CardFace.renderBack(backFrame, backStroke)
	local color = rarityColor(pull.card)
	local gold = pull.plan.goldShards
	local parked = OpeningStage.root() * CFrame.new(0, -40, 0)
	model:PivotTo(parked)
	model.Parent = OpeningStage.folder()
	return {
		pull = pull,
		model = model,
		part = part,
		halo = halo,
		back = backGui,
		shine = sweepLayer(faceGui, "Shine", Color3.new(1, 1, 1), 0.75),
		holo = sweepLayer(faceGui, "Holo", if gold then Color3.fromRGB(255, 220, 120) else color, 0.45),
		newTag = newTagFor(part),
		color = color,
		at = parked,
	}
end

-- Builds every card's faces, one a frame (building a face costs; call it while the pack tears). In reveal order.
function OpeningCards.build(pulls: { Pull })
	OpeningCards.clear()
	for index, pull in pulls do
		table.insert(cards, buildCard(pull, index))
		task.wait()
	end
end

function OpeningCards.count(): number
	return #cards
end

local function ensureBanner()
	if bannerGui then
		return
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "PackOpeningBanner"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 41
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- Under the shown card, as wide as it is tall times BANNER.ASPECT (so it suits any screen)
	local plate = Instance.new("Frame")
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, FLIP.BANNER_Y)
	plate.Size = UDim2.fromScale(FLIP.BANNER_HEIGHT * FLIP.BANNER_ASPECT, FLIP.BANNER_HEIGHT)
	plate.SizeConstraint = Enum.SizeConstraint.RelativeYY
	plate.BackgroundColor3 = Color3.new(1, 1, 1)
	plate.Visible = false
	plate.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = plate
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Color3.fromRGB(11, 15, 26)
	edge.Thickness = 3
	edge.Parent = plate
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = plate
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.88, 0.74)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = plate
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(34, 34, 34)
	outline.Thickness = 2
	outline.Parent = label
	bannerScale = Instance.new("UIScale")
	bannerScale.Scale = 0
	bannerScale.Parent = plate
	banner = plate
	bannerText = label
	bannerGui = screen
end

local function showBanner(text: string, color: Color3)
	ensureBanner()
	bannerText.Text = text
	local gradient = banner:FindFirstChildOfClass("UIGradient") :: UIGradient
	gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.15))
	banner.Visible = true
	bannerScale.Scale = 0
	TweenService:Create(bannerScale, TweenInfo.new(FLIP.BANNER_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function hideBanner()
	if bannerPulse then
		bannerPulse:Cancel()
		bannerPulse = nil
	end
	if bannerGui and banner.Visible then
		local t = TweenService:Create(bannerScale, TweenInfo.new(0.15), { Scale = 0 })
		t.Completed:Once(function()
			banner.Visible = false
		end)
		t:Play()
	end
end

local function play(gradient: UIGradient, seconds: number, repeats: number)
	gradient.Offset = Vector2.new(-1, 0)
	TweenService:Create(gradient, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, repeats), { Offset = Vector2.new(1, 0) }):Play()
end

-- Glints on a card's edges and corners, tinted, a little apart
local function glintsAround(shown: Shown, count: number, color: Color3?, spread: number)
	for _ = 1, count do
		task.delay(math.random() * spread, function()
			local pivot = shown.model:GetPivot()
			local side = math.random(1, 4)
			local u = math.random() - 0.5
			local x = if side == 1 then -CARD_W / 2 elseif side == 2 then CARD_W / 2 else u * CARD_W
			local y = if side == 3 then -SIZE.HEIGHT / 2 elseif side == 4 then SIZE.HEIGHT / 2 else u * SIZE.HEIGHT
			OpeningFx.glint((pivot * CFrame.new(x, y, -0.1)).Position, 0.35 + math.random() * 0.45, color)
		end)
	end
end

-- The card's resting place for a screen rect (viewport pixels): its middle, at the distance that shows it rect.h tall
local function restFor(rect: OpeningLayout.Rect, facing: CFrame): CFrame
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local depth = OpeningLayout.depthFor(rect.h, view.Y, PackOpening.FIELD_OF_VIEW, SIZE.HEIGHT)
	return CFrame.new(OpeningStage.screenPoint(rect.x + rect.w / 2, rect.y + rect.h / 2, depth)) * facing
end

local function screenRects(kind: "row" | "lineup"): { OpeningLayout.Rect }
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local inset = GuiService:GetGuiInset().Y
	local size = { w = view.X, h = view.Y }
	return if kind == "row" then OpeningLayout.row(#cards, size, inset, PackOpeningLayout.LAYOUT) else OpeningLayout.lineup(#cards, size, inset, PackOpeningLayout.LAYOUT)
end

-- The cards come out of the pack's top one at a time and snap onto a face-down stack, the best first (yields)
function OpeningCards.stack(from: Vector3)
	local stack = OpeningStage.root() * CFrame.new(0, 0.25, 0)
	local layer = 0
	for index = #cards, 1, -1 do
		local shown = cards[index]
		local tilt = math.rad((math.random() - 0.5) * 2 * PackOpening.STACK.TILT)
		local target = stack * CFrame.new(-layer * 0.01, layer * 0.006, -layer * PackOpening.STACK.STEP) * FACE_DOWN * CFrame.Angles(0, 0, tilt)
		shown.model:PivotTo(CFrame.new(from) * CFrame.new(0, -SIZE.HEIGHT * 0.45, 0) * FACE_DOWN)
		local t = tweenPivot(shown.model, target, PackOpening.STACK.CARD_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		OpeningStage.play("stack")
		t.Completed:Wait()
		shown.at = target
		OpeningStage.shake(0.02, 0.11)
		layer += 1
	end
end

-- The shown card floats and tilts, a holo band sweeps it, glints twinkle round it, motes rise, the aura breathes and
-- the banner pulses, until the next tap
local function startAlive(shown: Shown)
	local plan = shown.pull.plan
	local big = plan.goldShards
	play(shown.holo, if big then ALIVE.BIG_HOLO_SECONDS else ALIVE.HOLO_SECONDS, -1)
	if not plan.alive then
		shown.stopAlive = function()
			shown.holo.Offset = Vector2.new(-1, 0)
		end
		return
	end
	OpeningStage.play("shimmer")
	local period = if big then ALIVE.BIG_SECONDS else ALIVE.SECONDS
	local start = os.clock()
	local nextGlint = start
	local glintColor = if big then Color3.fromRGB(255, 210, 90) else shown.color
	OpeningFx.motes(plan.moteRate, shown.at * CFrame.new(0, -SIZE.HEIGHT / 2, 0.3), glintColor)
	ensureBanner()
	bannerPulse = TweenService:Create(bannerScale, TweenInfo.new(ALIVE.BANNER_PULSE_SECONDS / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.07 })
	task.delay(0.5, function()
		if bannerPulse then
			bannerPulse:Play()
		end
	end)
	local loop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local w = t * math.pi * 2 / period
		local bob = math.sin(w) * ALIVE.BOB
		shown.model:PivotTo(shown.at * CFrame.new(0, bob, 0) * CFrame.Angles(math.rad(math.sin(w * 0.8) * plan.tilt * 0.5), math.rad(math.sin(w) * plan.tilt), 0))
		OpeningFx.auraScale(1 + 0.14 * math.sin(t * math.pi * 2 / ALIVE.AURA_SECONDS))
		if plan.glintRate > 0 and os.clock() >= nextGlint then
			nextGlint = os.clock() + 1 / plan.glintRate
			local pivot = shown.model:GetPivot()
			local x = (math.random() - 0.5) * (CARD_W + 0.8)
			local y = (math.random() - 0.5) * (SIZE.HEIGHT + 0.6)
			OpeningFx.glint((pivot * CFrame.new(x, y, -0.15)).Position, 0.25 + math.random() * (if big then 0.55 else 0.4), glintColor)
		end
	end)
	shown.stopAlive = function()
		loop:Disconnect()
		shown.holo.Offset = Vector2.new(-1, 0)
		OpeningFx.motes(0)
		OpeningFx.auraScale(1)
		shown.model:PivotTo(shown.at)
	end
end

local function hitSound(plan: RevealRules.Plan): string
	return if plan.goldShards then "hitLegendary" elseif plan.cinematic then "hitEpic" else "hitRare"
end

-- Flips card `index` (reveal order): a tease first for a Rare-or-better (or foil) card, then the flip, then its
-- celebration; yields until it has landed
function OpeningCards.flip(index: number)
	local shown = cards[index]
	if not shown then
		return
	end
	local plan = shown.pull.plan
	local color = shown.color
	local raised = shown.at * CFrame.new(0, FLIP.LIFT, 0)
	if plan.tease > 0 then
		OpeningStage.play("tease")
		shown.halo.Color = color
		TweenService:Create(shown.halo, TweenInfo.new(plan.tease, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = FLIP.GLOW_TRANSPARENCY }):Play()
		OpeningFx.aura(true, color, behind(shown.at))
		if plan.cinematic then
			OpeningStage.bars(true, 0.28)
			OpeningStage.dim(1, 0.5)
			OpeningStage.push(1.15, shown.at.Position, plan.tease)
		end
		local start = os.clock()
		local shake = RunService.RenderStepped:Connect(function()
			local p = math.clamp((os.clock() - start) / plan.tease, 0, 1)
			local jitter = (0.01 + plan.shake * 0.006 * p) * (if math.random() < 0.5 then -1 else 1)
			shown.model:PivotTo(shown.at * CFrame.new(jitter, FLIP.RISE * (1 - (1 - p) ^ 2), 0) * CFrame.Angles(0, 0, math.rad(plan.shake * p * jitter * 40)))
		end)
		task.wait(plan.tease)
		shake:Disconnect()
		raised = shown.at * CFrame.new(0, FLIP.RISE, 0)
	else
		tweenPivot(shown.model, raised, FLIP.LIFT_SECONDS, Enum.EasingStyle.Quint, Enum.EasingDirection.Out).Completed:Wait()
	end
	-- The flip: a quick turn with an overshoot, landing nearer the camera (bigger)
	local home = OpeningStage.home()
	local scale = if plan.tease > 0 then FLIP.TEASED_SCALE else FLIP.SHOWN_SCALE
	local landing = CFrame.new(home.Position + home.LookVector * (PackOpening.CAMERA_DISTANCE / scale) + Vector3.new(0, FLIP.LANDING_UP, 0)) * FACE_UP
	local seconds = if plan.tease > 0 then FLIP.TEASE_SECONDS else FLIP.COMMON_SECONDS
	OpeningStage.play("flip")
	local watch = RunService.RenderStepped:Connect(function()
		-- the back is hidden outright once the card has turned past halfway (front toward the camera)
		if shown.part.CFrame.LookVector.Z < 0 then
			shown.back.Enabled = false
		end
	end)
	tweenPivot(shown.model, landing, seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out).Completed:Wait()
	watch:Disconnect()
	shown.back.Enabled = false
	shown.at = landing
	play(shown.shine, FLIP.SHINE_SECONDS, 0)
	OpeningFx.glint((landing * CFrame.new(CARD_W * 0.42, SIZE.HEIGHT * 0.42, -0.1)).Position, 0.8)
	if plan.tease > 0 then
		OpeningStage.play(hitSound(plan))
		OpeningFx.burst(landing.Position, color, if plan.goldShards then FLIP.BIG_BURST_SIZE else FLIP.BURST_SIZE)
		if plan.banner then
			showBanner(plan.banner, color)
		end
		if plan.rays then
			OpeningFx.rays(true, color, behind(landing))
		end
		if plan.flash then
			OpeningStage.flash(0.85, 0.5)
			OpeningStage.shake(0.15, 0.4)
		end
		if plan.shards > 0 then
			OpeningFx.shards(landing.Position, plan.shards, plan.goldShards, 1.4)
		end
		if plan.goldShards then
			task.delay(0.25, function()
				OpeningFx.shards((home * CFrame.new(0, 3.2, -5)).Position, 24, true, 0.4)
			end)
		end
		if plan.cinematic then
			OpeningStage.dim(0.4, 0.6)
		end
		glintsAround(shown, math.max(2, math.ceil(plan.burst / 6)), color, 0.3)
	end
	if plan.alive or plan.holo then
		startAlive(shown)
	end
end

-- The shown card zips into its place in the row along the bottom (small, far away), its show stopping
function OpeningCards.stow(index: number)
	local shown = cards[index]
	if not shown then
		return
	end
	if shown.stopAlive then
		shown.stopAlive()
		shown.stopAlive = nil
	end
	hideBanner()
	OpeningFx.rays(false, shown.color)
	OpeningFx.aura(false, shown.color)
	TweenService:Create(shown.halo, TweenInfo.new(0.2), { Transparency = 1 }):Play()
	if shown.pull.plan.cinematic then
		OpeningStage.bars(false, 0.28)
		OpeningStage.ease(0.3)
		OpeningStage.dim(0, 0.3)
	end
	local target = restFor(screenRects("row")[index], FACE_UP)
	tweenPivot(shown.model, target, PackOpening.STOW.SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
	shown.at = target
end

local function land(shown: Shown)
	local pull = shown.pull
	play(shown.shine, RESULTS.SHINE_SECONDS, 0)
	local rarity = if CardFace.isFrontier(pull.card) then "Legendary" else pull.card.rarity
	local tinted = if pull.plan.tease > 0 then shown.color else nil -- Commons sparkle white
	glintsAround(shown, (RESULTS.SPARKLES :: any)[rarity] or 3, tinted, 0.32)
	if pull.plan.goldShards then
		OpeningFx.burst(shown.at.Position, shown.color, 3.8)
		OpeningFx.shards(shown.at.Position, 14, true, 0.9)
	end
	if pull.plan.alive then
		shown.halo.Color = shown.color
		TweenService:Create(shown.halo, TweenInfo.new(0.3), { Transparency = FLIP.GLOW_TRANSPARENCY }):Play()
	end
	if pull.isNew then
		shown.newTag.Enabled = true
		local scale = (shown.newTag:FindFirstChildOfClass("TextLabel") :: TextLabel):FindFirstChildOfClass("UIScale") :: UIScale
		scale.Scale = 0
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.04), { Scale = 1 }):Play()
	end
	OpeningStage.play("land")
end

-- One card's flight from the row to its lineup place: an arc with a little spin, then a snap (Quint out)
local function fly(shown: Shown, target: CFrame, spin: number, onLanded: () -> ())
	local from = shown.model:GetPivot()
	local start = os.clock()
	local loop: RBXScriptConnection
	loop = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / RESULTS.FLIGHT_SECONDS, 0, 1)
		local e = 1 - (1 - t) ^ 5
		local position = from.Position:Lerp(target.Position, e) + Vector3.new(0, RESULTS.ARC * math.sin(math.pi * t), 0)
		shown.model:PivotTo(CFrame.new(position) * FACE_UP * CFrame.Angles(0, 0, math.rad(spin * math.sin(math.pi * t))))
		if t >= 1 then
			loop:Disconnect()
			shown.model:PivotTo(target)
			onLanded()
		end
	end)
end

-- The results: the row's cards fly one by one to the lineup in the middle and sparkle as they land; then they float
-- and twinkle until clear() (yields until the last one has landed)
function OpeningCards.lineup()
	local rects = screenRects("lineup")
	local landed = 0
	for index, shown in cards do
		local target = restFor(rects[index], FACE_UP)
		fly(shown, target, if index % 2 == 0 then RESULTS.SPIN else -RESULTS.SPIN, function()
			shown.at = target
			land(shown)
			landed += 1
		end)
		task.wait(RESULTS.STAGGER)
	end
	while landed < #cards do
		task.wait()
	end
	OpeningStage.play("chime")
	local start = os.clock()
	local nextTwinkle = start + RESULTS.TWINKLE_EVERY
	results = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		for index, shown in cards do
			local bob = math.sin((t + index * 0.18) * math.pi * 2 / RESULTS.FLOAT_SECONDS) * RESULTS.FLOAT
			shown.model:PivotTo(shown.at * CFrame.new(0, bob, 0))
		end
		if os.clock() >= nextTwinkle and #cards > 0 then
			nextTwinkle = os.clock() + RESULTS.TWINKLE_EVERY
			local pick = cards[math.random(1, #cards)]
			glintsAround(pick, 1, if pick.pull.plan.tease > 0 then pick.color else nil, 0)
		end
	end)
end

function OpeningCards.clear()
	if results then
		results:Disconnect()
		results = nil
	end
	for _, shown in cards do
		if shown.stopAlive then
			shown.stopAlive()
		end
		shown.model:Destroy()
	end
	table.clear(cards)
	if bannerGui then
		bannerPulse = nil
		banner.Visible = false
	end
	OpeningFx.clear()
end

return OpeningCards
