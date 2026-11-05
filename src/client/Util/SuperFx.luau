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
-- side: the caster's side ("a" | "b"), for the shields' domes
type Look = {
	charge: (view: View, grade: string, seconds: number, target: Vector3?) -> () -> (),
	impact: (view: View, grade: string, target: Vector3, targetBody: BasePart?, targetHeight: number, side: string) -> () -> (),
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

local function funnel(b: Bag, base: Vector3, count: number, tint: ColorSequence, width: number, turn: number, texture: string?): Funnel
	local holder = anchor(b, CFrame.new(base))
	local ends: { { Attachment } } = {}
	local beams: { Beam } = {}
	for index = 1, count do
		local a0 = attachment(holder, Vector3.zero)
		local a1 = attachment(holder, Vector3.zero)
		table.insert(ends, { a0, a1 })
		table.insert(beams, beam(a0, a1, texture or TEX.firestrip, tint, width * 0.7, width * 1.4, { speed = 2.5, length = 5, curve0 = 2, curve1 = -2 }))
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

-- The shields' domes (Tidal Shield, Tidal Blessing): one per side, rippling where a hit it soaks lands and bursting in
-- a splash when the side's shield runs out (the sim's "shieldGone"), a new cast or the fight ends
type Dome = { center: Vector3, radius: number, tint: Color3, b: Bag, burst: () -> () }
local domes: { [string]: Dome } = {}

local function makeDome(b: Bag, side: string, center: Vector3, radius: number, tint: Color3, burstSound: string?, hitSound: string?): Dome
	local old = domes[side]
	if old then
		old.burst()
	end
	local shell = part(b, Vector3.one * radius * 2, tint, CFrame.new(center), 0.15, Enum.PartType.Ball)
	shell.Material = Enum.Material.ForceField
	shell.Size = Vector3.one * 0.5
	tween(shell, 0.35, { Size = Vector3.one * radius * 2 }, Enum.EasingStyle.Back)
	local inner = part(b, Vector3.one * radius * 1.96, tint, CFrame.new(center), 0.88, Enum.PartType.Ball)
	inner.Material = Enum.Material.Glass
	local dome: Dome
	local function burst()
		if domes[side] == dome then
			domes[side] = nil
		end
		if b.done then
			return
		end
		ElementFx.burst(center + UP * radius * 0.5, tint, radius / 4)
		local spray = ElementFx.emitter(anchor(b, CFrame.new(center + UP * radius * 0.4)), "spark", tint, { size = { 0.6, 0.1 }, life = { 0.6, 1.1 }, speed = { 18, 30 }, spread = 180, accel = -UP * 30 })
		spray:Emit(60)
		play(b, anchor(b, CFrame.new(center)), burstSound, 1)
		tween(shell, 0.25, { Size = Vector3.one * radius * 2.3, Transparency = 1 })
		tween(inner, 0.25, { Transparency = 1 })
		task.delay(1.4, function()
			clear(b)
		end)
	end
	dome = { center = center, radius = radius, tint = tint, b = b, burst = burst }
	domes[side] = dome
	;(dome :: any).hitSound = hitSound
	return dome
end

-- A hit the side's shield soaked (the sim's `absorbed`): a ripple where it struck the dome, toward `from`
function SuperFx.shieldHit(side: string, from: Vector3)
	local dome = domes[side]
	if not dome or dome.b.done then
		return
	end
	local direction = from - dome.center
	local on = dome.center + (if direction.Magnitude > 0.1 then direction.Unit else UP) * dome.radius
	local flash = ElementFx.emitter(anchor(dome.b, CFrame.new(on)), "ring", dome.tint, { size = { 1, dome.radius * 0.5 }, life = 0.35, fade = 0.2, rotation = 0 })
	flash:Emit(1)
	ElementFx.burst(on, dome.tint, 0.5)
	play(dome.b, anchor(dome.b, CFrame.new(on)), (dome :: any).hitSound, 0.7)
end

-- The side's shield ran out: its dome bursts
function SuperFx.shieldGone(side: string)
	local dome = domes[side]
	if dome then
		dome.burst()
	end
end

