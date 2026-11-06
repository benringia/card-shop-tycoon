--!strict
-- Town walkers (spec 2026-11-06-customers-design, phase 2; Util/WalkerRules, Config/Customers WALKERS): a few customers
-- of every type walk in from the street's ends while players are in town and stroll the whole street at an easy pace:
-- looking in the shop windows, standing about on the road and the plaza, sitting on a free bench now and then. After a
-- while they pick an open shop (its owner in the game) by its rating, a collector by the card it wants on show. At the
-- shop's door they become its customer (CustomerService.Adopt); a full shop sends them strolling again. They add to
-- each shop's street customers, never replace them; after WALKERS.lifetime they walk off at the nearest street end.
-- The street side of every shop's own customers too (CustomerService.UseStreet): each walks in from a random street
-- stop or end out of sight of the shop and the players, and walks off to the nearest street end when it's done.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CustomerConfig = require(Config:WaitForChild("Customers"))
local Plaza = require(Config:WaitForChild("Plaza"))
local PlotConfig = require(Config:WaitForChild("Plots"))
local Town = require(Config:WaitForChild("Town"))
local Wild = require(Config:WaitForChild("Wild"))
local CollectorRules = require(Shared:WaitForChild("Util"):WaitForChild("CollectorRules"))
local CustomerTypes = require(Shared:WaitForChild("Util"):WaitForChild("CustomerTypes"))
local WalkerRules = require(Shared:WaitForChild("Util"):WaitForChild("WalkerRules"))

local Services = script.Parent :: Instance
local NpcMotion = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("NpcMotion"))
local CustomerService = require(Services:WaitForChild("CustomerService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local RatingService = require(Services:WaitForChild("RatingService"))
local ShowcaseService = require(Services:WaitForChild("ShowcaseService"))

type Stop = { kind: string, position: Vector3, face: Vector3, taken: boolean }
type Walker = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	kind: string,
	wanted: string?,
	alive: boolean,
	bornAt: number,
	heading: { plot: any, owner: Player }?, -- a shop's customer on its way in (CustomerService arrivals)
	leaving: boolean, -- a shop's customer walking off down the street (departures)
	fails: number, -- walks failed in a row (WALKERS.unstickAfter, giveUpAfter)
	route: { Vector3 }?, -- the last route it walked, to retrace out of a tight spot
}

local TownWalkerService = {}

local rng = Random.new()
local walkers: { Walker } = {}
local stops: { Stop } = {}
local exits: { Vector3 } = {}
local folder: Instance
local sitAnimation: Animation

local function spring(): Vector3
	return Vector3.new(Wild.SPRING.x, Wild.SPRING.y, Wild.SPRING.z)
end

local function ground(x: number, z: number): Vector3
	return Vector3.new(x, Wild.SPRING.y, z)
end

-- The street's stops (WalkerRules.townStops) and its two ends
local function buildStops()
	local world: WalkerRules.World = {
		perRow = PlotConfig.PER_ROW,
		plotWidth = PlotConfig.WIDTH,
		plotDepth = PlotConfig.DEPTH,
		gap = PlotConfig.GAP,
		streetWidth = PlotConfig.STREET_WIDTH,
		spring = { x = Wild.SPRING.x, z = Wild.SPRING.z },
	}
	for _, stop in WalkerRules.townStops(CustomerConfig, Town, world) do
		table.insert(stops, { kind = stop.kind, position = ground(stop.x, stop.z), face = ground(stop.faceX, stop.faceZ), taken = false })
	end
	for _, exit in WalkerRules.exits(CustomerConfig, Town) do
		table.insert(exits, ground(exit.x, exit.z))
	end
end

local function anyoneInTown(): boolean
	local centre = spring()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - centre).Magnitude <= CustomerConfig.WALKERS.townRadius then
			return true
		end
	end
	return false
end

