--!strict
-- Deliveries on every screen (owner 2026-11-23, mockups A, 1 and 3: "go A with 1 and 3"; Config/Delivery,
-- Util/DeliveryRules; DESIGN.md 4.2 "The packenship.co van"):
--   The van: when anyone orders, a packenship.co van comes down the street on that shop's side, slows to a stop on the
--   lane by its pad and slides its door open; the boxes hop out one by one (the server makes each box as it leaves the
--   door, its VanHop attribute; here it flies from the door to its place on the pad and lands with a thud and a puff of
--   dust); the shop's door bell rings, the van beeps twice and drives off, fading out at the street's end. Only you see
--   your van (owner 2026-11-23: the server sends it to the orderer alone); where it is comes from the server's clock
--   (DeliveryRules.offset), so it stops as the server's boxes leave its door. Others just see the boxes on your pad.
--   The unboxing: a shelf stocked near you plays Util/UnboxFx.
--   The waiting chip: over your own pad while boxes wait on it ("3 boxes waiting"), only while you stand near it.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Delivery = require(Config:WaitForChild("Delivery"))
local Town = require(Config:WaitForChild("Town"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DeliveryRules = require(Shared:WaitForChild("Util"):WaitForChild("DeliveryRules"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local DeliveryVan = require(ClientUtil:WaitForChild("DeliveryVan"))
local UnboxFx = require(ClientUtil:WaitForChild("UnboxFx"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

type Van = {
	stop: CFrame, -- on the lane by the pad, facing where it drives
	bell: Vector3, -- the shop's door
	route: DeliveryRules.Route,
	arrive: number, -- the server's clock
	leave: number,
	built: DeliveryVan.Built?,
	shownAt: number, -- this client's clock when it first showed
	alpha: number, -- how solid it was drawn last
	turn: number, -- its wheels' angle
	lastOffset: number?,
	cues: { [string]: boolean }, -- the sounds already played
}

local player = Players.LocalPlayer
local TRIP = Delivery.TRIP
local VAN = Delivery.VAN
local SOUNDS = Delivery.SOUNDS
local CHIP = Delivery.CHIP
local POP_IN = 0.3 -- s a van that shows partway down the street takes to fade in
local INK = Color3.fromRGB(91, 61, 110)
-- the lane's middle from the pad's middle, toward the street (Town.DELIVERY: the pad's middle from the shop's front)
local LANE = DeliveryRules.laneOffset({
	padCentre = Town.WALL_THICKNESS + Town.DELIVERY.GAP + Town.DELIVERY.SIZE[3] / 2,
	sidewalk = Town.LAYOUT.SIDEWALK,
	curb = VAN.curb,
	vanWidth = VAN.width,
})

local DeliveryController = {}

local vans: { Van } = {}
local folder: Folder? = nil
local chip: BillboardGui
local chipPill: Frame
local chipText: TextLabel
local shownCount = 0

local function fxFolder(): Folder
	local current = folder
	if current and current.Parent then
		return current
	end
	local made = Instance.new("Folder")
	made.Name = "DeliveryFx"
	made.Parent = workspace
	folder = made
	return made
end

-- The street's height under `position` (the van's lane): a ray down past the town's people and the shops
local function groundAt(position: Vector3): number?
	local ignore: { Instance } = { fxFolder() }
	for _, name in { "Plots", "Customers" } do
		local found = workspace:FindFirstChild(name)
		if found then
			table.insert(ignore, found)
		end
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y else nil
end

-- Where a shop's van stops (on the lane past its pad, facing along the street so its right side, the door's, faces the
-- pad) and where its door bell rings (the shop's door: the pad stands beside it)
local function stopFor(plot: Instance): (CFrame?, Vector3?)
	local spot = plot:FindFirstChild("DeliverySpot", true)
	if not spot or not spot:IsA("BasePart") then
		return nil, nil
	end
	local lane = (spot.CFrame * CFrame.new(0, 0, -LANE)).Position
	local y = groundAt(lane) or spot.Position.Y - 1
	local at = Vector3.new(lane.X, y, lane.Z)
	local forward = spot.CFrame.XVector
	local look = Town.DELIVERY
	local bell = (spot.CFrame * CFrame.new(-look.X, 4, look.SIZE[3] / 2 + look.GAP + Town.WALL_THICKNESS / 2)).Position
	return CFrame.lookAt(at, at + forward), bell
end

-- A sound at a part (it follows the part) or at a spot
local function play(sound: { id: string, volume: number, pitch: number?, stopAfter: number? }, at: BasePart | Vector3)
	local holder: BasePart
	if typeof(at) == "Vector3" then
		local made = Instance.new("Part")
		made.Anchored = true
		made.CanCollide = false
		made.CanQuery = false
		made.CanTouch = false
		made.Transparency = 1
		made.Size = Vector3.new(0.2, 0.2, 0.2)
		made.Position = at
		made.Parent = fxFolder()
		Debris:AddItem(made, 8)
		holder = made
	else
		holder = at
	end
	local made = Instance.new("Sound")
	made.SoundId = sound.id
	made.Volume = sound.volume
	made.PlaybackSpeed = sound.pitch or 1
	made.RollOffMaxDistance = 150
	made.Parent = holder
	made:Play()
	Debris:AddItem(made, 8)
	local stopAfter = sound.stopAfter
	if stopAfter then
		task.delay(stopAfter, function()
			local fade = TweenService:Create(made, TweenInfo.new(0.4), { Volume = 0 })
			fade:Play()
		end)
	end
end

-- How far open the van's door is: it slides open as the van stops and shut a little before it leaves
local function doorShare(now: number, van: Van): number
	if now < van.arrive then
		return 0
	end
	local closing = van.leave - 0.8
	if now < closing then
		return math.clamp((now - van.arrive) / VAN.doorOpen, 0, 1)
	end
	return math.clamp(1 - (now - closing) / VAN.doorOpen, 0, 1)
end

-- The trip's sounds, each once: the whirr rolling in, the door, the shop's bell once the last box is down, two honks,
-- the whirr driving off
local function cues(now: number, van: Van, built: DeliveryVan.Built)
	local body = built.body
	local function once(name: string, from: number, run: () -> ())
		if not van.cues[name] and now >= from then
			van.cues[name] = true
			run()
		end
	end
	once("arrive", van.arrive - 1.6, function()
		play(SOUNDS.arrive, body)
	end)
	once("door", van.arrive, function()
		play(SOUNDS.door, body)
	end)
	once("bell", van.leave - TRIP.linger + 0.05, function()
		play(SOUNDS.bell, van.bell)
	end)
	once("horn1", van.leave - 0.6, function()
		play(SOUNDS.horn, body)
	end)
	once("horn2", van.leave - 0.35, function()
		play(SOUNDS.horn, body)
	end)
	once("leave", van.leave, function()
		play(SOUNDS.leave, body)
	end)
end

-- Every frame: each van where the clock says, faded at the street's ends, gone once it has left
local function step()
	local now = workspace:GetServerTimeNow()
	for index = #vans, 1, -1 do
		local van = vans[index]
		local offset = DeliveryRules.offset(now, van.arrive, van.leave, TRIP)
		local opacity = DeliveryRules.opacity(offset, van.route, Delivery.STREET.fade)
		if opacity <= 0 then
			if now > van.leave then
				if van.built then
					van.built.model:Destroy()
				end
				table.remove(vans, index)
			end
			continue
		end
		local built = van.built
		if not built then
			built = DeliveryVan.build(fxFolder())
			van.built = built
			van.shownAt = os.clock()
		end
		local alpha = math.min(opacity, (os.clock() - van.shownAt) / POP_IN)
		if math.abs(alpha - van.alpha) > 0.01 then
			van.alpha = alpha
			DeliveryVan.fade(built, alpha)
		end
		local last = van.lastOffset or offset
		van.turn += (offset - last) / (VAN.wheel / 2)
		van.lastOffset = offset
		DeliveryVan.place(built, van.stop * CFrame.new(0, 0, -offset), van.turn, doorShare(now, van))
		cues(now, van, built)
	end
end

local function onVan(plot: unknown, arrive: unknown, count: unknown)
	if typeof(plot) ~= "Instance" or typeof(arrive) ~= "number" or typeof(count) ~= "number" then
		return
	end
	local stop, bell = stopFor(plot)
	if not stop or not bell then
		return -- (that shop isn't streamed in here)
	end
	local direction = if stop.LookVector.X >= 0 then 1 else -1
	table.insert(vans, {
		stop = stop,
		bell = bell,
		route = DeliveryRules.route(stop.Position.X, direction, Town.LAYOUT.STREET_HALF_LENGTH, Delivery.STREET.endInset),
		arrive = arrive,
		leave = arrive + DeliveryRules.stay(math.max(count, 1), TRIP),
		built = nil,
		shownAt = os.clock(),
		alpha = -1,
		turn = 0,
		lastOffset = nil,
		cues = {},
	})
end

-- A puff of dust where a box lands, and its thud
local function land(at: Vector3)
	play(SOUNDS.thud, at)
	local puff = Delivery.HOP.puff
	for index = 1, 6 do
		local angle = index / 6 * math.pi * 2
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.CastShadow = false
		ball.Material = Enum.Material.SmoothPlastic
		ball.Color = Color3.fromRGB(238, 236, 232)
		ball.Transparency = 0.35
		ball.Size = Vector3.new(0.5, 0.5, 0.5)
		ball.Position = at + Vector3.new(math.cos(angle) * 0.7, 0.25, math.sin(angle) * 0.7)
		ball.Parent = fxFolder()
		TweenService:Create(ball, TweenInfo.new(puff, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = at + Vector3.new(math.cos(angle) * 1.9, 0.6, math.sin(angle) * 1.9),
			Size = Vector3.new(1.3, 1.3, 1.3),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ball, puff + 0.1)
	end
end

-- Whether `plot` is your own shop's (only your van comes to it on your screen)
local function isOwnPlot(plot: Instance?): boolean
	local plotId = player:GetAttribute("PlotId")
	return plot ~= nil and typeof(plotId) == "number" and plot.Name == "Plot" .. plotId
end

-- A box the van just dropped off at your shop: it flies from the van's door to its place on the pad (moved on this
-- screen only; the server already put it there). Another shop's boxes just appear: its van isn't on your screen
local function hopIn(box: Instance)
	if not box:IsA("BasePart") or box.Name ~= "StockBox" then
		return
	end
	local stamp = box:GetAttribute("VanHop")
	if typeof(stamp) ~= "number" or workspace:GetServerTimeNow() - stamp > Delivery.HOP.recent then
		return
	end
	local plot = box.Parent
	if not isOwnPlot(plot) then
		return
	end
	local stop = if plot then stopFor(plot) else nil
	if not stop then
		return
	end
	local from = DeliveryVan.doorPoint(stop)
	local target = box.CFrame
	local turns = Delivery.HOP.spins * math.pi * 2
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		-- picked up or gone mid-flight: the server has it now
		if not box.Parent or not box.Anchored then
			connection:Disconnect()
			return
		end
		local share = (os.clock() - start) / TRIP.hopTime
		if share >= 1 then
			connection:Disconnect()
			box.CFrame = target
			land(target.Position - Vector3.new(0, box.Size.Y / 2, 0))
			return
		end
		local point = DeliveryRules.hopPoint({ x = from.X, y = from.Y, z = from.Z }, { x = target.X, y = target.Y, z = target.Z }, share, Delivery.HOP.peak)
		box.CFrame = CFrame.new(point.x, point.y, point.z) * target.Rotation * CFrame.Angles(0, turns * share, 0)
	end)
end

local function watchPlots()
	local plots = workspace:WaitForChild("Plots")
	local function watch(plot: Instance)
		plot.ChildAdded:Connect(hopIn)
	end
	for _, plot in plots:GetChildren() do
		watch(plot)
	end
	plots.ChildAdded:Connect(watch)
end

local spotFound: BasePart? = nil

-- Your pad (kept between looks; found again when its plot changes or it streams out)
local function ownSpot(): BasePart?
	if spotFound and spotFound.Parent and isOwnPlot(spotFound.Parent) then
		return spotFound
	end
	local plotId = player:GetAttribute("PlotId")
	local plots = workspace:FindFirstChild("Plots")
	local plot = if typeof(plotId) == "number" and plots then plots:FindFirstChild("Plot" .. plotId) else nil
	local spot = if plot then plot:FindFirstChild("DeliverySpot", true) else nil
	spotFound = if spot and spot:IsA("BasePart") then spot else nil
	return spotFound
end

-- How far your character stands from your pad; nil with no character or pad
local function padDistance(spot: BasePart?): number?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not spot or not root or not root:IsA("BasePart") then
		return nil
	end
	return (root.Position - spot.Position).Magnitude
end

-- The chip over your pad while you stand near it (DeliveryRules.chipShows): how many boxes wait there, popping in as
-- you come near and when one more lands
local function refreshChip()
	local count = tonumber(player:GetAttribute("BoxesWaiting")) or 0
	local spot = ownSpot()
	local was = chip.Enabled
	chip.Adornee = spot
	chip.Enabled = DeliveryRules.chipShows(count, padDistance(spot), was, CHIP)
	chipText.Text = DeliveryRules.waitingWords(count)
	if chip.Enabled and (not was or count > shownCount) then
		local scale = chipPill:FindFirstChildOfClass("UIScale")
		if scale then
			scale.Scale = 1.25
			TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end
	shownCount = count
end

local function buildChip()
	chip = Instance.new("BillboardGui")
	chip.Name = "DeliveryWaiting"
	chip.Size = UDim2.fromOffset(260, CHIP.height + 8)
	chip.StudsOffsetWorldSpace = Vector3.new(0, CHIP.up, 0)
	chip.MaxDistance = CHIP.maxDistance
	chip.LightInfluence = 0
	chip.ResetOnSpawn = false
	chip.Enabled = false
	chip.Parent = player:WaitForChild("PlayerGui")
	chipPill = Instance.new("Frame")
	chipPill.Name = "Pill"
	chipPill.AnchorPoint = Vector2.new(0.5, 0.5)
	chipPill.Position = UDim2.fromScale(0.5, 0.5)
	chipPill.Size = UDim2.fromOffset(0, CHIP.height)
	chipPill.AutomaticSize = Enum.AutomaticSize.X
	chipPill.BackgroundColor3 = Color3.new(1, 1, 1)
	chipPill.Parent = chip
	UIKit.corner(chipPill, CHIP.height / 2)
	UIKit.outline(chipPill, Color3.fromRGB(220, 203, 255), 3)
	local scale = Instance.new("UIScale")
	scale.Parent = chipPill
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = chipPill
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = chipPill
	local picture = Icon.make(chipPill, "Box", UDim2.fromOffset(CHIP.height - 8, CHIP.height - 8))
	picture.LayoutOrder = 1
	chipText = UIKit.label(chipPill, "", Enum.Font.FredokaOne, 20, INK)
	chipText.LayoutOrder = 2
	chipText.Size = UDim2.fromOffset(0, CHIP.height)
	chipText.AutomaticSize = Enum.AutomaticSize.X
	chipText.TextWrapped = false
end

local function onStocked(shelf: unknown, by: unknown, productId: unknown, added: unknown)
	if typeof(shelf) ~= "Instance" or not shelf:IsA("BasePart") or typeof(by) ~= "Instance" or not by:IsA("Player") then
		return
	end
	if typeof(productId) ~= "string" or typeof(added) ~= "number" then
		return
	end
	local character = by.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local camera = workspace.CurrentCamera
	if not root or not root:IsA("BasePart") or not camera then
		return
	end
	if (camera.CFrame.Position - shelf.Position).Magnitude > Delivery.UNBOX.reach then
		return
	end
	UnboxFx.play(shelf, root, productId, added)
end

function DeliveryController.Start()
	buildChip()
	Remotes.DeliveryVan.OnClientEvent:Connect(onVan)
	Remotes.ShelfStocked.OnClientEvent:Connect(onStocked)
	RunService.Heartbeat:Connect(step)
	task.spawn(watchPlots)
	player:GetAttributeChangedSignal("BoxesWaiting"):Connect(refreshChip)
	player:GetAttributeChangedSignal("PlotId"):Connect(refreshChip)
	refreshChip()
	task.spawn(function() -- walking up to the pad or away from it
		while true do
			task.wait(CHIP.check)
			refreshChip()
		end
	end)
end

return DeliveryController
