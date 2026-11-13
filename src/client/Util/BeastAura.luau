--!strict
-- A creature's element aura, on this client only (owner 2026-11-13, "finalize all" the pet glows and auras): the store
-- packs' effects (Util/PackEmitter, Config/BeastFx) on bones spread over the body (Util/BeastFxRules picks them, so the
-- aura moves with the animation), rising from the ground under Legendaries, with a flickering light and dust from the
-- feet while it walks. Grade S Legendaries (tier Divine) add a turning halo behind the head, small orbs circling it and
-- embers left where they walk; grade S and A copies of other cards a lighter tier. How much of it shows follows the
-- budget (BeastFxRules.budget): another player's creature in your boss fight, or every creature on low graphics or a
-- struggling frame rate, keeps its look with fewer particles. Everything turns off while the camera is far away.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BeastFx = require(Shared:WaitForChild("Config"):WaitForChild("BeastFx"))
local BeastFxRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastFxRules"))
local PackEmitter = require((script.Parent :: Instance):WaitForChild("PackEmitter"))
local Extras = require((script.Parent :: Instance):WaitForChild("Extras"))

-- The grade S Legendary extras (tier Divine)
export type Divine = {
	head: Bone?,
	height: number,
	halo: Part,
	orbs: { Part },
	discs: { Part }, -- a void orb's glowing disc, by orb (none for plain orbs)
	time: number,
	nextEmber: number,
	embers: number,
}

export type Aura = {
	model: Model,
	look: BeastFx.Look,
	tier: BeastFx.Tier,
	size: number,
	mine: boolean,
	emitters: { ParticleEmitter }, -- the body's, the halo's and the orbs' (each with its full rate as BaseRate)
	ground: { ParticleEmitter },
	dust: ParticleEmitter?,
	light: PointLight,
	near: boolean,
	shown: BeastFxRules.Shown,
	budgetKey: number, -- the budget flags last applied (-1: none yet)
	nextFlicker: number,
	base: Part,
	divine: Divine?,
}

local BeastAura = {}

local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local rng = Random.new()
local DIVINE = BeastFx.DIVINE

-- The packs' textures load in the background from the start: fetched on first sight, an aura came in blank for seconds
do
	local seen: { [string]: boolean } = {}
	local specs = {}
	for _, look in BeastFx.ELEMENTS do
		for _, group in { look.layers, look.ground, look.halo, look.orb } do
			for _, layer in group do
				if not seen[layer.texture] then
					seen[layer.texture] = true
					table.insert(specs, layer)
				end
			end
		end
	end
	PackEmitter.preload(specs)
end

local function rgb(color: BeastFx.Rgb): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- One pack layer on `parent` at `scale`, emitting `rate` a second at full budget (kept as BaseRate); `depth` studs
-- nearer the camera than the layer's own ZOffset
local function addLayer(parent: Instance, layer: BeastFx.Layer, scale: number, rate: number, depth: number, list: { ParticleEmitter }): ParticleEmitter
	local emitter = PackEmitter.make(layer, scale)
	emitter.Name = "BeastAura"
	emitter.ZOffset += depth
	emitter:SetAttribute("BaseRate", rate)
	emitter.Rate = rate
	emitter.Parent = parent
	table.insert(list, emitter)
	return emitter
end