local function despawn(walker: Walker)
	if not walker.alive then
		return
	end
	walker.alive = false
	local index = table.find(walkers, walker)
	if index then
		table.remove(walkers, index)
	end
	walker.model:Destroy()
end

-- Along a path that never jumps and keeps off grass; false when there's none or the walker got stuck on the way. A
-- walker that keeps failing is in a spot no path starts from (between a bench and the gazebo, by a planted tree): it
-- retraces the route it came in on (open, it just walked it), and is removed if even that keeps failing
local function walkTo(walker: Walker, target: Vector3): boolean
	local look = CustomerConfig.WALKERS
	local function alive(): boolean
		return walker.alive
	end
	local ok, route = NpcMotion.walkTo(walker.humanoid, walker.root, target, look.agent, alive, look.stuckSeconds, false)
	if ok then
		walker.fails = 0
		walker.route = route
		return true
	end
	if not walker.alive then
		return false
	end
	walker.fails += 1
	if walker.fails >= look.giveUpAfter then
		despawn(walker)
	elseif walker.fails >= look.unstickAfter and walker.route then
		local back: { Vector3 } = {}
		for index = #walker.route, 1, -1 do
			table.insert(back, walker.route[index])
		end
		walker.route = nil
		NpcMotion.walkRoute(walker.humanoid, walker.root, back, alive, look.stuckSeconds)
	end
	return false
end

local function face(walker: Walker, point: Vector3)
	local root = walker.root
	local flat = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
	if flat.Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
	end
end

