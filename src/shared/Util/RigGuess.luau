--!strict
-- Works out what each bone of a rig with generic bone names does (the Ultra Detailed pack: Root.M.004,
-- Root.L.009, leg.l, ...), from where the bones sit, and names them the way Util/PetRig reads (1_Left_Limb_0,
-- Arm_Left_0, Tail_2, Head_0, ...) so the same walk, wag and fidgets drive them.
-- * Bones named .L/.R (any case) are limbs: sideways ones are arms, high ones pointing up are ears, the rest can
--   be legs. With IK targets (the feet), each foot's leg is the limb ending nearest it, and the target is named
--   Foot_<pair>_<Side> so Util/PetAnimator moves the foot with the leg. Without them, legs are limbs ending low.
-- * The middle bones from the root are the pelvis, then spine, neck and head (a bone named "head" if there is
--   one, else the one furthest to the front-top), and the tail towards the back.
-- Pure, Lune-tested.
--
-- Positions are in the creature's space, divided by its height: x < 0 its left, y from 0 (ground) to 1 (top),
-- z < 0 its front.
export type Bone = { name: string, parent: number, x: number, y: number, z: number } -- parent: index, 0 for none
type Limb = { chain: { number }, side: string, start: Bone, finish: Bone }
type Leg = { limb: Limb, foot: number? } -- foot: the IK target it stands on

local RigGuess = {}

local LEG_DROP = 0.05 -- without IK feet, a limb whose end is at least this much lower than its start...
local LEG_LOW = 0.3 -- ...and ends this low is a leg
local FOOT_REACH = 0.5 -- with IK feet, a leg ends at most this far from its foot
local EAR_HIGH = 0.7 -- a limb starting this high and pointing up is an ear
local ARM_REACH = 0.15 -- a limb reaching this far sideways (further than it drops)...
local ARM_HIGH = 0.4 -- ...from at least this high is an arm (a sprawled leg starts lower), unless named leg
local PAIR_GAP = 0.15 -- legs further apart than this front to back are front and hind pairs
local MAX_SPINE = 3
local MAX_TAIL = 4

-- "L", "R" or "M" from a name like Root.L.009, Leg.R, leg.l.001 or Leg.L.001-IKTarget
local function sideOf(name: string): string
	local lower = string.lower(name)
	for _, side in { "l", "r" } do
		if string.find(lower, `%.{side}[%.%-]`) or string.sub(lower, -2) == `.{side}` then
			return string.upper(side)
		end
	end
	return "M"
end

local function isIk(name: string): boolean
	local lower = string.lower(name)
	return string.find(lower, "iktarget") ~= nil or string.match(lower, "^ik[%.%-_]") ~= nil
end

local function distance(a: Bone, b: Bone): number
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function sideName(side: string): string
	return if side == "L" then "Left" else "Right"
end

