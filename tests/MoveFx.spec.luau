--!strict
-- The Pet button moves' looks by grade (spec 2026-11-05-pet-moves-design): Config/MoveFx and Util/MoveFxRules
local MoveFx = require("../src/shared/Config/MoveFx")
local MoveFxRules = require("../src/shared/Util/MoveFxRules")
local Combat = require("../src/shared/Config/Combat")
local Party = require("../src/shared/Config/Party")
local expect = require("./lib/expect")

local GRADES = { "C", "B", "A", "S" }
local MOVES = { "RAIN", "VINES", "ORBS", "CURSE" }

local function pinned(move: string, key: string, values: { any })
	for index, grade in GRADES do
		expect.equal(MoveFx[move][grade][key], values[index], `{move}.{grade}.{key}`)
	end
end

local function assetIds(value: any, path: string)
	if type(value) == "string" then
		assert(string.match(value, "^rbxassetid://%d+$"), `{path} is not an asset id: {value}`)
	elseif type(value) == "table" then
		for key, inner in value do
			assetIds(inner, `{path}.{key}`)
		end
	end
end

return {
	["every move has all four grades"] = function()
		for _, move in MOVES do
			for _, grade in GRADES do
				expect.equal(type(MoveFx[move][grade]), "table", `{move}.{grade}`)
			end
		end
	end,

	-- The owner's rule: the higher the grade, the better the move looks and feels
	["each grade is a step up"] = function()
		for _, move in MOVES do
			local looks = MoveFx[move]
			local growing = 0
			for key, value in looks.C do
				if type(value) == "number" then
					for index = 2, #GRADES do
						local lower, higher = looks[GRADES[index - 1]][key], looks[GRADES[index]][key]
						assert(higher >= lower, `{move}.{key} drops from {GRADES[index - 1]} to {GRADES[index]}`)
					end
					if looks.S[key] > value then
						growing += 1
					end
				elseif type(value) == "boolean" then
					for index = 2, #GRADES do
						local lower, higher = looks[GRADES[index - 1]][key], looks[GRADES[index]][key]
						assert(not lower or higher, `{move}.{key} turns off from {GRADES[index - 1]} to {GRADES[index]}`)
					end
				end
			end
			assert(growing >= 3, `{move}: only {growing} numbers grow from C to S`)
		end
		for index = 2, #GRADES do
			assert(MoveFx.POSE_AMOUNT[GRADES[index]] > MoveFx.POSE_AMOUNT[GRADES[index - 1]], "the motion grows")
			assert(MoveFx.WINDUP[GRADES[index]].glow > MoveFx.WINDUP[GRADES[index - 1]].glow, "the wind-up glow grows")
			assert(MoveFx.WINDUP[GRADES[index]].ring > MoveFx.WINDUP[GRADES[index - 1]].ring, "the wind-up ring grows")
		end
	end,

	["the owner's counts"] = function()
		pinned("VINES", "count", { 2, 3, 4, 5 })
		pinned("VINES", "leaves", { 0, 4, 5, 6 })
		pinned("VINES", "thorns", { 0, 0, 8, 10 })
		pinned("VINES", "blossoms", { 0, 0, 0, 5 })
		pinned("VINES", "dirt", { false, false, true, true })
		pinned("VINES", "crack", { false, false, false, true })
		pinned("ORBS", "arcs", { false, false, true, true })
		pinned("ORBS", "flash", { false, false, false, true })
		pinned("RAIN", "ripple", { false, true, true, true })
		pinned("RAIN", "motes", { false, false, true, true })
		pinned("RAIN", "rings", { false, false, false, true })
		pinned("RAIN", "rainbow", { false, false, false, true })
		pinned("CURSE", "hex", { false, true, true, true })
		pinned("CURSE", "chains", { false, false, true, true })
		pinned("CURSE", "flames", { false, false, false, true })
		pinned("CURSE", "rings", { 1, 1, 2, 3 })
		expect.equal(Combat.ABILITIES.Volt.attacks, 3, "three orbs: one per fast attack")
	end,

	["poses are body poses every creature has"] = function()
		for kind, pose in MoveFx.POSES do
			assert(Party.PET_ANIM.FIDGET_SECONDS[pose], `{kind}'s pose {pose} is not a fight or fidget pose`)
		end
		for _, kind in { "Rain", "Snare", "Overcharge", "Curse" } do
			assert(MoveFx.POSES[kind], `{kind} has a pose`)
		end
	end,

	["no grade or an unknown one plays C; low graphics caps at B"] = function()
		expect.equal(MoveFxRules.grade(nil, true, MoveFx), "C")
		expect.equal(MoveFxRules.grade("Z", true, MoveFx), "C")
		expect.equal(MoveFxRules.grade("S", true, MoveFx), "S")
		expect.equal(MoveFxRules.grade("S", false, MoveFx), "B")
		expect.equal(MoveFxRules.grade("A", false, MoveFx), "B")
		expect.equal(MoveFxRules.grade("B", false, MoveFx), "B")
		expect.equal(MoveFxRules.grade("C", false, MoveFx), "C")
		expect.equal(MoveFxRules.look(MoveFx, "VINES", "S", false), MoveFx.VINES.B, "the look follows the grade")
		expect.equal(MoveFxRules.look(MoveFx, "ORBS", nil, true), MoveFx.ORBS.C)
	end,

	["vines climb round the target"] = function()
		local path = MoveFxRules.vinePath(1, 3, 10, 2, 1.5, 12)
		expect.equal(#path, 13, "steps + 1 points")
		expect.near(path[1].y, 0, 1e-9, "from the ground")
		expect.near(path[13].y, 10, 1e-9, "up to its height")
		for index, point in path do
			expect.near(math.sqrt(point.x * point.x + point.z * point.z), 2, 1e-9, `point {index} round the axis`)
		end
		local other = MoveFxRules.vinePath(2, 3, 10, 2, 1.5, 12)
		local a = math.atan2(path[1].z, path[1].x)
		local b = math.atan2(other[1].z, other[1].x)
		local turn = ((b - a) / (2 * math.pi)) % 1
		expect.near(turn, 1 / 3, 1e-9, "the next vine starts a third of a turn round")
		local last = math.atan2(path[13].z, path[13].x)
		expect.near(((last - a) / (2 * math.pi)) % 1, 0.5, 1e-9, "1.5 turns up the target")
	end,

	["every texture and sound is an asset id"] = function()
		assetIds(MoveFx.TEXTURES, "TEXTURES")
		assetIds(MoveFx.SOUNDS, "SOUNDS")
	end,
}
