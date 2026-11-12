--!strict
-- The Hydra's welcome (spec 2026-11-12-dungeon-atmosphere; the owner: "a cinematic with something like the hydra's
-- eyes but not showing the hydra yet, some roars, some eerie music"): when the run opens, this player's camera plays
-- Config/Dungeon INTRO's beats: the way back slams shut, the hall's braziers die one by one, the camera drifts into
-- the dark, one pair of eyes opens, four more (the heads' colours), the roar with shake and dust, the title. The
-- Hydra itself is never shown. The server says which welcome (full the first time ever, short after: DungeonRun
-- `intro`). Always skippable; everything (camera, lighting, braziers, HUD) goes back as it was. The player attribute
-- DungeonIntroPlaying is set on this client while it plays (the objective hides). Studio: `/dungeonfx intro|introshort`.
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
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
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local UIController = require(Controllers:WaitForChild("UIController"))

local DungeonIntroController = {}

local INTRO = Dungeon.INTRO
local SKIP_ACTION = "DungeonIntroSkip"
local DARK = { brightness = 0.4, ambient = Color3.fromRGB(30, 26, 44), fogEnd = 140 } -- the hall while the eyes watch
local EYE_OPEN = 0.35 -- seconds an eye takes to open
local FIRST_OPEN = 1.1 -- the first pair opens slowly
-- the eyes' look: the outer corners' slant (degrees), the pupil's and the heads' colours, the glow on the heads
local EYE_LOOK = { slant = 14, pupil = Color3.fromRGB(12, 6, 18), skin = Color3.fromRGB(34, 26, 48), glow = 2.2, narrow = 0.35, lean = 5 }
local LOADING_WAIT = 60 -- the longest the server's welcome waits for the loading screen to go
local SOUND_TIMEOUT = 15 -- a one-shot that never loaded is cleared after this

local player = Players.LocalPlayer
local token = 0 -- a newer welcome (or a skip) cancels the running one
local currentFinish: (() -> ())? = nil -- the running welcome's clean-up (a new one restores everything first)
local serverIntroStarted = false -- the server's welcome plays once a visit (every run message carries it until acked)

local function sound(key: string, parent: Instance?): Sound
	local spec = (Dungeon.SOUNDS :: any)[key]
	local made = Instance.new("Sound")
	made.Name = `DungeonIntro_{key}`
	made.SoundId = spec.id
	made.Volume = spec.volume
	made.PlaybackSpeed = spec.pitch or 1
	made.Parent = parent or SoundService
	return made
end

local function playOnce(key: string)
	local made = sound(key)
	made.Ended:Connect(function()
		made:Destroy()
	end)
	task.delay(SOUND_TIMEOUT, function()
		if made.Parent then
			made:Destroy()
		end
	end)
	made:Play()
end

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- One of the Hydra's eyes (round 2, concept_hydra_eyes.png): an almond of glowing iris with a dark slit pupil in
-- front, under a scaly brow; lids are the meshes' height (0 shut, 1 open), the pupil's width narrows when it looks
type Eye = { iris: BasePart, pupil: BasePart }
type Pair = { eyes: { Eye }, light: PointLight, parts: { BasePart } }

local function piece(parent: Instance, name: string, size: Vector3, frame: CFrame, color: Color3, neon: boolean, ellipsoid: boolean): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size
	part.CFrame = frame
	if ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = parent
	return part
end

-- An eye at `at` looking down -X (at the hall), its outer corner raised on `side` (-1 / 1 along z)
local function eye(parent: Instance, at: Vector3, color: Color3, size: number, side: number): Eye
	local slant = CFrame.new(at) * CFrame.Angles(math.rad(-EYE_LOOK.slant * side), 0, 0)
	local iris = piece(parent, "HydraEye", Vector3.new(size * 0.6, size * 0.8, size * 1.4), slant, color, true, true)
	local pupil = piece(parent, "HydraPupil", Vector3.new(size * 0.2, size * 0.74, size * 0.24), slant * CFrame.new(-size * 0.3, 0, 0), EYE_LOOK.pupil, false, true)
	for _, part in { iris, pupil } do
		(part:FindFirstChildOfClass("SpecialMesh") :: SpecialMesh).Scale = Vector3.new(1, 0, 1) -- shut
		part.Transparency = 1 -- not even a line until it opens
	end
	-- the brow ridge over it, lit only by the eyes' glow
	piece(parent, "HydraBrow", Vector3.new(size * 0.7, size * 0.32, size * 1.7), slant * CFrame.new(-size * 0.1, size * 0.56, 0) * CFrame.Angles(math.rad(-10 * side), 0, 0), EYE_LOOK.skin, false, false)
	return { iris = iris, pupil = pupil }
end

local function lidTo(each: Eye, open: number, seconds: number, narrow: number?)
	if open > 0 then
		each.iris.Transparency = 0
		each.pupil.Transparency = 0
	end
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local irisMesh = each.iris:FindFirstChildOfClass("SpecialMesh")
	local pupilMesh = each.pupil:FindFirstChildOfClass("SpecialMesh")
	if irisMesh then
		TweenService:Create(irisMesh, info, { Scale = Vector3.new(1, open, 1) }):Play()
	end
	if pupilMesh then
		TweenService:Create(pupilMesh, info, { Scale = Vector3.new(1, open, narrow or 1) }):Play()
	end
end

-- A pair's lids (and the glow on its head with them)
local function setLid(pair: Pair, open: number, seconds: number, narrow: number?)
	for _, each in pair.eyes do
		lidTo(each, open, seconds, narrow)
	end
	TweenService:Create(pair.light, TweenInfo.new(seconds), { Brightness = open * EYE_LOOK.glow }):Play()
end

-- The five pairs of eyes ahead of the hall, in the dark: head 0 in the middle, the others outwards, lower and wider;
-- each pair under its head's dark shape (skull and snout), only seen by its eyes' glow
local function makeEyes(folder: Instance): { Pair }
	local look = INTRO.EYES
	local origin = Vector3.new(Dungeon.ORIGIN.x, Dungeon.ORIGIN.y, Dungeon.ORIGIN.z)
	local center = origin + Vector3.new(Dungeon.HALL.length + look.distance, look.height, 0)
	local eyePairs: { Pair } = {}
	local offsets = { 0, -1, 1, -2, 2 } -- head 0 in the middle, then out on both sides
	for index, element in Bosses.BOSSES[Dungeon.BOSS].heads or {} do
		local side = offsets[index] or 0
		local headAt = center + Vector3.new(math.abs(side) * 4, -math.abs(side) * 4, side * look.spread / 2)
		local color = Cards.ELEMENTS[element] or Color3.new(1, 0.85, 0.3)
		local size = look.size * (if side == 0 then 1.15 else 1)
		local gap = size * 1.05
		local skull = piece(folder, "HydraHead", Vector3.new(size * 3, size * 2.2, size * 3.6), CFrame.new(headAt + Vector3.new(size * 1.2, size * 0.3, 0)), EYE_LOOK.skin, false, true)
		local snout = piece(folder, "HydraSnout", Vector3.new(size * 3.2, size * 1.2, size * 2.2), CFrame.new(headAt + Vector3.new(-size * 0.6, -size * 0.9, 0)), EYE_LOOK.skin, false, true)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = size * 5
		light.Brightness = 0
		light.Parent = snout
		local pair: Pair = { eyes = {}, light = light, parts = { skull, snout } }
		for _, z in { -1, 1 } do
			local each = eye(folder, headAt + Vector3.new(-size * 0.4, 0, z * gap), color, size, z)
			table.insert(pair.eyes, each)
		end
		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") and not table.find(pair.parts, part) and (part.Position - headAt).Magnitude < size * 3 then
				table.insert(pair.parts, part)
			end
		end
		table.insert(eyePairs, pair)
	end
	return eyePairs
end

-- The heads lean in toward the hall (the look): every piece of a pair slides `studs` toward the camera
local function leanIn(pair: Pair, studs: number, seconds: number)
	for _, part in pair.parts do
		TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = part.CFrame - Vector3.new(studs, 0, 0) }):Play()
	end
