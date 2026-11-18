--!strict
-- The prologue (owner 2026-11-14, spec 2026-11-14-prologue-hydra-design; Config/Prologue): on a new player's very first
-- join (player attribute SeenPrologue false, set by WelcomeService), once the loading screen has gone, on this screen
-- only:
--   1. Cinematic: the Hydra's crystal lair (the server's spot for you, your loadout lent there: PrologueService);
--      "Long ago, you were the greatest card master..."; the two-headed Hydra rises and roars; "FIGHT!"
--   2. The real boss fight (BattleService, the boss HUD: cuts, the skill, supers, swaps, dodges) with the best weapon
--      and three Legendaries, maxed (the first comes out as it starts); the server ends it at Config/Prologue
--      END_SHARE.
--   3. Cinematic (owner 2026-11-15): its blow shatters your weapon and throws you down (Util/PrologueBody); you crawl
--      toward it while every card you have flies into its mouths (your Legendary turns back into its card first) and
--      it grows its five heads; you black out; "...until the Hydra took everything." (the server takes the lent
--      loadout back in the dark)
-- Then you wake in town on your back in front of your shop, your eyes opening on Pish and Chikin waking you up
-- (Util/PrologueWake); you get up, and the welcome flight and Pish's tutorial follow as before (they wait for
-- SeenPrologue). A Skip button (from act 3: the opening and the fight can't be skipped, nor run from), a death or a
-- respawn all end it the same way. Studio:
-- /prologue plays it again (Remotes.PrologueReplay).
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Prologue = require(Config:WaitForChild("Prologue"))
local Weapons = require(Config:WaitForChild("Weapons"))
local Cards = require(Config:WaitForChild("Cards"))
local CardArtConfig = require(Config:WaitForChild("CardArt"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local CardArt = require(Shared:WaitForChild("Util"):WaitForChild("CardArt"))
local PrologueRules = require(Shared:WaitForChild("Util"):WaitForChild("PrologueRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local ScreenFx = require(ClientUtil:WaitForChild("ScreenFx"))
local ScreenClear = require(ClientUtil:WaitForChild("ScreenClear"))
local SoundBank = require(ClientUtil:WaitForChild("SoundBank"))
local PrologueStage = require(ClientUtil:WaitForChild("PrologueStage"))
local PrologueHydra = require(ClientUtil:WaitForChild("PrologueHydra"))
local PrologueBody = require(ClientUtil:WaitForChild("PrologueBody"))
local PrologueWake = require(ClientUtil:WaitForChild("PrologueWake"))
local HydraEntrance = require(ClientUtil:WaitForChild("HydraEntrance"))
local TownPishController = require(Controllers:WaitForChild("TownPishController"))
local TownChikinController = require(Controllers:WaitForChild("TownChikinController"))
local CreatureVisuals = require(ClientUtil:WaitForChild("CreatureVisuals"))

local PrologueController = {}

local player = Players.LocalPlayer
local CAPTIONS = Prologue.CAPTIONS
local KNOCK = Prologue.KNOCK
local CRAWL = Prologue.CRAWL
local CARDS = Prologue.CARDS
local BLACKOUT = Prologue.BLACKOUT
local BLAST = Prologue.BLAST
local WAKE = Prologue.WAKE
local ROAR = "rbxassetid://9116290951" -- Lion Growls 7 (AttackFx BOSS_SKILLS enrage)
local RUMBLE = "rbxassetid://9114344093" -- Energy Presence 8 (the Rift Reaper's wrath rumble): the lair trembling
local BREAK = "rbxassetid://9113216700" -- Avalanche Crashing 3 (the Rift Reaper's ground break): the floor bursting
local ENTRANCE = Prologue.ENTRANCE
local SHATTER = "rbxassetid://9116418035" -- Magic Tone Falling Shimmer
local playing = false

local function sound(id: string, volume: number, parent: Instance)
	local made = SoundBank.make(id)
	made.Volume = volume
	made.Parent = parent
	made:Play()
	task.delay(6, made.Destroy, made)
end

-- A rainbow sparkle aura on you while you're at your strongest (removed when it's taken)
local function aura(root: BasePart): Attachment
	local holder = Instance.new("Attachment")
	holder.Name = "PrologueAura"
	holder.Position = Vector3.new(0, 0.5, 0)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 110)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 80)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(120, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 140, 255)),
	})
	sparkles.LightEmission = 0.4
	sparkles.LightInfluence = 0
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(1, 0.3) })
	sparkles.Lifetime = NumberRange.new(1.2, 1.6)
	sparkles.Rate = 28
	sparkles.Speed = NumberRange.new(2.5, 3.5)
	sparkles.Drag = 0.6
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Acceleration = Vector3.new(0, 1, 0)
	sparkles.Parent = holder
	holder.Parent = root
	return holder
