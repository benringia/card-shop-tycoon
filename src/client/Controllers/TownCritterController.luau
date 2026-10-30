--!strict
-- Ambient animals on this client (Portal Worlds spec): 3 Cute Pets in town, 2 in the plaza and one in each portal area,
-- each running between random points round its home (Util/Wander; or laps round a circle, or resting in one spot)
-- and pausing, drawn and animated by the same code as summoned
-- pets (Util/CreatureVisuals follows an invisible marker this controller moves). Only animals near the camera are shown
-- and moved, and none while the extras are off (Util/Extras). Not synced between players: they're scenery.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
	facing: Vector3,
	resumeAt: number,
	shown: boolean,
}

local TownCritterController = {}

-- Where it heads next: further round its circle, or a fresh point round its home
local function nextTarget(critter: Critter, random: Random)
	local spec = critter.spec
	if spec.orbit then
		critter.target, critter.angle = Wander.orbitTarget(spec.home, spec.orbit, critter.angle, spec.maxArc, random)
	else
		critter.target = Wander.target(spec.home, spec.radius, spec.avoid, random)
	end
end

-- A point on its circle at `angle` degrees
local function circlePoint(spec: any, angle: number): Wander.Point
	local a = math.rad(angle)
	return { x = spec.home.x + math.cos(a) * spec.orbit, z = spec.home.z + math.sin(a) * spec.orbit }
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
	model.Name = spec.model
	local body = CreatureVisuals.build(model, marker, spec.height, false, template.Name)
	model.Parent = folder
	local angle = random:NextNumber(0, 360)
	local start = if spec.orbit then circlePoint(spec, angle) else { x = spec.home.x, z = spec.home.z }
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
		facing = facing,
		resumeAt = 0,
		shown = true,
	}
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
			end
			if show then
				if now >= critter.resumeAt then
					local before = critter.pos
					local arrived
					critter.pos, arrived = Wander.step(before, critter.target, look.SPEED, dt)
					local moved = Vector3.new(critter.pos.x - before.x, 0, critter.pos.z - before.z)
					if moved.Magnitude > 1e-4 then
						critter.facing = moved.Unit
					end
					if arrived then
						critter.resumeAt = now + random:NextNumber(look.PAUSE[1], look.PAUSE[2])
						nextTarget(critter, random)
					end
				end
				local at = Vector3.new(critter.pos.x, critter.ground, critter.pos.z)
				critter.marker.CFrame = CFrame.lookAt(at, at + critter.facing)
				CreatureVisuals.step(critter.body, dt, now, camera, Party.MOTION)
			end
		end
	end)
end

return TownCritterController
