--!strict
-- The danger all the way down (spec 2026-11-12-dungeon-atmosphere; the owner: "immersive, sound, dangerous feels,
-- ambiance"): the Dungeon's eerie music with a heartbeat layer that grows towards the chamber, distant roars about
-- once a minute (louder room by room, a little dust and a tremble), the Hydra's eyes glimpsed for a moment in the dark
-- ahead, and spot sounds round you (drips, rubble, chains, whispers, crystal rings: Config/Soundscape DUNGEON). Looks
-- and sounds only, never damage; quiet during the welcome, softer in fights, the music out in the Hydra's fight (its
-- own drone plays). Timings and volumes: Config/Dungeon AMBIENCE, rules: Util/AmbienceRules. Studio: `/dungeonfx
-- roar|glimpse`. Dungeon place only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Cards = require(Config:WaitForChild("Cards"))
local Dungeon = require(Config:WaitForChild("Dungeon"))
local Soundscape = require(Config:WaitForChild("Soundscape"))
local SharedUtil = Shared:WaitForChild("Util")
local AmbienceRules = require(SharedUtil:WaitForChild("AmbienceRules"))
local DungeonRules = require(SharedUtil:WaitForChild("DungeonRules"))
local SoundscapeRules = require(SharedUtil:WaitForChild("SoundscapeRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DungeonAmbienceController = {}

local LOOK = Dungeon.AMBIENCE
local CHECK_EVERY = 0.25
local FADE = 2.5 -- seconds the music layers take to follow a change
local GLIMPSE_HEIGHT = 14
local EYE_SIZE = 1.8
local SOUND_TIMEOUT = 15 -- seconds before a one-shot is cleared even if it never played (a sound that fails to load)

local player = Players.LocalPlayer
local rng = Random.new()
local state: any = nil -- the last DungeonRun message
local fighting = false
local music: Sound
local heartbeat: Sound
local nextRoar = math.huge
local nextGlimpse = math.huge
local nextSpot: { [number]: number } = {}
local targets = { bed = -1, beat = -1 } -- the music layers' last volumes asked for

local function newSound(key: string, looped: boolean): Sound
	local spec = (Dungeon.SOUNDS :: any)[key]
	local made = Instance.new("Sound")
	made.Name = `DungeonAmbience_{key}`
	made.SoundId = spec.id
	made.Volume = 0
	made.Looped = looped
	made.PlaybackSpeed = spec.pitch or 1
	made.Parent = SoundService
	return made
end

-- Steps of the run done, from the run's message (the stage and its room)
local function stepsDone(): number
	if not state then
		return 0
	end
	local stage = state.stage
	if stage == "room" then
		return DungeonRules.doneBefore(Dungeon.STEPS, state.room or 1)
	elseif stage == "boss" or stage == "won" then
		return #Dungeon.STEPS
	end
	local index = DungeonRules.stepIndex(Dungeon.STEPS, stage)
	return if index then index - 1 else 0
end

local function quiet(): boolean
	return player:GetAttribute("DungeonIntroPlaying") == true
		or state == nil
		or state.stage == "waiting"
		or state.stage == "out"
		or state.stage == "won"
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function oneShot(key: string, volume: number, at: Vector3?)
	local spec = (Dungeon.SOUNDS :: any)[key]
	local holder: Instance = SoundService
	local attachment: Attachment? = nil
	if at then
		attachment = Instance.new("Attachment")
		;(attachment :: Attachment).WorldPosition = at
		;(attachment :: Attachment).Parent = workspace.Terrain
		holder = attachment :: Attachment
	end
	local sound = Instance.new("Sound")
	sound.SoundId = spec.id
	sound.Volume = volume
	sound.PlaybackSpeed = (spec.pitch or 1) * rng:NextNumber(0.9, 1.05)
	sound.Parent = holder
	local holderToClear: Instance = attachment or sound
	sound.Ended:Connect(function()
		holderToClear:Destroy()
	end)
	task.delay(SOUND_TIMEOUT, function()
		if holderToClear.Parent then
			holderToClear:Destroy() -- a sound that never loaded never ends
		end
	end)
	sound:Play()
end

-- The camera trembles a little (on top of the normal camera, never fighting it; a scripted camera, a chest's or a
-- weapon's stage, is left alone, or the offsets would add up)
local function tremble(studs: number, seconds: number)
	local name = `DungeonTremble{os.clock()}`
	local started = os.clock()
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - started
		if t >= seconds then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local fade = 1 - t / seconds
		local camera = workspace.CurrentCamera
		if camera.CameraType ~= Enum.CameraType.Custom then
			return
		end
		camera.CFrame += Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * studs * fade
	end)
end

local function dust(at: Vector3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(24, 1, 24)
	part.Position = at
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(140, 130, 150))
	emitter.Transparency = NumberSequence.new(0.7, 1)
	emitter.Size = NumberSequence.new(1, 2.5)
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.Acceleration = Vector3.new(0, -5, 0)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Rate = 0
	emitter.Parent = part
	part.Parent = workspace
	emitter:Emit(20)
	task.delay(3, part.Destroy, part)
end

-- A distant roar from deep below: louder room by room, softer in a fight; dust and a tremble round you
local function roar()
	local volume = AmbienceRules.roarVolume(stepsDone(), #Dungeon.STEPS, LOOK.roarVolume) * (if fighting then LOOK.fightShare else 1)
	oneShot("roar", volume)
	task.delay(0.4, function()
		oneShot("rubble", volume * 0.6)
		local at = rootPosition()
		if at then
			dust(at + Vector3.new(0, 14, 0))
		end
		tremble(LOOK.roarShake, 1.2)
	end)
end

-- A pair of the Hydra's eyes opens for a moment in the dark ahead (down the cavern, +X), then shuts
local function glimpse()
	local at = rootPosition()
	if not at or (state and state.stage == "boss") then
		return -- never next to the real Hydra in its chamber
	end
	local heads = Bosses.BOSSES[Dungeon.BOSS].heads or { "Ember" }
	local color = Cards.ELEMENTS[heads[rng:NextInteger(1, #heads)]] or Color3.new(1, 0.85, 0.3)
	local spot = at + Vector3.new(rng:NextNumber(LOOK.glimpseDistance[1], LOOK.glimpseDistance[2]), GLIMPSE_HEIGHT, rng:NextNumber(-5, 5))
	local folder = Instance.new("Folder")
	folder.Name = "DungeonGlimpse"
	folder.Parent = workspace
	for _, side in { -1, 1 } do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Size = Vector3.new(EYE_SIZE, EYE_SIZE * 0.4, EYE_SIZE * 0.4)
		part.CFrame = CFrame.lookAt(spot + Vector3.new(0, 0, side * EYE_SIZE * 0.9), at)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 0, 1)
		mesh.Parent = part
		part.Parent = folder
		TweenService:Create(mesh, TweenInfo.new(0.3), { Scale = Vector3.new(1, 1, 1) }):Play()
		task.delay(LOOK.glimpseSeconds, function()
			TweenService:Create(mesh, TweenInfo.new(0.15), { Scale = Vector3.new(1, 0, 1) }):Play()
		end)
	end
	oneShot("growl", 0.25, spot)
	task.delay(LOOK.glimpseSeconds + 0.3, folder.Destroy, folder)
end

-- The spot sounds round you (Soundscape.DUNGEON), each on its own timer
local function spots(now: number, at: Vector3)
	for index, spot in Soundscape.DUNGEON do
		if not nextSpot[index] then
			nextSpot[index] = SoundscapeRules.nextAt(now, spot.every, rng:NextNumber())
		elseif now >= nextSpot[index] then
			nextSpot[index] = SoundscapeRules.nextAt(now, spot.every, rng:NextNumber())
			local offset = SoundscapeRules.spotOffset(rng:NextNumber(), rng:NextNumber(), rng:NextNumber(), spot)
			local holder = Instance.new("Attachment")
			holder.WorldPosition = at + Vector3.new(offset.x, offset.y, offset.z)
			holder.Parent = workspace.Terrain
			local sound = Instance.new("Sound")
			sound.SoundId = spot.ids[rng:NextInteger(1, #spot.ids)]
			sound.Volume = spot.volume
			sound.PlaybackSpeed = rng:NextNumber(spot.pitch[1], spot.pitch[2])
			sound.RollOffMaxDistance = spot.range
			sound.Parent = holder
			sound.Ended:Connect(function()
				holder:Destroy()
			end)
			task.delay(SOUND_TIMEOUT, function()
				if holder.Parent then
					holder:Destroy()
				end
			end)
			sound:Play()
		end
	end
end

-- The music's layers follow the run: the bed (out in the Hydra's fight and while quiet), the heartbeat near the end
local function layers()
	local inBoss = state and state.stage == "boss" and fighting
	local share = if fighting then LOOK.fightShare else 1
	local bed = if quiet() or inBoss then 0 else LOOK.musicVolume * Dungeon.SOUNDS.music.volume * share
	local beat = if quiet() or inBoss then 0 else AmbienceRules.heartbeat(stepsDone(), LOOK.heartbeatFrom, #Dungeon.STEPS) * LOOK.heartbeatVolume * share
	-- a new fade only when the target changes (not every check while one is running)
	if bed ~= targets.bed then
		targets.bed = bed
		TweenService:Create(music, TweenInfo.new(FADE), { Volume = bed }):Play()
	end
	if beat ~= targets.beat then
		targets.beat = beat
		TweenService:Create(heartbeat, TweenInfo.new(FADE), { Volume = beat }):Play()
	end
end

function DungeonAmbienceController.Start()
	music = newSound("music", true)
	heartbeat = newSound("heartbeat", true)
	music:Play()
	heartbeat:Play()
	Remotes.DungeonRun.OnClientEvent:Connect(function(message)
		if typeof(message) == "table" then
			state = message
		end
	end)
	Remotes.BattleStarted.OnClientEvent:Connect(function()
		fighting = true
	end)
	Remotes.BattleEnded.OnClientEvent:Connect(function()
		fighting = false
	end)
	if RunService:IsStudio() then
		player:GetAttributeChangedSignal("DungeonFxTest"):Connect(function()
			local value = player:GetAttribute("DungeonFxTest")
			local kind = if typeof(value) == "string" then string.match(value, "^(%a+):") else nil
			if kind == "roar" then
				roar()
			elseif kind == "glimpse" then
				glimpse()
			end
		end)
	end
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < CHECK_EVERY then
			return
		end
		since = 0
		layers()
		local now = os.clock()
		if quiet() then
			-- the timers start once the welcome is over (no roar right on top of it)
			nextRoar = AmbienceRules.nextAt(now, LOOK.roarEvery, rng:NextNumber())
			nextGlimpse = AmbienceRules.nextAt(now, LOOK.glimpseEvery, rng:NextNumber())
			return
		end
		local at = rootPosition()
		if at then
			spots(now, at)
		end
		if now >= nextRoar then
			nextRoar = AmbienceRules.nextAt(now, LOOK.roarEvery, rng:NextNumber())
			roar()
		end
		if now >= nextGlimpse then
			nextGlimpse = AmbienceRules.nextAt(now, LOOK.glimpseEvery, rng:NextNumber())
			if not fighting then
				glimpse()
			end
		end
	end)
end

return DungeonAmbienceController
