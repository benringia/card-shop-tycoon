--!strict
-- Shop jobs: levelled cards working in the owner's shop as Restocker or Cashier. Each working card is a
-- placeholder creature (an R15 rig in its element colour, sized by rarity) running its job as one thread.
-- SPD sets work speed, Power sets how often it makes a (time-only) mistake (Util/JobRules).
-- Workers share the owner's boxes (StockService) and checkouts (RegisterService) through their worker
-- APIs, so cash, XP, stats and saves are exactly as if the owner did the work.
-- Slots: 1 at shop level 10, +1 with the Extra Job Slot pass (MonetizationService). Saved as data.jobs.
-- Workers earn XP each minute and only run while the owner is online.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CustomerConfig = require(Config:WaitForChild("Customers"))
local Jobs = require(Config:WaitForChild("Jobs"))
local Party = require(Config:WaitForChild("Party"))
local Town = require(Config:WaitForChild("Town"))
local Monetization = require(Config:WaitForChild("Monetization"))
local PlotConfig = require(Config:WaitForChild("Plots"))
local Products = require(Config:WaitForChild("Products"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local JobRules = require(Shared:WaitForChild("Util"):WaitForChild("JobRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local RegisterService = require(Services:WaitForChild("RegisterService"))
local StockService = require(Services:WaitForChild("StockService"))
local NpcMotion = require(Util:WaitForChild("NpcMotion"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData
type Plot = typeof(PlotService.GetPlots()[1])
type PlacedShelf = typeof(PlacementService.GetShelves((nil :: any))[1])

type Worker = {
	slot: number,
	beastId: string,
	job: string,
	model: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	label: TextLabel?,
	carrying: Part?,
	alive: boolean,
	status: string,
}

type PlayerJobs = {
	plot: Plot,
	slots: { [number]: Worker },
	dirty: boolean,
}

local PASS_KEY = "ExtraJobSlot"
local MINUTE = 60
local CARRY_OFFSET = CFrame.new(0, 0.5, -1.4) -- box in front of the worker's chest
-- Workers start inside the shop and never need to jump; without jumping, paths go around the counter
-- instead of over it (a failed jump there used to leave them stuck)
local WORKER_AGENT = table.clone(CustomerConfig.PATH_AGENT)
WORKER_AGENT.AgentCanJump = false

local JobService = {}

local states: { [Player]: PlayerJobs } = {}
local allowAction = RateLimiter.new(Jobs.ACTION_COOLDOWN)
local rng = Random.new()
local workersFolder: Folder

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

local function isJob(job: unknown): boolean
	return typeof(job) == "string" and table.find(Jobs.JOBS, job) ~= nil
end

local function getSlotCount(player: Player, hasPass: boolean?): number
	local owns = if hasPass ~= nil then hasPass else MonetizationService.HasPass(player, PASS_KEY)
	return JobRules.getSlotCount(Jobs, EconomyService.GetLevel(player), owns)
end

-- Card, stats and job numbers for a worker's card right now (they change as it levels)
local function getProfile(player: Player, worker: Worker)
	local beast = CardService.GetBeast(player, worker.beastId)
	if not beast then
		return nil
	end
	local card = Cards.ById[beast.cardId]
	local stats = BeastRules.getStats(card, beast.foil, beast.level, beast.stars, beast.grade)
	return {
		beast = beast,
		card = card,
		spd = stats.spd,
		mistake = JobRules.getMistakeChance(Jobs, BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade)),
	}
end

-- Positions ------------------------------------------------------------------------------------------

local function floorPoint(plot: Plot, cframe: CFrame): Vector3
	return Vector3.new(cframe.X, plot.floor.Position.Y + PlotConfig.FLOOR_THICKNESS / 2, cframe.Z)
end

-- Just inside the shop front
local function getEntryCFrame(plot: Plot): CFrame
	return plot.floor.CFrame * CFrame.new(0, 0, -PlotConfig.DEPTH / 2 + 3)
end

-- Beside the delivery spot on the doorway side (it stands outside, its street side is the road)
local function getPadPoint(plot: Plot): Vector3
	local pad = plot.deliverySpot
	local towardDoor = if plot.floor.CFrame:PointToObjectSpace(pad.Position).X < 0 then 1 else -1
	return floorPoint(plot, pad.CFrame * CFrame.new(towardDoor * (pad.Size.X / 2 + 1.5), 0, 0))
end

local function getShelfPoint(plot: Plot, shelf: PlacedShelf): Vector3
	local part = shelf.part
	return floorPoint(plot, part.CFrame * CFrame.new(0, 0, -(part.Size.Z / 2 + CustomerConfig.SHELF_STAND_DISTANCE)))
end

-- Behind the counter (the staff side, where the owner stands to scan), inside the stall
local function getRegisterPoint(plot: Plot): Vector3
	local register = plot.register
	return floorPoint(plot, register.CFrame * CFrame.new(0, 0, register.Size.Z / 2 + Town.COUNTER.STAFF_BEHIND))
end

-- Turns a worker standing behind the register toward the customer queue (the register's front)
local function faceCustomers(worker: Worker, plot: Plot)
	local root = worker.root
	if not root or not worker.alive then
		return
	end
	local look = plot.register.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
	end
end

-- Out of the owner's way when they take over the register
local function getAsidePoint(plot: Plot): Vector3
	local register = plot.register
	return floorPoint(plot, register.CFrame * CFrame.new(register.Size.X / 2 + 3, 0, register.Size.Z / 2 + Town.COUNTER.STAFF_BEHIND))
end

-- Status and the creature ---------------------------------------------------------------------------

local function sendJobs(player: Player)
	local state = states[player]
	if not state then
		return
	end
	-- A list, not a slot-keyed table: remotes mangle tables with gaps in their number keys
	local slots = {}
	for slot, worker in state.slots do
		table.insert(slots, { slot = slot, beastId = worker.beastId, job = worker.job, status = worker.status })
	end
	local used = #slots
	local hasPass = MonetizationService.HasPass(player, PASS_KEY) -- one check per update
	local slotCount = getSlotCount(player, hasPass)
	-- Mirrored as attributes so the binder can show "Assign to job" without asking the Jobs panel
	player:SetAttribute("JobSlots", slotCount)
	player:SetAttribute("JobsUsed", used)
	Remotes.JobsChanged:FireClient(player, {
		slotCount = slotCount,
		maxSlots = Jobs.FREE_SLOTS + Jobs.PASS_SLOTS,
		unlockLevel = Jobs.UNLOCK_LEVEL,
		hasPass = hasPass,
		passId = Monetization.PASSES[PASS_KEY],
		slots = slots,
	})
	state.dirty = false
end

local function setStatus(player: Player, worker: Worker, status: string)
	if worker.status == status then
		return
	end
	worker.status = status
	local state = states[player]
	if state then
		state.dirty = true -- sent by the status loop, at most once per STATUS_SEND_SECONDS
	end
end

local function updateLabel(player: Player, worker: Worker)
	local label = worker.label
	local profile = getProfile(player, worker)
	if label and profile then
		local beast = profile.beast
		label.Text = `{profile.card.name}\n{BeastRules.describeGrade(beast.grade)} · Lv {beast.level}\n{worker.job}`
	end
end

local function spawnCreature(player: Player, state: PlayerJobs, worker: Worker)
	local profile = getProfile(player, worker)
	if not profile then
		return
	end
	local color = Cards.ELEMENTS[profile.card.element] or Color3.new(0.6, 0.6, 0.6)
	local scale = Jobs.RARITY_SCALE[profile.card.rarity] or 1
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = color
	description.TorsoColor = color
	description.LeftArmColor = color
	description.RightArmColor = color
	description.LeftLegColor = color
	description.RightLegColor = color
	description.HeightScale = scale
	description.WidthScale = scale
	description.DepthScale = scale
	description.HeadScale = scale

	local model = NpcMotion.createRig(description, `Worker_{worker.job}`, getEntryCFrame(state.plot))
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.WalkSpeed = Jobs.WALK_SPEED * JobRules.getSpeedFactor(Jobs, profile.spd)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	local head = model:FindFirstChild("Head")
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 54)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 70
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = head or root

	-- Cards with a creature model (Party.CREATURE_MODELS) are drawn by each client on this rig, which then only
	-- walks (WorkerVisualController): hide it and lift the name over the creature
	local creature = Party.CREATURE_MODELS[profile.card.name]
	local models = ReplicatedStorage:FindFirstChild("CreatureModels")
	local pack = if creature and models then models:FindFirstChild(creature.pack) else nil
	if pack and pack:FindFirstChild(creature.model) then
		model:SetAttribute("CardId", profile.card.id)
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Transparency = 1
			elseif descendant:IsA("Decal") then
				descendant.Transparency = 1
			end
		end
		local size = Party.CREATURE_HEIGHT * (Party.SIZE_BY_RARITY[profile.card.rarity] or 1) * (creature.size or 1)
		local height = math.max(size, Jobs.CREATURE_MIN_HEIGHT)
		local feet = humanoid.HipHeight + root.Size.Y / 2
		gui.Parent = root
		gui.StudsOffset = Vector3.new(0, height - feet + 1.6, 0)
	end

	model.Parent = workersFolder
	root:SetNetworkOwner(nil) -- server-owned physics, like customers
	NpcMotion.setupAnimations(humanoid, CustomerConfig.WALK_ANIMATION, CustomerConfig.IDLE_ANIMATION)

	worker.model, worker.humanoid, worker.root, worker.label = model, humanoid, root, label
	updateLabel(player, worker)
end

-- Never stuck: a blocked walk re-paths once from where the worker stands, then it hops to the target
local function walk(worker: Worker, target: Vector3): boolean
	local humanoid, root = worker.humanoid, worker.root
	if not humanoid or not root or not worker.alive then
		return false
	end
	local function isAlive(): boolean
		return worker.alive
	end
	for _ = 1, 2 do
		if NpcMotion.walkTo(humanoid, root, target, WORKER_AGENT, isAlive, Jobs.STUCK_GRACE_SECONDS) then
			return true
		end
		if not worker.alive then
			return false
		end
	end
	root.CFrame = CFrame.new(target + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)) * root.CFrame.Rotation
	return true
end

local function waitWork(player: Player, worker: Worker, baseSeconds: number): boolean
	local profile = getProfile(player, worker)
	task.wait(JobRules.getDuration(Jobs, baseSeconds, if profile then profile.spd else Jobs.REFERENCE_SPD))
	return worker.alive
end

local function rollMistake(player: Player, worker: Worker): boolean
	local profile = getProfile(player, worker)
	return profile ~= nil and rng:NextNumber() < profile.mistake
end

-- Restocker -------------------------------------------------------------------------------------------

local function accepts(shelf: PlacedShelf, productId: string): boolean
	local allowed = shelf.def.accepts
	return shelf.def.kind == "Products" and (allowed == nil or table.find(allowed, productId) ~= nil)
end

-- A product shelf that can take this product: one already holding it with space first, else an empty one
local function findShelfFor(player: Player, productId: string): PlacedShelf?
	local empty: PlacedShelf? = nil
	for _, shelf in PlacementService.GetShelves(player) do
		if accepts(shelf, productId) and shelf.units < shelf.def.capacity then
			if shelf.units > 0 and shelf.productId == productId then
				return shelf
			elseif shelf.units == 0 and not empty then
				empty = shelf
			end
		end
	end
	return empty
end

local function carry(worker: Worker, box: Part)
	local root = worker.root
	if not root then
		return
	end
	box.CFrame = root.CFrame * CARRY_OFFSET
	box.Anchored = false
	box.CanCollide = false
	box.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = box
	weld.Part1 = root
	weld.Parent = box
	-- Unanchored parts near a player can be handed to their client; keep the box server-owned
	pcall(function()
		box:SetNetworkOwner(nil)
	end)
	worker.carrying = box
end

local function putBack(player: Player, worker: Worker)
	local box = worker.carrying
	worker.carrying = nil
	if box and box.Parent then
		StockService.ReturnBox(player, box)
	end
end

local function runRestocker(player: Player, state: PlayerJobs, worker: Worker)
	while worker.alive do
		-- Pick a box some shelf can take
		local box: Part? = nil
		local waiting = StockService.GetWaitingBoxes(player)
		for _, candidate in waiting do
			local productId = candidate:GetAttribute("ProductId")
			if typeof(productId) == "string" and findShelfFor(player, productId) then
				box = candidate
				break
			end
		end
		if not box then
			setStatus(player, worker, if #waiting == 0 then "Idle: no boxes" else "Idle: shelves full")
			walk(worker, getPadPoint(state.plot))
			task.wait(Jobs.IDLE_RECHECK_SECONDS)
			continue
		end

		setStatus(player, worker, "Going to the delivery pad")
		if not walk(worker, getPadPoint(state.plot)) and not worker.alive then
			break
		end
		local chosen = box :: Part
		if not StockService.TakeWaitingBox(player, chosen) then
			continue -- the owner picked it up first
		end
		carry(worker, chosen)
		if worker.carrying ~= chosen then
			StockService.ReturnBox(player, chosen) -- no creature to hold it
			task.wait(Jobs.IDLE_RECHECK_SECONDS)
			continue
		end
		local productId = chosen:GetAttribute("ProductId") :: string
		local product = Products.ById[productId]

		-- Stock shelf after shelf until the box is empty or nothing takes the rest
		while worker.alive and worker.carrying == chosen and chosen.Parent do
			local shelf = findShelfFor(player, productId)
			if not shelf then
				break
			end
			setStatus(player, worker, `Carrying {if product then product.name else "a box"}`)
			walk(worker, getShelfPoint(state.plot, shelf))
			if not worker.alive then
				break
			end
			if rollMistake(player, worker) then
				setStatus(player, worker, "Dropped a box! Back to the pad")
				putBack(player, worker)
				task.wait(1)
				break
			end
			setStatus(player, worker, "Stocking")
			if not waitWork(player, worker, Jobs.STOCK_SECONDS) then
				break
			end
			local units = chosen:GetAttribute("Units")
			if typeof(units) ~= "number" then
				break
			end
			if PlacementService.GetShelf(player, shelf.uid) ~= shelf then
				continue -- the owner sold it on the way; pick another shelf (or put the box back)
			end
			local added = PlacementService.AddStock(shelf, productId, units)
			if added > 0 then
				StockService.ConsumeUnits(player, chosen, added)
			end
			if not chosen.Parent then
				worker.carrying = nil -- used up
			end
		end
		putBack(player, worker) -- leftovers back on the pad (no-op if used up or dropped)
	end
end

-- Cashier ---------------------------------------------------------------------------------------------

local function runCashier(player: Player, state: PlayerJobs, worker: Worker)
	local plot = state.plot
	while worker.alive do
		local checkout = RegisterService.GetCheckout(plot)
		if not checkout then
			setStatus(player, worker, "Idle: no customers")
			walk(worker, getRegisterPoint(plot))
			faceCustomers(worker, plot)
			task.wait(Jobs.IDLE_RECHECK_SECONDS)
			continue
		end
		if RegisterService.IsOwnerAtRegister(player, plot) then
			setStatus(player, worker, "Waiting: you're at the register")
			walk(worker, getAsidePoint(plot))
			task.wait(1)
			continue
		end

		walk(worker, getRegisterPoint(plot))
		faceCustomers(worker, plot)
		if checkout.remaining > 0 then
			setStatus(player, worker, `Scanning {checkout.scanned + 1}/{checkout.scanned + checkout.remaining}`)
			if not waitWork(player, worker, Jobs.SCAN_SECONDS) then
				break
			end
			if rollMistake(player, worker) then
				setStatus(player, worker, "Mis-scan, scanning again")
				if not waitWork(player, worker, Jobs.SCAN_SECONDS) then
					break
				end
			end
			-- The owner may have stepped in (or the customer left) while it was scanning
			if not RegisterService.IsOwnerAtRegister(player, plot) then
				RegisterService.ScanNext(plot)
			end
		elseif not RegisterService.IsOwnerAtRegister(player, plot) then
			RegisterService.ChargeByWorker(plot)
			setStatus(player, worker, "Sale!")
			task.wait(1)
		end
	end
end

-- Slots -------------------------------------------------------------------------------------------------

local function stopWorker(player: Player, worker: Worker)
	worker.alive = false
	putBack(player, worker)
	if worker.model then
		worker.model:Destroy()
	end
	worker.model, worker.humanoid, worker.root, worker.label = nil, nil, nil, nil
end

local function startWorker(player: Player, state: PlayerJobs, worker: Worker)
	worker.alive = true
	spawnCreature(player, state, worker)
	task.spawn(function()
		if worker.job == "Restocker" then
			runRestocker(player, state, worker)
		else
			runCashier(player, state, worker)
		end
	end)
end

local function freeSlot(player: Player, slot: number)
	local state = states[player]
	local worker = if state then state.slots[slot] else nil
	if not state or not worker then
		return
	end
	stopWorker(player, worker)
	state.slots[slot] = nil
	CardService.SetWorking(player, worker.beastId, nil)
	sendJobs(player)
end

-- Slots beyond what the player has now (pass removed) are freed
local function trimSlots(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local count = getSlotCount(player)
	for slot in table.clone(state.slots) do
		if slot > count then
			freeSlot(player, slot)
		end
	end
	sendJobs(player)
end

local function onAssign(player: Player, target: unknown, job: unknown)
	if not allowAction(player) or not isJob(job) then
		return
	end
	local state = states[player]
	if not state then
		return
	end
	local count = getSlotCount(player)
	if count == 0 then
		notify(player, `Jobs unlock at shop level {Jobs.UNLOCK_LEVEL}.`, true)
		return
	end
	local freeSlotNumber: number? = nil
	for slot = 1, count do
		if not state.slots[slot] then
			freeSlotNumber = slot
			break
		end
	end
	if not freeSlotNumber then
		notify(player, "All job slots are full. Unassign a card first.", true)
		return
	end

	local beastId: string? = nil
	if typeof(target) == "string" then
		if CardService.IsPartied(player, target) then
			notify(player, "That card is in your party. Remove it from the party first.", true)
			return
		end
		if CardService.GetBeast(player, target) and not CardService.IsWorking(player, target) then
			beastId = target
		end
	elseif typeof(target) == "table" then
		local entry = target :: { [string]: unknown }
		local cardId, foil, grade = entry.cardId, entry.foil, entry.grade
		if typeof(cardId) == "string" and typeof(foil) == "boolean" and BeastRules.isGrade(grade) then
			local beast = CardService.MakeIndividual(player, cardId, foil, grade :: string)
			beastId = if beast then beast.id else nil
		end
	end
	if not beastId then
		notify(player, "You can't assign that card.", true)
		return
	end

	local worker: Worker = { slot = freeSlotNumber, beastId = beastId, job = job :: string, alive = false, status = "Starting" }
	state.slots[freeSlotNumber] = worker
	CardService.SetWorking(player, beastId, job :: string)
	startWorker(player, state, worker)
	sendJobs(player)
	notify(player, `Assigned to {job}.`, false)
end

local function onUnassign(player: Player, slot: unknown)
	if not allowAction(player) or typeof(slot) ~= "number" then
		return
	end
	freeSlot(player, slot)
end

-- The worker in this slot takes the next job without leaving the slot. A fresh worker record, so the old job's
-- loop (which checks its own record's `alive`) stops for good.
local function onSwitch(player: Player, slot: unknown)
	if not allowAction(player) or typeof(slot) ~= "number" then
		return
	end
	local state = states[player]
	local worker = if state then state.slots[slot] else nil
	local job = if worker then JobRules.nextJob(Jobs.JOBS, worker.job) else nil
	if not state or not worker or not job then
		return
	end
	stopWorker(player, worker)
	local fresh: Worker = { slot = worker.slot, beastId = worker.beastId, job = job, alive = false, status = "Starting" }
	state.slots[worker.slot] = fresh
	CardService.SetWorking(player, fresh.beastId, job)
	startWorker(player, state, fresh)
	sendJobs(player)
	local profile = getProfile(player, fresh)
	notify(player, `{if profile then profile.card.name else "Your card"} is now a {job}.`, false)
end

-- Data --------------------------------------------------------------------------------------------------

local function load(player: Player, data: PlayerData)
	local plot = PlotService.GetPlot(player)
	if not plot then
		return
	end
	-- The pass check can yield; until it's done there is no state, so an autosave can't write empty jobs.
	-- If Roblox can't answer right now, keep the saved pass-slot job rather than drop a paying player's card.
	local count = if MonetizationService.IsCheckFailing(player, PASS_KEY)
		then JobRules.getSlotCount(Jobs, EconomyService.GetLevel(player), true)
		else getSlotCount(player)
	if player.Parent ~= Players then
		return
	end
	local state: PlayerJobs = { plot = plot, slots = {}, dirty = false }
	states[player] = state
	local seen: { [string]: boolean } = {}
	local saved = if typeof(data.jobs) == "table" then data.jobs else {}
	for _, entry in saved do
		if typeof(entry) ~= "table" then
			continue
		end
		local slot, beastId, job = entry.slot, entry.beastId, entry.job
		local valid = typeof(slot) == "number" and slot >= 1 and slot <= count and slot == math.floor(slot)
			and typeof(beastId) == "string" and not seen[beastId] and CardService.GetBeast(player, beastId) ~= nil
			and isJob(job) and not state.slots[slot]
		if valid then
			seen[beastId] = true
			state.slots[slot] = { slot = slot, beastId = beastId, job = job, alive = false, status = "Starting" }
			CardService.SetWorking(player, beastId, job)
		end
	end
	task.defer(function()
		if states[player] ~= state then
			return
		end
		for _, worker in state.slots do
			startWorker(player, state, worker)
		end
		sendJobs(player)
	end)
end

local function save(player: Player, data: PlayerData)
	local state = states[player]
	if not state then
		return
	end
	local jobs = {}
	for slot, worker in state.slots do
		table.insert(jobs, { slot = slot, beastId = worker.beastId, job = worker.job })
	end
	data.jobs = jobs
end

local function unload(player: Player)
	local state = states[player]
	if not state then
		return
	end
	for _, worker in state.slots do
		stopWorker(player, worker) -- a carried box goes back to StockService before it unloads
	end
	states[player] = nil
end

-- Once a minute: XP for every working card; a card that's gone frees its slot
local function xpLoop()
	while true do
		task.wait(MINUTE)
		for player, state in states do
			for slot, worker in table.clone(state.slots) do
				if not CardService.GetBeast(player, worker.beastId) then
					freeSlot(player, slot)
				else
					CardService.AddXP(player, worker.beastId, Jobs.XP_PER_MINUTE)
					updateLabel(player, worker)
				end
			end
			state.dirty = true
		end
	end
end

local function statusLoop()
	while true do
		task.wait(Jobs.STATUS_SEND_SECONDS)
		for player, state in states do
			if state.dirty then
				sendJobs(player)
			end
		end
	end
end

-- Frontier place: no shop jobs run there, but cards with a saved job stay locked, so they can't join a party
-- and come home in a different state. Read-only: it never saves, so the saved jobs come back untouched.
function JobService.StartLocksOnly()
	DataService.Register({
		name = "JobLocks",
		load = function(player: Player, data: PlayerData)
			for beastId, job in JobRules.getSavedLocks(Jobs, data.jobs) do
				if CardService.GetBeast(player, beastId) then
					CardService.SetWorking(player, beastId, job)
				end
			end
		end,
		save = function() end,
		unload = function() end,
	})
end

function JobService.Start()
	workersFolder = Instance.new("Folder")
	workersFolder.Name = "Workers"
	workersFolder.Parent = workspace
	NpcMotion.setupCollisionGroups()

	DataService.Register({ name = "JobService", load = load, save = save, unload = unload })
	Remotes.AssignJob.OnServerEvent:Connect(onAssign)
	Remotes.UnassignJob.OnServerEvent:Connect(onUnassign)
	Remotes.SwitchJob.OnServerEvent:Connect(onSwitch)
	Remotes.RequestJobs.OnServerEvent:Connect(function(player)
		if allowAction(player) then
			sendJobs(player)
		end
	end)
	MonetizationService.OnPassChanged(function(player)
		trimSlots(player)
	end)
	local function watchLevel(player: Player)
		player:GetAttributeChangedSignal("Level"):Connect(function()
			trimSlots(player)
		end)
	end
	Players.PlayerAdded:Connect(watchLevel)
	for _, player in Players:GetPlayers() do
		watchLevel(player)
	end
	task.spawn(xpLoop)
	task.spawn(statusLoop)
end

return JobService
