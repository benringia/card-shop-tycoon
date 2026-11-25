--!strict
-- A beaten wild monster's knockout on this client (owner 2026-11-18, pick A "make it smooth"; Config/MonsterKO): the
-- last hit freezes it a beat (a white flash, a swell, a camera kick), then it's launched away from the winner tumbling
-- end over end (Shared/Util/MonsterKOMotion, stepped every frame: its own gravity, bounces on the ground with a dust puff
-- and a thud, bumps off walls and rocks), plops onto its back with dizzy stars circling, and poofs into smoke and
-- sparkles. MonsterController hands the model over (it no longer follows its marker) and it's gone at the end. The
-- winner's coins come at the poof (`coins`, BattleController).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AttackFx = require(Config:WaitForChild("AttackFx"))
local KO = require(Config:WaitForChild("MonsterKO"))
local UIIcons = require(Config:WaitForChild("UIIcons"))
local MonsterKOMotion = require(Shared:WaitForChild("Util"):WaitForChild("MonsterKOMotion"))
local FinishingBlowRules = require(Shared:WaitForChild("Util"):WaitForChild("FinishingBlowRules"))

local ClientUtil = script.Parent :: Instance
local HitFx = require(ClientUtil:WaitForChild("HitFx"))
local ScreenFx = require(ClientUtil:WaitForChild("ScreenFx"))
local SoundBank = require(ClientUtil:WaitForChild("SoundBank"))

local MonsterKO = {}

export type Handle = {
	onPoof: (callback: (at: Vector3) -> ()) -> (), -- right away if it has poofed already
	onDone: (callback: () -> ()) -> (),
}

local STAR_COLOR = Color3.fromRGB(255, 212, 70)
local DUST_COLOR = Color3.fromRGB(236, 226, 206)
local SMOKE_COLOR = Color3.fromRGB(255, 255, 255)
local SPARKLE_COLOR = Color3.fromRGB(255, 226, 120)
local WALL_FACING = 0.6 -- a surface facing up less than this is a wall to bump off, not ground

local function range(pair: { number }, scale: number): NumberRange
	return NumberRange.new(pair[1] * scale, pair[2] * scale)
end

local function anchor(at: Vector3, life: number): Part
	local part = Instance.new("Part")
	part.Name = "MonsterKOFx"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(at)
	part.Parent = workspace
	Debris:AddItem(part, life)
	return part
end

local function sound(spec: { id: string, volume: number }, at: Vector3, volume: number?)
	local part = anchor(at, 4)
	local made = SoundBank.make(spec.id)
	made.Volume = spec.volume * (volume or 1)
	made.RollOffMaxDistance = 120
	made.Parent = part
	made:Play()
end

-- A burst of particles at `at` for a monster `height` studs tall (a Config/MonsterKO spec: count, sizes times its height,
-- speeds, lifetimes): `glow` 0 lit like dust, 1 shining; `upward` a puff off the ground, else every way; `front` studs
-- drawn toward the camera (the poof covers the monster shrinking inside it)
local function burst(at: Vector3, texture: string, color: Color3, spec: any, height: number, glow: number, upward: boolean, front: number)
	local part = anchor(at, 2)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = glow
	emitter.LightInfluence = 1 - glow * 0.6
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(spec.lifetime[1], spec.lifetime[2])
	emitter.Speed = range(spec.speed, math.sqrt(math.max(height, 1) / 3))
	emitter.SpreadAngle = if upward then Vector2.new(70, 70) else Vector2.new(180, 180)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Drag = 7
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec.size[1] * height),
		NumberSequenceKeypoint.new(1, spec.size[2] * height),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if glow > 0.5 then 0 else 0.1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.ZOffset = front
	emitter.Parent = part
	emitter:Emit(spec.count)
end

-- Dizzy stars circling over `part` (a BillboardGui: they always face you); returns its gui and a step(dt, show 0-1)
local function stars(part: BasePart, height: number): (BillboardGui, (number, number) -> ())
	local cfg = KO.stars
	local gui = Instance.new("BillboardGui")
	gui.Name = "DizzyStars"
	gui.Size = UDim2.fromScale(height * cfg.orbit * 2.6, height * cfg.orbit * 1.4)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.MaxDistance = KO.range
	gui.Adornee = part
	gui.Parent = part
	local icons: { ImageLabel } = {}
	for _ = 1, cfg.count do
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Image = UIIcons.Star
		icon.ImageColor3 = STAR_COLOR
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.ImageTransparency = 1
		icon.Parent = gui
		table.insert(icons, icon)
	end
	local turn = 0
	return gui, function(dt: number, show: number)
		turn += dt * cfg.speed * math.pi * 2
		for index, icon in icons do
			local angle = turn + (index - 1) / #icons * math.pi * 2
			local depth = (math.sin(angle) + 1) / 2 -- 0 behind, 1 in front
			icon.Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.4, 0.5 + math.sin(angle) * 0.22)
			local size = cfg.size * (0.75 + depth * 0.35)
			icon.Size = UDim2.fromScale(size / (cfg.orbit * 2.6), size / (cfg.orbit * 1.4))
			icon.Rotation = math.deg(turn) * 0.5
			icon.ImageTransparency = 1 - show * (0.55 + depth * 0.45)
			icon.ZIndex = if depth > 0.5 then 2 else 1
		end
	end
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Ease out with a little overshoot past the end: the plop onto its back
local function backOut(x: number): number
	x = math.clamp(x, 0, 1)
	local c = 1.6
	return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2
