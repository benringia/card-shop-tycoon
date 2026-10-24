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

	["flying pets tuck their legs instead of walking, and beat with the flap"] = function()
		local function fly(phase: number, flap: number, moving: number): { [string]: PetRig.Angles }
			return poseAt(BIRD, { time = 1, phase = phase, moving = moving, fidget = nil, fidgetProgress = 0, flying = true, flapPhase = flap })
		end
		local a, b = fly(0.3, 0, 1), fly(2.4, 0, 1)
		expect.near(a["leg:0:Left:0"].x, b["leg:0:Left:0"].x, 1e-9, "the legs don't stride in the air")
		expect.near(a["leg:0:Left:0"].x, a["leg:0:Right:0"].x, 1e-9, "both legs tucked the same")
		assert(math.abs(a["leg:0:Left:0"].x) > math.rad(15), "the legs aren't tucked")
		local up, down = fly(0, math.pi / 2, 0), fly(0, -math.pi / 2, 0)
		assert(math.abs(up["spine:0"].x - down["spine:0"].x) > math.rad(4), "the body doesn't beat with the flap")
		assertBounded(up, "flying")
	end,

	["wings beat up and down together, mirrored, and rest folded on the ground"] = function()
		local WINGED = table.clone(BIRD)
		for _, name in { "Wing_Left_0", "Wing_Left_1", "Wing_Right_0", "Wing_Right_1" } do
			table.insert(WINGED, name)
		end
		local role = PetRig.role("Wing_Left_1")
		assert(role and role.kind == "wing" and role.side == "Left" and role.segment == 1, "Wing_Left_1 is a wing")
		local function fly(flap: number): { [string]: PetRig.Angles }
			return poseAt(WINGED, { time = 1, phase = 0, moving = 0, fidget = nil, fidgetProgress = 0, flying = true, flapPhase = flap })
		end
		local up, down = fly(math.pi / 2), fly(-math.pi / 2)
		assert(math.abs(up["wing:Left:0"].z - down["wing:Left:0"].z) > math.rad(40), "the wing doesn't beat")
		expect.near(up["wing:Left:0"].z, -up["wing:Right:0"].z, 1e-9, "the wings mirror each other")
		assertBounded(up, "flapping")
		local ground = poseAt(WINGED, still(1))
		assert(math.abs(ground["wing:Left:0"].z) < math.rad(10), "wings flap on the ground")
	end,

	["arms hang down at the sides and swing against the legs"] = function()
		local BIPED = { "Pelvis", "Spine_0", "Head_0", "0_Left_Limb_0", "0_Right_Limb_0", "Arm_Left_0", "Arm_Left_1", "Arm_Right_0" }
		local role = PetRig.role("Arm_Left_1")
		assert(role and role.kind == "arm" and role.side == "Left" and role.segment == 1, "Arm_Left_1 is an arm")
		local drop = { Left = math.rad(70), Right = math.rad(70) }
		local standing = poseAt(BIPED, { time = 0, phase = 0, moving = 0, fidget = nil, fidgetProgress = 0, armDrop = drop })
		expect.near(standing["arm:Left:0"].z, math.rad(70), 1e-9, "the left arm lowered")
		expect.near(standing["arm:Right:0"].z, -math.rad(70), 1e-9, "the right arm lowered the other way")
		local step = poseAt(BIPED, { time = 0, phase = math.pi / 2, moving = 1, fidget = nil, fidgetProgress = 0, armDrop = drop })
		assert(step["arm:Left:0"].x * step["leg:0:Left:0"].x < 0, "the arm swings against its leg")
		assertBounded(step, "walking arms")
		local trex = poseAt(BIPED, { time = 0, phase = 0, moving = 0, fidget = nil, fidgetProgress = 0, armDrop = drop,
			armForward = math.rad(55), armBend = math.rad(50) })
		assert(trex["arm:Left:0"].x - standing["arm:Left:0"].x > math.rad(50), "the arms don't reach forward")
		assert(trex["arm:Left:1"].x > standing["arm:Left:1"].x + math.rad(30), "the elbows don't bend more")
	end,

	["feet lift as their leg swings forward and stay down standing"] = function()
		local foot = PetRig.role("Foot_1_Right")
		assert(foot and foot.kind == "foot" and foot.pair == 1 and foot.side == "Right", "Foot_1_Right is a foot")
		local roles = rolesOf(QUAD)
		local lifts = {}
		for step = 0, 15 do
			lifts[step] = PetRig.footLift(CFG, foot, false, walking(step / 16 * math.pi * 2))
		end
		local most, least = -1, 1
		for _, lift in lifts do
			most, least = math.max(most, lift), math.min(least, lift)
		end
		assert(most > 0.1 and least >= 0, "the foot doesn't step")
		expect.near(PetRig.footLift(CFG, foot, false, still(1)), 0, 1e-9, "standing, the foot is down")
		local _ = roles
	end,

	["swimmers wave their body from head to tail, even standing still"] = function()
		local FISH = { "Pelvis", "Spine_0", "Neck", "Head_0", "Tail_0", "Tail_1", "Tail_2" }
		local function swim(swimPhase: number, moving: number, kind: string): { [string]: PetRig.Angles }
			return poseAt(FISH, { time = 0, phase = 0, moving = moving, fidget = nil, fidgetProgress = 0, undulate = kind, swimPhase = swimPhase })
		end
		local a = swim(1, 0, "swim")
		assert(math.abs(a["tail:2"].y) > math.rad(8), "the tail doesn't sweep")
		assert(math.abs(a["tail:2"].y - a["tail:0"].y) > 1e-3, "the wave doesn't travel down the tail")
		assert(math.abs(a["head:0"].y) < math.abs(a["tail:2"].y), "the head sweeps as much as the tail")
		assertBounded(a, "swimming")
		local still, going = swim(1, 0, "slither"), swim(1, 1, "slither")
		assert(math.abs(going["tail:1"].y) > math.abs(still["tail:1"].y) * 2, "a slither is mostly while moving")
		assert(PetRig.swimSpeed(CFG, 1) > PetRig.swimSpeed(CFG, 0), "swims faster going along")
	end,

	["the flap lifts the body up and down"] = function()
		expect.near(PetRig.flapLift(CFG, 0), 0, 1e-9, "level")
		assert(PetRig.flapLift(CFG, math.pi / 2) > 0.1, "doesn't rise")
		assert(PetRig.flapLift(CFG, -math.pi / 2) < -0.05, "doesn't dip")
		assert(PetRig.flapSpeed(CFG, 1) > PetRig.flapSpeed(CFG, 0), "flaps faster flying along")
	end,

	["a roar rears back, lunges forward and settles"] = function()
		expect.near(PetRig.body(CFG, "roar", 0, 1).pitch, 0, 1e-6, "starts level")
		expect.near(PetRig.body(CFG, "roar", 1, 1).pitch, 0, 1e-6, "ends level")
		local rear, lunge = 0, 0
		for step = 0, 100 do
			local pitch = PetRig.body(CFG, "roar", step / 100, 1).pitch
			rear = math.max(rear, pitch)
			lunge = math.min(lunge, pitch)
		end
		assert(rear > math.rad(10), "doesn't rear back")
		assert(lunge < -math.rad(4), "doesn't lunge forward")
		assert(PetRig.roarBurst(CFG, 0.3) == false and PetRig.roarBurst(CFG, 0.5) == true, "the shockwave goes off at the lunge")
	end,

	["a stomp rises and slams back down"] = function()
		expect.near(PetRig.body(CFG, "stomp", 0, 1).lift, 0, 1e-6, "starts down")
		expect.near(PetRig.body(CFG, "stomp", 1, 1).lift, 0, 1e-6, "ends down")
		assert(PetRig.body(CFG, "stomp", 0.3, 1).lift > 0.2, "doesn't rise")
		assert(#CFG.TITAN_FIDGETS >= 3, "too few titan fidgets")
	end,
}