end

-- The hall's braziers' lights and flames (to put out and bring back)
local function braziers(): { { lights: { Light }, flames: { BasePart }, fires: { ParticleEmitter } } }
	local list = {}
	local folder = workspace:FindFirstChild("Dungeon") and workspace.Dungeon:FindFirstChild("HallLights")
	for index = 1, #Dungeon.HALL_BRAZIERS do
		local model = if folder then folder:FindFirstChild(`HallBrazier{index}`) else nil
		local entry = { lights = {} :: { Light }, flames = {} :: { BasePart }, fires = {} :: { ParticleEmitter } }
		for _, item in if model then model:GetDescendants() else {} do
			if item:IsA("ParticleEmitter") then
				table.insert(entry.fires, item)
			elseif item:IsA("Light") then
				table.insert(entry.lights, item)
			elseif item:IsA("BasePart") and item.Name == "Glow" then
				table.insert(entry.flames, item)
			end
		end
		table.insert(list, entry)
	end
	return list
end

-- Everything that glows down the cavern past the hall (the rooms' gates, light shafts, pylons): hidden while the eyes
-- watch, so only they glow in the dark
local function glowsAhead(): { BasePart }
	local list = {}
	local dungeon = workspace:FindFirstChild("Dungeon")
	local hallEnd = Dungeon.ORIGIN.x + Dungeon.HALL.length + 4
	for _, item in if dungeon then dungeon:GetDescendants() else {} do
		if item:IsA("BasePart") and item.Material == Enum.Material.Neon and item.Position.X > hallEnd then
			table.insert(list, item)
		end
	end
	return list
end

-- The lights and light falls past the hall (seals, crystals, the backdrop): off while the eyes watch
local function lightsAhead(): { Light | Beam }
	local list: { Light | Beam } = {}
	local dungeon = workspace:FindFirstChild("Dungeon")
	local hallEnd = Dungeon.ORIGIN.x + Dungeon.HALL.length + 4
	for _, item in if dungeon then dungeon:GetDescendants() else {} do
		local holder = item.Parent
		if (item:IsA("Light") or item:IsA("Beam")) and item.Enabled and holder and holder:IsA("BasePart") and holder.Position.X > hallEnd then
			table.insert(list, item)
		end
	end
	return list
end

local function shake(camera: Camera, base: () -> CFrame, studs: number, seconds: number, mine: number)
	local started = os.clock()
	while os.clock() - started < seconds and token == mine do
		local fade = 1 - (os.clock() - started) / seconds
		local wobble = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * studs * 2 * fade
		camera.CFrame = base() + wobble
		RunService.RenderStepped:Wait()
	end
end

local function dust(at: Vector3, folder: Instance)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(30, 1, 30)
	part.Position = at
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 140, 160))
	emitter.Transparency = NumberSequence.new(0.6, 1)
	emitter.Size = NumberSequence.new(1.5, 3)
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.Acceleration = Vector3.new(0, -6, 0)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Rate = 0
	emitter.Parent = part
	part.Parent = folder
	emitter:Emit(40)
