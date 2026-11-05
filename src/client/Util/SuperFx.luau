--!strict
-- The super moves in the world, for everyone in the fight (spec 2026-11-05-super-moves-design, Config/SuperFx): each
-- look's charge (from the press to the impact, on the caster) and its impact and linger (where it lands, for as long
-- as the move lasts). Routed from Util/FightFx; the caster's own screen (camera, cut-in, flash) is Util/SuperCinematic.
-- A look not finished yet plays its kind's first-pass effect (ElementFx.special) with a bigger wind-up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("Config"):WaitForChild("AttackFx"))
local Combat = require(Shared:WaitForChild("Config"):WaitForChild("Combat"))
local SuperFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("SuperFx"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))
local SoundBank = require((script.Parent :: Instance):WaitForChild("SoundBank"))

local SuperFx = {}

-- The caster as Util/FightFx sees it
export type View = { root: BasePart, element: string, height: number, grade: string?, mine: boolean }
type Look = {
	charge: (view: View, grade: string, seconds: number, target: Vector3?) -> () -> (),
	impact: (view: View, grade: string, target: Vector3, targetBody: BasePart?, targetHeight: number) -> () -> (),
}

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function nothing() end

local UP = Vector3.new(0, 1, 0)
local WHITE = Color3.new(1, 1, 1)
local TEX = SuperFxConfig.TEXTURES

-- Everything one look made, cleared together (its stop): parts and emitters, per-frame updates, sounds
type Bag = { items: { Instance }, connections: { RBXScriptConnection }, done: boolean }

local function bag(): Bag
	return { items = {}, connections = {}, done = false }
end

local function clear(b: Bag)
	if b.done then
		return
	end
	b.done = true
	for _, connection in b.connections do
		connection:Disconnect()
	end
	for _, item in b.items do
		item:Destroy()
	end
end

local function folder(): Folder
	local existing = workspace:FindFirstChild("SuperFx")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "SuperFx"
	made.Parent = workspace
	return made
end

