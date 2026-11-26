--!strict
-- Draws every wild monster on this client. WildService moves an invisible marker per monster in
-- workspace.Monsters (attributes MonsterId, Species, Level, Elite, Element, Fighting); here each marker gets a
-- model (ReplicatedStorage.MonsterModels[Species], or a placeholder shape in its element colour), the same
-- motion as summoned creatures (CreatureVisuals) and a name tag. Elites are bigger with a gold tag; bosses (attribute
-- Boss, a Config/Bosses id) are drawn from their config at its scale with a red tag. Each species has its own height
-- (Util/MonsterLooks); a model with PetRig bones moves them (Util/PetAnimator, styled by species, a boss by its id),
-- its glow mask shines at the species' steady glow strength, and a boss with heads (Config/Bosses heads: the Prism Hydra) lights the head of its
-- current phase (marker attribute Phase) and drops its heads one by one when it falls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Prologue = require(Config:WaitForChild("Prologue"))
local Dungeon = require(Config:WaitForChild("Dungeon"))
local Cards = require(Config:WaitForChild("Cards"))
local Party = require(Config:WaitForChild("Party"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
-- The server wild map in the main game, the Frontier in the Frontier place
local Wild = Place.getWorld()
local MonsterLooks = require(Shared:WaitForChild("Util"):WaitForChild("MonsterLooks"))
local BossMoments = require(Shared:WaitForChild("Util"):WaitForChild("BossMoments"))
local BossIdleRules = require(Shared:WaitForChild("Util"):WaitForChild("BossIdleRules"))
local SummonRules = require(Shared:WaitForChild("Util"):WaitForChild("SummonRules"))
local CreatureVisuals = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("CreatureVisuals"))
local Extras = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("Extras"))
local PetAnimator = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("PetAnimator"))
local ClipPlayer = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("ClipPlayer"))
local CrystalLook = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("CrystalLook"))

local MonsterController = {}
local SwordFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SwordFx"))
local HitFx = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("HitFx"))
local SoundBank = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("SoundBank"))
local Combat = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Combat"))
local ScreenFx = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("ScreenFx"))
local MonsterKO = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("MonsterKO"))
local MonsterKOConfig = require(Config:WaitForChild("MonsterKO"))
local HitFeel = require(Shared:WaitForChild("Util"):WaitForChild("HitFeel"))
local HitFeelConfig = require(Config:WaitForChild("HitFeel"))
local FinishingBlowRules = require(Shared:WaitForChild("Util"):WaitForChild("FinishingBlowRules"))
local FinishingBlowConfig = require(Config:WaitForChild("FinishingBlow"))

local ELITE_TAG_COLOR = Color3.fromRGB(255, 205, 60)
local TAG_COLOR = Color3.fromRGB(235, 235, 235)
local BOSS_TAG_COLOR = Color3.fromRGB(255, 90, 80)

