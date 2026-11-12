--!strict
-- The Dungeon's cinematics (owner 2026-11-12: "a cinematic when a puzzle is solved and a door opened", and after the
-- lock "a cinematic indicating you're about to go to the Hydra's lair"; Config/Dungeon CINEMATIC). The server sends
-- Remotes.DungeonCinematic and opens the gate itself at `openAt`:
--   door:  the camera turns to the puzzle's gate, its seal cracks with light and shatters as it opens, back to you;
--   hydra: the camera flies down the bridge to the Hydra's door, the five eye gems flare one by one, the door bursts
--          open with a flash, a roar shakes the cave, back to you.
-- The HUD hides while one plays; the camera always comes back (a failsafe ends it). Dungeon place only.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dungeon = require(Shared:WaitForChild("Config"):WaitForChild("Dungeon"))
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local UIController = require(Controllers:WaitForChild("UIController"))

local DungeonCinematicController = {}

local LOOK = Dungeon.CINEMATIC
local SEAL_GLOW = Color3.fromRGB(200, 150, 255)

local player = Players.LocalPlayer
local playing = 0 -- the running cinematic's number (a newer one ends the old)
local currentFinish: (() -> ())? = nil -- the running one's clean-up (a newer one restores everything first)

-- Holds your character still while a cinematic plays, so nobody walks off an island unseen: its Humanoid's walk and
-- jump at 0 (this game has no PlayerModule to switch off; never waits for anything). Returns how to let go.
local function holdStill(): () -> ()
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then
		return function() end
	end
	local walk, jump, power = humanoid.WalkSpeed, humanoid.JumpHeight, humanoid.JumpPower
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
	return function()
		if humanoid.Parent then
			humanoid.WalkSpeed = walk
			humanoid.JumpHeight = jump
			humanoid.JumpPower = power
		end
	end
end

local function sound(key: string, pitch: number?)
	local spec = (Dungeon.PUZZLE_SOUNDS :: any)[key] or (Dungeon.SOUNDS :: any)[key]
	if not spec then
		return
	end
	local made = Instance.new("Sound")
	made.SoundId = spec.id
	made.Volume = spec.volume
	made.PlaybackSpeed = (spec.pitch or 1) * (pitch or 1)
	made.Parent = SoundService
	made:Play()
	Debris:AddItem(made, 10)
end

-- A flash of light and a burst of sparkles at `at` (a seal shattering, a gem flaring)
local function burst(at: Vector3, color: Color3, size: number, count: number)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = at
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = size * 4
	light.Brightness = 5
	light.Parent = part
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.6, 1.3)
	emitter.Speed = NumberRange.new(size, size * 2.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -10, 0)
	emitter.Size = NumberSequence.new(size * 0.15, 0)
	emitter.Parent = part
	part.Parent = workspace
	emitter:Emit(count)
	TweenService:Create(light, TweenInfo.new(1.2), { Brightness = 0 }):Play()
	Debris:AddItem(part, 2)
end

-- Plays one cinematic: `beats` runs its moments on the camera, then everything goes back
local function run(seconds: number, beats: (camera: Camera, mine: number) -> ())
	if currentFinish then
		currentFinish() -- the one still playing puts everything back first
	end
	playing += 1
	local mine = playing
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local gui = UIController.GetScreenGui()
	local guiWas = gui.Enabled
	local typeWas = camera.CameraType
	local letGo = holdStill()
	local function finish()
		if playing ~= mine then
			return
		end
		playing += 1
		currentFinish = nil
		-- never left Scriptable (a welcome or cinematic still running when this one began)
		camera.CameraType = if typeWas == Enum.CameraType.Scriptable then Enum.CameraType.Custom else typeWas
		gui.Enabled = guiWas
		player:SetAttribute("DungeonIntroPlaying", nil)
		letGo()
	end
	currentFinish = finish
	task.delay(seconds + 2, finish) -- a failsafe: the camera always comes back
	-- only now (the way back is set) does the camera leave you
	gui.Enabled = false
	player:SetAttribute("DungeonIntroPlaying", true) -- the objective and the fall fade stand aside meanwhile
	camera.CameraType = Enum.CameraType.Scriptable
	task.spawn(function()
		local ok, problem = xpcall(beats, debug.traceback, camera, mine)
		if not ok then
			warn("[DungeonCinematic]", problem)
		end
		finish() -- the beats wait out its seconds themselves
	end)
end

