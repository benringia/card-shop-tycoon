--!strict
-- The effects of the originals' signature idles (Party.SIGNATURE), on this client only, fired once by
-- Util/CreatureVisuals when Util/PetRig says the fidget's moment has come:
-- * butterfly (Sprouthop): a little butterfly appears on the raised hand in a puff of sparkles, flutters round the
--   head and flies off.
-- * thunderroar (Boltlynx): lightning crackles round its head and leaps off its ear and tail bolts in three bursts,
--   with a flash.
-- * voidroar (Voidmaw): dark void smoke bursts from every mouth.
-- * stormroar (Stormjack): lightning leaps between its mouths in four bursts.
-- * firebreath (Infernox): a cone of fire pours from its mouth for a moment, lighting up round it.
-- * shellcrack (Puffpuddle, a sea otter): sitting up, a blue clam appears between its front paws and sparkles as
--   it taps it; rolling over (roll) puffs up dust.
-- * sneeze (Blazehound): a little puff of flame, embers and smoke from its nose.
-- * hiccup (Cindercub): three hiccups, each puffing a little flame and a smoke ring from its mouth.
-- * zaphop (Zappit): at the top of a big bunny jump, lightning crackles up off its ear and tail bolts with sparks.
-- * sporepuff (Mossmole): up on its toes, glowing teal spores rise from the mushroom garden it hugs, with a soft glow.
-- * petaltwirl (Petalpaw): a happy spin while pink petals swirl out round it.
-- * shadowloop (Gloomlet): a loop-the-loop in the air trailing violet shadow smoke, sparkles off its ear wisps.
-- * emberflap (Ashbeak): a flapping hop; at the top, a flame bursts from its crest with a puff of embers.
-- * shypeek (Shellshy): ducks shyly into its shell, then peeks out with rising bubbles and aqua sparkles.
-- * buzzzap (Fizzlebug): a zigzag buzz up into the air; at the top a bolt shoots down from its stinger.
-- * ghostfloat (Wispurr): drifts up fading half see-through, violet wisps swirling round it, then comes back solid.
-- * flameswoop (Emberwing): climbs, then dives nose-down with fire streaming off its wing tips and tail.
-- * tidecall (Tidecaller): rears up and stamps down; a ring of water splashes out round it with spray.
-- * thorncharge (Briarhorn): head down, a short charge forward; thorny vines burst up in front of it with petals.
-- * kungfu (Thornback): leaves whirl out round it as it chops.
-- * eclipse (Eclipse Fox): a dark orb ringed with golden light rises over its head, glowing violet, then fades.
-- * backflip (Duskstalker): shadow smoke where it takes off and a smoky trail through the flip.
-- * solarroar (Solarion): fire bursts from every mouth with a flash of sunlight.
-- * voltcharge (Voltkit): lightning arcs between its raised fists, building up, then a bolt shoots into the sky.
-- (Roars also get CreatureVisuals' shockwave ring and sparks.) Everything is anchored, never collides, and cleans
-- itself up, also if the creature is removed first.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Party = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Party"))

local SignatureFx = {}

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local BUTTERFLY_COLORS = { Color3.fromRGB(120, 190, 255), Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 220, 90), Color3.fromRGB(190, 150, 255) }
local BUTTERFLY_SECONDS = 3.6
local LIGHTNING_COLOR = Color3.fromRGB(255, 246, 170)
local VOID_COLOR = Color3.fromRGB(120, 50, 200)
local THUNDER_TIPS = { "Ear_Left_0", "Ear_Right_0", "Tail_3" }
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
			-- Lightning also leaps up off the bolts on its ear tips and tail tip
			for _, name in THUNDER_TIPS do
				local tip = bonePosition(model, name)
				if tip then
					local up = Vector3.new(rng:NextNumber(-0.4, 0.4), 1, rng:NextNumber(-0.4, 0.4)).Unit
					bolt(tip + Vector3.yAxis * 0.3 * size, tip + up * rng:NextNumber(0.8, 1.2) * size, 0.05 * size)
				end
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

-- Between a four-legged creature's front paws (where a sitting-up sea otter holds its shell)
local function frontPaws(model: Model): Vector3?
	local left, right = bonePosition(model, "0_Left_Limb_2"), bonePosition(model, "0_Right_Limb_2")
	return if left and right then (left + right) / 2 else nil