function RigGuess.guess(bones: { Bone }): { [string]: string }
	local count = #bones
	local names: { [string]: string } = {}
	if count == 0 then
		return names
	end
	local children: { { number } } = {}
	for index = 1, count do
		children[index] = {}
	end
	for index, bone in bones do
		if bone.parent > 0 and bone.parent <= count then
			table.insert(children[bone.parent], index)
		end
	end
	-- IK targets (the feet) and the bones under them are moved as feet, never as limbs
	local pinned: { [number]: boolean } = {}
	local function pin(index: number)
		pinned[index] = true
		for _, child in children[index] do
			pin(child)
		end
	end
	local targets: { number } = {}
	for index, bone in bones do
		if isIk(bone.name) and not pinned[index] then
			table.insert(targets, index)
			pin(index)
		end
	end
	local side: { string } = {}
	for index, bone in bones do
		side[index] = sideOf(bone.name)
	end
	local function usable(index: number): boolean
		return index > 0 and index <= count and not pinned[index]
	end

	-- Limbs: chains of same-side bones, starting where the side changes
	local function depth(index: number): number
		local deepest = 0
		for _, child in children[index] do
			if side[child] == side[index] and usable(child) then
				deepest = math.max(deepest, 1 + depth(child))
			end
		end
		return deepest
	end
	local function chainFrom(start: number): { number }
		local chain = { start }
		local current = start
		while true do
			local best, bestDepth = 0, -1
			for _, child in children[current] do
				if side[child] == side[current] and usable(child) then
					local d = depth(child)
					if d > bestDepth then
						best, bestDepth = child, d
					end
				end
			end
			if best == 0 then
				return chain
			end
			table.insert(chain, best)
			current = best
		end
	end

	local candidates: { Limb } = {}
	local ears: { Limb } = {}
	local arms: { Limb } = {}
	for index, bone in bones do
		local parent = bone.parent
		local limbSide = side[index]
		if usable(index) and limbSide ~= "M" and not (usable(parent) and side[parent] == limbSide) then
			local chain = chainFrom(index)
			local finish = bones[chain[#chain]]
			local limb = { chain = chain, side = limbSide, start = bone, finish = finish }
			local reach = math.abs(finish.x - bone.x)
			local drop = bone.y - finish.y
			if #chain >= 2 and bone.y >= EAR_HIGH and finish.y > bone.y then
				table.insert(ears, limb)
			elseif #chain >= 2 and reach >= ARM_REACH and reach > drop and bone.y >= ARM_HIGH
				and string.sub(string.lower(bone.name), 1, 3) ~= "leg" then
				table.insert(arms, limb)
			else
				table.insert(candidates, limb)
			end
		end
	end

	local function nameChain(limb: Limb, prefix: string)
		for segment, index in limb.chain do
			if segment <= 3 then
				names[bones[index].name] = `{prefix}{segment - 1}`
			end
		end
	end

	-- Legs, each with the foot it stands on (nil without IK targets)
	local legs: { Leg } = {}
	if #targets > 0 then
		local taken: { [Limb]: boolean } = {}
		for _, target in targets do
			local foot = bones[target]
			local best: Limb? = nil
			local bestGap = FOOT_REACH
			for _, limb in candidates do
				local gap = distance(limb.finish, foot)
				if limb.side == sideOf(foot.name) and not taken[limb] and gap <= bestGap then
					best, bestGap = limb, gap
				end
			end
			if best then
				taken[best] = true
				table.insert(legs, { limb = best, foot = target })
			end
		end
	else
		for _, limb in candidates do
			if limb.start.y - limb.finish.y >= LEG_DROP and limb.finish.y <= LEG_LOW then
				table.insert(legs, { limb = limb, foot = nil })
			end
		end
	end

	-- Front and hind pairs by how far forward the legs start; on each side and pair, the leg reaching lowest
	local front, back = math.huge, -math.huge
	for _, leg in legs do
		front = math.min(front, leg.limb.start.z)
		back = math.max(back, leg.limb.start.z)
	end
	local twoPairs = back - front > PAIR_GAP
	local bestLeg: { [string]: Leg } = {}
	for _, leg in legs do
		local pair = if twoPairs and leg.limb.start.z > (front + back) / 2 then 1 else 0
		local key = `{pair}_{sideName(leg.limb.side)}`
		local current = bestLeg[key]
		if not current or leg.limb.finish.y < current.limb.finish.y then
			bestLeg[key] = leg
		end
	end
	for key, leg in bestLeg do
		nameChain(leg.limb, `{key}_Limb_`)
		if leg.foot then
			names[bones[leg.foot].name] = `Foot_{key}`
		end
	end

	-- Arms (two-legged rigs only: on four legs they're claws or wings): every arm chain, since some rigs have two
	-- sets of arm bones and only one carries the mesh
	if not twoPairs then
		for _, limb in arms do
			nameChain(limb, `Arm_{sideName(limb.side)}_`)
		end
	end
	-- On each side, the longest ear
	local bestEar: { [string]: Limb } = {}
	for _, limb in ears do
		local current = bestEar[limb.side]
		if not current or #limb.chain > #current.chain then
			bestEar[limb.side] = limb
		end
	end
	for limbSide, limb in bestEar do
		nameChain(limb, `Ear_{sideName(limbSide)}_`)
	end

	-- The middle: the pelvis is the first middle bone, the head a bone named so or the one furthest to the
	-- front-top, the tail the one furthest back
	local pelvis = 0
	for index, bone in bones do
		if usable(index) and side[index] == "M" and not usable(bone.parent) then
			pelvis = index
			break
		end
	end
	if pelvis == 0 then
		return names
	end
	local middle: { number } = {}
	local function collect(index: number)
		table.insert(middle, index)
		for _, child in children[index] do
			if usable(child) and side[child] == "M" then
				collect(child)
			end
		end
	end
	collect(pelvis)
	local function pathTo(target: number): { number }
		local path = {}
		local current = target
		while current ~= pelvis and usable(current) do
			table.insert(path, 1, current)
			current = bones[current].parent
		end
		return path -- after the pelvis, ending at the target
	end
	local head, headScore = 0, -math.huge
	local namedHead = false
	local tail, tailZ = 0, bones[pelvis].z + 0.1
	for _, index in middle do
		local bone = bones[index]
		if not namedHead and string.lower(bone.name) == "head" then
			head, namedHead = index, true
		elseif not namedHead and bone.y - bone.z > headScore then
			head, headScore = index, bone.y - bone.z
		end
		if bone.z > tailZ then
			tail, tailZ = index, bone.z
		end
	end
	names[bones[pelvis].name] = "Pelvis"
	local headPath = if head ~= pelvis then pathTo(head) else {}
	local onHeadPath: { [number]: boolean } = {}
	for _, index in headPath do
		onHeadPath[index] = true
	end
	-- A named head is Head_0 itself; a guessed one is the tip, Head_1, below its Head_0
	local tip = if namedHead then 0 else 1
	local steps = #headPath
	for position, index in headPath do
		local fromEnd = steps - position -- 0 for the target
		local name = bones[index].name
		if fromEnd == 0 then
			names[name] = if tip == 1 and steps >= 2 then "Head_1" else "Head_0"
		elseif fromEnd == tip then
			names[name] = "Head_0"
		elseif fromEnd == tip + 1 then
			names[name] = "Neck"
		elseif position <= MAX_SPINE then
			names[name] = `Spine_{position - 1}`
		end
	end
	if tail ~= 0 then
		local segment = 0
		for _, index in pathTo(tail) do
			if not onHeadPath[index] and segment < MAX_TAIL then
				names[bones[index].name] = `Tail_{segment}`
				segment += 1
			end
		end
	end
	return names
end

-- Whether the guess found legs to walk on (without them the creature uses the whole-body motion instead)
function RigGuess.hasLegs(names: { [string]: string }): boolean
	for _, role in names do
		if string.find(role, "_Limb_") then
			return true
		end
	end
	return false
end

return RigGuess