end

local function play(kind: string)
	local beats = (INTRO :: any)[kind]
	if not beats then
		return
	end
	if currentFinish then
		currentFinish() -- restore first, so this one saves the real lighting, camera and HUD
	end
	token += 1
	local mine = token
	local alive = true
	player:SetAttribute("DungeonIntroPlaying", true)
	local camera = workspace.CurrentCamera
	local previousType = camera.CameraType
	local saved = {
		brightness = Lighting.Brightness,
		ambient = Lighting.Ambient,
		outdoor = Lighting.OutdoorAmbient,
		fogEnd = Lighting.FogEnd,
	}
	local gui = UIController.GetScreenGui()
	local guiWasEnabled = gui.Enabled
	local folder = Instance.new("Folder")
	folder.Name = "DungeonIntro"
	folder.Parent = workspace
	local eyes = makeEyes(folder)
	local fires = braziers()
	local hidden = glowsAhead()
	for _, part in hidden do
		part.LocalTransparencyModifier = 1
	end
	local dimmed = lightsAhead()
	for _, light in dimmed do
		light.Enabled = false
	end
	-- the cave's violet haze goes dark with the hall (restored after)
	local air = Lighting:FindFirstChildOfClass("Atmosphere")
	local airWas = if air then { color = air.Color, decay = air.Decay } else nil
	local music = sound("music")
	music.Looped = true
	local musicVolume = Dungeon.AMBIENCE.musicVolume * Dungeon.SOUNDS.music.volume -- the bed's level, not louder
	music.Volume = 0
	local tweens: { Tween } = {} -- lighting and camera tweens, cancelled when it ends (a skip mid-fade)
	if air then
		local fade = TweenService:Create(air, TweenInfo.new(2.5), { Color = DARK.ambient, Decay = Color3.new(0, 0, 0) })
		table.insert(tweens, fade)
		fade:Play()
	end

	-- the title and Skip on their own screen
	local overlay = Instance.new("ScreenGui")
	overlay.Name = "DungeonIntro"
	overlay.IgnoreGuiInset = true
	overlay.DisplayOrder = 50
	overlay.ResetOnSpawn = false
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.45)
	title.Size = UDim2.fromScale(0.8, 0.12)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(216, 200, 160)
	title.TextTransparency = 1
	title.Text = INTRO.TITLE
	title.Parent = overlay
	local subtitle = title:Clone()
	subtitle.Position = UDim2.fromScale(0.5, 0.56)
	subtitle.Size = UDim2.fromScale(0.6, 0.05)
	subtitle.TextColor3 = Color3.fromRGB(154, 143, 176)
	subtitle.Text = INTRO.SUBTITLE
	subtitle.Parent = overlay
	local skip = Instance.new("TextButton")
	skip.Text = "Skip"
	skip.Font = Enum.Font.FredokaOne
	skip.TextSize = 20
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.BackgroundColor3 = Color3.fromRGB(30, 24, 44)
	skip.BackgroundTransparency = 0.3
	skip.AnchorPoint = Vector2.new(0.5, 1) -- bottom centre: clear of the thumbstick and the jump button
	skip.Position = UDim2.new(0.5, 0, 1, -24)
	skip.Size = UDim2.fromOffset(110, 48)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = skip
	skip.Parent = overlay
	overlay.Parent = player:WaitForChild("PlayerGui")

	local function finish()
		if not alive then
			return
		end
		alive = false
		if currentFinish == finish then
			currentFinish = nil
		end
		token += 1
		for _, tween in tweens do
			tween:Cancel()
		end
		ContextActionService:UnbindAction(SKIP_ACTION)
		for _, part in hidden do
			part.LocalTransparencyModifier = 0
		end
		for _, light in dimmed do
			light.Enabled = true
		end
		if air and airWas then
			air.Color = airWas.color
			air.Decay = airWas.decay
		end
		for _, fire in fires do
			for _, light in fire.lights do
				light.Enabled = true
			end
			for _, flame in fire.flames do
				flame.LocalTransparencyModifier = 0
			end
			for _, emitter in fire.fires do
				emitter.Enabled = true
			end
		end
		Lighting.Brightness = saved.brightness
		Lighting.Ambient = saved.ambient
		Lighting.OutdoorAmbient = saved.outdoor
		Lighting.FogEnd = saved.fogEnd
		camera.CameraType = if previousType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else previousType
		gui.Enabled = guiWasEnabled
		TweenService:Create(music, TweenInfo.new(2), { Volume = 0 }):Play()
		task.delay(2.1, music.Destroy, music)
		folder:Destroy()
		overlay:Destroy()
		player:SetAttribute("DungeonIntroPlaying", nil)
	end
	currentFinish = finish
	skip.Activated:Connect(finish)
	ContextActionService:BindAction(SKIP_ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			finish()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonB)

	gui.Enabled = false
	camera.CameraType = Enum.CameraType.Scriptable
	local origin = Vector3.new(Dungeon.ORIGIN.x, Dungeon.ORIGIN.y, Dungeon.ORIGIN.z)
	local eyesAt = origin + Vector3.new(Dungeon.HALL.length + INTRO.EYES.distance, INTRO.EYES.height, 0)
	local shot = CFrame.lookAt(origin + Vector3.new(4, 7, 0), eyesAt) -- down the hall at the dark
	camera.CFrame = shot
	if kind == "short" then
		Lighting.Brightness = DARK.brightness
		Lighting.Ambient = DARK.ambient
		Lighting.OutdoorAmbient = DARK.ambient
		Lighting.FogEnd = DARK.fogEnd
	end

	-- a failsafe: whatever happens, everything is back a little after the last beat
	task.delay(beats[#beats].at + 3, finish)

	local function runBeats()
		local started = os.clock()
		for index, beat in beats do
			local waitFor = beat.at - (os.clock() - started)
			if waitFor > 0 then
				task.wait(waitFor)
			end
			if token ~= mine then
				return
			end
			local name = beat.beat
			if name == "slam" then
				-- behind you: the way back slams shut
				local back = origin + Vector3.new(-9, 0, 0)
				-- from the side, so you (at the spawn) never block the slab
				camera.CFrame = CFrame.lookAt(origin + Vector3.new(10, 7, 9), back + Vector3.new(0, 6, 0))
				local slab = Instance.new("Part")
				slab.Anchored = true
				slab.CanCollide = false
				slab.Color = rgb(Dungeon.COLORS.WALL)
				slab.Material = Enum.Material.Slate
				slab.Size = Vector3.new(3, 16, 20)
				slab.CFrame = CFrame.new(back + Vector3.new(0, 28, 0))
				slab.Parent = folder
				TweenService:Create(slab, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(back + Vector3.new(0, 8, 0)) }):Play()
				task.delay(0.35, function()
					if token == mine then
						playOnce("slam")
						dust(back + Vector3.new(4, 1, 0), folder)
						local view = camera.CFrame
						shake(camera, function()
							return view
						end, INTRO.SHAKE * 0.6, 0.5, mine)
					end
				end)
			elseif name == "torches" then
				camera.CFrame = shot
				music:Play()
				TweenService:Create(music, TweenInfo.new(2), { Volume = musicVolume }):Play()
				task.spawn(function()
					for _, fire in fires do
						if token ~= mine then
							return
						end
						playOnce("torchOut")
						for _, light in fire.lights do
							light.Enabled = false
						end
						for _, flame in fire.flames do
							flame.LocalTransparencyModifier = 1
						end
						for _, emitter in fire.fires do
							emitter.Enabled = false
						end
						task.wait(0.4)
					end
				end)
				local fade = TweenService:Create(Lighting, TweenInfo.new(1.6), { Brightness = DARK.brightness, Ambient = DARK.ambient, OutdoorAmbient = DARK.ambient, FogEnd = DARK.fogEnd })
				table.insert(tweens, fade)
				fade:Play()
			elseif name == "drift" then
				local nextAt = (beats[index + 1] and beats[index + 1].at or beat.at + 1.5) - beat.at
				local drift = TweenService:Create(camera, TweenInfo.new(nextAt, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					CFrame = CFrame.lookAt(origin + Vector3.new(Dungeon.HALL.length - 6, 8, 0), eyesAt),
				})
				table.insert(tweens, drift)
				drift:Play()
				playOnce("breath")
			elseif name == "eyes" then
				TweenService:Create(music, TweenInfo.new(0.6), { Volume = 0 }):Play()
				if eyes[1] then
					setLid(eyes[1], 1, FIRST_OPEN)
				end
			elseif name == "blink" then
				if eyes[1] then
					setLid(eyes[1], 0, 0.1)
					task.delay(0.18, function()
						if token == mine then
							setLid(eyes[1], 1, 0.25)
						end
					end)
				end
			elseif name == "pairs" then
				camera.CFrame = if kind == "short" then shot else camera.CFrame
				for pair = (if kind == "short" then 1 else 2), #eyes do
					if token ~= mine then
						return
					end
					setLid(eyes[pair], 1, EYE_OPEN)
					if pair > 1 then
						playOnce("growl")
					end
					task.wait(if kind == "short" then 0.12 else 0.45)
				end
			elseif name == "look" then
				-- the pupils narrow to slits on you, the heads lean in
				for _, pair in eyes do
					setLid(pair, 1, 0.5, EYE_LOOK.narrow)
					leanIn(pair, EYE_LOOK.lean, 1.1)
				end
				playOnce("breath")
			elseif name == "roar" then
				for _, pair in eyes do
					setLid(pair, 0.45, 0.2, EYE_LOOK.narrow)
				end
				playOnce("roar")
				playOnce("rubble")
				dust(camera.CFrame.Position + Vector3.new(0, 10, 0), folder)
				TweenService:Create(music, TweenInfo.new(0.3), { Volume = musicVolume }):Play()
				local view = camera.CFrame
				task.spawn(shake, camera, function()
					return view
				end, INTRO.SHAKE, 1.3, mine)
			elseif name == "title" then
				for _, pair in eyes do
					setLid(pair, 0, 0.15)
				end
				playOnce("title")
				TweenService:Create(title, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
				TweenService:Create(subtitle, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
			elseif name == "end" then
				finish()
			end
		end
	end
	-- an error mid-welcome must never strand the camera, the HUD or the dark
	local ok, problem = xpcall(runBeats, debug.traceback)
	if not ok then
		warn("[DungeonIntro]", problem)
		finish()
	end
end

-- The server's welcome waits until the loading screen is gone (it can come the moment this player's data loads)
local function waitForLoading()
	local waited = 0
	while player:GetAttribute("LoadingDone") ~= true and waited < LOADING_WAIT do
		waited += task.wait(0.25)
	end
end

function DungeonIntroController.Start()
	Remotes.DungeonRun.OnClientEvent:Connect(function(message)
		if typeof(message) == "table" and (message.intro == "full" or message.intro == "short") and not serverIntroStarted then
			serverIntroStarted = true
			task.spawn(function()
				waitForLoading()
				Remotes.DungeonRun:FireServer("introSeen")
				play(message.intro)
			end)
		end
	end)
	if RunService:IsStudio() then
		-- /dungeonfx intro | introshort (DevService sets "intro:<clock>")
		player:GetAttributeChangedSignal("DungeonFxTest"):Connect(function()
			local value = player:GetAttribute("DungeonFxTest")
			local kind = if typeof(value) == "string" then string.match(value, "^(%a+):") else nil
			if kind == "intro" or kind == "introshort" then
				task.spawn(play, if kind == "intro" then "full" else "short")
			end
		end)
	end
end

return DungeonIntroController
