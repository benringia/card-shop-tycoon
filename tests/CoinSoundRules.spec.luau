--!strict
-- The coin sound whenever your cash goes up (owner 2026-11-19: "Add a coin sound effect everytime you earn coin for
-- everything"): only on a rise, once for a burst, never at load, quiet while a reward waits for its own moment
local CoinSoundRules = require("../src/shared/Util/CoinSoundRules")
local CoinSound = require("../src/shared/Config/CoinSound")
local expect = require("./lib/expect")

return {
	["it plays when your cash goes up, not when it goes down or stays"] = function()
		expect.equal(CoinSoundRules.plays(100, 103, 10, nil, 0, CoinSound), true, "+$3: a coin")
		expect.equal(CoinSoundRules.plays(100, 100.1, 10, nil, 0, CoinSound), true, "even a dime")
		expect.equal(CoinSoundRules.plays(100, 52, 10, nil, 0, CoinSound), false, "spending: no coin")
		expect.equal(CoinSoundRules.plays(100, 100, 10, nil, 0, CoinSound), false, "no change")
	end,

	["not when your cash first arrives (joining), nor for junk"] = function()
		expect.equal(CoinSoundRules.plays(nil, 1500, 10, nil, 0, CoinSound), false, "the save loading")
		expect.equal(CoinSoundRules.plays(100, nil, 10, nil, 0, CoinSound), false)
		expect.equal(CoinSoundRules.plays("x" :: any, 5, 10, nil, 0, CoinSound), false)
	end,

	["a burst of earnings sounds once"] = function()
		expect.equal(CoinSoundRules.plays(100, 103, 10 + CoinSound.GAP * 0.5, 10, 0, CoinSound), false, "right after the last one")
		expect.equal(CoinSoundRules.plays(100, 103, 10 + CoinSound.GAP + 0.01, 10, 0, CoinSound), true, "after the gap")
	end,

	["quiet while a reward waits for its own moment (a monster's knockout coins)"] = function()
		expect.equal(CoinSoundRules.plays(100, 136, 10, nil, 12, CoinSound), false, "held until 12")
		expect.equal(CoinSoundRules.plays(100, 136, 12.5, nil, 12, CoinSound), true, "after the hold")
	end,

	["the sound picked by ear, else the default"] = function()
		expect.equal(CoinSoundRules.option(CoinSound, nil), CoinSound.DEFAULT)
		expect.equal(CoinSoundRules.option(CoinSound, 2), 2)
		expect.equal(CoinSoundRules.option(CoinSound, #CoinSound.OPTIONS + 1), CoinSound.DEFAULT, "no such option")
		expect.equal(CoinSoundRules.option(CoinSound, 1.5), CoinSound.DEFAULT, "junk")
		for index, option in CoinSound.OPTIONS do
			expect.equal(string.match(option.id, "^rbxassetid://%d+$") ~= nil, true, `option {index} is an asset id`)
			expect.equal(string.find(option.name, "Pro Sound Effects", 1, true) ~= nil, true, `option {index} is Roblox-licensed`)
		end
	end,
}
