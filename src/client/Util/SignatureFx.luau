--!strict
-- The effects of the originals' signature idles (Party.SIGNATURE), on this client only, fired once by
-- Util/CreatureVisuals when Util/PetRig says the fidget's moment has come:
-- * butterfly (Sprouthop): a little butterfly appears on the raised hand in a puff of sparkles, flutters round the
--   head and flies off.
-- * thunderroar (Boltlynx): lightning crackles out of the mane in three bursts, with a flash.
-- * voidroar (Voidmaw): dark void smoke bursts from every mouth.
-- * stormroar (Stormjack): lightning leaps between its mouths in four bursts.
-- * firebreath (Infernox): a cone of fire pours from its mouth for a moment, lighting up round it.
-- (Roars also get CreatureVisuals' shockwave ring and sparks.) Everything is anchored, never collides, and cleans
-- itself up, also if the creature is removed first.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SignatureFx = {}

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local BUTTERFLY_COLORS = { Color3.fromRGB(120, 190, 255), Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 220, 90), Color3.fromRGB(190, 150, 255) }
local BUTTERFLY_SECONDS = 3.6
local LIGHTNING_COLOR = Color3.fromRGB(255, 246, 170)
local VOID_COLOR = Color3.fromRGB(120, 50, 200)
local rng = Random.new()

local function bonePosition(model: Model, name: string): Vector3?
	local bone = model:FindFirstChild(name, true)
	return if bone and bone:IsA("Bone") then bone.TransformedWorldCFrame.Position else nil
end

local function fxPart(size: Vector3, color: Color3, neon: boolean): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size
	return part
end

-- A one-off burst of particles at a point, cleaned up once they've faded
local function burst(at: CFrame, texture: string, color: ColorSequence, count: number, size: number, speed: number, lifetime: number)
	local holder = Instance.new("Attachment")
	holder.WorldCFrame = at
	holder.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = color
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new(size, 0)
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)
	task.delay(lifetime + 0.2, holder.Destroy, holder)
end

local function butterfly(model: Model, size: number)
	local hand = bonePosition(model, "Arm_Right_2") or bonePosition(model, "Head_0")
	if not hand then
		return
	end
	local scale = 0.35 + 0.15 * size
	local color = BUTTERFLY_COLORS[rng:NextInteger(1, #BUTTERFLY_COLORS)]
	local folder = Instance.new("Folder")
	folder.Name = "Butterfly"
	local thorax = fxPart(Vector3.new(0.06, 0.06, 0.28) * scale, Color3.fromRGB(40, 30, 30), false)
	local wings = {}
	for _, side in { 1, -1 } do
		local wing = fxPart(Vector3.new(0.34, 0.02, 0.3) * scale, color, true)
		wing.Transparency = 0.15
		wing.Parent = folder
		table.insert(wings, { part = wing, side = side })
	end
	thorax.Parent = folder
	folder.Parent = workspace
	burst(CFrame.lookAt(hand, hand + Vector3.yAxis), SPARKLES, ColorSequence.new(Color3.fromRGB(190, 255, 140), color), 14, 0.35 * scale * 2, 3, 0.8)

	local start = os.clock()
	local last = CFrame.new(hand)
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - start
		local head = bonePosition(model, "Head_0")
		if t >= BUTTERFLY_SECONDS or not model.Parent or not head then
			connection:Disconnect()
			folder:Destroy()
			return
		end
		-- Rises off the hand, circles above the head, then flies away up and out, fading
		local centre = head + Vector3.new(0, 0.9 * size, 0)
		local radius = 0.7 * size
		local angle = t * 2.4
		local circling = centre + Vector3.new(math.cos(angle) * radius, math.sin(t * 7) * 0.15 * size, math.sin(angle) * radius)
		local position
		if t < 0.6 then
			position = (bonePosition(model, "Arm_Right_2") or hand):Lerp(circling, t / 0.6)
		elseif t < 2.7 then
			position = circling
		else
			local away = (t - 2.7) / (BUTTERFLY_SECONDS - 2.7)
			position = circling + Vector3.new(math.cos(angle) * 4, 3, math.sin(angle) * 4) * away * size
			for _, wing in wings do
				wing.part.Transparency = 0.15 + 0.85 * away
			end
			thorax.Transparency = away
		end
		local facing = if (position - last.Position).Magnitude > 1e-3 then CFrame.lookAt(position, position + (position - last.Position)) else CFrame.new(position) * last.Rotation
		last = facing
		thorax.CFrame = facing
		local flap = math.rad(55) * math.sin(t * 30)
		for _, wing in wings do
			local hinge = facing * CFrame.Angles(0, 0, wing.side * flap)
			wing.part.CFrame = hinge * CFrame.new(wing.side * wing.part.Size.X / 2, 0, 0)
		end
	end)
end

-- A jagged bolt of neon segments from a to b, gone after a moment
local function bolt(a: Vector3, b: Vector3, width: number)
	local points = { a }
	local segments = 5
	local across = (b - a).Magnitude * 0.18
	for i = 1, segments - 1 do
		local jitter = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * across
		table.insert(points, a:Lerp(b, i / segments) + jitter)
	end
	table.insert(points, b)
	for i = 1, #points - 1 do
		local from, to = points[i], points[i + 1]
		local part = fxPart(Vector3.new(width, width, (to - from).Magnitude), LIGHTNING_COLOR, true)
		part.CFrame = CFrame.lookAt((from + to) / 2, to)
		part.Parent = workspace
		task.delay(0.12, part.Destroy, part)
	end
end

local function thunder(model: Model, size: number)
	local head = bonePosition(model, "Head_0")
	if not head then
		return
	end
	local flash = Instance.new("Attachment")
	flash.WorldPosition = head
	flash.Parent = workspace.Terrain
	local light = Instance.new("PointLight")
	light.Color = LIGHTNING_COLOR
	light.Brightness = 4
	light.Range = 10 * size
	light.Parent = flash
	TweenService:Create(light, TweenInfo.new(0.7), { Brightness = 0 }):Play()
	task.delay(0.8, flash.Destroy, flash)
	for wave = 0, 2 do
		task.delay(wave * 0.16, function()
			local now = bonePosition(model, "Head_0")
			if not now or not model.Parent then
				return
			end
			for _ = 1, 4 do
				local out = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1), rng:NextNumber(-1, 1)).Unit
				bolt(now + out * 0.35 * size, now + out * rng:NextNumber(1.1, 1.7) * size, 0.07 * size)
			end
		end)
	end