end

-- A card (its painting on both faces) flying from `from` into the Hydra's mouth over `seconds`
local function cardInto(cardName: string, from: Vector3, into: Vector3, seconds: number)
	local card = Instance.new("Part")
	card.Anchored = true
	card.CanCollide = false
	card.CanQuery = false
	local size = Vector3.new(CARDS.size[1], CARDS.size[2], 0.1)
	card.Size = size
	card.Color = Color3.fromRGB(255, 220, 120)
	card.Material = Enum.Material.Neon
	card.CFrame = CFrame.new(from)
	card.Parent = workspace
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local art = Instance.new("Decal")
		art.Face = face
		art.Texture = CardArt.pick(cardName, 320, CardArtConfig)
		art.Parent = card
	end
	local spin = Instance.new("NumberValue")
	TweenService:Create(spin, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 }):Play()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not card.Parent then
			connection:Disconnect()
			return
		end
		local t = spin.Value
		local arc = from:Lerp(into, t) + Vector3.new(0, math.sin(t * math.pi) * 5, 0)
		card.CFrame = CFrame.new(arc) * CFrame.Angles(0, t * math.pi * 6, t * 1.5)
		card.Size = size * (1 - t * 0.7)
	end)
	task.delay(seconds, function()
		card:Destroy()
		spin:Destroy()
	end)
end

-- Your weapon breaking: bright shards bursting from your hand and falling
local function shatter(at: Vector3)
	for _ = 1, 16 do
		local shard = Instance.new("Part")
		shard.Anchored = false
		shard.CanCollide = false
		shard.CanQuery = false
		shard.Material = Enum.Material.Neon
		shard.Color = Color3.fromHSV(math.random(), 0.4, 1)
		shard.Size = Vector3.new(0.3, 0.9 + math.random(), 0.12)
		shard.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		shard.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 30, 14 + math.random() * 14, (math.random() - 0.5) * 30)
		shard.Parent = workspace
		TweenService:Create(shard, TweenInfo.new(1.4), { Transparency = 1 }):Play()
		task.delay(1.5, shard.Destroy, shard)
	end
end

-- A puff of dust off the floor where you land
local function dust(at: Vector3)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(4, 0.2, 4)
	holder.CFrame = CFrame.new(at)
	holder.Parent = workspace
	local puff = Instance.new("ParticleEmitter")
	puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
	puff.Color = ColorSequence.new(Color3.fromRGB(190, 180, 210))
	puff.Size = NumberSequence.new(1.2, 3.5)
	puff.Transparency = NumberSequence.new(0.4, 1)
	puff.Lifetime = NumberRange.new(0.6, 1.1)
	puff.Speed = NumberRange.new(4, 9)
	puff.SpreadAngle = Vector2.new(80, 10)
	puff.Drag = 3
	puff.Enabled = false
	puff.Parent = holder
	puff:Emit(24)
	task.delay(2, holder.Destroy, holder)
end

local function glowPart(name: string, shape: Enum.PartType, at: CFrame, size: Vector3): Part
	local made = Instance.new("Part")
	made.Name = name
	made.Shape = shape
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Material = Enum.Material.Neon
	made.Size = size
	made.CFrame = at
	made.Parent = workspace
	return made
end

