--!strict
local LoadingRules = require("../src/shared/Util/LoadingRules")
local LoadingScreen = require("../src/shared/Config/LoadingScreen")
local CardArt = require("../src/shared/Config/CardArt")
local expect = require("./lib/expect")

local cfg = LoadingScreen

local function status(character: boolean, data: boolean, creature: boolean, gear: boolean, art: boolean?): LoadingRules.Status
	return { character = character, data = data, art = if art == nil then data else art, creature = creature, gear = gear }
end

return {
	["the steps tick off in order: character, save, creature, fight gear"] = function()
		local step, share, done = LoadingRules.progress(status(false, false, false, false), 0, cfg)
		expect.equal(step, 1)
		expect.equal(share, 0)
		expect.equal(done, false)
		step, share = LoadingRules.progress(status(true, false, false, false), 1, cfg)
		expect.equal(step, 2)
		expect.equal(share, 0.25)
		step, share = LoadingRules.progress(status(true, true, true, false), 2, cfg)
		expect.equal(step, 4)
		expect.equal(share, 0.75)
		step, share, done = LoadingRules.progress(status(true, true, true, true), 3, cfg)
		expect.equal(step, 5, "all done")
		expect.equal(share, 1)
		expect.equal(done, true)
	end,

	["a later step done early doesn't jump the bar ahead"] = function()
		local step, share = LoadingRules.progress(status(true, false, true, true), 1, cfg)
		expect.equal(step, 2, "still loading the save")
		expect.equal(share, 0.25)
	end,

	["a slow save gets its note after SLOW_SECONDS"] = function()
		local _, _, _, slow = LoadingRules.progress(status(true, false, false, false), cfg.SLOW_SECONDS - 0.1, cfg)
		expect.equal(slow, false)
		_, _, _, slow = LoadingRules.progress(status(true, false, false, false), cfg.SLOW_SECONDS, cfg)
		expect.equal(slow, true)
		_, _, _, slow = LoadingRules.progress(status(true, true, false, false), cfg.SLOW_SECONDS + 5, cfg)
		expect.equal(slow, false, "the save is in: no note")
	end,

	["nobody waits longer than MAX_SECONDS"] = function()
		expect.equal(cfg.MAX_SECONDS, 30)
		local _, _, done = LoadingRules.progress(status(false, false, false, false), cfg.MAX_SECONDS - 0.1, cfg)
		expect.equal(done, false)
		_, _, done = LoadingRules.progress(status(false, false, false, false), cfg.MAX_SECONDS, cfg)
		expect.equal(done, true)
	end,

	["every step has its words, the first one per place"] = function()
		expect.equal(#cfg.STEPS, 4)
		for _, kind in { "Main", "Frontier", "Dungeon" } do
			expect.equal(typeof(LoadingRules.stepText(1, kind, cfg)), "string", kind)
		end
		expect.equal(LoadingRules.stepText(1, "Main", cfg), cfg.FIRST_STEP.Main)
		expect.equal(LoadingRules.stepText(3, "Main", cfg), cfg.STEPS[3])
		expect.equal(LoadingRules.stepText(5, "Main", cfg), cfg.READY)
		expect.equal(LoadingRules.stepText(1, "Elsewhere", cfg), cfg.STEPS[1], "an unknown place: the plain first step")
	end,

	["the fan's cards all have a small painting"] = function()
		expect.equal(#cfg.FAN_CARDS, 3)
		for _, name in cfg.FAN_CARDS do
			expect.equal(typeof(CardArt.SMALL[name]), "string", name)
		end
	end,

	["the cards step also waits for your cards' paintings, but only a slow save gets the note"] = function()
		local step = LoadingRules.progress(status(true, true, true, true, false), 1, cfg)
		expect.equal(step, 2, "save in, paintings still downloading")
		local _, _, _, slow = LoadingRules.progress(status(true, true, false, false, false), cfg.SLOW_SECONDS + 1, cfg)
		expect.equal(slow, false, "the save isn't what's slow")
	end,

	["the card ids you own: stacks and individual cards, once each"] = function()
		local ids = LoadingRules.ownedCardIds({
			stacks = { c1 = { C = { normal = 2, foil = 0 } }, c2 = {} },
			beasts = { b1 = { cardId = "c2" }, b2 = { cardId = "c3" }, b3 = { cardId = 7 } },
		})
		table.sort(ids)
		expect.equal(table.concat(ids, ","), "c1,c2,c3")
		expect.equal(#LoadingRules.ownedCardIds({}), 0)
		expect.equal(#LoadingRules.ownedCardIds("junk" :: any), 0)
	end,
}
