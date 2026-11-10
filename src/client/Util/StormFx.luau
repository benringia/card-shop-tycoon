--!strict
-- The Storm Sovereign's thunderclap (the owner 2026-11-11: "add animation and effects to thunderclap"; Config/AttackFx
-- STORM, numbers in Util/StormFxRules), drawn on this client by Util/FightFx and Util/DebuffFx. While it rears up: its
-- storm circle on the ground (an electric outline and a glow spreading from round it to the edge, lightning crackling
-- round the edge) and its crown crystal charging (a growing glow, sparks pulling in, arcs from its wing tips). The clap:
-- a flash on the crown, a bolt from the sky onto it, shockwaves out to the edge, bolts striking all over the circle, a
-- shake and a flash. An Electrocuted player's jolt: arcs flickering round them, a bright flicker, a zap. A pet the clap
-- stunned crackles for a moment.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("Config"):WaitForChild("AttackFx"))
local SwordFx = require(Shared:WaitForChild("Config"):WaitForChild("SwordFx"))
local StormFxRules = require(Shared:WaitForChild("Util"):WaitForChild("StormFxRules"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))
local RingFx = require((script.Parent :: Instance):WaitForChild("RingFx"))
local ScreenFx = require((script.Parent :: Instance):WaitForChild("ScreenFx"))

local StormFx = {}

local STORM = AttackFx.STORM
local UP = Vector3.yAxis
local WHITE = Color3.new(1, 1, 1)

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local COLOR = rgb(STORM.color)
local CORE = rgb(STORM.core)

-- A boss's bone by name (Bones follow its clips), nil when its model has none
local function bone(root: BasePart, name: string): Bone?
	local body = root:FindFirstAncestorOfClass("Model")
	local found = if body then body:FindFirstChild(name, true) else nil
	return if found and found:IsA("Bone") then found else nil
end

-- Its crown crystal now (Fx_Crown, else high on its body)
local function crownAt(root: BasePart, height: number): Vector3
	local crown = bone(root, "Fx_Crown")
	return if crown then crown.WorldPosition else root.Position + UP * height * 0.85
end

-- Its wing tips now: past its last wing bones, along them (none without them)
local function wingTips(root: BasePart, height: number): { Vector3 }
	local tips = {}
	for _, side in { "Left", "Right" } do
		local last, before = bone(root, `Wing_{side}_2`), bone(root, `Wing_{side}_1`)
		if last and before then
			local along = last.WorldPosition - before.WorldPosition
			local reach = if along.Magnitude > 1e-3 then along.Unit * height * 0.18 else Vector3.zero
			table.insert(tips, last.WorldPosition + reach)
		end
	end
	return tips
end

local function flat(image: string, color: Color3, transparency: number, centre: CFrame): (Part, Decal)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 0.05, 1)
	part.CFrame = centre
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = image
	decal.Color3 = color
	decal.Transparency = transparency
	decal.Parent = part
	part.Parent = ElementFx.folder()
	return part, decal
end

local function sized(part: Part, radius: number)
	local across = math.max(0.2, radius * 2)
	part.Size = Vector3.new(across, 0.05, across)
end

export type Windup = { centre: Vector3, radius: number, stop: (clapped: boolean) -> () }