local SHIELD_CAP = 25 -- seconds a dome stays at most if its shield never runs out (the fight's end clears it too)

-- Tidal Shield (Abyssal Koi, Epic, Tide; spec "Tidal Shield"): the koi leaps from a swirl of water as a huge wave rises
-- behind your side, the wave crashes over you and sets into a shining water dome with spirit koi swimming round it.
-- By grade: a thicker dome, more spirit koi; S: a rainbow sheen and a second ring.
local TIDE = SuperFxConfig.LOOKS.TidalShield
local TIDE_SOUNDS = SuperFxConfig.SOUNDS.TidalShield

-- The way from the caster away from what it faces (where the wave rises, behind your side)
local function behind(view: View, target: Vector3?): Vector3
	local toward = if target then Vector3.new(target.X - view.root.Position.X, 0, target.Z - view.root.Position.Z) else Vector3.zero
	if toward.Magnitude < 0.5 then
		toward = view.root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	return -toward.Unit
end

local function tideCharge(view: View, grade: string, seconds: number, target: Vector3?): () -> ()
	local g = TIDE.grades[grade]
	local b = bag()
	local water = color(TIDE.color)
	local feet = view.root.Position
	local source = anchor(b, CFrame.new(feet + UP * 2))
	play(b, source, TIDE_SOUNDS.call, 1)
	play(b, source, TIDE_SOUNDS.charge, 0.9)
	local swirl = funnel(b, groundAt(feet), math.floor(3 + 2 * g.scale), sequence(Color3.fromRGB(220, 245, 255), water), 1.2 * g.scale, 300, TEX.waterstrip)
	-- The koi leaps out of the swirl and arcs back in
	local koi = part(b, Vector3.new(0.9, 0.9, 2.2) * g.scale, Color3.fromRGB(255, 150, 70), CFrame.new(feet), 0.05, Enum.PartType.Ball)
	local trail = ElementFx.emitter(koi, "spark", Color3.fromRGB(255, 220, 180), { size = { 0.5, 0.1 }, life = 0.5, speed = 0, fade = 0.3 })
	trail.Rate = 40
	-- The wave rises behind your side
	local back = behind(view, target)
	local wavePos = groundAt(feet + back * g.dome * 0.9)
	local wave = part(b, Vector3.new(g.dome * 2.2, 0.5, 2.5), water, CFrame.lookAt(wavePos, wavePos - back), 0.25)
	wave.Material = Enum.Material.Glass
	local foam = ElementFx.emitter(wave, "spark", WHITE, { size = { 0.6, 0.1 }, life = { 0.4, 0.8 }, speed = { 3, 6 }, spread = 40 })
	foam.Shape = Enum.ParticleEmitterShape.Box
	foam.Rate = g.particles
	everyFrame(b, function(elapsed)
		local t = math.clamp(elapsed / math.max(0.1, seconds), 0, 1)
		swirl.set(view.height * (0.4 + 0.6 * t), view.height * 0.4, view.height * (0.6 + 0.4 * t))
		local hop = math.clamp(elapsed / (seconds * 0.7), 0, 1)
		local arc = math.sin(hop * math.pi) * view.height * 1.6
		koi.CFrame = CFrame.lookAt(feet + UP * (arc + 1), feet + UP * (arc + 1) + back * -1 + UP * math.cos(hop * math.pi) * 2)
		local height = g.waveHeight * t
		wave.Size = Vector3.new(g.dome * 2.2, math.max(0.5, height), 2.5)
		wave.CFrame = CFrame.lookAt(wavePos + UP * height / 2, wavePos + UP * height / 2 - back)
	end)
	local stopGlow = ElementFx.chargeGlow(view.root, water, seconds, 1.4 * g.scale)
	return function()
		stopGlow()
		clear(b)
	end
end

local function tideImpact(view: View, grade: string, target: Vector3, _targetBody: BasePart?, _targetHeight: number, side: string): () -> ()
	local g = TIDE.grades[grade]
	local b = bag()
	local water = color(TIDE.color)
	local feet = groundAt(view.root.Position)
	local back = behind(view, target)
	-- The wave crashes over your side
	local crash = part(b, Vector3.new(g.dome * 2.2, g.waveHeight, 2.5), water, CFrame.lookAt(feet + back * g.dome * 0.9 + UP * g.waveHeight / 2, feet + UP * g.waveHeight / 2), 0.25)
	crash.Material = Enum.Material.Glass
	tween(crash, 0.35, { CFrame = CFrame.lookAt(feet + UP * 1, feet + UP * 1 - back) * CFrame.Angles(math.rad(-80), 0, 0), Transparency = 1 }, Enum.EasingStyle.Quad)
	local spray = ElementFx.emitter(anchor(b, CFrame.new(feet + UP * 2)), "spark", Color3.fromRGB(220, 245, 255), { size = { 0.7, 0.1 }, life = { 0.6, 1.2 }, speed = { 14, 24 }, spread = 90, accel = -UP * 25 })
	spray:Emit(g.particles)
	play(b, anchor(b, CFrame.new(feet)), TIDE_SOUNDS.impact, 1.1)
	if grade == "A" or grade == "S" then
		play(b, anchor(b, CFrame.new(feet)), TIDE_SOUNDS.layer, 0.9)
	end
	-- The dome sets, spirit koi swimming round it
	local radius = g.dome
	local center = feet + UP * radius * 0.35
	local dome = makeDome(b, side, center, radius, water, TIDE_SOUNDS.burst, TIDE_SOUNDS.hit)
	local swimmers = {}
	for index = 1, g.koi do
		local fish = part(b, Vector3.new(0.7, 0.7, 1.8), Color3.fromRGB(255, 160, 80), CFrame.new(center), 0.1, Enum.PartType.Ball)
		local glint = ElementFx.emitter(fish, "spark", Color3.fromRGB(255, 225, 190), { size = { 0.4, 0.05 }, life = 0.6, speed = 0, fade = 0.3 })
		glint.Rate = 25
		table.insert(swimmers, { fish = fish, tilt = (index / g.koi) * math.pi, speed = 0.9 + index * 0.12, phase = index * 1.7 })
	end
	local sheen: Part? = nil
	if g.extra then
		sheen = part(b, Vector3.one * radius * 2.08, WHITE, CFrame.new(center), 0.8, Enum.PartType.Ball)
		;(sheen :: Part).Material = Enum.Material.Glass
		local ring = fireRing(b, center, radius * 1.15, 18, Color3.fromRGB(190, 240, 255), 1.4)
		for _, flame in ring do
			flame.Texture = AttackFx.TEXTURES.spark
		end
	end
	everyFrame(b, function(elapsed)
		for _, s in swimmers do
			local a = elapsed * s.speed + s.phase
			local orbit = CFrame.Angles(s.tilt, 0, 0) * Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.98
			local nextOrbit = CFrame.Angles(s.tilt, 0, 0) * Vector3.new(math.cos(a + 0.1), 0, math.sin(a + 0.1)) * radius * 0.98
			s.fish.CFrame = CFrame.lookAt(center + orbit, center + nextOrbit)
		end
		if sheen then
			sheen.Color = Color3.fromHSV((elapsed * 0.25) % 1, 0.45, 1)
		end
	end)
	task.delay(SHIELD_CAP, dome.burst)
	return dome.burst
end

-- Tidal Blessing (Tideborne Kirin, Legendary, Tide, Frontier; spec "Tidal Blessing"): clouds part with rays of light, a
-- giant water lotus opens under your side, its petals rise and close into a dome of light-water, a soft rain of light
-- falls while it holds. By grade: lotus size, petal count, light rays; S: a halo over the Kirin and golden rain.
local BLESS = SuperFxConfig.LOOKS.TidalBlessing
local BLESS_SOUNDS = SuperFxConfig.SOUNDS.TidalBlessing
local GOLD = Color3.fromRGB(255, 226, 140)

-- The petals of a lotus round `center`: flat leaves pointing out, `open` 0 (closed up) to 1 (flat out)
local function petals(b: Bag, center: Vector3, count: number, length: number, tint: Color3): (open: number, lift: number) -> ()
	local list = {}
	for index = 1, count do
		local leaf = part(b, Vector3.new(length * 0.42, 0.25, length), tint, CFrame.new(center), 0.2, Enum.PartType.Ball)
		table.insert(list, { leaf = leaf, angle = (index - 1) / count * 2 * math.pi })
	end
	return function(open: number, lift: number)
		for _, p in list do
			local out = CFrame.new(center + UP * lift) * CFrame.Angles(0, p.angle, 0)
			local tilt = math.rad(90 - 75 * open) -- 90: standing up (closed), 15: nearly flat (open)
			p.leaf.CFrame = out * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, 0, -length * 0.5)
		end
	end