type Head = { element: string, light: PointLight, sparks: ParticleEmitter }
-- A boss between its moves (Util/BossIdleRules): where it stands off its spot (x, z: its spot's own space), a walk
-- under way (from, to, started), when it may do the next thing, until when a move holds it and when its intro ends (all
-- os.clock), its roar sound
type Idle = { x: number, z: number, walk: { ax: number, az: number, bx: number, bz: number, start: number }?, nextAt: number, busyUntil: number, introEnd: number, roar: string?, cfg: any, scale: number }
type Aura = { highlight: Highlight, light: PointLight, flames: { ParticleEmitter } }
type Monster = {
	marker: BasePart,
	body: CreatureVisuals.Body,
	tag: TextLabel,
	connections: { RBXScriptConnection },
	heads: { Head }, -- a boss with heads: one per Hydra_<n>_3 bone, n = index - 1
	fallenAt: number?, -- os.clock() its death began (heads dropping)
	runes: { SurfaceAppearance }?, -- a boss with phaseGlow: its glow-masked surfaces, tinted by phase
	runePhase: any, -- the phase they were last tinted for (set only when it changes)
	aura: Aura?, -- a boss with a rainbow aura
	fx: { ParticleEmitter }, -- sparks or smoke on its Fx_ bones (Config/Wild SPECIES fx), on only near the camera
	lasting: { ParticleEmitter }, -- a boss's plume while it is enraged (Config/Bosses moments.enrage)
	enraged: boolean, -- its marker's Enraged attribute
	key: string, -- its boss id, else its species: its model and attack clips are saved under this
	element: string,
	height: number,
	clips: { [string]: ClipPlayer.Clip }, -- its attack clips (ReplicatedStorage.MonsterAnimations/<key>), if any
	lengths: { [string]: number }, -- each clip's length in seconds
	clipPlayer: ClipPlayer.Player?,
	idle: Idle?, -- a boss's life between its moves (a Dungeon pack's and a wild monster's steps too)
	-- A boss's summon (marker Size, Emerge, EmergeAt; the Rift Devourer's): climbing out of its rift until `at` +
	-- `seconds` (the server's clock), and the void wisps it trails while it runs
	emerge: { at: number, seconds: number }?,
	trail: ParticleEmitter?,
	-- Hit feel (spec 2026-11-25-hit-feel-design): a wild monster (not a boss or a Dungeon pack), its reaction to its last
	-- hit, its lunge into a strike (os.clock start, seconds) and its reused white flash
	wild: boolean?,
	react: HitFeel.Reaction?,
	lunge: { at: number, length: number }?,
	flash: Highlight?,
	-- The finishing blow (Config/FinishingBlow): a boss's beaten mark seen (asked once), and it held still until then
	beaten: boolean?,
	heldUntil: number?,
	-- A boss turns to what it goes for (FaceToward): where that is now (nil once it's gone), and the turn it has
	faceAt: (() -> Vector3?)?,
	faceYaw: number?,
}

local TRAIL_SPEED = 3 -- studs a second: a summon running faster than this trails its wisps

local monsters: { [BasePart]: Monster } = {}

local BALL, BLOCK = Enum.PartType.Ball, Enum.PartType.Block

-- Simple part-built stand-ins, one look per species shape, all facing -Z
local function makePlaceholder(shape: string, color: Color3): Model
	local model = Instance.new("Model")
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.4)
	local light = color:Lerp(Color3.new(1, 1, 1), 0.35)
	local eye = Color3.new(0.08, 0.08, 0.1)
	local function add(shapeType: Enum.PartType, size: Vector3, x: number, y: number, z: number, partColor: Color3)
		CreatureVisuals.addPart(model, "Part", shapeType, size, CFrame.new(x, y, z), partColor)
	end
	local function eyes(y: number, z: number, spread: number)
		for _, side in { -1, 1 } do
			add(BALL, Vector3.new(0.3, 0.3, 0.3), spread * side, y, z, eye)
		end
	end
	if shape == "slime" then
		add(BLOCK, Vector3.new(2.4, 1.6, 2.4), 0, 0.8, 0, color)
		add(BLOCK, Vector3.new(1.6, 0.4, 1.6), 0, 1.75, 0, light)
		eyes(1.1, -1.22, 0.45)
	elseif shape == "crab" then
		add(BLOCK, Vector3.new(2.6, 1, 1.8), 0, 0.9, 0, color)
		for _, side in { -1, 1 } do
			add(BLOCK, Vector3.new(0.7, 0.6, 0.9), 1.7 * side, 1, -0.9, dark)
			add(BLOCK, Vector3.new(0.2, 0.6, 0.2), 0.4 * side, 1.6, -0.6, dark)
			add(BALL, Vector3.new(0.3, 0.3, 0.3), 0.4 * side, 2, -0.6, eye)
			for leg = -1, 1 do
				add(BLOCK, Vector3.new(0.9, 0.2, 0.2), 1.4 * side, 0.3, leg * 0.6, dark)
			end
		end
	elseif shape == "bat" then
		add(BALL, Vector3.new(1.6, 1.6, 1.6), 0, 1, 0, color)
		for _, side in { -1, 1 } do
			add(BLOCK, Vector3.new(1.8, 0.12, 1), 1.6 * side, 1.2, 0.1, dark)
			add(BLOCK, Vector3.new(0.3, 0.5, 0.2), 0.4 * side, 1.9, 0, dark)
		end
		eyes(1.15, -0.75, 0.3)
	elseif shape == "beetle" then
		add(BALL, Vector3.new(2.4, 1.6, 2.6), 0, 0.8, 0.2, color)
		add(BLOCK, Vector3.new(0.1, 1.2, 2.4), 0, 1.1, 0.2, dark)
		add(BALL, Vector3.new(1.1, 0.9, 1), 0, 0.7, -1.3, dark)
		eyes(0.85, -1.75, 0.3)
		for _, side in { -1, 1 } do
			add(BLOCK, Vector3.new(0.1, 0.1, 0.8), 0.25 * side, 1.1, -1.9, light)
		end
	elseif shape == "golem" then
		add(BLOCK, Vector3.new(2.4, 2, 1.6), 0, 2.2, 0, color)
		add(BLOCK, Vector3.new(1.4, 1.1, 1.2), 0, 3.75, -0.1, dark)
		for _, side in { -1, 1 } do
			add(BLOCK, Vector3.new(0.8, 2, 0.8), 1.65 * side, 1.9, 0, dark)
			add(BLOCK, Vector3.new(0.8, 1.2, 0.8), 0.6 * side, 0.6, 0, dark)
		end
		add(BLOCK, Vector3.new(1, 0.25, 0.1), 0, 3.85, -0.72, light)
	else -- wolf
		add(BLOCK, Vector3.new(1.2, 1.1, 2.6), 0, 1.4, 0, color)
		add(BLOCK, Vector3.new(1, 0.9, 1), 0, 1.9, -1.6, color)
		add(BLOCK, Vector3.new(0.6, 0.4, 0.6), 0, 1.7, -2.3, dark)
		for _, side in { -1, 1 } do
			add(BLOCK, Vector3.new(0.25, 0.5, 0.2), 0.3 * side, 2.55, -1.5, dark)
			add(BLOCK, Vector3.new(0.3, 0.9, 0.3), 0.4 * side, 0.45, -0.9, dark)
			add(BLOCK, Vector3.new(0.3, 0.9, 0.3), 0.4 * side, 0.45, 0.9, dark)
		end
		add(BLOCK, Vector3.new(0.3, 0.3, 1.2), 0, 1.8, 1.7, dark)
		eyes(2.05, -2.12, 0.25)
	end
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

local function updateTag(monster: Monster)
	local marker = monster.marker
	local species = marker:GetAttribute("Species")
	local level = marker:GetAttribute("Level")
	local elite = marker:GetAttribute("Elite") == true
	local boss = marker:GetAttribute("Boss") ~= nil
	local fighting = marker:GetAttribute("Fighting") == true
	local name = if typeof(species) == "string" then species else "Monster"
	monster.tag.Text = `{if fighting then "⚔ " else ""}{if boss then "BOSS " elseif elite then "ELITE " else ""}{name}\nLv {if typeof(level) == "number" then level else 1}`
	monster.tag.TextColor3 = if boss then BOSS_TAG_COLOR elseif elite then ELITE_TAG_COLOR else TAG_COLOR
end

-- Only the current phase's head glows (marker attribute Phase, set by BattleService); none once it has fallen
local function lightHeads(monster: Monster)
	local phase = monster.marker:GetAttribute("Phase")
	-- The rune lines in the phase's element colour: set once per phase (a tint that keeps changing costs about 6 ms of
	-- render CPU a frame, docs/creatures.md "Glow masks")
	if monster.runes and phase ~= monster.runePhase then
		monster.runePhase = phase
		local tint = if typeof(phase) == "string" and Cards.ELEMENTS[phase] then Cards.ELEMENTS[phase] else Color3.new(1, 1, 1)
		for _, surface in monster.runes do
			pcall(function()
				surface.EmissiveTint = tint
			end)
		end
	end
	for _, head in monster.heads do
		local on = monster.fallenAt == nil and head.element == phase
		head.light.Enabled = on
		head.sparks.Enabled = on
	end
end

-- A light and sparks on each head bone, in that head's element colour (off until its phase)
local function makeHeads(model: Model, elements: { string }): { Head }
	local heads = {}
	for index, element in elements do
		local bone = model:FindFirstChild(`Hydra_{index - 1}_3`, true)
		if bone and bone:IsA("Bone") then
			local color = Cards.ELEMENTS[element] or Color3.new(1, 1, 1)
			local light = Instance.new("PointLight")
			light.Color = color
			light.Brightness = Bosses.HEAD_GLOW.brightness
			light.Range = Bosses.HEAD_GLOW.range
			light.Enabled = false
			light.Parent = bone
			local sparks = Instance.new("ParticleEmitter")
			sparks.Color = ColorSequence.new(color)
			sparks.LightEmission = 1
			sparks.Rate = Bosses.HEAD_GLOW.particles
			sparks.Lifetime = NumberRange.new(0.5, 0.9)
			sparks.Speed = NumberRange.new(1, 3)
			sparks.SpreadAngle = Vector2.new(180, 180)
			sparks.Size = NumberSequence.new(0.5, 0)
			sparks.Enabled = false
			sparks.Parent = bone
			table.insert(heads, { element = element, light = light, sparks = sparks })
		end
	end
	return heads