end

-- A sea otter sitting up, a blue clam shell appearing between its front paws as it taps it, a little sparkle with
-- each tap (in step with PetRig's taps), then the shell fading away
local function shellcrack(model: Model, size: number)
	local folder = Instance.new("Folder")
	folder.Name = "Shell"
	local shell = fxPart(Vector3.new(0.34, 0.1, 0.28) * size * 0.6, Color3.fromRGB(110, 170, 230), false)
	local stripe = fxPart(Vector3.new(0.05, 0.11, 0.28) * size * 0.6, Color3.fromRGB(180, 220, 255), false)
	shell.Parent, stripe.Parent = folder, folder
	folder.Parent = workspace
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - start
		local paws = frontPaws(model)
		if not paws or not model.Parent or t > 2.2 then
			connection:Disconnect()
			folder:Destroy()
			return
		end
		local at = CFrame.new(paws) * model:GetPivot().Rotation * CFrame.new(0, 0.05 * size, -0.08 * size)
		shell.CFrame, stripe.CFrame = at, at
		local fade = math.clamp((t - 1.8) / 0.4, 0, 1)
		shell.Transparency, stripe.Transparency = fade, fade
	end)
	for _, delay in { 0.19, 0.94, 1.69 } do
		task.delay(delay, function()
			local paws = frontPaws(model)
			if paws and model.Parent then
				burst(CFrame.lookAt(paws, paws + Vector3.yAxis), SPARKLES, ColorSequence.new(Color3.fromRGB(200, 235, 255)), 8, 0.25 * size, 3 * size, 0.5)
			end
		end)
	end
end

-- Rolling over on the ground: a puff of dust as it comes round
local function rollDust(model: Model, size: number)
	local at = model:GetPivot().Position
	burst(CFrame.lookAt(at, at + Vector3.yAxis), SMOKE, ColorSequence.new(Color3.fromRGB(190, 180, 165)), 8, 0.8 * size, 2 * size, 0.9)
end

-- A sneeze: a little puff of flame, embers and smoke from the nose
local function sneeze(model: Model, size: number)
	local head = bonePosition(model, "Head_0")
	if not head then
		return
	end
	local forward = model:GetPivot().LookVector
	local nose = head + forward * 0.6 * size
	local aim = CFrame.lookAt(nose, nose + forward)
	burst(aim, "rbxasset://textures/particles/fire_main.dds", ColorSequence.new(Color3.fromRGB(255, 220, 110), Color3.fromRGB(255, 90, 30)), 14, 0.7 * size, 5 * size, 0.45)
	burst(aim, SPARKLES, ColorSequence.new(Color3.fromRGB(255, 190, 80)), 10, 0.3 * size, 7 * size, 0.6)
	burst(aim, SMOKE, ColorSequence.new(Color3.fromRGB(120, 110, 105)), 4, 0.8 * size, 2 * size, 0.8)
end

