--!strict
-- Drives a rigged pack pet's bones on this client (Util/PetRig works out the angles): walks, breathing, tail
-- wags, ear flops and a random idle fidget every few seconds. Angles are in the creature's own space; each bone
-- turns about its own pivot, and child bones follow their parents (a tail curls as a wave). Only pets near the
-- camera are animated. Numbers: Config/Party PET_ANIM.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Party = require(Shared:WaitForChild("Config"):WaitForChild("Party"))
local PetRig = require(Shared:WaitForChild("Util"):WaitForChild("PetRig"))
local RigGuess = require(Shared:WaitForChild("Util"):WaitForChild("RigGuess"))

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
	flying: boolean,
	flapPhase: number,
	undulate: string?, -- "swim" or "slither" (Party.UNDULATE)
	swimPhase: number,
	armDrop: { [string]: number }, -- radians each side's arm is lowered (from its T-pose)
	armForward: number?, -- Party.ARM_POSE for this model, radians
	armBend: number?,
	armSwing: number?, -- radians the arms swing walking (Party.ARM_POSE), else PET_ANIM.ARM_SWING
	feet: { Foot }, -- IK target feet, carried with their leg
	size: number,
	flapRate: number, -- Party.WING_SPEED for this model, else 1
	nextFidget: number,
	random: Random,
	signature: { fidget: string, chance: number }?, -- Party.SIGNATURE for this model
	cued: boolean, -- the playing fidget's effect has gone off
}

-- An IK target foot (named Foot_<pair>_<Side> by Util/RigGuess) and where it sits from its leg's hip at rest
type Foot = { bone: Bone, role: PetRig.Role, hip: Bone, fromHip: CFrame }

local PetAnimator = {}

local function gap(random: Random): number
	local range = Party.PET_ANIM.FIDGET_GAP
	return random:NextNumber(range[1], range[2])
end

-- Roles for a rig with generic bone names (Root.M.004, ...): guessed from where its bones sit (Util/RigGuess)
local function guessNames(model: Model, root: BasePart, bones: { Bone }): { [string]: string }
	local height = math.max(model:GetExtentsSize().Y, 0.1)
	local index: { [Instance]: number } = {}
	for position, bone in bones do
		index[bone] = position
	end
	local points: { RigGuess.Bone } = {}
	for position, bone in bones do
		local at = root.CFrame:PointToObjectSpace(bone.WorldPosition) / height
		points[position] = { name = bone.Name, parent = index[bone.Parent :: Instance] or 0, x = at.X, y = at.Y, z = at.Z }
	end
	return RigGuess.guess(points)
end

-- Names each wing (Party.WINGS: its first bone, then the same-side bones under it) Wing_Left_0, Wing_Left_1, ...
-- Returns whether it found any.
local function nameWings(model: Model, sourceName: string, names: { [string]: string }): boolean
	local found = false
	for _, first in Party.WINGS[sourceName] or {} do
		for _, side in { { "L", "Left" }, { "R", "Right" } } do
			local name = string.gsub(first, "%.L(%.?)", `.{side[1]}%1`, 1)
			local bone = model:FindFirstChild(name, true)
			local segment = 0
			while bone and bone:IsA("Bone") and segment <= 3 do
				names[bone.Name] = `Wing_{side[2]}_{segment}`
				found = true
				segment += 1
				local nextBone: Instance? = nil
				for _, child in bone:GetChildren() do
					if child:IsA("Bone") and string.find(child.Name, `.{side[1]}`, 1, true) then
						nextBone = child
						break
					end
				end
				bone = nextBone
			end
		end
	end
	return found
end

