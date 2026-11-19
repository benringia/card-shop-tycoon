--!strict
-- A creature appearing, leaving and fainting (timings in Party.SUMMON_FX, curves in Util/SummonMotion). Summon (owner
-- 2026-11-20: "a better/immersive summon and unsummon effects"; your card comes alive): its card, painting and all,
-- flies from its owner to the spot, a circle spins up under it while light gathers, the card stretches into a pillar
-- of light and the creature pops out with rings and sparkles, bigger the rarer the card (a Legendary pulls a beam from
-- the sky). Unsummon: it turns to light and shrinks, its card forms there and flies back into its owner. Faint: a white flash, it tips
-- over (CreatureVisuals), dizzy stars circle its head, then it fades in a puff; it comes back (revive) when it's no
-- longer fainted. CreatureController calls these on the marker's SummonedAt stamp and its Unsummon / Fainted flags.
-- A summon dings softly and an unsummon whooshes where the creature is (Party.SUMMON_SOUNDS).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Party = require(Shared:WaitForChild("Config"):WaitForChild("Party"))
local CardArtConfig = require(Shared:WaitForChild("Config"):WaitForChild("CardArt"))
local CardDesign = require(Shared:WaitForChild("Config"):WaitForChild("CardDesign"))
local CardArt = require(Shared:WaitForChild("Util"):WaitForChild("CardArt"))
local SummonMotion = require(Shared:WaitForChild("Util"):WaitForChild("SummonMotion"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))
local ScreenFx = require((script.Parent :: Instance):WaitForChild("ScreenFx"))
local SoundBank = require((script.Parent :: Instance):WaitForChild("SoundBank"))

local SummonFx = {}

type Body = { model: Model, root: BasePart, cframe: CFrame, grow: number?, faintedAt: number? }
-- Whose card it is: the owner's character (the card flies from and back to it), the card's name (its painting) and
-- rarity (how big), and whether it's the local player's (the camera shake)
export type Info = { owner: Model?, cardName: string?, rarity: string?, mine: boolean? }

local CFG = Party.SUMMON_FX
local SOUNDS = Party.SUMMON_SOUNDS
local WHITE = Color3.new(1, 1, 1)
local DUST = Color3.fromRGB(200, 196, 190)
local STARS = { "⭐", "💫", "⭐" }
local GOLD = Color3.fromRGB(255, 214, 110)
local TURN = math.pi * 2

-- The latest faint or revive on each model: an older one's leftover animation stops (a revive mid-fade)
local tokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function bump(model: Model): number
	tokens[model] = (tokens[model] or 0) + 1
	return tokens[model]
end

-- Runs `each(t)` every frame for `seconds` (t from 0), then `done`
local function animate(seconds: number, each: (number) -> (), done: (() -> ())?)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		each(math.min(t, seconds))
		if t >= seconds then
			connection:Disconnect()
			if done then
				done()
			end
		end
	end)
end

-- Every part of the model drawn at this transparency share (client-side only)
local function fade(model: Model, share: number)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = share
		end
	end
end

local function flash(model: Model, color: Color3, strength: number, seconds: number)
	local glow = Instance.new("Highlight")
	glow.FillColor = color
	glow.FillTransparency = 1 - strength
	glow.OutlineTransparency = 1
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = model
	TweenService:Create(glow, TweenInfo.new(seconds), { FillTransparency = 1 }):Play()
	Debris:AddItem(glow, seconds + 0.05)
end

-- A summon or unsummon sound where the creature is: quiet and always at its set pitch (no random wobble, which made the
-- first chime sound busy)
local function play(spec: { id: string, volume: number, pitch: number }, at: Vector3)
	local anchor = Instance.new("Attachment")
	anchor.Position = at -- Terrain sits at the origin, so this is the world position
	anchor.Parent = workspace.Terrain
	local sound = SoundBank.make(spec.id)
	sound.Volume = spec.volume
	sound.PlaybackSpeed = spec.pitch
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = SOUNDS.range
	sound.Parent = anchor
	sound:Play()
	Debris:AddItem(anchor, 4)
end

type Sound = { id: string, volume: number, pitch: number }

