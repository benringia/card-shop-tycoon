--!strict
-- The server wild map (battles part 1): a placeholder map far from the plots, the plaza portal and the
-- healing spring, and the wild monsters. The server only moves an invisible marker per monster in
-- workspace.Monsters; clients draw them (MonsterController). Monsters sleep with no player near, wander near
-- their spawn, and elites (and every monster in an aggro zone) chase players and report contact, which
-- BattleService turns into a fight. Fights themselves live in BattleService.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
-- The server wild map in the main game, the Frontier's map in the Frontier place (same shape)
local Wild = Place.getWorld()
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local PlotService = require(Services:WaitForChild("PlotService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

export type Monster = {
	id: string,
	species: string,
	level: number,
	elite: boolean,
	element: string,
	zone: number,
	home: Vector3,
	marker: Part,
	fightingPlayer: Player?,
	alive: boolean,
	spawnPoint: BasePart?, -- nil for dev-spawned monsters (no respawn)
	wanderTarget: Vector3?,
	waitUntil: number,
	chaseCooldownUntil: number,
}

local WildService = {}

local SPAWN_TAG = "WildSpawn"
local TRAVEL_COOLDOWN = 1
local ARRIVAL_LIFT = 3 -- studs above the pad, so characters drop onto it
local PORTAL_COLOR = Color3.fromRGB(120, 90, 255)
local SPRING_COLOR = Color3.fromRGB(80, 190, 255)

local monsters: { [string]: Monster } = {}
local monstersFolder: Folder
local inWild: { [Player]: boolean } = {}
local contactCallbacks: { (player: Player, monster: Monster) -> () } = {}
local travelBlockers: { (player: Player) -> string? } = {}
local homeHandler: ((player: Player) -> ())? = nil
local frontierSpawn: SpawnLocation? = nil -- Frontier: everyone spawns here (not on a template spawn pad)
local allowTravel = RateLimiter.new(TRAVEL_COOLDOWN)
local rng = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function vec(point: { x: number, y: number, z: number }): Vector3
	return Vector3.new(point.x, point.y, point.z)
end

local ORIGIN = vec(Wild.ORIGIN)

local function zoneCenter(index: number): Vector3
	return ORIGIN + Vector3.new(0, 0, (index - 1) * (Wild.ZONE_SIZE + Wild.ZONE_GAP))
end

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

-- Map building -------------------------------------------------------------------------------------------

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function sign(parent: Instance, text: string, cframe: CFrame)
	local board = block(parent, "Sign", Vector3.new(14, 5, 0.6), cframe, Color3.fromRGB(40, 40, 50))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(560, 200)
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
end

local function portal(parent: Instance, name: string, position: Vector3, facing: Vector3, actionText: string, onTriggered: (Player) -> ())
	local ring = block(parent, name, Vector3.new(1, 10, 10), CFrame.lookAt(position + Vector3.new(0, 5, 0), position + Vector3.new(0, 5, 0) + facing) * CFrame.Angles(0, math.rad(90), 0), PORTAL_COLOR, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.CanCollide = false
	ring.Transparency = 0.25
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = ring
	prompt.Triggered:Connect(onTriggered)
end

local function decorate(parent: Instance, center: Vector3, seed: number)
	local decor = Random.new(seed)
	local half = Wild.ZONE_SIZE / 2 - 6
	for _ = 1, 10 do
		local x = decor:NextNumber(-half, half)
		local z = decor:NextNumber(-half, half)
		local spot = center + Vector3.new(x, 0, z)
		if decor:NextNumber() < 0.6 then
			-- Cylinders run along X: stand the trunk up
			local trunk = block(parent, "Trunk", Vector3.new(6, 1.4, 1.4), CFrame.new(spot + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(100, 70, 45), Enum.Material.Wood)
			trunk.Shape = Enum.PartType.Cylinder
			local leaves = block(parent, "Leaves", Vector3.new(6, 6, 6), CFrame.new(spot + Vector3.new(0, 7.5, 0)), Color3.fromRGB(60, 140, 60), Enum.Material.Grass)
			leaves.Shape = Enum.PartType.Ball
		else
			local rock = block(parent, "Rock", Vector3.new(decor:NextNumber(2, 4), decor:NextNumber(1.5, 3), decor:NextNumber(2, 4)), CFrame.new(spot + Vector3.new(0, 1, 0)) * CFrame.Angles(0, decor:NextNumber(0, math.pi), 0), Color3.fromRGB(120, 120, 125), Enum.Material.Slate)
			rock.CanCollide = true
		end
	end
end

local function buildMap(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Wild"

	local entrance = ORIGIN + vec(Wild.ENTRANCE_OFFSET)
	block(folder, "Entrance", Vector3.new(30, 2, 24), CFrame.new(entrance - Vector3.new(0, 1, 0)), Color3.fromRGB(150, 140, 120), Enum.Material.Cobblestone)
	portal(folder, "Return to shop", entrance + Vector3.new(0, 0, -9), Vector3.new(0, 0, 1), "Return", function(player)
		WildService.TravelHome(player)
	end)
	sign(folder, if Place.isFrontier() then "The Frontier" else "The Wild", CFrame.new(entrance + Vector3.new(10, 4, -9)) * CFrame.Angles(0, math.pi, 0))

	for index, zone in Wild.ZONES do
		local center = zoneCenter(index)
		local floor = block(folder, zone.name, Vector3.new(Wild.ZONE_SIZE, 2, Wild.ZONE_SIZE), CFrame.new(center - Vector3.new(0, 1, 0)), rgb(zone.color), Enum.Material.Grass)
		floor:SetAttribute("Zone", index)
		if index > 1 then
			-- Path from the previous zone
			local back = center - Vector3.new(0, 1, Wild.ZONE_SIZE / 2 + Wild.ZONE_GAP / 2)
			block(folder, "Path", Vector3.new(14, 2, Wild.ZONE_GAP + 2), CFrame.new(back), Color3.fromRGB(150, 140, 120), Enum.Material.Cobblestone)
		end
		local edge = center - Vector3.new(0, 0, Wild.ZONE_SIZE / 2 - 4)
		-- Faces the way players arrive (from -Z)
		sign(folder, `{zone.name}\nRecommended Lv {zone.recommended}+`, CFrame.new(edge + Vector3.new(12, 4, 0)) * CFrame.Angles(0, math.pi, 0))
		decorate(folder, center, index * 97)
		for spot = 1, Wild.MONSTERS_PER_ZONE do
			local angle = (spot / Wild.MONSTERS_PER_ZONE) * math.pi * 2
			local radius = Wild.ZONE_SIZE * (if spot % 2 == 0 then 0.32 else 0.18)
			local point = block(folder, "WildSpawn", Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(math.cos(angle) * radius, 0.5, math.sin(angle) * radius)), Color3.new(1, 1, 1))
			point.Transparency = 1
			point.CanCollide = false
			point.CanQuery = false
			point.CanTouch = false
			point:SetAttribute("Zone", index)
			CollectionService:AddTag(point, SPAWN_TAG)
		end
	end
	return folder
end

-- Main game: the wild portal at the end of the street. Frontier: a spawn on the entrance and the Dungeon portal.
local function buildPlaza()
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"
	if Place.isFrontier() then
		local entrance = ORIGIN + vec(Wild.ENTRANCE_OFFSET)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "FrontierSpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = CFrame.lookAt(entrance + Vector3.new(0, 0.5, 4), entrance + Vector3.new(0, 0.5, 20))
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Duration = 0
		spawn.Parent = folder
		frontierSpawn = spawn
		local dungeonSpot = vec((Wild :: any).DUNGEON_PORTAL)
		portal(folder, "Dungeon", dungeonSpot, Vector3.new(1, 0, 0), "Enter", function(player)
			notify(player, "Dungeons are coming soon!", false)
		end)
		sign(folder, "Dungeons · coming soon", CFrame.new(dungeonSpot + Vector3.new(0, Wild.PORTAL_SIGN_HEIGHT, 0)) * CFrame.Angles(0, math.rad(90), 0))
	else
		local portalSpot = vec(Wild.PLAZA_PORTAL)
		-- Its floating name label comes from TownService, like the other plaza portals
		portal(folder, "The Wild", portalSpot, Vector3.new(-1, 0, 0), "Travel", function(player)
			WildService.TravelToWild(player)
		end)
	end

	local springSpot = vec(Wild.SPRING)
	local pool = block(folder, "HealingSpring", Vector3.new(0.6, 10, 10), CFrame.new(springSpot + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), SPRING_COLOR, Enum.Material.Neon)
	pool.Shape = Enum.PartType.Cylinder
	pool.CanCollide = false
	pool.Transparency = 0.3
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 6
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.EmissionDirection = Enum.NormalId.Right -- the cylinder lies on its side: its X axis points up
	sparkle.Color = ColorSequence.new(SPRING_COLOR)
	sparkle.LightEmission = 1
	sparkle.Parent = pool
	local light = Instance.new("PointLight")
	light.Color = SPRING_COLOR
	light.Range = 14
	light.Brightness = 1
	light.Parent = pool
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(200, 40)
	board.StudsOffset = Vector3.new(0, 5, 0)
	board.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "💧 Healing Spring"
	label.Parent = board
	board.Parent = pool
	folder.Parent = workspace
end

-- Monsters -----------------------------------------------------------------------------------------------

local function setMarker(monster: Monster)
	local marker = monster.marker
	marker:SetAttribute("MonsterId", monster.id)
	marker:SetAttribute("Species", monster.species)
	marker:SetAttribute("Level", monster.level)
	marker:SetAttribute("Elite", monster.elite)
	marker:SetAttribute("Element", monster.element)
	marker:SetAttribute("Zone", monster.zone)
	marker:SetAttribute("Fighting", monster.fightingPlayer ~= nil)
end

local function groundAt(position: Vector3): Vector3
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), rayParams)
	return if hit then hit.Position else position
end

local function createMonster(species: string, level: number, elite: boolean, zone: number, home: Vector3, spawnPoint: BasePart?): Monster?
	local info = Wild.SPECIES[species]
	if not info then
		return nil
	end
	local marker = Instance.new("Part")
	marker.Size = Vector3.new(1, 1, 1)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	local ground = groundAt(home)
	marker.CFrame = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local monster: Monster = {
		id = HttpService:GenerateGUID(false),
		species = species,
		level = level,
		elite = elite,
		element = info.element,
		zone = zone,
		home = ground,
		marker = marker,
		fightingPlayer = nil,
		alive = true,
		spawnPoint = spawnPoint,
		wanderTarget = nil,
		waitUntil = 0,
		chaseCooldownUntil = 0,
	}
	marker.Name = `Monster_{monster.id}`
	setMarker(monster)
	marker.Parent = monstersFolder
	monsters[monster.id] = monster
	return monster
end

local function spawnAt(point: BasePart)
	local zoneIndex = point:GetAttribute("Zone")
	local zone = if typeof(zoneIndex) == "number" then Wild.ZONES[zoneIndex] else nil
	if not zone then
		return
	end
	local species = zone.species[rng:NextInteger(1, #zone.species)]
	local level = rng:NextInteger(zone.minLevel, zone.maxLevel)
	createMonster(species, level, rng:NextNumber() < Wild.ELITE_CHANCE, zoneIndex :: number, point.Position, point)
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- Moves a monster marker toward a point on the ground, facing the way it goes. True when it got there.
local function moveToward(monster: Monster, target: Vector3, speed: number, dt: number): boolean
	local position = monster.marker.Position
	local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
	local distance = flat.Magnitude
	if distance < 0.5 then
		return true
	end
	local stepLength = math.min(distance, speed * dt)
	local nextPosition = groundAt(position + flat.Unit * stepLength)
	monster.marker.CFrame = CFrame.lookAt(nextPosition, nextPosition + flat.Unit)
	return stepLength >= distance
end

local busy: { [Player]: boolean } = {} -- players in a fight right now (rebuilt every monster tick)

-- Nearest player in the wild; with skipBusy, ignoring players already in a fight (nobody chases into a ring)
local function nearestPlayer(position: Vector3, skipBusy: boolean?): (Player?, number)
	local best, bestDistance = nil, math.huge
	for player in inWild do
		local root = getRoot(player)
		if root and not (skipBusy and busy[player]) then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best, bestDistance
end

local function updateMonster(monster: Monster, dt: number, now: number)
	if not monster.alive or monster.fightingPlayer then
		return
	end
	local player, distance = nearestPlayer(monster.marker.Position)
	if not player or distance > Wild.WAKE_RADIUS then
		return -- asleep: nobody near
	end
	local zone = Wild.ZONES[monster.zone]
	local aggressive = monster.elite or (zone ~= nil and zone.aggro)
	local fromHome = (monster.marker.Position - monster.home).Magnitude
	local prey, preyDistance = nearestPlayer(monster.marker.Position, true)
	if aggressive and prey and now >= monster.chaseCooldownUntil and preyDistance <= Wild.AGGRO_RADIUS and fromHome <= Wild.CHASE_GIVE_UP then
		player, distance = prey, preyDistance
		local root = getRoot(player) :: BasePart
		if distance <= Wild.CONTACT_DISTANCE then
			monster.chaseCooldownUntil = now + Wild.CHASE_REST_SECONDS
			monster.wanderTarget = monster.home
			for _, callback in contactCallbacks do
				task.spawn(callback, player, monster)
			end
		else
			moveToward(monster, root.Position, Wild.CHASE_SPEED, dt)
		end
		return
	end
	if fromHome > Wild.CHASE_GIVE_UP then
		monster.chaseCooldownUntil = now + Wild.CHASE_REST_SECONDS
		monster.wanderTarget = monster.home -- too far from home: walk back
	end
	if now < monster.waitUntil then
		return
	end
	if not monster.wanderTarget then
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(2, Wild.WANDER_RADIUS)
		monster.wanderTarget = monster.home + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	end
	if moveToward(monster, monster.wanderTarget :: Vector3, Wild.WANDER_SPEED, dt) then
		monster.wanderTarget = nil
		monster.waitUntil = now + rng:NextNumber(1, 4)
	end
end

-- API ----------------------------------------------------------------------------------------------------

function WildService.GetMonster(id: string): Monster?
	local monster = monsters[id]
	return if monster and monster.alive then monster else nil
end

function WildService.Lock(monster: Monster, player: Player)
	monster.fightingPlayer = player
	setMarker(monster)
end

-- Fight over without a win: it heals (stats come fresh each fight) and walks home
function WildService.Unlock(monster: Monster)
	monster.fightingPlayer = nil
	monster.wanderTarget = monster.home
	monster.chaseCooldownUntil = os.clock() + Wild.CHASE_REST_SECONDS
	setMarker(monster)
end

function WildService.Defeat(monster: Monster)
	if not monster.alive then
		return
	end
	monster.alive = false
	monster.fightingPlayer = nil
	monsters[monster.id] = nil
	monster.marker:Destroy()
	local point = monster.spawnPoint
	if point then
		task.delay(rng:NextNumber(Wild.RESPAWN_MIN, Wild.RESPAWN_MAX), spawnAt, point)
	end
end

-- Holds a monster at its spot in a fight ring (nil: free again)
function WildService.SetFightPose(monster: Monster, cframe: CFrame?)
	if cframe and monster.alive then
		monster.marker.CFrame = cframe
	end
end

function WildService.OnContact(callback: (player: Player, monster: Monster) -> ())
	table.insert(contactCallbacks, callback)
end

-- BattleService and ArenaService refuse travel mid-fight (they can't be required from here: they require this)
function WildService.AddTravelBlocker(blocker: (player: Player) -> string?)
	table.insert(travelBlockers, blocker)
end

-- A glowing ring with a prompt (FrontierService uses it for the Frontier portal)
function WildService.BuildPortal(parent: Instance, name: string, position: Vector3, facing: Vector3, actionText: string, onTriggered: (Player) -> ())
	portal(parent, name, position, facing, actionText, onTriggered)
end

function WildService.IsInWild(player: Player): boolean
	return inWild[player] == true
end

function WildService.GetSpringPosition(): Vector3
	return vec(Wild.SPRING)
end

-- Dev command (/elite): a monster at a spot, never respawned
function WildService.SpawnAt(position: Vector3, species: string, level: number, elite: boolean): Monster?
	local zone = 1
	for index in Wild.ZONES do
		if (position - zoneCenter(index)).Magnitude < (position - zoneCenter(zone)).Magnitude then
			zone = index
		end
	end
	return createMonster(species, level, elite, zone, position, nil)
end

local function canTravel(player: Player): boolean
	if not allowTravel(player) then
		return false
	end
	for _, blocker in travelBlockers do
		local reason = blocker(player)
		if reason then
			notify(player, reason, true)
			return false
		end
	end
	return true
end

-- StreamingEnabled: the client only has parts near it. Load the arrival area on their device first, or the
-- character lands before the floor exists there and falls through the world.
local function moveCharacter(player: Player, cframe: CFrame): boolean
	if not player.Character or not getRoot(player) then
		return false
	end
	local ok, err = pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, Wild.STREAM_TIMEOUT)
	end)
	if not ok then
		warn(`[WildService] streaming around the destination failed: {err}`)
	end
	local character = player.Character
	if not character or not getRoot(player) then
		return false -- left or died while it loaded
	end
	character:PivotTo(cframe + Vector3.new(0, ARRIVAL_LIFT, 0))
	return true
end

-- Safety net: anyone in the wild who falls well below its floor goes back to the entrance
local function rescueFallen()
	local entrance = ORIGIN + vec(Wild.ENTRANCE_OFFSET)
	for player in inWild do
		local root = getRoot(player)
		if root and root.Position.Y < ORIGIN.Y - Wild.FALL_RESCUE_DEPTH and not root.Anchored then
			root.AssemblyLinearVelocity = Vector3.zero
			local character = player.Character :: Model
			character:PivotTo(CFrame.lookAt(entrance, entrance + Vector3.new(0, 0, 1)) + Vector3.new(0, ARRIVAL_LIFT, 0))
		end
	end
end

-- Moves a player somewhere outside the wild (the arena, their shop), streaming the spot in first.
-- Not blocked by fights: the caller decides. False if they have no character.
function WildService.MoveTo(player: Player, cframe: CFrame): boolean
	if not moveCharacter(player, cframe) then
		return false
	end
	if inWild[player] then
		inWild[player] = nil
		Remotes.WildTravel:FireClient(player, "home")
	end
	return true
end

function WildService.TravelToWild(player: Player)
	if not canTravel(player) then
		return
	end
	local entrance = ORIGIN + vec(Wild.ENTRANCE_OFFSET)
	if moveCharacter(player, CFrame.lookAt(entrance, entrance + Vector3.new(0, 0, 1))) then
		inWild[player] = true
		Remotes.WildTravel:FireClient(player, "wild")
	end
end

-- Frontier only: what "home" means there (FrontierService teleports back to the main game)
function WildService.SetHomeHandler(handler: (player: Player) -> ())
	homeHandler = handler
end

function WildService.TravelHome(player: Player)
	if not canTravel(player) then
		return
	end
	if Place.isFrontier() then
		if homeHandler then
			homeHandler(player)
		end
		return
	end
	local plot = PlotService.GetPlot(player)
	local target = if plot then plot.spawn.CFrame else CFrame.new(vec(Wild.SPRING) + Vector3.new(8, 0, 0))
	if moveCharacter(player, target) then
		inWild[player] = nil
		Remotes.WildTravel:FireClient(player, "home")
	end
end

function WildService.Start()
	-- Free models can carry scripts: none may ever run. Clients also strip their own copies.
	local models = ReplicatedStorage:FindFirstChild("MonsterModels")
	if models then
		for _, descendant in models:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
	end

	monstersFolder = Instance.new("Folder")
	monstersFolder.Name = "Monsters"
	monstersFolder.Parent = workspace

	local map = buildMap()
	map.Parent = workspace
	rayParams.FilterDescendantsInstances = { map }
	buildPlaza()
	for _, point in CollectionService:GetTagged(SPAWN_TAG) do
		if point:IsA("BasePart") then
			spawnAt(point)
		end
	end

	Remotes.WildTravel.OnServerEvent:Connect(function(player, where)
		if where == "wild" then
			WildService.TravelToWild(player)
		elseif where == "home" then
			WildService.TravelHome(player)
		end
	end)
	local function watch(player: Player)
		if Place.isFrontier() then
			-- The whole Frontier is wild: monsters wake for everyone here
			inWild[player] = true
			player.RespawnLocation = frontierSpawn
			player.CharacterAdded:Connect(function()
				inWild[player] = true
			end)
			return
		end
		-- Respawning puts you back at your shop
		player.CharacterAdded:Connect(function()
			if inWild[player] then
				inWild[player] = nil
				Remotes.WildTravel:FireClient(player, "home")
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		inWild[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / Wild.MARKER_RATE then
			return
		end
		local step = elapsed
		elapsed = 0
		local now = os.clock()
		rescueFallen()
		table.clear(busy)
		for _, monster in monsters do
			if monster.fightingPlayer then
				busy[monster.fightingPlayer] = true
			end
		end
		for _, monster in monsters do
			updateMonster(monster, step, now)
		end
	end)
end

return WildService
