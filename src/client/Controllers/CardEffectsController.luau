--!strict
-- Cards displayed in card cases, drawn locally on every client: the full card face (CardFace, with the asking
-- price), a neon halo in the rarity colour behind it, glows and sparkles while shown, an element aura on
-- Legendaries (Util/ElementAura, stronger with grade and stars), plus a burst when a card is listed. The server only places plain card parts with attributes; nothing here is replicated, so pulsing
-- costs no network.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CardEffects = require(Config:WaitForChild("CardEffects"))
local ClientUtil = ((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local ElementAura = require(ClientUtil:WaitForChild("ElementAura"))
local Cards = require(Config:WaitForChild("Cards"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local ElementFx = require(Config:WaitForChild("ElementFx"))
local ElementFxRules = require(Shared:WaitForChild("Util"):WaitForChild("ElementFxRules"))

type RarityEffect = CardEffects.RarityEffect

local BURST_CLEANUP_SECONDS = 3
local SUPREME = CardEffects.SUPREME

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

type Card = typeof(Cards.List[1])

-- The card face on the part's front, glowing (it ignores the room's light). Redrawn when the price or the
-- copy's growth changes.
local function drawFace(part: BasePart, card: Card, foil: boolean)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CardFace"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = CardEffects.FACE_PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = CardEffects.FACE_BRIGHTNESS
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame

	local function render()
		local level, stars, grade = part:GetAttribute("Level"), part:GetAttribute("Stars"), part:GetAttribute("Grade")
		local growth = {
			level = if typeof(level) == "number" then level else 1,
			stars = if typeof(stars) == "number" then stars else BeastRules.START_STARS,
			grade = if BeastRules.isGrade(grade) then grade :: string else BeastRules.DEFAULT_GRADE,
		}
		local price = part:GetAttribute("Price")
		CardFace.render(frame, stroke, card, foil, true, growth, if typeof(price) == "number" then price else nil)
	end
	render()
	for _, attribute in { "Price", "Level", "Stars", "Grade" } do
		part:GetAttributeChangedSignal(attribute):Connect(render)
	end
end

-- A neon card-shaped glow just behind the card, a little bigger, in the rarity colour
local function addHalo(part: BasePart, effect: RarityEffect, color: Color3)
	if effect.halo >= 1 then
		return
	end
	local margin = CardEffects.HALO_MARGIN
	local halo = Instance.new("Part")
	halo.Name = "Halo"
	halo.Anchored = true
	halo.CanCollide = false
	halo.CanQuery = false -- clicks and prompts still hit the card
	halo.CanTouch = false
	halo.CastShadow = false
	halo.Material = Enum.Material.Neon
	halo.Color = color
	halo.Transparency = effect.halo
	halo.Size = Vector3.new(part.Size.X + margin * 2, part.Size.Y + margin * 2, 0.02)
	-- The front face is -Z, so +Z is just behind the card
	halo.CFrame = part.CFrame * CFrame.new(0, 0, part.Size.Z / 2 + 0.015)
	halo.Parent = part
	part:GetPropertyChangedSignal("CFrame"):Connect(function()
		halo.CFrame = part.CFrame * CFrame.new(0, 0, part.Size.Z / 2 + 0.015)
	end)
	if effect.pulse then
		local info = TweenInfo.new(CardEffects.PULSE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(halo, info, { Transparency = CardEffects.HALO_PULSE_TRANSPARENCY }):Play()
	end
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

-- Grade S copies shine brighter; a Grade S Legendary (or Frontier card) is "supreme": a solid halo, more glow
local function boostForGrade(effect: RarityEffect, grade: unknown, supreme: boolean): RarityEffect
	if grade ~= "S" then
		return effect
	end
	local boosted = table.clone(effect)
	boosted.glow *= CardEffects.GRADE_S.GLOW_MULTIPLIER
	boosted.sparkleRate *= CardEffects.GRADE_S.SPARKLE_MULTIPLIER
	if supreme then
		boosted.glow *= SUPREME.GLOW_MULTIPLIER
		boosted.glowRange *= SUPREME.RANGE_MULTIPLIER
		boosted.halo = SUPREME.HALO
		boosted.pulse = true
	end
	return boosted
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
	local grade = instance:GetAttribute("Grade")
	local supreme = grade == "S" and (frontier or card.rarity == "Legendary")
	effect = boostForGrade(effect, grade, supreme)

	drawFace(instance, card, foil)
	addHalo(instance, effect, color)
	addAlwaysOn(instance, effect, color, foil)
	-- Legendaries burn, bubble, bloom, crackle or smoke by element, stronger with grade and stars
	if card.rarity == "Legendary" then
		local stars = instance:GetAttribute("Stars")
		local intensity = ElementFxRules.intensity(
			ElementFx.INTENSITY,
			if typeof(grade) == "string" then grade else BeastRules.DEFAULT_GRADE,
			if typeof(stars) == "number" then stars else BeastRules.START_STARS
		)
		ElementAura.attach(instance, card.element, intensity)
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