-- The pet's bones with a role, their rest turn relative to the creature's root; nil without any (static model)
function PetAnimator.attach(model: Model, root: BasePart, sourceName: string, size: number, flying: boolean): Rig?
	local all: { Bone } = {}
	local named = false
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") then
			descendant.Transform = CFrame.new()
			table.insert(all, descendant)
			named = named or PetRig.role(PetRig.shortName(descendant.Name, sourceName, nil)) ~= nil
		end
	end
	local aliases: { [string]: string }? = Party.PET_BONE_ALIASES[sourceName]
	local undulate = Party.UNDULATE[sourceName]
	if not named then
		-- Generic names: guessed, with the wings from Party.WINGS; without legs, wings or a body wave it keeps the
		-- whole-body motion
		local guessed = guessNames(model, root, all)
		local winged = nameWings(model, sourceName, guessed)
		if not winged and not undulate and not RigGuess.hasLegs(guessed) then
			return nil
		end
		aliases = guessed
	end
	local bones = {}
	local roles = {}
	local byKey: { [string]: Bone } = {}
	local feetFound: { { bone: Bone, role: PetRig.Role } } = {}
	for _, descendant in all do
		local role = PetRig.role(PetRig.shortName(descendant.Name, sourceName, aliases))
		if role and role.kind == "foot" then
			table.insert(feetFound, { bone = descendant, role = role })
		elseif role then
			local rest = (root.CFrame:Inverse() * descendant.WorldCFrame).Rotation
			table.insert(bones, { bone = descendant, key = role.key, rest = rest, restInverse = rest:Inverse() })
			table.insert(roles, role)
			byKey[role.key] = descendant
		end
	end
	if #bones == 0 then
		return nil
	end
	local feet: { Foot } = {}
	for _, found in feetFound do
		local hip = byKey[`leg:{found.role.pair}:{found.role.side}:0`]
		if hip then
			table.insert(feet, { bone = found.bone, role = found.role, hip = hip, fromHip = hip.WorldCFrame:Inverse() * found.bone.WorldCFrame })
		end
	end
	-- How far down each T-posed arm turns to hang: from its shoulder-to-hand direction to ARM_HANG off straight down
	local armDrop: { [string]: number } = {}
	local armPose = Party.ARM_POSE[sourceName]
	for _, side in { "Left", "Right" } do
		local shoulder = byKey[`arm:{side}:0`]
		local hand = byKey[`arm:{side}:2`] or byKey[`arm:{side}:1`]
		if shoulder and hand then
			local along = root.CFrame:VectorToObjectSpace(hand.WorldPosition - shoulder.WorldPosition)
			local fromDown = math.atan2(math.abs(along.X), -along.Y)
			armDrop[side] = math.max(0, fromDown - math.rad(armPose and armPose.hang or Party.PET_ANIM.ARM_HANG))
		end
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
		flying = flying and not undulate,
		flapPhase = random:NextNumber(0, math.pi * 2),
		undulate = undulate,
		swimPhase = random:NextNumber(0, math.pi * 2),
		armDrop = armDrop,
		armForward = if armPose then math.rad(armPose.forward) else nil,
		armBend = if armPose then math.rad(armPose.bend) else nil,
		armSwing = if armPose and armPose.swing then math.rad(armPose.swing) else nil,
		feet = feet,
		size = size,
		flapRate = Party.WING_SPEED[sourceName] or 1,
		nextFidget = os.clock() + gap(random),
		random = random,
		signature = Party.SIGNATURE[sourceName],
		cued = false,
	}
end

-- The whole body's part of the fidget playing (a hop, a spin, a shake), in studs at size 1 and radians
function PetAnimator.bodyPose(rig: Rig, now: number): PetRig.Body
	if not rig.fidget then
		return { lift = 0, yaw = 0, roll = 0, pitch = 0 }
	end
	return PetRig.body(Party.PET_ANIM, rig.fidget, (now - rig.fidgetStart) / rig.fidgetLength, rig.side, true)
end

-- The playing fidget's effect, once, when it's due (Util/SignatureFx draws it); nil otherwise
function PetAnimator.takeCue(rig: Rig, now: number): string?
	local fidget = rig.fidget
	if not fidget or rig.cued or not PetRig.cue(Party.PET_ANIM, fidget, (now - rig.fidgetStart) / rig.fidgetLength) then
		return nil
	end
	rig.cued = true
	return fidget