end

local function void(model: Model, size: number)
	local forward = model:GetPivot().LookVector
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") and string.match(descendant.Name, "^Jaw_%d$") then
			local mouth = descendant.TransformedWorldCFrame.Position
			burst(CFrame.lookAt(mouth, mouth + forward + Vector3.new(0, 0.3, 0)), SMOKE,
				ColorSequence.new(VOID_COLOR, Color3.fromRGB(20, 10, 30)), 10, 0.9 * size, 5 * size, 1)
			burst(CFrame.lookAt(mouth, mouth + forward), SPARKLES, ColorSequence.new(Color3.fromRGB(220, 170, 255)), 6, 0.4 * size, 7 * size, 0.6)
		end
	end
end

local function mouths(model: Model): { Bone }
	local found = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") and string.match(descendant.Name, "^Jaw_%d$") then
			table.insert(found, descendant)
		end
	end
	return found
end

local function storm(model: Model, size: number)
	local jaws = mouths(model)
	if #jaws < 2 then
		return
	end
	for wave = 0, 3 do
		task.delay(wave * 0.14, function()
			if not model.Parent then
				return
			end
			-- Lightning leaps from every mouth to every other
			for i = 1, #jaws do
				for j = i + 1, #jaws do
					bolt(jaws[i].TransformedWorldCFrame.Position, jaws[j].TransformedWorldCFrame.Position, 0.06 * size)
				end
			end
		end)
	end
	for _, jaw in jaws do
		local mouth = jaw.TransformedWorldCFrame.Position
		burst(CFrame.lookAt(mouth, mouth + Vector3.yAxis), SPARKLES, ColorSequence.new(LIGHTNING_COLOR, Color3.fromRGB(120, 210, 255)), 10, 0.4 * size, 6 * size, 0.6)
	end
end

local function fireBreath(model: Model, size: number)
	local jaw = mouths(model)[1]
	if not jaw then
		return
	end
	local holder = Instance.new("Attachment")
	holder.Parent = workspace.Terrain
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 140, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 30, 10)),
	})
	fire.LightEmission = 0.9
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 * size), NumberSequenceKeypoint.new(1, 1.6 * size) })
	fire.Transparency = NumberSequence.new(0.1, 1)
	fire.Lifetime = NumberRange.new(0.35, 0.55)
	fire.Speed = NumberRange.new(10 * size, 14 * size)
	fire.SpreadAngle = Vector2.new(14, 14)
	fire.EmissionDirection = Enum.NormalId.Front
	fire.Rate = 140
	fire.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Brightness = 3
	light.Range = 8 * size
	light.Parent = holder
	-- The flames follow the mouth, pouring forward and a little down, then stop and fade out
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if not model.Parent or os.clock() - start > 1.3 then
			connection:Disconnect()
			fire.Enabled = false
			TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
			task.delay(0.8, holder.Destroy, holder)
			return
		end
		local mouth = jaw.TransformedWorldCFrame.Position
		local forward = model:GetPivot().LookVector
		holder.WorldCFrame = CFrame.lookAt(mouth, mouth + forward - Vector3.new(0, 0.25, 0))
	end)
end

-- The effect of a signature idle (Party.SIGNATURE), from the creature's current pose; size: its size multiplier
function SignatureFx.play(kind: string, model: Model, size: number)
	if kind == "butterfly" then
		butterfly(model, size)
	elseif kind == "thunderroar" then
		thunder(model, size)
	elseif kind == "voidroar" then
		void(model, size)
	elseif kind == "stormroar" then
		storm(model, size)
	elseif kind == "firebreath" then
		fireBreath(model, size)
	end
end

return SignatureFx
