--!strict
-- Procedural bone animation for rigged pack pets (Cute Pets: Root, Pelvis, Spine, Neck, Head, legs as
-- <pair>_<Side>_Limb_<segment> with pair 0 front and 1 hind, Tail_0..3, Ear_<Side>_<n>, Wing_<Side>_<n>;
-- other rigs are named this way by Util/RigGuess and Party.WINGS). Pure, Lune-tested:
-- turns time, walk phase and an idle fidget into angles per bone role, in model space (x = pitch forward/back,
-- y = yaw left/right, z = roll). Util/PetAnimator applies them to the bones on the client. Numbers:
-- Config/Party PET_ANIM.
export type Role = { kind: string, pair: number, side: string, segment: number, key: string }
export type Angles = { x: number, y: number, z: number }
export type State = {
	time: number, -- seconds
	phase: number, -- walk cycle, radians (distance walked / stride)
	moving: number, -- 0 standing .. 1 walking (blended)
	fidget: string?, -- the idle fidget playing, if any
	fidgetProgress: number, -- 0 .. 1 through it
	side: number?, -- which way a look-around turns: 1 or -1
	tailPhase: number?, -- the tail's wag, radians, built up frame by frame (PetRig.wagSpeed): changing speed never jumps
	flying: boolean?, -- in the air: legs tucked, the body beats with the flap instead of walking
	flapPhase: number?, -- the wingbeat, radians, built up frame by frame (PetRig.flapSpeed)
	armDrop: { [string]: number }?, -- radians each side's arm turns down from its rest (T-posed arms hang)
	armForward: number?, -- radians the arms reach forward once lowered (a T-rex's), from Party.ARM_POSE
	armBend: number?, -- radians the elbows bend, else PET_ANIM.ARM_BEND
	armSwing: number?, -- radians the arms swing walking, else PET_ANIM.ARM_SWING
	undulate: string?, -- "swim" (fish: always) or "slither" (snakes: mostly moving): the body waves side to side
	swimPhase: number?, -- that wave, radians, built up frame by frame (PetRig.swimSpeed)
}

local PetRig = {}

local TAU = math.pi * 2

-- A bone's name without the pack prefix ("Pet_Cat_Tail_1" -> "Tail_1"), renamed by the model's aliases
function PetRig.shortName(boneName: string, modelName: string, aliases: { [string]: string }?): string
	local prefix = `Pet_{modelName}_`
	local short = if string.sub(boneName, 1, #prefix) == prefix then string.sub(boneName, #prefix + 1) else boneName
	return if aliases and aliases[short] then aliases[short] else short
end

-- What a bone does, from its short name (nil: it stays put)
function PetRig.role(name: string): Role?
	local pair, side, segment = string.match(name, "^(%d)_(%a+)_Limb_(%d)$")
	if pair and side and segment then
		return { kind = "leg", pair = tonumber(pair) :: number, side = side, segment = tonumber(segment) :: number, key = `leg:{pair}:{side}:{segment}` }
	end
	local armSide, armSegment = string.match(name, "^Arm_(%a+)_(%d)$")
	if armSide and armSegment then
		return { kind = "arm", pair = 0, side = armSide, segment = tonumber(armSegment) :: number, key = `arm:{armSide}:{armSegment}` }
	end
	local footPair, footSide = string.match(name, "^Foot_(%d)_(%a+)$")
	if footPair and footSide then
		return { kind = "foot", pair = tonumber(footPair) :: number, side = footSide, segment = 0, key = `foot:{footPair}:{footSide}` }
	end
	local wingSide, wingSegment = string.match(name, "^Wing_(%a+)_(%d)$")
	if wingSide and wingSegment then
		return { kind = "wing", pair = 0, side = wingSide, segment = tonumber(wingSegment) :: number, key = `wing:{wingSide}:{wingSegment}` }
	end
	local hydraHead, hydraSegment = string.match(name, "^Hydra_(%d)_(%d)$")
	if hydraHead and hydraSegment then
		return { kind = "hydra", pair = tonumber(hydraHead) :: number, side = "", segment = tonumber(hydraSegment) :: number, key = `hydra:{hydraHead}:{hydraSegment}` }
	end
	local jawHead = string.match(name, "^Jaw_(%d)$")
	if jawHead then
		return { kind = "jaw", pair = tonumber(jawHead) :: number, side = "", segment = 0, key = `jaw:{jawHead}` }
	end
	local earSide, earSegment = string.match(name, "^Ear_(%a+)_(%d)$")
	if earSide and earSegment then
		return { kind = "ear", pair = 0, side = earSide, segment = tonumber(earSegment) :: number, key = `ear:{earSide}:{earSegment}` }
	end
	local kind, index = string.match(name, "^(%a+)_(%d)$")
	local kinds = { Spine = "spine", Head = "head", Tail = "tail" }
	if kind and index and kinds[kind] then
		local segment = tonumber(index) :: number
		return { kind = kinds[kind], pair = 0, side = "", segment = segment, key = `{kinds[kind]}:{segment}` }
	end
	if name == "Neck" then
		return { kind = "neck", pair = 0, side = "", segment = 0, key = "neck:0" }
	end
	if name == "Pelvis" then
		return { kind = "pelvis", pair = 0, side = "", segment = 0, key = "pelvis:0" }
	end
	return nil
end

-- Two legs only (birds): they step left, right instead of trotting
function PetRig.isBiped(roles: { Role }): boolean
	for _, role in roles do
		if role.kind == "leg" and role.pair == 1 then
			return false
		end
	end
	return true
end

-- How fast the tail's wag phase moves (radians a second) at this much walking: callers add it up each frame
function PetRig.wagSpeed(cfg: any, moving: number): number
	return TAU / cfg.TAIL_SECONDS * (1 + (cfg.TAIL_WALK - 1) * math.clamp(moving, 0, 1))
end

-- How fast a swimmer's (or slitherer's) body wave moves (radians a second): quicker going along
function PetRig.swimSpeed(cfg: any, moving: number): number
	return TAU / cfg.SWIM_SECONDS * (1 + (cfg.SWIM_FAST - 1) * math.clamp(moving, 0, 1))
end

-- Where a leg is in the walk cycle: trot (front-left with hind-right) or, on two legs, left then right
local function legOffset(role: Role, biped: boolean): number
	local offset = if role.side == "Left" then 0 else math.pi
	if not biped and role.pair == 1 then
		offset += math.pi
	end
	return offset
end

-- How high a foot lifts (studs at size 1) as its leg swings forward; for feet moved apart from their leg (IK
-- targets: Util/PetAnimator carries them with the leg and adds this). role: the foot's (or its leg's) role.
function PetRig.footLift(cfg: any, role: Role, biped: boolean, state: State): number
	if state.flying then
		return 0
	end
	return cfg.FOOT_LIFT * math.max(0, math.cos(state.phase + legOffset(role, biped))) * math.clamp(state.moving, 0, 1)
