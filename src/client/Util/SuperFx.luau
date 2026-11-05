--!strict
-- The super moves in the world, for everyone in the fight (spec 2026-11-05-super-moves-design, Config/SuperFx): each
-- look's charge (from the press to the impact, on the caster) and its impact and linger (where it lands, for as long
-- as the move lasts). Routed from Util/FightFx; the caster's own screen (camera, cut-in, flash) is Util/SuperCinematic.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("Config"):WaitForChild("AttackFx"))
local Combat = require(Shared:WaitForChild("Config"):WaitForChild("Combat"))
local SuperFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("SuperFx"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))
local SoundBank = require((script.Parent :: Instance):WaitForChild("SoundBank"))
local ScreenFx = require((script.Parent :: Instance):WaitForChild("ScreenFx"))

local SuperFx = {}

-- The caster as Util/FightFx sees it
export type View = { root: BasePart, element: string, height: number, grade: string?, mine: boolean }
-- One warded ally (Tidal Shield, Tidal Blessing): its fighter id, the part its bubble follows, its height and how far
-- over the part the bubble's centre sits
export type Ally = { id: string, part: BasePart, height: number, lift: number }
-- extra: what the landing event adds (the shields' warded allies and their seconds)
export type Extra = { allies: { Ally }?, seconds: number? }
type Look = {
	charge: (view: View, grade: string, seconds: number, target: Vector3?) -> () -> (),
	impact: (view: View, grade: string, target: Vector3, targetBody: BasePart?, targetHeight: number, extra: Extra) -> () -> (),
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

-- A look's big moment shakes everyone's screen near it (owner 2026-11-05: "add screenshake on impact"): its grade's
-- shake times `mult`, less the further you are (the caster's own cinematic adds its shake on top)
local function quake(g: any, at: Vector3, mult: number?)
	ScreenFx.shakeAt(AttackFx.SHAKE.super * g.shake * (mult or 1), at)
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
	-- It leaps high (its wind-up pose) as fire gathers in its jaws
	local stopGather = ElementFx.gather(feet + UP * view.height * 1.4, base, seconds, view.height * 0.8 * g.scale)
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
		stopGather()
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
	quake(g, target, 0.6)
	-- Then the fire tornado erupts round the boss and engulfs it (owner: "breath fire then tornado"), then dies down
	task.delay(0.45, function()
		if b.done then
			return
		end
		quake(g, target, 1.2)
		local spin = funnel(b, ground, math.floor(4 + 2 * g.scale), flames, 2 * g.scale, 320)
		local height = g.tornadoHeight * math.max(1, targetHeight / 10)
		everyFrame(b, function(elapsed)
			local rise = math.clamp(elapsed / 0.3, 0, 1)
			local fade = math.clamp((elapsed - 1.4) / 0.6, 0, 1)
			spin.set(height * (0.3 + 0.7 * rise) * (1 - fade), fit * 0.6 * (1 - fade * 0.5), fit * 1.3)
			if fade >= 1 then
				for _, each in spin.beams do
					each.Enabled = false
				end
			end
		end)
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
	quake(g, landing, 1.3)
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
		quake(g, ground, 0.8)
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

-- The shields' bubbles (Tidal Shield, Tidal Blessing; the sim's per-fighter ward, owner 2026-11-05 "you and your
-- whole party"): one round each warded ally that follows it, rippling where a hit its ward soaks lands and bursting in a
-- splash when that ward breaks or runs out (the sim's "shieldGone"), a new cast or the fight ends
type Dome = { ally: Ally, radius: number, tint: Color3, b: Bag, burst: () -> (), hitSound: string? }
local domes: { [string]: Dome } = {}

local function domeCenter(dome: Dome): Vector3
	return dome.ally.part.Position + UP * dome.ally.lift
end

-- A bubble round `ally` for `seconds` (its ward's; the sim's "shieldGone" usually bursts it first); `b` holds it and
-- whatever the look hangs on it
local function makeDome(ally: Ally, tint: Color3, seconds: number, burstSound: string?, hitSound: string?): Dome
	local old = domes[ally.id]
	if old then
		old.burst()
	end
	local b = bag()
	local radius = math.max(3, ally.height * 0.8)
	local center = ally.part.Position + UP * ally.lift
	local shell = part(b, Vector3.one * 0.5, tint, CFrame.new(center), 0.15, Enum.PartType.Ball)
	shell.Material = Enum.Material.ForceField
	tween(shell, 0.35, { Size = Vector3.one * radius * 2 }, Enum.EasingStyle.Back)
	local inner = part(b, Vector3.one * radius * 1.96, tint, CFrame.new(center), 0.88, Enum.PartType.Ball)
	inner.Material = Enum.Material.Glass
	local dome: Dome
	local function burst()
		if domes[ally.id] == dome then
			domes[ally.id] = nil
		end
		if b.done then
			return
		end
		local at = if ally.part.Parent then domeCenter(dome) else center
		for _, connection in b.connections do
			connection:Disconnect() -- it stops following and bursts where it is
		end
		ElementFx.burst(at + UP * radius * 0.5, tint, radius / 4)
		local spray = ElementFx.emitter(anchor(b, CFrame.new(at + UP * radius * 0.4)), "spark", tint, { size = { 0.6, 0.1 }, life = { 0.6, 1.1 }, speed = { 18, 30 }, spread = 180, accel = -UP * 30 })
		spray:Emit(40)
		play(b, anchor(b, CFrame.new(at)), burstSound, 0.9)
		tween(shell, 0.25, { Size = Vector3.one * radius * 2.3, Transparency = 1 })
		tween(inner, 0.25, { Transparency = 1 })
		task.delay(1.4, function()
			clear(b)
		end)
	end
	dome = { ally = ally, radius = radius, tint = tint, b = b, burst = burst, hitSound = hitSound }
	domes[ally.id] = dome
	everyFrame(b, function()
		if not ally.part.Parent then
			burst()
			return
		end
		local now = CFrame.new(domeCenter(dome))
		shell.CFrame, inner.CFrame = now, now
	end)
	task.delay(seconds + 0.5, burst)
	return dome
end

-- Every warded ally's bubble (none listed: the caster's own); returns them and a stop that bursts them all
local function makeDomes(view: View, extra: Extra, tint: Color3, burstSound: string?, hitSound: string?): ({ Dome }, () -> ())
	local allies = extra.allies
	if not allies or #allies == 0 then
		allies = { { id = "caster", part = view.root, height = view.height, lift = view.height * 0.45 } }
	end
	local made = {}
	for _, ally in allies :: { Ally } do
		table.insert(made, makeDome(ally, tint, extra.seconds or 8, burstSound, hitSound))
	end
	return made, function()
		for _, dome in made do
			dome.burst()
		end
	end
end

-- A hit a ward soaked (the sim's `absorbed`): a ripple where it struck that fighter's bubble, toward `from`
function SuperFx.shieldHit(id: string, from: Vector3)
	local dome = domes[id]
	if not dome or dome.b.done or not dome.ally.part.Parent then
		return
	end
	local center = domeCenter(dome)
	local direction = from - center
	local on = center + (if direction.Magnitude > 0.1 then direction.Unit else UP) * dome.radius
	local flash = ElementFx.emitter(anchor(dome.b, CFrame.new(on)), "ring", dome.tint, { size = { 1, dome.radius * 0.5 }, life = 0.35, fade = 0.2, rotation = 0 })
	flash:Emit(1)
	ElementFx.burst(on, dome.tint, 0.5)
	play(dome.b, anchor(dome.b, CFrame.new(on)), dome.hitSound, 0.7)
end

-- The fight is over: every bubble bursts
function SuperFx.burstDomes()
	for _, dome in domes do
		dome.burst()
	end
end

-- That fighter's ward broke or ran out: its bubble bursts
function SuperFx.shieldGone(id: string)
	local dome = domes[id]
	if dome then
		dome.burst()
	end
end

-- Tidal Shield (Abyssal Koi, Epic, Tide; spec "Tidal Shield"): the koi leaps from a swirl of water as a huge wave rises
-- behind your side and crashes over it, and every ally (you, your creatures) is left in a shining water bubble with
-- spirit koi swimming round it for the ward's seconds. By grade: a bigger wave, more spirit koi; S: a rainbow sheen.
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

local function tideImpact(view: View, grade: string, target: Vector3, _targetBody: BasePart?, _targetHeight: number, extra: Extra): () -> ()
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
	quake(g, feet, 0.8)
	if grade == "A" or grade == "S" then
		play(b, anchor(b, CFrame.new(feet)), TIDE_SOUNDS.layer, 0.9)
	end
	-- A bubble sets round every ally, spirit koi swimming round each (S: a rainbow sheen)
	local made, burstAll = makeDomes(view, extra, water, TIDE_SOUNDS.burst, TIDE_SOUNDS.hit)
	local each = math.max(1, math.ceil(g.koi / #made))
	for _, dome in made do
		local swimmers = {}
		for index = 1, each do
			local fish = part(dome.b, Vector3.new(0.7, 0.7, 1.8), Color3.fromRGB(255, 160, 80), CFrame.new(domeCenter(dome)), 0.1, Enum.PartType.Ball)
			local glint = ElementFx.emitter(fish, "spark", Color3.fromRGB(255, 225, 190), { size = { 0.4, 0.05 }, life = 0.6, speed = 0, fade = 0.3 })
			glint.Rate = 25
			table.insert(swimmers, { fish = fish, tilt = (index / each) * math.pi, speed = 0.9 + index * 0.12, phase = index * 1.7 })
		end
		local sheen: Part? = nil
		if g.extra then
			sheen = part(dome.b, Vector3.one * dome.radius * 2.08, WHITE, CFrame.new(domeCenter(dome)), 0.8, Enum.PartType.Ball)
			;(sheen :: Part).Material = Enum.Material.Glass
		end
		everyFrame(dome.b, function(elapsed)
			if not dome.ally.part.Parent then
				return
			end
			local center = domeCenter(dome)
			for _, s in swimmers do
				local a = elapsed * s.speed + s.phase
				local orbit = CFrame.Angles(s.tilt, 0, 0) * Vector3.new(math.cos(a), 0, math.sin(a)) * dome.radius * 0.98
				local nextOrbit = CFrame.Angles(s.tilt, 0, 0) * Vector3.new(math.cos(a + 0.1), 0, math.sin(a + 0.1)) * dome.radius * 0.98
				s.fish.CFrame = CFrame.lookAt(center + orbit, center + nextOrbit)
			end
			if sheen then
				sheen.CFrame = CFrame.new(center)
				sheen.Color = Color3.fromHSV((elapsed * 0.25) % 1, 0.45, 1)
			end
		end)
	end
	task.delay(1.5, function()
		clear(b) -- the wave's spray; the bubbles hold on their own
	end)
	return function()
		burstAll()
		clear(b)
	end
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

local function blessImpact(view: View, grade: string, _target: Vector3, _targetBody: BasePart?, _targetHeight: number, extra: Extra): () -> ()
	local g = BLESS.grades[grade]
	local b = bag()
	local light = color(BLESS.color)
	local feet = groundAt(view.root.Position)
	play(b, anchor(b, CFrame.new(feet)), BLESS_SOUNDS.impact, 1.1)
	quake(g, feet, 0.8)
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
	-- The lotus closes into light, and a bubble of light-water sets round every ally
	local center = feet + UP * radius * 0.35
	ElementFx.burst(center, GOLD, radius / 3)
	local _, burstAll = makeDomes(view, extra, light, BLESS_SOUNDS.burst, BLESS_SOUNDS.hit)
	-- A soft rain of light over your side for a while (S: golden)
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
	task.delay(math.min(extra.seconds or 8, 6), function()
		rain.Rate = 0
		task.delay(2, function()
			clear(b)
		end)
	end)
	return function()
		burstAll()
		clear(b)
	end
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
	play(b, anchor(b, CFrame.new(target)), STAMP_SOUNDS.impact, 1.5)
	play(b, anchor(b, CFrame.new(target)), STAMP_SOUNDS.thunder, 1.2)
	if grade == "A" or grade == "S" then
		play(b, anchor(b, CFrame.new(target)), STAMP_SOUNDS.layer, 0.7)
	end
	quake(g, target, 1.1)
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

-- Eclipse (Eclipse Fox, Epic, Shade; spec "Eclipse", owner 2026-11-05): the fox holds still as a five-point star sigil
-- draws itself on the ground under it and a black moon slides over the sun; then it glows dark purple and a mirror image
-- at its side copies its every move (its hits echoed by a shadow slash) while attacks pass through it in puffs of
-- shadow, for the move's 5 s. By grade: a bigger sigil and corona, more afterimages; S: two mirror images.
local ECLIPSE = SuperFxConfig.LOOKS.Eclipse
local ECLIPSE_SOUNDS = SuperFxConfig.SOUNDS.Eclipse
local SHADOW = Color3.fromRGB(40, 24, 70)
local DUSK = Color3.fromRGB(88, 36, 160) -- the dark purple glow

-- The creatures whose mirror images are out (Eclipse), and the images
local mirrors: { [BasePart]: { Model } } = {}

-- A star sigil on the ground at `at`: two rings and an upright five-point star (one point toward `facing`), its lines
-- drawing themselves in one after another over `seconds` (0: at once), glowing points where they meet
local function starSigil(b: Bag, at: Vector3, radius: number, facing: Vector3, tint: Color3, seconds: number): { Instance }
	local made: { Instance } = {}
	local ground = groundAt(at)
	local function ring(size: number)
		local decal = groundDecal(b, ground, size, AttackFx.TEXTURES.ring, tint, math.max(0.05, seconds * 0.4))
		table.insert(made, decal)
	end
	ring(radius * 2.3)
	ring(radius * 2.05)
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local start = if flat.Magnitude > 0.01 then math.atan2(flat.Z, flat.X) else 0
	local points = {}
	for index = 0, 4 do
		local a = start + index * 2 * math.pi / 5
		points[index] = ground + UP * 0.12 + Vector3.new(math.cos(a), 0, math.sin(a)) * radius
	end
	for index = 0, 4 do
		local from, to = points[index], points[(index + 2) % 5]
		local line = part(b, Vector3.new(0.28, 0.06, 0.05), tint, CFrame.lookAt(from, to), 0.05)
		line.Material = Enum.Material.Neon
		table.insert(made, line)
		local length = (to - from).Magnitude
		local delay = seconds * 0.7 * index / 5
		local draw = math.max(0.01, seconds * 0.7 / 5)
		everyFrame(b, function(elapsed)
			local t = math.clamp((elapsed - delay) / draw, 0, 1)
			local reach = math.max(0.05, length * t)
			line.Size = Vector3.new(0.28, 0.06, reach)
			line.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -reach / 2)
		end)
		local dot = part(b, Vector3.one * 0.7, tint, CFrame.new(from), 1, Enum.PartType.Ball)
		dot.Material = Enum.Material.Neon
		table.insert(made, dot)
		task.delay(delay, function()
			if not b.done then
				tween(dot, 0.2, { Transparency = 0 })
			end
		end)
	end
	local light = Instance.new("PointLight")
	light.Color = tint
	light.Range = radius * 2.4
	light.Brightness = 2
	light.Shadows = false
	light.Parent = anchor(b, CFrame.new(ground + UP * 1))
	table.insert(made, light)
	return made
end

-- A see-through dark copy of the creature `side` studs to its right (negative: its left) that moves and poses with it
-- every frame (its bones copied over): Eclipse's mirror image
local function mirrorImage(b: Bag, view: View, side: number, tint: Color3): Model?
	local model = view.root:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	local copy = model:Clone()
	local fromBones, toBones = {}, {}
	local twins = copy:GetDescendants()
	for index, item in model:GetDescendants() do
		local twin = twins[index]
		if item:IsA("Bone") and twin and twin:IsA("Bone") and twin.Name == item.Name then
			table.insert(fromBones, item)
			table.insert(toBones, twin)
		end
	end
	for _, item in twins do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.CastShadow = false
			item.Material = Enum.Material.Neon
			item.Color = tint
			item.Transparency = 0.5
			if item:IsA("MeshPart") then
				item.TextureID = ""
			end
		elseif item:IsA("Decal") or item:IsA("Texture") or item:IsA("SurfaceAppearance") or item:IsA("Script") or item:IsA("LocalScript")
			or item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Light") or item:IsA("BillboardGui") or item:IsA("Highlight")
			or item:IsA("AnimationController") then
			item:Destroy()
		end
	end
	copy.Name = "MirrorImage"
	copy.Parent = folder()
	table.insert(b.items, copy)
	everyFrame(b, function()
		if not model.Parent then
			return
		end
		copy:PivotTo(model:GetPivot() * CFrame.new(side, 0, 0))
		for index, bone in fromBones do
			toBones[index].Transform = bone.Transform
		end
	end)
	return copy
end

-- A hit by `root`'s creature landed at `at` (Util/FightFx): its mirror images strike with it, a shadow slash each
function SuperFx.echoHit(root: BasePart, at: Vector3, scale: number)
	local images = mirrors[root]
	if not images then
		return
	end
	for index, image in images do
		if image.Parent then
			local from = image:GetPivot().Position
			ElementFx.slash(at + (from - root.Position).Unit * 0.6, from, color(ECLIPSE.color), "claw", index, scale * 0.9)
			ElementFx.burst(at, DUSK, 0.5 * scale)
		end
	end
end

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

local function eclipseCharge(view: View, grade: string, seconds: number, target: Vector3?): () -> ()
	local g = ECLIPSE.grades[grade]
	local b = bag()
	local violet = color(ECLIPSE.color)
	local source = anchor(b, CFrame.new(view.root.Position + UP * view.height))
	play(b, source, ECLIPSE_SOUNDS.call, 1)
	play(b, source, ECLIPSE_SOUNDS.charge, 0.8)
	-- It holds still (Config windupPose "still") as the star sigil draws itself under it
	local facing = if target then target - view.root.Position else view.root.CFrame.LookVector
	starSigil(b, view.root.Position, view.height * g.sigil, facing, violet, seconds)
	-- The moon slides over the sun: a pale sun high above, the black disc moving across it
	local sky = view.root.Position + UP * 30
	local sun = part(b, Vector3.one * g.corona, Color3.fromRGB(255, 236, 170), CFrame.new(sky), 0.1, Enum.PartType.Ball)
	local moon = part(b, Vector3.one * g.corona * 0.95, Color3.fromRGB(8, 4, 16), CFrame.new(sky + Vector3.new(g.corona * 1.5, 0, 0)), 0, Enum.PartType.Ball)
	moon.Material = Enum.Material.SmoothPlastic
	tween(moon, seconds, { CFrame = CFrame.new(sky - (sky - workspace.CurrentCamera.CFrame.Position).Unit * 2) }, Enum.EasingStyle.Sine)
	tween(sun, seconds, { Color = violet })
	local motes = ElementFx.emitter(anchor(b, CFrame.new(groundAt(view.root.Position) + UP * 0.3)), "spark", violet, { size = { 0.4, 0.1 }, life = { 0.8, 1.3 }, speed = { 2, 4 }, spread = 15, accel = UP * 2 })
	motes.Shape = Enum.ParticleEmitterShape.Disc
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	motes.Rate = g.particles * 0.6
	local stopGlow = ElementFx.chargeGlow(view.root, violet, seconds, 1.4 * g.scale)
	return function()
		stopGlow()
		clear(b)
	end
end

local function eclipseImpact(view: View, grade: string, target: Vector3, _targetBody: BasePart?, _targetHeight: number, extra: Extra): () -> ()
	local g = ECLIPSE.grades[grade]
	local b = bag()
	local violet = color(ECLIPSE.color)
	local seconds = extra.seconds or (SuperFx.abilityOf("Eclipse") or { seconds = 5 }).seconds
	local feet = groundAt(view.root.Position)
	play(b, anchor(b, CFrame.new(feet)), ECLIPSE_SOUNDS.impact, 1.1)
	quake(g, feet, 0.8)
	if grade == "A" or grade == "S" then
		play(b, anchor(b, CFrame.new(feet)), ECLIPSE_SOUNDS.layer, 0.9)
	end
	-- The sigil flares and fades, the eclipse hangs above, a ring of violet light bursts out
	local flare = starSigil(b, view.root.Position, view.height * g.sigil, target - view.root.Position, violet, 0)
	task.delay(0.5, function()
		for _, item in flare do
			if item:IsA("BasePart") then
				tween(item, 0.6, { Transparency = 1 })
			elseif item:IsA("Decal") then
				tween(item, 0.6, { Transparency = 1 })
			elseif item:IsA("PointLight") then
				tween(item, 0.6, { Brightness = 0 })
			end
		end
	end)
	eclipseSky(b, view.root.Position, g.corona, violet, 30)
	ElementFx.ring(feet + UP * 0.2, violet, view.height * 2 * g.scale, 0.5)
	ElementFx.burst(view.root.Position + UP * view.height * 0.5, violet, 1.6 * g.scale)
	-- It glows dark purple
	local model = view.root:FindFirstAncestorOfClass("Model")
	if model then
		local glow = Instance.new("Highlight")
		glow.FillColor = DUSK
		glow.FillTransparency = 0.45
		glow.OutlineColor = Color3.fromRGB(196, 160, 255)
		glow.OutlineTransparency = 0.15
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Adornee = model
		glow.Parent = folder()
		table.insert(b.items, glow)
	end
	local aura = Instance.new("PointLight")
	aura.Color = DUSK
	aura.Range = view.height * 2.5
	aura.Brightness = 2.5
	aura.Shadows = false
	aura.Parent = view.root
	table.insert(b.items, aura)
	local haze = ElementFx.emitter(view.root, "smoke", SHADOW, { size = { view.height * 0.4, view.height * 0.7 }, life = { 0.4, 0.7 }, speed = { 0.5, 1.5 }, spread = 180, light = 0 })
	haze.Rate = g.particles * 0.4
	table.insert(b.items, haze)
	-- Its mirror image (S: one each side), copying its every move; afterimages trail it as it darts
	local images = {}
	for index = 1, g.mirrors do
		local side = view.height * 1.1 * (if index == 1 then -1 else 1)
		local image = mirrorImage(b, view, side, DUSK)
		if image then
			table.insert(images, image)
			ElementFx.burst(image:GetPivot().Position, violet, 1)
		end
	end
	mirrors[view.root] = images
	-- Afterimages trail it as it darts, one copy every 0.15 s at most (each is a whole copy of its model: a dash cloned
	-- one a frame and hitched the frame in Studio)
	local last, lastAt = view.root.Position, 0
	everyFrame(b, function(elapsed)
		local now = view.root.Position
		if (now - last).Magnitude > 2 and elapsed - lastAt >= 0.15 then
			afterimages(b, view, last, now, 1, violet, 0.4)
			last, lastAt = now, elapsed
		end
	end)
	local drone = play(b, anchor(b, CFrame.new(feet)), ECLIPSE_SOUNDS.linger, 0.6, true)
	-- Attacks pass through it in a puff of shadow
	dodgers[view.root] = function(at: Vector3)
		ElementFx.emitter(anchor(b, CFrame.new(at)), "smoke", SHADOW, { size = { 2, 4 }, life = 0.5, speed = { 3, 6 }, spread = 180, light = 0 }):Emit(10)
	end
	local function done()
		if mirrors[view.root] == images then
			mirrors[view.root] = nil
		end
		if dodgers[view.root] then
			dodgers[view.root] = nil
		end
	end
	task.delay(seconds, function()
		done()
		haze.Rate = 0
		for _, image in images do
			for _, item in image:GetDescendants() do
				if item:IsA("BasePart") then
					tween(item, 0.5, { Transparency = 1 })
				end
			end
		end
		if drone then
			tween(drone, 0.4, { Volume = 0 })
		end
		task.delay(0.8, function()
			clear(b)
		end)
	end)
	return function()
		done()
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
	quake(g, center, 0.8)
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

-- Supernova (Solarion, Legendary, Ember; spec "Supernova"): Solarion rises glowing as a small sun grows over its hands,
-- pulling light and sparks in, then hurls it down: a white-out and a dome of fire, shockwave rings, rays of light and
-- heat shimmer over the crater (the deep space and the impact frame are on the caster's screen). By grade: a bigger
-- sun, more rings and rays; S: two impact frames and pillars of light round the crater.
local NOVA = SuperFxConfig.LOOKS.Supernova
local NOVA_SOUNDS = SuperFxConfig.SOUNDS.Supernova
local SUN_CORE = Color3.fromRGB(255, 250, 220)

-- A small sun: a white-hot core in a golden corona with a light
local function sunBall(b: Bag, at: Vector3, size: number, tint: Color3): (Part, Part)
	local corona = part(b, Vector3.one * size * 1.6, tint, CFrame.new(at), 0.45, Enum.PartType.Ball)
	local core = part(b, Vector3.one * size, SUN_CORE, CFrame.new(at), 0, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = tint
	light.Range = size * 6
	light.Brightness = 5
	light.Parent = core
	local flare = ElementFx.emitter(core, "flare", tint, { size = { size * 2, size * 3 }, life = 0.4, fade = 0.3, locked = true, spin = { 60, 120 }, brightness = 2 })
	flare.Rate = 6
	return core, corona
end

-- Where the sun bursts: high over the boss (owner 2026-11-05: "make the ball rise then explode"); the caster's
-- cinematic frames the same point (Util/SuperCinematic)
local function novaSky(target: Vector3, g: any): Vector3
	return target + UP * g.burst
end

local function novaCharge(view: View, grade: string, seconds: number, target: Vector3?): () -> ()
	local g = NOVA.grades[grade]
	local b = bag()
	local gold = color(NOVA.color)
	local above = view.root.Position + UP * (view.height * 1.35 + 2)
	local sky = novaSky(target or (view.root.Position + view.root.CFrame.LookVector * 14), g)
	play(b, anchor(b, CFrame.new(above)), NOVA_SOUNDS.call, 1)
	play(b, anchor(b, CFrame.new(above)), NOVA_SOUNDS.charge, 0.9)
	-- It grows over its hands (the first 60%), then rises high over the boss, trailing light
	local core, corona = sunBall(b, above, 0.5, gold)
	local grow = seconds * 0.6
	tween(core, grow, { Size = Vector3.one * g.sun })
	tween(corona, grow, { Size = Vector3.one * g.sun * 1.6 })
	task.delay(grow, function()
		if b.done then
			return
		end
		local rise = TweenInfo.new(seconds - grow, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(core, rise, { CFrame = CFrame.new(sky), Size = Vector3.one * g.sun * 1.4 }):Play()
		TweenService:Create(corona, rise, { CFrame = CFrame.new(sky), Size = Vector3.one * g.sun * 2.3 }):Play()
		local trail = ElementFx.emitter(core, "spark", gold, { size = { 0.8, 0.1 }, life = 0.5, speed = 0, fade = 0.3 })
		trail.Rate = 60
	end)
	local stopGather = ElementFx.gather(above, gold, grow, g.sun * 3)
	local stopGlow = ElementFx.chargeGlow(view.root, gold, seconds, 1.8 * g.scale)
	return function()
		stopGather()
		stopGlow()
		clear(b)
	end
end

local function novaImpact(_view: View, grade: string, target: Vector3, _targetBody: BasePart?, targetHeight: number): () -> ()
	local g = NOVA.grades[grade]
	local b = bag()
	local gold = color(NOVA.color)
	local fire = Color3.fromRGB(255, 120, 40)
	local ground = groundAt(target)
	local blast = math.max(8, targetHeight * 1.1) * g.scale
	local sky = novaSky(target, g)
	-- The risen sun explodes in the sky: a white-out burst up there and fire raining down onto the boss
	local flash = part(b, Vector3.one * g.sun * 1.4, SUN_CORE, CFrame.new(sky), 0, Enum.PartType.Ball)
	tween(flash, 0.3, { Size = Vector3.one * g.sun * 7, Transparency = 1 }, Enum.EasingStyle.Quart)
	ElementFx.burst(sky, gold, 4 * g.scale)
	ElementFx.ring(sky, gold, g.sun * 5, 0.5)
	quake(g, target, 1.6)
	for index = 1, math.floor(6 + 4 * g.scale) do
		local a = index / (6 + 4 * g.scale) * 2 * math.pi
		local spot = ground + Vector3.new(math.cos(a), 0, math.sin(a)) * blast * 0.5 * math.random()
		ElementFx.projectile(sky, function()
			return spot
		end, gold, 0.18 + math.random() * 0.12, 0, function(at)
			ElementFx.burst(at, fire, 0.8 * g.scale)
		end, { scale = 1.1, flames = true })
	end
	task.delay(0.22, function()
		if b.done then
			return
		end
		quake(g, ground, 1.2)
		play(b, anchor(b, CFrame.new(target)), NOVA_SOUNDS.impact, 1.3)
		if grade == "A" or grade == "S" then
			play(b, anchor(b, CFrame.new(target)), NOVA_SOUNDS.layer, 1.1)
		end
		-- The white-out and the dome of fire
		local dome = part(b, Vector3.one * 2, SUN_CORE, CFrame.new(ground), 0, Enum.PartType.Ball)
		tween(dome, 0.35, { Size = Vector3.one * blast * 2, Color = fire }, Enum.EasingStyle.Quart)
		task.delay(0.35, function()
			tween(dome, 0.6, { Transparency = 1 })
		end)
		ElementFx.burst(target, gold, 3 * g.scale)
		ElementFx.eruption(ground, fire, blast * 0.8, 14)
		-- Shockwave rings, one after another
		for ring = 1, g.rings do
			task.delay((ring - 1) * 0.18, function()
				ElementFx.ring(ground + UP * 0.2, gold, blast * (1 + ring * 0.35), 0.6)
			end)
		end
		-- Rays of light up out of the crater, heat shimmer, a scorched crater
		for index = 1, g.rays do
			local a = index / g.rays * 2 * math.pi + math.random() * 0.3
			local top = anchor(b, CFrame.new(ground + Vector3.new(math.cos(a), 0, math.sin(a)) * blast * 0.6 + UP * (20 + 10 * g.scale)))
			local foot = anchor(b, CFrame.new(ground))
			local ray = beam(attachment(foot, Vector3.zero), attachment(top, Vector3.zero), AttackFx.TEXTURES.streak, sequence(SUN_CORE, gold), 2.5 * g.scale, 0.6, { speed = 2, length = 12 })
			task.delay(1.6, function()
				tween(ray, 0.8, { Width0 = 0, Width1 = 0 })
			end)
		end
		local shimmer = ElementFx.emitter(anchor(b, CFrame.new(ground + UP)), "smoke", fire, { size = { blast * 0.4, blast * 0.7 }, life = { 0.8, 1.4 }, speed = { 2, 5 }, spread = 60, accel = UP * 3, light = 0.4 })
		shimmer.Rate = g.particles * 0.4
		groundDecal(b, ground, blast * 2, TEX.crack, fire, 0.2)
		local rumble = play(b, anchor(b, CFrame.new(ground)), NOVA_SOUNDS.linger, 0.9)
		-- S: pillars of light round the crater
		if g.extra then
			for index = 1, 6 do
				local a = index / 6 * 2 * math.pi
				ElementFx.pillar(ground + Vector3.new(math.cos(a), 0, math.sin(a)) * blast * 1.1, gold, 24, 1.6, "glow")
			end
		end
		task.delay(2.6, function()
			shimmer.Rate = 0
			if rumble then
				tween(rumble, 0.6, { Volume = 0 })
			end
			task.delay(1, function()
				clear(b)
			end)
		end)
	end)
	return function()
		clear(b)
	end
end

-- Thunderstorm (Stormking, Legendary, Volt, Frontier; spec "Thunderstorm"): storm clouds swirl in above the boss and
-- lightning crawls across them as Stormking raises its horns, then a colossal bolt and forked strikes hit the boss;
-- rain and sparks crawling over the ground as the thunder rolls away (the storm sky is on the caster's screen). By
-- grade: more forks, a wider storm; S: three bolts and a chain of lightning round the arena.
local STORM = SuperFxConfig.LOOKS.Thunderstorm
local STORM_SOUNDS = SuperFxConfig.SOUNDS.Thunderstorm
local CLOUD = Color3.fromRGB(70, 78, 96)

-- Storm clouds circling `height` studs over `at`, `radius` wide; returns the cloud puffs
local function stormClouds(b: Bag, at: Vector3, radius: number, height: number): { Part }
	local puffs = {}
	for index = 1, 14 do
		local a = index / 14 * 2 * math.pi
		local reach = radius * (0.4 + math.random() * 0.6)
		local puff = part(b, Vector3.new(9, 4, 8) * (0.8 + math.random() * 0.6), CLOUD, CFrame.new(at + UP * height + Vector3.new(math.cos(a), 0, math.sin(a)) * reach), 0.25, Enum.PartType.Ball)
		puff.Material = Enum.Material.SmoothPlastic
		table.insert(puffs, puff)
	end
	local holder = at + UP * height
	everyFrame(b, function(_, dt)
		for _, puff in puffs do
			local offset = puff.Position - holder
			local turned = CFrame.Angles(0, math.rad(25) * dt, 0) * offset
			puff.CFrame = CFrame.new(holder + turned)
		end
	end)
	return puffs
end

local function stormCharge(view: View, grade: string, seconds: number, target: Vector3?): () -> ()
	local g = STORM.grades[grade]
	local b = bag()
	local volt = color(STORM.color)
	local over = target or (view.root.Position + view.root.CFrame.LookVector * 12)
	play(b, anchor(b, CFrame.new(over + UP * 20)), STORM_SOUNDS.call, 1)
	play(b, anchor(b, CFrame.new(over + UP * 20)), STORM_SOUNDS.charge, 0.8)
	local puffs = stormClouds(b, over, g.storm * 0.5, 26)
	everyFrame(b, function(elapsed)
		if math.floor(elapsed * 5) ~= math.floor((elapsed - 1 / 60) * 5) and #puffs > 1 then
			local a, c = puffs[math.random(#puffs)], puffs[math.random(#puffs)]
			if a ~= c then
				ElementFx.bolt(a.Position, c.Position, volt, 0.12, 0.8 * g.scale)
			end
		end
	end)
	local horns = ElementFx.emitter(anchor(b, CFrame.new(view.root.Position + UP * view.height)), "spark", volt, { size = { 0.6, 0.1 }, life = 0.3, speed = { 8, 14 }, spread = 180 })
	horns.Rate = g.particles
	local stopGlow = ElementFx.chargeGlow(view.root, volt, seconds, 1.6 * g.scale)
	return function()
		stopGlow()
		clear(b)
	end
end

local function stormImpact(view: View, grade: string, target: Vector3, _targetBody: BasePart?, targetHeight: number): () -> ()
	local g = STORM.grades[grade]
	local b = bag()
	local volt = color(STORM.color)
	local ground = groundAt(target)
	local sky = ground + UP * 26
	stormClouds(b, ground, g.storm * 0.5, 26)
	play(b, anchor(b, CFrame.new(target)), STORM_SOUNDS.impact, 1.3)
	if grade == "A" or grade == "S" then
		play(b, anchor(b, CFrame.new(target)), STORM_SOUNDS.layer, 1)
	end
	-- The colossal bolt and its forks
	for strike = 1, g.bolts do
		task.delay((strike - 1) * 0.22, function()
			if b.done then
				return
			end
			ElementFx.skyStrike(target, volt, 2.2 * g.scale)
			quake(g, target, 1.2)
			local column = anchor(b, CFrame.new(sky))
			local foot = anchor(b, CFrame.new(ground))
			local bolt = beam(attachment(column, Vector3.zero), attachment(foot, Vector3.zero), AttackFx.TEXTURES.bolt, sequence(WHITE, volt), 4 * g.scale, 2.5 * g.scale, { speed = 8, length = 10, brightness = 4, faceCamera = true })
			tween(bolt, 0.35, { Width0 = 0, Width1 = 0 })
			for _ = 1, g.forks do
				local a = math.random() * 2 * math.pi
				local spot = ground + Vector3.new(math.cos(a), 0, math.sin(a)) * math.max(4, targetHeight * 0.6) * (0.5 + math.random())
				ElementFx.bolt(sky + Vector3.new(math.cos(a), 0, math.sin(a)) * 4, spot, volt, 0.2, 1.2 * g.scale)
			end
			ElementFx.burst(target, volt, 2 * g.scale)
			ElementFx.ring(ground + UP * 0.2, volt, math.max(6, targetHeight * 0.8) * g.scale, 0.45)
		end)
	end
	-- The rain, sparks crawling over the ground
	local rain = ElementFx.emitter(anchor(b, CFrame.new(sky - UP * 2)), "streak", Color3.fromRGB(190, 210, 235), {
		size = { 0.25, 0.25 },
		life = { 0.8, 1 },
		speed = { 28, 34 },
		direction = Enum.NormalId.Bottom,
		orientation = Enum.ParticleOrientation.VelocityParallel,
		light = 0.3,
	})
	rain.Shape = Enum.ParticleEmitterShape.Disc
	rain.Rate = g.particles * 2
	local crawl = ElementFx.emitter(anchor(b, CFrame.new(ground + UP * 0.3)), "spark", volt, { size = { 0.5, 0.1 }, life = 0.3, speed = { 4, 8 }, spread = 80 })
	crawl.Shape = Enum.ParticleEmitterShape.Disc
	crawl.Rate = g.particles
	local drizzle = play(b, anchor(b, CFrame.new(ground + UP * 6)), STORM_SOUNDS.linger, 0.6, true)
	-- S: a chain of lightning round the arena
	if g.extra then
		local ring = {}
		for index = 1, 10 do
			local a = index / 10 * 2 * math.pi
			table.insert(ring, ground + Vector3.new(math.cos(a), 0.5, math.sin(a)) * g.storm * 0.7)
		end
		for index = 1, #ring do
			task.delay(0.6 + index * 0.05, function()
				ElementFx.bolt(ring[index], ring[index % #ring + 1], volt, 0.3, 1.2)
			end)
		end
	end
	task.delay(3.5, function()
		rain.Rate = 0
		crawl.Rate = 0
		if drizzle then
			tween(drizzle, 1, { Volume = 0 })
		end
		task.delay(1.2, function()
			clear(b)
		end)
	end)
	return function()
		clear(b)
	end
end

-- Devour (Voidmaw, Legendary, Shade; spec "Devour"): the world dims and Voidmaw's eyes burn violet as a black hole opens
-- behind the boss pulling everything in, then giant spectral jaws rise from the ground and clamp shut, and streams of
-- life flow from the boss into Voidmaw (its heal). By grade: a bigger black hole, more life streams; S: the jaws bite
-- twice.
local DEVOUR = SuperFxConfig.LOOKS.Devour
local DEVOUR_SOUNDS = SuperFxConfig.SOUNDS.Devour
local VOID = Color3.fromRGB(14, 6, 26)

-- The black hole behind `at` (away from `from`): a dark disc in a turning violet swirl, `size` studs
local function blackHole(b: Bag, at: Vector3, from: Vector3, size: number, tint: Color3): Part
	local away = Vector3.new(at.X - from.X, 0, at.Z - from.Z)
	local spot = at + (if away.Magnitude > 0.5 then away.Unit else Vector3.new(0, 0, 1)) * size * 0.7 + UP * size * 0.4
	local swirl = part(b, Vector3.new(size * 2.2, size * 2.2, 0.1), WHITE, CFrame.lookAt(spot, from + UP * size * 0.4), 1)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local decal = Instance.new("Decal")
		decal.Texture = TEX.swirl
		decal.Color3 = tint
		decal.Face = face
		decal.Parent = swirl
	end
	local hole = part(b, Vector3.one * size * 0.75, VOID, CFrame.new(spot), 0, Enum.PartType.Ball)
	hole.Material = Enum.Material.SmoothPlastic
	everyFrame(b, function(_, dt)
		swirl.CFrame = swirl.CFrame * CFrame.Angles(0, 0, math.rad(-120) * dt)
	end)
	swirl.Size = Vector3.new(0.5, 0.5, 0.1)
	tween(swirl, 0.5, { Size = Vector3.new(size * 2.2, size * 2.2, 0.1) }, Enum.EasingStyle.Back)
	return hole
end

-- Spectral jaws round `at`: two rows of fangs rising from the ground either side, clamping shut; `bites` times
local function jaws(b: Bag, at: Vector3, width: number, tint: Color3, bites: number)
	for bite = 1, bites do
		task.delay((bite - 1) * 0.42, function()
			if b.done then
				return
			end
			for _, side in { -1, 1 } do
				local base = at + Vector3.new(0, -width * 0.6, 0)
				local jaw = part(b, Vector3.new(width * 1.6, width * 0.35, width * 0.5), tint, CFrame.new(base + Vector3.new(0, 0, side * width * 0.9)), 0.3)
				for fang = 1, 5 do
					local tooth = part(b, Vector3.new(width * 0.18, width * 0.5, width * 0.18), Color3.fromRGB(235, 220, 255), jaw.CFrame * CFrame.new((fang - 3) * width * 0.3, width * 0.4, -side * width * 0.15), 0.2, Enum.PartType.Wedge)
					local weld = Instance.new("WeldConstraint")
					weld.Part0, weld.Part1 = jaw, tooth
					weld.Parent = tooth
					tooth.Anchored = false
				end
				TweenService:Create(jaw, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = CFrame.new(at + Vector3.new(0, 0, side * width * 0.25)) * CFrame.Angles(side * math.rad(25), 0, 0) }):Play()
				task.delay(0.32, function()
					tween(jaw, 0.25, { Transparency = 1 })
					for _, child in jaw:GetConnectedParts() do
						tween(child, 0.25, { Transparency = 1 })
					end
				end)
			end
			ElementFx.burst(at, tint, width / 3)
		end)
	end
end

local function devourCharge(view: View, grade: string, seconds: number, target: Vector3?): () -> ()
	local g = DEVOUR.grades[grade]
	local b = bag()
	local violet = color(DEVOUR.color)
	local foe = target or (view.root.Position + view.root.CFrame.LookVector * 12)
	play(b, anchor(b, CFrame.new(view.root.Position)), DEVOUR_SOUNDS.call, 0.9)
	play(b, anchor(b, CFrame.new(foe)), DEVOUR_SOUNDS.charge, 1)
	local hole = blackHole(b, foe, view.root.Position, g.hole, violet)
	local stopGather = ElementFx.gather(hole.Position, violet, seconds, g.hole * 2)
	-- Its eyes burn violet
	local eyes = ElementFx.emitter(anchor(b, CFrame.new(view.root.Position + UP * view.height * 0.8 + view.root.CFrame.LookVector * view.height * 0.3)), "glow", violet, { size = { 1.2 * g.scale, 1.8 * g.scale }, life = 0.3, fade = 0.3, locked = true, brightness = 3 })
	eyes.Rate = 10
	local stopGlow = ElementFx.chargeGlow(view.root, violet, seconds, 1.6 * g.scale)
	return function()
		stopGather()
		stopGlow()
		clear(b)
	end
end

local function devourImpact(view: View, grade: string, target: Vector3, _targetBody: BasePart?, targetHeight: number): () -> ()
	local g = DEVOUR.grades[grade]
	local b = bag()
	local violet = color(DEVOUR.color)
	local width = math.max(5, targetHeight * 0.7)
	blackHole(b, target, view.root.Position, g.hole, violet)
	play(b, anchor(b, CFrame.new(target)), DEVOUR_SOUNDS.impact, 1.3)
	quake(g, target, 0.8)
	if grade == "A" or grade == "S" then
		play(b, anchor(b, CFrame.new(target)), DEVOUR_SOUNDS.layer, 1)
	end
	jaws(b, target, width, violet, g.bites)
	-- Life flowing back from the boss into Voidmaw
	task.delay(0.35, function()
		if b.done then
			return
		end
		local mouth = view.root.Position + UP * view.height * 0.6
		for index = 1, g.streams do
			local from = anchor(b, CFrame.new(target + Vector3.new(math.random() - 0.5, math.random(), math.random() - 0.5) * width * 0.6))
			local to = anchor(b, CFrame.new(mouth))
			local stream = beam(attachment(from, Vector3.zero), attachment(to, Vector3.zero), AttackFx.TEXTURES.streak, sequence(Color3.fromRGB(170, 255, 190), violet), 0.8 * g.scale, 0.4, {
				speed = 5,
				length = 4,
				curve0 = (index % 2 * 2 - 1) * 6,
				curve1 = (index % 3 - 1) * 4,
			})
			task.delay(1.6, function()
				tween(stream, 0.4, { Width0 = 0, Width1 = 0 })
			end)
		end
		ElementFx.burst(mouth, Color3.fromRGB(170, 255, 190), 1.2 * g.scale)
	end)
	local drone = play(b, anchor(b, CFrame.new(target)), DEVOUR_SOUNDS.linger, 0.6, true)
	task.delay(2.4, function()
		if drone then
			tween(drone, 0.6, { Volume = 0 })
		end
		task.delay(0.8, function()
			clear(b)
		end)
	end)
	return function()
		clear(b)
	end
end

-- The ten looks (spec "The ten moves"), by look id (tests/SuperFx: every super has one in Config/SuperFx)
local LOOKS: { [string]: Look } = {
	Inferno = { charge = infernoCharge, impact = infernoImpact },
	MagmaSlam = { charge = magmaCharge, impact = magmaImpact },
	TidalShield = { charge = tideCharge, impact = tideImpact },
	TidalBlessing = { charge = blessCharge, impact = blessImpact },
	Stampede = { charge = stampCharge, impact = stampImpact },
	Eclipse = { charge = eclipseCharge, impact = eclipseImpact },
	RiftStep = { charge = riftCharge, impact = riftImpact },
	Supernova = { charge = novaCharge, impact = novaImpact },
	Thunderstorm = { charge = stormCharge, impact = stormImpact },
	Devour = { charge = devourCharge, impact = devourImpact },
}

-- Everything from the press to the impact on the caster; returns a stop
function SuperFx.charge(lookId: string, view: View, grade: string, seconds: number, target: Vector3?): () -> ()
	local own = LOOKS[lookId]
	if not own then
		warn(`[SuperFx] no look for {lookId}`)
		return nothing
	end
	return own.charge(view, grade, seconds, target)
end

-- The impact and what lingers on the field for the move's seconds; returns a stop
function SuperFx.impact(lookId: string, view: View, grade: string, target: Vector3, targetBody: BasePart?, targetHeight: number, extra: Extra?): () -> ()
	local own = LOOKS[lookId]
	if not own then
		warn(`[SuperFx] no look for {lookId}`)
		return nothing
	end
	return own.impact(view, grade, target, targetBody, targetHeight, extra or {})
end

return SuperFx
