--!strict
-- The Rift Devourer's summoning (the owner 2026-11-11: "add a noticeable summoning effect when creatures are summoned";
-- Config/AttackFx RIFT), drawn on this client by Util/FightFx. It calls: a void shockwave out from it, a dark burst at
-- its jaws, a shake. At each summon's corner a rift tears open: a lightning beam from its jaws to the spot, a pool of
-- void on the ground, a round portal (a violet halo and ring round a dark void) with a light, motes pulling in and
-- crackles off its rim, for the
-- summon's emerge time; it bursts (shards, smoke) as the summon climbs out (MonsterController raises it out of the
-- ground) and closes a moment later.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("Config"):WaitForChild("AttackFx"))
local SwordFx = require(Shared:WaitForChild("Config"):WaitForChild("SwordFx"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))
local ScreenFx = require((script.Parent :: Instance):WaitForChild("ScreenFx"))

local RiftFx = {}

local RIFT = AttackFx.RIFT
local TEXTURES = AttackFx.TEXTURES
local UP = Vector3.yAxis

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local COLOR = rgb(RIFT.color)
local CORE = rgb(RIFT.core)
local GLOW = rgb(RIFT.glow)

local function piece(size: Vector3, color: Color3, cframe: CFrame, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	part.Parent = ElementFx.folder()
	return part
end

-- A flat decal on the ground at `centre`, `radius` across its middle
local function flat(image: string, color: Color3, transparency: number, centre: CFrame, radius: number): (Part, Decal)
	local across = math.max(0.2, radius * 2)
	local part = piece(Vector3.new(across, 0.05, across), color, centre, Enum.Material.SmoothPlastic)
	part.Transparency = 1
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = image
	decal.Color3 = color
	decal.Transparency = transparency
	decal.Parent = part
	return part, decal
end

-- A disc of `image` at `centre` (decals on both faces; RiftFx.open turns it to the camera and sizes it)
local function disc(image: string, color: Color3, transparency: number, centre: Vector3): Part
	local part = piece(Vector3.new(0.1, 0.1, 0.05), color, CFrame.new(centre), Enum.Material.SmoothPlastic)
	part.Transparency = 1
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local decal = Instance.new("Decal")
		decal.Face = face
		decal.Texture = image
		decal.Color3 = color
		decal.Transparency = transparency
		decal.Parent = part
	end
	return part
end

-- Its jaws now (Jaw_0, else high at its front), where its call and beams come from
function RiftFx.jaws(root: BasePart, height: number): Vector3
	local body = root:FindFirstAncestorOfClass("Model")
	local jaw = if body then body:FindFirstChild("Jaw_0", true) else nil
	if jaw and jaw:IsA("Bone") then
		return jaw.WorldPosition
	end
	return root.Position + UP * height * 0.45 + root.CFrame.LookVector * height * 0.5
end

-- It calls its summons: a void shockwave out from it, a dark burst at its jaws, a shake and its call
function RiftFx.call(root: BasePart, height: number)
	local call = RIFT.call
	local jaws = RiftFx.jaws(root, height)
	local ground = Vector3.new(root.Position.X, root.Position.Y + 0.3, root.Position.Z)
	ElementFx.burst(jaws, CORE, 2.5)
	ElementFx.burst(jaws, COLOR, 1.8)
	ElementFx.ring(ground, COLOR, call.wave, call.waveSeconds)
	task.delay(0.12, function()
		ElementFx.ring(ground, CORE, call.wave * 0.7, call.waveSeconds)
	end)
	ElementFx.sound(RIFT.sounds.call, jaws, 1.1)
	ScreenFx.shakeAt(call.shake, ground)
end

-- A rift at `at` (on the ground) for a summon `tall` studs high climbing out over `emerge` seconds, a beam to it from
-- `from` (the boss's jaws)
function RiftFx.open(from: Vector3, at: Vector3, tall: number, emerge: number)
	local tear = RIFT.tear
	local ground = CFrame.new(at + UP * RIFT.pool.lift)
	ElementFx.bolt(from, at + UP * tall * 0.6, COLOR, RIFT.call.beamSeconds, RIFT.call.beamWidth, true)
	ElementFx.sound(RIFT.sounds.crack, at, 1)
	ElementFx.sound(RIFT.sounds.open, at, 1.1)

	-- the pool of void on the ground, a violet rim round it
	local poolRadius = RIFT.pool.radius * tall
	local pool, poolDecal = flat(SwordFx.RING_GLOW, CORE, 0.05, ground, 0.1)
	local rim, rimDecal = flat(SwordFx.RING_OUTLINE, COLOR, 0.1, ground, 0.1)
	local grow = TweenInfo.new(tear.open, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local across = poolRadius * 2
	TweenService:Create(pool, grow, { Size = Vector3.new(across, 0.05, across) }):Play()
	TweenService:Create(rim, grow, { Size = Vector3.new(across * 1.1, 0.05, across * 1.1) }):Play()

	-- the rift: a round portal standing on the ground, facing this player's camera: a soft violet halo, a bright violet
	-- ring and a dark void inside it, opening out
	local across = tear.size * tall
	local centre = at + UP * (across / 2 + 0.3)
	local halo = disc(TEXTURES.glow, COLOR, 0.3, centre)
	local ring = disc(TEXTURES.ring, GLOW, 0, centre)
	local core = disc(TEXTURES.glow, CORE, 0, centre)
	local discs = { { halo, 1.45 }, { ring, 1 }, { core, 0.8 } }
	local opening = TweenInfo.new(tear.open, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for _, entry in discs do
		local side = across * entry[2]
		TweenService:Create(entry[1], opening, { Size = Vector3.new(side, side, 0.05) }):Play()
	end
	local light = Instance.new("PointLight")
	light.Color = COLOR
	light.Brightness = tear.light.brightness
	light.Range = tear.light.range
	light.Shadows = false
	light.Parent = ring

	-- motes pulling in from round it
	local holder = piece(Vector3.one * math.max(2, tall * RIFT.motes.reach * 2), COLOR, CFrame.new(centre), Enum.Material.SmoothPlastic)
	holder.Shape = Enum.PartType.Ball
	holder.Transparency = 1
	local pull = ElementFx.emitter(holder, "spark", COLOR, {
		size = { tall * 0.07, tall * 0.02 },
		life = 0.5,
		speed = { -tall * 1.4, -tall * 1.8 },
		rotation = 0,
		orientation = Enum.ParticleOrientation.VelocityParallel,
		brightness = 2,
	})
	pull.Shape = Enum.ParticleEmitterShape.Sphere
	pull.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pull.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	pull.Rate = math.round(RIFT.motes.rate * ElementFx.detailShare())

	-- it turns to face this player's camera for as long as it's there (a flat disc seen edge-on is a line)
	local turning = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not ring.Parent or not camera then
			return
		end
		local eye = camera.CFrame.Position
		local toward = Vector3.new(eye.X - centre.X, 0, eye.Z - centre.Z)
		if toward.Magnitude > 0.1 then
			local frame = CFrame.lookAt(centre, centre + toward.Unit)
			halo.CFrame = frame * CFrame.new(0, 0, 0.05)
			ring.CFrame = frame
			core.CFrame = frame * CFrame.new(0, 0, -0.05)
		end
	end)

	-- crackles off its rim while it's open
	local started = os.clock()
	local nextCrackle = 0
	local stepping = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - started
		if elapsed < nextCrackle then
			return
		end
		nextCrackle = elapsed + 1 / math.max(1, tear.crackles * ElementFx.detailShare())
		local angle = math.random() * math.pi * 2
		local reach = across / 2
		local a = ring.CFrame * CFrame.new(math.cos(angle) * reach, math.sin(angle) * reach, 0)
		local b = ring.CFrame * CFrame.new(math.cos(angle) * reach * 1.6, math.sin(angle) * reach * 1.6, 0)
		ElementFx.bolt(a.Position, b.Position, COLOR, 0.12, 0.6, true)
	end)

	-- out it comes: a burst, then the tear closes and the pool fades
	task.delay(math.max(0, emerge), function()
		stepping:Disconnect()
		pull.Rate = 0
		local out = at + UP * tall * 0.5
		ElementFx.burst(out, CORE, RIFT.burst.scale)
		ElementFx.burst(out, COLOR, RIFT.burst.scale * 0.7)
		ElementFx.eruption(at, COLOR, tall * 0.7, math.round(RIFT.burst.shards * ElementFx.detailShare()))
		ElementFx.sound(RIFT.sounds.burst, at, 1)
		task.delay(RIFT.close, function()
			local shut = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for _, entry in discs do
				TweenService:Create(entry[1], shut, { Size = Vector3.new(0.05, 0.05, 0.05) }):Play()
			end
			TweenService:Create(light, shut, { Brightness = 0 }):Play()
			local fade = TweenInfo.new(RIFT.pool.fade)
			TweenService:Create(poolDecal, fade, { Transparency = 1 }):Play()
			TweenService:Create(rimDecal, fade, { Transparency = 1 }):Play()
			task.delay(0.3, function()
				turning:Disconnect()
			end)
			for _, entry in discs do
				Debris:AddItem(entry[1], 0.3)
			end
			Debris:AddItem(holder, 0.6)
			Debris:AddItem(pool, RIFT.pool.fade + 0.1)
			Debris:AddItem(rim, RIFT.pool.fade + 0.1)
		end)
	end)
end

return RiftFx