end

-- Where a middle bone sits along a waving body (larger is further back) and how much it sways; nil: not part of it
local function waveSpot(role: Role): (number?, number)
	if role.kind == "head" then
		return -3, 0.3
	elseif role.kind == "neck" then
		return -2.4, 0.45
	elseif role.kind == "spine" then
		return -(role.segment + 1) * 0.6, 0.55
	elseif role.kind == "pelvis" then
		return 0, 0.6
	elseif role.kind == "tail" then
		return role.segment + 1, 0.8 + 0.35 * role.segment
	end
	return nil, 0
end

-- How fast the wingbeat moves (radians a second): quicker flying along than hovering
function PetRig.flapSpeed(cfg: any, moving: number): number
	return TAU / cfg.FLAP_SECONDS * (1 + (cfg.FLAP_FAST - 1) * math.clamp(moving, 0, 1))
end

-- How far the flap lifts the body (studs at size 1): up on the downstroke, a smaller dip on the upstroke
function PetRig.flapLift(cfg: any, flapPhase: number): number
	local beat = math.sin(flapPhase)
	return cfg.FLAP_LIFT * (if beat > 0 then beat else beat * 0.5)
end

-- 0 at the start and end of a fidget, 1 through its middle (eased in and out)
local function envelope(progress: number): number
	local p = math.clamp(progress, 0, 1)
	return math.sin(p * math.pi) ^ 2
end