-- An effect part: anchored, untouchable, glowing unless told otherwise
local function part(b: Bag, size: Vector3, tint: Color3, at: CFrame, transparency: number?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = tint
	p.Size = size
	p.Shape = shape or Enum.PartType.Block
	p.CFrame = at
	p.Transparency = transparency or 0
	p.Parent = folder()
	table.insert(b.items, p)
	return p
end

-- An invisible anchor for beams, emitters, lights and sounds
local function anchor(b: Bag, at: CFrame): Part
	return part(b, Vector3.new(0.2, 0.2, 0.2), WHITE, at, 1)
end

local function attachment(parent: Instance, offset: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Position = offset
	a.Parent = parent
	return a
end

-- A textured beam between two attachments: light, facing the camera, its texture scrolling along it
local function beam(a0: Attachment, a1: Attachment, texture: string, tint: ColorSequence, width0: number, width1: number, o: any?): Beam
	local opts = o or {}
	local made = Instance.new("Beam")
	made.Attachment0 = a0
	made.Attachment1 = a1
	made.Texture = texture
	made.TextureMode = Enum.TextureMode.Wrap
	made.TextureLength = opts.length or 6
	made.TextureSpeed = opts.speed or 1
	made.Color = tint
	made.LightEmission = 1
	made.LightInfluence = 0
	made.Brightness = opts.brightness or 2
	made.Width0 = width0
	made.Width1 = width1
	made.FaceCamera = opts.faceCamera ~= false
	made.Segments = opts.segments or 10
	made.CurveSize0 = opts.curve0 or 0
	made.CurveSize1 = opts.curve1 or 0
	made.Transparency = opts.transparency or NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.8, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	made.Parent = a0.Parent
	return made
end

-- A look's sound on `parent` (Config/SuperFx SOUNDS; the fight volume, a little pitch spread), kept loaded
local function play(b: Bag, parent: Instance, id: string?, volume: number, looped: boolean?): Sound?
	if not id or id == "" then
		return nil
	end
	local s = SoundBank.make(id)
	s.Volume = AttackFx.VOLUME * volume
	s.PlaybackSpeed = 0.96 + math.random() * 0.08
	s.Looped = looped == true
	s.RollOffMaxDistance = 180
	s.Parent = parent
	s:Play()
	table.insert(b.items, s)
	return s
end

local function tween(item: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(item, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

-- Every frame until the look is cleared: `step(elapsed, dt)`
local function everyFrame(b: Bag, step: (elapsed: number, dt: number) -> ())
	local started = os.clock()
	table.insert(b.connections, RunService.RenderStepped:Connect(function(dt)
		step(os.clock() - started, dt)
	end))
end

-- The ground under a point (terrain or solid parts), or 3 studs under it
local function groundAt(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder() }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(at + UP * 4, Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else at - UP * 3
end

local function sequence(from: Color3, to: Color3): ColorSequence
	return ColorSequence.new(from, to)
end

-- A spinning funnel of flame beams round `base`: `count` beams from `bottom` studs out at the foot to `top` out at its
-- height, twisting as they rise; `set(height, bottom, top)` reshapes it, and it spins `turn` degrees a second
type Funnel = { holder: Part, set: (height: number, bottom: number, top: number) -> (), beams: { Beam } }

local function funnel(b: Bag, base: Vector3, count: number, tint: ColorSequence, width: number, turn: number): Funnel
	local holder = anchor(b, CFrame.new(base))
	local ends: { { Attachment } } = {}
	local beams: { Beam } = {}
	for index = 1, count do
		local a0 = attachment(holder, Vector3.zero)
		local a1 = attachment(holder, Vector3.zero)
		table.insert(ends, { a0, a1 })
		table.insert(beams, beam(a0, a1, TEX.firestrip, tint, width * 0.7, width * 1.4, { speed = 2.5, length = 5, curve0 = 2, curve1 = -2 }))
	end
	local shape = { height = 1, bottom = 1, top = 1 }
	local function set(height: number, bottom: number, top: number)
		shape.height, shape.bottom, shape.top = height, bottom, top
		for index, pair in ends do
			local angle = (index - 1) / count * 2 * math.pi
			local twist = angle + 1.4
			pair[1].Position = Vector3.new(math.cos(angle) * bottom, 0, math.sin(angle) * bottom)
			pair[2].Position = Vector3.new(math.cos(twist) * top, height, math.sin(twist) * top)
		end
	end
	set(1, 1, 1)
	everyFrame(b, function(_, dt)
		holder.CFrame = holder.CFrame * CFrame.Angles(0, math.rad(turn) * dt, 0)
	end)
	return { holder = holder, set = set, beams = beams }
end

-- A glowing crack racing along the ground from `from` to `to` over `seconds`: jagged neon segments appearing one after
-- another, `jag` studs either side of the straight line
local function crackLine(b: Bag, from: Vector3, to: Vector3, width: number, tint: Color3, seconds: number, jag: number)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude < 0.5 then
		return
	end
	local side = Vector3.new(-flat.Z, 0, flat.X).Unit
	local steps = math.clamp(math.floor(flat.Magnitude / 3), 4, 24)
	local points = {}
	for index = 0, steps do
		local wobble = if index > 0 and index < steps then (math.random() * 2 - 1) * jag else 0
		table.insert(points, groundAt(from:Lerp(to, index / steps) + side * wobble) + UP * 0.07)
	end
	for index = 1, steps do
		task.delay((index - 1) / steps * seconds, function()
			if b.done then
				return
			end
			local a, c = points[index], points[index + 1]
			part(b, Vector3.new(width, 0.12, (c - a).Magnitude + width * 0.6), tint, CFrame.lookAt((a + c) / 2, c), 0.05)
		end)
	end
end

-- A flat picture on the ground at `at` (TEXTURES), `size` studs across, fading in
local function groundDecal(b: Bag, at: Vector3, size: number, texture: string, tint: Color3, seconds: number): Decal
	local holder = part(b, Vector3.new(size, 0.05, size), WHITE, CFrame.new(at + UP * 0.08), 1)
	local decal = Instance.new("Decal")
	decal.Texture = texture
	decal.Face = Enum.NormalId.Top
	decal.Color3 = tint
	decal.Transparency = 1
	decal.Parent = holder
	tween(decal, seconds, { Transparency = 0 })
	return decal
end

-- `count` rocks falling over `seconds` onto a disc of `radius` round `center`, each with a trail of fire, bursting as it lands
local function rockRain(b: Bag, center: Vector3, radius: number, count: number, size: number, trail: Color3, seconds: number)
	for index = 1, count do
		task.delay(math.random() * seconds, function()
			if b.done then
				return
			end
			local angle, reach = math.random() * 2 * math.pi, math.sqrt(math.random()) * radius
			local land = groundAt(center + Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach))
			local rock = part(b, Vector3.one * size * (0.6 + math.random() * 0.7), Color3.fromRGB(58, 44, 38), CFrame.new(land + UP * 26), 0, Enum.PartType.Ball)
			rock.Material = Enum.Material.Slate
			local flames = ElementFx.emitter(rock, "flame", trail, { size = { size, 0.2 }, life = 0.35, speed = 0, fade = 0.4 })
			flames.Rate = 30
			local fall = 0.45 + math.random() * 0.25
			TweenService:Create(rock, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(land + UP * size * 0.3) }):Play()
			task.delay(fall, function()
				if b.done then
					return
				end
				flames.Rate = 0
				ElementFx.burst(land + UP * 0.5, trail, 0.6)
				tween(rock, 1.2, { Transparency = 1 })
			end)
		end)
	end
end

-- A ring of `count` flame emitters round `center` (on the ground), each rising
local function fireRing(b: Bag, center: Vector3, radius: number, count: number, tint: Color3, size: number): { ParticleEmitter }
	local holder = anchor(b, CFrame.new(center))
	local list = {}
	for index = 1, count do
		local angle = (index - 1) / count * 2 * math.pi
		local spot = attachment(holder, Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
		local flame = ElementFx.emitter(spot, "flame", tint, {
			size = { size, size * 0.3 },
			life = { 0.5, 0.9 },
			speed = { 4, 7 },
			spread = 12,
			rotation = { -20, 20 },
			fade = 0.5,
			brightness = 2,
		})
		flame.Rate = 14
		table.insert(list, flame)
	end
	return list
end

-- The super of a look's card (Config/Combat SIGNATURES): its kind, name and numbers
function SuperFx.abilityOf(lookId: string): any?
	local look = SuperFxConfig.LOOKS[lookId]
	return if look then Combat.SIGNATURES[look.card] else nil
end

-- The first-pass wind-up, bigger with grade: a glow, a ring under it and the move's name
local function placeholderCharge(lookId: string, view: View, grade: string, seconds: number): () -> ()
	local look = SuperFxConfig.LOOKS[lookId]
	local ability = SuperFx.abilityOf(lookId)
	local tint = color(look.color)
	local scale = look.grades[grade].scale
	local stop = ElementFx.chargeGlow(view.root, tint, seconds, 2 * scale)
	ElementFx.castRing(view.root.Position - Vector3.new(0, view.height * 0.45, 0), tint, math.max(2, view.height * 0.8) * scale, seconds)
	ElementFx.callout(view.root, view.height * 0.6, `{string.upper(if ability then ability.name else lookId)}!`, tint, seconds)
	ElementFx.sound(AttackFx.SOUNDS.charge, view.root.Position)
	return stop
end

-- The first-pass impact: its kind's effect (AttackFx.SPECIALS, ElementFx.special) and the shared chime and boom
local function placeholderImpact(lookId: string, view: View, target: Vector3): () -> ()
	local look = SuperFxConfig.LOOKS[lookId]
	local ability = SuperFx.abilityOf(lookId)
	local spec = if ability then AttackFx.SPECIALS[ability.kind] else nil
	if not spec then
		return nothing
	end
	local caster = view.root.Position + Vector3.new(0, view.height * 0.4, 0)
	local hitAt = if ability and (ability.kind == "TidalShield" or ability.kind == "Eclipse") then caster else target
	ElementFx.sound(AttackFx.SPECIAL_SOUND, caster)
	ElementFx.sound(AttackFx.SOUNDS.big[view.element] or AttackFx.SOUNDS.boom, hitAt, 0.6)
	ElementFx.special(spec.style, caster, hitAt, color(look.color), spec.seconds or 0)
	return nothing
end

-- Inferno (Infernox, Epic, Ember; spec "Inferno"): it roars to the sky as a fire tornado spins up round it, breathes a
-- torrent and the tornado leaps onto the boss and engulfs it, then a ring of fire, flames licking the boss and rising
-- embers for the burn's 6 s. By grade: a taller tornado, more embers, hotter colours; S: the ground cracks into lava.
local INFERNO = SuperFxConfig.LOOKS.Inferno
local INFERNO_SOUNDS = SuperFxConfig.SOUNDS.Inferno

local function infernoColors(grade: string): (Color3, ColorSequence)
	local base = color(INFERNO.color)
	local hot = base:Lerp(Color3.fromRGB(255, 236, 140), ({ C = 0.25, B = 0.4, A = 0.55, S = 0.75 })[grade] or 0.25)
	return base, sequence(hot, base)
end

local function infernoCharge(view: View, grade: string, seconds: number, _target: Vector3?): () -> ()
	local g = INFERNO.grades[grade]
	local b = bag()
	local base, flames = infernoColors(grade)
	local feet = view.root.Position
	local source = anchor(b, CFrame.new(feet + UP * view.height * 0.6))
	play(b, source, INFERNO_SOUNDS.call, 1.1)
	task.delay(seconds * 0.35, function()
		if not b.done then
			play(b, source, INFERNO_SOUNDS.charge, 0.9)
		end
	end)
	local spin = funnel(b, feet, math.floor(3 + 2 * g.scale), flames, 1.5 * g.scale, 260)
	local reach = math.max(2.5, view.height * 0.45)
	everyFrame(b, function(elapsed)
		local grow = math.clamp(elapsed / math.max(0.1, seconds), 0, 1)
		spin.set(view.height * (0.6 + 0.8 * grow), reach * 0.5, reach * (0.9 + 0.4 * grow))
	end)
	local embers = ElementFx.emitter(source, "spark", base, {
		size = { 0.5, 0.1 },
		life = { 0.6, 1.2 },
		speed = { 5, 10 },
		spread = 60,
		accel = UP * 6,
		brightness = 2.4,
	})
	embers.Rate = g.embers
	local stopGlow = ElementFx.chargeGlow(view.root, base, seconds, 1.6 * g.scale)
	return function()
		stopGlow()
		clear(b)
	end
end

local function infernoImpact(view: View, grade: string, target: Vector3, targetBody: BasePart?, targetHeight: number): () -> ()
	local g = INFERNO.grades[grade]
	local b = bag()
	local base, flames = infernoColors(grade)
	local burn = (SuperFx.abilityOf("Inferno") or { seconds = 6 }).seconds
	local feet = view.root.Position
	local mouth = feet + UP * view.height * 0.7 + view.root.CFrame.LookVector * view.height * 0.3
	local ground = groundAt(target)
	local fit = math.clamp(targetHeight * 0.45, 3, 12)
	-- The torrent: a wide stream of flame from its mouth to the boss
	local stream = anchor(b, CFrame.new(mouth))
	local streamEnd = anchor(b, CFrame.new(target))
	local torrent = beam(attachment(stream, Vector3.zero), attachment(streamEnd, Vector3.zero), TEX.firestrip, flames, 2.2 * g.scale, 4.5 * g.scale, { speed = 9, length = 7 })
	task.delay(0.55, function()
		if not b.done then
			tween(torrent, 0.3, { Width0 = 0, Width1 = 0 })
		end
	end)
	play(b, streamEnd, INFERNO_SOUNDS.impact, 1.2)
	if grade == "A" or grade == "S" then
		play(b, streamEnd, INFERNO_SOUNDS.layer, 1)
	end
	-- The tornado leaps from it onto the boss and engulfs it, then dies down
	local spin = funnel(b, feet, math.floor(4 + 2 * g.scale), flames, 2 * g.scale, 320)
	local height = g.tornadoHeight * math.max(1, targetHeight / 10)
	everyFrame(b, function(elapsed)
		local leap = math.clamp(elapsed / 0.3, 0, 1)
		local foot = feet:Lerp(ground, leap)
		spin.holder.CFrame = CFrame.new(foot) * spin.holder.CFrame.Rotation
		local fade = math.clamp((elapsed - 1.4) / 0.6, 0, 1)
		spin.set(height * (0.5 + 0.5 * leap) * (1 - fade), fit * 0.6 * (1 - fade * 0.5), fit * 1.3)
		if fade >= 1 then
			for _, each in spin.beams do
				each.Enabled = false
			end
		end
	end)
	ElementFx.burst(target, base, 2 * g.scale)
	ElementFx.ring(ground + UP * 0.2, base, fit * 2.2, 0.5)
	-- The burn: a ring of fire on the ground, flames licking the boss, embers rising, a crackle
	local ring = fireRing(b, ground + UP * 0.3, g.fireRing * fit, math.floor(10 + 6 * g.scale), base, (1.2 + fit * 0.25) * g.scale)
	local body = anchor(b, CFrame.new(target))
	body.Size = Vector3.new(fit, math.max(2, targetHeight * 0.8), fit)
	local licks = ElementFx.emitter(body, "flame", base, {
		size = { 2 * g.scale, 0.4 },
		life = { 0.4, 0.8 },
		speed = { 3, 6 },
		spread = 20,
		fade = 0.5,
		brightness = 2,
	})
	licks.Shape = Enum.ParticleEmitterShape.Box
	licks.Rate = 18 * g.scale
	local embers = ElementFx.emitter(anchor(b, CFrame.new(ground)), "spark", base, {
		size = { 0.45, 0.1 },
		life = { 1, 1.8 },
		speed = { 4, 9 },
		spread = 45,
		accel = UP * 5,
		brightness = 2.4,
	})
	embers.Rate = g.embers
	local crackle = play(b, body, INFERNO_SOUNDS.linger, 0.7, true)
	local light = Instance.new("PointLight")
	light.Color = base
	light.Range = fit * 3
	light.Brightness = 3
	light.Parent = body
	-- S: the ground cracks into glowing lava under the boss
	if g.extra then
		local crackPart = part(b, Vector3.new(fit * 3.2, 0.05, fit * 3.2), WHITE, CFrame.new(ground + UP * 0.08), 1)
		local decal = Instance.new("Decal")
		decal.Texture = TEX.crack
		decal.Face = Enum.NormalId.Top
		decal.Color3 = Color3.fromRGB(255, 120, 30)
		decal.Transparency = 1
		decal.Parent = crackPart
		tween(decal, 0.4, { Transparency = 0 })
		local glow = ElementFx.emitter(anchor(b, CFrame.new(ground)), "glow", base, { size = { fit * 2, fit * 2.4 }, life = 0.8, fade = 0.3, brightness = 1.5 })
		glow.Rate = 2
	end
	-- After the burn: the flames die down and everything goes
	task.delay(burn, function()
		if b.done then
			return
		end
		for _, flame in ring do
			flame.Rate = 0
		end
		licks.Rate = 0
		embers.Rate = 0
		tween(light, 0.6, { Brightness = 0 })
		if crackle then
			tween(crackle, 0.6, { Volume = 0 })
		end
		task.delay(1, function()
			clear(b)
		end)
	end)
	return function()
		clear(b)
	end
end

-- Magma Slam (Cinder Titan, Epic, Ember, Frontier; spec "Magma Slam"): lava glows through its cracks and the ground
-- splits under it as it winds up, then it crashes down (its own lava-slam pose): glowing cracks race to the boss, lava
-- geysers erupt under it, rocks rain down and a cooling crust holds its feet for the stun. By grade: longer cracks,
-- more geysers and rocks; S: a ring of lava bursts round the landing.
local MAGMA = SuperFxConfig.LOOKS.MagmaSlam
local MAGMA_SOUNDS = SuperFxConfig.SOUNDS.MagmaSlam

local function magmaCharge(view: View, grade: string, seconds: number, _target: Vector3?): () -> ()
	local g = MAGMA.grades[grade]
	local b = bag()
	local lava = color(MAGMA.color)
	local feet = view.root.Position
	local source = anchor(b, CFrame.new(feet + UP * view.height * 0.5))
	play(b, source, MAGMA_SOUNDS.call, 1)
	task.delay(seconds * 0.5, function()
		if not b.done then
			play(b, source, MAGMA_SOUNDS.charge, 1)
		end
	end)
	local glow = Instance.new("PointLight")
	glow.Color = lava
	glow.Range = view.height * 2.5
	glow.Brightness = 0
	glow.Parent = source
	tween(glow, seconds, { Brightness = 4 })
	groundDecal(b, groundAt(feet), view.height * 1.6 * g.scale, TEX.crack, lava, seconds)
	local embers = ElementFx.emitter(source, "spark", lava, { size = { 0.5, 0.1 }, life = { 0.5, 1 }, speed = { 4, 8 }, spread = 70, accel = UP * 4 })
	embers.Shape = Enum.ParticleEmitterShape.Sphere
	embers.Rate = g.particles
	local stopGlow = ElementFx.chargeGlow(view.root, lava, seconds, 1.5 * g.scale)
	return function()
		stopGlow()
		clear(b)
	end
end

local function magmaImpact(view: View, grade: string, target: Vector3, _targetBody: BasePart?, targetHeight: number): () -> ()
	local g = MAGMA.grades[grade]
	local b = bag()
	local lava = color(MAGMA.color)
	local stun = (SuperFx.abilityOf("MagmaSlam") or { stun = 2 }).stun
	local landing = groundAt(view.root.Position)
	local ground = groundAt(target)
	local fit = math.clamp(targetHeight * 0.45, 3, 12)
	local boom = anchor(b, CFrame.new(landing + UP * 2))
	play(b, boom, MAGMA_SOUNDS.impact, 1.2)
	if grade == "A" or grade == "S" then
		play(b, boom, MAGMA_SOUNDS.layer, 1)
	end
	-- The slam: a shockwave and dust where it lands, then glowing cracks racing out to the boss
	ElementFx.ring(landing + UP * 0.2, lava, view.height * 1.4 * g.scale, 0.45)
	ElementFx.burst(landing + UP, Color3.fromRGB(120, 90, 70), 1.4 * g.scale)
	local reach = (ground - landing).Magnitude
	for index = 1, g.cracks do
		local spread = (index - (g.cracks + 1) / 2) * 0.22
		local flat = Vector3.new(ground.X - landing.X, 0, ground.Z - landing.Z)
		local aim = if flat.Magnitude > 0.5 then CFrame.lookAt(landing, landing + flat) * CFrame.Angles(0, spread, 0) else CFrame.new(landing)
		local length = math.max(reach + fit, g.crackLength) * (0.85 + math.random() * 0.3)
		crackLine(b, landing, landing + aim.LookVector * length, 0.35 + 0.15 * g.scale, lava, 0.35, 1.2)
	end
	-- Under the boss: lava geysers once the cracks reach it
	task.delay(0.35, function()
		if b.done then
			return
		end
		ElementFx.eruption(ground, lava, fit * 1.3, g.geysers * 2)
		for index = 1, g.geysers do
			local angle = index / g.geysers * 2 * math.pi
			local spot = ground + Vector3.new(math.cos(angle), 0, math.sin(angle)) * fit * 0.7 * math.random()
			ElementFx.pillar(spot, lava, (8 + targetHeight) * (0.8 + 0.3 * g.scale), 0.9, "flame")
		end
		groundDecal(b, ground, fit * 3, TEX.crack, lava, 0.25)
	end)
	-- The linger: rocks raining down and a cooling crust round its feet for the stun
	rockRain(b, ground, fit * 1.6, g.rocks, 0.9 + 0.3 * g.scale, lava, 1.6)
	local rumble = play(b, anchor(b, CFrame.new(ground + UP * 2)), MAGMA_SOUNDS.linger, 0.8)
	local crust = part(b, Vector3.new(1.4, fit * 1.9, fit * 1.9), Color3.fromRGB(52, 40, 36), CFrame.new(ground + UP * 0.6) * CFrame.Angles(0, 0, math.rad(90)), 0, Enum.PartType.Cylinder)
	crust.Material = Enum.Material.Basalt
	local seam = part(b, Vector3.new(0.2, fit * 2, fit * 2), lava, CFrame.new(ground + UP * 1.35) * CFrame.Angles(0, 0, math.rad(90)), 0.35, Enum.PartType.Cylinder)
	task.delay(stun, function()
		if b.done then
			return
		end
		tween(crust, 0.5, { Transparency = 1 })
		tween(seam, 0.5, { Transparency = 1 })
		ElementFx.burst(ground + UP, Color3.fromRGB(90, 70, 60), 1)
	end)
	-- S: a ring of lava bursts round the landing
	if g.extra then
		ElementFx.eruption(landing, lava, view.height * 1.3, 10)
		local ring = fireRing(b, landing + UP * 0.3, view.height * 1.1, 14, lava, 1.8)
		task.delay(1.4, function()
			for _, flame in ring do
				flame.Rate = 0
			end
		end)
	end
	task.delay(math.max(stun, 2.2) + 1, function()
		if rumble then
			tween(rumble, 0.4, { Volume = 0 })
		end
		task.delay(0.5, function()
			clear(b)
		end)
	end)
	return function()
		clear(b)
	end
end

-- The finished looks (spec "The ten moves"), by look id; the rest play the first pass
local LOOKS: { [string]: Look } = {
	Inferno = { charge = infernoCharge, impact = infernoImpact },
	MagmaSlam = { charge = magmaCharge, impact = magmaImpact },
}

-- Everything from the press to the impact on the caster; returns a stop
function SuperFx.charge(lookId: string, view: View, grade: string, seconds: number, target: Vector3?): () -> ()
	local own = LOOKS[lookId]
	if own then
		return own.charge(view, grade, seconds, target)
	end
	return placeholderCharge(lookId, view, grade, seconds)
end

-- The impact and what lingers on the field for the move's seconds; returns a stop
function SuperFx.impact(lookId: string, view: View, grade: string, target: Vector3, targetBody: BasePart?, targetHeight: number): () -> ()
	local own = LOOKS[lookId]
	if own then
		return own.impact(view, grade, target, targetBody, targetHeight)
	end
	return placeholderImpact(lookId, view, target)
end

return SuperFx
