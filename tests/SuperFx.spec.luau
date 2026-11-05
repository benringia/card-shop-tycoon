--!strict
-- The super moves' looks (spec 2026-11-05-super-moves-design): ten looks, each a step up from grade C to S, the
-- caster's cinematic beats and camera framing
local SuperFx = require("../src/shared/Config/SuperFx")
local SuperFxRules = require("../src/shared/Util/SuperFxRules")
local Combat = require("../src/shared/Config/Combat")
local CardList = require("../src/shared/Config/CardList")
local expect = require("./lib/expect")

local GRADES = { "C", "B", "A", "S" }

local function rarityOf(card: string): string?
	for _, set in CardList do
		for _, entry in set do
			if entry[1] == card then
				return entry[3]
			end
		end
	end
	return nil
end

local function distance(a: any, b: any): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

local function eachId(value: any, visit: (id: string, path: string) -> (), path: string)
	if typeof(value) == "table" then
		for key, child in value do
			eachId(child, visit, `{path}.{key}`)
		end
	else
		visit(value, path)
	end
end

return {
	["every super has a look, for all four grades"] = function()
		local count = 0
		for _ in SuperFx.LOOKS do
			count += 1
		end
		expect.equal(count, 10, "ten looks")
		for card, ability in Combat.SIGNATURES do
			local look = SuperFx.LOOKS[ability.look]
			assert(look, `{card}: its look {ability.look}`)
			expect.equal(look.card, card, `{ability.look} belongs to {card}`)
			for _, grade in GRADES do
				assert(look.grades[grade], `{ability.look} {grade}`)
			end
		end
	end,

	["a look's tier is its card's rarity, and the sim's wind-up matches"] = function()
		for id, look in SuperFx.LOOKS do
			expect.equal(rarityOf(look.card), look.tier, id)
			assert(SuperFx.TIERS[look.tier], `{id}: tier {look.tier}`)
			expect.equal(Combat.SIGNATURES[look.card].windup, look.windup or SuperFx.TIERS[look.tier].windup, `{id} wind-up`)
		end
	end,

	["each grade is a step up"] = function()
		for id, look in SuperFx.LOOKS do
			local c, s = look.grades.C, look.grades.S
			for _, field in { "scale", "particles", "shake" } do
				for index = 2, #GRADES do
					local lower, higher = look.grades[GRADES[index - 1]][field], look.grades[GRADES[index]][field]
					expect.equal(higher > lower, true, `{id} {field} grows {GRADES[index - 1]} -> {GRADES[index]}`)
				end
			end
			for field, value in c do
				for index = 2, #GRADES do
					local lower, higher = look.grades[GRADES[index - 1]][field], look.grades[GRADES[index]][field]
					if typeof(value) == "number" then
						expect.equal(higher >= lower, true, `{id} {field} never drops`)
					elseif typeof(value) == "boolean" and lower == true then
						expect.equal(higher, true, `{id} {field} once on stays on`)
					end
				end
			end
			expect.equal(s.extra, true, `{id}: S has its extra`)
			for _, grade in { "C", "B", "A" } do
				expect.equal(look.grades[grade].extra, false, `{id}: only S has the extra`)
			end
		end
	end,

	["no grade or an unknown one plays C; low graphics caps at B"] = function()
		expect.equal(SuperFxRules.grade(nil, true, SuperFx), "C")
		expect.equal(SuperFxRules.grade("Z", true, SuperFx), "C")
		expect.equal(SuperFxRules.grade("S", false, SuperFx), "B")
		expect.equal(SuperFxRules.grade("A", false, SuperFx), "B")
		expect.equal(SuperFxRules.grade("C", false, SuperFx), "C")
		expect.equal(SuperFxRules.grade("S", true, SuperFx), "S")
		expect.equal(SuperFxRules.look(SuperFx, "Inferno", "S", false), SuperFx.LOOKS.Inferno.grades.B)
		expect.equal(SuperFxRules.look(SuperFx, "Devour", nil, true), SuperFx.LOOKS.Devour.grades.C)
	end,

	["the beats: the call, the impact at the wind-up's end, control back after the tail"] = function()
		local epic = SuperFxRules.beats("Epic", Combat.SUPER_PROTECT_TAIL, SuperFx)
		expect.near(epic.call, 0.3, 1e-9)
		expect.near(epic.impact, 1.5, 1e-9)
		expect.near(epic.back, 2.1, 1e-9)
		local legendary = SuperFxRules.beats("Legendary", Combat.SUPER_PROTECT_TAIL, SuperFx)
		expect.near(legendary.call, 0.3, 1e-9)
		expect.near(legendary.impact, 2, 1e-9)
		expect.near(legendary.back, 2.6, 1e-9)
	end,

	["the camera frames the creature close, then creature and target together"] = function()
		local origin, facing = { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 1 }
		local eye, focus = SuperFxRules.shot("call", origin, 10, facing, nil, SuperFx)
		expect.equal(eye.z > 0, true, "in front of it")
		expect.equal(distance(eye, origin) <= 30, true, "close")
		expect.equal(distance(focus, origin) <= 10, true, "looking at it")
		local bigEye = SuperFxRules.shot("call", origin, 20, facing, nil, SuperFx)
		expect.near(distance(bigEye, origin), 2 * distance(eye, origin), 1e-6, "a creature twice as tall: twice as far")
		local target = { x = 0, y = 0, z = 40 }
		local wideEye, wideFocus = SuperFxRules.shot("impact", origin, 10, facing, target, SuperFx)
		expect.equal(wideFocus.z > 0 and wideFocus.z < 40, true, "the focus is between them")
		expect.equal(distance(wideEye, origin) > 20 and distance(wideEye, target) > 20, true, "far enough to see both")
		local soloEye = SuperFxRules.shot("impact", origin, 10, facing, nil, SuperFx)
		expect.equal(distance(soloEye, origin) > distance(eye, origin), true, "no target: a wide shot of the creature")
	end,

	["only Legendary has bars, the impact frame and the sky"] = function()
		expect.equal(SuperFx.TIERS.Legendary.bars and SuperFx.TIERS.Legendary.impactFrame and SuperFx.TIERS.Legendary.sky, true)
		expect.equal(SuperFx.TIERS.Epic.bars or SuperFx.TIERS.Epic.impactFrame or SuperFx.TIERS.Epic.sky, false)
	end,

	["every texture and sound is an asset id, and every look has a sound list"] = function()
		for id in SuperFx.LOOKS do
			assert(SuperFx.SOUNDS[id], `{id} sounds`)
		end
		eachId(SuperFx.TEXTURES, function(id, path)
			assert(string.match(id, "^rbxassetid://%d+$"), `TEXTURES{path}`)
		end, "")
		eachId(SuperFx.SOUNDS, function(id, path)
			assert(string.match(id, "^rbxassetid://%d+$"), `SOUNDS{path}`)
		end, "")
	end,
	-- The owner (2026-11-05): "sometimes when cinematic is played the creature gets covered by the player or the boss".
	-- The cinematic picks the side nothing stands on; every shot can go to either side, mirrored
	["the shots can stand off to either side, mirrored across the creature's line"] = function()
		local origin, facing, target = { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 1 }, { x = 0, y = 0, z = 40 }
		for _, beat in { "call", "charge", "impact" } do
			local right = SuperFxRules.shot(beat, origin, 10, facing, target, SuperFx, nil, 1)
			local left = SuperFxRules.shot(beat, origin, 10, facing, target, SuperFx, nil, -1)
			local plain = SuperFxRules.shot(beat, origin, 10, facing, target, SuperFx)
			expect.near(left.x, -right.x, 1e-6, `{beat}: the other side`)
			expect.near(left.z, right.z, 1e-6, `{beat}: as far along`)
			expect.near(left.y, right.y, 1e-6, `{beat}: as high`)
			expect.near(plain.x, right.x, 1e-6, `{beat}: the first side by default`)
			expect.equal(math.abs(right.x) > 1, true, `{beat}: off the line`)
		end
	end,

	-- What stands between the camera and the creature (a body's bounding box, in its own space) gets faded
	["a sight line crossing a body's box, or not"] = function()
		local half = { x = 1, y = 2, z = 1 }
		local function v(x: number, y: number, z: number): any
			return { x = x, y = y, z = z }
		end
		expect.equal(SuperFxRules.segmentHitsBox(v(-5, 0, 0), v(5, 0, 0), half), true, "straight through")
		expect.equal(SuperFxRules.segmentHitsBox(v(-5, 3, 0), v(5, 3, 0), half), false, "over the top")
		expect.equal(SuperFxRules.segmentHitsBox(v(-5, 0, 0), v(-2, 0, 0), half), false, "stops short of it")
		expect.equal(SuperFxRules.segmentHitsBox(v(0, 0, 0), v(9, 9, 9), half), true, "starts inside it")
		expect.equal(SuperFxRules.segmentHitsBox(v(-5, 0, 3), v(5, 0, 3), half), false, "passes beside")
		expect.equal(SuperFxRules.segmentHitsBox(v(0.5, -9, 0.5), v(0.5, 9, 0.5), half), true, "straight down through it")
	end,

	-- Found in Studio (Task 4): straight in front of a big creature the close shot sat at the boss, which hid it
	["the close shots stand off to one side, so the target isn't in the way"] = function()
		local origin, facing = { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 1 }
		for _, beat in { "call", "charge" } do
			local eye = SuperFxRules.shot(beat, origin, 10, facing, { x = 0, y = 0, z = 40 }, SuperFx)
			expect.equal(math.abs(eye.x) >= 5, true, `{beat}: off the line to the target`)
			expect.equal(eye.z > 0, true, `{beat}: still in front`)
		end
	end,
	-- Legendary looks change the sky on the caster's screen, each its own way (spec: Supernova's deep space, Devour's
	-- dimmed world, Thunderstorm's storm, Tidal Blessing's clouds parting)
	["every Legendary look has its own sky grade, and only Legendary looks have one"] = function()
		for id, look in SuperFx.LOOKS do
			if look.tier == "Legendary" then
				assert(look.sky, `{id}: its sky`)
				assert(typeof(look.sky.brightness) == "number" and typeof(look.sky.saturation) == "number", `{id}: brightness and saturation`)
				expect.equal(#look.sky.tint, 3, `{id}: an rgb tint`)
			else
				expect.isNil(look.sky, `{id}: Epic looks leave the sky alone`)
			end
		end
	end,

	-- The owner (2026-11-05): Supernova was "really quick. sun grows, rises up, then explodes. dont rush the animations"
	["Supernova takes its time: the sun grows, rises, then swells before it bursts"] = function()
		local look = SuperFx.LOOKS.Supernova
		expect.equal(look.windup >= 3, true, "a longer wind-up than the Legendary 2 s")
		expect.equal(Combat.SIGNATURES.Solarion.windup, look.windup, "the sim lands it then")
		local grow = look.windup * look.timing.grow
		local rise = look.windup * look.timing.rise
		local swell = look.windup - grow - rise
		expect.equal(grow >= 1.2 and rise >= 1.2, true, "a second or more to grow and to rise")
		expect.equal(swell >= 0.4, true, "a beat hanging over the boss before it bursts")
		expect.equal(Combat.SIGNATURES.Stormking.windup, SuperFx.TIERS.Legendary.windup, "Thunderstorm keeps its own pace")
	end,

	["Supernova's S plays two impact frames, every other grade one"] = function()
		for _, grade in GRADES do
			local frames = SuperFx.LOOKS.Supernova.grades[grade].impactFrames
			expect.equal(frames, if grade == "S" then 2 else 1, grade)
		end
	end,
	-- Every look has its own layered sounds (spec "Sound"): a call, a charge, the impact and a layer for A and S; what
	-- lasts on the field its linger, the shields a hit and a burst, Rift Step a blink
	["every look has its sounds"] = function()
		for id in SuperFx.LOOKS do
			local sounds = SuperFx.SOUNDS[id]
			for _, moment in { "call", "charge", "impact", "layer" } do
				assert(sounds[moment], `{id}: {moment}`)
			end
		end
		for _, id in { "Inferno", "MagmaSlam", "TidalBlessing", "Stampede", "Eclipse", "Supernova", "Thunderstorm", "Devour" } do
			assert(SuperFx.SOUNDS[id].linger, `{id}: linger`)
		end
		assert(SuperFx.SOUNDS.TidalShield.hit and SuperFx.SOUNDS.TidalShield.burst, "TidalShield: hit and burst")
		assert(SuperFx.SOUNDS.TidalBlessing.revive and SuperFx.SOUNDS.TidalBlessing.heal, "TidalBlessing: revive and heal")
		assert(SuperFx.SOUNDS.RiftStep.blink and SuperFx.SOUNDS.RiftStep.slash, "RiftStep: blink and slash")
	end,
	-- The owner (2026-11-05, option C "Blink Barrage"): Rift Step blinks round the boss, a hit from each rift
	["Rift Step's rifts ring the boss, the first behind it, then side to side"] = function()
		local caster = { x = 0, y = 0, z = 0 }
		local boss = { x = 0, y = 2, z = -20 }
		local spots = SuperFxRules.riftSpots(caster, boss, 4, 6)
		expect.equal(#spots, 4, "one rift a hit")
		for index, spot in spots do
			expect.near(math.sqrt((spot.x - boss.x) ^ 2 + (spot.z - boss.z) ^ 2), 6, 1e-6, `rift {index}: round the boss`)
			expect.equal(spot.y, boss.y, `rift {index}: at the boss's height`)
		end
		expect.equal(spots[1].z < boss.z - 5, true, "the first behind the boss (away from the caster)")
		expect.equal(spots[2].x * spots[3].x < 0, true, "then one side, then the other")
		expect.equal(spots[4].z > boss.z + 5, true, "the last in front")
		expect.equal(#SuperFxRules.riftSpots(caster, boss, 6, 6), 6, "any number of hits")
		local same = SuperFxRules.riftSpots(boss, boss, 4, 6)
		expect.equal(#same, 4, "a caster on top of the boss still gets its rifts")
	end,

	-- Final review: the dome's burst never played (a "shieldGone" has no `from`) and in boss and wild fights the dome's
	-- ripples and the dodge puffs never played (the monster's hits went down another path). What an event means for the
	-- lasting looks is read first, whoever sent it.
	-- Owner 2026-11-05: Tidal Shield wards every ally, each its own bubble (a ward breaking or running out names whose)
	["what an event means for the lasting looks, whoever sent it"] = function()
		local gone = SuperFxRules.decorations({ type = "shieldGone", to = "a:@1" })
		expect.equal(gone.gone, "a:@1", "a ward running out, with no sender: whose")
		expect.isNil(SuperFxRules.decorations({ type = "shieldGone", side = "b" }).gone, "a side's shield has no bubble")
		local soaked = SuperFxRules.decorations({ type = "attack", from = "b:m", to = "a:p1", damage = 3, absorbed = 40 })
		expect.equal(soaked.soaked, "a:p1", "a boss's hit a ward soaked: whose bubble ripples")
		local dodged = SuperFxRules.decorations({ type = "attack", from = "b:m", to = "a:p1", damage = 0, dodged = true })
		expect.equal(dodged.dodged, "a:p1", "a boss's hit passing through a dodging super")
		local plain = SuperFxRules.decorations({ type = "attack", from = "b:m", to = "a:p1", damage = 9 })
		expect.isNil(plain.gone)
		expect.isNil(plain.soaked)
		expect.isNil(plain.dodged)
		expect.isNil(SuperFxRules.decorations({ type = "shieldGone", to = 5 }).gone, "only a fighter id")
		expect.isNil(SuperFxRules.decorations("junk" :: any).gone)
	end,
	-- Owner 2026-11-05: Inferno and Magma Slam leap high to wind up (the others crouch), and every super's big moment
	-- shakes harder than a Pet button move
	["Inferno and Magma Slam leap to wind up; supers shake harder than Pet moves"] = function()
		expect.equal(SuperFx.LOOKS.Inferno.windupPose, "leap")
		expect.equal(SuperFx.LOOKS.MagmaSlam.windupPose, "leap")
		for id, made in SuperFx.LOOKS do
			if id ~= "Inferno" and id ~= "MagmaSlam" and id ~= "Eclipse" then
				expect.isNil(made.windupPose, id)
			end
		end
		local AttackFx = require("../src/shared/Config/AttackFx")
		assert(AttackFx.SHAKE.super > AttackFx.SHAKE.special, "a super shakes harder than a Pet move")
	end,
	-- Studio check (owner 2026-11-05 "make the ball rise then explode"): the low charge shot never showed Supernova's
	-- sun, over its hands or risen over the boss. A look that bursts in the sky frames the burst point too.
	["Supernova bursts in the sky, and its charge and impact shots keep the sky in frame"] = function()
		for _, grade in GRADES do
			local burst = SuperFx.LOOKS.Supernova.grades[grade].burst
			expect.equal(typeof(burst) == "number" and burst >= 12, true, `{grade}: studs over the target`)
		end
		local origin, facing = { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 1 }
		local target = { x = 0, y = 5, z = 30 }
		local sky = { x = 0, y = 5 + SuperFx.LOOKS.Supernova.grades.S.burst, z = 30 }
		local half = math.rad(SuperFx.CAMERA.fov / 2)
		local function inFrame(eye: any, focus: any, point: any): boolean
			local a = { x = focus.x - eye.x, y = focus.y - eye.y, z = focus.z - eye.z }
			local b = { x = point.x - eye.x, y = point.y - eye.y, z = point.z - eye.z }
			local cos = (a.x * b.x + a.y * b.y + a.z * b.z) / (distance(eye, focus) * distance(eye, point))
			return math.acos(math.clamp(cos, -1, 1)) <= half
		end
		for _, beat in { "charge", "impact" } do
			local plainEye, plainFocus = SuperFxRules.shot(beat, origin, 10, facing, target, SuperFx)
			local eye, focus = SuperFxRules.shot(beat, origin, 10, facing, target, SuperFx, sky)
			expect.equal(inFrame(eye, focus, sky), true, `{beat}: the burst point in frame`)
			expect.equal(inFrame(eye, focus, plainFocus), true, `{beat}: what it framed before still in frame`)
			expect.equal(focus.y > plainFocus.y, true, `{beat}: it looks up`)
			expect.equal(distance(eye, focus) >= distance(plainEye, plainFocus), true, `{beat}: never closer`)
		end
		local callEye = SuperFxRules.shot("call", origin, 10, facing, target, SuperFx, sky)
		local plainCall = SuperFxRules.shot("call", origin, 10, facing, target, SuperFx)
		expect.near(distance(callEye, plainCall), 0, 1e-9, "the call's close-up is unchanged")
	end,
	-- Owner 2026-11-05: "Eclipse: creature stands still, Pentagram appears underneath it then every move from this
	-- creature has a mirror image for 5 seconds evading everything while glowing dark purple"
	["Eclipse winds up standing still over a star sigil, then mirror images: one, two at S"] = function()
		local eclipse = SuperFx.LOOKS.Eclipse
		expect.equal(eclipse.windupPose, "still")
		for index, grade in GRADES do
			local g = eclipse.grades[grade]
			expect.equal(g.mirrors, if grade == "S" then 2 else 1, `{grade}: mirror images`)
			expect.equal(typeof(g.sigil) == "number" and g.sigil > 0, true, `{grade}: the sigil's size`)
			if index > 1 then
				expect.equal(g.sigil > eclipse.grades[GRADES[index - 1]].sigil, true, `{grade}: a bigger sigil`)
			end
		end
	end,
}
