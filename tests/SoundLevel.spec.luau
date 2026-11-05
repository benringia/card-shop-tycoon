--!strict
-- Skill sounds brought to one level (owner 2026-11-05: "adjust skill volumes make sure its not too loud"): each
-- sound's measured loudness (Config/SoundLevels) turns the loud ones down, never a quiet one up
local SoundLevel = require("../src/shared/Util/SoundLevel")
local SoundLevels = require("../src/shared/Config/SoundLevels")
local SuperFx = require("../src/shared/Config/SuperFx")
local MoveFx = require("../src/shared/Config/MoveFx")
local expect = require("./lib/expect")

local function eachId(value: any, visit: (id: string, path: string) -> (), path: string)
	if type(value) == "string" then
		visit(value, path)
	elseif type(value) == "table" then
		for key, inner in value do
			eachId(inner, visit, `{path}.{key}`)
		end
	end
end

return {
	["every super move and Pet button move sound has its loudness measured"] = function()
		for name, sounds in { SuperFx = SuperFx.SOUNDS, MoveFx = MoveFx.SOUNDS } do
			eachId(sounds, function(id, path)
				local key = string.match(id, "%d+") :: string
				assert(SoundLevels.LEVELS[key], `{name}{path} ({id}): measure it (tools/audio/measure_loudness)`)
			end, "")
		end
	end,

	["a loud sound is turned down, a quiet one left as it is"] = function()
		local cfg = { TARGET = 100, KNEE = 0.75, LEVELS = { ["1"] = 400, ["2"] = 50, ["3"] = 100 } }
		expect.near(SoundLevel.gain(cfg, "rbxassetid://1"), (100 / 400) ^ 0.75, 1e-9, "four times too loud")
		expect.equal(SoundLevel.gain(cfg, "rbxassetid://2"), 1, "quieter than the target: never turned up")
		expect.equal(SoundLevel.gain(cfg, "rbxassetid://3"), 1, "at the target")
		expect.equal(SoundLevel.gain(cfg, "rbxassetid://9"), 1, "not measured: as it is")
		expect.equal(SoundLevel.gain(cfg, ""), 1, "no sound")
	end,

	["louder stays louder after the turn-down, so big impacts still feel big"] = function()
		local cfg = { TARGET = 100, KNEE = 0.75, LEVELS = { ["1"] = 200, ["2"] = 400 } }
		local a = 200 * SoundLevel.gain(cfg, "rbxassetid://1")
		local b = 400 * SoundLevel.gain(cfg, "rbxassetid://2")
		expect.equal(b > a and a > 100, true, "the order kept, squeezed toward the target")
	end,

	["the real numbers: the loudest skill sounds come down by half or more"] = function()
		expect.equal(SoundLevels.TARGET > 0 and SoundLevels.KNEE > 0 and SoundLevels.KNEE <= 1, true)
		local loudest, gain = 0, 1
		for key, level in SoundLevels.LEVELS do
			if level > loudest then
				loudest, gain = level, SoundLevel.gain(SoundLevels, `rbxassetid://{key}`)
			end
		end
		expect.equal(gain <= 0.5, true, `the loudest ({loudest}) at {gain}`)
	end,
}
