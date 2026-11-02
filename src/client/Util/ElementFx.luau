--!strict
-- The pieces fight effects are built from (Util/FightFx, Config/AttackFx), all on this client and cleaned up by
-- themselves: a charge glow with sparks pulling in, a projectile flying in an arc, an impact burst, a jagged lightning
-- bolt, a slash (claw marks or a vine lash) and a positional sound. Parts are anchored, can't collide and cast no
-- shadow; everything sits in workspace.FightFx.
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackFx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AttackFx"))

local ElementFx = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

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

local function emitter(parent: Instance, color: Color3, speed: number, lifetime: number, size: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color)
	e.LightEmission = 0.8
	e.Speed = NumberRange.new(math.min(speed * 0.5, speed), math.max(speed * 0.5, speed)) -- negative: they pull in
	e.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.1, 1)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = parent
	return e
end

-- A positional sound at `at`, removed once played
function ElementFx.sound(id: string?, at: Vector3)
	if not id or id == "" then
		return
	end
	local holder = part(Vector3.new(0.2, 0.2, 0.2), Color3.new(), at)
	holder.Transparency = 1
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = AttackFx.VOLUME
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, 3)
end

-- A glow building on `root` over `seconds`, sparks pulling in from round it; returns a stop (also stops by itself)
function ElementFx.chargeGlow(root: BasePart, color: Color3, seconds: number): () -> ()
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 0
	light.Parent = attachment
	TweenService:Create(light, TweenInfo.new(math.max(seconds, 0.05)), { Brightness = AttackFx.CHARGE_LIGHT }):Play()
	local sparks = emitter(attachment, color, -6, 0.5, 0.5) -- negative speed from a sphere's surface: they pull in
	sparks.Shape = Enum.ParticleEmitterShape.Sphere
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparks.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	sparks.SpreadAngle = Vector2.new(0, 0)
	sparks.Rate = 40
	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		attachment:Destroy()
	end
	task.delay(seconds + 0.25, stop)
	return stop
end

-- An impact: sparks bursting out and a quick flash of light at `at`
function ElementFx.burst(at: Vector3, color: Color3, scale: number?)
	local size = scale or 1
	local holder = part(Vector3.new(0.2, 0.2, 0.2), color, at)
	holder.Transparency = 1
	local sparks = emitter(holder, color, 18 * size, 0.45, 0.9 * size)
	sparks:Emit(math.round(AttackFx.BURST * size))
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14 * size
	light.Brightness = 4
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.3), { Brightness = 0 }):Play()
	Debris:AddItem(holder, 1)
end

-- A glowing ball from `from` to wherever `target()` is, rising `arc` studs at its middle, taking `seconds`; then
-- `onArrive(position)`
function ElementFx.projectile(from: Vector3, target: () -> Vector3, color: Color3, seconds: number, arc: number, onArrive: (Vector3) -> ())
	local ball = part(Vector3.one * AttackFx.PROJECTILE_SIZE, color:Lerp(Color3.new(1, 1, 1), 0.4), from)
	ball.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 3
	light.Parent = ball
	local trail = emitter(ball, color, 1, 0.35, 0.8)
	trail.Rate = 60
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = if seconds <= 0 then 1 else math.clamp((os.clock() - started) / seconds, 0, 1)
		local goal = target()
		local mid = (from + goal) / 2 + Vector3.new(0, arc, 0)
		local a, b = from:Lerp(mid, t), mid:Lerp(goal, t)
		ball.CFrame = CFrame.new(a:Lerp(b, t))
		if t >= 1 then
			connection:Disconnect()
			trail.Rate = 0
			ball.Transparency = 1
			light.Enabled = false
			Debris:AddItem(ball, 0.5)
			onArrive(goal)
		end
	end)
end