end

-- Shrink with a swell first: the poof
local function backIn(x: number): number
	x = math.clamp(x, 0, 1)
	local c = 1.4
	return (c + 1) * x ^ 3 - c * x ^ 2
end

-- The knockout of `model` (a monster's, now this module's), flying along `away` (flat, from the winner); an `elite`
-- is hit harder; your own fight's last hit (`moment`, Config/FinishingBlow WILD) holds the beat longer and launches
-- and kicks harder (Util/FinishingBlowRules.knockout)
function MonsterKO.play(model: Model, away: Vector3, elite: boolean, moment: FinishingBlowRules.Moment?): Handle
	local poofWaiting: { (Vector3) -> () } = {}
	local doneWaiting: { () -> () } = {}
	local poofedAt: Vector3? = nil
	local finished = false

	local pivot = model:GetPivot()
	local box, size = model:GetBoundingBox()
	local offset = pivot:ToObjectSpace(box) -- its middle from its pivot
	local startTurn = box.Rotation
	local baseScale = model:GetScale()
	local flat = Vector3.new(away.X, 0, away.Z)
	local dir = if flat.Magnitude > 0.05 then flat.Unit else -Vector3.new(box.LookVector.X, 0, box.LookVector.Z).Unit
	if dir ~= dir then
		dir = Vector3.xAxis -- looking straight up or down: any way will do
	end
	local axis = Vector3.yAxis:Cross(dir) -- turning about this tips its top away from the winner: a backflip
	-- its height and its length along the flight, for where its middle sits over the ground as it turns
	local height = size.Y
	local depth = math.abs(dir:Dot(box.LookVector)) * size.Z + math.abs(dir:Dot(box.RightVector)) * size.X
	local hitStop, power, kick = FinishingBlowRules.knockout(KO, elite, moment)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local skip: { Instance } = { model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	local markers = workspace:FindFirstChild("Monsters")
	if markers then
		table.insert(skip, markers)
	end
	params.FilterDescendantsInstances = skip

	local start = box.Position
	local groundY = start.Y - height / 2
	-- the ground from about its top down (not from higher up: it would land on a branch over it)
	local function groundUnder(at: Vector3): number
		local hit = workspace:Raycast(at + Vector3.new(0, height / 2, 0), Vector3.new(0, -(height / 2 + 40), 0), params)
		if hit then
			groundY = hit.Position.Y
		end
		return groundY
	end
	groundUnder(start)

	-- Puts it with its middle at `at`, turned `angle` degrees end over end, at `scale` of its size
	local function pose(at: Vector3, angle: number, scale: number)
		if scale ~= 1 then
			model:ScaleTo(baseScale * math.max(scale, 0.02))
		end
		local scaled = CFrame.new(offset.Position * math.max(scale, 0.02)) * offset.Rotation
		model:PivotTo(CFrame.new(at) * CFrame.fromAxisAngle(axis, math.rad(angle)) * startTurn * scaled:Inverse())
	end

	local function finish()
		if finished then
			return
		end
		finished = true
		local at = poofedAt or Vector3.new(start.X, groundY, start.Z)
		if not poofedAt then
			poofedAt = at
			for _, callback in poofWaiting do
				task.spawn(callback, at)
			end
		end
		poofWaiting = {}
		if model.Parent then
			model:Destroy()
		end
		for _, callback in doneWaiting do
			task.spawn(callback)
		end
		doneWaiting = {}
	end

	-- The hit: a white flash, a swell and a camera kick, held a beat
	HitFx.flash(model, Color3.new(1, 1, 1), 0.3, 0.1)
	ScreenFx.shakeAt(kick, start)

	local state = MonsterKOMotion.launch(start.X, start.Y, start.Z, dir.X, dir.Z, KO, power)
	local phase = "hit"
	local clock = 0
	local settleFrom: { angle: number, y: number }? = nil
	local rest: { angle: number, y: number }? = nil
	local phaseAt = 0
	local starGui: BillboardGui? = nil
	local stepStars: ((number, number) -> ())? = nil
	local starPart: Part? = nil

	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt)
		if finished or not model.Parent then
			connection:Disconnect()
			if starPart then
				starPart:Destroy()
			end
			finish()
			return
		end
		clock += dt
		if phase == "hit" then
			local beat = math.clamp(clock / hitStop, 0, 1)
			pose(start, 0, 1 + (KO.pop - 1) * math.sin(beat * math.pi))
			if clock >= hitStop then
				pose(start, 0, 1)
				model:ScaleTo(baseScale)
				phase, phaseAt = "fly", clock
				sound(KO.sounds.launch, start)
			end
			return
		end
		if phase == "fly" then
			local ground = groundUnder(Vector3.new(state.x, state.y, state.z))
			-- a wall or a rock in the way: it bounces back off it
			local along = Vector3.new(state.vx, 0, state.vz)
			if along.Magnitude > 0.5 then
				local reach = along.Unit * (along.Magnitude * dt + depth / 2)
				local hit = workspace:Raycast(Vector3.new(state.x, state.y, state.z), reach, params)
				if hit and math.abs(hit.Normal.Y) < WALL_FACING then
					state = MonsterKOMotion.bump(state, hit.Normal.X, hit.Normal.Z, KO)
					burst(hit.Position, KO.PUFF, DUST_COLOR, KO.dust, height, 0, false, 0.5)
				end
			end
			local event
			state, event = MonsterKOMotion.step(state, dt, ground, height, depth, KO)
			pose(Vector3.new(state.x, state.y, state.z), state.angle, 1)
			if event then
				local feet = Vector3.new(state.x, ground, state.z)
				burst(feet, KO.PUFF, DUST_COLOR, KO.dust, height, 0, true, 0.5)
				sound(KO.sounds.bounce, feet, if event == "bounce" then 1 else 0.8)
				ScreenFx.shakeAt(KO.bounceShake, feet)
			end
			if state.settled then
				local restAngle = MonsterKOMotion.rest(state.angle, height, depth)
				settleFrom = { angle = state.angle, y = state.y }
				rest = { angle = restAngle, y = ground + MonsterKOMotion.halfHeight(restAngle, height, depth) }
				phase, phaseAt = "settle", clock
			end
			return
		end
		local at = Vector3.new(state.x, state.y, state.z)
		if phase == "settle" then
			local from, to = settleFrom :: { angle: number, y: number }, rest :: { angle: number, y: number }
			local share = (clock - phaseAt) / KO.settleSeconds
			local angle = from.angle + (to.angle - from.angle) * backOut(share)
			local y = from.y + (to.y - from.y) * smooth(share)
			pose(Vector3.new(at.X, y, at.Z), angle, 1)
			if share >= 1 then
				state.y = to.y
				state.angle = to.angle
				local top = to.y + MonsterKOMotion.halfHeight(to.angle, height, depth) + height * KO.stars.above
				starPart = anchor(Vector3.new(at.X, top, at.Z), KO.holdSeconds + KO.poofSeconds + 1)
				starGui, stepStars = stars(starPart :: Part, height)
				phase, phaseAt = "dizzy", clock
			end
			return
		end
		if phase == "dizzy" then
			local held = clock - phaseAt
			if stepStars then
				stepStars(dt, math.clamp(held / 0.15, 0, 1))
			end
			if held >= KO.holdSeconds then
				phase, phaseAt = "poof", clock
				local middle = Vector3.new(at.X, state.y, at.Z)
				burst(middle, KO.PUFF, SMOKE_COLOR, KO.smoke, height, 0.35, false, height * 0.4)
				burst(middle, AttackFx.TEXTURES.goldStars, SPARKLE_COLOR, KO.sparkles, height, 1, false, height * 0.5)
				sound(KO.sounds.poof, middle)
				poofedAt = middle
				for _, callback in poofWaiting do
					task.spawn(callback, middle)
				end
				poofWaiting = {}
			end
			return
		end
		-- poof: it swells a touch, then shrinks away into the smoke; the stars go with it
		local share = (clock - phaseAt) / KO.poofSeconds
		pose(Vector3.new(at.X, state.y, at.Z), state.angle, 1 - backIn(share))
		if stepStars then
			stepStars(dt, 1 - math.clamp(share, 0, 1))
		end
		if share >= 1 then
			connection:Disconnect()
			if starGui then
				starGui:Destroy()
			end
			if starPart then
				starPart:Destroy()
			end
			finish()
		end
	end)

	return {
		onPoof = function(callback: (Vector3) -> ())
			if poofedAt then
				task.spawn(callback, poofedAt)
			else
				table.insert(poofWaiting, callback)
			end
		end,
		onDone = function(callback: () -> ())
			if finished then
				task.spawn(callback)
			else
				table.insert(doneWaiting, callback)
			end
		end,
	}
end

-- The winner's coins popping out of the poof (`from`, the screen) into their cash, with a jingle
function MonsterKO.coins(from: Vector2, elite: boolean)
	local Controllers = (ClientUtil.Parent :: Instance):WaitForChild("Controllers")
	local UIController = require(Controllers:WaitForChild("UIController")) :: any
	local CoinBurst = require(ClientUtil:WaitForChild("CoinBurst"))
	local pill = UIController.GetCashPill()
	if not pill or not pill.Visible then
		return
	end
	local count = KO.coins * (if elite then KO.elite.coins else 1)
	CoinBurst.fly(UIController.GetScreenGui(), from, pill, count)
	local jingle = SoundBank.make(KO.sounds.coins.id)
	jingle.Volume = KO.sounds.coins.volume
	jingle.Parent = workspace
	jingle:Play()
	Debris:AddItem(jingle, 4)
end

return MonsterKO