local function glowPart(name: string, shape: Enum.PartType, size: number, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Size = Vector3.new(size, size, size)
	return part
end

-- The grade S Legendary extras: a ring of the look's halo layer (turned each frame to sit behind the head) and small
-- neon orbs circling it wearing its orb layer; their emitters join the aura's so they follow its budget and switch off
-- with it. No lights of their own: lit from this close, the model glares white
local function addDivine(model: Model, look: BeastFx.Look, tier: BeastFx.Tier, size: number, height: number, emitters: { ParticleEmitter }): Divine
	local color = rgb(look.light.color)
	local scale = BeastFxRules.scale(BeastFx, size, tier)
	local head = model:FindFirstChild("Head_0", true)
	local halo = glowPart("DivineHalo", Enum.PartType.Block, 0.1, color, 1)
	for _, point in BeastFxRules.ring(DIVINE.HALO.count, DIVINE.HALO.radius * height, 0) do
		local spot = Instance.new("Attachment")
		spot.Position = Vector3.new(point[1], point[2], 0)
		spot.Parent = halo
		for _, layer in look.halo do
			local emitter = addLayer(spot, layer, scale, layer.rate * tier.rate / DIVINE.HALO.count, 0, emitters)
			emitter.LockedToPart = true
		end
	end
	halo.Parent = model
	local orbs: { Part } = {}
	local discs: { Part } = {}
	for _ = 1, DIVINE.ORBS.count do
		local orb = glowPart("DivineOrb", Enum.PartType.Ball, DIVINE.ORBS.size * size, color, 0)
		if look.void then
			-- A little black hole: a black core in a glowing disc
			orb.Name = "DivineVoid"
			orb.Material = Enum.Material.SmoothPlastic
			orb.Color = Color3.new(0, 0, 0)
			local disc = glowPart("DivineVoidDisc", Enum.PartType.Cylinder, orb.Size.X * DIVINE.VOID_DISC.size, color, 0.35)
			disc.Size = Vector3.new(0.02, disc.Size.Y, disc.Size.Z)
			disc.Parent = model
			table.insert(discs, disc)
		end
		for _, layer in look.orb do
			addLayer(orb, layer, scale, layer.rate * tier.rate, 0, emitters)
		end
		orb.Parent = model
		table.insert(orbs, orb)
	end
	return {
		head = if head and head:IsA("Bone") then head else nil,
		height = height,
		halo = halo,
		orbs = orbs,
		discs = discs,
		time = 0,
		nextEmber = 0,
		embers = 0,
	}
end

-- An ember left on the ground where it walked (its ground layers, small), fading out; a dark rift for a void look
local function dropEmber(aura: Aura, divine: Divine)
	if divine.embers >= DIVINE.EMBERS.max then
		return
	end
	divine.embers += 1
	local color = rgb(aura.look.light.color)
	local ember = glowPart("DivineEmber", Enum.PartType.Cylinder, DIVINE.EMBERS.size * aura.size, color, 0.2)
	if aura.look.void then
		ember.Name = "DivineRift"
		ember.Color = color:Lerp(Color3.new(0, 0, 0), 0.7)
	end
	ember.Size = Vector3.new(0.05, ember.Size.Y, ember.Size.Z)
	local at = aura.base.Position + Vector3.new(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)) * aura.size
	ember.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
	local made: { ParticleEmitter } = {}
	for _, layer in aura.look.ground do
		addLayer(ember, layer, BeastFxRules.scale(BeastFx, aura.size, aura.tier) * DIVINE.EMBERS.size, layer.rate * DIVINE.EMBERS.size, 0, made)
	end
	ember.Parent = workspace
	local fade = TweenService:Create(ember, TweenInfo.new(DIVINE.EMBERS.seconds), { Transparency = 1 })
	task.delay(DIVINE.EMBERS.seconds * 0.6, function()
		for _, emitter in made do
			emitter.Enabled = false
		end
	end)
	fade.Completed:Once(function()
		ember:Destroy()
		divine.embers -= 1
	end)
	fade:Play()
end

-- One frame of the extras: the halo turning behind the head, the orbs circling, embers while it walks
local function stepDivine(aura: Aura, divine: Divine, dt: number, moving: boolean)
	divine.time += dt
	local facing = aura.model:GetPivot().LookVector
	local head = if divine.head then divine.head.TransformedWorldCFrame.Position else aura.base.Position + Vector3.new(0, divine.height * 0.85, 0)
	local centre = head - facing * DIVINE.HALO.behind * divine.height
	divine.halo.CFrame = CFrame.lookAt(centre, centre + facing) * CFrame.Angles(0, 0, math.rad(DIVINE.HALO.spin) * divine.time)
	local feet = aura.base.Position
	for index, orb in divine.orbs do
		local at = BeastFxRules.orbit(index, #divine.orbs, divine.time, DIVINE.ORBS.seconds, DIVINE.ORBS.radius * divine.height,
			DIVINE.ORBS.height * divine.height, DIVINE.ORBS.bob * divine.height)
		orb.CFrame = CFrame.new(feet + Vector3.new(at[1], at[2], at[3]))
		local disc = divine.discs[index]
		if disc then
			disc.CFrame = orb.CFrame * CFrame.Angles(0, 0, math.rad(DIVINE.VOID_DISC.tilt))
				* CFrame.Angles(math.rad(DIVINE.VOID_DISC.spin) * divine.time, 0, 0)
		end
	end
	if not moving or not aura.shown.embers then
		return
	end
	divine.nextEmber -= dt
	if divine.nextEmber <= 0 then
		divine.nextEmber = DIVINE.EMBERS.every
		dropEmber(aura, divine)
	end
end

-- Everything on or off for the camera's distance and the budget
local function refresh(aura: Aura)
	local near, shown = aura.near, aura.shown
	for _, emitter in aura.emitters do
		emitter.Rate = ((emitter:GetAttribute("BaseRate") :: number?) or 0) * shown.rate
		emitter.Enabled = near
	end
	for _, emitter in aura.ground do
		emitter.Rate = ((emitter:GetAttribute("BaseRate") :: number?) or 0) * shown.rate
		emitter.Enabled = near and shown.ground
	end
	aura.light.Enabled = near and shown.light
	local divine = aura.divine
	if divine then
		for _, orb in divine.orbs do
			orb.Transparency = if near then 0 else 1
		end
		for _, disc in divine.discs do
			disc.Transparency = if near then 0.35 else 1
		end
	end
end

