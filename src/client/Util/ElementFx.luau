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

return ElementFx
