--!strict
-- Drives a rigged pack pet's bones on this client (Util/PetRig works out the angles): walks, breathing, tail
-- wags, ear flops and a random idle fidget every few seconds. Angles are in the creature's own space; each bone
-- turns about its own pivot, and child bones follow their parents (a tail curls as a wave). Only pets near the
-- camera are animated. Numbers: Config/Party PET_ANIM.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Party = require(Shared:WaitForChild("Config"):WaitForChild("Party"))
local PetRig = require(Shared:WaitForChild("Util"):WaitForChild("PetRig"))

export type Rig = {
	bones: { { bone: Bone, key: string, rest: CFrame, restInverse: CFrame } },
	roles: { PetRig.Role },
	biped: boolean,
	stride: number, -- studs per leg cycle at this size
	moving: number,
	fidget: string?,
	fidgetStart: number,
	fidgetLength: number,
	side: number,
	tailPhase: number,
	nextFidget: number,
	random: Random,
}

local PetAnimator = {}

local function gap(random: Random): number
	local range = Party.PET_ANIM.FIDGET_GAP
	return random:NextNumber(range[1], range[2])
end

-- The pet's bones with a role, their rest turn relative to the creature's root; nil without any (static model)
function PetAnimator.attach(model: Model, root: BasePart, sourceName: string, size: number): Rig?
	local aliases = Party.PET_BONE_ALIASES[sourceName]
	local bones = {}
	local roles = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") then
			local role = PetRig.role(PetRig.shortName(descendant.Name, sourceName, aliases))
			if role then
				descendant.Transform = CFrame.new()
				local rest = (root.CFrame:Inverse() * descendant.WorldCFrame).Rotation
				table.insert(bones, { bone = descendant, key = role.key, rest = rest, restInverse = rest:Inverse() })
				table.insert(roles, role)
			end
		end
	end
	if #bones == 0 then
		return nil
	end
	local random = Random.new()
	return {
		bones = bones,
		roles = roles,
		biped = PetRig.isBiped(roles),
		stride = Party.PET_ANIM.STRIDE * size,
		moving = 0,
		fidget = nil,
		fidgetStart = 0,
		fidgetLength = 1,
		side = 1,
		tailPhase = random:NextNumber(0, math.pi * 2),
		nextFidget = os.clock() + gap(random),
		random = random,
	}
end

-- The whole body's part of the fidget playing (a hop, a spin, a shake), in studs at size 1 and radians
function PetAnimator.bodyPose(rig: Rig, now: number): PetRig.Body
	if not rig.fidget then
		return { lift = 0, yaw = 0, roll = 0 }
	end
	return PetRig.body(Party.PET_ANIM, rig.fidget, (now - rig.fidgetStart) / rig.fidgetLength, rig.side, true)
end

-- One frame: walking blends in with speed; standing, the next fidget starts when it's due
function PetAnimator.step(rig: Rig, dt: number, now: number, walking: boolean, walked: number)
	local cfg = Party.PET_ANIM
	local target = if walking then 1 else 0
	rig.moving += (target - rig.moving) * math.min(1, dt / cfg.BLEND_SECONDS)
	rig.tailPhase = (rig.tailPhase + PetRig.wagSpeed(cfg, rig.moving) * math.min(dt, 0.1)) % (math.pi * 2)
	if rig.fidget and now - rig.fidgetStart >= rig.fidgetLength then
		rig.fidget = nil
		rig.nextFidget = now + gap(rig.random)
	end
	if walking then
		rig.nextFidget = math.max(rig.nextFidget, now + 1) -- a fidget waits until it stops
	elseif not rig.fidget and now >= rig.nextFidget then
		local kinds = cfg.FIDGETS
		local kind = kinds[rig.random:NextInteger(1, #kinds)]
		rig.fidget = kind
		rig.fidgetStart = now
		rig.fidgetLength = cfg.FIDGET_SECONDS[kind] or 2
		rig.side = if rig.random:NextNumber() < 0.5 then 1 else -1
	end
	local pose = PetRig.pose(cfg, rig.roles, rig.biped, {
		time = now,
		phase = walked / math.max(rig.stride, 0.1) * math.pi * 2,
		moving = rig.moving,
		fidget = rig.fidget,
		fidgetProgress = if rig.fidget then (now - rig.fidgetStart) / rig.fidgetLength else 0,
		side = rig.side,
		tailPhase = rig.tailPhase,
	})
	for _, entry in rig.bones do
		local angles = pose[entry.key]
		if angles then
			-- A turn in the creature's space, applied about the bone's own pivot
			entry.bone.Transform = entry.restInverse * CFrame.Angles(angles.x, angles.y, angles.z) * entry.rest
		end
	end
end

return PetAnimator
