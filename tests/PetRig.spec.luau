--!strict
local party = require("../src/shared/Config/Party")
local PetRig = require("../src/shared/Util/PetRig")
local expect = require("./lib/expect")

local CFG = party.PET_ANIM

local QUAD = {
	"Root", "Pelvis", "Spine_0", "Neck", "Head_0", "Head_1",
	"0_Left_Limb_0", "0_Left_Limb_1", "0_Right_Limb_0", "0_Right_Limb_1",
	"1_Left_Limb_0", "1_Left_Limb_1", "1_Right_Limb_0", "1_Right_Limb_1",
	"Tail_0", "Tail_1", "Tail_2", "Tail_3",
}
local BIRD = { "Root", "Pelvis", "Spine_0", "Neck", "Head_0", "Head_1", "0_Left_Limb_0", "0_Left_Limb_1", "0_Right_Limb_0", "0_Right_Limb_1" }

local function rolesOf(names: { string }): { PetRig.Role }
	local roles = {}
	for _, name in names do
		local role = PetRig.role(name)
		if role then
			table.insert(roles, role)
		end
	end
	return roles
end

local function poseAt(names: { string }, state: PetRig.State): { [string]: PetRig.Angles }
	local roles = rolesOf(names)
	return PetRig.pose(CFG, roles, PetRig.isBiped(roles), state)
end

local function still(time: number): PetRig.State
	return { time = time, phase = 0, moving = 0, fidget = nil, fidgetProgress = 0 }
end

local function walking(phase: number): PetRig.State
	return { time = 0, phase = phase, moving = 1, fidget = nil, fidgetProgress = 0 }
end

local MAX = math.rad(70)

local function assertBounded(pose: { [string]: PetRig.Angles }, label: string)
	for key, angles in pose do
		for _, value in { angles.x, angles.y, angles.z } do
			assert(math.abs(value) <= MAX, `{label}: {key} turns {math.deg(value)} degrees`)
		end
	end
end