export type Body = { lift: number, yaw: number, roll: number, pitch: number }

-- When a roar's shockwave goes off: as the lunge starts (ROAR_BURST of the way through)
function PetRig.roarBurst(cfg: any, progress: number): boolean
	return progress >= cfg.ROAR_BURST
end

-- The whole creature's part of a fidget: lift (studs at size 1), yaw, roll and pitch (radians, positive rears back). boned: a rigged pet, whose
-- look-around is its head's job, not the body's
function PetRig.body(cfg: any, kind: string?, progress: number, side: number, boned: boolean?): Body
	local p = math.clamp(progress, 0, 1)
	local lift, yaw, roll, pitch = 0, 0, 0, 0
	if kind == "roar" then
		-- Rear back, then lunge forward with a shudder, then settle
		local burst = cfg.ROAR_BURST
		local rad = math.rad(cfg.ROAR_PITCH)
		if p < burst then
			pitch = rad * math.sin(p / burst * math.pi / 2)
			lift = cfg.ROAR_LIFT * (p / burst)
		else
			local q = (p - burst) / (1 - burst)
			-- From reared back, through level, down into the lunge, and back to level
			pitch = rad * math.cos(q * math.pi) * math.sqrt(1 - q)
			lift = cfg.ROAR_LIFT * (1 - q) ^ 2
			roll = math.rad(3) * math.sin(q * TAU * 8) * (1 - q)
		end
	elseif kind == "stomp" then
		-- Up, then a fast slam
		lift = cfg.STOMP_HEIGHT * (if p < 0.6 then math.sin(p / 0.6 * math.pi / 2) else math.cos((p - 0.6) / 0.4 * math.pi / 2) ^ 3)
		pitch = math.rad(6) * envelope(p)
	elseif kind == "hop" then
		lift = cfg.HOP_HEIGHT * math.abs(math.sin(p * TAU))
	elseif kind == "spin" then
		local eased = p * p * (3 - 2 * p)
		yaw = side * TAU * eased
	elseif kind == "shake" then
		roll = math.rad(cfg.SHAKE_BODY) * math.sin(p * TAU * 6) * (1 - p)
	elseif kind == "look" and not boned then
		yaw = side * math.rad(cfg.LOOK) * envelope(p)
	elseif kind == "bounce" then
		lift = cfg.BOUNCE * math.abs(math.sin(p * TAU * 1.5)) * (1 - p)
	end
	return { lift = lift, yaw = yaw, roll = roll, pitch = pitch }
end