end

-- Light rays from the sky onto `at`: `count` beams fanning down from parted clouds `height` studs up
local function skyRays(b: Bag, at: Vector3, height: number, count: number, tint: Color3, width: number)
	for index = 1, count do
		local angle = index / count * 2 * math.pi
		local top = anchor(b, CFrame.new(at + UP * height + Vector3.new(math.cos(angle), 0, math.sin(angle)) * height * 0.25))
		local foot = anchor(b, CFrame.new(at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * width))
		beam(attachment(top, Vector3.zero), attachment(foot, Vector3.zero), AttackFx.TEXTURES.streak, sequence(WHITE, tint), width * 0.6, width * 1.4, {
			speed = 0.4,
			length = height,
			brightness = 1.5,
			transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.7, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		})
	end
	-- the clouds parting: puffs drifting apart overhead
	for index = 1, 10 do
		local angle = index / 10 * 2 * math.pi
		local puff = part(b, Vector3.new(9, 4, 7), Color3.fromRGB(235, 242, 255), CFrame.new(at + UP * height + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 4), 0.35, Enum.PartType.Ball)
		puff.Material = Enum.Material.SmoothPlastic
		tween(puff, 1.6, { CFrame = CFrame.new(at + UP * height + Vector3.new(math.cos(angle), 0, math.sin(angle)) * height * 0.6) })
	end
end