-- Adds the aura to a creature model standing on `floor`, at a tier (BeastFx.TIERS: Divine, Legendary, S, A); `mine`:
-- this player's own creature (always drawn whole but on low graphics). nil for an element or tier without one
function BeastAura.attach(model: Model, floor: CFrame, element: string, size: number, tierName: string, mine: boolean): Aura?
	local look = BeastFx.ELEMENTS[element]
	local tier = BeastFx.TIERS[tierName]
	if not look or not tier then
		return nil
	end
	local bones: { Bone } = {}
	local names: { string } = {}
	local points: { BeastFxRules.Point } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") then
			local at = descendant.WorldPosition
			table.insert(bones, descendant)
			table.insert(names, descendant.Name)
			table.insert(points, { at.X, at.Y, at.Z })
		end
	end
	local _, extent = model:GetBoundingBox()
	-- Both sides glow alike: a picked ear or foot brings its mirror along; each layer's rate is shared out between them
	local burning = BeastFxRules.withMirrors(names, BeastFxRules.spread(points, tier.bones))
	local scale = BeastFxRules.scale(BeastFx, size, tier)
	local depth = math.max(extent.X, extent.Z) * BeastFx.DEPTH
	local emitters: { ParticleEmitter } = {}
	for _, index in burning do
		for _, layer in look.layers do
			addLayer(bones[index], layer, scale, layer.rate * tier.rate / #burning, depth, emitters)
		end
	end

	-- A flat invisible part over the footprint: ground layers rise from all of it, the light and dust sit on it
	local base = Instance.new("Part")
	base.Name = "AuraBase"
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	base.Transparency = 1
	base.Size = Vector3.new(extent.X * 0.8, 0.2, extent.Z * 0.8)
	base.CFrame = floor * CFrame.new(0, 0.1, 0)
	base.Parent = model
	local ground: { ParticleEmitter } = {}
	if tier.ground then
		for _, layer in look.ground do
			addLayer(base, layer, scale, layer.rate * tier.rate, 0, ground)
		end
	end

	local light = Instance.new("PointLight")
	light.Color = rgb(look.light.color)
	light.Brightness = look.light.brightness * tier.light
	light.Range = look.light.range * math.sqrt(tier.light)
	light.Shadows = false
	local glow = Instance.new("Attachment")
	glow.Name = "Glow"
	glow.Position = Vector3.new(0, extent.Y * 0.5, 0)
	glow.Parent = base
	light.Parent = glow

	local divine = if tier.divine then addDivine(model, look, tier, size, extent.Y, emitters) else nil

	local dust: ParticleEmitter? = nil
	if tier.dust then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Dust"
		emitter.Texture = DUST_TEXTURE
		emitter.Color = ColorSequence.new(Color3.fromRGB(200, 190, 175))
		emitter.Transparency = NumberSequence.new(0.55, 1)
		emitter.Size = NumberSequence.new(size * 0.6, size * 1.6)
		emitter.Lifetime = NumberRange.new(0.6, 1)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.SpreadAngle = Vector2.new(70, 70)
		emitter.Rate = 0
		emitter.Parent = base
		dust = emitter
	end

	local aura: Aura = {
		model = model,
		look = look,
		tier = tier,
		size = size,
		mine = mine,
		emitters = emitters,
		ground = ground,
		dust = dust,
		light = light,
		near = true,
		shown = BeastFxRules.budget(tier, BeastFx.BUDGET, true, false, false),
		budgetKey = -1,
		nextFlicker = 0,
		base = base,
		divine = divine,
	}
	refresh(aura)
	return aura
end

-- One frame. speed: studs a second (dust while moving); far: camera further than BeastFx.FAR (all off)
function BeastAura.step(aura: Aura, dt: number, speed: number, moving: boolean, far: boolean)
	local near = not far
	local bossFight, low = Extras.bossFight(), not Extras.enabled()
	local key = (if bossFight and not aura.mine then 1 else 0) + (if low then 2 else 0)
	if near ~= aura.near or key ~= aura.budgetKey then
		aura.near = near
		if key ~= aura.budgetKey then
			aura.budgetKey = key
			aura.shown = BeastFxRules.budget(aura.tier, BeastFx.BUDGET, aura.mine, bossFight, low)
		end
		refresh(aura)
	end
	local dust = aura.dust
	if dust then
		dust.Rate = if near and moving and aura.shown.dust then math.min(speed * BeastFx.DUST.PER_SPEED, BeastFx.DUST.MAX) else 0
	end
	if not near then
		return
	end
	if aura.divine then
		stepDivine(aura, aura.divine, dt, moving)
	end
	if not aura.shown.light then
		return
	end
	aura.nextFlicker -= dt
	if aura.nextFlicker <= 0 then
		aura.nextFlicker = BeastFx.FLICKER_SECONDS
		aura.light.Brightness = aura.look.light.brightness * aura.tier.light * rng:NextNumber(BeastFx.FLICKER[1], BeastFx.FLICKER[2])
	end
end

return BeastAura