-- It rears up for `seconds`: its storm circle of `radius` round `centre` (the boss's spot; the ground is found under
-- it) and its crown charging. stop(true) as it claps flashes the circle out; stop(false) just takes it away
function StormFx.windup(root: BasePart, height: number, centre: Vector3, radius: number, seconds: number): Windup
	local circle = STORM.circle
	local groundY = RingFx.groundY(centre.X, centre.Y, centre.Z) + circle.lift
	local ground = Vector3.new(centre.X, groundY, centre.Z)
	local place = CFrame.new(ground)
	local outline, outlineDecal = flat(SwordFx.RING_OUTLINE, COLOR, circle.outline, place)
	local glow, glowDecal = flat(SwordFx.RING_GLOW, COLOR, 1, place)
	sized(outline, radius)
	sized(glow, radius * StormFxRules.fillShare(0, seconds))

	-- the crown: a ball kept on it each frame (it follows the clip) holding a PointLight, a glow and sparks pulling in
	-- from its surface
	local holder = Instance.new("Part")
	holder.Name = "StormCrown"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Shape = Enum.PartType.Ball
	holder.Size = Vector3.one * math.max(2, height * 0.5)
	holder.CFrame = CFrame.new(crownAt(root, height))
	holder.Parent = ElementFx.folder()
	local pieces: { Instance } = { holder }
	local middle = Instance.new("Attachment") -- the glow and light from its middle, not all over the ball
	middle.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = COLOR
	light.Range = STORM.crown.light
	light.Brightness = 0
	light.Shadows = false
	light.Parent = middle
	table.insert(pieces, light)
	TweenService:Create(light, TweenInfo.new(math.max(seconds, 0.05)), { Brightness = 4 }):Play()
	local glowSize = height * STORM.crown.glow
	local aura = ElementFx.emitter(middle, "glow", COLOR, { size = { glowSize * 0.6, glowSize }, life = 0.25, rotation = 0, fade = 0.5, locked = true, brightness = 2 })
	aura.Rate = 16
	table.insert(pieces, aura)
	local pull = ElementFx.emitter(holder, "spark", CORE, {
		size = { height * 0.08, height * 0.02 },
		life = 0.45,
		speed = { -height * 0.9, -height * 1.2 },
		rotation = 0,
		orientation = Enum.ParticleOrientation.VelocityParallel,
		brightness = 2.2,
	})
	pull.Shape = Enum.ParticleEmitterShape.Sphere
	pull.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pull.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	pull.Rate = math.round(60 * ElementFx.detailShare())
	table.insert(pieces, pull)
	local at = crownAt(root, height)
	ElementFx.sound(STORM.sounds.charge, at, 1)
	ElementFx.sound(STORM.sounds.hum, ground, 0.8)

	local started = os.clock()
	local nextCrackle, nextArc = 0, 0
	local done = false
	local stepping: RBXScriptConnection
	stepping = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - started
		if done or not root.Parent then
			return
		end
		holder.CFrame = CFrame.new(crownAt(root, height))
		sized(glow, radius * StormFxRules.fillShare(elapsed, seconds))
		glowDecal.Transparency = 1 - circle.glow * math.clamp(elapsed / math.max(seconds, 0.05), 0.3, 1)
		-- crackles round the edge and arcs from the wing tips onto the crown, more as it nears the clap
		if elapsed >= nextCrackle then
			nextCrackle = elapsed + 1 / (circle.crackles * ElementFx.detailShare())
			local a, b = StormFxRules.edgeArc(math.random() * 360, radius, circle.span)
			ElementFx.bolt(ground + Vector3.new(a.x, 0.4, a.z), ground + Vector3.new(b.x, 0.4, b.z), COLOR, 0.14, 0.8, true)
		end
		if elapsed >= nextArc then
			local share = math.clamp(elapsed / math.max(seconds, 0.05), 0, 1)
			nextArc = elapsed + 1 / (STORM.crown.arcs * (0.5 + share))
			local tips = wingTips(root, height)
			if #tips > 0 then
				ElementFx.bolt(tips[math.random(1, #tips)], crownAt(root, height), CORE, 0.1, 0.6 + share * 0.6, true)
			end
		end
	end)

	local function stop(clapped: boolean)
		if done then
			return
		end
		done = true
		stepping:Disconnect()
		for _, item in pieces do
			if item:IsA("ParticleEmitter") then
				item.Rate = 0
			elseif item:IsA("PointLight") then
				item.Enabled = false
			end
		end
		Debris:AddItem(holder, 1) -- its sparks fade out first
		local fade = TweenInfo.new(if clapped then 0.6 else 0.25)
		if clapped then
			-- the whole circle flashes white-blue as it claps, then fades
			sized(glow, radius)
			glowDecal.Color3 = CORE
			glowDecal.Transparency = 0.15
			outlineDecal.Color3 = WHITE
			outlineDecal.Transparency = 0
		end
		TweenService:Create(glowDecal, fade, { Transparency = 1 }):Play()
		TweenService:Create(outlineDecal, fade, { Transparency = 1 }):Play()
		Debris:AddItem(outline, fade.Time + 0.1)
		Debris:AddItem(glow, fade.Time + 0.1)
	end
	-- a safety net: a lost clap event never leaves the circle on the ground
	task.delay(seconds + 3, function()
		stop(false)
	end)
	return { centre = ground, radius = radius, stop = stop }
end

-- It claps: everything at once over its storm circle (`centre` on the ground, `radius`)
function StormFx.clap(root: BasePart, height: number, centre: Vector3, radius: number)
	local clap = STORM.clap
	local crown = crownAt(root, height)
	ElementFx.bolt(crown + UP * 45, crown, CORE, 0.3, clap.crownBolt, true)
	ElementFx.burst(crown, COLOR, 3)
	ElementFx.sound(STORM.sounds.clap, crown, 1.2)
	ElementFx.sound(STORM.sounds.thunder, centre, 1.2)
	for wave = 1, clap.waves do
		task.delay((wave - 1) * 0.12, function()
			ElementFx.ring(centre, if wave == 1 then COLOR else CORE, radius, 0.45 + wave * 0.1)
		end)
	end
	local count = math.max(1, math.round(clap.strikes * ElementFx.detailShare()))
	for _, strike in StormFxRules.strikePoints(count, radius) do
		task.delay(strike.delay, function()
			local spot = Vector3.new(centre.X + strike.x, centre.Y, centre.Z + strike.z)
			local ground = Vector3.new(spot.X, RingFx.groundY(spot.X, spot.Y + 2, spot.Z), spot.Z)
			local top = ground + Vector3.new((math.random() - 0.5) * 8, clap.skyHeight, (math.random() - 0.5) * 8)
			ElementFx.bolt(top, ground, COLOR:Lerp(WHITE, 0.25), 0.28, clap.strikeScale)
		end)
	end
	ElementFx.sound(STORM.sounds.crackle, centre, 1)
	ScreenFx.shakeAt(clap.shake, centre)
	if ScreenFx.distance(centre) <= radius + AttackFx.SHAKE.NEAR then
		ScreenFx.flash(CORE, clap.flash.strength, clap.flash.seconds)
	end
end

-- Arcs flickering round a body for `seconds`: `count` at a time, redrawn every `flicker` seconds, round `root` within a
-- box `width` across and `tall` high
local function arcsRound(root: BasePart, width: number, tall: number, count: number, seconds: number, flicker: number, scale: number)
	task.spawn(function()
		local finish = os.clock() + seconds
		while os.clock() < finish and root.Parent do
			for _ = 1, count do
				local from = root.CFrame * CFrame.new((math.random() - 0.5) * width, (math.random() - 0.45) * tall, (math.random() - 0.5) * width * 0.6)
				local to = from.Position + Vector3.new((math.random() - 0.5), (math.random() - 0.5), (math.random() - 0.5)).Unit * (width * (0.5 + math.random() * 0.4))
				ElementFx.bolt(from.Position, to, CORE, flicker * 1.2, scale, true)
			end
			task.wait(flicker * 1.6)
		end
	end)
end

-- An Electrocuted player's jolt (the owner 2026-11-11: "stun for 1 sec every 3 seconds"): arcs round them, a bright
-- blue-white flicker over them, sparks and a zap, for `seconds`
function StormFx.jolt(character: Model, seconds: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local look = STORM.electrocuted
	local flash = Instance.new("Highlight")
	flash.FillColor = COLOR
	flash.OutlineColor = CORE
	flash.FillTransparency = look.fill
	flash.OutlineTransparency = 0
	flash.DepthMode = Enum.HighlightDepthMode.Occluded
	flash.Parent = character
	task.spawn(function()
		local finish = os.clock() + seconds
		local lit = true
		while os.clock() < finish and flash.Parent do
			lit = not lit
			flash.FillTransparency = if lit then look.fill else 0.75
			task.wait(look.flicker)
		end
		flash:Destroy()
	end)
	arcsRound(root, 3, 5.5, math.max(1, math.round(look.arcs * ElementFx.detailShare())), seconds, look.flicker, 0.6)
	ElementFx.burst(root.Position, COLOR, 0.6)
	ElementFx.sound(STORM.sounds.jolt, root.Position, 0.9)
end

-- A pet the clap stunned crackles for a moment
function StormFx.zapPet(root: BasePart, height: number, seconds: number)
	local zap = STORM.petZap
	local across = math.max(1.5, height * 0.8)
	arcsRound(root, across, height, zap.arcs, math.min(seconds, zap.seconds), STORM.electrocuted.flicker, 0.4 + height * 0.04)
	ElementFx.burst(root.Position + UP * height * 0.4, COLOR, 0.5 + height * 0.05)
end

return StormFx