-- The summon or unsummon sound: the configured one, or (Studio) the option picked with /summonsound or /unsummonsound
-- (DevService sets the player's SummonSoundPick / UnsummonSoundPick attributes, and a volume beside them)
local function chosen(kind: string): Sound
	local player = Players.LocalPlayer
	local attribute = if kind == "summon" then "SummonSoundPick" else "UnsummonSoundPick"
	local pick = if player then player:GetAttribute(attribute) else nil
	local option = if typeof(pick) == "number" then SOUNDS.options[kind][pick] else nil
	if not option then
		return SOUNDS[kind]
	end
	local volume = player:GetAttribute(attribute .. "Volume")
	return { id = option.id, volume = if typeof(volume) == "number" then volume else option.volume, pitch = option.pitch }
end

local function ground(body: Body): Vector3
	return body.cframe.Position
end

-- The card ----------------------------------------------------------------------------------------------------------

-- An invisible anchor for emitters at `at`, gone after `life`
local function anchorAt(at: Vector3, life: number): Part
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(at)
	anchor.Parent = ElementFx.folder()
	Debris:AddItem(anchor, life)
	return anchor
end

-- One face of the flying card: `image` in a frame of the card's colour
local function cardFace(card: Part, normal: Enum.NormalId, image: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = normal
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = CFG.card.pixels
	gui.LightInfluence = 0
	gui.Parent = card
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.07, 0)
	corner.Parent = frame
	local picture = Instance.new("ImageLabel")
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	picture.Size = UDim2.fromScale(0.9, 0.93)
	picture.BackgroundTransparency = 1
	picture.ScaleType = Enum.ScaleType.Crop
	picture.Image = image
	picture.Parent = frame
	local inner = Instance.new("UICorner")
	inner.CornerRadius = UDim.new(0.06, 0)
	inner.Parent = picture
end

-- The creature's card as a thing in the world: its painting on the front, the card back behind, glowing in its
-- element's colour with sparks trailing off it
local function makeCard(cardName: string?, color: Color3, at: CFrame): Part
	local look = CFG.card
	local card = Instance.new("Part")
	card.Name = "SummonCard"
	card.Anchored = true
	card.CanCollide = false
	card.CanQuery = false
	card.CanTouch = false
	card.CastShadow = false
	card.Material = Enum.Material.SmoothPlastic
	card.Color = color:Lerp(WHITE, 0.5)
	card.Size = Vector3.new(look.width, look.height, look.thick)
	card.CFrame = at
	local art = if cardName then CardArt.pick(cardName, look.height * look.pixels, CardArtConfig) else nil
	cardFace(card, Enum.NormalId.Front, art or CardDesign.BACK.IMAGE, color)
	cardFace(card, Enum.NormalId.Back, CardDesign.BACK.IMAGE, color)
	local glow = ElementFx.emitter(card, "glow", color, { size = { 2.6, 1.9 }, life = 0.12, locked = true, rotation = 0, fade = 0.65 }) -- a halo the painting reads through
	glow.Rate = 60
	local trail = ElementFx.emitter(card, "spark", color:Lerp(WHITE, 0.4), { size = { 0.5, 0.1 }, life = { 0.25, 0.5 }, speed = { 1, 4 }, spread = 180, rotation = 0, orientation = Enum.ParticleOrientation.VelocityParallel, brightness = 2.2 })
	trail.Rate = 45 * ElementFx.detailShare()
	card.Parent = ElementFx.folder()
	Debris:AddItem(card, 4)
	return card
end

-- The card flies from `from` to `target()` over `seconds` in an arc, spinning `spins` times and ending with its front
-- toward `face()`; then `onArrive`
local function flyCard(card: Part, from: Vector3, target: () -> Vector3, face: () -> Vector3, seconds: number, arc: number, spins: number, onArrive: (Vector3) -> ())
	animate(seconds, function(t)
		if not card.Parent then
			return
		end
		local u = t / seconds
		local eased = 1 - (1 - u) ^ 2
		local goal = target()
		local at = from:Lerp(goal, eased) + Vector3.new(0, SummonMotion.arcLift(u, arc), 0)
		local toward = face()
		local flat = Vector3.new(toward.X - at.X, 0, toward.Z - at.Z)
		local facing = if flat.Magnitude > 0.05 then CFrame.lookAt(at, at + flat) else CFrame.new(at)
		card.CFrame = facing * CFrame.Angles(0, (1 - eased) * spins * TURN, math.rad(14) * (1 - eased))
	end, function()
		onArrive(target())
	end)
end

-- Where a card leaves from and comes back to: its owner's chest
local function chest(owner: Model?): BasePart?
	local root = if owner then owner:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Summoned: its card flies from its owner to the spot and stands over a spinning circle; the card stretches into a
-- pillar of light and the creature pops up out of it
function SummonFx.summon(body: Body, color: Color3, info: Info?)
	local at = ground(body)
	local look = CFG.card
	local tier = SummonMotion.tier(CFG, if info then info.rarity else nil)
	local beats = SummonMotion.beats(CFG)
	local size = tier.scale
	local spot = at + Vector3.new(0, look.hover, 0)
	local from = chest(if info then info.owner else nil)
	local start = if from then from.Position + Vector3.new(0, look.chest, 0) else spot + Vector3.new(0, look.drop, 0)

	body.grow = SummonMotion.summonScale(0, CFG)
	animate(beats.done, function(t)
		body.grow = SummonMotion.summonScale(t, CFG)
	end, function()
		body.grow = nil
	end)

	play(SOUNDS.throw, start)
	ElementFx.castRing(at, color, CFG.circle * size, beats.burst)
	local card = makeCard(if info then info.cardName else nil, color, CFrame.new(start))
	flyCard(card, start, function()
		return spot
	end, function()
		return if from then from.Position else start
	end, look.fly, look.arc, look.spins, function()
		-- landed: light gathers into it while the circle spins, and it stretches into a line of light
		ElementFx.burst(spot, WHITE, 0.45 * size)
		ElementFx.gather(spot, color, CFG.windup, 2.2 * size)
		for _, child in card:GetChildren() do
			if child:IsA("SurfaceGui") then
				child:Destroy()
			end
		end
		card.Material = Enum.Material.Neon
		card.Color = color:Lerp(WHITE, 0.8)
		local up = card.CFrame + Vector3.new(0, tier.pillar * 0.25, 0)
		TweenService:Create(card, TweenInfo.new(CFG.windup, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = Vector3.new(0.12, look.height + tier.pillar * 0.5, 0.12),
			CFrame = up,
			Transparency = 0.6,
		}):Play()
	end)

	task.delay(beats.burst, function()
		card:Destroy()
		if not body.model.Parent then
			return
		end
		play(chosen("summon"), at)
		ElementFx.pillar(at, color:Lerp(WHITE, 0.35), tier.pillar, CFG.pop + 0.25, "glow")
		for ring = 1, tier.rings do
			task.delay((ring - 1) * 0.09, function()
				ElementFx.ring(at + Vector3.new(0, 0.2, 0), if ring % 2 == 0 then color:Lerp(WHITE, 0.5) else color, (2.6 + ring * 1.3) * size, CFG.pop + 0.15)
			end)
		end
		ElementFx.burst(at + Vector3.new(0, 1.5, 0), color, 0.9 * size)
		flash(body.model, color:Lerp(WHITE, 0.6), 0.85, CFG.pop + 0.2) -- it arrives as light, then its own colours
		-- sparkles drifting up where it stands
		local anchor = anchorAt(at + Vector3.new(0, 1, 0), 2)
		local motes = ElementFx.emitter(anchor, "flare", if tier.beam then GOLD else color:Lerp(WHITE, 0.5), { size = { 0.55, 0.1 }, life = { 0.6, 1.1 }, speed = { 2, 5 }, spread = 60, spin = { -180, 180 }, accel = Vector3.new(0, 3, 0), brightness = 2.2 })
		motes:Emit(math.max(4, math.round(14 * tier.sparks * ElementFx.detailShare())))
		if tier.beam then
			-- a Legendary: a second, taller beam in gold and a wider ring
			ElementFx.pillar(at, GOLD, tier.pillar * 1.5, CFG.pop + 0.35, "glow")
			ElementFx.ring(at + Vector3.new(0, 0.2, 0), GOLD, 9 * size, CFG.pop + 0.3)
		end
		if tier.shake > 0 and info and info.mine then
			ScreenFx.shakeAt(tier.shake, at)
		end
	end)
end

-- Unsummoned: it turns to light and shrinks; its card forms where it stood and flies back into `owner` (its owner's
-- character, if there)
function SummonFx.unsummon(body: Body, color: Color3, owner: Model?, info: Info?)
	local from = ground(body) + Vector3.new(0, CFG.card.hover, 0) -- its middle: where its card forms
	local leave = CFG.leave
	local beats = SummonMotion.leaveBeats(CFG)
	play(chosen("unsummon"), from)
	-- turning to light: the glow builds instead of fading
	local glow = Instance.new("Highlight")
	glow.FillColor = color:Lerp(WHITE, 0.7)
	glow.FillTransparency = 1
	glow.OutlineTransparency = 1
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = body.model
	TweenService:Create(glow, TweenInfo.new(leave.glow), { FillTransparency = 0.05 }):Play()
	Debris:AddItem(glow, CFG.unsummon + 0.1)
	ElementFx.castRing(ground(body), color, CFG.circle * 0.8, CFG.unsummon * 0.8)
	ElementFx.gather(from, color, beats.card, 2.4)
	animate(CFG.unsummon, function(t)
		body.grow = SummonMotion.shrinkScale(t, CFG.unsummon)
	end)
	task.delay(beats.card, function()
		ElementFx.burst(from, color:Lerp(WHITE, 0.5), 0.6)
		local target = chest(owner)
		local card = makeCard(if info then info.cardName else nil, color, CFrame.new(from))
		local full = card.Size
		card.Size = full * 0.2
		TweenService:Create(card, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = full }):Play()
		flyCard(card, from, function()
			return if target then target.Position + Vector3.new(0, CFG.card.chest, 0) else from + Vector3.new(0, CFG.card.drop, 0)
		end, function()
			return from
		end, leave.fly, leave.arc, leave.spins, function(arrived)
			-- back in its owner: the card folds away into them
			ElementFx.burst(arrived, color, 0.5)
			if target then
				ElementFx.ring(target.Position - Vector3.new(0, 2.6, 0), color, 2.2, 0.35)
			end
			local fold = TweenService:Create(card, TweenInfo.new(0.1), { Size = full * 0.05, Transparency = 1 })
			fold.Completed:Once(function()
				card:Destroy()
			end)
			fold:Play()
		end)
	end)