-- Hiccups: a little puff of flame and a smoke ring from the mouth with each hiccup (cued on the first; the others
-- follow at Party's HICCUP_BEATS)
local function hiccup(model: Model, size: number)
	local anim = Party.PET_ANIM
	local beats = anim.HICCUP_BEATS
	for _, beat in beats do
		task.delay((beat - beats[1]) * anim.FIDGET_SECONDS.hiccup, function()
			local head = bonePosition(model, "Head_0")
			if not head or not model.Parent then
				return
			end
			local forward = model:GetPivot().LookVector
			local mouth = head + forward * 0.85 * size
			local aim = CFrame.lookAt(mouth, mouth + forward + Vector3.new(0, 0.6, 0))
			burst(aim, "rbxasset://textures/particles/fire_main.dds", ColorSequence.new(Color3.fromRGB(255, 220, 110), Color3.fromRGB(255, 110, 40)), 6, 0.35 * size, 2.5 * size, 0.35)
			burst(aim, SMOKE, ColorSequence.new(Color3.fromRGB(150, 140, 135)), 3, 0.5 * size, 1.5 * size, 0.9)
		end)
	end
end

-- A zap hop: at the top of the jump lightning crackles up off its ear-tip and tail bolts, with a burst of sparks
local ZAP_TIPS = { "Ear_Left_1", "Ear_Right_1", "Tail_1" }
local function zaphop(model: Model, size: number)
	local centre = model:GetPivot().Position + Vector3.new(0, 1.2 * size, 0)
	burst(CFrame.new(centre), SPARKLES, ColorSequence.new(Color3.fromRGB(150, 220, 255), LIGHTNING_COLOR), 16, 0.4 * size, 6 * size, 0.6)
	for wave = 0, 1 do
		task.delay(wave * 0.12, function()
			if not model.Parent then
				return
			end
			for _, name in ZAP_TIPS do
				local tip = bonePosition(model, name)
				if tip then
					local up = Vector3.new(rng:NextNumber(-0.5, 0.5), 1, rng:NextNumber(-0.5, 0.5)).Unit
					bolt(tip + Vector3.yAxis * 0.2 * size, tip + up * rng:NextNumber(0.7, 1.1) * size, 0.05 * size)
				end
			end
		end)
	end
end

-- A spore puff: glowing teal spores rise from the mushroom garden it hugs to its chest, with a soft teal glow
local SPORE_COLOR = Color3.fromRGB(110, 230, 210)
local function sporepuff(model: Model, size: number)
	local spine = bonePosition(model, "Spine_1")
	if not spine then
		return
	end
	local garden = spine + model:GetPivot().LookVector * 0.5 * size
	local up = CFrame.lookAt(garden, garden + Vector3.yAxis)
	burst(up, SPARKLES, ColorSequence.new(SPORE_COLOR, Color3.fromRGB(200, 255, 240)), 18, 0.35 * size, 2.5 * size, 1.6)
	burst(up, SMOKE, ColorSequence.new(SPORE_COLOR), 5, 0.6 * size, 1.2 * size, 1.4)
	local glow = Instance.new("Attachment")
	glow.WorldPosition = garden
	glow.Parent = workspace.Terrain
	local light = Instance.new("PointLight")
	light.Color = SPORE_COLOR
	light.Brightness = 2
	light.Range = 6 * size
	light.Parent = glow
	TweenService:Create(light, TweenInfo.new(1.4), { Brightness = 0 }):Play()
	task.delay(1.5, glow.Destroy, glow)
end

-- A thorn charge: as it lunges, thorny vines burst up from the ground in front of it with pink petals and dust
local function thorncharge(model: Model, size: number)
	local pivot = model:GetPivot()
	local front = pivot.Position + pivot.LookVector * 1.6 * size
	for i = 1, 7 do
		local side = (i - 4) * 0.28 * size
		local base = front + pivot.RightVector * side
		local thorn = fxPart(Vector3.new(0.18, 0.1, 0.18) * size, Color3.fromRGB(70, 120, 55), false)
		thorn.CFrame = CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3))
		thorn.Parent = workspace
		local up = TweenService:Create(thorn, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.18, rng:NextNumber(0.9, 1.4), 0.18) * size, CFrame = thorn.CFrame * CFrame.new(0, 0.5 * size, 0) })
		up:Play()
		task.delay(0.9, function()
			local fade = TweenService:Create(thorn, TweenInfo.new(0.4), { Transparency = 1 })
			fade.Completed:Once(function()
				thorn:Destroy()
			end)
			fade:Play()
		end)
	end
	burst(CFrame.lookAt(front, front + Vector3.yAxis), SPARKLES, ColorSequence.new(Color3.fromRGB(255, 170, 205)), 16, 0.3 * size, 4 * size, 0.9)
	burst(CFrame.lookAt(front, front + Vector3.yAxis), SMOKE, ColorSequence.new(Color3.fromRGB(170, 150, 120)), 6, 0.8 * size, 2 * size, 0.8)
end

