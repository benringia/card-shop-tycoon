--!strict
-- The pieces fight effects are built from (Util/FightFx, Config/AttackFx), in the owner's reference look (spec
-- 2026-11-02-attack-animations-design "Quality bar"): textured light (AttackFx.TEXTURES, white, tinted here) drawn as
-- a coloured layer under a white-hot core. A charge glow with sparks pulling in, a comet with its trail, an impact
-- (starburst, shockwave ring, flash, sparks), lightning beams, crescent slashes, crystal shards erupting from the
-- ground, fire and water pillars, and a positional sound. `scale` sizes most of them (a creature's grade, Util/FightFx).
-- Everything sits in workspace.FightFx and cleans itself up; with the low-graphics switch off, fewer particles.
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AttackFx"))
local Extras = require((script.Parent :: Instance):WaitForChild("Extras"))
local SoundBank = require((script.Parent :: Instance):WaitForChild("SoundBank"))

local ElementFx = {}

local TEX = AttackFx.TEXTURES
local WHITE = Color3.new(1, 1, 1)
local CORE = 0.45 -- a white core's size against its coloured layer
local DUST = Color3.fromRGB(160, 138, 108)
local ROOT = Color3.fromRGB(78, 54, 34)
local MOSS = Color3.fromRGB(96, 170, 64)
local WEB = Color3.fromRGB(236, 232, 245)
local MOLTEN = Color3.fromRGB(255, 196, 64)
local CRACK = Color3.fromRGB(255, 72, 18)
local GOLD = Color3.fromRGB(255, 215, 106)

local function folder(): Folder
	local existing = workspace:FindFirstChild("FightFx")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "FightFx"
	made.Parent = workspace
	return made
end

local function part(size: Vector3, color: Color3, at: Vector3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = CFrame.new(at)
	p.Parent = folder()
	return p
end

-- An invisible anchor for emitters, beams and lights, removed after `life`
local function holder(at: Vector3, life: number): Part
	local p = part(Vector3.new(0.2, 0.2, 0.2), WHITE, at)
	p.Transparency = 1
	Debris:AddItem(p, life)
	return p
end

-- Fewer particles with the low-graphics switch off
local function detail(count: number): number
	return math.max(1, math.round(if Extras.enabled() then count else count * 0.45))
end

local function range(value: any): NumberRange
	if typeof(value) == "number" then
		return NumberRange.new(value)
	end
	return NumberRange.new(math.min(value[1], value[2]), math.max(value[1], value[2]))
end

-- An emitter of one texture, ready to Emit. o: size {from, to} (studs), life, speed, spread, rotation, spin,
-- orientation, accel, drag, brightness, fade (when it starts fading, 0-1), locked, light (LightEmission), squash,
-- direction, zOffset
local function emitter(parent: Instance, texture: string, color: Color3, o: any): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX[texture]
	e.Color = ColorSequence.new(color)
	e.LightEmission = o.light or 1
	e.LightInfluence = 0
	e.Brightness = o.brightness or 1.5
	local size = o.size or { 1, 1 }
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size[1]), NumberSequenceKeypoint.new(1, size[2]) })
	local fade = o.fade or 0.4
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, o.start or 0),
		NumberSequenceKeypoint.new(fade, o.start or 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = range(o.life or 0.4)
	e.Speed = range(o.speed or 0)
	e.SpreadAngle = Vector2.new(o.spread or 0, o.spread or 0)
	e.Rotation = range(o.rotation or { 0, 360 })
	e.RotSpeed = range(o.spin or 0)
	e.Orientation = o.orientation or Enum.ParticleOrientation.FacingCamera
	e.Acceleration = o.accel or Vector3.zero
	e.Drag = o.drag or 0
	e.LockedToPart = o.locked == true
	e.EmissionDirection = o.direction or Enum.NormalId.Top
	e.ZOffset = o.zOffset or 0
	if o.squash then
		e.Squash = NumberSequence.new(o.squash)
	end
	e.Rate = 0
	e.Parent = parent
	return e
end

-- One sprite at `at`: `texture` growing from `from` to `to` studs over `life`, a coloured layer and a white core
local function flashSprite(at: Vector3, texture: string, color: Color3, from: number, to: number, life: number, o: any?)
	local opts = o or {}
	local anchor = holder(at, life + 0.3)
	local base = table.clone(opts)
	base.size = { from, to }
	base.life = life
	emitter(anchor, texture, color, base):Emit(1)
	if opts.core ~= false then
		local core = table.clone(base)
		core.size = { from * CORE, to * CORE }
		core.brightness = 2.2
		emitter(anchor, texture, WHITE, core):Emit(1)
	end
end

-- A flat ring on the ground at `center` spreading out to `radius` over `seconds`
local function shockwave(center: Vector3, color: Color3, radius: number, seconds: number)
	local anchor = holder(center + Vector3.new(0, 0.3, 0), seconds + 0.3)
	local flat = { size = { 1, radius * 2 }, life = seconds, speed = 0.01, orientation = Enum.ParticleOrientation.VelocityPerpendicular, rotation = 0, fade = 0.2 }
	emitter(anchor, "ring", color, flat):Emit(1)
	local inner = table.clone(flat)
	inner.size = { 0.6, radius * 1.4 }
	inner.life = seconds * 0.7
	inner.brightness = 2.2
	emitter(anchor, "ring", WHITE, inner):Emit(1)
end

-- Sparks flying out of `at`
local function sparks(at: Vector3, color: Color3, count: number, speed: number, size: number, gravity: number?)
	local anchor = holder(at, 1.2)
	emitter(anchor, "spark", color, {
		size = { size, size * 0.4 },
		life = { 0.35, 0.75 },
		speed = { speed * 0.5, speed },
		spread = 180,
		rotation = 0,
		orientation = Enum.ParticleOrientation.VelocityParallel,
		accel = Vector3.new(0, -(gravity or 30), 0),
		drag = 2,
		brightness = 2.2,
		fade = 0.5,
	}):Emit(detail(count))
end

-- A random point on the ground within `radius` of `center`
local function scatter(center: Vector3, radius: number): Vector3
	local angle = math.random() * math.pi * 2
	local distance = radius * math.sqrt(math.random())
	return center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function light(parent: Instance, color: Color3, rangeStuds: number, brightness: number, seconds: number)
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = rangeStuds
	glow.Brightness = brightness
	glow.Shadows = false
	glow.Parent = parent
	TweenService:Create(glow, TweenInfo.new(seconds), { Brightness = 0 }):Play()
end

-- A positional sound at `at` (a slightly random pitch, so repeats don't drone), removed once played
-- A particle emitter with one of the attack textures (AttackFx.TEXTURES), for effects built elsewhere (Util/DebuffFx).
-- Rate 0: set a rate or Emit
function ElementFx.emitter(parent: Instance, texture: string, color: Color3, o: any): ParticleEmitter
	return emitter(parent, texture, color, o)
end

function ElementFx.sound(id: string?, at: Vector3, volume: number?)
	if not id or id == "" then
		return
	end
	local anchor = holder(at, 4)
	local sound = SoundBank.make(id) -- loaded already (a fresh Sound of a dropped id started late or not at all)
	-- A little different every time (pitch and loudness), so repeated hits don't sound like one clip on a loop
	local vary = AttackFx.VARY
	sound.Volume = AttackFx.VOLUME * (volume or 1) * (vary.volume[1] + math.random() * (vary.volume[2] - vary.volume[1]))
	sound.PlaybackSpeed = vary.pitch[1] + math.random() * (vary.pitch[2] - vary.pitch[1])
	sound.RollOffMaxDistance = 140
	sound.Parent = anchor
	sound:Play()
end

-- A glow building on `root` over `seconds`, a flare spinning in it and sparks pulling in from round it; returns a
-- stop (also stops by itself)
function ElementFx.chargeGlow(root: BasePart, color: Color3, seconds: number, scale: number?): () -> ()
	local s = scale or 1
	local life = math.max(seconds, 0.05) + 0.15
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	emitter(attachment, "glow", color, { size = { 0.6 * s, 4 * s }, life = life, locked = true, fade = 0.85, rotation = 0 }):Emit(1)
	emitter(attachment, "glow", WHITE, { size = { 0.3 * s, 1.6 * s }, life = life, locked = true, fade = 0.85, rotation = 0, brightness = 2.2 }):Emit(1)
	emitter(attachment, "flare", WHITE, { size = { 0.6 * s, 3 * s }, life = life, locked = true, fade = 0.8, spin = { 140, 200 }, brightness = 2.2 }):Emit(1)
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 10 * s
	glow.Brightness = 0
	glow.Parent = attachment
	TweenService:Create(glow, TweenInfo.new(math.max(seconds, 0.05)), { Brightness = AttackFx.CHARGE_LIGHT }):Play()
	-- Sparks from a ball round it, flying in (a negative speed from the ball's surface)
	local shell = part(Vector3.one * 6 * s, color, root.Position)
	shell.Shape = Enum.PartType.Ball
	shell.Transparency = 1
	local pull = emitter(shell, "spark", color, {
		size = { 0.9 * s, 0.3 * s },
		life = 0.3,
		speed = { -10 * s, -12 * s },
		rotation = 0,
		orientation = Enum.ParticleOrientation.VelocityParallel,
		brightness = 2.2,
	})
	pull.Shape = Enum.ParticleEmitterShape.Sphere
	pull.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pull.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	pull.Rate = detail(45 * s)
	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		attachment:Destroy()
		shell:Destroy()
	end
	task.delay(seconds + 0.25, stop)
	return stop
end

-- An impact at `at`: a starburst, a shockwave ring, a glow and a flash of light, sparks flying out
function ElementFx.burst(at: Vector3, color: Color3, scale: number?)
	local s = scale or 1
	flashSprite(at, "impact", color, 2.5 * s, 7 * s, 0.28)
	flashSprite(at, "ring", color, 1 * s, 12 * s, 0.42, { rotation = 0, fade = 0.2 })
	flashSprite(at, "glow", color, 3 * s, 8 * s, 0.32, { start = 0.2, core = false })
	sparks(at, color, 24 * s, 34 * math.sqrt(s), 1.3 * s)
	light(holder(at, 0.6), color, 12 * s, 2.5, 0.35)
end

-- A comet from `from` to wherever `target()` is, rising `arc` studs at its middle, taking `seconds`; then
-- `onArrive(position)`. o: scale, flames (fire licking off it), rings (water rings spiralling round it, how many
-- layers), sparkle (gold sparkles: a grade S trail)
function ElementFx.projectile(from: Vector3, target: () -> Vector3, color: Color3, seconds: number, arc: number, onArrive: (Vector3) -> (), o: any?)
	local opts = o or {}
	local s = opts.scale or 1
	-- A small white-hot core: the comet reads as one even before its glow textures are in
	local ball = part(Vector3.one * 0.55 * s, color:Lerp(WHITE, 0.7), from)
	ball.Shape = Enum.PartType.Ball
	ball.Transparency = 0.15
	local emitters: { ParticleEmitter } = {}
	local function keep(e: ParticleEmitter, rate: number)
		e.Rate = detail(rate)
		table.insert(emitters, e)
	end
	keep(emitter(ball, "glow", color, { size = { 2.6 * s, 1.4 * s }, life = 0.1, locked = true, rotation = 0, fade = 0.3 }), 90)
	keep(emitter(ball, "glow", WHITE, { size = { 1.1 * s, 0.6 * s }, life = 0.08, locked = true, rotation = 0, brightness = 2.2 }), 90)
	keep(emitter(ball, "spark", color, { size = { 0.8 * s, 0.2 * s }, life = { 0.2, 0.4 }, speed = { 1, 4 }, spread = 180, rotation = 0, orientation = Enum.ParticleOrientation.VelocityParallel, brightness = 2.2 }), 45 * s)
	if opts.flames then
		keep(emitter(ball, "flame", color, { size = { 1.8 * s, 0.2 * s }, life = { 0.25, 0.4 }, speed = { 1, 3 }, spread = 40, rotation = { -20, 20 }, accel = Vector3.new(0, 10, 0) }), 55)
	end
	for layer = 1, opts.rings or 0 do
		keep(emitter(ball, "ring", if layer == 1 then color else color:Lerp(WHITE, 0.5), {
			size = { 1.6 * s * (1 + (layer - 1) * 0.4), 2.6 * s * (1 + (layer - 1) * 0.4) },
			life = 0.3,
			speed = 0.5,
			rotation = 0,
			orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			direction = Enum.NormalId.Back,
			fade = 0.3,
		}), 20)
	end
	if opts.sparkle then
		keep(emitter(ball, "flare", GOLD, { size = { 0.9 * s, 0.2 }, life = 0.45, speed = { 1, 3 }, spread = 180, spin = { -200, 200 }, brightness = 2.2 }), 30)
	end
	-- A glowing ribbon behind it
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.55 * s, 0)
	a1.Position = Vector3.new(0, -0.55 * s, 0)
	a0.Parent, a1.Parent = ball, ball
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(WHITE, color)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Lifetime = 0.2
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = ball
	light(ball, color, 10 * s, 2, seconds + 0.2)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = if seconds <= 0 then 1 else math.clamp((os.clock() - started) / seconds, 0, 1)
		local goal = target()
		local mid = (from + goal) / 2 + Vector3.new(0, arc, 0)
		local function at(x: number): Vector3
			return from:Lerp(mid, x):Lerp(mid:Lerp(goal, x), x)
		end
		local now, ahead = at(t), at(math.min(1, t + 0.02))
		ball.CFrame = if (ahead - now).Magnitude > 1e-3 then CFrame.lookAt(now, ahead) else CFrame.new(now)
		if t >= 1 then
			connection:Disconnect()
			for _, e in emitters do
				e.Rate = 0
			end
			trail.Enabled = false
			ball.Transparency = 1
			Debris:AddItem(ball, 0.6)
			onArrive(goal)
		end
	end)
end

-- A crescent of moonlight flung from `from` at a (moving) target over `seconds` (Shade's basic attack, AttackFx
-- MOON_SLASH): a glowing crescent bowed forward and tilted, a white core, a dark shadow sheet trailing behind it and
-- motes; `onArrive` where it lands. tilt: degrees (the default's own tilt when nil)
function ElementFx.moonSlash(from: Vector3, target: () -> Vector3, color: Color3, seconds: number, onArrive: (Vector3) -> (), scale: number?, tilt: number?)
	local cfg = AttackFx.MOON_SLASH
	local s = scale or 1
	local half = cfg.length * 0.5 * s
	local turn = math.rad(tilt or cfg.tilt)
	local carrier = holder(from, seconds + 1)
	-- The two tips, across the flight and tilted; each one's X axis points ahead so the beam bows forward between them
	local function tip(side: number): Attachment
		local a = Instance.new("Attachment")
		a.CFrame = CFrame.fromMatrix(Vector3.new(math.cos(turn), math.sin(turn), 0) * half * side, Vector3.new(0, 0, -1), Vector3.new(-math.sin(turn), math.cos(turn), 0))
		a.Parent = carrier
		return a
	end
	local left, right = tip(-1), tip(1)
	local function crescent(width: number, tint: Color3, glow: number, z: number): Beam
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = left, right
		b.CurveSize0, b.CurveSize1 = cfg.bow * s, -cfg.bow * s
		b.Texture = TEX.moon
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureLength = 1
		b.Width0, b.Width1 = width, width
		b.Color = ColorSequence.new(tint)
		b.LightEmission = glow
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Segments = 16
		b.ZOffset = z
		b.Parent = carrier
		return b
	end
	local beams = { crescent(cfg.width * s, color, 1, 0), crescent(cfg.width * 0.45 * s, WHITE, 1, 0.05) }
	-- The shadow it drags behind it: a dark sheet between the tips, not lit
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = left, right
	trail.Color = ColorSequence.new(color, Color3.fromRGB(cfg.shadow[1], cfg.shadow[2], cfg.shadow[3]))
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.Lifetime = cfg.trail
	trail.LightEmission = 0.2
	trail.LightInfluence = 0
	trail.Parent = carrier
	local motes = emitter(carrier, "spark", color, { size = { 0.6 * s, 0.1 }, life = { 0.25, 0.45 }, speed = { 1, 3 }, spread = 180, brightness = 2 })
	motes.Rate = detail(40)
	light(carrier, color, 9 * s, 2, seconds + 0.2)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = if seconds <= 0 then 1 else math.clamp((os.clock() - started) / seconds, 0, 1)
		local goal = target()
		local now = from:Lerp(goal, t) + Vector3.new(0, (AttackFx.ARC.Shade or 0) * math.sin(t * math.pi), 0)
		local flat = Vector3.new(goal.X - now.X, 0, goal.Z - now.Z)
		carrier.CFrame = if flat.Magnitude > 1e-3 then CFrame.lookAt(now, now + flat) else CFrame.new(now)
		if t >= 1 then
			connection:Disconnect()
			motes.Rate = 0
			trail.Enabled = false
			for _, b in beams do
				b.Enabled = false
			end
			Debris:AddItem(carrier, 0.6)
			onArrive(goal)
		end
	end)
end

-- A flickering lightning beam between two points for `seconds`, flares at both ends
function ElementFx.bolt(from: Vector3, to: Vector3, color: Color3, seconds: number, scale: number?)
	local s = scale or 1
	local anchor = holder((from + to) / 2, seconds + 0.4)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = anchor, anchor
	a0.WorldPosition, a1.WorldPosition = from, to
	local function beam(width: number, tint: Color3, brightness: number): Beam
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Texture = TEX.bolt
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureLength = 1
		b.Width0, b.Width1 = width, width
		b.Color = ColorSequence.new(tint)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = brightness
		b.FaceCamera = true
		b.Segments = 12
		b.Transparency = NumberSequence.new(0)
		b.Parent = anchor
		return b
	end
	local outer, core = beam(1.8 * s, color, 1), beam(0.7 * s, WHITE, 1.5)
	task.spawn(function()
		local finish = os.clock() + seconds
		local flip = false
		while os.clock() < finish and anchor.Parent do
			flip = not flip
			for _, b in { outer, core } do
				b.Attachment0, b.Attachment1 = if flip then a1 else a0, if flip then a0 else a1
				b.CurveSize0 = (math.random() * 2 - 1) * 2 * s
				b.CurveSize1 = (math.random() * 2 - 1) * 2 * s
			end
			task.wait(0.045)
		end
		for _, b in { outer, core } do
			b.Transparency = NumberSequence.new(0.6)
		end
		task.wait(0.06)
		outer:Destroy()
		core:Destroy()
	end)
	flashSprite(from, "flare", WHITE, 2 * s, 3.5 * s, 0.25, { spin = { 150, 250 }, core = false, brightness = 2.2 })
	flashSprite(to, "flare", color, 3 * s, 6 * s, 0.3, { spin = { -250, -150 } })
	light(anchor, color, 12 * s, 2, seconds + 0.2)
end

-- A flat ring on the ground at `center` spreading to `radius` over `seconds`
function ElementFx.ring(center: Vector3, color: Color3, radius: number, seconds: number)
	shockwave(center, color, radius, seconds)
end

-- A special move winding up (owner 2026-11-04, design A): a ring in its colour spinning flat on the ground at `at`,
-- growing a little over `seconds`, a white one inside turning the other way, and a light
function ElementFx.castRing(at: Vector3, color: Color3, radius: number, seconds: number)
	local anchor = holder(at + Vector3.new(0, 0.25, 0), seconds + 0.4)
	local flat = { size = { radius * 1.3, radius * 2.2 }, life = seconds + 0.15, speed = 0.01, orientation = Enum.ParticleOrientation.VelocityPerpendicular, spin = { 220, 300 }, fade = 0.75 }
	emitter(anchor, "ring", color, flat):Emit(1)
	local inner = table.clone(flat)
	inner.size = { radius * 0.8, radius * 1.5 }
	inner.spin = { -300, -220 }
	inner.brightness = 2.2
	emitter(anchor, "ring", WHITE, inner):Emit(1)
	light(anchor, color, radius * 4, 2, seconds + 0.2)
end

-- A move's name popping up over `root` ("FIREBALL!") on a plate in its colour, `height` studs up, for `seconds`, then
-- rising away
function ElementFx.callout(root: BasePart, height: number, text: string, color: Color3, seconds: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "MoveCallout"
	gui.Size = UDim2.fromOffset(240, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height + 1.6, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Adornee = root
	gui.Parent = root
	local plate = Instance.new("TextLabel")
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.new(0, 0, 1, -6)
	plate.AutomaticSize = Enum.AutomaticSize.X
	plate.BackgroundColor3 = color
	plate.Text = text
	plate.Font = Enum.Font.FredokaOne
	plate.TextSize = 24
	plate.TextColor3 = WHITE
	plate.TextStrokeTransparency = 0.35
	plate.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = plate
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	pad.Parent = plate
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = WHITE
	edge.Transparency = 0.35
	edge.Thickness = 2
	edge.Parent = plate
	local shine = Instance.new("UIGradient")
	shine.Rotation = 90
	shine.Color = ColorSequence.new(color:Lerp(WHITE, 0.35), color:Lerp(Color3.new(0, 0, 0), 0.15))
	shine.Parent = plate
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = plate
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(seconds, function()
		local away = TweenInfo.new(0.35)
		TweenService:Create(gui, away, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 1.2, 0) }):Play()
		TweenService:Create(plate, away, { TextTransparency = 1, TextStrokeTransparency = 1, BackgroundTransparency = 1 }):Play()
		TweenService:Create(edge, away, { Transparency = 1 }):Play()
		Debris:AddItem(gui, 0.4)
	end)
end

-- Lightning from the sky onto `at` (a grade S Volt's extra)
function ElementFx.skyStrike(at: Vector3, color: Color3, scale: number?)
	local s = scale or 1
	local top = at + Vector3.new((math.random() - 0.5) * 6, 45, (math.random() - 0.5) * 6)
	ElementFx.bolt(top, at, color:Lerp(WHITE, 0.4), 0.3, 1.5 * s)
	ElementFx.burst(at, color, 1.3 * s)
end

-- A glowing crescent slash at `at`, facing from `from` (claw: three side by side; vine: one with leaves); `index`
-- turns each in a combo a different way, `rotation` (degrees) sets it
function ElementFx.slash(at: Vector3, from: Vector3, color: Color3, style: string, index: number, scale: number?, rotation: number?)
	local s = scale or 1
	local angles = { -35, 40, -95, 70, -10 }
	local turn = rotation or angles[((index - 1) % #angles) + 1]
	local spin = if index % 2 == 0 then { -260, -200 } else { 200, 260 }
	local opts = { rotation = turn, spin = spin, fade = 0.35 }
	if style == "claw" then
		local flat = Vector3.new(at.X - from.X, 0, at.Z - from.Z)
		local right = if flat.Magnitude > 0.01 then flat.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
		for mark = -1, 1 do
			flashSprite(at + right * mark * 0.8 * s, "slash", color, 2.8 * s, 4.6 * s, 0.22, opts)
		end
	else
		flashSprite(at, "slash", color, 3.4 * s, 6 * s, 0.24, opts)
		sparks(at, color, 8 * s, 18, 0.9 * s, 12)
	end
end

-- Crystal shards bursting up out of the ground round `ground` within `radius`, a shockwave, dust and sparks
function ElementFx.eruption(ground: Vector3, color: Color3, radius: number, count: number?)
	shockwave(ground, color, radius * 1.15, 0.5)
	flashSprite(ground + Vector3.new(0, 2, 0), "glow", color, 4, radius * 2, 0.45, { start = 0.2, core = false })
	for _ = 1, detail(count or 14) do
		local spot = scatter(ground, radius)
		local height = 4 + math.random() * 5
		task.delay((spot - ground).Magnitude / math.max(radius, 1) * 0.12, function()
			local anchor = holder(spot + Vector3.new(0, height * 0.4, 0), 1.1)
			local shard = { size = { 0.6, height }, life = 0.7, rotation = { -12, 12 }, orientation = Enum.ParticleOrientation.FacingCameraWorldUp, fade = 0.55 }
			emitter(anchor, "shard", color, shard):Emit(1)
			local core = table.clone(shard)
			core.size = { 0.3, height * 0.55 }
			core.brightness = 2.2
			core.life = 0.45
			emitter(anchor, "shard", WHITE, core):Emit(1)
		end)
	end
	local dust = holder(ground + Vector3.new(0, 1, 0), 1.8)
	local puff = emitter(dust, "smoke", DUST, { size = { 3, 7 }, life = { 0.9, 1.3 }, speed = { 3, 6 }, spread = 70, light = 0, brightness = 1, start = 0.4, fade = 0.3 })
	puff.Shape = Enum.ParticleEmitterShape.Disc
	puff.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	puff:Emit(detail(10))
	sparks(ground + Vector3.new(0, 1, 0), color, 30, 40, 1.4, 45)
	light(dust, color, radius * 2, 3, 0.5)
end

-- A column of fire or water (`texture` "flame" | "glow") rising at `at` for `seconds` (a grade S extra, Inferno)
function ElementFx.pillar(at: Vector3, color: Color3, height: number, seconds: number, texture: string)
	local anchor = holder(at, seconds + 1)
	local rise = emitter(anchor, texture, color, { size = { 3.2, 0.8 }, life = 0.45, speed = { height * 1.6, height * 2.2 }, spread = 8, rotation = { -20, 20 }, fade = 0.4 })
	rise.Rate = detail(90)
	local core = emitter(anchor, texture, WHITE, { size = { 1.4, 0.3 }, life = 0.35, speed = { height * 1.6, height * 2 }, spread = 4, rotation = { -20, 20 }, brightness = 2.2 })
	core.Rate = detail(50)
	light(anchor, color, height, 3, seconds + 0.5)
	task.delay(seconds, function()
		rise.Rate = 0
		core.Rate = 0
	end)
end

-- A Pet button move's first-pass effect (Config/AttackFx SPECIALS: Fireball's; the other Pet moves are Util/MoveFx's,
-- the super moves Util/SuperFx's), landing now from `caster` at `target`
function ElementFx.special(style: string, caster: Vector3, target: Vector3, color: Color3, _seconds: number)
	if style == "bigball" then
		ElementFx.projectile(caster, function()
			return target
		end, color, 0.18, 2, function(at)
			ElementFx.burst(at, color, 2)
			shockwave(at - Vector3.new(0, 2, 0), color, 9, 0.5)
			ElementFx.pillar(at - Vector3.new(0, 2, 0), color, 10, 0.4, "flame")
		end, { scale = 1.8, flames = true })
	end
end

-- Sparks pulling in to `at` from a sphere `radius` round it, and a glow building, over `seconds` (a boss winding up
-- a ring); returns a stop (also stops by itself)
function ElementFx.gather(at: Vector3, color: Color3, seconds: number, radius: number): () -> ()
	local shell = part(Vector3.one * radius * 2, color, at)
	shell.Shape = Enum.PartType.Ball
	shell.Transparency = 1
	local light0 = Instance.new("PointLight")
	light0.Color = color
	light0.Range = radius * 2
	light0.Brightness = 0
	light0.Parent = shell
	TweenService:Create(light0, TweenInfo.new(math.max(seconds, 0.05)), { Brightness = AttackFx.CHARGE_LIGHT }):Play()
	emitter(shell, "glow", color, { size = { radius * 0.3, radius * 1.4 }, life = seconds + 0.2, rotation = 0, fade = 0.85, locked = true }):Emit(1)
	local pull = emitter(shell, "spark", color, {
		size = { radius * 0.35, radius * 0.1 },
		life = 0.6,
		speed = { -radius * 1.4, -radius * 1.8 },
		rotation = 0,
		orientation = Enum.ParticleOrientation.VelocityParallel,
		brightness = 2.2,
	})
	pull.Shape = Enum.ParticleEmitterShape.Sphere
	pull.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pull.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	pull.Rate = detail(80)
	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		shell:Destroy()
	end
	task.delay(seconds + 0.3, stop)
	return stop
end

-- A boss's or wild monster's normal attack landing at `at`, from `from` (Config/AttackFx BOSS and MONSTER strike)
function ElementFx.monsterStrike(style: string, at: Vector3, from: Vector3, color: Color3)
	if style == "leaves" then
		ElementFx.slash(at, from, color, "vine", 2, 1.4)
		ElementFx.burst(at, color, 1.3)
		sparks(at - Vector3.new(0, 1.5, 0), DUST, 12, 16, 1, 20)
	elseif style == "fangs" then
		ElementFx.slash(at, from, color, "claw", 1, 1.3)
		ElementFx.slash(at, from, color, "claw", 2, 1.3)
		ElementFx.burst(at, Color3.fromRGB(150, 230, 90), 1.1) -- poison
	elseif style == "embers" then
		ElementFx.burst(at, color, 1.6)
		shockwave(at - Vector3.new(0, 2.5, 0), color, 6, 0.35)
		sparks(at - Vector3.new(0, 1.5, 0), DUST, 14, 18, 1.2, 25)
	elseif style == "bite" then
		ElementFx.slash(at + Vector3.new(0, 0.6, 0), from, WEB, "claw", 1, 0.9, -15)
		ElementFx.slash(at - Vector3.new(0, 0.6, 0), from, WEB, "claw", 2, 0.9, 165)
		ElementFx.burst(at, color, 0.9)
	elseif style == "dive" then
		for index = 1, 3 do
			ElementFx.slash(at, from, color, "claw", index, 0.9)
		end
		ElementFx.burst(at, Color3.fromRGB(60, 30, 90), 0.8)
	elseif style == "headbutt" then
		ElementFx.burst(at, color, 0.9)
		shockwave(at - Vector3.new(0, 2.5, 0), color, 3.5, 0.3)
		sparks(at - Vector3.new(0, 1.5, 0), DUST, 10, 14, 0.9, 20)
	elseif style == "snap" then
		ElementFx.slash(at, from, color, "claw", 1, 0.9, 30)
		ElementFx.slash(at, from, color, "claw", 2, 0.9, -150)
		ElementFx.burst(at, color, 1.0) -- the splash
	elseif style == "spark" then
		ElementFx.bolt(from + Vector3.new(0, 1, 0), at, color, 0.2, 0.8)
		ElementFx.burst(at, color, 0.9)
	end
end

-- A boss's ring attack landing (Config/AttackFx BOSS release): a slam on the ground at `ground` (its centre) over
-- `radius`; a swipe from `ground` (the boss's spot) along `direction` for `length`, `halfAngle` degrees either side
function ElementFx.bossRelease(style: string, ground: Vector3, radius: number, direction: Vector3, length: number, halfAngle: number, color: Color3, height: number?)
	if style == "roots" then
		ElementFx.eruption(ground, color, radius, 10)
		-- Big roots burst up through the ground and curl outward: one thick one in the middle, a ring of them round it,
		-- each four segments, thinner and bending further as they go, with a mossy tip, pulled back down after a moment
		local function root(spot: Vector3, outward: Vector3, size: number)
			local flat = Vector3.new(outward.X, 0, outward.Z)
			local away = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
			local frame = CFrame.lookAt(spot, spot - away) -- facing the centre, so bending "back" curls it outward
			local bend = math.rad(math.random(10, 18))
			local segments: { Part } = {}
			local rise = 0
			for index, thickness in { 2.4, 1.8, 1.25, 0.75 } do
				local span = (4.4 - index * 0.6) * size
				frame = frame * CFrame.Angles(-bend * (if index == 1 then 0.3 else 1), 0, 0)
				local tip = index == 4
				local piece = part(Vector3.new(thickness * size, span, thickness * size), if tip then MOSS else ROOT, spot)
				piece.Material = if tip then Enum.Material.Grass else Enum.Material.Wood
				piece.CFrame = frame * CFrame.new(0, span / 2, 0)
				frame = frame * CFrame.new(0, span, 0)
				rise += span
				table.insert(segments, piece)
			end
			for _, piece in segments do
				local up = piece.CFrame
				piece.CFrame = up - Vector3.new(0, rise, 0)
				TweenService:Create(piece, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = up }):Play()
				task.delay(1.1, function()
					TweenService:Create(piece, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = up - Vector3.new(0, rise, 0) }):Play()
				end)
				Debris:AddItem(piece, 1.6)
			end
			sparks(spot + Vector3.new(0, 1, 0), DUST, 10 * size, 22, 1.4 * size, 30)
		end
		root(ground, Vector3.zero, 1.35)
		local count = detail(8)
		for index = 1, count do
			local angle = index / count * math.pi * 2 + math.random() * 0.4
			local away = Vector3.new(math.cos(angle), 0, math.sin(angle))
			root(ground + away * radius * (0.45 + math.random() * 0.4), away, 0.85 + math.random() * 0.3)
		end
	elseif style == "web" then
		-- The web spit, big (owner 2026-11-03): from her fangs (half her height up) a thick spray of strands lands across
		-- the whole cone with wide splats, and a fan of web, spokes and cross threads, sticks over it, then fades
		local flat = Vector3.new(direction.X, 0, direction.Z)
		local forward = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
		local tall = height or 6
		local mouth = ground + Vector3.new(0, tall * 0.5, 0) + forward * tall * 0.3
		local floor = ground + Vector3.new(0, 0.3, 0)
		local hold = 1.4
		ElementFx.burst(mouth, color, 3)
		sparks(mouth, WEB, detail(30), 30, 1.2, 20)
		local function way(degrees: number): Vector3
			return CFrame.fromAxisAngle(Vector3.yAxis, math.rad(degrees)):VectorToWorldSpace(forward)
		end
		-- A thread that shoots from `a` to `b` after `after` seconds, holds, then fades
		local function thread(a: Vector3, b: Vector3, thickness: number, after: number)
			task.delay(after, function()
				local piece = part(Vector3.new(thickness, thickness, 0.2), WEB, a)
				piece.Material = Enum.Material.SmoothPlastic
				piece.CFrame = CFrame.lookAt(a, b)
				TweenService:Create(piece, TweenInfo.new(0.18), {
					Size = Vector3.new(thickness, thickness, (b - a).Magnitude),
					CFrame = CFrame.lookAt((a + b) / 2, b),
				}):Play()
				task.delay(hold - after, function()
					TweenService:Create(piece, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				end)
				Debris:AddItem(piece, hold - after + 0.6)
			end)
		end
		-- The fan: spokes out from her to the cone's edge, then the cross threads between them, nearest first
		local spokes = 7
		local apex = floor + forward * 2
		local angles = {}
		for index = 1, spokes do
			angles[index] = -halfAngle + 2 * halfAngle * (index - 1) / (spokes - 1)
			thread(apex, floor + way(angles[index]) * length, 0.45, 0.05)
		end
		for step, share in { 0.3, 0.5, 0.7, 0.9 } do
			for index = 1, spokes - 1 do
				thread(floor + way(angles[index]) * length * share, floor + way(angles[index + 1]) * length * share, 0.3, 0.15 + step * 0.05)
			end
		end
		-- The spray: thick strands from her mouth, each landing with a wide splat
		for _ = 1, detail(12) do
			local finish = floor + way(halfAngle * (math.random() * 2 - 1)) * length * (0.35 + math.random() * 0.65)
			thread(mouth, finish, 0.75, 0)
			task.delay(0.18, function()
				local splat = part(Vector3.new(0.15, 1, 1), WEB, finish)
				splat.Shape = Enum.PartType.Cylinder
				splat.Material = Enum.Material.SmoothPlastic
				splat.CFrame = CFrame.new(finish) * CFrame.Angles(0, 0, math.rad(90))
				TweenService:Create(splat, TweenInfo.new(0.15), { Size = Vector3.new(0.15, 7, 7) }):Play()
				flashSprite(finish + Vector3.new(0, 0.5, 0), "impact", color, 2.5, 7, 0.3)
				task.delay(hold - 0.18, function()
					TweenService:Create(splat, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				end)
				Debris:AddItem(splat, hold + 0.5)
			end)
		end
		shockwave(floor + forward * length * 0.55, color, length * 0.75, 0.5)
	elseif style == "lava" then
		-- Bigger since the meteor lands here (owner 2026-11-04): a wide eruption, a tall fire pillar, a burst and a ring
		ElementFx.eruption(ground, color, radius * 1.3, 22)
		ElementFx.pillar(ground, color, 18, 0.5, "flame")
		ElementFx.burst(ground + Vector3.new(0, 2, 0), color, 3)
		shockwave(ground, color, radius * 1.8, 0.5)
		for index = 1, 8 do
			local angle = index / 8 * math.pi * 2 + math.random() * 0.3
			local reach = radius * (0.6 + math.random() * 0.4)
			local tip = ground + Vector3.new(math.cos(angle) * reach, 0.1, math.sin(angle) * reach)
			local crack = part(Vector3.new(0.5, 0.12, 0.2), CRACK, ground)
			crack.CFrame = CFrame.lookAt(ground + Vector3.new(0, 0.1, 0), tip)
			TweenService:Create(crack, TweenInfo.new(0.2), {
				Size = Vector3.new(0.5, 0.12, reach),
				CFrame = CFrame.lookAt((ground + tip) / 2 + Vector3.new(0, 0.1, 0), tip),
			}):Play()
			task.delay(0.8, function()
				TweenService:Create(crack, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end)
			Debris:AddItem(crack, 1.5)
		end
		for _ = 1, detail(6) do
			local landing = scatter(ground, radius)
			ElementFx.projectile(ground + Vector3.new(0, 0.5, 0), function()
				return landing
			end, MOLTEN, 0.55, 5 + math.random() * 3, function(at)
				ElementFx.burst(at, color, 0.5)
			end, { scale = 0.6, flames = true })
		end
	end
end

return ElementFx