end

-- Fainted: a flash, dizzy stars round its head while it tips over, then a puff as it fades out. `quiet`: it was already
-- fainted when it came into view (no stars, just gone)
function SummonFx.faint(body: Body, quiet: boolean?)
	local token = bump(body.model)
	if quiet then
		fade(body.model, 1)
		return
	end
	flash(body.model, WHITE, 0.8, 0.3)
	local _, size = body.model:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "DizzyStars"
	gui.Size = UDim2.fromOffset(90, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.6, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = body.root
	gui.Parent = body.root
	local labels: { TextLabel } = {}
	for _, star in STARS do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromOffset(24, 24)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Text = star
		label.TextSize = 20
		label.Parent = gui
		table.insert(labels, label)
	end
	animate(CFG.stars, function(t)
		if tokens[body.model] ~= token then
			return
		end
		for index, label in labels do
			local angle = t * 6 + index * math.pi * 2 / #labels
			label.Position = UDim2.new(0.5, math.cos(angle) * 30, 0.5, math.sin(angle) * 9)
		end
	end, function()
		gui:Destroy()
		if tokens[body.model] ~= token then
			return -- revived meanwhile
		end
		local puff = ElementFx.emitter(body.root, "smoke", DUST, { size = { 2, 4 }, life = 0.7, speed = { 2, 4 }, spread = 180, start = 0.2, light = 0 })
		puff:Emit(14)
		Debris:AddItem(puff, 1)
		animate(CFG.fade, function(t)
			if tokens[body.model] == token then
				fade(body.model, t / CFG.fade)
			end
		end)
	end)
end

-- No longer fainted (the fight is over): back in view with a little pop
function SummonFx.revive(body: Body)
	bump(body.model)
	fade(body.model, 0)
	local stars = body.root:FindFirstChild("DizzyStars")
	if stars then
		stars:Destroy()
	end
	animate(CFG.pop, function(t)
		body.grow = SummonMotion.popScale(t, CFG.pop)
	end, function()
		body.grow = nil
	end)
end

-- Studio: a sound picked with /summonsound or /unsummonsound plays once at your character so you can hear it
-- (DevService stamps SoundPreview with "summon" or "unsummon" and the time)
do
	local player = Players.LocalPlayer
	if player then
		player:GetAttributeChangedSignal("SoundPreview"):Connect(function()
			local stamp = player:GetAttribute("SoundPreview")
			local kind = if typeof(stamp) == "string" then string.match(stamp, "^(%a+)|") else nil
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if (kind == "summon" or kind == "unsummon") and root and root:IsA("BasePart") then
				play(chosen(kind), root.Position)
			end
		end)
	end
end

return SummonFx
