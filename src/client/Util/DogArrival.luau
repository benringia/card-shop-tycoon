--!strict
-- A guide dog's arrival (Pish's after the welcome flight, Chikin's after Pish's goodbye; owner 2026-11-10 for its shot):
-- since the owner 2026-11-11 ("change the pish and chicken entrance cinematic ... still epic/magical/welcoming") it
-- opens with magic (Util/DogMagic, ArrivalShot.magic, Config/Pish ARRIVAL.MAGIC): the camera looks out from beside the
-- player as a golden circle on the ground calls him, he pops out of a burst of stars with a bark and a happy hop as his
-- name card pops up, the camera pushing in on him; then he runs in trailing sparkles, the camera riding low beside him
-- on his paws, slowly panning up to his face and zooming out to the two of you as he stops in front of the player in
-- hearts and stars and barks (Util/ArrivalShot, Config/Pish ARRIVAL). He runs in from the first clear way (never
-- through a shelf or a wall), the camera rides on the clearer side and never goes through a wall. A tap skips it.
-- `done` runs once the camera is back behind the player.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pish = require(Shared:WaitForChild("Config"):WaitForChild("Pish"))
local ArrivalShot = require(Shared:WaitForChild("Util"):WaitForChild("ArrivalShot"))

local PishVisual = require((script.Parent :: Instance):WaitForChild("PishVisual"))
local DogMagic = require((script.Parent :: Instance):WaitForChild("DogMagic"))
local ScreenClear = require((script.Parent :: Instance):WaitForChild("ScreenClear"))

local DogArrival = {}

local ARRIVAL = Pish.ARRIVAL
local MAGIC = ARRIVAL.MAGIC

-- His name card as he pops out (DogMagic.banner): his name, what he is to you, its colour
export type Intro = { name: string, role: string, color: Color3 }

-- `at`: the player's root; `dog`: his marker (placed at the start here); `playBark`: his bark clip; `intro`: his card
local function runNow(at: BasePart, dog: BasePart, visual: PishVisual.Visual?, character: Model?, playBark: () -> (), done: () -> (), intro: Intro?)
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
	-- The magic: the camera beside the player looking out at the circle, then pushing in on him as he pops out
	local cam = MAGIC.camera
	local callTarget = start + up * cam.lookUp
	local callShot = CFrame.lookAt(clear(callTarget, feet - outward * cam.back + side * cam.side + up * cam.up), callTarget)
	local heroTarget = start + up * cam.hero.lookUp
	local heroShot = CFrame.lookAt(clear(heroTarget, start + runWay * cam.hero.ahead + side * cam.hero.side + up * cam.hero.up), heroTarget)
	local magicStarted = os.clock()
	local running = false
	local function shot(): CFrame
		if not running then
			local now = ArrivalShot.magic(os.clock() - magicStarted, MAGIC)
			if now.phase == "call" then
				return callShot
			end
			local eased = 1 - (1 - math.min(1, now.share * cam.push)) ^ 3
			return callShot:Lerp(heroShot, eased)
		end
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
	camera.CFrame = shot() -- a cut to the magic circle
	if visual then
		PishVisual.setShown(visual, false) -- not there till he pops out of the stars
	end
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
		-- the circle calls him...
		DogMagic.preload()
		local stopCircle = DogMagic.circle(start, MAGIC.call)
		DogMagic.sound("call")
		hold(MAGIC.call)
		stopCircle()
		-- ...he pops out of the stars, barks and hops, his name card up
		if visual then
			PishVisual.setShown(visual, true)
		end
		if not skipped then
			DogMagic.poof(start + up * 1.2)
			if visual then
				PishVisual.sound(visual, "bark")
				PishVisual.play(visual, "happyHop")
			end
			if intro then
				DogMagic.banner(intro.name, intro.role, intro.color)
			end
			hold(MAGIC.hop)
		end
		-- then he runs in, sparkles trailing him
		running = true
		local stopTrail = DogMagic.trail(dog)
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
		stopTrail()
		local facing = Vector3.new(at.Position.X, stop.Y, at.Position.Z)
		if dog.Parent then
			dog.CFrame = CFrame.lookAt(stop, facing)
		end
		if not skipped then
			DogMagic.arrive(stop + up * 1.5)
			if visual then
				PishVisual.hearts(visual)
			end
			playBark()
			hold(if visual then math.max(PishVisual.length(visual, "bark"), 1) else 1)
		end
		follow:Disconnect()
		tap:Disconnect()
		camera.CameraType = Enum.CameraType.Custom
		done()
	end)
end

-- Runs once the screen is clear (no purchase dialog or Roblox menu: Util/ScreenClear; owner 2026-11-13): at once when
-- it already is
function DogArrival.run(at: BasePart, dog: BasePart, visual: PishVisual.Visual?, character: Model?, playBark: () -> (), done: () -> (), intro: Intro?)
	task.spawn(function()
		ScreenClear.wait()
		runNow(at, dog, visual, character, playBark, done, intro)
	end)
end

return DogArrival
