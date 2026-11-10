--!strict
-- Town Pish (spec 2026-11-09-tutorial-pish-design 4, 7): one dog per server that everyone sees, the owner's own Shih
-- Tzu. The server moves an invisible marker (workspace.PishNpc.TownPish) round the town's street stops and to open shops'
-- doors, at a dog's walk, going round the plaza fountain (Util/PishPath), and between walks picks a random idle clip
-- (never the same twice running) or a nap. Clients draw him on the marker (Client/Controllers/TownPishController) and
-- play the clip named by its Clip attribute each time ClipId changes.
-- Petting him (a ProximityPrompt on the marker) only at your own shop's door, after your first visit (owner 2026-11-10;
-- his VisitingOwner attribute, the client shows the prompt only then): he stops, faces the player and plays "petted";
-- within LUCK.petRange, once per LUCK.cooldown, it gives Pish's Luck for LUCK.seconds (PackService.SetLuck; the
-- player's PishLuckUntil attribute, os.time).
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CustomerConfig = require(Config:WaitForChild("Customers"))
local Pish = require(Config:WaitForChild("Pish"))
local Plaza = require(Config:WaitForChild("Plaza"))
local PlotConfig = require(Config:WaitForChild("Plots"))
local Town = require(Config:WaitForChild("Town"))
local Wild = require(Config:WaitForChild("Wild"))
local LuckRules = require(Shared:WaitForChild("Util"):WaitForChild("LuckRules"))
local PishPath = require(Shared:WaitForChild("Util"):WaitForChild("PishPath"))
local WalkerRules = require(Shared:WaitForChild("Util"):WaitForChild("WalkerRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local RateLimiter = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("RateLimiter"))
local PackService = require(Services:WaitForChild("PackService"))
local PlotService = require(Services:WaitForChild("PlotService"))

local PishService = {}

local PET_COOLDOWN = 2 -- seconds between one player's pets (the cuddle plays every time)
local PETTED_SECONDS = 2.5 -- he holds still this long for the "petted" clip
local DOOR_STEP = 3 -- studs out in front of a shop's doorway, on the sidewalk
local FOUNTAIN_CLEAR = 2 -- studs kept from the fountain's base

local rng = Random.new()
local marker: Part
local stops: { Vector3 } = {}
local clipId = 0
local lastClip: string? = nil
local pettedUntil = 0
local luckAt: { [Player]: number } = {} -- os.time of each player's last luck from him (TutorialService saves it later)
local allowPet = RateLimiter.new(PET_COOLDOWN)

local function ground(x: number, z: number): Vector3
	return Vector3.new(x, Wild.SPRING.y, z)
end

local function play(clip: string)
	clipId += 1
	lastClip = clip
	marker:SetAttribute("Clip", clip)
	marker:SetAttribute("ClipId", clipId)
end

local function face(point: Vector3)
	local at = marker.Position
	local flat = Vector3.new(point.X, at.Y, point.Z)
	if (flat - at).Magnitude > 0.05 then
		marker.CFrame = CFrame.lookAt(at, flat)
	end
end

-- Holds still while he's being petted, at most Pish.TOWN.petHoldMax seconds at a time (PishPath.holdEnd)
local function waitWhilePetted()
	local started = os.clock()
	while os.clock() < PishPath.holdEnd(pettedUntil, started, Pish.TOWN.petHoldMax) do
		task.wait(0.1)
	end
end

local function waitFor(seconds: number)
	local finish = os.clock() + seconds
	local holdLeft = Pish.TOWN.petHoldMax -- petting can stretch this wait by this much in all
	while os.clock() < finish do
		task.wait(0.1)
		if holdLeft > 0 and os.clock() < pettedUntil then
			local before = os.clock()
			waitWhilePetted()
			holdLeft -= os.clock() - before
		end
	end
end

-- Walks the marker to `target`, round the fountain, at `speed` studs a second
local function walkTo(target: Vector3, speed: number)
	local centre = { x = Wild.SPRING.x, z = Wild.SPRING.z }
	local here = marker.Position
	local points = PishPath.route({ x = here.X, z = here.Z }, { x = target.X, z = target.Z }, centre, Plaza.FOUNTAIN_RADIUS + FOUNTAIN_CLEAR)
	marker:SetAttribute("Moving", true)
	local holdLeft = Pish.TOWN.petHoldMax -- petting can stop this walk for this long in all
	for _, point in points do
		local goal = ground(point.x, point.z)
		face(goal)
		while (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(marker.Position.X, 0, marker.Position.Z)).Magnitude > 0.2 do
			if holdLeft > 0 and os.clock() < pettedUntil then
				marker:SetAttribute("Moving", false)
				local before = os.clock()
				waitWhilePetted()
				holdLeft -= os.clock() - before
				marker:SetAttribute("Moving", true)
				face(goal)
			end
			local dt = RunService.Heartbeat:Wait()
			local at = marker.Position
			local step = goal - Vector3.new(at.X, goal.Y, at.Z)
			local move = math.min(step.Magnitude, speed * dt)
			local next = Vector3.new(at.X, goal.Y, at.Z) + step.Unit * move
			marker.CFrame = CFrame.lookAt(next, next + step.Unit)
		end
	end
	marker:SetAttribute("Moving", false)
end

-- An open shop's doorway (its owner in the game), seen from the street, and its owner; or nil
local function shopDoor(): (Vector3?, Vector3?, Player?)
	local open = {}
	for _, plot in PlotService.GetPlots() do
		if plot.owner and plot.owner.Parent then
			table.insert(open, plot)
		end
	end
	if #open == 0 then
		return nil, nil, nil
	end
	local plot = open[rng:NextInteger(1, #open)]
	local floor = plot.floor
	local outward = Vector3.new(floor.CFrame.LookVector.X, 0, floor.CFrame.LookVector.Z).Unit
	local doorway = floor.Position + outward * PlotConfig.DEPTH / 2
	local outside = doorway + outward * DOOR_STEP
	return ground(outside.X, outside.Z), ground(doorway.X, doorway.Z), plot.owner
end

local function idle()
	if rng:NextNumber() < Pish.TOWN.napChance then
		play("nap")
		return
	end
	local clips = Pish.TOWN.idleClips
	local clip = clips[rng:NextInteger(1, #clips)]
	if clip == lastClip then
		clip = clips[(table.find(clips, clip) :: number) % #clips + 1]
	end
	play(clip)
end

local function day()
	while true do
		local town = Pish.TOWN
		local door, doorway, owner = nil, nil, nil
		if rng:NextNumber() < town.shopChance then
			door, doorway, owner = shopDoor()
		end
		if door and doorway and owner then
			walkTo(door, town.speed)
			face(doorway)
			play(if rng:NextNumber() < 0.5 then "sit" else "sniff")
			-- At this shop's door: its owner may pet him (owner 2026-11-10), once their first visit is done
			marker:SetAttribute("VisitingOwner", owner.UserId)
			waitFor(rng:NextNumber(town.visitSeconds[1], town.visitSeconds[2]))
			marker:SetAttribute("VisitingOwner", 0)
		elseif #stops > 0 then
			walkTo(stops[rng:NextInteger(1, #stops)], town.speed)
			idle()
		end
		waitFor(rng:NextNumber(town.idleEvery[1], town.idleEvery[2]))
	end
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function onPet(player: Player)
	if not allowPet(player) then
		return
	end
	local root = characterRoot(player)
	if not root then
		return
	end
	local near = (root.Position - marker.Position).Magnitude <= Pish.LUCK.petRange + 2
	local visitingYou = marker:GetAttribute("VisitingOwner") == player.UserId
	if not near or not visitingYou or player:GetAttribute("TutorialDone") ~= true then
		return -- only at your own shop's door, after your first visit (the client shows the prompt only then)
	end
	pettedUntil = os.clock() + PETTED_SECONDS
	face(root.Position)
	marker:SetAttribute("Petting", player.UserId)
	play("petted")
	task.delay(PETTED_SECONDS, function()
		if os.clock() >= pettedUntil then
			marker:SetAttribute("Petting", 0)
		end
	end)
	local now = os.time()
	local lucky = LuckRules.canGrant(luckAt[player], now, Pish.LUCK.cooldown)
	if lucky then
		luckAt[player] = now
		local untilTime = now + Pish.LUCK.seconds
		player:SetAttribute("PishLuckUntil", untilTime)
		PackService.SetLuck(player, untilTime)
	end
	Remotes.PishPetted:FireAllClients(player.UserId, lucky)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, "PishPetted", if lucky then 1 else 0)
	end)
end

-- The last time a player had luck from him, and setting it: TutorialService loads it (petting gives nothing until
-- then), saves it and forgets it on unload, so it lives in DataService's lifecycle
function PishService.GetLuckAt(player: Player): number
	return luckAt[player] or 0
end

function PishService.SetLuckAt(player: Player, at: number)
	luckAt[player] = at
end

function PishService.ForgetLuck(player: Player)
	luckAt[player] = nil
end

-- Studio's /pish: Town Pish comes to you, as if visiting your shop (so petting can be tried)
function PishService.ComeTo(player: Player)
	local root = characterRoot(player)
	if root and marker then
		marker.CFrame = CFrame.new(ground(root.Position.X + 4, root.Position.Z))
		marker:SetAttribute("VisitingOwner", player.UserId)
	end
end

function PishService.Start()
	-- No model, no Town Pish: an invisible marker would carry a "Pet" prompt round the town on nothing
	local models = ReplicatedStorage:FindFirstChild("NpcModels")
	if not models or not models:FindFirstChild("Pish") then
		warn("[PishService] ReplicatedStorage.NpcModels.Pish is missing: Town Pish stays home")
		return
	end
	local world: WalkerRules.World = {
		perRow = PlotConfig.PER_ROW,
		plotWidth = PlotConfig.WIDTH,
		plotDepth = PlotConfig.DEPTH,
		gap = PlotConfig.GAP,
		streetWidth = PlotConfig.STREET_WIDTH,
		spring = { x = Wild.SPRING.x, z = Wild.SPRING.z },
	}
	for _, stop in WalkerRules.townStops(CustomerConfig, Town, world) do
		table.insert(stops, ground(stop.x, stop.z))
	end

	local folder = Instance.new("Folder")
	folder.Name = "PishNpc"
	folder.Parent = workspace
	marker = Instance.new("Part")
	marker.Name = "TownPish"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(2, 2, 2)
	local start = stops[1] or ground(Wild.SPRING.x + Plaza.FOUNTAIN_RADIUS + 6, Wild.SPRING.z)
	marker.CFrame = CFrame.new(start)
	marker:SetAttribute("Clip", "")
	marker:SetAttribute("ClipId", 0)
	marker:SetAttribute("Moving", false)
	marker:SetAttribute("Petting", 0)
	marker.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PetPrompt"
	prompt.ActionText = "Pet"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = Pish.LUCK.petRange
	prompt.Parent = marker
	prompt.Triggered:Connect(onPet)
	task.spawn(day)
end

return PishService
