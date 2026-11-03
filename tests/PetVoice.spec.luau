--!strict
local PetVoice = require("../src/shared/Util/PetVoice")
local Party = require("../src/shared/Config/Party")
local expect = require("./lib/expect")

local CFG = {
	small = { "chirpA", "chirpB" },
	big = { "huff" },
	bigRarities = { Epic = true, Legendary = true },
	every = { 18, 40 },
	pitch = { min = 0.6, max = 1.35, vary = 0.08, power = 0.4 },
	bounce = 0.08,
}

return {
	["small creatures chirp, Epics and Legendaries huff, and each keeps its own voice"] = function()
		expect.equal(PetVoice.voice("Common", 0, CFG), "chirpA")
		expect.equal(PetVoice.voice("Common", 1, CFG), "chirpB")
		expect.equal(PetVoice.voice("Rare", 7, CFG), PetVoice.voice("Rare", 7, CFG), "same seed, same voice")
		expect.equal(PetVoice.voice("Epic", 3, CFG), "huff")
		expect.equal(PetVoice.voice("Legendary", 0, CFG), "huff")
	end,

	["the next chirp comes 18-40 s later"] = function()
		expect.equal(PetVoice.nextChirp(0, CFG), 18)
		expect.equal(PetVoice.nextChirp(1, CFG), 40)
		expect.equal(PetVoice.nextChirp(0.5, CFG), 29)
		expect.equal(PetVoice.nextChirp(7, CFG), 40, "a roll out of range is clamped")
	end,

	["bigger creatures sound lower, within the pitch limits"] = function()
		expect.near(PetVoice.pitch(3, 3, 0.5, CFG), 1, 1e-9, "base height, middle roll: as recorded")
		expect.equal(PetVoice.pitch(6, 3, 0.5, CFG) < 1, true, "twice as tall: lower")
		expect.equal(PetVoice.pitch(1.5, 3, 0.5, CFG) > 1, true, "half as tall: higher")
		expect.equal(PetVoice.pitch(100, 3, 0, CFG), 0.6 * 0.92, "never below the minimum (then the wobble)")
		expect.equal(PetVoice.pitch(0.01, 3, 1, CFG), 1.35 * 1.08, "never above the maximum (then the wobble)")
		expect.near(PetVoice.pitch(0, 3, 0.5, CFG), 1.35, 1e-9, "a zero height doesn't divide by zero")
	end,

	["only your own creature chirps, when it's out and about"] = function()
		local free = { mine = true, inFight = false, fainted = false, benched = false, leaving = false }
		expect.equal(PetVoice.isFree(free), true)
		for key in free do
			local state = table.clone(free)
			state[key] = not state[key]
			expect.equal(PetVoice.isFree(state), false, `{key} flipped`)
		end
	end,

	["a chirp gives a little squash-bounce that ends at full size"] = function()
		expect.equal(PetVoice.bounce(0, 0.3, CFG), 1)
		expect.near(PetVoice.bounce(0.15, 0.3, CFG), 1.08, 1e-9, "biggest halfway")
		expect.near(PetVoice.bounce(0.3, 0.3, CFG), 1, 1e-9)
		expect.equal(PetVoice.bounce(5, 0.3, CFG), 1, "after it: full size")
	end,

	["the game's voice settings are sane"] = function()
		local voice = Party.VOICE
		expect.equal(#voice.small > 0 and #voice.big > 0, true)
		for _, id in voice.small do
			expect.equal(string.match(id, "^rbxassetid://%d+$") ~= nil, true, id)
		end
		for _, id in voice.big do
			expect.equal(string.match(id, "^rbxassetid://%d+$") ~= nil, true, id)
		end
		expect.equal(voice.every[1] >= 10 and voice.every[2] > voice.every[1], true, "occasional, not chatty")
		expect.equal(voice.volume > 0 and voice.volume <= 0.5, true, "quiet")
		for _, key in { "summon", "unsummon" } do
			local sound = Party.SUMMON_SOUNDS[key]
			expect.equal(string.match(sound.id, "^rbxassetid://%d+$") ~= nil, true, key)
			expect.equal(sound.volume > 0 and sound.volume <= 1, true, key)
			-- Options for the owner to hear in Studio (/summonsound <n>, /unsummonsound <n>), the current one among them
			local options = Party.SUMMON_SOUNDS.options[key]
			expect.equal(#options >= 3, true, `{key} options`)
			local found = false
			for _, option in options do
				expect.equal(string.match(option.id, "^rbxassetid://%d+$") ~= nil and #option.name > 0, true, option.name)
				expect.equal(option.volume > 0 and option.volume <= 0.3 and option.pitch > 0, true, `{option.name}: quiet`)
				found = found or option.id == sound.id
			end
			expect.equal(found, true, `the current {key} sound is one of the options`)
		end
	end,
}