end

-- A rainbow aura on a boss (Bosses.RAINBOW_AURA): the model itself glows, a coloured outline round it and a faint
-- colour wash over it (the model always shows through), and a light; MonsterController's frame loop turns the colour
local function makeAura(body: CreatureVisuals.Body): Aura
	local look = Bosses.RAINBOW_AURA
	local highlight = Instance.new("Highlight")
	highlight.Name = "RainbowAura"
	highlight.Adornee = body.model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded -- not through walls
	highlight.OutlineTransparency = look.outlineTransparency
	highlight.FillTransparency = look.fillTransparency
	highlight.Parent = body.model
	local light = Instance.new("PointLight")
	light.Brightness = look.lightBrightness
	light.Range = look.lightRange
	light.Parent = body.root
	return { highlight = highlight, light = light, flames = {} }
end

local AURORA = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 255, 170)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 210, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 110, 255)),
})

-- An aurora flame (Bosses.AURORA_FLAME): soft flames in aurora colours rising off its back (above the listed bones,
-- on its outside, not from inside the body), over the glow
local function makeFlames(model: Model, root: BasePart): { ParticleEmitter }
	local look = Bosses.AURORA_FLAME
	local box, size = model:GetBoundingBox()
	local top = box.Position.Y - size.Y / 2 + size.Y * look.height
	local flames = {}
	for _, name in look.bones do
		local bone = model:FindFirstChild(name, true)
		if bone and bone:IsA("Bone") then
			local spot = Instance.new("Attachment")
			spot.Name = "AuroraFlame"
			spot.Parent = root
			spot.WorldPosition = Vector3.new(bone.WorldPosition.X, top, bone.WorldPosition.Z)
			local flame = Instance.new("ParticleEmitter")
			flame.Name = "AuroraFlame"
			flame.Texture = "rbxasset://textures/particles/fire_main.dds"
			flame.Color = AURORA
			flame.LightEmission = 1
			flame.Rate = look.rate
			flame.Lifetime = NumberRange.new(look.lifetimeMin, look.lifetimeMax)
			flame.Speed = NumberRange.new(0.5, 1.5)
			flame.SpreadAngle = Vector2.new(180, 180)
			flame.Acceleration = Vector3.new(0, look.rise, 0) -- up in the world, whichever way the bone points
			flame.Size = NumberSequence.new(look.sizeStart, look.sizeEnd)
			flame.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, look.transparency),
				NumberSequenceKeypoint.new(1, 1),
			})
			flame.Rotation = NumberRange.new(-20, 20)
			flame.Parent = spot
			table.insert(flames, flame)
		end
	end
	return flames
end

local function stepAura(monster: Monster, now: number)
	local aura = monster.aura :: Aura
	local color = Color3.fromHSV((now / Bosses.RAINBOW_AURA.hueSeconds) % 1, 0.6, 1)
	aura.highlight.OutlineColor = color
	aura.highlight.FillColor = color
	aura.light.Color = color
	if monster.fallenAt then
		for _, flame in aura.flames do
			flame.Enabled = false
		end
		aura.highlight.OutlineTransparency = math.min(1, aura.highlight.OutlineTransparency + 0.02)
		aura.highlight.FillTransparency = math.min(1, aura.highlight.FillTransparency + 0.02)
		aura.light.Enabled = false
	end
end