local function blessCharge(view: View, grade: string, seconds: number, _target: Vector3?): () -> ()
	local g = BLESS.grades[grade]
	local b = bag()
	local light = color(BLESS.color)
	local feet = groundAt(view.root.Position)
	local source = anchor(b, CFrame.new(feet + UP * 2))
	play(b, source, BLESS_SOUNDS.call, 0.9)
	play(b, source, BLESS_SOUNDS.charge, 0.9)
	skyRays(b, feet, 34, g.rays, GOLD, 2.2 * g.scale)
	local setPetals = petals(b, feet + UP * 0.3, g.petals, g.lotus * 0.5, light)
	everyFrame(b, function(elapsed)
		local open = math.clamp(elapsed / math.max(0.1, seconds * 0.8), 0, 1)
		setPetals(open, 0.2)
	end)
	local motes = ElementFx.emitter(anchor(b, CFrame.new(feet + UP * 12)), "spark", GOLD, { size = { 0.4, 0.1 }, life = { 1, 1.6 }, speed = { 2, 4 }, spread = 180, accel = -UP * 3 })
	motes.Shape = Enum.ParticleEmitterShape.Sphere
	motes.Rate = g.particles
	local stopGlow = ElementFx.chargeGlow(view.root, light, seconds, 1.6 * g.scale)
	return function()
		stopGlow()
		clear(b)
	end
end

