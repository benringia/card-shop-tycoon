--!strict
-- A guide dog's arrival (Pish's after the welcome flight, Chikin's after Pish's goodbye; owner 2026-11-10 for its shot):
-- a bark, then the camera rides low beside him on his paws as he runs in, slowly pans up to his face, and zooms out to
-- the two of you as he stops in front of the player and barks (Util/ArrivalShot, Config/Pish ARRIVAL). He runs in from
-- the first clear way (never through a shelf or a wall), the camera rides on the clearer side and never goes through a
-- wall. A tap skips it. `done` runs once the camera is back behind the player.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pish = require(Shared:WaitForChild("Config"):WaitForChild("Pish"))
local ArrivalShot = require(Shared:WaitForChild("Util"):WaitForChild("ArrivalShot"))

local PishVisual = require((script.Parent :: Instance):WaitForChild("PishVisual"))

local DogArrival = {}

local ARRIVAL = Pish.ARRIVAL

-- `at`: the player's root; `dog`: his marker (placed at the start here); `playBark`: his bark clip
function DogArrival.run(at: BasePart, dog: BasePart, visual: PishVisual.Visual?, character: Model?, playBark: () -> (), done: () -> ())
	local up = Vector3.yAxis
	local look = Vector3.new(at.CFrame.LookVector.X, 0, at.CFrame.LookVector.Z).Unit
	local feet = at.Position - Vector3.new(0, 3, 0)
	local blockers = RaycastParams.new()
	blockers.FilterType = Enum.RaycastFilterType.Exclude
	blockers.FilterDescendantsInstances = { character or dog, dog, if visual then visual.body.model else dog }
	local function freeFor(from: Vector3, way: Vector3, length: number): number
		local hit = workspace:Raycast(from, way * length, blockers)
		return if hit then hit.Distance else length
	end
	-- His run: in front of the player if it's clear, else the first clear way fanning out left and right, else the
	-- longest (Util/ArrivalShot.pickRun): he never runs through a shelf or a wall
	local ways, clearance = {}, {}
	for _, degrees in { 0, 30, -30, 60, -60, 90, -90, 135, -135, 180 } do
		local way = CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(look)
		table.insert(ways, way)
		table.insert(clearance, freeFor(feet + up * 1.2, way, ARRIVAL.from + ARRIVAL.wallGap))
	end
	local index, runFrom = ArrivalShot.pickRun(clearance, ARRIVAL)
	local outward = ways[index]
	local across = Vector3.new(-outward.Z, 0, outward.X) -- to the side of his way in
	local stop = feet + outward * ARRIVAL.stop + across * ARRIVAL.stopSide
	local start = feet + outward * runFrom + across * math.min(ARRIVAL.startSide, runFrom * 0.15)
	local run = Vector3.new(stop.X - start.X, 0, stop.Z - start.Z)
	local runLength = run.Magnitude
	local runWay = run.Unit
	-- The camera rides on the side of his run with fewer things in the way (Util/ArrivalShot.pickSide)
	local side = Vector3.new(runWay.Z, 0, -runWay.X)
	local blocked = { 0, 0 }
	for sample = 0, 5 do
		local point = start + run * (sample / 5) + up * 1
		for which, sign in { 1, -1 } do
			if freeFor(point, side * sign, ARRIVAL.wide.side) < ARRIVAL.wide.side then
				blocked[which] += 1
			end
		end
	end
	side *= ArrivalShot.pickSide(blocked[1], blocked[2])
	-- The wide shot of the two of you: the first angle with a clear view (Util/ArrivalShot.pickWide)
	local middle = (feet + stop) / 2
	local wideTarget = middle + up * ARRIVAL.wide.lookUp
	local widePlaces, wideFree = {}, {}
	for _, angle in ARRIVAL.wideAngles do
		local place = middle + side * angle.side + outward * angle.out + up * angle.up
		local reach = (place - wideTarget).Magnitude
		table.insert(widePlaces, place)
		table.insert(wideFree, freeFor(wideTarget, (place - wideTarget).Unit, reach) / reach)
	end
	local widePlace = widePlaces[ArrivalShot.pickWide(wideFree, ARRIVAL)]
	dog.CFrame = CFrame.lookAt(start, Vector3.new(stop.X, start.Y, stop.Z))
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	-- Never through a wall or a shelf: the camera stops short of anything between it and what it looks at
	local function clear(from: Vector3, to: Vector3): Vector3
		local hit = workspace:Raycast(from, to - from, blockers)
		return if hit then hit.Position + (from - to).Unit * 0.5 else to
	end
	local function shot(): CFrame
		local here = dog.Position
		local covered = Vector3.new(here.X - start.X, 0, here.Z - start.Z).Magnitude
		local frame = ArrivalShot.at(if runLength > 0 then covered / runLength else 1, ARRIVAL)
		local target = here + up * frame.lookUp
		local close = CFrame.lookAt(clear(target, here + side * frame.side + runWay * frame.ahead + up * frame.up), target)
		if frame.wide <= 0 then
			return close
		end
		local wide = CFrame.lookAt(clear(wideTarget, widePlace), wideTarget)
		return close:Lerp(wide, frame.wide)
	end
	camera.CFrame = shot() -- a cut to his paws
	local skipped = false
	local tap = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			skipped = true
		end
	end)
	local follow = RunService.RenderStepped:Connect(function(dt)
		camera.CFrame = camera.CFrame:Lerp(shot(), math.min(1, dt * ARRIVAL.follow))
	end)
	task.spawn(function()
		local function hold(seconds: number)
			local from = os.clock()
			while os.clock() - from < seconds and not skipped do
				task.wait()
			end
		end
		hold(ARRIVAL.delay)
		if visual and not skipped then
			PishVisual.sound(visual, "bark")
		end
		while not skipped and dog.Parent do
			local now = dog.Position
			local flat = Vector3.new(stop.X - now.X, 0, stop.Z - now.Z)
			if flat.Magnitude < 0.3 then
				break
			end
			local dt = task.wait()
			local nextAt = now + flat.Unit * math.min(flat.Magnitude, ARRIVAL.speed * dt)
			dog.CFrame = CFrame.lookAt(nextAt, nextAt + flat.Unit)
		end
		local facing = Vector3.new(at.Position.X, stop.Y, at.Position.Z)
		if dog.Parent then
			dog.CFrame = CFrame.lookAt(stop, facing)
		end
		if not skipped then
			playBark()
			hold(if visual then math.max(PishVisual.length(visual, "bark"), 1) else 1)
		end
		follow:Disconnect()
		tap:Disconnect()
		camera.CameraType = Enum.CameraType.Custom
		done()
	end)
end

return DogArrival