-- The Hydra's prism blast, part 1 (owner 2026-11-16: "a massive attack that makes the player knocked out"): rainbow
-- light gathering into an orb at its mouth over `seconds`, shimmering through every colour, sparks streaming off it.
-- Returns its removal (it goes by itself a little after its time too)
local function prismOrb(at: Vector3, seconds: number): () -> ()
	local orb = glowPart("PrologueOrb", Enum.PartType.Ball, CFrame.new(at), Vector3.one * BLAST.orb[1])
	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 3
	light.Parent = orb
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new(0.8, 0.1)
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Rate = 90
	sparks.Speed = NumberRange.new(6, 12)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = orb
	local started = os.clock()
	local growing = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - started) / seconds)
		orb.Size = Vector3.one * (BLAST.orb[1] + (BLAST.orb[2] - BLAST.orb[1]) * t * t)
		local hue = Color3.fromHSV((os.clock() * 1.6) % 1, 0.55, 1)
		orb.Color = hue
		light.Color = hue
		sparks.Color = ColorSequence.new(hue)
	end)
	local removed = false
	local function remove()
		if removed then
			return
		end
		removed = true
		growing:Disconnect()
		orb:Destroy()
	end
	task.delay(seconds + 3, remove)
	return remove
end

-- Part 2: a thick rainbow beam with a white-hot core from its mouth to you for `seconds`, and a shockwave ring spreading
-- across the floor from your feet
local function prismBeam(from: Vector3, to: Vector3, feet: Vector3, seconds: number)
	local ends = glowPart("PrologueBeam", Enum.PartType.Block, CFrame.new(from), Vector3.one * 0.2)
	ends.Transparency = 1
	local startAt = Instance.new("Attachment")
	startAt.Parent = ends
	local endAt = Instance.new("Attachment")
	endAt.Parent = ends
	endAt.WorldPosition = to
	local rainbow = Instance.new("Beam")
	rainbow.Attachment0 = startAt
	rainbow.Attachment1 = endAt
	rainbow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 110)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 180, 70)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 110)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(110, 240, 140)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(100, 190, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 130, 255)),
	})
	rainbow.Width0 = BLAST.width
	rainbow.Width1 = BLAST.width * 1.4
	rainbow.LightEmission = 1
	rainbow.LightInfluence = 0
	rainbow.FaceCamera = true
	rainbow.Transparency = NumberSequence.new(0.05)
	rainbow.Parent = ends
	local core = rainbow:Clone()
	core.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	core.Width0 = BLAST.width * 0.35
	core.Width1 = BLAST.width * 0.5
	core.Parent = ends
	-- the shockwave: a thin glowing disc spreading out from your feet and fading
	local ring = glowPart("PrologueShockwave", Enum.PartType.Cylinder, CFrame.new(feet) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.2, 2, 2))
	ring.Color = Color3.fromRGB(255, 240, 255)
	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, BLAST.ring, BLAST.ring),
		Transparency = 1,
	}):Play()
	task.delay(0.7, ring.Destroy, ring)
	task.delay(seconds, ends.Destroy, ends)
end

-- Every card in the game but your three Legendaries, shuffled: what the Hydra takes after them
local function otherCards(): { string }
	local names: { string } = {}
	for _, card in Cards.List do
		table.insert(names, card.name)
	end
	Random.new():Shuffle(names)
	return names
end

-- Your weapon in hand, gone from this screen (it shatters; the one you own comes back with your loadout and
-- SwordController drops this one then). Taken out of the world: the camera's own fading resets a modifier on anything
-- in the character.
local function hideWeapon(character: Model)
	local weapon = Weapons.ById[Prologue.LOADOUT.weapon]
	local model = if weapon then character:FindFirstChild(weapon.model) else nil
	if model then
		model.Parent = nil
	end
end

-- Asks the server for this player's lair (its loadout lent there): its middle, or nil if there's no prologue now
local function askArena(seconds: number): Vector3?
	local answered, centre = false, nil
	local connection = Remotes.PrologueArena.OnClientEvent:Connect(function(at: unknown)
		answered = true
		centre = if typeof(at) == "Vector3" then at else nil
	end)
	Remotes.PrologueStep:FireServer("begin")
	local started = os.clock()
	while not answered and os.clock() - started < seconds do
		task.wait()
	end
	connection:Disconnect()
	return centre