local function blessImpact(view: View, grade: string, _target: Vector3, _targetBody: BasePart?, _targetHeight: number, side: string): () -> ()
	local g = BLESS.grades[grade]
	local b = bag()
	local light = color(BLESS.color)
	local feet = groundAt(view.root.Position)
	play(b, anchor(b, CFrame.new(feet)), BLESS_SOUNDS.impact, 1.1)
	if grade == "A" or grade == "S" then
		play(b, anchor(b, CFrame.new(feet)), BLESS_SOUNDS.layer, 0.9)
	end
	-- The petals rise and close into the dome
	local radius = g.lotus * 0.75
	local before = #b.items
	local setPetals = petals(b, feet, g.petals, g.lotus * 0.5, light)
	local leaves = table.move(b.items, before + 1, #b.items, 1, {})
	everyFrame(b, function(elapsed)
		local close = math.clamp(elapsed / 0.4, 0, 1)
		setPetals(1 - close, close * radius * 0.5)
	end)
	task.delay(0.45, function()
		if b.done then
			return
		end
		for _, leaf in leaves do
			tween(leaf, 0.3, { Transparency = 1 })
		end
	end)
	local center = feet + UP * radius * 0.35
	local dome = makeDome(b, side, center, radius, light, BLESS_SOUNDS.burst, BLESS_SOUNDS.hit)
	ElementFx.burst(center, GOLD, radius / 3)
	-- A soft rain of light over your side while it holds (S: golden)
	local rain = ElementFx.emitter(anchor(b, CFrame.new(center + UP * radius * 0.8)), "spark", if g.extra then GOLD else light, {
		size = { 0.35, 0.1 },
		life = { 1.2, 1.8 },
		speed = { 6, 9 },
		spread = 25,
		direction = Enum.NormalId.Bottom,
	})
	rain.Shape = Enum.ParticleEmitterShape.Disc
	rain.Rate = g.particles
	local hum = play(b, anchor(b, CFrame.new(center)), BLESS_SOUNDS.linger, 0.45, true)
	if hum then
		task.delay(4, function()
			tween(hum, 1.5, { Volume = 0 })
		end)
	end
	if g.extra then
		-- A halo over the Kirin
		local crown = view.root.Position + UP * (view.height * 1.25)
		for index = 1, 16 do
			local angle = index / 16 * 2 * math.pi
			part(b, Vector3.new(0.45, 0.45, 0.45), GOLD, CFrame.new(crown + Vector3.new(math.cos(angle), 0, math.sin(angle)) * view.height * 0.35), 0, Enum.PartType.Ball)
		end
	end
	task.delay(SHIELD_CAP, dome.burst)
	return dome.burst
end

-- See-through copies of the creature's model along a path (afterimages), fading over `life`
local function afterimages(b: Bag, view: View, from: Vector3, to: Vector3, count: number, tint: Color3, life: number)
	local model = view.root:FindFirstAncestorOfClass("Model")
	if not model then
		return
	end
	local pivot = model:GetPivot()
	for index = 1, count do
		local copy = model:Clone()
		for _, item in copy:GetDescendants() do
			if item:IsA("BasePart") then
				item.Anchored = true
				item.CanCollide = false
				item.CanQuery = false
				item.CanTouch = false
				item.CastShadow = false
				item.Material = Enum.Material.Neon
				item.Color = tint
				item.Transparency = 0.55
				if item:IsA("MeshPart") then
					item.TextureID = ""
				end
			elseif item:IsA("Decal") or item:IsA("Texture") or item:IsA("SurfaceAppearance") or item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Light") or item:IsA("BillboardGui") then
				item:Destroy()
			end
		end
		local spot = from:Lerp(to, index / (count + 1))
		copy:PivotTo(pivot.Rotation + spot + (pivot.Position - view.root.Position))
		copy.Parent = folder()
		table.insert(b.items, copy)
		task.delay(index * 0.03, function()
			for _, item in copy:GetDescendants() do
				if item:IsA("BasePart") then
					tween(item, life, { Transparency = 1 })
				end
			end
		end)
	end
end

-- Electric rings spinning round a point (a stun): `count` rings of sparks for `seconds`
local function stunRings(b: Bag, at: Vector3, radius: number, count: number, tint: Color3, seconds: number)
	local holder = anchor(b, CFrame.new(at))
	local dots = {}
	for ring = 1, count do
		for index = 1, 8 do
			local dot = part(b, Vector3.one * 0.45, tint, CFrame.new(at), 0, Enum.PartType.Ball)
			table.insert(dots, { dot = dot, ring = ring, angle = index / 8 * 2 * math.pi })
		end
	end
	local zap = ElementFx.emitter(holder, "spark", tint, { size = { 0.5, 0.1 }, life = 0.25, speed = { 6, 10 }, spread = 180 })
	zap.Rate = 20
	everyFrame(b, function(elapsed)
		for _, d in dots do
			local a = d.angle + elapsed * (5 + d.ring)
			local tilt = CFrame.Angles(d.ring * 0.7, 0, d.ring * 0.4)
			d.dot.CFrame = CFrame.new(at) * tilt * CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		end
		if elapsed > seconds then
			for _, d in dots do
				d.dot.Transparency = 1
			end
			zap.Rate = 0
		end
	end)
end

-- Stampede (Thunderhorn, Epic, Volt; spec "Stampede"): it paws the ground as sparks fly and lightning wraps it, then a
-- lightning dash through the boss with afterimages and a thunderclap, electric rings spinning round its head for the
-- stun and a scorched trail. By grade: more afterimages, a wider trail; S: a bolt from the sky as it passes.
local STAMP = SuperFxConfig.LOOKS.Stampede
local STAMP_SOUNDS = SuperFxConfig.SOUNDS.Stampede

local function stampCharge(view: View, grade: string, seconds: number, _target: Vector3?): () -> ()
	local g = STAMP.grades[grade]
	local b = bag()
	local volt = color(STAMP.color)
	local feet = groundAt(view.root.Position)
	local source = anchor(b, CFrame.new(view.root.Position + UP * view.height * 0.5))
	play(b, source, STAMP_SOUNDS.call, 1)
	task.delay(seconds * 0.4, function()
		if not b.done then
			play(b, source, STAMP_SOUNDS.charge, 1)
		end
	end)
	-- Sparks kicked up from the ground as it paws, lightning crawling round it
	local kick = ElementFx.emitter(anchor(b, CFrame.new(feet)), "spark", volt, { size = { 0.5, 0.1 }, life = { 0.3, 0.6 }, speed = { 8, 14 }, spread = 50, accel = -UP * 20 })
	kick.Rate = g.particles
	local reach = view.height * 0.6
	everyFrame(b, function(elapsed)
		if math.floor(elapsed * 6) ~= math.floor((elapsed - 1 / 60) * 6) then
			local a = math.random() * 2 * math.pi
			local from = view.root.Position + UP * view.height * (0.2 + math.random() * 0.6) + Vector3.new(math.cos(a), 0, math.sin(a)) * reach
			local to = view.root.Position + UP * view.height * (0.2 + math.random() * 0.6) + Vector3.new(math.cos(a + 2), 0, math.sin(a + 2)) * reach
			ElementFx.bolt(from, to, volt, 0.12, 0.6 * g.scale)
		end
	end)
	local stopGlow = ElementFx.chargeGlow(view.root, volt, seconds, 1.5 * g.scale)
	return function()
		stopGlow()
		clear(b)
	end
end

local function stampImpact(view: View, grade: string, target: Vector3, _targetBody: BasePart?, targetHeight: number): () -> ()
	local g = STAMP.grades[grade]
	local b = bag()
	local volt = color(STAMP.color)
	local ability = SuperFx.abilityOf("Stampede") or { stun = 2 }
	local start = groundAt(view.root.Position)
	local ground = groundAt(target)
	local flat = Vector3.new(ground.X - start.X, 0, ground.Z - start.Z)
	local past = ground + (if flat.Magnitude > 0.5 then flat.Unit else Vector3.zero) * math.max(4, targetHeight * 0.5)
	play(b, anchor(b, CFrame.new(target)), STAMP_SOUNDS.impact, 1.2)
	if grade == "A" or grade == "S" then
		play(b, anchor(b, CFrame.new(target)), STAMP_SOUNDS.layer, 1)
	end
	-- The dash: afterimages along the way, a lightning trail, a thunderclap at the boss
	afterimages(b, view, start, past, g.afterimages, volt, 0.5)
	local a0 = anchor(b, CFrame.new(start + UP * view.height * 0.5))
	local a1 = anchor(b, CFrame.new(past + UP * view.height * 0.5))
	local trail = beam(attachment(a0, Vector3.zero), attachment(a1, Vector3.zero), AttackFx.TEXTURES.streak, sequence(WHITE, volt), g.trailWidth * 1.5, g.trailWidth, { speed = 6, length = 8 })
	tween(trail, 0.5, { Width0 = 0, Width1 = 0 })
	for _ = 1, 3 do
		ElementFx.bolt(start + UP * view.height * 0.5, past + UP * view.height * 0.5, volt, 0.25, g.scale)
	end
	ElementFx.burst(target, volt, 1.8 * g.scale)
	ElementFx.ring(ground + UP * 0.2, volt, math.max(5, targetHeight * 0.6) * g.scale, 0.4)
	-- The scorched trail on the ground
	crackLine(b, start, past, g.trailWidth * 0.6, Color3.fromRGB(40, 30, 20), 0.15, 0.3)
	-- S: a bolt from the sky as it passes
	if g.extra then
		ElementFx.skyStrike(target, volt, 1.6)
	end
	-- The stun: electric rings round its head
	local head = target + UP * math.max(1.5, targetHeight * 0.45)
	stunRings(b, head, math.max(1.5, targetHeight * 0.25), 2, volt, ability.stun)
	local hum = play(b, anchor(b, CFrame.new(head)), STAMP_SOUNDS.linger, 0.6, true)
	task.delay(ability.stun + 0.3, function()
		if hum then
			tween(hum, 0.3, { Volume = 0 })
		end
		task.delay(0.5, function()
			clear(b)
		end)
	end)
	return function()
		clear(b)
	end
end

-- A dodge's puff: what a dodging super does when a hit passes through it (Eclipse's shadow, Rift Step's empty rift)
local dodgers: { [BasePart]: (at: Vector3) -> () } = {}

function SuperFx.dodged(root: BasePart, at: Vector3)
	local react = dodgers[root]
	if react then
		react(at)
	end
end

-- Eclipse (Eclipse Fox, Epic, Shade; spec "Eclipse"): the fox howls at the sky, a black moon slides over the sun, a ring
-- of violet light bursts out and the fox turns to shadow: attacks pass through it in puffs of shadow, afterimages
-- trail it and the eclipse hangs above for the 3 s. By grade: a bigger corona, more afterimages; S: two shadow clones.
local ECLIPSE = SuperFxConfig.LOOKS.Eclipse
local ECLIPSE_SOUNDS = SuperFxConfig.SOUNDS.Eclipse
local SHADOW = Color3.fromRGB(40, 24, 70)

-- The eclipse in the sky over `at`: a black moon in a glowing corona, `size` studs, `height` up
local function eclipseSky(b: Bag, at: Vector3, size: number, tint: Color3, height: number): (Part, Part)
	local center = at + UP * height
	local corona = part(b, Vector3.one * size * 1.35, tint, CFrame.new(center), 0.35, Enum.PartType.Ball)
	local moon = part(b, Vector3.one * size, Color3.fromRGB(8, 4, 16), CFrame.new(center), 0, Enum.PartType.Ball)
	moon.Material = Enum.Material.SmoothPlastic
	local glow = ElementFx.emitter(corona, "glow", tint, { size = { size * 1.6, size * 1.9 }, life = 0.8, fade = 0.3, locked = true, rotation = 0 })
	glow.Rate = 3
	return moon, corona
end

local function eclipseCharge(view: View, grade: string, seconds: number, _target: Vector3?): () -> ()
	local g = ECLIPSE.grades[grade]
	local b = bag()
	local violet = color(ECLIPSE.color)
	local source = anchor(b, CFrame.new(view.root.Position + UP * view.height))
	play(b, source, ECLIPSE_SOUNDS.call, 1)
	play(b, source, ECLIPSE_SOUNDS.charge, 0.8)
	-- The moon slides over the sun: a pale sun high above, the black disc moving across it
	local sky = view.root.Position + UP * 30
	local sun = part(b, Vector3.one * g.corona, Color3.fromRGB(255, 236, 170), CFrame.new(sky), 0.1, Enum.PartType.Ball)
	local moon = part(b, Vector3.one * g.corona * 0.95, Color3.fromRGB(8, 4, 16), CFrame.new(sky + Vector3.new(g.corona * 1.5, 0, 0)), 0, Enum.PartType.Ball)
	moon.Material = Enum.Material.SmoothPlastic
	tween(moon, seconds, { CFrame = CFrame.new(sky - (sky - workspace.CurrentCamera.CFrame.Position).Unit * 2) }, Enum.EasingStyle.Sine)
	tween(sun, seconds, { Color = violet })
	local wisps = ElementFx.emitter(anchor(b, CFrame.new(view.root.Position)), "smoke", SHADOW, { size = { 1.5, 3 }, life = { 0.6, 1 }, speed = { 1, 3 }, spread = 180, accel = UP * 2, light = 0 })
	wisps.Rate = g.particles * 0.5
	local stopGlow = ElementFx.chargeGlow(view.root, violet, seconds, 1.4 * g.scale)
	return function()
		stopGlow()
		clear(b)
	end
end

local function eclipseImpact(view: View, grade: string, _target: Vector3, _targetBody: BasePart?, _targetHeight: number): () -> ()
	local g = ECLIPSE.grades[grade]
	local b = bag()
	local violet = color(ECLIPSE.color)
	local seconds = (SuperFx.abilityOf("Eclipse") or { seconds = 3 }).seconds
	local feet = groundAt(view.root.Position)
	play(b, anchor(b, CFrame.new(feet)), ECLIPSE_SOUNDS.impact, 1.1)
	if grade == "A" or grade == "S" then
		play(b, anchor(b, CFrame.new(feet)), ECLIPSE_SOUNDS.layer, 0.9)
	end
	-- The eclipse hangs above, a ring of violet light bursts out
	eclipseSky(b, view.root.Position, g.corona, violet, 30)
	ElementFx.ring(feet + UP * 0.2, violet, view.height * 2 * g.scale, 0.5)
	ElementFx.burst(view.root.Position + UP * view.height * 0.5, violet, 1.6 * g.scale)
	-- The fox turned to shadow: a dark haze round it, afterimages trailing it
	local haze = ElementFx.emitter(view.root, "smoke", SHADOW, { size = { view.height * 0.5, view.height * 0.8 }, life = { 0.4, 0.7 }, speed = { 0.5, 1.5 }, spread = 180, light = 0 })
	haze.Rate = g.particles * 0.6
	table.insert(b.items, haze)
	local last = view.root.Position
	everyFrame(b, function()
		local now = view.root.Position
		if (now - last).Magnitude > 2 then
			afterimages(b, view, last, now, 1, violet, 0.4)
			last = now
		end
	end)
	-- S: two shadow clones beside it
	if g.extra then
		local side = view.root.CFrame.RightVector * view.height * 0.9
		afterimages(b, view, view.root.Position - side, view.root.Position - side, 1, SHADOW, seconds)
		afterimages(b, view, view.root.Position + side, view.root.Position + side, 1, SHADOW, seconds)
	end
	local drone = play(b, anchor(b, CFrame.new(feet)), ECLIPSE_SOUNDS.linger, 0.6, true)
	-- Attacks pass through it in a puff of shadow
	dodgers[view.root] = function(at: Vector3)
		ElementFx.emitter(anchor(b, CFrame.new(at)), "smoke", SHADOW, { size = { 2, 4 }, life = 0.5, speed = { 3, 6 }, spread = 180, light = 0 }):Emit(10)
	end
	task.delay(seconds, function()
		if dodgers[view.root] then
			dodgers[view.root] = nil
		end
		haze.Rate = 0
		if drone then
			tween(drone, 0.4, { Volume = 0 })
		end
		task.delay(0.8, function()
			clear(b)
		end)
	end)
	return function()
		dodgers[view.root] = nil
		clear(b)
	end
end

-- Rift Step (Riftwalker, Epic, Shade, Frontier; spec "Rift Step"): space cracks like glass round it, the cracks open into
-- purple void, it shatters through a rift and blinks out, then blinks between rifts while attacks hit empty cracks
-- that seal up. By grade: more rifts and shards; S: the arena's edge cracks for a moment.
local RIFT = SuperFxConfig.LOOKS.RiftStep
local RIFT_SOUNDS = SuperFxConfig.SOUNDS.RiftStep

-- A crack in space at `at` facing `facing`: a dark void pane with a glowing rim, `size` studs
local function riftPane(b: Bag, at: Vector3, facing: Vector3, size: number, tint: Color3): Part
	local pane = part(b, Vector3.new(size * 0.55, size, 0.1), Color3.fromRGB(10, 2, 20), CFrame.lookAt(at, at + facing) * CFrame.Angles(0, 0, math.random() - 0.5), 0.1)
	pane.Material = Enum.Material.SmoothPlastic
	local decal = Instance.new("Decal")
	decal.Texture = TEX.crack
	decal.Color3 = tint
	decal.Face = Enum.NormalId.Front
	decal.Parent = pane
	local back = decal:Clone()
	back.Face = Enum.NormalId.Back
	back.Parent = pane
	return pane
end

local function riftCharge(view: View, grade: string, seconds: number, _target: Vector3?): () -> ()
	local g = RIFT.grades[grade]
	local b = bag()
	local void = color(RIFT.color)
	local center = view.root.Position + UP * view.height * 0.5
	play(b, anchor(b, CFrame.new(center)), RIFT_SOUNDS.call, 1)
	play(b, anchor(b, CFrame.new(center)), RIFT_SOUNDS.charge, 0.9)
	for index = 1, g.rifts do
		task.delay((index - 1) / g.rifts * seconds * 0.8, function()
			if b.done then
				return
			end
			local a = index / g.rifts * 2 * math.pi
			local spot = center + Vector3.new(math.cos(a), (math.random() - 0.5) * 0.6, math.sin(a)) * view.height * 0.9
			local pane = riftPane(b, spot, spot - center, view.height * 0.4 * g.scale, void)
			pane.Size = Vector3.new(0.1, 0.1, 0.1)
			tween(pane, 0.3, { Size = Vector3.new(view.height * 0.22 * g.scale, view.height * 0.4 * g.scale, 0.1) })
		end)
	end
	local stopGlow = ElementFx.chargeGlow(view.root, void, seconds, 1.4 * g.scale)
	return function()
		stopGlow()
		clear(b)
	end
end

local function riftImpact(view: View, grade: string, _target: Vector3, _targetBody: BasePart?, _targetHeight: number): () -> ()
	local g = RIFT.grades[grade]
	local b = bag()
	local void = color(RIFT.color)
	local seconds = (SuperFx.abilityOf("RiftStep") or { seconds = 3 }).seconds
	local center = view.root.Position + UP * view.height * 0.5
	play(b, anchor(b, CFrame.new(center)), RIFT_SOUNDS.impact, 1.1)
	if grade == "A" or grade == "S" then
		play(b, anchor(b, CFrame.new(center)), RIFT_SOUNDS.layer, 1)
	end
	-- It shatters through: glass shards flying out, a flash of void
	local shards = ElementFx.emitter(anchor(b, CFrame.new(center)), "shard", void, { size = { 0.9, 0.2 }, life = { 0.5, 0.9 }, speed = { 16, 28 }, spread = 180, spin = { -400, 400 }, accel = -UP * 20 })
	shards:Emit(g.shards)
	ElementFx.burst(center, void, 1.6 * g.scale)
	-- Rifts hanging round it while it blinks
	for index = 1, g.rifts do
		local a = index / g.rifts * 2 * math.pi
		local spot = center + Vector3.new(math.cos(a), (math.random() - 0.5) * 0.8, math.sin(a)) * view.height * 1.2
		riftPane(b, spot, spot - center, view.height * 0.5 * g.scale, void)
	end
	-- S: the arena's edge cracks for a moment (a ring of rifts far out)
	if g.extra then
		for index = 1, 12 do
			local a = index / 12 * 2 * math.pi
			local spot = center + Vector3.new(math.cos(a), 0.3, math.sin(a)) * 28
			local pane = riftPane(b, spot, center - spot, 9, void)
			task.delay(1.2, function()
				tween(pane, 0.5, { Transparency = 1 })
			end)
		end
	end
	-- Attacks hit an empty crack that seals up
	dodgers[view.root] = function(at: Vector3)
		local pane = riftPane(b, at, (at - view.root.Position) * Vector3.new(1, 0, 1) + Vector3.new(0, 0, 0.01), 3, void)
		play(b, pane, RIFT_SOUNDS.blink, 0.8)
		tween(pane, 0.45, { Size = Vector3.new(0.1, 0.1, 0.1) })
	end
	task.delay(seconds, function()
		dodgers[view.root] = nil
		task.delay(0.6, function()
			clear(b)
		end)
	end)
	return function()
		dodgers[view.root] = nil
		clear(b)
	end
end

-- The finished looks (spec "The ten moves"), by look id; the rest play the first pass
local LOOKS: { [string]: Look } = {
	Inferno = { charge = infernoCharge, impact = infernoImpact },
	MagmaSlam = { charge = magmaCharge, impact = magmaImpact },
	TidalShield = { charge = tideCharge, impact = tideImpact },
	TidalBlessing = { charge = blessCharge, impact = blessImpact },
	Stampede = { charge = stampCharge, impact = stampImpact },
	Eclipse = { charge = eclipseCharge, impact = eclipseImpact },
	RiftStep = { charge = riftCharge, impact = riftImpact },
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
function SuperFx.impact(lookId: string, view: View, grade: string, target: Vector3, targetBody: BasePart?, targetHeight: number, side: string?): () -> ()
	local own = LOOKS[lookId]
	if own then
		return own.impact(view, grade, target, targetBody, targetHeight, side or "a")
	end
	return placeholderImpact(lookId, view, target)
end

return SuperFx