-- A puzzle's gate opening: look at it, the seal cracks with light, it shatters as the server opens the gate
local function doorShot(door: Vector3, through: Vector3)
	local look = LOOK.door
	local view = CFrame.lookAt(door - through * look.back + Vector3.new(0, look.up, 0), door + Vector3.new(0, look.up * 0.6, 0))
	run(look.seconds, function(camera: Camera, mine: number)
		local started = os.clock()
		camera.CFrame = view * CFrame.new(0, 0, 4)
		TweenService:Create(camera, TweenInfo.new(look.openAt, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = view }):Play()
		sound("closer", 0.8)
		task.wait(look.openAt * 0.5)
		burst(door + Vector3.new(0, 7, 0), SEAL_GLOW, 3, 15) -- the seal cracking
		task.wait(look.openAt - (os.clock() - started))
		if playing ~= mine then
			return
		end
		sound("shatter")
		burst(door + Vector3.new(0, 7, 0), SEAL_GLOW, 6, 60) -- it shatters as the gate opens
		task.wait(look.seconds - (os.clock() - started))
	end)
end

-- The castle gate's dragon head `index` glares: its eyes lit in its colour here at once (the server lights them for
-- everyone as the door opens)
local function lightEye(index: number): Color3
	local colors = (Town.PORTAL_LOOKS :: any).Dungeon.glow
	local rgb = colors[`Eye{index}`] or Dungeon.HYDRA_EYES.dark
	local color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	local dungeon = workspace:FindFirstChild("Dungeon")
	local gate = if dungeon then dungeon:FindFirstChild("HydraGate", true) else nil
	local eye = if gate then gate:FindFirstChild(`Eye{index}`) else nil
	if eye and eye:IsA("BasePart") then
		if eye:IsA("MeshPart") then
			eye.TextureID = ""
		end
		eye.Material = Enum.Material.Neon
		eye.Color = color
	end
	return color
end

-- The way to the Hydra: fly down the bridge to the castle gate, its dragon heads' eyes light one by one, the door bursts
-- open, the roar (owner 2026-11-12: "after completing the puzzle the hydra gate should light their eyes")
local function hydraShot(door: Vector3, through: Vector3, eyes: { Vector3 })
	local look = LOOK.hydra
	local aim = door + Vector3.new(0, look.aimUp, 0)
	local from = CFrame.lookAt(door - through * look.from.back + Vector3.new(0, look.from.up, 0), aim)
	local to = CFrame.lookAt(door - through * look.to.back + Vector3.new(0, look.to.up, 0), aim)
	run(look.seconds, function(camera: Camera, mine: number)
		local started = os.clock()
		camera.CFrame = from
		TweenService:Create(camera, TweenInfo.new(look.fly, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = to }):Play()
		sound("breath")
		task.wait(look.socketsAt - (os.clock() - started))
		for index, spot in eyes do
			if playing ~= mine then
				return
			end
			burst(spot, lightEye(index), 1.5, 12)
			sound("right", 1 + index * 0.12)
			task.wait(look.socketEvery)
		end
		task.wait(math.max(0, look.openAt - (os.clock() - started)))
		sound("shatter", 0.7)
		burst(aim, SEAL_GLOW, 10, 90) -- the door bursts open as the server opens it
		task.wait(math.max(0, look.roarAt - (os.clock() - started)))
		sound("roar")
		local base = camera.CFrame
		local shakeUntil = os.clock() + 1.4
		while os.clock() < shakeUntil and playing == mine do
			local fade = (shakeUntil - os.clock()) / 1.4
			camera.CFrame = base + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * look.shake * 2 * fade
			RunService.RenderStepped:Wait()
		end
		task.wait(math.max(0, look.seconds - (os.clock() - started)))
	end)
end

function DungeonCinematicController.Start()
	Remotes.DungeonCinematic.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.door) ~= "Vector3" or typeof(payload.through) ~= "Vector3" then
			return
		end
		local through = Vector3.new(payload.through.X, 0, payload.through.Z)
		through = if through.Magnitude > 0.01 then through.Unit else Vector3.new(1, 0, 0)
		if payload.kind == "hydra" then
			local eyes = {}
			for _, spot in if typeof(payload.eyes) == "table" then payload.eyes else {} do
				if typeof(spot) == "Vector3" then
					table.insert(eyes, spot)
				end
			end
			hydraShot(payload.door, through, eyes)
		else
			doorShot(payload.door, through)
		end
	end)
end

return DungeonCinematicController