return {
	["bone names map to roles"] = function()
		local leg = PetRig.role("0_Left_Limb_1") :: PetRig.Role
		expect.equal(leg.kind, "leg", "kind")
		expect.equal(leg.pair, 0, "front pair")
		expect.equal(leg.side, "Left", "side")
		expect.equal(leg.segment, 1, "segment")
		expect.equal((PetRig.role("1_Right_Limb_0") :: PetRig.Role).pair, 1, "hind pair")
		expect.equal((PetRig.role("Tail_2") :: PetRig.Role).segment, 2, "tail segment")
		expect.equal((PetRig.role("Head_0") :: PetRig.Role).kind, "head", "head")
		expect.equal((PetRig.role("Spine_1") :: PetRig.Role).kind, "spine", "spine")
		expect.equal((PetRig.role("Ear_Right_1") :: PetRig.Role).kind, "ear", "ear")
		expect.equal(PetRig.role("Root"), nil, "root stays put")
		expect.equal(PetRig.role("bone_12"), nil, "unknown bones stay put")
	end,

	["a bone's own name loses the pack prefix, and aliases rename odd bones"] = function()
		expect.equal(PetRig.shortName("Pet_Cat_Tail_1", "Cat", nil), "Tail_1", "prefix")
		expect.equal(PetRig.shortName("bone_12", "Puppy", party.PET_BONE_ALIASES.Puppy), "Ear_Right_0", "alias")
	end,

	["four legs trot: diagonal legs swing together, left and right opposite"] = function()
		local pose = poseAt(QUAD, walking(math.pi / 2))
		local frontLeft = pose["leg:0:Left:0"].x
		expect.near(pose["leg:1:Right:0"].x, frontLeft, 1e-9, "front left with hind right")
		expect.near(pose["leg:0:Right:0"].x, -frontLeft, 1e-9, "front right opposite")
		assert(math.abs(frontLeft) > math.rad(10), "the legs barely move")
		assertBounded(pose, "trot")
	end,

	["two legs step left then right"] = function()
		local pose = poseAt(BIRD, walking(math.pi / 2))
		expect.near(pose["leg:0:Right:0"].x, -pose["leg:0:Left:0"].x, 1e-9, "opposite")
		assert(math.abs(pose["leg:0:Left:0"].x) > math.rad(10), "the legs barely move")
	end,

	["standing still the legs rest and only the body breathes"] = function()
		for _, time in { 0, 0.7, 1.9, 3.3 } do
			local pose = poseAt(QUAD, still(time))
			for _, key in { "leg:0:Left:0", "leg:1:Right:1" } do
				expect.near(pose[key].x, 0, 1e-9, `{key} at {time}`)
			end
			assert(math.abs(pose["spine:0"].x) <= CFG.BREATH + 1e-9, "breathing too big")
		end
	end,

	["the tail wags in a wave: every segment sways, the tip the most"] = function()
		local biggest = { 0, 0, 0, 0 }
		for step = 0, 40 do
			local pose = poseAt(QUAD, still(step * 0.05))
			for segment = 0, 3 do
				biggest[segment + 1] = math.max(biggest[segment + 1], math.abs(pose[`tail:{segment}`].y))
			end
		end
		assert(biggest[1] > 0, "the tail never moves")
		assert(biggest[4] > biggest[1], "the tip should sway more than the base")
	end,

	["looking around turns the head and comes back"] = function()
		local function headYaw(progress: number): number
			local pose = poseAt(QUAD, { time = 0, phase = 0, moving = 0, fidget = "look", fidgetProgress = progress })
			return pose["head:0"].y + pose["neck:0"].y
		end
		expect.near(headYaw(0), 0, 1e-6, "starts straight")
		expect.near(headYaw(1), 0, 1e-6, "ends straight")
		assert(math.abs(headYaw(0.5)) > math.rad(20), "doesn't look round")
	end,

	["every fidget stays in range"] = function()
		for _, kind in CFG.FIDGETS do
			for _, progress in { 0, 0.25, 0.5, 0.75, 1 } do
				assertBounded(poseAt(QUAD, { time = 1, phase = 0, moving = 0, fidget = kind, fidgetProgress = progress }), `{kind} {progress}`)
			end
		end
	end,

	["fidgets fade out while walking"] = function()
		local idle = poseAt(QUAD, { time = 0, phase = 0, moving = 0, fidget = "look", fidgetProgress = 0.5 })
		local walk = poseAt(QUAD, { time = 0, phase = 0, moving = 1, fidget = "look", fidgetProgress = 0.5 })
		assert(math.abs(walk["neck:0"].y) < math.abs(idle["neck:0"].y), "walking should cancel the look-around")
	end,

	["walking, the tail sways slower and smaller than a standing wag"] = function()
		-- One wag cycle's peak per pose: sample a few seconds, count sign changes of the tip
		local function wag(moving: number): (number, number)
			local crossings, biggest, last = 0, 0, nil
			for step = 0, 400 do
				local time = step * 0.01
				local pose = poseAt(QUAD, { time = time, phase = 0, moving = moving, fidget = nil, fidgetProgress = 0 })
				local yaw = pose["tail:3"].y
				biggest = math.max(biggest, math.abs(yaw))
				if last and (yaw > 0) ~= (last > 0) then
					crossings += 1
				end
				last = yaw
			end
			return crossings, biggest
		end
		local standCrossings, standBiggest = wag(0)
		local walkCrossings, walkBiggest = wag(1)
		assert(walkCrossings <= standCrossings, `walking wags faster ({walkCrossings} vs {standCrossings} swings)`)
		assert(walkBiggest < standBiggest, "walking wags as wide as standing")
	end,

	["starting or stopping a walk never makes the tail jump"] = function()
		-- Same moment, same wag phase: blending from standing into walking only changes the tail a little
		for _, wag in { 0.3, 1.7, 4.1, 9.9 } do
			local before = poseAt(QUAD, { time = 37.2, phase = 0, moving = 0.2, fidget = nil, fidgetProgress = 0, tailPhase = wag })
			local after = poseAt(QUAD, { time = 37.2, phase = 0, moving = 0.3, fidget = nil, fidgetProgress = 0, tailPhase = wag })
			assert(math.abs(after["tail:3"].y - before["tail:3"].y) < math.rad(3), `tail jumps at wag {wag}`)
		end
	end,

	["a pet without tail bones sways its hips so its tails swish, the front stays put"] = function()
		local kitsune = { "Root", "Pelvis", "Spine_0", "Neck", "Head_0", "Head_1", "0_Left_Limb_0", "0_Left_Limb_1", "0_Right_Limb_0", "0_Right_Limb_1", "1_Left_Limb_0", "1_Left_Limb_1", "1_Right_Limb_0", "1_Right_Limb_1" }
		local biggest = 0
		for step = 0, 40 do
			local pose = poseAt(kitsune, { time = step * 0.05, phase = 0, moving = 0, fidget = nil, fidgetProgress = 0, tailPhase = step * 0.2 })
			local hips = pose["pelvis:0"].y
			biggest = math.max(biggest, math.abs(hips))
			expect.near(pose["spine:0"].y, -hips, 1e-9, "the spine turns back so the front stays still")
		end
		assert(biggest > math.rad(4), "the hips barely sway")
		-- A pet with tail bones keeps its hips still and wags the tail itself
		local cat = poseAt(QUAD, still(1.3))
		expect.near(cat["pelvis:0"].y, 0, 1e-9, "a cat's hips stay put")
	end,

	["whole-body fidgets: hop lifts off and lands, spin turns once round, shake settles"] = function()
		for _, progress in { 0, 1 } do
			local hop = PetRig.body(CFG, "hop", progress, 1)
			expect.near(hop.lift, 0, 1e-6, `hop at {progress}`)
			local shake = PetRig.body(CFG, "shake", progress, 1)
			expect.near(shake.roll, 0, 1e-6, `shake at {progress}`)
		end
		assert(PetRig.body(CFG, "hop", 0.25, 1).lift > 0.1, "the hop doesn't leave the ground")
		expect.near(PetRig.body(CFG, "spin", 0.5, 1).yaw, math.pi, 0.15, "halfway round")
		expect.near(PetRig.body(CFG, "spin", 1, 1).yaw, math.pi * 2, 1e-6, "a full turn")
		expect.near(PetRig.body(CFG, "spin", 0.5, -1).yaw, -math.pi, 0.15, "spins either way")
		local none = PetRig.body(CFG, "sniff", 0.5, 1)
		expect.equal(none.lift + none.yaw + none.roll, 0, "bone fidgets don't move the body")
	end,

	["creatures without bones get whole-body fidgets"] = function()
		assert(#CFG.BODY_FIDGETS >= 4, "too few")
		for _, kind in CFG.BODY_FIDGETS do
			local moved = false
			for _, progress in { 0.2, 0.4, 0.6 } do
				local body = PetRig.body(CFG, kind, progress, 1)
				moved = moved or math.abs(body.lift) + math.abs(body.yaw) + math.abs(body.roll) > 1e-3
			end
			assert(moved, `{kind} doesn't move a creature without bones`)
		end
	end,
}