-- A tide call: as its front feet stamp down, a ring of water splashes out round it with spray and bubbles
local WATER = Color3.fromRGB(110, 210, 240)
local function tidecall(model: Model, size: number)
	local feet = model:GetPivot().Position
	for i = 1, 14 do
		local angle = i / 14 * math.pi * 2
		local drop = fxPart(Vector3.new(0.25, 0.25, 0.25) * size, WATER, false)
		drop.Shape = Enum.PartType.Ball
		drop.Transparency = 0.25
		drop.Position = feet + Vector3.new(math.cos(angle), 0.2, math.sin(angle)) * 0.6 * size
		drop.Parent = workspace
		local out = feet + Vector3.new(math.cos(angle) * 2.4, rng:NextNumber(0.8, 1.4), math.sin(angle) * 2.4) * size
		local splash = TweenService:Create(drop, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = out, Transparency = 1 })
		splash.Completed:Once(function()
			drop:Destroy()
		end)
		splash:Play()
	end
	burst(CFrame.lookAt(feet, feet + Vector3.yAxis), SPARKLES, ColorSequence.new(Color3.fromRGB(190, 245, 255)), 18, 0.35 * size, 5 * size, 0.8)
	burst(CFrame.lookAt(feet, feet + Vector3.yAxis), SMOKE, ColorSequence.new(Color3.fromRGB(200, 235, 245)), 6, 0.9 * size, 2 * size, 0.9)
end

-- A flame swoop: through the dive its wing tips and tail stream fire, with a burst of embers as it levels out
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local function flameswoop(model: Model, size: number)
	local seconds = Party.PET_ANIM.FIDGET_SECONDS.flameswoop * 0.6
	for step = 0, 6 do
		task.delay(step * seconds / 7, function()
			if not model.Parent then
				return
			end
			for _, name in { "Wing_Left_2", "Wing_Right_2", "Tail_3" } do
				local tip = bonePosition(model, name)
				if tip then
					burst(CFrame.lookAt(tip, tip + Vector3.yAxis), FIRE, ColorSequence.new(Color3.fromRGB(255, 220, 110), Color3.fromRGB(255, 80, 20)), 4, 0.5 * size, 1 * size, 0.5)
				end
			end
		end)
	end
	task.delay(seconds, function()
		local body = bonePosition(model, "Spine_0")
		if body and model.Parent then
			burst(CFrame.new(body), SPARKLES, ColorSequence.new(Color3.fromRGB(255, 170, 70)), 16, 0.3 * size, 5 * size, 0.8)
		end
	end)
end

-- A ghost float: it fades half see-through as it drifts up, violet wisps swirling round it, then comes back solid
local function ghostfloat(model: Model, size: number)
	local anim = Party.PET_ANIM
	local seconds = anim.FIDGET_SECONDS.ghostfloat
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local solid = part.Transparency
			local fade = TweenService:Create(part, TweenInfo.new(seconds * 0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true, seconds * 0.15),
				{ Transparency = solid + (1 - solid) * anim.GHOST_FADE })
			fade:Play()
		end
	end
	for wave = 0, 3 do
		task.delay(wave * seconds * 0.18, function()
			local body = bonePosition(model, "Spine_0")
			if body and model.Parent then
				burst(CFrame.lookAt(body, body + Vector3.yAxis), SMOKE, ColorSequence.new(Color3.fromRGB(190, 140, 255), Color3.fromRGB(120, 70, 200)), 4, 0.6 * size, 1 * size, 1.2)
				burst(CFrame.new(body), SPARKLES, ColorSequence.new(Color3.fromRGB(210, 170, 255)), 5, 0.25 * size, 2 * size, 0.8)
			end
		end)
	end
end

-- A buzz zap: at the top of its zigzag buzz, a bolt shoots down from its stinger and sparks fly off its antenna bolts
local function buzzzap(model: Model, size: number)
	local stinger = bonePosition(model, "Tail_0")
	if stinger then
		local ground = stinger - Vector3.new(rng:NextNumber(-0.5, 0.5), 2.2, rng:NextNumber(-0.5, 0.5)) * size
		bolt(stinger, ground, 0.06 * size)
		burst(CFrame.lookAt(ground, ground + Vector3.yAxis), SPARKLES, ColorSequence.new(Color3.fromRGB(150, 240, 255)), 12, 0.3 * size, 4 * size, 0.5)
	end
	for _, name in { "Ear_Left_0", "Ear_Right_0" } do
		local tip = bonePosition(model, name)
		if tip then
			burst(CFrame.lookAt(tip, tip + Vector3.yAxis), SPARKLES, ColorSequence.new(Color3.fromRGB(150, 240, 255), LIGHTNING_COLOR), 6, 0.25 * size, 3 * size, 0.4)
		end
	end