end

-- How far this frame's wingbeat lifts the body (studs at size 1); 0 for pets on the ground
function PetAnimator.flapLift(rig: Rig): number
	return if rig.flying then PetRig.flapLift(Party.PET_ANIM, rig.flapPhase) else 0
end

-- One frame: walking blends in with speed; standing, the next fidget starts when it's due
function PetAnimator.step(rig: Rig, dt: number, now: number, walking: boolean, walked: number)
	local cfg = Party.PET_ANIM
	local target = if walking then 1 else 0
	rig.moving += (target - rig.moving) * math.min(1, dt / cfg.BLEND_SECONDS)
	rig.tailPhase = (rig.tailPhase + PetRig.wagSpeed(cfg, rig.moving) * math.min(dt, 0.1)) % (math.pi * 2)
	if rig.flying then
		rig.flapPhase = (rig.flapPhase + PetRig.flapSpeed(cfg, rig.moving) * rig.flapRate * math.min(dt, 0.1)) % (math.pi * 2)
	end
	if rig.undulate then
		rig.swimPhase = (rig.swimPhase + PetRig.swimSpeed(cfg, rig.moving) * math.min(dt, 0.1)) % (math.pi * 2)
	end
	if rig.fidget and now - rig.fidgetStart >= rig.fidgetLength then
		rig.fidget = nil
		rig.nextFidget = now + gap(rig.random)
	end
	if walking then
		rig.nextFidget = math.max(rig.nextFidget, now + 1) -- a fidget waits until it stops
	elseif not rig.fidget and now >= rig.nextFidget then
		local kinds = if rig.flying or rig.undulate then cfg.FLY_FIDGETS else cfg.FIDGETS
		local kind = kinds[rig.random:NextInteger(1, #kinds)]
		local signature = rig.signature
		if signature and rig.random:NextNumber() < signature.chance then
			kind = signature.fidget
		end
		rig.fidget = kind
		rig.cued = false
		rig.fidgetStart = now
		rig.fidgetLength = cfg.FIDGET_SECONDS[kind] or 2
		rig.side = if rig.random:NextNumber() < 0.5 then 1 else -1
	end
	local state: PetRig.State = {
		time = now,
		phase = walked / math.max(rig.stride, 0.1) * math.pi * 2,
		moving = rig.moving,
		fidget = rig.fidget,
		fidgetProgress = if rig.fidget then (now - rig.fidgetStart) / rig.fidgetLength else 0,
		side = rig.side,
		tailPhase = rig.tailPhase,
		flying = rig.flying,
		flapPhase = rig.flapPhase,
		armDrop = rig.armDrop,
		armForward = rig.armForward,
		armBend = rig.armBend,
		armSwing = rig.armSwing,
		undulate = rig.undulate,
		swimPhase = rig.swimPhase,
	}
	local pose = PetRig.pose(cfg, rig.roles, rig.biped, state)
	for _, entry in rig.bones do
		local angles = pose[entry.key]
		if angles then
			-- A turn in the creature's space, applied about the bone's own pivot
			entry.bone.Transform = entry.restInverse * CFrame.Angles(angles.x, angles.y, angles.z) * entry.rest
		end
	end
	-- IK feet: carried round with their leg's hip, lifted as the leg swings forward
	for _, foot in rig.feet do
		local parent = foot.bone.Parent
		local parentFrame = if parent and parent:IsA("Bone") then parent.TransformedWorldCFrame
			elseif parent and parent:IsA("BasePart") then parent.CFrame
			else nil
		if parentFrame then
			local lift = PetRig.footLift(cfg, foot.role, rig.biped, state) * rig.size
			local want = CFrame.new(0, lift, 0) * foot.hip.TransformedWorldCFrame * foot.fromHip
			foot.bone.Transform = (parentFrame * foot.bone.CFrame):Inverse() * want
		end
	end
end

return PetAnimator