function PetRig.pose(cfg: any, roles: { Role }, biped: boolean, state: State): { [string]: Angles }
	local rad = math.rad
	local moving = math.clamp(state.moving, 0, 1)
	local idle = 1 - moving
	local fidget = state.fidget
	local progress = math.clamp(state.fidgetProgress, 0, 1)
	local amount = if fidget then envelope(progress) * idle else 0
	local side = state.side or 1
	local lookYaw = if fidget == "look" then rad(cfg.LOOK) * amount * side else 0
	local breath = cfg.BREATH * math.sin(state.time * TAU / cfg.BREATH_SECONDS)
	local bob = rad(cfg.WALK_BOB) * math.sin(state.phase * 2) * moving
	local shake = if fidget == "shake" then rad(cfg.SHAKE) * math.sin(progress * TAU * 6) * (1 - progress) * idle else 0

	local wagScale = (1 + (if fidget == "wag" then (cfg.HAPPY_WAG - 1) * amount else 0)) * (1 + (cfg.TAIL_WALK_AMOUNT - 1) * moving)
	local wag = state.tailPhase or state.time * TAU / cfg.TAIL_SECONDS
	local hasTail, hasUpperSpine, hasNeck = false, false, false
	for _, role in roles do
		hasTail = hasTail or role.kind == "tail"
		hasUpperSpine = hasUpperSpine or (role.kind == "spine" and role.segment == 1)
		hasNeck = hasNeck or role.kind == "neck"
	end
	-- No tail bones: the tails are skinned to the hips, so the hips sway them and the spine turns back. Two-legged
	-- rigs without a tail have no tail to swish: they shift their weight slowly from foot to foot instead
	local hips = if hasTail or biped then 0 else rad(cfg.HIP_SWAY) * math.sin(wag) * wagScale
	local weight = if biped and not hasTail then rad(cfg.IDLE_SWAY) * math.sin(state.time * TAU / cfg.IDLE_SWAY_SECONDS) * idle else 0
	-- Walking on two legs: the hips turn with the forward leg and dip over the standing one, the shoulders turn
	-- back against them and the neck keeps the head facing ahead
	local walkTwist = if biped and not flying then -rad(cfg.HIP_TWIST) * math.sin(state.phase) * moving else 0
	local walkRoll = if biped and not flying then rad(cfg.HIP_ROLL) * math.sin(state.phase) * moving else 0
	-- What's left of the twist at the shoulders, undone by the neck (or the head without one)
	local shoulderTwist = walkTwist * (0.5 - (if hasUpperSpine then cfg.SHOULDER_COUNTER else 0))

	local flying = state.flying == true
	local flap = if flying then math.sin(state.flapPhase or 0) else 0

	local undulating = state.undulate ~= nil
	local swim = state.swimPhase or 0
	local strength = if state.undulate == "slither" then cfg.SLITHER_STILL + (1 - cfg.SLITHER_STILL) * moving else 1 + 0.3 * moving

	local pose: { [string]: Angles } = {}
	for _, role in roles do
		local x, y, z = 0, 0, 0
		if role.kind == "leg" and flying then
			-- Tucked up under the body, swinging a little with each beat
			x = if role.segment == 0 then rad(cfg.LEG_TUCK) + rad(4) * flap else rad(cfg.KNEE_TUCK) / role.segment
		elseif role.kind == "leg" and state.undulate == "swim" then
			-- Swimmers paddle slowly with the stroke
			x = if role.segment == 0 then rad(cfg.LEG_SWING) * 0.5 * math.sin(swim + legOffset(role, biped)) else 0
		elseif role.kind == "leg" then
			-- Trot: front-left with hind-right; two legs: left, right
			local offset = legOffset(role, biped)
			local swing = math.sin(state.phase + offset) * moving
			local hind = not biped and role.pair == 1
			if role.segment == 0 then
				x = rad(cfg.LEG_SWING) * swing
				if fidget == "stretch" and role.pair == 0 then
					x -= rad(cfg.STRETCH) * amount
				elseif fidget == "sit" and hind then
					x -= rad(cfg.SIT) * 1.5 * amount
				elseif fidget == "scratch" and hind and role.side == "Right" then
					x -= rad(cfg.SCRATCH) * amount
				elseif fidget == "hop" then
					x -= rad(10) * math.abs(math.sin(progress * TAU)) * idle
				end
			else
				-- The lower leg bends as the leg comes forward, then straightens to land
				x = -rad(cfg.KNEE_LIFT) * math.max(0, math.cos(state.phase + offset)) * moving / role.segment
				if fidget == "sit" and hind then
					x += rad(cfg.SIT) * 2 * amount / role.segment
				elseif fidget == "scratch" and hind and role.side == "Right" then
					-- The quick scratching
					x += rad(18) * math.sin(progress * TAU * 8) * amount
				end
			end
		elseif role.kind == "pelvis" then
			y = hips + walkTwist
			z = walkRoll + weight
			if fidget == "sit" then
				x = rad(cfg.SIT) * amount
			end
		elseif role.kind == "spine" then
			x = (if flying then rad(cfg.FLAP_PITCH) * flap else breath * idle + bob * 0.5)
			if role.segment == 0 then
				y = -hips - walkTwist * 0.5
				z = -(walkRoll + weight) * 0.7
			elseif role.segment == 1 then
				y = -walkTwist * cfg.SHOULDER_COUNTER
			end
			if fidget == "stretch" then
				x += rad(cfg.STRETCH) * 0.4 * amount
			elseif fidget == "sit" then
				x -= rad(cfg.SIT) * 0.8 * amount -- the front stays up while the hips go down
			end
			z += shake * 0.6
		elseif role.kind == "neck" or role.kind == "head" then
			local share = if role.kind == "neck" then 0.45 else 0.55
			y = lookYaw * share
			if role.segment == 0 and (role.kind == "neck" or not hasNeck) then
				y -= shoulderTwist
			end
			x = if flying then -rad(cfg.FLAP_PITCH) * flap * share else -bob * share
			z = shake * share
			if fidget == "sniff" then
				x += rad(cfg.SNIFF) * share * amount
			elseif fidget == "yawn" then
				x -= rad(cfg.YAWN) * share * amount
			elseif fidget == "scratch" and role.kind == "head" then
				z += rad(12) * amount
			end
			if fidget == "tilt" and role.kind == "head" and role.segment == 0 then
				z = rad(cfg.TILT) * amount
			end
			if role.kind == "head" and role.segment > 0 then
				-- The tip of the head only follows a little
				x *= 0.3
				y *= 0.3
				z *= 0.3
			end
		elseif role.kind == "hydra" then
			-- One neck of many (Hydra_<head>_<bone>, the last bone its head): each sways and nods on its own beat, the
			-- wave running up the neck; they all join in the look, sniff, yawn and shake
			local beat = state.time * TAU / cfg.HYDRA_SECONDS + role.pair * cfg.HYDRA_SPREAD - role.segment * cfg.HYDRA_LAG
			local share = 0.25 + 0.15 * role.segment
			local calm = 1 - 0.4 * moving
			y = rad(cfg.HYDRA_SWAY) * math.sin(beat) * calm + lookYaw * share
			x = rad(cfg.HYDRA_NOD) * math.sin(beat * 1.6 + 1) * calm - bob * share
			z = shake * share
			if fidget == "sniff" then
				x += rad(cfg.SNIFF) * share * amount
			elseif fidget == "yawn" then
				x -= rad(cfg.YAWN) * share * amount
			elseif fidget == "tilt" and role.segment == 3 then
				z += rad(cfg.TILT) * amount * (if role.pair % 2 == 0 then 1 else -1)
			end
		elseif role.kind == "jaw" then
			-- Snapping open now and then, each head at its own moment; wide open in a yawn
			local snap = math.max(0, math.sin(state.time * TAU / cfg.JAW_SNAP_SECONDS + role.pair * cfg.HYDRA_SPREAD * 2)) ^ 4
			x = -rad(cfg.JAW_SNAP) * snap
			if fidget == "yawn" then
				x = math.min(x, -rad(cfg.JAW_YAWN) * amount)
			end
		elseif role.kind == "tail" then
			local amplitude = rad(cfg.TAIL_WAG) * (1 + cfg.TAIL_GROW * role.segment) * wagScale
			y = amplitude * math.sin(wag - role.segment * cfg.TAIL_LAG)
			x = -breath * 0.5
		elseif role.kind == "arm" then
			-- Lowered from a T-pose to hang at the sides, swinging against the leg on the same side
			local drop = if state.armDrop then state.armDrop[role.side] or 0 else 0
			if role.segment == 0 then
				z = if role.side == "Left" then drop else -drop
				x = (state.armSwing or rad(cfg.ARM_SWING)) * math.sin(state.phase + legOffset(role, biped) + math.pi) * moving + breath * idle
					+ (state.armForward or 0)
			elseif drop > 0 then
				x = (state.armBend or rad(cfg.ARM_BEND)) / role.segment -- elbows forward
			end
		elseif role.kind == "wing" then
			-- Beating about the body's length, the tip a little behind the root; folded still on the ground
			local beat = if flying then rad(cfg.WING_FLAP) * math.sin((state.flapPhase or 0) - role.segment * cfg.WING_LAG) else 0
			z = if role.side == "Left" then -beat else beat
		elseif role.kind == "ear" then
			local flop = rad(cfg.EAR_FLOP) * (math.sin(state.phase * 2 + role.segment) * moving + 0.3 * math.sin(state.time * 1.7 + role.segment) * idle)
			z = if role.side == "Left" then flop else -flop
		end
		if undulating then
			local spot, share = waveSpot(role)
			if spot then
				-- The wave replaces the wag: each bone a little behind the one in front of it
				y = (if role.kind == "tail" then 0 else y) + rad(cfg.SWIM_BEND) * share * strength * math.sin(swim - spot * cfg.SWIM_LAG)
			end
		end
		pose[role.key] = { x = x, y = y, z = z }
	end
	return pose
end

return PetRig