end

-- A shy peek: as it pops back out of its shell, bubbles rise and its shell's swirls sparkle aqua
local function shypeek(model: Model, size: number)
	local shell = bonePosition(model, "Spine_0")
	if not shell then
		return
	end
	local top = shell + Vector3.new(0, 0.5 * size, 0)
	local up = CFrame.lookAt(top, top + Vector3.yAxis)
	burst(up, "rbxasset://textures/particles/sparkles_main.dds", ColorSequence.new(Color3.fromRGB(150, 255, 240)), 14, 0.35 * size, 2.5 * size, 0.9)
	for i = 1, 8 do
		local bubble = fxPart(Vector3.one * rng:NextNumber(0.12, 0.22) * size, Color3.fromRGB(190, 240, 255), false)
		bubble.Shape = Enum.PartType.Ball
		bubble.Transparency = 0.4
		bubble.Position = top + Vector3.new(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)) * size
		bubble.Parent = workspace
		local rise = TweenService:Create(bubble, TweenInfo.new(rng:NextNumber(1, 1.6), Enum.EasingStyle.Sine),
			{ Position = bubble.Position + Vector3.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(1.5, 2.5), 0) * size, Transparency = 1 })
		rise.Completed:Once(function()
			bubble:Destroy()
		end)
		task.delay(i * 0.05, function()
			rise:Play()
		end)
	end
end

-- An ember flap: at the top of its flapping hop, a puff of embers and a little flame burst from its crest
local function emberflap(model: Model, size: number)
	local crest = bonePosition(model, "Ear_Left_0") or bonePosition(model, "Head_0")
	if not crest then
		return
	end
	local up = CFrame.lookAt(crest, crest + Vector3.yAxis)
	burst(up, "rbxasset://textures/particles/fire_main.dds", ColorSequence.new(Color3.fromRGB(255, 210, 100), Color3.fromRGB(255, 90, 30)), 10, 0.45 * size, 2.5 * size, 0.5)
	local body = model:GetPivot().Position + Vector3.new(0, 0.8 * size, 0)
	burst(CFrame.lookAt(body, body + Vector3.yAxis), SPARKLES, ColorSequence.new(Color3.fromRGB(255, 170, 70)), 14, 0.3 * size, 4 * size, 0.8)
end

-- A shadow loop: a trail of violet shadow smoke follows it round the loop, with sparkles off its ear wisps
local function shadowloop(model: Model, size: number)
	local duration = Party.PET_ANIM.FIDGET_SECONDS.shadowloop * 0.8
	for step = 0, 5 do
		task.delay(step * duration / 6, function()
			local body = bonePosition(model, "Spine_0")
			if not body or not model.Parent then
				return
			end
			burst(CFrame.new(body), SMOKE, ColorSequence.new(VOID_COLOR, Color3.fromRGB(30, 15, 45)), 4, 0.7 * size, 0.6 * size, 0.9)
			for _, name in { "Ear_Left_0", "Ear_Right_0" } do
				local ear = bonePosition(model, name)
				if ear then
					burst(CFrame.new(ear), SPARKLES, ColorSequence.new(Color3.fromRGB(200, 150, 255)), 3, 0.25 * size, 1.5 * size, 0.5)
				end
			end
		end)
	end
end

-- A petal twirl: pink petals swirl out round it as it spins, drifting up and fading
local PETAL_COLORS = { Color3.fromRGB(255, 170, 205), Color3.fromRGB(255, 205, 225), Color3.fromRGB(240, 130, 180) }
local function petaltwirl(model: Model, size: number)
	local centre = model:GetPivot().Position + Vector3.new(0, 1 * size, 0)
	for i = 1, 12 do
		local angle = i / 12 * math.pi * 2
		local petal = fxPart(Vector3.new(0.22, 0.03, 0.14) * size, PETAL_COLORS[(i % 3) + 1], false)
		petal.CFrame = CFrame.new(centre) * CFrame.Angles(0, angle, 0) * CFrame.new(0.5 * size, 0, 0)
		petal.Parent = workspace
		local out = CFrame.new(centre) * CFrame.Angles(0, angle + 2.2, 0) * CFrame.new(2 * size, 1.4 * size, 0)
			* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		local swirl = TweenService:Create(petal, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = out, Transparency = 1 })
		swirl.Completed:Once(function()
			petal:Destroy()
		end)
		swirl:Play()
	end
	burst(CFrame.lookAt(centre, centre + Vector3.yAxis), SPARKLES, ColorSequence.new(Color3.fromRGB(255, 200, 225)), 10, 0.3 * size, 3 * size, 0.8)
