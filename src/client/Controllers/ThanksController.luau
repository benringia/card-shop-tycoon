--!strict
-- The thank-you after a "Support the dev" gift (owner 2026-11-12: "when a player donates, play a cinematic that both
-- dogs running towards the player, then saying something like 'thank you, for your support, this is for you' and then
-- a glow slowly coming out the players body"; Config/Support CINEMATIC, Server/Services/SupportService fires
-- Remotes.SupportThanks): on the giver's screen Pish and Chikin run in from the first clear ways in front of them
-- (Util/ArrivalShot.pickRun) in sparkles, stop side by side, Pish says thank you and Chikin "This is for you!", then a
-- golden glow rises out of the player as the server's aura appears, and the dogs hop and vanish in stars. The camera
-- frames the three of them and moves in for the glow; the player holds still; a tap ends it early. Mid-fight, during a
-- tour or another cinematic only the glow plays (Util/SupportRules.thanksMode). The town dogs hide meanwhile, so there's
-- one of each.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Chikin = require(Config:WaitForChild("Chikin"))
local Support = require(Config:WaitForChild("Support"))
local SharedUtil = Shared:WaitForChild("Util")
local ArrivalShot = require(SharedUtil:WaitForChild("ArrivalShot"))
local SupportRules = require(SharedUtil:WaitForChild("SupportRules"))
local TutorialRules = require(SharedUtil:WaitForChild("TutorialRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local PishVisual = require(ClientUtil:WaitForChild("PishVisual"))
local DogMagic = require(ClientUtil:WaitForChild("DogMagic"))
local GreetBubble = require(ClientUtil:WaitForChild("GreetBubble"))
local BattleController = require(Controllers:WaitForChild("BattleController"))
local WeaponRevealController = require(Controllers:WaitForChild("WeaponRevealController"))
local TownPishController = require(Controllers:WaitForChild("TownPishController"))
local TownChikinController = require(Controllers:WaitForChild("TownChikinController"))

local ThanksController = {}

local CINEMATIC = Support.CINEMATIC
local RUN = CINEMATIC.run
local player = Players.LocalPlayer
local playing = false

type Dog = { name: string, marker: BasePart, visual: PishVisual.Visual?, stop: Vector3 }

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function stepOf(name: string): string
	local value = player:GetAttribute(name)
	return if typeof(value) == "string" then value else ""
end

-- Whether something else holds the screen: another cinematic's camera, a weapon reveal, the knockout screen
local function busy(): boolean
	local camera = workspace.CurrentCamera
	local gui = player:FindFirstChildOfClass("PlayerGui")
	local knockout = if gui then gui:FindFirstChild("KnockoutScreen") else nil
	return (camera ~= nil and camera.CameraType ~= Enum.CameraType.Custom)
		or WeaponRevealController.IsPlaying()
		or (knockout ~= nil and knockout:IsA("ScreenGui") and knockout.Enabled)
end

-- The golden glow rising out of the character over `seconds`: a soft gold highlight swelling and fading, glow and
-- sparkles streaming up from the chest, a warm light, a shimmer
local function glowOut(character: Model, seconds: number)
	local look = CINEMATIC.glow
	local gold = rgb(look.color)
	local chest = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	if not chest or not chest:IsA("BasePart") then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "ThanksGlow"
	highlight.FillColor = gold
	highlight.OutlineColor = Color3.fromRGB(255, 240, 190)
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = character
	highlight.Parent = character
	local rise = TweenInfo.new(seconds * 0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(highlight, rise, { FillTransparency = 0.45, OutlineTransparency = 0.2 }):Play()
	task.delay(seconds * 0.6, function()
		TweenService:Create(highlight, TweenInfo.new(seconds * 0.6), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	end)

	local holder = Instance.new("Attachment")
	holder.Name = "ThanksGlowStream"
	local stream = Instance.new("ParticleEmitter")
	stream.Texture = Support.GLOW
	stream.Color = ColorSequence.new(gold)
	stream.LightEmission = 0.6
	stream.LightInfluence = 0
	stream.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
	stream.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1) })
	stream.Lifetime = NumberRange.new(1, 1.4)
	stream.Speed = NumberRange.new(2.5, 4)
	stream.SpreadAngle = Vector2.new(20, 20)
	stream.EmissionDirection = Enum.NormalId.Top
	stream.Rate = 14
	stream.Parent = holder
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = Support.SPARKLE
	sparkles.Color = ColorSequence.new(gold, Color3.fromRGB(255, 240, 170))
	sparkles.LightEmission = 0.2
	sparkles.LightInfluence = 0
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.2) })
	sparkles.Lifetime = NumberRange.new(1, 1.5)
	sparkles.Speed = NumberRange.new(3, 6)
	sparkles.SpreadAngle = Vector2.new(35, 35)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Rate = 30
	sparkles.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 12
	light.Brightness = 0
	light.Shadows = false
	light.Parent = holder
	holder.Parent = chest
	TweenService:Create(light, rise, { Brightness = 3 }):Play()

	local shimmer = Instance.new("Sound")
	shimmer.SoundId = look.sound
	shimmer.Volume = look.volume
	shimmer.Parent = SoundService
	shimmer.Ended:Once(function()
		shimmer:Destroy()
	end)
	shimmer:Play()

	task.delay(seconds, function()
		stream.Enabled = false
		sparkles.Enabled = false
		TweenService:Create(light, TweenInfo.new(1), { Brightness = 0 }):Play()
		task.delay(1.6, function()
			holder:Destroy()
			highlight:Destroy()
		end)
	end)
