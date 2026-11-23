--!strict
-- Petting Pish or Chikin (owner 2026-11-23, mockup A: "when players pet pish and chikin they should get a noticeable
-- popup that they got a notification"): the popup's words from each dog's own numbers, and the bubble when petted again
-- too soon
local PetRewardRules = require("../src/shared/Util/PetRewardRules")
local PetReward = require("../src/shared/Config/PetReward")
local Pish = require("../src/shared/Config/Pish")
local Chikin = require("../src/shared/Config/Chikin")
local expect = require("./lib/expect")

return {
	["Pish's popup says what his luck does, from his own numbers"] = function()
		local words = PetRewardRules.words("Pish", PetReward, Pish.LUCK, Chikin.COURAGE)
		assert(words, "Pish has words")
		expect.equal(words.title, "Pish's Luck!")
		expect.equal(words.line, "Better pulls for " .. PetRewardRules.duration(Pish.LUCK.seconds))
		expect.equal(words.chip, `{Pish.LUCK.fromRarity} and up: +{math.floor(Pish.LUCK.boost * 100 + 0.5)}% chance`)
	end,

	["Chikin's popup says what his courage does"] = function()
		local words = PetRewardRules.words("Chikin", PetReward, Pish.LUCK, Chikin.COURAGE)
		assert(words, "Chikin has words")
		expect.equal(words.title, "Chikin's Courage!")
		expect.equal(words.line, "Your creatures hit harder for " .. PetRewardRules.duration(Chikin.COURAGE.seconds))
		expect.equal(words.chip, `+{math.floor(Chikin.COURAGE.share * 100 + 0.5)}% damage in every fight`)
		expect.isNil(PetRewardRules.words("Turts", PetReward, Pish.LUCK, Chikin.COURAGE), "no popup for a dog without a buff")
	end,

	["how long a buff lasts, in plain words"] = function()
		expect.equal(PetRewardRules.duration(180), "3 minutes")
		expect.equal(PetRewardRules.duration(60), "1 minute")
		expect.equal(PetRewardRules.duration(45), "45 seconds")
		expect.equal(PetRewardRules.duration(90), "90 seconds")
		expect.equal(PetRewardRules.duration(1), "1 second")
	end,

	["petted too soon: the bubble says when, never silent"] = function()
		expect.equal(PetRewardRules.again("Pish", PetReward, 750), "Lucky again in 12:30!")
		expect.equal(PetRewardRules.again("Chikin", PetReward, 45), "Brave again in 0:45!")
		expect.equal(PetRewardRules.again("Pish", PetReward, 0.2), "Lucky again in 0:01!", "a part second rounds up, never 0:00")
		expect.equal(PetRewardRules.again("Pish", PetReward, 3725), "Lucky again in 1:02:05!")
		expect.isNil(PetRewardRules.again("Pish", PetReward, 0), "nothing to wait for")
	end,

	["every line is plain ASCII the game fonts draw (emoji only for the icons)"] = function()
		for dog, style in PetReward.DOGS do
			for _, key in { "title", "line", "chip", "again" } do
				assert(not string.find(style[key], "[\128-\255]"), `{dog}.{key} has a symbol the fonts can't draw`)
			end
		end
	end,
}
