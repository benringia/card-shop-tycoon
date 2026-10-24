--!strict
-- Procedural bone animation for rigged pack pets (Cute Pets: Root, Pelvis, Spine, Neck, Head, legs as
-- <pair>_<Side>_Limb_<segment> with pair 0 front and 1 hind, Tail_0..3, Puppy ears via aliases). Pure, Lune-tested:
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

-- 0 at the start and end of a fidget, 1 through its middle (eased in and out)
local function envelope(progress: number): number
	local p = math.clamp(progress, 0, 1)
	return math.sin(p * math.pi) ^ 2
end

export type Body = { lift: number, yaw: number, roll: number }

-- The whole creature's part of a fidget: lift (studs at size 1), yaw and roll (radians). boned: a rigged pet, whose
-- look-around is its head's job, not the body's
function PetRig.body(cfg: any, kind: string?, progress: number, side: number, boned: boolean?): Body
	local p = math.clamp(progress, 0, 1)
	local lift, yaw, roll = 0, 0, 0
	if kind == "hop" then
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
	return { lift = lift, yaw = yaw, roll = roll }
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
	local hasTail = false
	for _, role in roles do
		if role.kind == "tail" then
			hasTail = true
			break
		end
	end
	-- No tail bones: the tails are skinned to the hips, so the hips sway them and the spine turns back
	local hips = if hasTail then 0 else rad(cfg.HIP_SWAY) * math.sin(wag) * wagScale

	local pose: { [string]: Angles } = {}
	for _, role in roles do
		local x, y, z = 0, 0, 0
		if role.kind == "leg" then
			-- Trot: front-left with hind-right; two legs: left, right
			local offset = if role.side == "Left" then 0 else math.pi
			if not biped and role.pair == 1 then
				offset += math.pi
			end
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
			y = hips
			if fidget == "sit" then
				x = rad(cfg.SIT) * amount
			end
		elseif role.kind == "spine" then
			x = breath * idle + bob * 0.5
			if role.segment == 0 then
				y = -hips
			end
			if fidget == "stretch" then
				x += rad(cfg.STRETCH) * 0.4 * amount
			elseif fidget == "sit" then
				x -= rad(cfg.SIT) * 0.8 * amount -- the front stays up while the hips go down
			end
			z = shake * 0.6
		elseif role.kind == "neck" or role.kind == "head" then
			local share = if role.kind == "neck" then 0.45 else 0.55
			y = lookYaw * share
			x = -bob * share
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
		elseif role.kind == "tail" then
			local amplitude = rad(cfg.TAIL_WAG) * (1 + cfg.TAIL_GROW * role.segment) * wagScale
			y = amplitude * math.sin(wag - role.segment * cfg.TAIL_LAG)
			x = -breath * 0.5
		elseif role.kind == "ear" then
			local flop = rad(cfg.EAR_FLOP) * (math.sin(state.phase * 2 + role.segment) * moving + 0.3 * math.sin(state.time * 1.7 + role.segment) * idle)
			z = if role.side == "Left" then flop else -flop
		end
		pose[role.key] = { x = x, y = y, z = z }
	end
	return pose
end

return PetRig
