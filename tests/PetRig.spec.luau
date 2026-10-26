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
		local wide = poseAt(BIPED, { time = 0, phase = math.pi / 2, moving = 1, fidget = nil, fidgetProgress = 0, armDrop = drop,
			armSwing = math.rad(40) })
		assert(math.abs(wide["arm:Left:0"].x) > math.abs(step["arm:Left:0"].x) + math.rad(10), "Party.ARM_POSE swing doesn't widen the swing")
	end,

	["signature idles: a butterfly on the raised hand, a rippling hydra roar, a lion's roar"] = function()
		assert(not PetRig.cue(CFG, "butterfly", 0.05) and PetRig.cue(CFG, "butterfly", 0.2), "the butterfly appears as the hand comes up")
		assert(PetRig.cue(CFG, "voidroar", CFG.ROAR_BURST) and not PetRig.cue(CFG, "voidroar", CFG.ROAR_BURST - 0.05), "the void roar goes off with the lunge")
		assert(PetRig.cue(CFG, "thunderroar", CFG.ROAR_BURST), "the thunder roar goes off with the lunge")
		assert(not PetRig.cue(CFG, "look", 0.9), "ordinary fidgets have no effect")

		local function at(names: { string }, kind: string, progress: number): { [string]: PetRig.Angles }
			return poseAt(names, { time = 0, phase = 0, moving = 0, fidget = kind, fidgetProgress = progress, armDrop = { Left = math.rad(70), Right = math.rad(70) } })
		end
		local SPRITE = { "Pelvis", "Spine_0", "Neck", "Head_0", "0_Left_Limb_0", "0_Right_Limb_0", "Arm_Left_0", "Arm_Right_0", "Arm_Right_1", "Ear_Left_0" }
		local rest, lifted = at(SPRITE, "look", 0), at(SPRITE, "butterfly", 0.5)
		assert(lifted["arm:Right:0"].x - rest["arm:Right:0"].x > math.rad(40), "the hand doesn't come up for the butterfly")
		assert(math.abs(lifted["arm:Left:0"].x - rest["arm:Left:0"].x) < math.rad(5), "the other arm moves too")
		assert(lifted["head:0"].x < rest["head:0"].x, "it doesn't look up at the butterfly")
		assertBounded(lifted, "butterfly")

		local HYDRA = { "Pelvis", "Spine_0", "Spine_1" }
		for head = 0, 6 do
			table.insert(HYDRA, `Hydra_{head}_3`)
			table.insert(HYDRA, `Jaw_{head}`)
		end
		local rear, lunge = at(HYDRA, "voidroar", 0.25), at(HYDRA, "voidroar", 0.7)
		assert(rear["hydra:0:3"].x < -math.rad(5) and lunge["hydra:0:3"].x > math.rad(3), "the heads don't rear back and lunge")
		assert(math.abs(rear["hydra:0:3"].x - rear["hydra:6:3"].x) > math.rad(2), "all heads roar at once instead of rippling")
		assert(at(HYDRA, "voidroar", 0.55)["jaw:3"].x < -math.rad(25), "the jaws don't gape")
		assertBounded(rear, "void roar")

		local LION = { "Pelvis", "Spine_0", "Neck", "Head_0", "Jaw_0", "Tail_0", "Tail_1", "0_Left_Limb_0", "0_Right_Limb_0", "1_Left_Limb_0", "1_Right_Limb_0" }
		for step = 0, 30 do
			expect.near(poseAt(LION, still(step * 0.13))["jaw:0"].x, 0, 1e-9, "a lion's jaw snaps while idle")
		end
		local roar = at(LION, "thunderroar", 0.55)
		assert(roar["jaw:0"].x < -math.rad(25), "the lion doesn't open its mouth to roar")
		assert(at(LION, "thunderroar", 0.25)["head:0"].x < -math.rad(5), "the lion doesn't rear its head back")
		assertBounded(roar, "thunder roar")
	end,

	["storm roars ripple through a hydra's heads; fire breath holds the mouth open with the head thrust out"] = function()
		assert(PetRig.cue(CFG, "stormroar", CFG.ROAR_BURST) and PetRig.cue(CFG, "firebreath", CFG.ROAR_BURST), "no effect cue with the lunge")
		local function at(names: { string }, kind: string, progress: number): { [string]: PetRig.Angles }
			return poseAt(names, { time = 0, phase = 0, moving = 0, fidget = kind, fidgetProgress = progress })
		end
		local HYDRA = { "Pelvis", "Spine_0" }
		for head = 0, 2 do
			table.insert(HYDRA, `Hydra_{head}_3`)
			table.insert(HYDRA, `Jaw_{head}`)
		end
		local rear = at(HYDRA, "stormroar", 0.25)
		assert(rear["hydra:0:3"].x < -math.rad(5), "the heads don't rear back")
		assert(math.abs(rear["hydra:0:3"].x - rear["hydra:2:3"].x) > math.rad(2), "the heads roar at once instead of rippling")
		assert(at(HYDRA, "stormroar", 0.55)["jaw:1"].x < -math.rad(25), "the jaws don't gape")

		local REX = { "Pelvis", "Spine_0", "Neck", "Head_0", "Jaw_0", "Tail_0", "0_Left_Limb_0", "0_Right_Limb_0" }
		local breathing = at(REX, "firebreath", 0.7)
		assert(breathing["jaw:0"].x < -math.rad(25), "the mouth isn't open while breathing fire")
		assert(breathing["head:0"].x > math.rad(3), "the head isn't thrust forward while breathing fire")
		assert(at(REX, "firebreath", 0.25)["head:0"].x < -math.rad(5), "no rear back before the breath")
		assertBounded(breathing, "fire breath")
	end,

	["two-legged rigs stretch by leaning back with their arms up; tails can swish smaller; stomps land with a cue"] = function()
		local BIPED = { "Pelvis", "Spine_0", "Neck", "Head_0", "0_Left_Limb_0", "0_Right_Limb_0", "Arm_Left_0", "Arm_Right_0", "Tail_0", "Tail_1" }
		local function at(state: PetRig.State): { [string]: PetRig.Angles }
			return poseAt(BIPED, state)
		end
		local rest = at({ time = 0, phase = 0, moving = 0, fidget = "look", fidgetProgress = 0 })
		local stretch = at({ time = 0, phase = 0, moving = 0, fidget = "stretch", fidgetProgress = 0.5 })
		expect.near(stretch["leg:0:Left:0"].x, rest["leg:0:Left:0"].x, 1e-9, "a two-legged stretch kicks its legs")
		assert(stretch["spine:0"].x < rest["spine:0"].x - math.rad(5), "a two-legged stretch doesn't lean back")
		assert(stretch["arm:Left:0"].x > rest["arm:Left:0"].x + math.rad(20), "a two-legged stretch doesn't lift its arms")
		assertBounded(stretch, "two-legged stretch")

		local full = at({ time = 0.3, phase = 0, moving = 0, fidget = nil, fidgetProgress = 0, tailPhase = 1 })
		local small = at({ time = 0.3, phase = 0, moving = 0, fidget = nil, fidgetProgress = 0, tailPhase = 1, tailAmount = 0.5 })
		expect.near(small["tail:1"].y, full["tail:1"].y * 0.5, 1e-9, "tailAmount doesn't scale the swish")

		assert(PetRig.cue(CFG, "stomp", 0.96) and not PetRig.cue(CFG, "stomp", 0.5), "a stomp's dust goes off as it lands")
	end,

	["sea otters sit up to groom and crack shells with their front paws, and roll over; swimmers don't walk-twist; sneezes snap; kung fu alternates arms"] = function()
		assert(PetRig.cue(CFG, "shellcrack", 0.25) and not PetRig.cue(CFG, "shellcrack", 0.1), "the taps start with the first one")
		assert(PetRig.cue(CFG, "roll", 0.5) and not PetRig.cue(CFG, "roll", 0.3), "the dust goes with the roll")
		local OTTER = { "Pelvis", "Spine_0", "Spine_1", "Neck", "Head_0", "Tail_0",
			"0_Left_Limb_0", "0_Left_Limb_1", "0_Right_Limb_0", "0_Right_Limb_1", "1_Left_Limb_0", "1_Left_Limb_1", "1_Right_Limb_0", "1_Right_Limb_1" }
		local function otterAt(kind: string, progress: number): { [string]: PetRig.Angles }
			return poseAt(OTTER, { time = 0, phase = 0, moving = 0, fidget = kind, fidgetProgress = progress })
		end
		local rest = otterAt("look", 0)
		local groom = otterAt("groom", 0.5)
		assert(groom["leg:0:Left:0"].x - rest["leg:0:Left:0"].x > math.rad(30) and groom["leg:0:Right:0"].x - rest["leg:0:Right:0"].x > math.rad(30),
			"the front paws don't come up to the face")
		-- Positive x tips a bone's front end up: the hips pitch the whole front up, the hind legs turn back to stay planted
		assert(groom["pelvis:0"].x > rest["pelvis:0"].x + math.rad(30), "it doesn't sit right up on its hips to groom")
		assert(groom["spine:0"].x >= rest["spine:0"].x, "the spine pulls the front back down")
		assert(groom["leg:1:Left:0"].x < rest["leg:1:Left:0"].x - math.rad(30), "the hind legs don't turn back to stay planted")
		assertBounded(groom, "grooming")
		local lowest, highest = math.huge, -math.huge
		for step = 4, 16 do
			local lift = otterAt("shellcrack", step / 20)["leg:0:Right:0"].x
			lowest, highest = math.min(lowest, lift), math.max(highest, lift)
		end
		assert(highest - lowest > math.rad(12), "the front paws don't tap the shell")
		assert(otterAt("shellcrack", 0.5)["head:0"].x > rest["head:0"].x, "it doesn't look down at its shell")
		assertBounded(otterAt("shellcrack", 0.3), "shell cracking")
		local half = PetRig.body(CFG, "roll", 0.5, 1, true)
		expect.near(math.abs(half.roll), math.pi, 1e-6, "halfway through a roll it isn't on its back")
		expect.near(PetRig.body(CFG, "roll", 1, 1, true).roll, math.pi * 2, 1e-6, "a roll doesn't come all the way round")

		local BIPED = { "Pelvis", "Spine_0", "Neck", "Head_0", "0_Left_Limb_0", "0_Right_Limb_0", "Tail_0" }
		local function swimming(phase: number): { [string]: PetRig.Angles }
			return poseAt(BIPED, { time = 1, phase = phase, moving = 1, fidget = nil, fidgetProgress = 0, undulate = "swim", swimPhase = 0.4 })
		end
		expect.near(swimming(0.3)["pelvis:0"].y, swimming(1.9)["pelvis:0"].y, 1e-9, "a swimmer's hips twist with a walking stride")

		local function at(names: { string }, kind: string, progress: number): { [string]: PetRig.Angles }
			return poseAt(names, { time = 0, phase = 0, moving = 0, fidget = kind, fidgetProgress = progress,
				armDrop = { Left = math.rad(70), Right = math.rad(70) } })
		end
		assert(PetRig.cue(CFG, "sneeze", CFG.ROAR_BURST) and not PetRig.cue(CFG, "sneeze", 0.1), "the sneeze fires with the snap forward")
		assert(PetRig.cue(CFG, "kungfu", 0.3) and not PetRig.cue(CFG, "kungfu", 0.1), "the leaves fly with the first chop")

		local DOG = { "Pelvis", "Spine_0", "Neck", "Head_0", "Jaw_0", "Tail_0", "0_Left_Limb_0", "0_Right_Limb_0", "1_Left_Limb_0", "1_Right_Limb_0" }
		assert(at(DOG, "sneeze", 0.25)["head:0"].x < -math.rad(5), "no rear back before the sneeze")
		assert(at(DOG, "sneeze", 0.55)["head:0"].x > math.rad(3), "no snap forward for the sneeze")

		local MANTIS = { "Pelvis", "Spine_0", "Spine_1", "Neck", "Head_0", "Arm_Left_0", "Arm_Left_1", "Arm_Right_0", "Arm_Right_1",
			"0_Left_Limb_0", "0_Right_Limb_0", "1_Left_Limb_0", "1_Right_Limb_0", "Tail_0" }
		local mantisRest = at(MANTIS, "look", 0)
		local strikes = {}
		for step = 0, 20 do
			local pose = at(MANTIS, "kungfu", step / 20)
			strikes[step] = { right = pose["arm:Right:0"].x - mantisRest["arm:Right:0"].x, left = pose["arm:Left:0"].x - mantisRest["arm:Left:0"].x }
			assertBounded(pose, "kung fu")
		end
		local rightFirst, leftFirst = false, false
		for _, strike in strikes do
			rightFirst = rightFirst or (strike.right > math.rad(30) and strike.left < math.rad(10))
			leftFirst = leftFirst or (strike.left > math.rad(30) and strike.right < math.rad(10))
		end
		assert(rightFirst and leftFirst, "the arms don't chop one after the other")
	end,

	["a cape billows back when running and flutters standing; a volt charge raises both fists"] = function()
		local cape = PetRig.role("Cape_1")
		assert(cape and cape.kind == "cape" and cape.segment == 1, "Cape_1 is the cape's second bone")
		local HERO = { "Pelvis", "Spine_0", "Spine_1", "Neck", "Head_0", "Arm_Left_0", "Arm_Right_0", "0_Left_Limb_0", "0_Right_Limb_0",
			"Cape_0", "Cape_1", "Cape_2", "Tail_0" }
		local standing, running = poseAt(HERO, still(1.2)), poseAt(HERO, walking(1.2))
		-- Negative x swings a hanging bone's lower end back, behind the body
		assert(running["cape:0"].x < standing["cape:0"].x - math.rad(15), "the cape doesn't billow back when running")
		local a, b = poseAt(HERO, still(0.3)), poseAt(HERO, still(1.1))
		assert(math.abs(a["cape:2"].x - b["cape:2"].x) > math.rad(1), "the cape doesn't flutter standing")
		assertBounded(running, "billowing cape")

		assert(PetRig.cue(CFG, "voltcharge", 0.2) and not PetRig.cue(CFG, "voltcharge", 0.05), "the lightning starts once the fists are up")
		local charge = poseAt(HERO, { time = 0, phase = 0, moving = 0, fidget = "voltcharge", fidgetProgress = 0.5,
			armDrop = { Left = math.rad(70), Right = math.rad(70) } })
		local rest = poseAt(HERO, { time = 0, phase = 0, moving = 0, fidget = "look", fidgetProgress = 0, armDrop = { Left = math.rad(70), Right = math.rad(70) } })
		for _, side in { "Left", "Right" } do
			assert(charge[`arm:{side}:0`].x - rest[`arm:{side}:0`].x > math.rad(40), `the {side} fist doesn't come up`)
		end
		assertBounded(charge, "volt charge")
	end,

	["nine tails each sway on their own beat and fan out, and count as a tail for the hips"] = function()
		local role = PetRig.role("Tails_4_2")
		assert(role and role.kind == "tails" and role.pair == 4 and role.segment == 2, "Tails_4_2 is the third bone of tail 4")
		local KITSUNE = { "Pelvis", "Spine_0", "Neck", "Head_0", "0_Left_Limb_0", "0_Right_Limb_0", "1_Left_Limb_0", "1_Right_Limb_0" }
		for tail = 0, 8 do
			for segment = 0, 2 do
				table.insert(KITSUNE, `Tails_{tail}_{segment}`)
			end
		end
		local function at(wag: number): { [string]: PetRig.Angles }
			return poseAt(KITSUNE, { time = 0.5, phase = 0, moving = 0, fidget = nil, fidgetProgress = 0, tailPhase = wag })
		end
		local lowest, highest, inStep = math.huge, -math.huge, true
		for step = 0, 15 do
			local pose = at(step / 16 * math.pi * 2)
			lowest, highest = math.min(lowest, pose["tails:4:1"].y), math.max(highest, pose["tails:4:1"].y)
			inStep = inStep and math.abs(pose["tails:0:1"].y - pose["tails:8:1"].y) < math.rad(3)
			expect.near(pose["pelvis:0"].y, 0, 1e-9, "a kitsune's hips wag like a tailless pet")
			assertBounded(pose, "nine tails")
		end
		assert(highest - lowest > math.rad(10), "the tails don't sway")
		assert(not inStep, "the tails sway in step")
	end,

	["an eclipse sits up and looks to the sky, a backflip goes all the way over, solar roars ripple"] = function()
		assert(PetRig.cue(CFG, "eclipse", 0.3) and not PetRig.cue(CFG, "eclipse", 0.1), "the eclipse rises once it's sitting up")
		assert(PetRig.cue(CFG, "backflip", 0.15) and not PetRig.cue(CFG, "backflip", 0.05), "the smoke goes as it takes off")
		assert(PetRig.cue(CFG, "solarroar", CFG.ROAR_BURST), "the solar fire goes with the lunge")
		local FOX = { "Pelvis", "Spine_0", "Spine_1", "Neck", "Head_0", "Tail_0", "Tail_1",
			"0_Left_Limb_0", "0_Right_Limb_0", "1_Left_Limb_0", "1_Left_Limb_1", "1_Right_Limb_0", "1_Right_Limb_1" }
		local rest = poseAt(FOX, still(0))
		local gazing = poseAt(FOX, { time = 0, phase = 0, moving = 0, fidget = "eclipse", fidgetProgress = 0.5 })
		assert(gazing["pelvis:0"].x > rest["pelvis:0"].x + math.rad(10), "it doesn't sit back for the eclipse")
		assert(gazing["head:0"].x < rest["head:0"].x - math.rad(10), "it doesn't look up at the sky")
		assertBounded(gazing, "eclipse")

		local top = PetRig.body(CFG, "backflip", 0.5, 1, true)
		assert(top.lift > CFG.BACKFLIP_HEIGHT * 0.8, "the backflip doesn't leave the ground")
		-- Positive pitch rears back (nose up), so a backflip turns all the way round the positive way
		assert(PetRig.body(CFG, "backflip", 0.3, 1, true).pitch > 0, "the flip goes forwards, not backwards")
		expect.near(PetRig.body(CFG, "backflip", 1, 1, true).pitch, math.pi * 2, 1e-6, "the backflip doesn't land the right way up")
		expect.near(PetRig.body(CFG, "backflip", 1, 1, true).lift, 0, 1e-6, "the backflip doesn't land")

		local HYDRA = { "Pelvis", "Spine_0" }
		for head = 0, 2 do
			table.insert(HYDRA, `Hydra_{head}_3`)
			table.insert(HYDRA, `Jaw_{head}`)
		end
		local roar = poseAt(HYDRA, { time = 0, phase = 0, moving = 0, fidget = "solarroar", fidgetProgress = 0.25 })
		assert(roar["hydra:0:3"].x < -math.rad(5) and math.abs(roar["hydra:0:3"].x - roar["hydra:2:3"].x) > math.rad(2), "the solar roar doesn't ripple")
	end,

	["two-legged walks twist the hips with the stride and the shoulders against them"] = function()
		local BIPED = { "Pelvis", "Spine_0", "Spine_1", "Neck", "Head_0", "0_Left_Limb_0", "0_Right_Limb_0", "Arm_Left_0", "Arm_Right_0" }
		local step = poseAt(BIPED, walking(math.pi / 2))
		assert(step["pelvis:0"].y * step["leg:0:Left:0"].x < 0, "the hips don't turn with the forward leg")
		assert(math.abs(step["pelvis:0"].z) > math.rad(1), "no weight shift onto the standing leg")
		local shoulders = step["pelvis:0"].y + step["spine:0"].y + step["spine:1"].y
		assert(shoulders * step["pelvis:0"].y < 0, "the shoulders don't turn against the hips")
		local head = shoulders + step["neck:0"].y + step["head:0"].y
		assert(math.abs(head) < math.rad(1), "the head doesn't stay facing ahead")
		assertBounded(step, "two-legged walk")
	end,

	["tailless two-legged rigs sway their weight slowly instead of wagging their hips"] = function()
		local BIPED = { "Pelvis", "Spine_0", "Neck", "Head_0", "0_Left_Limb_0", "0_Right_Limb_0" }
		local most, changes = 0, 0
		local last = nil
		for step = 0, 40 do
			local pose = poseAt(BIPED, still(step * 0.1))
			most = math.max(most, math.abs(pose["pelvis:0"].y))
			if last then
				changes = math.max(changes, math.abs(pose["pelvis:0"].z - last))
			end
			last = pose["pelvis:0"].z
		end
		assert(most < 1e-9, "the hips still wag")
		assert(changes > 0 and changes < math.rad(0.5), "the weight sway is missing or too quick")
		local tailless = poseAt({ "Pelvis", "Spine_0", "0_Left_Limb_0", "0_Right_Limb_0", "1_Left_Limb_0", "1_Right_Limb_0" }, still(0.3))
		assert(math.abs(tailless["pelvis:0"].y) > 0, "four-legged pets without tail bones stopped swishing their hips")
	end,

	["hydra necks sway each on their own, jaws snap and open wide on a yawn"] = function()
		local neck = PetRig.role("Hydra_3_2")
		assert(neck and neck.kind == "hydra" and neck.pair == 3 and neck.segment == 2, "Hydra_3_2 is the third bone of head 3")
		local jaw = PetRig.role("Jaw_4")
		assert(jaw and jaw.kind == "jaw" and jaw.pair == 4, "Jaw_4 is head 4's jaw")
		local HYDRA = { "Pelvis", "Spine_0", "Spine_1" }
		for head = 0, 2 do
			for segment = 0, 3 do
				table.insert(HYDRA, `Hydra_{head}_{segment}`)
			end
			table.insert(HYDRA, `Jaw_{head}`)
		end
		local a = poseAt(HYDRA, still(0.7))
		local b = poseAt(HYDRA, still(1.9))
		assert(math.abs(a["hydra:1:1"].y - b["hydra:1:1"].y) > math.rad(3), "the necks don't sway")
		assert(math.abs(a["hydra:1:1"].y - a["hydra:2:1"].y) > math.rad(2), "the heads sway in step")
		assertBounded(a, "hydra standing")
		local widest, shut = 0, 0
		for step = 0, 80 do
			local x = poseAt(HYDRA, still(step * 0.1))["jaw:1"].x
			widest, shut = math.min(widest, x), math.max(shut, x)
		end
		assert(widest < -math.rad(10), "the jaw never opens")
		assert(shut > -math.rad(2), "the jaw never closes")
		local yawn = poseAt(HYDRA, { time = 0, phase = 0, moving = 0, fidget = "yawn", fidgetProgress = 0.5 })
		assert(yawn["jaw:1"].x < widest - math.rad(5), "a yawn doesn't open the jaws wide")
		local look = poseAt(HYDRA, { time = 0, phase = 0, moving = 0, fidget = "look", fidgetProgress = 0.5, side = 1 })
		local rest = poseAt(HYDRA, still(0))
		for head = 0, 2 do
			assert(look[`hydra:{head}:0`].y - rest[`hydra:{head}:0`].y > math.rad(4), `head {head} doesn't look round`)
		end
		assertBounded(yawn, "hydra yawning")
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
