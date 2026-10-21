--!strict
-- Rarity effects on cards displayed in card cases, run locally on every client:
-- glows, ambient sparkles and a foil shimmer while shown, plus a burst when a card is listed.
-- The server only places the card parts; nothing here is replicated, so pulsing costs no network.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local CardEffects = require(Config:WaitForChild("CardEffects"))
local CardFace = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("CardFace"))
local Cards = require(Config:WaitForChild("Cards"))
local Rarities = require(Config:WaitForChild("Rarities"))

type RarityEffect = CardEffects.RarityEffect

local BURST_CLEANUP_SECONDS = 3

local CardEffectsController = {}

local function getRarityColor(rarity: string): Color3
	local tier = Rarities.Tiers[rarity]
	return if tier then tier.color else Color3.new(1, 1, 1)
end

local function makeEmitter(parent: Instance, color: Color3, rate: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = CardEffects.PARTICLE_TEXTURE
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Speed = NumberRange.new(0.4, 1.2)
	emitter.SpreadAngle = Vector2.new(50, 50)
	emitter.Acceleration = Vector3.new(0, 1.5, 0) -- drift upward
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = parent
	return emitter
end

-- A rainbow band sweeping across the card face, drawn over the server's SurfaceGui
local function addFoilShimmer(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "FoilShimmer"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.ZOffset = 1 -- draw above the server's card text on the same face
	gui.Parent = part

	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(1, 1, 1)
	overlay.BorderSizePixel = 0
	overlay.Parent = gui

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 220)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 150)),
	})
	-- Only a narrow band is visible; the rest of the overlay is fully transparent
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Rotation = 25
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = overlay

	local info = TweenInfo.new(CardEffects.SHIMMER_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)
	TweenService:Create(gradient, info, { Offset = Vector2.new(1, 0) }):Play()
end

local function addAlwaysOn(part: BasePart, effect: RarityEffect, color: Color3, foil: boolean)
	if effect.glow > 0 then
		local pointLight = Instance.new("PointLight")
		pointLight.Color = color
		pointLight.Brightness = effect.glow
		pointLight.Range = effect.glowRange
		pointLight.Shadows = false
		pointLight.Parent = part

		if effect.pulse then
			local info = TweenInfo.new(
				CardEffects.PULSE_SECONDS,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true
			)
			TweenService:Create(pointLight, info, { Brightness = effect.glow * 0.4 }):Play()
		end
	end
	if effect.sparkleRate > 0 then
		makeEmitter(part, color, effect.sparkleRate).Name = "AmbientSparkles"
	end
	if foil then
		makeEmitter(part, Color3.new(1, 1, 1), CardEffects.FOIL_GLINT_RATE).Name = "FoilGlints"
		addFoilShimmer(part)
	end
end

-- The moment a card is listed: a burst of sparkles, and for rarer cards a pop and a flash
local function playListingBurst(part: BasePart, effect: RarityEffect, color: Color3, foil: boolean)
	local burstColor = if effect.glow > 0 then color else Color3.new(1, 1, 1)
	local burst = makeEmitter(part, burstColor, 0)
	burst.Speed = NumberRange.new(3, 7)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst:Emit(effect.burst)
	if foil then
		local glints = makeEmitter(part, Color3.new(1, 1, 1), 0)
		glints.Speed = NumberRange.new(2, 5)
		glints.SpreadAngle = Vector2.new(180, 180)
		glints:Emit(CardEffects.FOIL_BURST)
		task.delay(BURST_CLEANUP_SECONDS, glints.Destroy, glints)
	end
	task.delay(BURST_CLEANUP_SECONDS, burst.Destroy, burst)

	if effect.pop then
		local normalSize = part.Size
		local info = TweenInfo.new(CardEffects.POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true)
		TweenService:Create(part, info, { Size = normalSize * CardEffects.POP_SCALE }):Play()
	end
	if effect.flash then
		local flash = Instance.new("PointLight")
		flash.Color = color
		flash.Brightness = CardEffects.FLASH_BRIGHTNESS
		flash.Range = effect.glowRange * 2
		flash.Shadows = false
		flash.Parent = part
		local info = TweenInfo.new(CardEffects.FLASH_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local fade = TweenService:Create(flash, info, { Brightness = 0 })
		fade.Completed:Once(function()
			flash:Destroy()
		end)
		fade:Play()
	end
end

local function attach(instance: Instance, isNewListing: boolean)
	if not instance:IsA("BasePart") then
		return
	end
	local cardId = instance:GetAttribute("CardId")
	local card = if typeof(cardId) == "string" then Cards.ById[cardId] else nil
	if not card then
		return
	end
	local frontier = card.set == "Frontier"
	local effect = if frontier then CardEffects.FRONTIER.CASE_EFFECT else CardEffects.BY_RARITY[card.rarity]
	if not effect then
		return
	end
	local color = if frontier then CardEffects.FRONTIER.AURORA[1] else getRarityColor(card.rarity)
	local foil = instance:GetAttribute("Foil") == true

	addAlwaysOn(instance, effect, color, foil)
	if frontier then
		-- The server draws a white border; here it becomes the moving aurora, with a shimmer like a foil's
		local border = instance:FindFirstChild("Border", true)
		if border and border:IsA("UIStroke") then
			CardFace.addAurora(border)
		end
		if not foil then
			addFoilShimmer(instance)
		end
	end
	if isNewListing then
		playListingBurst(instance, effect, color, foil)
	end
end

function CardEffectsController.Start()
	local plots = workspace:WaitForChild("Plots")
	-- Cards already on display when we arrive get their glow, but no listing burst. Some may still
	-- be arriving over the network just after this runs, so bursts wait until the join settles.
	local burstsFrom = os.clock() + CardEffects.JOIN_GRACE_SECONDS
	for _, instance in plots:GetDescendants() do
		attach(instance, false)
	end
	plots.DescendantAdded:Connect(function(instance)
		attach(instance, os.clock() >= burstsFrom)
	end)
end

return CardEffectsController