end

-- Kung fu: leaves whirl out round the creature with each chop
local function kungfu(model: Model, size: number)
	local centre = model:GetPivot().Position + Vector3.new(0, 1.2 * size, 0)
	local leafColors = { Color3.fromRGB(120, 200, 70), Color3.fromRGB(170, 225, 90), Color3.fromRGB(80, 150, 50) }
	for i = 1, 14 do
		local angle = i / 14 * math.pi * 2
		local leaf = fxPart(Vector3.new(0.25, 0.04, 0.18) * size, leafColors[(i % 3) + 1], false)
		leaf.CFrame = CFrame.new(centre) * CFrame.Angles(0, angle, 0) * CFrame.new(0.6 * size, 0, 0)
		leaf.Parent = workspace
		local out = CFrame.new(centre) * CFrame.Angles(0, angle + 1.4, 0) * CFrame.new(2.6 * size, 1 * size, 0) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		local whirl = TweenService:Create(leaf, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = out, Transparency = 1 })
		whirl.Completed:Once(function()
			leaf:Destroy()
		end)
		whirl:Play()
	end
	for _, name in { "Arm_Right_2", "Arm_Left_2" } do
		local hand = bonePosition(model, name)
		if hand then
			burst(CFrame.lookAt(hand, hand + model:GetPivot().LookVector), SPARKLES, ColorSequence.new(Color3.fromRGB(210, 255, 150)), 8, 0.35 * size, 5 * size, 0.5)
		end
	end
end

-- An eclipse rising over the head: a dark orb ringed with golden light, a faint violet glow, then fading
local function eclipse(model: Model, size: number)
	local head = bonePosition(model, "Head_0")
	if not head then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Eclipse"
	local radius = 0.7 * size
	local corona = fxPart(Vector3.one * radius * 2.5, Color3.fromRGB(255, 214, 110), true)
	corona.Shape = Enum.PartType.Ball
	corona.Transparency = 0.55
	local moon = fxPart(Vector3.one * radius * 2, Color3.fromRGB(16, 8, 26), false)
	moon.Shape = Enum.PartType.Ball
	moon.Material = Enum.Material.SmoothPlastic
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 110, 255)
	light.Brightness = 0
	light.Range = 12 * size
	light.Parent = moon
	corona.Parent, moon.Parent = folder, folder
	folder.Parent = workspace
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - start
		local now = bonePosition(model, "Head_0")
		if not now or not model.Parent or t > 2.8 then
			connection:Disconnect()
			folder:Destroy()
			return
		end
		-- Rising out of the head over half a second, hanging there while the corona pulses, fading at the end
		local rise = math.min(t / 0.5, 1)
		local fade = math.clamp((t - 2.3) / 0.5, 0, 1)
		local at = now + Vector3.new(0, (0.6 + 1.6 * rise) * size, 0)
		moon.Position = at
		corona.Position = at + model:GetPivot().LookVector * -0.05
		corona.Size = Vector3.one * radius * (2.4 + 0.25 * math.sin(t * 6)) * rise
		moon.Size = Vector3.one * radius * 2 * rise
		moon.Transparency = fade
		corona.Transparency = 0.55 + 0.45 * fade
		light.Brightness = 2 * rise * (1 - fade)
	end)
	burst(CFrame.lookAt(head, head + Vector3.yAxis), SPARKLES, ColorSequence.new(Color3.fromRGB(200, 150, 255), Color3.fromRGB(255, 220, 120)), 16, 0.35 * size, 4 * size, 0.9)
end