-- A jagged bolt of light between two points, gone after `seconds`
function ElementFx.bolt(from: Vector3, to: Vector3, color: Color3, seconds: number)
	local points = { from }
	local segments = 7
	for index = 1, segments - 1 do
		local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.2
		table.insert(points, from:Lerp(to, index / segments) + jitter)
	end
	table.insert(points, to)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local length = (b - a).Magnitude
		local piece = part(Vector3.new(0.18, 0.18, length), color:Lerp(Color3.new(1, 1, 1), 0.3), (a + b) / 2)
		piece.CFrame = CFrame.lookAt((a + b) / 2, b)
		TweenService:Create(piece, TweenInfo.new(seconds), { Transparency = 1 }):Play()
		Debris:AddItem(piece, seconds + 0.05)
	end
end

-- A slash at `at` facing from `from`: three claw marks, or one curved vine lash (`index` turns each one a little)
function ElementFx.slash(at: Vector3, from: Vector3, color: Color3, style: string, index: number)
	local facing = CFrame.lookAt(at, Vector3.new(from.X, at.Y, from.Z))
	local tilt = math.rad(-35 + 30 * ((index - 1) % 3))
	local pieces: { Part } = {}
	if style == "claw" then
		for mark = -1, 1 do
			local piece = part(Vector3.new(0.16, 3.2, 0.16), color, at)
			piece.CFrame = facing * CFrame.new(mark * 0.6, 0, -1) * CFrame.Angles(0, 0, tilt)
			table.insert(pieces, piece)
		end
	else
		for step = 0, 4 do
			local angle = math.rad(-60 + step * 30)
			local piece = part(Vector3.new(0.35, 0.35, 1.3), color, at)
			piece.CFrame = facing * CFrame.Angles(0, 0, tilt) * CFrame.new(math.sin(angle) * 2, math.cos(angle) * 2 - 1, -1) * CFrame.Angles(0, 0, -angle)
			table.insert(pieces, piece)
		end
	end
	for _, piece in pieces do
		TweenService:Create(piece, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		Debris:AddItem(piece, 0.3)
	end
end

-- A shape of light that fades out after `seconds` (lasting effects: pillars, bubbles, rings)
local function lasting(shape: Enum.PartType, size: Vector3, color: Color3, at: CFrame, seconds: number, transparency: number): Part
	local piece = part(size, color, at.Position)
	piece.Shape = shape
	piece.CFrame = at
	piece.Transparency = transparency
	task.delay(math.max(0, seconds - 0.4), function()
		if piece.Parent then
			TweenService:Create(piece, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(piece, seconds + 0.1)
	return piece
end

-- Sparks rising round `at` for `seconds` (fire, mist, an aura)
local function haze(at: Vector3, color: Color3, seconds: number, speed: number, size: number, rate: number)
	local holder = part(Vector3.new(0.2, 0.2, 0.2), color, at)
	holder.Transparency = 1
	local sparks = emitter(holder, color, speed, 0.9, size)
	sparks.Shape = Enum.ParticleEmitterShape.Sphere
	sparks.Rate = rate
	task.delay(seconds, function()
		sparks.Rate = 0
	end)
	Debris:AddItem(holder, seconds + 1)
end

-- A Pet button move or super move (Config/AttackFx SPECIALS), all landing now: `style` picks the look; `caster` and
-- `target` are positions (the target is the caster for moves on itself); `seconds` for the lasting ones
function ElementFx.special(style: string, caster: Vector3, target: Vector3, color: Color3, seconds: number)
	local ground = target - Vector3.new(0, 2, 0)
	if style == "bigball" then
		ElementFx.bolt(caster, target, color, 0.2)
		ElementFx.burst(target, color, 1.8)
		local ring = part(Vector3.new(0.3, 2, 2), color, ground)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
		TweenService:Create(ring, TweenInfo.new(0.5), { Size = Vector3.new(0.3, 16, 16), Transparency = 1 }):Play()
		Debris:AddItem(ring, 0.6)
	elseif style == "wave" then
		local base = caster - Vector3.new(0, 2, 0)
		local wave = part(Vector3.new(1, 1, 1), color, base)
		wave.Shape = Enum.PartType.Ball
		wave.Material = Enum.Material.Glass
		wave.Transparency = 0.4
		TweenService:Create(wave, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(9, 7, 9) }):Play()
		task.delay(0.45, function()
			TweenService:Create(wave, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end)
		Debris:AddItem(wave, 0.9)
		ElementFx.burst(caster, color, 1.2)
	elseif style == "snare" then
		for index = 1, 5 do
			local angle = index / 5 * math.pi * 2
			local root = ground + Vector3.new(math.cos(angle) * 2.5, 0, math.sin(angle) * 2.5)
			local vine = lasting(Enum.PartType.Block, Vector3.new(0.4, 0.2, 0.4), color, CFrame.new(root), seconds, 0)
			TweenService:Create(vine, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
				Size = Vector3.new(0.4, 6, 0.4),
				CFrame = CFrame.new(root + Vector3.new(0, 3, 0)) * CFrame.Angles(0, angle, math.rad(18)),
			}):Play()
		end
	elseif style == "aura" then
		haze(caster, color, seconds, 4, 0.7, 30)
		for step = 0, 2 do
			task.delay(step * 0.4, function()
				ElementFx.bolt(caster + Vector3.new(0, 3, 0), caster - Vector3.new(0, 1, 0), color, 0.15)
			end)
		end
	elseif style == "mist" then
		haze(target, color, seconds, 1.5, 2.5, 18)
	elseif style == "inferno" then
		local pillar = lasting(Enum.PartType.Cylinder, Vector3.new(14, 4, 4), color, CFrame.new(ground + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)), seconds, 0.45)
		pillar.Material = Enum.Material.Neon
		haze(target, color, seconds, 8, 1.2, 40)
	elseif style == "shield" then
		local bubble = lasting(Enum.PartType.Ball, Vector3.new(11, 11, 11), color, CFrame.new(caster), seconds, 0.2)
		bubble.Material = Enum.Material.ForceField
	elseif style == "stampede" then
		ElementFx.bolt(caster, target, color, 0.3)
		ElementFx.bolt(caster + Vector3.new(0, 1, 0), target + Vector3.new(0, 1, 0), color, 0.3)
		ElementFx.burst(target, color, 1.5)
	elseif style == "eclipse" then
		lasting(Enum.PartType.Ball, Vector3.new(6, 6, 6), Color3.fromRGB(20, 10, 40), CFrame.new(caster + Vector3.new(0, 16, 0)), seconds, 0)
		local halo = lasting(Enum.PartType.Ball, Vector3.new(7.5, 7.5, 7.5), color, CFrame.new(caster + Vector3.new(0, 16, 0)), seconds, 0.6)
		halo.Material = Enum.Material.Neon
		local ring = lasting(Enum.PartType.Cylinder, Vector3.new(0.2, 7, 7), color, CFrame.new(caster - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), seconds, 0.3)
		ring.Material = Enum.Material.Neon
	elseif style == "nova" then
		local star = part(Vector3.new(1, 1, 1), color, target + Vector3.new(0, 10, 0))
		star.Shape = Enum.PartType.Ball
		TweenService:Create(star, TweenInfo.new(0.25), { Size = Vector3.new(5, 5, 5), CFrame = CFrame.new(target) }):Play()
		task.delay(0.25, function()
			star:Destroy()
			ElementFx.burst(target, color, 2.5)
		end)
	elseif style == "devour" then
		for side = -1, 1, 2 do
			local jaw = part(Vector3.new(6, 1.2, 3), Color3.fromRGB(40, 20, 70), target + Vector3.new(0, side * 4, 0))
			TweenService:Create(jaw, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(target + Vector3.new(0, side * 0.6, 0)) }):Play()
			task.delay(0.35, function()
				TweenService:Create(jaw, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end)
			Debris:AddItem(jaw, 0.7)
		end
		task.delay(0.2, function()
			ElementFx.burst(target, color, 1.2)
			for step = 0, 2 do
				task.delay(step * 0.12, function()
					ElementFx.projectile(target, function()
						return caster
					end, Color3.fromRGB(74, 222, 128), 0.4, 2, function() end)
				end)
			end
		end)
	end
end

return ElementFx