-- Sits on the bench at `stop` for `seconds`: the root held on the seat, Roblox's sit animation (as the plaza's cafe
-- townsfolk); the seat's top is found by a ray, so any bench model works
local function sit(walker: Walker, stop: Stop, seconds: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local toward = (stop.face - stop.position).Unit
	local probe = stop.position + toward * 0.3
	local hit = workspace:Raycast(probe + Vector3.new(0, 8, 0), Vector3.new(0, -12, 0), params)
	if not hit or not walker.alive then
		task.wait(seconds)
		return
	end
	local root = walker.root
	root.Anchored = true
	root.CFrame = CFrame.lookAt(hit.Position + Vector3.new(0, Plaza.SITTER.rootHeight, 0), hit.Position + Vector3.new(toward.X, Plaza.SITTER.rootHeight, toward.Z))
	local animator = walker.humanoid:FindFirstChildOfClass("Animator")
	local track = if animator then animator:LoadAnimation(sitAnimation) else nil
	if track then
		track.Looped = true
		track:Play()
	end
	task.wait(seconds)
	if track then
		track:Stop()
	end
	if walker.alive then
		root.CFrame = CFrame.lookAt(stop.position + toward * 1.5 + Vector3.new(0, 3, 0), stop.face + Vector3.new(0, 3, 0))
		root.Anchored = false
	end
end

-- One stroll stop: the next free stop, walked to, then sat on or stood at a few seconds; a stop it can't reach is
-- skipped after a short pause
local function stroll(walker: Walker)
	local look = CustomerConfig.WALKERS
	local view: { WalkerRules.Stop } = {}
	for index, stop in stops do
		view[index] = { kind = stop.kind, free = not stop.taken }
	end
	local index = WalkerRules.nextStop(CustomerConfig, view, rng:NextNumber())
	if not index then
		task.wait(2)
		return
	end
	local stop = stops[index]
	stop.taken = true
	local seconds = rng:NextNumber(look.stopSeconds[1], look.stopSeconds[2])
	if stop.kind == "bench" then
		local toward = (stop.face - stop.position).Unit
		if walkTo(walker, stop.position + toward * 1.5) and walker.alive then
			sit(walker, stop, seconds * 2)
		elseif walker.alive then
			task.wait(1)
		end
	elseif walkTo(walker, stop.position) and walker.alive then
		face(walker, stop.face)
		task.wait(seconds)
	elseif walker.alive then
		task.wait(1)
	end
	stop.taken = false
end

-- An open shop for this walker (WalkerRules.chooseShop), or nil
local function pickShop(walker: Walker): (any, Player?)
	local candidates: { WalkerRules.Shop } = {}
	local byId: { [number]: any } = {}
	for _, plot in PlotService.GetPlots() do
		local owner = plot.owner
		if owner then
			local wanted = walker.wanted
			local hasWanted = wanted ~= nil and (ShowcaseService.FindCardForCollector(owner, wanted)) ~= nil
			table.insert(candidates, { id = plot.id, rating = RatingService.Get(owner), open = true, hasWanted = hasWanted })
			byId[plot.id] = plot
		end
	end
	local id = WalkerRules.chooseShop(CustomerConfig, candidates, rng:NextNumber())
	local plot = if id then byId[id] else nil
	return plot, if plot then plot.owner else nil
end

-- Off at the nearest street end, then gone
local function leave(walker: Walker)
	if walker.alive then
		local at = walker.root.Position
		local points: { WalkerRules.Point } = {}
		for _, exit in exits do
			table.insert(points, { x = exit.X, z = exit.Z })
		end
		walkTo(walker, exits[WalkerRules.nearestExit(points, at.X, at.Z)])
	end
	despawn(walker)
end

-- The shop's customer now: CustomerService owns the model from here
local function handOver(walker: Walker)
	walker.alive = false
	local index = table.find(walkers, walker)
	if index then
		table.remove(walkers, index)
	end
end

-- A shop's customer on its way in: to the door (a few tries), where it becomes the shop's customer; a full or
-- closed shop, or no way there, and it strolls the town like any walker
local function arrive(walker: Walker)
	local heading = walker.heading :: { plot: any, owner: Player }
	for _ = 1, 3 do
		if not walker.alive or heading.plot.owner ~= heading.owner then
			break
		end
		if walkTo(walker, CustomerService.EntryPoint(heading.plot)) then
			if walker.alive and heading.plot.owner == heading.owner then
				if CustomerService.Adopt(walker.model, heading.plot, heading.owner, walker.kind, walker.wanted) then
					handOver(walker)
					return
				end
			end
			break
		end
	end
	walker.heading = nil
	walker.bornAt = os.clock()
end

local function run(walker: Walker)
	local look = CustomerConfig.WALKERS
	if walker.heading then
		arrive(walker)
		if not walker.alive then
			return
		end
	end
	while walker.alive and os.clock() - walker.bornAt < look.lifetime do
		local lingerUntil = os.clock() + rng:NextNumber(look.linger[1], look.linger[2])
		while walker.alive and os.clock() < lingerUntil do
			stroll(walker)
		end
		local plot, owner = pickShop(walker)
		if plot and owner and walker.alive and walkTo(walker, CustomerService.EntryPoint(plot)) then
			if walker.alive and plot.owner == owner and CustomerService.Adopt(walker.model, plot, owner, walker.kind, walker.wanted) then
				handOver(walker)
				return
			end
		end
	end
	leave(walker)
end

local function highestShopLevel(): number
	local best = 1
	for _, plot in PlotService.GetPlots() do
		local owner = plot.owner
		if owner then
			best = math.max(best, EconomyService.GetLevel(owner))
		end
	end
	return best
end

-- A new walker at `at` (looking at the plaza), set off on its way
local function startWalker(at: Vector3, kind: string, wanted: string?, heading: { plot: any, owner: Player }?)
	local model = CustomerService.BuildModel(CFrame.lookAt(at + Vector3.new(0, 3, 0), spring() + Vector3.new(0, 3, 0)), kind)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.WalkSpeed = CustomerConfig.WALKERS.walkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local walker: Walker = {
		model = model,
		humanoid = humanoid,
		root = root,
		kind = kind,
		wanted = wanted,
		alive = true,
		bornAt = os.clock(),
		heading = heading,
		leaving = false,
		fails = 0,
		route = nil,
	}
	table.insert(walkers, walker)
	model.Parent = folder
	root:SetNetworkOwner(nil)
	NpcMotion.setupAnimations(humanoid, CustomerConfig.WALK_ANIMATION, CustomerConfig.IDLE_ANIMATION)
	task.spawn(run, walker)
end

local function spawnWalker()
	local kind = CustomerTypes.pick(CustomerConfig, { hasShowcase = true, shopLevel = highestShopLevel() }, rng:NextNumber())
	local wanted: string? = nil
	if kind == "collector" then
		local all: { CollectorRules.CardEntry } = {}
		for _, card in Cards.BySet["First Spark"] do
			table.insert(all, { id = card.id, rarity = card.rarity })
		end
		-- Kept to itself until it's in a shop (CustomerService.Adopt shows the thought bubble): no cards over heads on the street
		wanted = CollectorRules.wanted(CustomerConfig, {}, all, 1, rng:NextNumber())
	end
	startWalker(exits[rng:NextInteger(1, #exits)], kind, wanted, nil)
end

-- Walkers strolling for themselves (not a shop's customer on its way in or out)
local function strolling(): number
	local count = 0
	for _, walker in walkers do
		if not walker.heading and not walker.leaving then
			count += 1
		end
	end
	return count
end

-- CustomerService's arrivals: a shop's customer walks in from a random street stop or end, away from the shop's door
-- and every player (WalkerRules.spawnPoint); false (it appears at the door) past crowdCap or with nowhere far enough
local function sendCustomer(plot: any, owner: Player, kind: string, wanted: string?): boolean
	local look = CustomerConfig.WALKERS
	if #walkers >= look.crowdCap then
		return false
	end
	local points: { WalkerRules.Point } = {}
	for _, stop in stops do
		if stop.kind ~= "bench" then
			table.insert(points, { x = stop.position.X, z = stop.position.Z })
		end
	end
	for _, exit in exits do
		table.insert(points, { x = exit.X, z = exit.Z })
	end
	local door = CustomerService.EntryPoint(plot)
	local avoid: { WalkerRules.Point } = { { x = door.X, z = door.Z } }
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			table.insert(avoid, { x = root.Position.X, z = root.Position.Z })
		end
	end
	local from = WalkerRules.spawnPoint(points, avoid, look.arriveAway, rng:NextNumber())
	if not from then
		return false
	end
	startWalker(ground(from.x, from.z), kind, wanted, { plot = plot, owner = owner })
	return true
end

-- CustomerService's departures: a customer done with a shop walks off to the nearest street end; false (it vanishes at
-- the door) past crowdCap
local function walkOff(model: Model): boolean
	local look = CustomerConfig.WALKERS
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if #walkers >= look.crowdCap or not humanoid or not root or not root:IsA("BasePart") then
		return false
	end
	humanoid.WalkSpeed = look.walkSpeed
	local walker: Walker = {
		model = model,
		humanoid = humanoid,
		root = root,
		kind = "plain",
		wanted = nil,
		alive = true,
		bornAt = os.clock(),
		heading = nil,
		leaving = true,
		fails = 0,
		route = nil,
	}
	table.insert(walkers, walker)
	task.spawn(leave, walker)
	return true
end

function TownWalkerService.Start()
	folder = workspace:WaitForChild("Customers") -- with the shops' customers, so clients dress them the same way
	sitAnimation = Instance.new("Animation")
	sitAnimation.AnimationId = Plaza.SITTER.animation
	buildStops()
	CustomerService.UseStreet(sendCustomer, walkOff)
	task.spawn(function()
		local look = CustomerConfig.WALKERS
		while true do
			task.wait(look.spawnEvery)
			if strolling() < look.max and #walkers < look.crowdCap and anyoneInTown() then
				spawnWalker()
			end
		end
	end)
end

return TownWalkerService