-- Its death: the outer heads first, the middle one last, each neck bowing down over HEAD_DROP.seconds
local function dropHeads(monster: Monster, now: number)
	local pet = monster.body.pet
	local fallenAt = monster.fallenAt
	if not pet or not fallenAt then
		return
	end
	local drop = Bosses.HEAD_DROP
	for _, entry in (pet :: any).bones do
		local head = tonumber(string.match(entry.key, "^hydra:(%d+):0$") or "")
		if head then
			local delay = (#monster.heads - 1 - head) * drop.gap
			local share = math.clamp((now - fallenAt - delay) / drop.seconds, 0, 1)
			entry.bone.Transform = entry.restInverse * CFrame.Angles(-math.rad(drop.angle) * share, 0, 0) * entry.rest
		end
	end
end

local function remove(marker: BasePart)
	local monster = monsters[marker]
	if not monster then
		return
	end
	monsters[marker] = nil
	for _, connection in monster.connections do
		connection:Disconnect()
	end
	monster.body.model:Destroy()
end

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- An emitter on each named Fx_ bone of the model (a Bone is an Attachment, so it emits from there), off, from a look's
-- numbers (Config/Wild FX, Config/Bosses MOMENT_FX)
local function emitters(model: Model, bones: { string }, look: any): { ParticleEmitter }
	local made = {}
	for _, name in bones do
		local bone = model:FindFirstChild(name, true)
		if bone and bone:IsA("Bone") then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = look.texture
			emitter.Color = ColorSequence.new(rgb(look.color))
			emitter.LightEmission = look.lightEmission
			emitter.Size = NumberSequence.new(look.size[1], look.size[2])
			emitter.Transparency = NumberSequence.new(look.transparency[1], look.transparency[2])
			emitter.Lifetime = NumberRange.new(look.lifetime[1], look.lifetime[2])
			emitter.Rate = look.rate or 0
			emitter.Speed = NumberRange.new(look.speed[1], look.speed[2])
			emitter.SpreadAngle = Vector2.new(look.spread, look.spread)
			emitter.Acceleration = Vector3.new(0, look.rise, 0)
			emitter.ZOffset = look.zOffset or 0
			emitter.Enabled = false
			emitter.Parent = bone
			table.insert(made, emitter)
		end
	end
	return made
end

-- A species' small effect on its model's Fx_ bones, off until the camera comes near
local function makeFx(model: Model, fx: any, world: any): { ParticleEmitter }
	local look = world.FX[fx.kind]
	return if look then emitters(model, fx.bones, look) else {}
end

-- A boss's moment effect on the bones BossMoments.anchors found (none without them, so no model means no effect)
local function momentFx(model: Model, bones: { string }?, kind: string?): { ParticleEmitter }
	local look = if kind then Bosses.MOMENT_FX[kind] else nil
	return if bones and look then emitters(model, bones, look) else {}
end

local function burstAll(list: { ParticleEmitter }, kind: string)
	for _, emitter in list do
		emitter:Emit(Bosses.MOMENT_FX[kind].burst or 10)
	end
end

-- A boss's moments (Config/Bosses moments, Util/BossMoments) from its marker's attributes: the intro roar (a pose and
-- its sound), the heal flare and the enrage vents. A player arriving mid-fight sees the vents smoking, never a replay
local function startMoments(monster: Monster, moments: any)
	local marker, body = monster.marker, monster.body
	local names: { [string]: boolean } = {}
	for _, descendant in body.model:GetDescendants() do
		if descendant:IsA("Bone") then
			names[descendant.Name] = true
		end
	end
	local delay = BossMoments.roarIn(tonumber(marker:GetAttribute("SpawnedAt")), workspace:GetServerTimeNow(), Bosses.ROAR_SHAKE.at)
	if delay then
		task.delay(delay, function()
			if monsters[marker] ~= monster then
				return
			end
			if body.pet then
				PetAnimator.play(body.pet, "wildroar", os.clock())
			end
			local sound = SoundBank.make(moments.roar)
			sound.Volume = moments.roarVolume or Bosses.ROAR_VOLUME
			sound.Parent = body.root
			sound.Ended:Once(function()
				sound:Destroy()
			end)
			sound:Play()
		end)
	end
	local heal = momentFx(body.model, BossMoments.anchors(moments.heal, names), moments.heal and moments.heal.fx)
	if #heal > 0 then
		local seen = tonumber(marker:GetAttribute("Heals")) or 0 -- no heal yet counts as 0, so the first one flares
		table.insert(monster.connections, marker:GetAttributeChangedSignal("Heals"):Connect(function()
			local current = tonumber(marker:GetAttribute("Heals"))
			if BossMoments.flares(seen, current) and Extras.enabled() then
				burstAll(heal, moments.heal.fx)
			end
			seen = current or seen
		end))
	end
	local enrage = moments.enrage
	local vents = BossMoments.anchors(enrage, names)
	if vents then
		local burst = momentFx(body.model, vents, enrage.burst)
		monster.lasting = momentFx(body.model, vents, enrage.lasting)
		monster.enraged = marker:GetAttribute("Enraged") == true
		table.insert(monster.connections, marker:GetAttributeChangedSignal("Enraged"):Connect(function()
			local enraged = marker:GetAttribute("Enraged") == true
			if enraged and not monster.enraged and Extras.enabled() then
				burstAll(burst, enrage.burst)
			end
			monster.enraged = enraged
		end))
	end
end

-- Lights the model's glow masks once: a SurfaceAppearance whose strength keeps changing costs about 6.6 ms of render
-- CPU a frame, so glows stay steady
-- A model's glow-masked SurfaceAppearances (its rune lines, markings)
local function glowSurfaces(model: Model): { SurfaceAppearance }
	local list = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("SurfaceAppearance") and descendant.EmissiveMaskContent.SourceType ~= Enum.ContentSourceType.None then
			table.insert(list, descendant)
		end
	end
	return list
end

local function lightGlow(model: Model, strength: number)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("SurfaceAppearance") and descendant.EmissiveMaskContent.SourceType ~= Enum.ContentSourceType.None then
			descendant.EmissiveStrength = strength
		end
	end
end

local idleRandom = Random.new()

-- Its turn toward what it goes for now (FaceToward; testers 2026-11-26: "Boss still face/attack dead pets": it faced
-- the way its fight began, where your first creature fell), from where it stands (x, z in its spot's space). The turn
-- it has stays while that's gone (fainted, left); straight ahead, the fight, until something comes
local function faceYaw(monster: Monster, x: number, z: number): number
	local at = if monster.faceAt then monster.faceAt() else nil
	if at then
		local mine = monster.marker.CFrame:PointToObjectSpace(at)
		local yaw = BossIdleRules.faceYaw(x, z, mine.X, mine.Z)
		if yaw then
			monster.faceYaw = yaw
		end
	end
	return monster.faceYaw or 0
end

-- A boss between its moves (the owner 2026-11-10: "walking around while waiting for his next attack or roaring.
-- something intimidating but not limiting its attack speed"; Config/Bosses IDLE): short walks to new spots near its
-- own, a roar, a stomp, a second or two apart. A move only stops its feet: it attacks from wherever it stands, turned
-- to what it goes for, so its attacks keep the server's clock
local function stepIdle(monster: Monster, idle: Idle, now: number)
	local cfg = idle.cfg
	local body = monster.body
	local scale = idle.scale
	local walk = idle.walk
	if not BossIdleRules.free(now, idle.busyUntil, idle.introEnd, monster.marker:GetAttribute("Fainted") == true) then
		if walk then
			-- stopped where it is, turned to what it goes for
			local x, z = BossIdleRules.walk(now - walk.start, walk.ax, walk.az, walk.bx, walk.bz, cfg.wander.speed * scale)
			idle.x, idle.z, idle.walk = x, z, nil
		end
		body.offset = CFrame.new(idle.x, 0, idle.z) * CFrame.Angles(0, faceYaw(monster, idle.x, idle.z), 0)
		idle.nextAt = math.max(idle.nextAt, idle.busyUntil)
		return
	end
	if walk then
		local x, z, yaw, done = BossIdleRules.walk(now - walk.start, walk.ax, walk.az, walk.bx, walk.bz, cfg.wander.speed * scale)
		if monster.wild then
			yaw *= HitFeelConfig.STEP.turn -- a wild monster mostly keeps facing the fight as it steps (Config/HitFeel)
		end
		if done then
			idle.x, idle.z, idle.walk = x, z, nil
			idle.nextAt = now + BossIdleRules.gap(idleRandom:NextNumber(), cfg.gap)
			yaw = faceYaw(monster, x, z)
		end
		body.offset = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
		return
	end
	-- standing between its moves: turned to what it goes for
	body.offset = CFrame.new(idle.x, 0, idle.z) * CFrame.Angles(0, faceYaw(monster, idle.x, idle.z), 0)
	if now < idle.nextAt then
		return
	end
	local action = BossIdleRules.pick(idleRandom:NextNumber(), cfg.weights)
	idle.nextAt = now + BossIdleRules.gap(idleRandom:NextNumber(), cfg.gap)
	if action == "wander" then
		local bx, bz = BossIdleRules.spot(idleRandom:NextNumber(), idleRandom:NextNumber(), scale, cfg)
		idle.walk = { ax = idle.x, az = idle.z, bx = bx, bz = bz, start = now }
	elseif body.pet and action == "roar" then
		PetAnimator.play(body.pet, "wildroar", now)
		if idle.roar then
			local sound = SoundBank.make(idle.roar)
			sound.Volume = cfg.roarVolume
			sound.Parent = body.root
			sound.Ended:Once(function()
				sound:Destroy()
			end)
			sound:Play()
		end
	elseif body.pet and action == "stomp" then
		PetAnimator.play(body.pet, "stomp", now)
		ScreenFx.shakeAt(cfg.stompShake, body.root.Position)
	end
end

-- A hit's white flash (spec 2026-11-25-hit-feel-design 1): one Highlight per monster, made on its first hit and reused
-- (Roblox draws only so many at once), switched off once it has faded
local function flashWhite(monster: Monster)
	local react = HitFeelConfig.REACT
	local highlight = monster.flash
	if not highlight or not highlight.Parent then
		local made = Instance.new("Highlight")
		made.Name = "HitFlash"
		made.FillColor = Color3.new(1, 1, 1)
		made.OutlineTransparency = 1
		made.DepthMode = Enum.HighlightDepthMode.Occluded
		made.Adornee = monster.body.model
		made.Parent = monster.body.model
		monster.flash = made
		highlight = made
	end
	local shown = highlight :: Highlight
	shown.Enabled = true
	shown.FillTransparency = react.flash
	local fade = TweenService:Create(shown, TweenInfo.new(react.flashSeconds), { FillTransparency = 1 })
	fade.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed and shown.FillTransparency >= 1 then
			shown.Enabled = false
		end
	end)
	fade:Play()
end

-- A wild monster's offset off its server spot this frame (its own space: x right, z behind): its steps, its lunge
-- forward into a strike, and no further than MAX_DRIFT, so a sword swung at it still lands (spec
-- 2026-11-25-hit-feel-design 3, 4)
local function wildOffset(monster: Monster, now: number): CFrame
	local idle = monster.idle
	-- walking, the steps set this frame's offset (with its slight turn); else where its last step left it
	local base = if idle and idle.walk then monster.body.offset or CFrame.identity
		else CFrame.new(if idle then idle.x else 0, 0, if idle then idle.z else 0)
	local forward = 0
	local lunge = monster.lunge
	if lunge then
		local share = HitFeel.lunge(now - lunge.at, lunge.length, HitFeelConfig.LUNGE)
		if share then
			forward = share * HitFeelConfig.LUNGE.studs
		else
			monster.lunge = nil
		end
	end
	local at = base * CFrame.new(0, 0, -forward)
	local x, z = HitFeel.clampDrift(at.X, at.Z, HitFeelConfig.MAX_DRIFT)
	return CFrame.new(x, at.Y, z) * base.Rotation
end

-- A hit's jolt and lean away from the hitter and its pop, on top of where the monster is drawn (no smoothing: it snaps)
local function stepReaction(monster: Monster, now: number)
	local react = monster.react
	if not react then
		return
	end
	local amount = if monster.marker:GetAttribute("Fainted") == true then nil else HitFeel.amount(react, now)
	if not amount then
		monster.react = nil
		if not monster.emerge then
			monster.body.grow = nil
		end
		return
	end
	local pivot = monster.body.model:GetPivot()
	local away = Vector3.new(react.dx, 0, react.dz)
	-- leaning back: turned round the line across the push, so its top follows the push
	local across = Vector3.yAxis:Cross(away)
	local lean = if across.Magnitude > 0.01 then CFrame.fromAxisAngle(across.Unit, react.tilt * amount) else CFrame.identity
	monster.body.model:PivotTo(CFrame.new(pivot.Position + away * react.knock * amount) * lean * pivot.Rotation)
	if react.pop > 1 and not monster.emerge then
		monster.body.grow = 1 + (react.pop - 1) * amount
	end
end

-- A Dungeon room's monster rising (owner 2026-11-12: "a spawn effect instead of just popping out"): a ring of light
-- spreading on the ground, a burst of sparks, a flash and a rising whoosh where it comes up (Dungeon.PACK_SPAWN)
local function spawnBurst(at: Vector3, seconds: number)
	local look = Dungeon.PACK_SPAWN
	local color = rgb(look.color)
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(at.X, at.Y - 2.6, at.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.2
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 4
	light.Parent = ring
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(6, 14)
	sparks.SpreadAngle = Vector2.new(30, 30)
	sparks.Size = NumberSequence.new(0.6, 0)
	sparks.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis: up
	sparks.Parent = ring
	ring.Parent = workspace
	sparks:Emit(40)
	local sound = SoundBank.make(look.sound)
	sound.Volume = 0.4
	sound.Parent = ring
	sound:Play()
	local spread = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, spread, { Size = Vector3.new(0.2, 12, 12), Transparency = 1 }):Play()
	TweenService:Create(light, spread, { Brightness = 0 }):Play()
	task.delay(seconds + 1.5, ring.Destroy, ring)
end

-- Beaten monsters flying off (Config/MonsterKO, owner 2026-11-18 pick A: "make it smooth"), by marker, while it plays
local knockouts: { [BasePart]: MonsterKO.Handle } = {}

-- The finishing blow (client Util/FinishingBlow): asked once a monster is beaten, it plays the moment and gives its
-- numbers back when the monster is your own fight's (nil: anyone else's)
local finishingBlow: ((marker: BasePart, boss: boolean) -> FinishingBlowRules.Moment?)? = nil

function MonsterController.SetFinishingBlow(callback: (marker: BasePart, boss: boolean) -> FinishingBlowRules.Moment?)
	finishingBlow = callback
end

-- A beaten monster (not a boss: its own death scene) is knocked out: its model leaves its marker and flies off away from
-- the winner (the marker's KODir; else away from you), Util/MonsterKO's from now on. Further away than the knockout's
-- range it simply goes with its marker
local function knockOut(monster: Monster)
	local marker = monster.marker
	local camera = workspace.CurrentCamera
	if knockouts[marker] or not camera then
		return
	end
	if (monster.body.cframe.Position - camera.CFrame.Position).Magnitude > MonsterKOConfig.range then
		return
	end
	monsters[marker] = nil
	for _, connection in monster.connections do
		connection:Disconnect()
	end
	local tagGui = monster.tag:FindFirstAncestorWhichIsA("BillboardGui")
	if tagGui then
		tagGui:Destroy()
	end
	for _, emitter in monster.fx do
		emitter.Enabled = false
	end
	if monster.trail then
		monster.trail.Enabled = false
	end
	for _, track in monster.body.tracks do
		track:Stop(0.1)
	end
	local away = marker:GetAttribute("KODir")
	local direction: Vector3
	if typeof(away) == "Vector3" then
		direction = away
	else
		local character = game:GetService("Players").LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local from = if root and root:IsA("BasePart") then root.Position else camera.CFrame.Position
		direction = monster.body.cframe.Position - from
	end
	local moment = if finishingBlow then finishingBlow(marker, false) else nil
	local handle = MonsterKO.play(monster.body.model, direction, marker:GetAttribute("Elite") == true, moment)
	knockouts[marker] = handle
	handle.onDone(function()
		knockouts[marker] = nil
	end)
end

local function add(marker: BasePart)
	local species = marker:GetAttribute("Species")
	if monsters[marker] or typeof(species) ~= "string" then
		return
	end
	if marker:GetAttribute("Fainted") == true and marker:GetAttribute("Boss") == nil then
		return -- knocked out already, on its way out: nothing to draw
	end
	local bossId = marker:GetAttribute("Boss")
	local boss = if typeof(bossId) == "string" then Bosses.BOSSES[bossId] else nil
	-- a boss's summons may be another world's species (Place.worldOf: the prologue's Hydra calls Rift Horrors here)
	local world = if boss then Wild else Place.worldOf(species)
	local info: { element: string, shape: string }? = boss or (if world then world.SPECIES[species] else nil)
	if not info or not world then
		return
	end
	local elite = marker:GetAttribute("Elite") == true
	local color = Cards.ELEMENTS[info.element] or Color3.new(0.6, 0.6, 0.6)
	-- A boss model, when it exists, is saved under the boss's id; the prologue's Hydra (PrologueService's marker) has its
	-- own two-headed one (Config/Prologue HYDRA.model; set before the marker is parented, so it's here already)
	local prologueModel = if marker:GetAttribute("Prologue") == true then CreatureVisuals.getTemplate("MonsterModels", Prologue.HYDRA.model, Wild.MAX_MODEL_PARTS) else nil
	local template = prologueModel or CreatureVisuals.getTemplate("MonsterModels", if boss then bossId :: string else species, Wild.MAX_MODEL_PARTS)
	local model = if template then template:Clone() else makePlaceholder(info.shape, color)
	CreatureVisuals.strip(model)
	model.Name = `{species}_{marker:GetAttribute("MonsterId")}`

	local flying = boss == nil and table.find(world.FLYING, species) ~= nil
	local size = tonumber(marker:GetAttribute("Size"))
	local height = MonsterLooks.height(world, species, elite, if boss then boss.scale else nil, if boss then boss.height else nil, size)
	-- A model's bones move like a creature's (its PetRig names; Party style keyed by species, a boss by its id)
	local styleKey = MonsterLooks.styleKey(species, if boss then bossId :: string else nil, template ~= nil)
	local body = CreatureVisuals.build(model, marker, height, flying, styleKey)
	body.fxColor = color
	if Place.isDungeon() and not boss then
		CrystalLook.apply(model, body.root, height) -- the fight rooms' monsters, crystal-touched (spec 2026-11-11-dungeon-puzzles)
	end
	local glow = if boss then boss.glow else (world.SPECIES[species] :: any).glow
	if glow and template then
		lightGlow(model, glow.strength)
	end
	if boss and boss.light and template then
		local light = Instance.new("PointLight")
		light.Color = rgb(boss.light.color)
		light.Brightness = boss.light.brightness
		light.Range = boss.light.range
		light.Shadows = false
		light.Parent = body.root
	end
	local fxSpec = if boss or not template then nil else (world.SPECIES[species] :: any).fx
	local key = if boss then bossId :: string else species
	local clips, clipPlayer = ClipPlayer.loadSet(key, model)
	local lengths = {}
	for name, clip in clips do
		lengths[name] = clip.length
	end
	local monster: Monster = {
		marker = marker,
		body = body,
		tag = CreatureVisuals.makeTag(body.root, height + (if flying then Party.MOTION.HOVER_HEIGHT else 0), TAG_COLOR),
		connections = {},
		heads = if boss and boss.heads and template then makeHeads(model, boss.heads) else {},
		runes = if boss and boss.phaseGlow and template then glowSurfaces(model) else nil,
		runePhase = nil,
		fallenAt = nil,
		aura = if boss and boss.rainbowAura then makeAura(body) else nil,
		fx = if fxSpec then makeFx(model, fxSpec, world) else {},
		lasting = {},
		enraged = false,
		key = key,
		element = info.element,
		height = height,
		clips = clips,
		lengths = lengths,
		clipPlayer = clipPlayer,
	}
	if boss and boss.moments then
		startMoments(monster, boss.moments)
	end
	local emergeAt, emergeSeconds = tonumber(marker:GetAttribute("EmergeAt")), tonumber(marker:GetAttribute("Emerge"))
	if emergeAt and emergeSeconds and emergeSeconds > 0 then
		monster.emerge = { at = emergeAt, seconds = emergeSeconds }
		if not size and workspace:GetServerTimeNow() - emergeAt < emergeSeconds then
			spawnBurst(marker.Position, emergeSeconds) -- a room's pack, still rising
		end
	end
	if size then
		-- void wisps off a running summon (on while it runs, MonsterController's frame loop)
		local trail = Instance.new("ParticleEmitter")
		trail.Texture = "rbxasset://textures/particles/smoke_main.dds"
		trail.Color = ColorSequence.new(Color3.fromRGB(150, 70, 255), Color3.fromRGB(30, 10, 50))
		trail.LightEmission = 0.6
		trail.Size = NumberSequence.new(height * 0.35, height * 0.05)
		trail.Transparency = NumberSequence.new(0.3, 1)
		trail.Lifetime = NumberRange.new(0.5, 0.9)
		trail.Rate = 30
		trail.Speed = NumberRange.new(1, 3)
		trail.SpreadAngle = Vector2.new(40, 40)
		trail.Enabled = false
		trail.Parent = body.root
		monster.trail = trail
	end
	if boss then
		-- its life between moves starts once its intro has played (SpawnedAt: the server's clock)
		local spawnedAt = tonumber(marker:GetAttribute("SpawnedAt"))
		local introLeft = if spawnedAt then spawnedAt + Bosses.INTRO_SECONDS - workspace:GetServerTimeNow() else 0
		local now = os.clock()
		monster.idle = {
			x = 0,
			z = 0,
			walk = nil,
			nextAt = now + math.max(0, introLeft) + 1,
			busyUntil = 0,
			introEnd = now + math.max(0, introLeft),
			roar = if boss.moments then boss.moments.roar else nil,
			-- its own idle numbers over the bosses' (the Prism Hydra walks more)
			cfg = if boss.idle then setmetatable(table.clone(boss.idle), { __index = Bosses.IDLE }) else Bosses.IDLE,
			scale = height / 17,
		}
	elseif workspace:GetAttribute("PlaceKind") == "Dungeon" then
		-- a Dungeon room's monsters move round the arena between their hits too (owner 2026-11-12; Bosses.IDLE_PACK)
		local now = os.clock()
		monster.idle = { x = 0, z = 0, walk = nil, nextAt = now + 1, busyUntil = 0, introEnd = now, roar = nil, cfg = Bosses.IDLE_PACK, scale = 1 }
	else
		-- a wild monster steps round its spot between its attacks too, calmly (owner 2026-11-25: "monsters just stand
		-- there"; spec 2026-11-25-hit-feel-design 3, Config/HitFeel STEP)
		local now = os.clock()
		monster.wild = true
		monster.idle = { x = 0, z = 0, walk = nil, nextAt = now + 1, busyUntil = 0, introEnd = now, roar = nil, cfg = HitFeel.stepIdle(Bosses.IDLE_PACK, HitFeelConfig.STEP), scale = 1 }
	end
	if monster.aura and boss and boss.auroraFlame then
		monster.aura.flames = makeFlames(model, body.root)
	end
	if elite or boss then
		local light = Instance.new("PointLight")
		light.Color = if boss then BOSS_TAG_COLOR else ELITE_TAG_COLOR
		light.Brightness = 0.8
		light.Range = 8
		light.Parent = body.root
	end
	updateTag(monster)
	lightHeads(monster)
	-- A boss winding up an attack on a player (BattleService): a quick hit flashes it red; a big attack rears it back
	-- (its roar pose, unless it has its own special wind-up clip, which Util/FightFx plays) with an orange glow, for
	-- the warning's length; a thunderclap the same with a storm-blue glow
	-- A dangerous monster starting to chase you (WildService ChasingUserId; owner 2026-11-12: "they would be scared"): a
	-- red "!" pops over it and it growls
	table.insert(monster.connections, marker:GetAttributeChangedSignal("ChasingUserId"):Connect(function()
		if marker:GetAttribute("ChasingUserId") ~= game:GetService("Players").LocalPlayer.UserId or not body.root then
			return
		end
		local cue = Combat.DANGER.chaseCue
		local tall = if body.model then body.model:GetExtentsSize().Y else 6
		local board = Instance.new("BillboardGui")
		board.Name = "ChaseCue"
		board.AlwaysOnTop = true
		board.Size = UDim2.fromOffset(60, 60)
		board.StudsOffsetWorldSpace = Vector3.new(0, tall * 0.6 + 2, 0)
		board.Parent = body.root
		local mark = Instance.new("TextLabel")
		mark.BackgroundTransparency = 1
		mark.Size = UDim2.fromScale(1, 1)
		mark.Font = Enum.Font.FredokaOne
		mark.Text = "!"
		mark.TextScaled = true
		mark.TextColor3 = Color3.fromRGB(cue.color[1], cue.color[2], cue.color[3])
		mark.TextStrokeTransparency = 0
		mark.Parent = board
		local scale = Instance.new("UIScale")
		scale.Scale = 0.2
		scale.Parent = mark
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(cue.seconds, function()
			board:Destroy()
		end)
		local sound = SoundBank.make(cue.sound)
		sound.Volume = cue.volume
		sound.Parent = body.root
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 6)
	end))
	table.insert(monster.connections, marker:GetAttributeChangedSignal("WindUps"):Connect(function()
		local seconds = tonumber(marker:GetAttribute("WindUp")) or 0.5
		local kind = marker:GetAttribute("WindUpKind")
		local big = kind == "big" or kind == "clap"
		local tint = if kind == "clap" then SwordFx.WINDUP_CLAP_COLOR elseif big then SwordFx.WINDUP_BIG_COLOR else SwordFx.WINDUP_QUICK_COLOR
		if monster.idle then
			monster.idle.busyUntil = math.max(monster.idle.busyUntil, os.clock() + seconds + monster.idle.cfg.after)
		end
		HitFx.flash(body.model, Color3.fromRGB(tint[1], tint[2], tint[3]), seconds, SwordFx.WINDUP_FILL)
		if big and body.pet and not clips.specialWindup then
			PetAnimator.play(body.pet, "wildroar", os.clock())
		end
	end))
	table.insert(monster.connections, marker.AttributeChanged:Connect(function()
		if marker:GetAttribute("Fainted") == true and marker:GetAttribute("Boss") == nil then
			knockOut(monster) -- beaten: it flies off (its tag and this connection go with it)
			return
		end
		if marker:GetAttribute("Fainted") == true and not monster.beaten then
			-- a boss beaten in your own fight holds still and white a beat, then its death scene (Config/FinishingBlow)
			monster.beaten = true
			local moment = if finishingBlow then finishingBlow(marker, true) else nil
			if moment then
				local now = os.clock()
				monster.heldUntil = now + moment.hold
				HitFx.flash(monster.body.model, Color3.new(1, 1, 1), moment.hold + FinishingBlowConfig.BODY_FLASH.tail, FinishingBlowConfig.BODY_FLASH.fill)
				if #monster.heads > 0 or monster.aura then
					monster.fallenAt = now + moment.hold -- the Hydra's heads drop once the beat is over
				end
			end
		end
		updateTag(monster)
		if #monster.heads > 0 or monster.aura then
			if marker:GetAttribute("Fainted") == true and not monster.fallenAt then
				monster.fallenAt = os.clock()
			end
			lightHeads(monster)
		end
	end))
	monsters[marker] = monster
end

-- Downloads this place's boss and monster models in the background (MonsterLooks.preloadOrder: bosses first), a few at a
-- time, once the player's own cards have started: otherwise a boss's model was fetched only when its fight began, and
-- its intro showed an empty ring for several seconds
local function preloadModels()
	task.wait(Party.MONSTER_PRELOAD_WAIT)
	if not ReplicatedStorage:WaitForChild("MonsterModels", 30) then
		return
	end
	local place = if Place.isDungeon() then "Dungeon" elseif Place.isFrontier() then "Frontier" else "Wild"
	local batch: { Model } = {}
	for _, name in MonsterLooks.preloadOrder(Wild, Bosses, place) do
		local template = CreatureVisuals.getTemplate("MonsterModels", name, Wild.MAX_MODEL_PARTS)
		if template then
			table.insert(batch, template)
		end
		if #batch >= Party.PRELOAD_BATCH then
			CreatureVisuals.preloadTemplates(batch)
			batch = {}
		end
	end
	if #batch > 0 then
		CreatureVisuals.preloadTemplates(batch)
	end
end

-- A monster's model on this client (sword hits flash it), if it has one
function MonsterController.GetModel(marker: BasePart): Model?
	local monster = monsters[marker]
	return if monster then monster.body.model else nil
end

-- A beaten monster's knockout playing (Config/MonsterKO): `callback` runs as it poofs, with where (the winner's coins,
-- toast and XP sparks come then: BattleController). false: none playing (too far, or not knocked out)
function MonsterController.OnKnockoutPoof(marker: BasePart, callback: (at: Vector3) -> ()): boolean
	local handle = knockouts[marker]
	if not handle then
		return false
	end
	handle.onPoof(callback)
	return true
end

-- A monster's or boss's body for fight effects (Util/FightFx): where it is, how tall, its boss id or species and the
-- attack clips it has (name -> seconds)
function MonsterController.GetFightView(marker: BasePart): { root: BasePart, height: number, key: string, lengths: { [string]: number } }?
	local monster = monsters[marker]
	if not monster then
		return nil
	end
	return { root = monster.body.root, height = monster.height, key = monster.key, lengths = monster.lengths }
end

-- Plays one of its attack clips at `speed`, holding its last pose `hold` seconds (Util/ClipPlayer)
-- A boss turns to what it goes for (FightFx on its charge, warning, ring or hit): `target` says where that is now, nil
-- once it's gone (fainted, left: it keeps the turn it has). Its body turns where it stands; its spot stays the server's
function MonsterController.FaceToward(marker: BasePart, target: () -> Vector3?)
	local monster = monsters[marker]
	if monster then
		monster.faceAt = target
	end
end

function MonsterController.PlayClip(marker: BasePart, name: string, speed: number, hold: number)
	local monster = monsters[marker]
	local clip = if monster then monster.clips[name] else nil
	if monster and clip and monster.clipPlayer then
		ClipPlayer.play(monster.clipPlayer, clip, speed, nil, hold)
		if monster.idle then
			monster.idle.busyUntil = math.max(monster.idle.busyUntil, os.clock() + clip.length / math.max(speed, 0.05) + hold + monster.idle.cfg.after)
		end
		-- a wild monster lunges forward into its strike (spec 2026-11-25-hit-feel-design 3)
		if monster.wild and name == "strike" then
			monster.lunge = { at = os.clock(), length = clip.length / math.max(speed, 0.05) + hold }
		end
	end
end

-- A hit on a monster from `from` (the hitter's position); `big` your finisher or dash slash, a creature's finishing hit
-- or a super (spec 2026-11-25-hit-feel-design 1): a white flash, a jolt and lean away from the hitter, a pop and its
-- clip frozen a moment; a boss takes a share of the jolt and never pops. false: not a monster drawn here, or fainted
function MonsterController.React(marker: BasePart, from: Vector3, big: boolean): boolean
	local monster = monsters[marker]
	if not monster or marker:GetAttribute("Fainted") == true then
		return false
	end
	local at = monster.body.root.Position
	monster.react = HitFeel.reaction(os.clock(), at.X, at.Z, from.X, from.Z, big, marker:GetAttribute("Boss") ~= nil, HitFeelConfig.REACT)
	flashWhite(monster)
	return true
end

function MonsterController.Start()
	task.spawn(preloadModels)
	local folder = workspace:WaitForChild("Monsters")
	local function watch(child: Instance)
		if not child:IsA("BasePart") then
			return
		end
		add(child)
		if not monsters[child] then
			-- Attributes can arrive a moment after the part: try again when the species shows up
			local connection: RBXScriptConnection
			connection = child:GetAttributeChangedSignal("Species"):Connect(function()
				connection:Disconnect()
				add(child)
			end)
		end
	end
	folder.ChildAdded:Connect(watch)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			remove(child)
		end
	end)
	for _, child in folder:GetChildren() do
		watch(child)
	end

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local camera = workspace.CurrentCamera
		local origin = if camera then camera.CFrame.Position else Vector3.zero
		local extras = Extras.enabled()
		for _, monster in monsters do
			if monster.heldUntil and now < monster.heldUntil then
				continue -- the finishing blow's beat: everything about it holds (its tip-over starts after)
			end
			if monster.idle then
				stepIdle(monster, monster.idle, now)
			end
			if monster.wild then
				monster.body.offset = wildOffset(monster, now)
			end
			local emerge = monster.emerge
			if emerge then
				-- climbing out of its rift: up through the ground, growing (Util/SummonRules)
				local elapsed = workspace:GetServerTimeNow() - emerge.at
				local sink, scale = SummonRules.emerge(elapsed, emerge.seconds)
				monster.body.offset = CFrame.new(0, -monster.height * sink, 0)
				monster.body.grow = scale
				if elapsed >= emerge.seconds then
					monster.emerge = nil
					monster.body.offset = nil
				end
			elseif monster.trail and monster.body.grow == 1 then
				monster.body.grow = nil
			end
			CreatureVisuals.step(monster.body, dt, now, origin, Party.MOTION)
			stepReaction(monster, now)
			local trail = monster.trail
			if trail then
				local running = monster.body.speed > TRAIL_SPEED and monster.marker:GetAttribute("Fainted") ~= true and extras
				if trail.Enabled ~= running then
					trail.Enabled = running
				end
			end
			local clipPlayer = monster.clipPlayer
			-- a hit holds its own animation still a moment (its hit-stop, Config/HitFeel)
			local frozen = monster.react ~= nil and HitFeel.frozen(monster.react :: HitFeel.Reaction, now)
			if clipPlayer and clipPlayer.playing and not frozen and (monster.body.cframe.Position - origin).Magnitude <= Party.PET_ANIM.DISTANCE then
				ClipPlayer.step(clipPlayer, dt, monster.body.model:GetScale())
			end
			if monster.fallenAt then
				dropHeads(monster, now)
			end
			if monster.aura then
				stepAura(monster, now)
			end
			if #monster.lasting > 0 then
				local smoking = monster.enraged and extras
				if monster.lasting[1].Enabled ~= smoking then
					for _, emitter in monster.lasting do
						emitter.Enabled = smoking
					end
				end
			end
			if #monster.fx > 0 then
				local near = MonsterLooks.effectsOn((monster.marker.Position - origin).Magnitude, Wild.FX_RANGE, extras)
				if monster.fx[1].Enabled ~= near then
					for _, emitter in monster.fx do
						emitter.Enabled = near
					end
				end
			end
		end
	end)
end

return MonsterController
