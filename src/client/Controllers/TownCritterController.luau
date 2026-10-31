--!strict
-- Ambient animals on this client (Portal Worlds spec): 3 Cute Pets in town, 2 in the plaza and one in each portal area,
-- each running between random points round its home (Util/Wander; or laps along a circle, or asleep in one spot with a
-- "z Z z" floating over it) and pausing, drawn and animated by the same code as summoned
-- pets (Util/CreatureVisuals follows an invisible marker this controller moves). Only animals near the camera are shown
-- and moved, and none while the extras are off (Util/Extras). Not synced between players: they're scenery.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Ambient = require(Config:WaitForChild("Ambient"))
local Party = require(Config:WaitForChild("Party"))
local SharedUtil = Shared:WaitForChild("Util")
local Place = require(SharedUtil:WaitForChild("Place"))
local Wander = require(SharedUtil:WaitForChild("Wander"))
local ClientUtil = ((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util")
local CreatureVisuals = require(ClientUtil:WaitForChild("CreatureVisuals"))
local Extras = require(ClientUtil:WaitForChild("Extras"))

type Critter = {
	spec: any,
	ground: number,
	marker: Part,
	body: CreatureVisuals.Body,
	pos: Wander.Point,
	target: Wander.Point,
	angle: number, -- degrees round the circle, for one running laps
	targetAngle: number,
	facing: Vector3,
	rest: Vector3, -- a sleeper's feet from where it lies
	snore: BillboardGui?, -- a sleeper's "z Z z", shown and hidden with its model
	resumeAt: number,
	shown: boolean,
}

local TownCritterController = {}

-- Where it heads next: further round its circle, or a fresh point round its home (a sleeper stays put)
local function nextTarget(critter: Critter, random: Random)
	local spec = critter.spec
	if spec.orbit then
		critter.targetAngle = Wander.orbitTarget(critter.angle, spec.maxArc, random)
	elseif not spec.sleeps then
		critter.target = Wander.target(spec.home, spec.radius, spec.avoid, random)
	end
end

-- A sleeper: lying on its side (CreatureVisuals' fainted pose) with a "z Z z" bobbing and fading over it
local function fallAsleep(marker: Part, height: number): BillboardGui
	marker:SetAttribute("Fainted", true)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(2.2, 1.1)
	board.StudsOffset = Vector3.new(0, height * 0.75, 0)
	board.MaxDistance = Ambient.CRITTER.RANGE
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(235, 245, 255)
	label.TextStrokeTransparency = 0.3
	label.TextStrokeColor3 = Color3.fromRGB(60, 80, 140)
	label.Text = "z Z z"
	label.Parent = board
	board.Parent = marker
	local drift = TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(board, drift, { StudsOffset = Vector3.new(0.3, height * 0.75 + 0.6, 0) }):Play()
	TweenService:Create(label, drift, { TextTransparency = 0.5, TextStrokeTransparency = 0.7 }):Play()
	return board
end

local function spawnCritter(folder: Folder, spec: any, random: Random): Critter?
	local template = CreatureVisuals.getTemplate("CreatureModels", spec.model, Ambient.CRITTER.MAX_PARTS, "CutePets")
	if not template then
		warn(`[TownCritterController] no Cute Pets model {spec.model}`)
		return nil
	end
	local ground = spec.y or 0
	local marker = Instance.new("Part")
	marker.Name = "CritterMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.one
	marker.CFrame = CFrame.new(spec.home.x, ground, spec.home.z)
	marker.Parent = folder
	local model = template:Clone()
	CreatureVisuals.strip(model)
	if spec.variant then
		CreatureVisuals.applyVariant(model, spec.variant)
	end
	model.Name = spec.model
	local body = CreatureVisuals.build(model, marker, spec.height, false, template.Name)
	model.Parent = folder
	local angle = random:NextNumber(0, 360)
	local start = if spec.orbit then Wander.circlePoint(spec.home, spec.orbit, angle) else { x = spec.home.x, z = spec.home.z }
	local facing = Vector3.new(0, 0, -1)
	if spec.faces then
		local toward = Vector3.new(spec.faces.x - start.x, 0, spec.faces.z - start.z)
		if toward.Magnitude > 1e-4 then
			facing = toward.Unit
		end
	end
	local critter: Critter = {
		spec = spec,
		ground = ground,
		marker = marker,
		body = body,
		pos = start,
		target = start,
		angle = angle,
		targetAngle = angle,
		facing = facing,
		rest = Vector3.zero,
		snore = nil,
		resumeAt = 0,
		shown = true,
	}
	if spec.sleeps then
		-- It rolls toward its left: feet to the right, and up, so its body lies on the spot
		local sleep = Ambient.CRITTER.SLEEP
		critter.rest = CFrame.lookAt(Vector3.zero, facing).RightVector * spec.height * sleep.shift + Vector3.new(0, spec.height * sleep.lift, 0)
		critter.snore = fallAsleep(marker, spec.height)
	end
	nextTarget(critter, random)
	return critter
end

function TownCritterController.Start()
	if Place.isFrontier() or Place.isDungeon() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "TownCritters"
	folder.Parent = workspace
	local random = Random.new()
	local critters: { Critter } = {}
	for _, spec in Ambient.CRITTERS do
		local critter = spawnCritter(folder, spec, random)
		if critter then
			table.insert(critters, critter)
		end
	end
	local look = Ambient.CRITTER
	RunService.RenderStepped:Connect(function(dt)
		local enabled = Extras.enabled()
		local now = os.clock()
		local camera = workspace.CurrentCamera.CFrame.Position
		for _, critter in critters do
			local home = Vector3.new(critter.spec.home.x, critter.ground, critter.spec.home.z)
			local show = enabled and (home - camera).Magnitude <= look.RANGE
			if show ~= critter.shown then
				critter.shown = show
				critter.body.model.Parent = if show then folder else nil
				if critter.snore then
					critter.snore.Enabled = show
				end
			end
			if show then
				if now >= critter.resumeAt and not critter.spec.sleeps then
					local before = critter.pos
					local arrived
					if critter.spec.orbit then
						critter.angle, arrived = Wander.orbitStep(critter.angle, critter.targetAngle, critter.spec.orbit, look.SPEED, dt)
						critter.pos = Wander.circlePoint(critter.spec.home, critter.spec.orbit, critter.angle)
					else
						critter.pos, arrived = Wander.step(before, critter.target, look.SPEED, dt)
					end
					local moved = Vector3.new(critter.pos.x - before.x, 0, critter.pos.z - before.z)
					if moved.Magnitude > 1e-4 then
						critter.facing = moved.Unit
					end
					if arrived then
						critter.resumeAt = now + random:NextNumber(look.PAUSE[1], look.PAUSE[2])
						nextTarget(critter, random)
					end
				end
				local at = Vector3.new(critter.pos.x, critter.ground, critter.pos.z) + critter.rest
				critter.marker.CFrame = CFrame.lookAt(at, at + critter.facing)
				CreatureVisuals.step(critter.body, dt, now, camera, Party.MOTION)
			end
		end
	end)
end

return TownCritterController