end

-- Where a dog runs in from: the first clear way of `angles` (degrees off the player's front), `RUN.from` studs out
local function runStart(feet: Vector3, look: Vector3, angles: { number }, character: Model): Vector3
	local blockers = RaycastParams.new()
	blockers.FilterType = Enum.RaycastFilterType.Exclude
	blockers.FilterDescendantsInstances = { character }
	local ways, clear = {}, {}
	for _, degrees in angles do
		local way = CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(look)
		local hit = workspace:Raycast(feet + Vector3.yAxis * 1.2, way * (RUN.from + RUN.wallGap), blockers)
		table.insert(ways, way)
		table.insert(clear, if hit then hit.Distance else RUN.from + RUN.wallGap)
	end
	local index, length = ArrivalShot.pickRun(clear, RUN :: any)
	return feet + ways[index] * length
end

local function makeDog(name: string, start: Vector3, stop: Vector3): Dog
	local marker = Instance.new("Part")
	marker.Name = `Thanks{name}`
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(2, 2, 2)
	marker.CFrame = CFrame.lookAt(start, Vector3.new(stop.X, start.Y, stop.Z))
	marker.Parent = workspace
	return { name = name, marker = marker, visual = PishVisual.new(marker, name), stop = stop }
end

local function say(dog: Dog, line: string, bubble: { up: number, edge: { number } })
	if not dog.visual then
		return
	end
	dog.marker:SetAttribute("GreetUserId", player.UserId)
	dog.marker:SetAttribute("GreetLine", 1)
	GreetBubble.show(dog.marker, dog.visual, { line }, bubble.up, rgb(bubble.edge))
	PishVisual.play(dog.visual, "headTilt")
end

-- The whole scene (`mode` "full"), or only the glow at its time ("glow")
local function play(mode: "full" | "glow")
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not character or not root or not humanoid then
		return
	end
	if mode == "glow" then
		task.delay(CINEMATIC.at.glow, function()
			if character.Parent then
				glowOut(character, CINEMATIC.glow.seconds)
			end
		end)
		return
	end
	playing = true
	DogMagic.preload()
	local held = { walk = humanoid.WalkSpeed, jump = humanoid.JumpPower, jumpHeight = humanoid.JumpHeight }
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local right = Vector3.new(-look.Z, 0, look.X)
	local feet = root.Position - Vector3.new(0, 3, 0)
	local pishStop = feet + look * RUN.stop - right * RUN.side / 2
	local chikinStop = feet + look * RUN.stop + right * RUN.side / 2
	local dogs: { Dog } = {
		makeDog("Pish", runStart(feet, look, RUN.pish, character), pishStop),
		makeDog("Chikin", runStart(feet, look, RUN.chikin, character), chikinStop),
	}
	TownPishController.SetHidden(true)
	TownChikinController.SetHidden(true)
	local trails: { () -> () } = {}
	for _, dog in dogs do
		table.insert(trails, DogMagic.trail(dog.marker))
	end

	-- The camera: in front of the player to one side, the dogs running in; closer for the glow
	local camera = workspace.CurrentCamera
	local view = RaycastParams.new()
	view.FilterType = Enum.RaycastFilterType.Exclude
	view.FilterDescendantsInstances = { character, dogs[1].marker, dogs[2].marker }
	local close = false
	local function shot(): CFrame
		local frame = if close then CINEMATIC.camera.close else CINEMATIC.camera
		local target = root.Position + look * (if close then 0.5 else 2.2) + Vector3.yAxis * (if close then 0.6 else 0)
		local want = root.Position + look * frame.back + right * frame.side + Vector3.yAxis * frame.up
		local hit = workspace:Raycast(target, want - target, view)
		local at = if hit then target + (want - target).Unit * math.max(2, hit.Distance - 1) else want
		return CFrame.lookAt(at, target)
	end
	local started = os.clock()
	local finished = false
	local tap: RBXScriptConnection? = nil
	local frame: RBXScriptConnection? = nil
	local function finish()
		if finished then
			return
		end
		finished = true
		playing = false
		if tap then
			tap:Disconnect()
		end
		if frame then
			frame:Disconnect()
		end
		for _, stopTrail in trails do
			stopTrail()
		end
		for _, dog in dogs do
			if dog.visual then
				PishVisual.destroy(dog.visual)
			end
			dog.marker:Destroy()
		end
		TownPishController.SetHidden(false)
		TownChikinController.SetHidden(false)
		camera.CameraType = Enum.CameraType.Custom
		if humanoid.Parent then
			humanoid.WalkSpeed = held.walk
			humanoid.JumpPower = held.jump
			humanoid.JumpHeight = held.jumpHeight
		end
	end
	task.delay(CINEMATIC.at.done + 3, finish) -- failsafe first: the camera and walking always come back
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = shot()

	tap = UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			finish() -- the aura still comes at its time (the server)
		end
	end)
	frame = RunService.RenderStepped:Connect(function(dt: number)
		if finished then
			return
		end
		camera.CFrame = camera.CFrame:Lerp(shot(), math.min(1, dt * CINEMATIC.camera.follow))
		for _, dog in dogs do
			local here = dog.marker.Position
			local flat = Vector3.new(dog.stop.X - here.X, 0, dog.stop.Z - here.Z)
			if flat.Magnitude > 0.3 then
				local nextAt = here + flat.Unit * math.min(flat.Magnitude, RUN.speed * dt)
				dog.marker.CFrame = CFrame.lookAt(nextAt, nextAt + flat.Unit)
			elseif not dog.marker:GetAttribute("Arrived") then
				dog.marker:SetAttribute("Arrived", true)
				dog.marker.CFrame = CFrame.lookAt(dog.stop, Vector3.new(root.Position.X, dog.stop.Y, root.Position.Z))
				DogMagic.arrive(dog.stop + Vector3.yAxis * 1.5)
				if dog.visual then
					PishVisual.hearts(dog.visual)
					PishVisual.play(dog.visual, "happyHop")
				end
			end
			if dog.visual then
				PishVisual.step(dog.visual, dt)
			end
		end
	end)

	local function at(seconds: number)
		local wait = started + seconds - os.clock()
		if wait > 0 then
			task.wait(wait)
		end
	end
	task.spawn(function()
		at(CINEMATIC.at.talkPish)
		if finished then
			return
		end
		say(dogs[1], string.format(CINEMATIC.lines.pish, player.DisplayName), CINEMATIC.bubbles.pish)
		at(CINEMATIC.at.talkChikin)
		if finished then
			return
		end
		say(dogs[2], CINEMATIC.lines.chikin, CINEMATIC.bubbles.chikin)
		at(CINEMATIC.at.glow)
		if finished then
			return
		end
		close = true
		glowOut(character, CINEMATIC.glow.seconds)
		at(CINEMATIC.at.leave)
		if finished then
			return
		end
		for _, dog in dogs do
			if dog.visual then
				PishVisual.play(dog.visual, "happyHop")
			end
		end
		task.wait(0.5)
		for _, dog in dogs do
			DogMagic.poof(dog.marker.Position + Vector3.yAxis * 1.2)
			if dog.visual then
				PishVisual.setShown(dog.visual, false)
			end
		end
		at(CINEMATIC.at.done)
		finish()
	end)
end

function ThanksController.Start()
	Remotes.SupportThanks.OnClientEvent:Connect(function(view: unknown)
		if typeof(view) ~= "table" or playing then
			return
		end
		local touring = TutorialRules.tourLeading(stepOf("TutorialStep"), stepOf("CombatStep"), Chikin.WAIT_STEP)
		play(SupportRules.thanksMode({ fighting = BattleController.IsFighting(), touring = touring, busy = busy() }))
	end)
end

return ThanksController