end

local function flat(vector: Vector3): Vector3
	local level = Vector3.new(vector.X, 0, vector.Z)
	return if level.Magnitude > 0.01 then level.Unit else Vector3.zAxis
end

local function play()
	if playing then
		return
	end
	playing = true
	ScreenClear.wait() -- a purchase dialog or the Roblox menu first
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		playing = false
		return
	end
	local centre = askArena(8)
	if not centre then
		-- no prologue now (the server said no or never answered): on to the welcome flight
		playing = false
		Remotes.PrologueSeen:FireServer()
		return
	end
	local stage = PrologueStage.enter(centre)
	-- each part's music (Config/Music PROLOGUE, MusicController; this screen only)
	local function music(part: string?)
		player:SetAttribute("PrologueMusic", part)
	end
	music("lair")
	local camera = workspace.CurrentCamera
	local hydra: PrologueHydra.Hydra? = nil
	local entrance: HydraEntrance.Entrance? = nil
	local glow: Attachment? = aura(root)
	local body: PrologueBody.Body? = nil
	local wake: PrologueWake.Wake? = nil
	local blur: BlurEffect? = nil
	local standAt: CFrame? = nil
	local finished = false
	local cameraHold: string? = nil
	local connections: { RBXScriptConnection } = {}

	local function holdCamera(name: string, frame: (t: number) -> CFrame)
		if cameraHold then
			RunService:UnbindFromRenderStep(cameraHold)
		end
		cameraHold = name
		local started = os.clock()
		camera.CameraType = Enum.CameraType.Scriptable
		RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
			camera.CFrame = frame(os.clock() - started)
		end)
	end
	local function releaseCamera()
		if cameraHold then
			RunService:UnbindFromRenderStep(cameraHold)
			cameraHold = nil
		end
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end

	-- Every way out: put everything back, stand up at your shop, mark it seen (the server ends a fight still on and
	-- gives your own loadout back; the welcome flight then starts)
	local function finish()
		if finished then
			return
		end
		finished = true
		for _, connection in connections do
			connection:Disconnect()
		end
		releaseCamera()
		if hydra then
			hydra.destroy()
		end
		if entrance then
			entrance.finish()
		end
		if glow then
			glow:Destroy()
		end
		if blur then
			blur:Destroy()
		end
		if wake then
			wake.destroy()
		end
		if body then
			body.release()
		end
		if humanoid and humanoid.Parent then
			humanoid.PlatformStand = false
		end
		TownPishController.SetHidden(false)
		TownChikinController.SetHidden(false)
		music(nil)
		stage.leave(standAt)
		Remotes.PrologueSeen:FireServer()
		playing = false
	end
	table.insert(connections, humanoid.Died:Connect(finish))
	table.insert(connections, player.CharacterRemoving:Connect(finish))
	local function wait(seconds: number): boolean
		task.wait(seconds)
		return not finished
	end
	local function flash()
		stage.fade(true, 0.08, true)
		task.delay(0.1, function()
			if not finished then
				stage.fade(false, 0.5, true)
			end
		end)
	end

	-- Act 1: the lair, you at your strongest, the Hydra rising (your Legendary only comes out for the fight: owner
	-- 2026-11-15, it blocked the view)
	stage.bars(true)
	stage.fade(false, 1.2)
	holdCamera("PrologueOrbit", function(t: number): CFrame
		local angle = math.rad(200 - t * 14)
		local at = root.Position + Vector3.new(math.sin(angle) * 16, 5 + t * 0.2, math.cos(angle) * 16)
		return CFrame.lookAt(at, root.Position + Vector3.new(0, 2, 0))
	end)
	-- the legend, a line at a time as the camera circles you (owner 2026-11-16: better storytelling)
	stage.caption(CAPTIONS.open[1], 3)
	local hydraSpot = stage.spot("hydra")
	hydra = PrologueHydra.spawn(hydraSpot - Vector3.new(0, 45, 0))
	if not wait(3.1) then
		return
	end
	stage.caption(CAPTIONS.open[2], 3)
	if not wait(3.1) then
		return
	end
	stage.caption(CAPTIONS.open[3], 4.6)
	-- Its entrance (owner 2026-11-17: "make young hydra entrance more epic"; Util/HydraEntrance): the lair shakes harder
	-- and harder as rainbow cracks race over the floor from its spot, the floor bursts in a pillar of light and crystal
	-- shards, it erupts out of the light, and its roar, close up, sends a shockwave and a white flash through the lair
	holdCamera("PrologueRise", function(t: number): CFrame
		local from = root.Position + Vector3.new(6, 5, 14)
		local lift = math.clamp(t - ENTRANCE.crackSeconds, 0, ENTRANCE.rise) / ENTRANCE.rise
		return CFrame.lookAt(from, hydraSpot.Position + Vector3.new(0, 4 + lift * 18, 0))
	end)
	local fx = HydraEntrance.begin(hydraSpot, stage.ground)
	entrance = fx
	sound(RUMBLE, 0.55, stage.gui)
	fx.cracks(ENTRANCE.crackSeconds)
	for _, strength in ENTRANCE.rumble do
		ScreenFx.shake(strength)
		if not wait(ENTRANCE.rumbleGap) then
			return
		end
	end
	fx.burst()
	sound(BREAK, 0.6, stage.gui)
	flash()
	ScreenFx.shake(1)
	local rise = Instance.new("NumberValue")
	TweenService:Create(rise, TweenInfo.new(ENTRANCE.rise, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 }):Play()
	local rising = RunService.Heartbeat:Connect(function()
		local h = hydra
		if h and h.model.Parent then
			h.model:PivotTo(hydraSpot - Vector3.new(0, 45 * (1 - rise.Value), 0))
		end
	end)
	table.insert(connections, rising)
	if not wait(ENTRANCE.rise + 0.15) then
		return
	end
	rising:Disconnect()
	-- its roar, the camera close and low, looking up at it
	holdCamera("PrologueRoar", function(t: number): CFrame
		local toward = (hydraSpot.Position - root.Position) * 0.32
		local from = root.Position + toward + Vector3.new(0, 2.5 + math.min(t, 1.6) * 0.6, 0)
		return CFrame.lookAt(from, hydraSpot.Position + Vector3.new(0, 15, 0))
	end)
	;(hydra :: PrologueHydra.Hydra).play("enrage") -- its roar
	sound(ROAR, 0.75, stage.gui)
	fx.shockwave()
	flash()
	ScreenFx.shake(1.3)
	if not wait(1.8) then
		return
	end
	fx.finish()
	entrance = nil
	stage.caption(CAPTIONS.hydra, 1.5, true)
	if not wait(1.6) then
		return
	end
	stage.caption(CAPTIONS.fight, 1.4, true)
	if not wait(1.4) then
		return
	end

	-- Act 2: the real boss fight (BattleService, the boss HUD); the server brings your first Legendary out with it and
	-- ends it at END_SHARE
	local started, ended = false, false
	local hydraAt: CFrame? = nil
	table.insert(connections, Remotes.BattleStarted.OnClientEvent:Connect(function()
		started = true
	end))
	table.insert(connections, Remotes.BattleEnded.OnClientEvent:Connect(function(summary: unknown)
		ended = true
		local at = if typeof(summary) == "table" then (summary :: any).hydraAt else nil
		hydraAt = if typeof(at) == "CFrame" then at else nil
	end))
	releaseCamera()
	stage.bars(false)
	stage.hold(false)
	music("fight")
	Remotes.PrologueStep:FireServer("fight")
	local asked = os.clock()
	while not started and not finished and os.clock() - asked < 6 do
		task.wait()
	end
	if finished then
		return
	end
	if started then
		-- the fight's Hydra (MonsterController's) takes over from the cinematic one under a flash
		flash()
		if hydra then
			hydra.destroy()
			hydra = nil
		end
		stage.screens(true)
		local since = os.clock()
		while not ended and not finished and os.clock() - since < 120 do
			task.wait(0.1)
		end
		if finished then
			return
		end
	end

	-- Act 3 (owner 2026-11-15): its blow knocks you down; you crawl toward it while it takes every card you have; you
	-- black out
	stage.screens(false)
	stage.hold(true)
	stage.bars(true)
	stage.caption("", 0.1)
	stage.skipButton(finish) -- only now: the opening and the fight can't be skipped (owner 2026-11-15)
	music("taken")
	-- your Legendary goes back into its card under the flash (it would hide you; its card flies with the others), and
	-- the cinematic Hydra takes the fight's place, close in front of you so it looms
	Remotes.PrologueStep:FireServer("vanish")
	flash()
	local floorY = stage.centre.Y
	local from = root.Position
	local toFoe = flat((if hydraAt then hydraAt.Position else hydraSpot.Position) - from)
	local right = toFoe:Cross(Vector3.yAxis)
	local foeAt = Vector3.new(from.X, floorY, from.Z) + toFoe * KNOCK.near
	if hydra then
		hydra.destroy()
	end
	local foe = PrologueHydra.spawn(CFrame.lookAt(foeAt, Vector3.new(from.X, floorY, from.Z)))
	hydra = foe
	local grabbed = PrologueBody.grab(character)
	if not grabbed then
		finish()
		return
	end
	body = grabbed
	local upright = CFrame.lookAt(from, from + toFoe)
	grabbed.place(upright)
	-- from your side: you on the left, the Hydra rearing up on the right
	holdCamera("PrologueBlow", function(t: number): CFrame
		return CFrame.lookAt(from + right * (17 - t) - toFoe * 3 + Vector3.new(0, 4, 0), from + toFoe * 7 + Vector3.new(0, 7, 0))
	end)
	-- its massive attack (owner 2026-11-16): it rears up roaring as its crystals blaze, rainbow light gathers into an
	-- orb at its mouth, then a prism blast knocks you out
	local mouth = foeAt + Vector3.new(0, foe.height * CARDS.mouth[1], 0) - toFoe * foe.height * CARDS.mouth[2]
	foe.play("enrage")
	sound(ROAR, 0.8, stage.gui)
	ScreenFx.shake(0.8)
	local blazing = RunService.Heartbeat:Connect(function()
		foe.glow(Color3.fromHSV((os.clock() * 0.8) % 1, 0.7, 1))
	end)
	table.insert(connections, blazing)
	if not wait(BLAST.rear) then
		return
	end
	local removeOrb = prismOrb(mouth, BLAST.charge)
	sound(BLAST.chargeSound, 0.7, stage.gui)
	ScreenFx.shake(0.5)
	if not wait(BLAST.charge) then
		removeOrb()
		return
	end
	removeOrb()
	blazing:Disconnect()
	foe.play("strike")
	prismBeam(mouth, from + Vector3.new(0, 1.5, 0), Vector3.new(from.X, floorY + 0.15, from.Z), BLAST.beam)
	sound(BLAST.blastSound, 0.9, stage.gui)
	-- the blow: your weapon shatters, your aura goes out, you're thrown back, tumbling, onto your face
	ScreenFx.shake(1.8)
	flash()
	local hand = character:FindFirstChild("RightHand")
	shatter(if hand and hand:IsA("BasePart") then hand.Position else from)
	sound(SHATTER, 0.8, stage.gui)
	hideWeapon(character)
	if glow then
		glow:Destroy()
		glow = nil
	end
	local offset = from - stage.centre
	local back = PrologueRules.knockRoom(offset.X, offset.Z, -toFoe.X, -toFoe.Z, Prologue)
	local landed = PrologueBody.faceDown(Vector3.new(from.X, floorY + KNOCK.lie, from.Z) - toFoe * back, toFoe)
	local thrownAt = os.clock()
	local thrown = RunService.RenderStepped:Connect(function()
		local k = PrologueRules.knock(os.clock() - thrownAt, Prologue)
		local share = k.back / KNOCK.back
		local y = from.Y + (floorY + KNOCK.lie - from.Y) * share + k.up
		local at = Vector3.new(from.X, 0, from.Z) - toFoe * back * share
		grabbed.place(CFrame.new(at.X, y, at.Z) * upright.Rotation * CFrame.Angles(math.rad(-k.flip), 0, 0))
	end)
	table.insert(connections, thrown)
	if not wait(KNOCK.seconds) then
		return
	end
	thrown:Disconnect()
	grabbed.place(landed)
	ScreenFx.shake(0.8)
	dust(Vector3.new(landed.X, floorY, landed.Z))
	if not wait(0.5) then
		return
	end

	-- you crawl toward it, reaching, while every card you have flies out of you into its mouths
	local crawlFrom = os.clock()
	local crawling = RunService.RenderStepped:Connect(function()
		local pose = PrologueRules.crawl(os.clock() - crawlFrom, Prologue)
		grabbed.pose(pose)
		grabbed.place(landed + toFoe * pose.advance)
	end)
	table.insert(connections, crawling)
	holdCamera("PrologueCrawl", function(t: number): CFrame
		local me = root.Position
		local near = 1 - 0.2 * math.min(t / 6, 1)
		local eye = me - toFoe * 8 * near + right * 4 * near + Vector3.new(0, 3.5, 0)
		return CFrame.lookAt(eye, me + toFoe * 6 + Vector3.new(0, 3.5, 0))
	end)
	-- the cards fly into its mouth (the young Hydra's one head, high at its front: Config/Prologue CARDS.mouth)
	stage.caption(CAPTIONS.swallow, 3.4)
	local taken = PrologueRules.stolenCards(Prologue, otherCards(), CARDS.count)
	for index, cardName in taken do
		task.delay((index - 1) * CARDS.every, function()
			if not finished then
				cardInto(cardName, root.Position + toFoe * 1.2 + Vector3.new(0, 1.2, 0), mouth, CARDS.seconds)
			end
		end)
	end
	local hues = 0
	local flaring = RunService.Heartbeat:Connect(function(dt)
		hues = (hues + dt * 0.5) % 1
		foe.glow(Color3.fromHSV(hues, 0.7, 1))
	end)
	table.insert(connections, flaring)
	if not wait(CRAWL.stroke * CRAWL.strokes + CRAWL.collapse * 0.6) then
		return
	end
	-- it grows from your power: five heads now (the Dungeon's Hydra)
	flaring:Disconnect()
	flash()
	local pivot = foe.model:GetPivot()
	foe.destroy()
	local grown = PrologueHydra.spawn(CFrame.new(pivot.Position.X, floorY, pivot.Position.Z) * pivot.Rotation, true)
	hydra = grown
	grown.play("enrage")
	sound(ROAR, 0.9, stage.gui)
	ScreenFx.shake(1.2)
	stage.caption(CAPTIONS.grow, 2.4)
	if not wait(1.8) then
		return
	end
	-- you black out (the server gives your own loadout back in the dark)
	Remotes.PrologueStep:FireServer("take")
	local blurring = Instance.new("BlurEffect")
	blurring.Name = "PrologueBlackout"
	blurring.Size = 0
	blurring.Parent = camera
	blur = blurring
	TweenService:Create(blurring, TweenInfo.new(BLACKOUT.seconds), { Size = BLACKOUT.blur }):Play()
	stage.fade(true, BLACKOUT.seconds)
	if not wait(BLACKOUT.seconds + 0.3) then
		return
	end
	stage.caption(CAPTIONS.took, 3.4, true)
	if not wait(3.8) then
		return
	end

	-- In town: your eyes open on Pish and Chikin waking you up in front of your shop
	crawling:Disconnect()
	grabbed.pose(nil)
	grown.destroy()
	hydra = nil
	blurring:Destroy()
	blur = nil
	TownPishController.SetHidden(true) -- the town's own dogs: these two are them
	TownChikinController.SetHidden(true)
	local door = stage.home()
	if not door then
		finish()
		return
	end
	local scene = PrologueWake.new(stage.gui, stage.covers, character, door)
	wake = scene
	music("wake")
	grabbed.place(scene.lying)
	grabbed.pose(WAKE.pose)
	stage.bars(false)
	stage.fade(false, 0) -- the shut lids hide it now
	local wokeAt = os.clock()
	local waking = RunService.RenderStepped:Connect(function(dt: number)
		scene.step(os.clock() - wokeAt, dt)
	end)
	table.insert(connections, waking)
	holdCamera("PrologueWake", scene.eye)
	local lines = CAPTIONS.wake
	local beats: { { at: number, run: () -> () } } = {
		{ at = 0.3, run = function() scene.play("Pish", "bark") end },
		{ at = 1.8, run = function() scene.say(lines[1].dog, lines[1].text, 2.2) end },
		{ at = 2.6, run = function() scene.play("Chikin", "headTilt") end },
		{ at = 4.2, run = function() scene.say(lines[2].dog, lines[2].text, 2.2) scene.play("Pish", "headTilt") end },
		{ at = 6.6, run = function() scene.say(lines[3].dog, lines[3].text, 2.6) scene.play("Chikin", "bark") end },
		{ at = 9.4, run = function() scene.say(lines[4].dog, lines[4].text, 2.8) scene.play("Pish", "headTilt") end },
		{ at = 12.4, run = function() scene.say(lines[5].dog, lines[5].text, 2.6) scene.play("Chikin", "bark") end },
	}
	for _, beat in beats do
		task.delay(beat.at, function()
			if not finished then
				beat.run()
			end
		end)
	end
	if not wait(15.2) then
		return
	end
	-- you get up; they hop for joy
	scene.getUp()
	grabbed.release()
	body = nil
	standAt = scene.standing
	character:PivotTo(scene.standing)
	releaseCamera()
	camera.CFrame = CFrame.lookAt(scene.standing.Position - scene.standing.LookVector * 9 + Vector3.new(0, 4, 0), scene.standing.Position + scene.standing.LookVector * 3)
	scene.play("Pish", "happyHop")
	scene.play("Chikin", "happyHop")
	if not wait(1.8) then
		return
	end
	stage.fade(true, 0.35)
	if not wait(0.4) then
		return
	end
	finish()
end

-- The prologue's models fetched while the loading screen is still up (a new player only): the Hydra, the lair's crystal
-- pieces, the three Legendaries, the weapon and Pish and Chikin, so nothing pops in as it plays
local preloaded = false
local function preload()
	if preloaded then
		return
	end
	preloaded = true
	local items: { Instance } = {}
	local function add(folderName: string, name: string)
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		local found = if folder then folder:FindFirstChild(name) else nil
		if found then
			table.insert(items, found)
		end
	end
	add("MonsterModels", Prologue.HYDRA.model)
	add("MonsterModels", Prologue.HYDRA.boss)
	add("NpcModels", "Pish")
	add("NpcModels", "Chikin")
	local props = ReplicatedStorage:FindFirstChild("PropModels")
	for _, name in { "DungeonSigil", "DungeonPillar", "DungeonCrystals", "DungeonPillarBroken", "CrystalPylon", "ElementCrystal" } do
		local prop = props and props:FindFirstChild(name)
		if prop then
			table.insert(items, prop)
		end
	end
	for _, cardName in Prologue.LOADOUT.creatures do
		local template = CreatureVisuals.cardTemplate(cardName)
		if template then
			table.insert(items, template)
		end
	end
	local weapons = ReplicatedStorage:FindFirstChild("WeaponModels")
	local weapon = Weapons.ById[Prologue.LOADOUT.weapon]
	local model = weapons and weapon and weapons:FindFirstChild(weapon.model)
	if model then
		table.insert(items, model)
	end
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, items)
	end)
end

function PrologueController.Start()
	if Place.isFrontier() or Place.isDungeon() then
		return
	end
	local function check()
		if player:GetAttribute("SeenPrologue") == false then
			preload()
		end
		if playing or player:GetAttribute("SeenPrologue") ~= false or player:GetAttribute("LoadingDone") ~= true then
			return
		end
		task.spawn(play)
	end
	player:GetAttributeChangedSignal("SeenPrologue"):Connect(check)
	player:GetAttributeChangedSignal("LoadingDone"):Connect(check)
	Remotes.PrologueReplay.OnClientEvent:Connect(function()
		task.spawn(play)
	end)
	check()
end

return PrologueController
