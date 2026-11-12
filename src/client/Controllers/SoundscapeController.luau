--!strict
-- The worlds' soundscape on this client (the owner 2026-11-11: "make it more immersive"; Config/Soundscape,
-- Util/SoundscapeRules). A few times a second it looks where you are: in town, the Wild valley's or the Frontier's
-- biomes (never a boss arena's copy, never the Dungeon). Each spot group there plays one of its sounds now and then from
-- somewhere round you (birds in the trees, cave drips, a wolf far off). In town the day groups fade out and the night
-- ones in with the clock (SoundscapeRules.nightShare), the birds' loop (Config/Scenery SOUNDS) fades out and a crickets
-- loop in. In town and the Meadow the wind gusts now and then: its rustle swells and dies, the trees bend harder
-- (Util/Gust, TreeSwayController) and leaves blow past the camera (only while the extras run, Util/Extras).
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Cycle = require(Config:WaitForChild("DayCycle"))
local Soundscape = require(Config:WaitForChild("Soundscape"))
local SharedUtil = Shared:WaitForChild("Util")
local DayCycle = require(SharedUtil:WaitForChild("DayCycle"))
local Place = require(SharedUtil:WaitForChild("Place"))
local SoundscapeRules = require(SharedUtil:WaitForChild("SoundscapeRules"))
local WildValley = require(SharedUtil:WaitForChild("WildValley"))

local ClientUtil = ((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util")
local Extras = require(ClientUtil:WaitForChild("Extras"))
local Gust = require(ClientUtil:WaitForChild("Gust"))

local SoundscapeController = {}

local Valley = Place.getValley() -- this place's valley (Util/Place)

local GUST = Soundscape.GUST
local BED_EASE = 0.5 -- of the way to its target volume per check (a smooth fade)
local LEAVES_AHEAD = 14 -- studs in front of the camera the gust's leaves blow through

type Group = { key: string, spot: Soundscape.Spot, kind: string }

local rng = Random.new()
local nextAt: { [string]: number } = {}
local nightBed: Sound? = nil
local dayBed: Sound? = nil
local dayBedVolume = 0
local gustAt = 0 -- when the current gust began (0: none yet)
local gustNext = 0
local gustSound: Sound? = nil
local leaves: ParticleEmitter? = nil

-- Where the listener is: your character, or the camera's focus while you have none
local function listener(): Vector3
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return workspace.CurrentCamera.Focus.Position
end

-- The spot groups that play here (keys stay the same while you stay in the area) and whether it's the town
local function groupsAt(at: Vector3): ({ Group }, boolean)
	local list: { Group } = {}
	if WildValley.arenaZoneAt(Valley, Bosses.ARENA_COPIES, at.X, at.Z) then
		return list, false
	end
	if not Place.isFrontier() and DayCycle.inTown(Cycle, at.X, at.Z) then
		for index, spot in Soundscape.TOWN.day do
			table.insert(list, { key = `town/day/{index}`, spot = spot, kind = "day" })
		end
		for index, spot in Soundscape.TOWN.night do
			table.insert(list, { key = `town/night/{index}`, spot = spot, kind = "night" })
		end
		return list, true
	end
	local zone = WildValley.zoneAt(Valley, { x = at.X, z = at.Z })
	local spots = if zone then (if Place.isFrontier() then Soundscape.FRONTIER else Soundscape.WILD)[zone] else nil
	for index, spot in spots or {} do
		table.insert(list, { key = `zone/{zone}/{index}`, spot = spot, kind = "zone" })
	end
	return list, false
end

-- One of the spot's sounds from somewhere round `at`
local function play(spot: Soundscape.Spot, at: Vector3)
	local offset = SoundscapeRules.spotOffset(rng:NextNumber(), rng:NextNumber(), rng:NextNumber(), spot)
	local holder = Instance.new("Attachment")
	holder.Name = "SoundscapeSpot"
	holder.WorldPosition = at + Vector3.new(offset.x, offset.y, offset.z)
	holder.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = spot.ids[rng:NextInteger(1, #spot.ids)]
	sound.Volume = spot.volume
	sound.PlaybackSpeed = rng:NextNumber(spot.pitch[1], spot.pitch[2])
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = spot.range * 0.15
	sound.RollOffMaxDistance = spot.range
	sound.Parent = holder
	sound.Ended:Once(function()
		holder:Destroy()
	end)
	sound:Play()
	Debris:AddItem(holder, 20)
end

local function loop(id: string, name: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	return sound
end

-- The town's beds: the birds' loop out and the crickets' in with the night (and the crickets only in town). The birds'
-- holder can stream out and back in as a new part: it's looked up again then (its volume is the server's again).
local function beds(night: number, inTown: boolean)
	local current = dayBed
	if current and not current:IsDescendantOf(workspace) then
		dayBed = nil
	end
	if not dayBed then
		local scenery = workspace:FindFirstChild("Scenery")
		local holder = if scenery then scenery:FindFirstChild(Soundscape.TOWN.dayBed, true) else nil
		local sound = if holder then holder:FindFirstChildOfClass("Sound") else nil
		if sound then
			dayBed = sound
			dayBedVolume = sound.Volume
		end
	end
	local birds = dayBed
	if birds then
		birds.Volume = dayBedVolume * (1 - night)
	end
	local crickets = nightBed or loop(Soundscape.TOWN.nightBed.id, "NightBed")
	nightBed = crickets
	local target = Soundscape.TOWN.nightBed.volume * (if inTown then night else 0)
	crickets.Volume += (target - crickets.Volume) * BED_EASE
	if crickets.Volume > 0.002 and not crickets.IsPlaying then
		crickets:Play()
	elseif crickets.Volume <= 0.002 and target <= 0 and crickets.IsPlaying then
		crickets:Stop()
	end
end

-- The leaves a gust blows past the camera (made once, moved with the camera each frame while a gust blows)
local function leafEmitter(): ParticleEmitter
	if leaves and leaves.Parent then
		return leaves
	end
	local part = Instance.new("Part")
	part.Name = "GustLeaves"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 16, 26)
	part.Parent = workspace.CurrentCamera
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 200, 90), Color3.fromRGB(230, 200, 80))
	emitter.LightEmission = 0
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.EmissionDirection = Enum.NormalId.Right
	emitter.Speed = NumberRange.new(GUST.leaves.speed[1], GUST.leaves.speed[2])
	emitter.SpreadAngle = Vector2.new(15, 25)
	emitter.Acceleration = Vector3.new(0, -2, 0)
	emitter.Lifetime = NumberRange.new(2.5, 3.5)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.Size = NumberSequence.new(GUST.leaves.size)
	emitter.Rate = 0
	emitter.Parent = part
	leaves = emitter
	return emitter
end

-- A gust's sound: a stretch of the rustle, faded by the gust's shape
local function gustNoise(): Sound
	local sound = gustSound or loop(GUST.sound, "GustSound")
	gustSound = sound
	return sound
end

local function gusts(now: number, windy: boolean)
	local strength = if gustAt > 0 then SoundscapeRules.gustShape(now - gustAt, GUST) else 0
	if windy and strength <= 0 and now >= gustNext then
		gustAt = now
		gustNext = SoundscapeRules.nextAt(now, GUST.every, rng:NextNumber())
		local sound = gustNoise()
		sound.TimePosition = rng:NextNumber(0, GUST.soundLength - GUST.seconds - 1)
		sound.Volume = 0
		sound:Play()
	end
	if not windy then
		strength = 0
	end
	Gust.set(strength)
	local sound = gustSound
	if sound then
		sound.Volume = GUST.volume * strength
		if strength <= 0 and sound.IsPlaying then
			sound:Stop()
		end
	end
	local emitter = if strength > 0 and Extras.enabled() then leafEmitter() else leaves
	if emitter then
		emitter.Rate = if Extras.enabled() then GUST.leaves.rate * strength else 0
		if strength > 0 then
			-- Upwind of the view, blowing across it from the left
			local camera = workspace.CurrentCamera.CFrame
			local at = camera.Position + camera.LookVector * LEAVES_AHEAD - camera.RightVector * 16
			local holder = emitter.Parent :: BasePart
			holder.CFrame = CFrame.lookAt(at, at + camera.LookVector)
		end
	end
end

function SoundscapeController.Start()
	if Place.isDungeon() then
		return
	end
	gustNext = os.clock() + SoundscapeRules.nextAt(0, GUST.every, rng:NextNumber())
	local area: string? = nil
	local sinceCheck = 0
	local inTown, windy = false, false
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		gusts(now, windy)
		sinceCheck += dt
		if sinceCheck < Soundscape.CHECK_EVERY then
			return
		end
		sinceCheck = 0
		local at = listener()
		local groups, town = groupsAt(at)
		inTown = town
		windy = town or (not Place.isFrontier() and WildValley.zoneAt(Valley, { x = at.X, z = at.Z }) == 1)
		local night = if inTown then SoundscapeRules.nightShare(Lighting.ClockTime, Soundscape.NIGHT) else 0
		if not Place.isFrontier() then
			beds(if inTown then night else 0, inTown)
		end
		-- A new area: its groups start their own timers (no burst of sounds on arrival)
		local here = if #groups > 0 then groups[1].key else nil
		if here ~= area then
			area = here
			table.clear(nextAt)
			for _, group in groups do
				nextAt[group.key] = SoundscapeRules.nextAt(now, group.spot.every, rng:NextNumber())
			end
		end
		for _, group in groups do
			if now >= (nextAt[group.key] or math.huge) then
				nextAt[group.key] = SoundscapeRules.nextAt(now, group.spot.every, rng:NextNumber())
				if rng:NextNumber() < SoundscapeRules.weight(group.kind, night) then
					play(group.spot, at)
				end
			end
		end
	end)
end

return SoundscapeController
