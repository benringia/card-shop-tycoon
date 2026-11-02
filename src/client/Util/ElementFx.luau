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

local DUST = Color3.fromRGB(160, 138, 108)
local ROOT = Color3.fromRGB(78, 54, 34)
local MOSS = Color3.fromRGB(96, 170, 64)
local WEB = Color3.fromRGB(236, 232, 245)
local MOLTEN = Color3.fromRGB(255, 196, 64)
local CRACK = Color3.fromRGB(255, 72, 18)

-- Sparks pulling in to `at` from a sphere `radius` round it, and a light building, over `seconds` (a boss winding up
-- a ring); returns a stop (also stops by itself)
function ElementFx.gather(at: Vector3, color: Color3, seconds: number, radius: number): () -> ()
	local shell = part(Vector3.one * radius * 2, color, at)
	shell.Shape = Enum.PartType.Ball
	shell.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = radius * 2
	light.Brightness = 0
	light.Parent = shell
	TweenService:Create(light, TweenInfo.new(math.max(seconds, 0.05)), { Brightness = AttackFx.CHARGE_LIGHT }):Play()
	local sparks = emitter(shell, color, -radius * 1.2, 0.7, 0.4 * radius / 3)
	sparks.Shape = Enum.ParticleEmitterShape.Sphere
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparks.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	sparks.SpreadAngle = Vector2.new(0, 0)
	sparks.Rate = 70
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

-- A flat ring on the ground at `center` spreading out to `radius` and fading
local function shockwave(center: Vector3, color: Color3, radius: number, seconds: number)
	local wave = part(Vector3.new(0.3, 2, 2), color, center)
	wave.Shape = Enum.PartType.Cylinder
	wave.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	wave.Transparency = 0.2
	TweenService:Create(wave, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(wave, seconds + 0.05)
end

-- A random point on the ground within `radius` of `center`
local function scatter(center: Vector3, radius: number): Vector3
	local angle = math.random() * math.pi * 2
	local distance = radius * math.sqrt(math.random())
	return center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

-- A boss's normal attack landing at `at`, swung from `from` (Config/AttackFx BOSS strike)
function ElementFx.bossStrike(style: string, at: Vector3, from: Vector3, color: Color3)
	if style == "leaves" then
		ElementFx.slash(at, from, color, "vine", 2)
		ElementFx.burst(at, color, 1.2)
		ElementFx.burst(at - Vector3.new(0, 1.5, 0), DUST, 0.9)
	elseif style == "fangs" then
		ElementFx.slash(at, from, color, "claw", 1)
		ElementFx.slash(at, from, color, "claw", 3)
		ElementFx.burst(at, Color3.fromRGB(150, 230, 90), 1.0) -- poison
	elseif style == "embers" then
		ElementFx.burst(at, color, 1.6)
		ElementFx.burst(at - Vector3.new(0, 1.5, 0), DUST, 1.0)
		shockwave(at - Vector3.new(0, 2.5, 0), color, 5, 0.35)
	end
end

-- A boss's ring attack landing (Config/AttackFx BOSS release): a slam on the ground at `ground` (its centre) over
-- `radius`; a swipe from `ground` (the boss's spot) along `direction` for `length`, `halfAngle` degrees either side
function ElementFx.bossRelease(style: string, ground: Vector3, radius: number, direction: Vector3, length: number, halfAngle: number, color: Color3)
	if style == "roots" then
		shockwave(ground + Vector3.new(0, 0.2, 0), color, radius, 0.5)
		ElementFx.burst(ground + Vector3.new(0, 1, 0), color, 1.6)
		-- Each root is three segments, thinner and bending further as they go, built under the ground and pushed up
		-- through it, then pulled back down
		for _ = 1, 7 do
			local spot = scatter(ground, radius * 0.9)
			local bend = math.rad(math.random(14, 24))
			local frame = CFrame.new(spot) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
			local segments: { Part } = {}
			local rise = 0
			for index, thickness in { 1.1, 0.75, 0.45 } do
				local span = 2.2 - index * 0.35
				frame = frame * CFrame.Angles(bend, 0, 0)
				local piece = part(Vector3.new(thickness, span, thickness), if index == 3 then MOSS else ROOT, spot)
				piece.Material = if index == 3 then Enum.Material.Grass else Enum.Material.Wood
				piece.CFrame = frame * CFrame.new(0, span / 2, 0)
				frame = frame * CFrame.new(0, span, 0)
				rise += span
				table.insert(segments, piece)
			end
			for _, piece in segments do
				local up = piece.CFrame
				piece.CFrame = up - Vector3.new(0, rise, 0)
				TweenService:Create(piece, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = up }):Play()
				task.delay(0.95, function()
					TweenService:Create(piece, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = up - Vector3.new(0, rise, 0) }):Play()
				end)
				Debris:AddItem(piece, 1.4)
			end
			ElementFx.burst(spot + Vector3.new(0, 0.5, 0), DUST, 0.5)
		end
	elseif style == "web" then
		local flat = Vector3.new(direction.X, 0, direction.Z)
		local forward = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
		local mouth = ground + Vector3.new(0, 3, 0) + forward * 3
		ElementFx.burst(mouth, color, 1.2)
		for index = 1, 9 do
			local angle = math.rad(-halfAngle + 2 * halfAngle * (index - 1) / 8 + math.random(-4, 4))
			local way = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(forward)
			local finish = ground + way * length * (0.55 + math.random() * 0.45) + Vector3.new(0, 0.3, 0)
			local strand = part(Vector3.new(0.35, 0.35, 0.2), WEB, mouth)
			strand.Material = Enum.Material.SmoothPlastic
			strand.CFrame = CFrame.lookAt(mouth, finish)
			local distance = (finish - mouth).Magnitude
			TweenService:Create(strand, TweenInfo.new(0.22), {
				Size = Vector3.new(0.35, 0.35, distance),
				CFrame = CFrame.lookAt((mouth + finish) / 2, finish),
			}):Play()
			task.delay(0.22, function()
				local splat = part(Vector3.new(0.15, 1, 1), WEB, finish)
				splat.Shape = Enum.PartType.Cylinder
				splat.Material = Enum.Material.SmoothPlastic
				splat.CFrame = CFrame.new(finish) * CFrame.Angles(0, 0, math.rad(90))
				TweenService:Create(splat, TweenInfo.new(0.15), { Size = Vector3.new(0.15, 4.5, 4.5) }):Play()
				task.delay(1.4, function()
					TweenService:Create(splat, TweenInfo.new(0.5), { Transparency = 1 }):Play()
					TweenService:Create(strand, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				end)
				Debris:AddItem(splat, 2)
			end)
			Debris:AddItem(strand, 2.2)
		end
	elseif style == "lava" then
		shockwave(ground + Vector3.new(0, 0.2, 0), color, radius, 0.45)
		ElementFx.burst(ground + Vector3.new(0, 1, 0), color, 2)
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
		for _ = 1, 6 do
			local landing = scatter(ground, radius)
			ElementFx.projectile(ground + Vector3.new(0, 0.5, 0), function()
				return landing
			end, MOLTEN, 0.55, 5 + math.random() * 3, function(at)
				ElementFx.burst(at, color, 0.5)
			end)
		end
	end
end

return ElementFx
