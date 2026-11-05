--!strict
-- Town walkers (spec 2026-11-06-customers-design, phase 2; Util/WalkerRules, Config/Customers WALKERS): a few customers
-- of every type stroll the plaza while players are in town, stop at the fountain and along the lanes, sit on a free
-- bench now and then, and after a while pick an open shop (its owner in the game) by its rating, a collector by the
-- card it wants on show. At the shop's door they become its customer (CustomerService.Adopt); a full shop sends them
-- strolling again. They add to each shop's street customers, never replace them; gone after WALKERS.lifetime.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CustomerConfig = require(Config:WaitForChild("Customers"))
local Plaza = require(Config:WaitForChild("Plaza"))
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
}

local TownWalkerService = {}

local rng = Random.new()
local walkers: { Walker } = {}
local stops: { Stop } = {}
local folder: Instance
local sitAnimation: Animation

local function spring(): Vector3
	return Vector3.new(Wild.SPRING.x, Wild.SPRING.y, Wild.SPRING.z)
end

local function ring(radius: number, degrees: number): Vector3
	local angle = math.rad(degrees)
	return spring() + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

-- The plaza's stops: its benches (TownLayout puts them round the spring), the fountain rim and spots along the lanes
local function buildStops()
	local look = CustomerConfig.WALKERS
	local centre = spring()
	for _, degrees in Town.LAYOUT.BENCH_ANGLES do
		local at = ring(Town.LAYOUT.BENCH_RADIUS, degrees)
		table.insert(stops, { kind = "bench", position = at, face = centre, taken = false })
	end
	for index = 1, look.fountainStops do
		local at = ring(look.fountainRadius, index * 360 / look.fountainStops + 20)
		table.insert(stops, { kind = "fountain", position = at, face = centre, taken = false })
	end
	for index = 1, look.laneStops do
		local degrees = index * 360 / look.laneStops
		local at = ring(look.laneRadius, degrees)
		table.insert(stops, { kind = "spot", position = at, face = ring(look.laneRadius + 10, degrees + 40), taken = false })
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

local function walkTo(walker: Walker, target: Vector3): boolean
	return NpcMotion.walkTo(walker.humanoid, walker.root, target, CustomerConfig.PATH_AGENT, function()
		return walker.alive
	end)
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

-- One stroll stop: the next free stop, walked to, then sat on or stood at a few seconds
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
		walkTo(walker, stop.position + toward * 1.5)
		if walker.alive then
			sit(walker, stop, seconds * 2)
		end
	else
		walkTo(walker, stop.position)
		if walker.alive then
			face(walker, stop.face)
			task.wait(seconds)
		end
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

local function run(walker: Walker)
	local look = CustomerConfig.WALKERS
	while walker.alive and os.clock() - walker.bornAt < look.lifetime do
		local lingerUntil = os.clock() + rng:NextNumber(look.linger[1], look.linger[2])
		while walker.alive and os.clock() < lingerUntil do
			stroll(walker)
		end
		local plot, owner = pickShop(walker)
		if plot and owner and walker.alive then
			walkTo(walker, CustomerService.EntryPoint(plot))
			if walker.alive and plot.owner == owner and CustomerService.Adopt(walker.model, plot, owner, walker.kind) then
				-- The shop's customer now: CustomerService owns the model from here
				walker.alive = false
				local index = table.find(walkers, walker)
				if index then
					table.remove(walkers, index)
				end
				return
			end
		end
	end
	despawn(walker)
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

local function spawnWalker()
	local look = CustomerConfig.WALKERS
	local kind = CustomerTypes.pick(CustomerConfig, { hasShowcase = true, shopLevel = highestShopLevel() }, rng:NextNumber())
	local edge = ring(look.edgeRadius, rng:NextNumber(0, 360))
	local model = CustomerService.BuildModel(CFrame.lookAt(edge + Vector3.new(0, 3, 0), spring() + Vector3.new(0, 3, 0)), kind)
	local wanted: string? = nil
	if kind == "collector" then
		local all: { CollectorRules.CardEntry } = {}
		for _, card in Cards.BySet["First Spark"] do
			table.insert(all, { id = card.id, rarity = card.rarity })
		end
		wanted = CollectorRules.wanted(CustomerConfig, {}, all, 1, rng:NextNumber())
		model:SetAttribute("WantedCard", wanted)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.WalkSpeed = CustomerConfig.WALK_SPEED
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local walker: Walker = { model = model, humanoid = humanoid, root = root, kind = kind, wanted = wanted, alive = true, bornAt = os.clock() }
	table.insert(walkers, walker)
	model.Parent = folder
	root:SetNetworkOwner(nil)
	NpcMotion.setupAnimations(humanoid, CustomerConfig.WALK_ANIMATION, CustomerConfig.IDLE_ANIMATION)
	task.spawn(run, walker)
end

function TownWalkerService.Start()
	folder = workspace:WaitForChild("Customers") -- with the shops' customers, so clients dress them the same way
	sitAnimation = Instance.new("Animation")
	sitAnimation.AnimationId = Plaza.SITTER.animation
	buildStops()
	task.spawn(function()
		while true do
			task.wait(CustomerConfig.WALKERS.spawnEvery)
			if #walkers < CustomerConfig.WALKERS.max and anyoneInTown() then
				spawnWalker()
			end
		end
	end)
end

return TownWalkerService