-- A backflip: a puff of shadow smoke where it takes off, and a smoky trail through the flip
local function backflip(model: Model, size: number)
	local shadow = ColorSequence.new(Color3.fromRGB(120, 70, 190), Color3.fromRGB(30, 15, 45))
	local feet = model:GetPivot().Position
	burst(CFrame.lookAt(feet, feet + Vector3.yAxis), SMOKE, shadow, 10, 0.9 * size, 2.5 * size, 0.9)
	for i = 1, 4 do
		task.delay(i * 0.18, function()
			local body = bonePosition(model, "Spine_0")
			if body and model.Parent then
				burst(CFrame.new(body), SMOKE, shadow, 4, 0.6 * size, 0.8 * size, 0.7)
			end
		end)
	end
end

-- A solar roar: fire bursting from every mouth and a flash of sunlight
local function solar(model: Model, size: number)
	local forward = model:GetPivot().LookVector
	local fire = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 20, 20)),
	})
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") and string.match(descendant.Name, "^Jaw_%d$") then
			local mouth = descendant.TransformedWorldCFrame.Position
			burst(CFrame.lookAt(mouth, mouth + forward + Vector3.new(0, 0.2, 0)), "rbxasset://textures/particles/fire_main.dds", fire, 16, 1.1 * size, 8 * size, 0.6)
		end
	end
	local at = model:GetPivot().Position + Vector3.new(0, 2 * size, 0)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = at
	holder.Parent = workspace.Terrain
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 70)
	light.Brightness = 5
	light.Range = 16 * size
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.9), { Brightness = 0 }):Play()
	task.delay(1, holder.Destroy, holder)
end

-- A volt charge: lightning arcing between the raised fists, building up, then a bolt shot up into the sky with a flash
local function voltcharge(model: Model, size: number)
	for i = 0, 9 do
		task.delay(i * 0.16, function()
			local left, right = bonePosition(model, "Arm_Left_2"), bonePosition(model, "Arm_Right_2")
			if not left or not right or not model.Parent then
				return
			end
			bolt(left, right, (0.04 + i * 0.005) * size)
			if i % 3 == 0 then
				local middle = (left + right) / 2
				burst(CFrame.lookAt(middle, middle + Vector3.yAxis), SPARKLES, ColorSequence.new(LIGHTNING_COLOR, Color3.fromRGB(120, 210, 255)), 6, 0.3 * size, 3 * size, 0.4)
			end
		end)
	end
	task.delay(1.7, function()
		local left, right = bonePosition(model, "Arm_Left_2"), bonePosition(model, "Arm_Right_2")
		if not left or not right or not model.Parent then
			return
		end
		local middle = (left + right) / 2
		for _ = 1, 3 do
			bolt(middle, middle + Vector3.new(rng:NextNumber(-1, 1), 9, rng:NextNumber(-1, 1)) * size, 0.12 * size)
		end
		local flash = Instance.new("Attachment")
		flash.WorldPosition = middle
		flash.Parent = workspace.Terrain
		local light = Instance.new("PointLight")
		light.Color = LIGHTNING_COLOR
		light.Brightness = 5
		light.Range = 14 * size
		light.Parent = flash
		TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
		task.delay(0.7, flash.Destroy, flash)
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
	elseif kind == "shellcrack" then
		shellcrack(model, size)
	elseif kind == "roll" then
		rollDust(model, size)
	elseif kind == "sneeze" then
		sneeze(model, size)
	elseif kind == "hiccup" then
		hiccup(model, size)
	elseif kind == "zaphop" then
		zaphop(model, size)
	elseif kind == "sporepuff" then
		sporepuff(model, size)
	elseif kind == "petaltwirl" then
		petaltwirl(model, size)
	elseif kind == "shadowloop" then
		shadowloop(model, size)
	elseif kind == "emberflap" then
		emberflap(model, size)
	elseif kind == "shypeek" then
		shypeek(model, size)
	elseif kind == "buzzzap" then
		buzzzap(model, size)
	elseif kind == "ghostfloat" then
		ghostfloat(model, size)
	elseif kind == "flameswoop" then
		flameswoop(model, size)
	elseif kind == "tidecall" then
		tidecall(model, size)
	elseif kind == "thorncharge" then
		thorncharge(model, size)
	elseif kind == "kungfu" then
		kungfu(model, size)
	elseif kind == "eclipse" then
		eclipse(model, size)
	elseif kind == "backflip" then
		backflip(model, size)
	elseif kind == "solarroar" then
		solar(model, size)
	elseif kind == "voltcharge" then
		voltcharge(model, size)
	end
end

return SignatureFx
