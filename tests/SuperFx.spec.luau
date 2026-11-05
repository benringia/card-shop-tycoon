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
			expect.equal(Combat.SIGNATURES[look.card].windup, SuperFx.TIERS[look.tier].windup, `{id} wind-up`)
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
	-- Found in Studio (Task 4): straight in front of a big creature the close shot sat at the boss, which hid it
	["the close shots stand off to one side, so the target isn't in the way"] = function()
		local origin, facing = { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 1 }
		for _, beat in { "call", "charge" } do
			local eye = SuperFxRules.shot(beat, origin, 10, facing, { x = 0, y = 0, z = 40 }, SuperFx)
			expect.equal(math.abs(eye.x) >= 5, true, `{beat}: off the line to the target`)
			expect.equal(eye.z > 0, true, `{beat}: still in front`)
		end
	end,
}
