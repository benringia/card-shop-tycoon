--!strict
local LoadingRules = require("../src/shared/Util/LoadingRules")
local LoadingScreen = require("../src/shared/Config/LoadingScreen")
local WildLoading = require("../src/shared/Config/WildLoading")
local BinderCovers = require("../src/shared/Config/BinderCovers")
local CardArt = require("../src/shared/Config/CardArt")
local expect = require("./lib/expect")

local cfg = LoadingScreen

-- shop: the product models, icons and other first pictures (round 4); ready unless a test says otherwise
local function status(character: boolean, data: boolean, creature: boolean, gear: boolean, art: boolean?, shop: boolean?): LoadingRules.Status
	return { character = character, data = data, art = if art == nil then data else art, shop = if shop == nil then true else shop, creature = creature, gear = gear }
end

return {
	-- The Frontier valley (spec 2026-11-10-frontier-valley-design, plan Task 6): its own look and a wait for its valley
	["the Frontier's look keeps the screen and changes its title, colours and steps"] = function()
		local look = LoadingRules.look(cfg, "Frontier")
		expect.equal(look.TITLE, "The Frontier")
		assert(look.SWIRL_COLORS[1][1] ~= cfg.SWIRL_COLORS[1][1], "the Frontier's swirl is its own colour")
		assert(look.STEPS[3] ~= cfg.STEPS[3], "no shelves to stock in the Frontier")
		expect.equal(#look.STEPS, #cfg.STEPS, "the same number of steps")
		expect.equal(look.MAX_SECONDS, cfg.MAX_SECONDS, "the rest is the screen's")
		expect.equal(LoadingRules.look(cfg, "Main").TITLE, cfg.TITLE, "the main game keeps its look")
		expect.equal(LoadingRules.look(cfg, "Dungeon").TITLE, cfg.TITLE, "the Dungeon too, for now")
	end,

	["the main game's teleport screen is the Frontier's"] = function()
		expect.equal(LoadingRules.teleportLook("Main"), "Frontier", "the main game teleports only to the Frontier")
		expect.isNil(LoadingRules.teleportLook("Frontier"), "home or to the Dungeon: the usual screen")
		expect.equal(LoadingRules.teleportLook("Dungeon"), "Frontier", "the Dungeon only goes back to the Frontier")
	end,

	["the Frontier's loading waits for its valley"] = function()
		local waiting = status(true, true, true, true) :: any
		waiting.valley = false
		local _, _, done = LoadingRules.progress(waiting, 3, cfg)
		expect.equal(done, false, "the valley isn't in yet")
		local step = LoadingRules.progress(waiting, 3, cfg)
		expect.equal(step, 3, "held on the third step")
		waiting.valley = true
		_, _, done = LoadingRules.progress(waiting, 3, cfg)
		expect.equal(done, true, "the valley's in")
	end,

	["the steps tick off in order: character, save, shop pictures, creature, fight gear"] = function()
		local step, share, done = LoadingRules.progress(status(false, false, false, false), 0, cfg)
		expect.equal(step, 1)
		expect.equal(share, 0)
		expect.equal(done, false)
		step, share = LoadingRules.progress(status(true, false, false, false), 1, cfg)
		expect.equal(step, 2)
		expect.equal(share, 0.2)
		step, share = LoadingRules.progress(status(true, true, true, false), 2, cfg)
		expect.equal(step, 5)
		expect.equal(share, 0.8)
		step, share, done = LoadingRules.progress(status(true, true, true, true), 3, cfg)
		expect.equal(step, 6, "all done")
		expect.equal(share, 1)
		expect.equal(done, true)
	end,

	["the shop step waits for the first pictures"] = function()
		local step, _, done = LoadingRules.progress(status(true, true, true, true, true, false), 2, cfg)
		expect.equal(step, 3, "everything else is in: the shop pictures still loading")
		expect.equal(done, false)
	end,

	["failed assets count as settled"] = function()
		expect.equal(LoadingRules.settled({ "Success", "Failure", "TimedOut" }), true, "failed or timed out: nothing more to wait for")
		expect.equal(LoadingRules.settled({ "Success", "Loading" }), false, "still loading")
		expect.equal(LoadingRules.settled({ "None" }), false, "not asked for yet")
		expect.equal(LoadingRules.settled({}), true, "nothing to load")
	end,

	["a later step done early doesn't jump the bar ahead"] = function()
		local step, share = LoadingRules.progress(status(true, false, true, true), 1, cfg)
		expect.equal(step, 2, "still loading the save")
		expect.equal(share, 0.2)
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
		expect.equal(#cfg.STEPS, 5)
		for _, kind in { "Main", "Frontier", "Dungeon" } do
			expect.equal(typeof(LoadingRules.stepText(1, kind, cfg)), "string", kind)
		end
		expect.equal(LoadingRules.stepText(1, "Main", cfg), cfg.FIRST_STEP.Main)
		expect.equal(LoadingRules.stepText(3, "Main", cfg), cfg.STEPS[3])
		expect.equal(LoadingRules.stepText(6, "Main", cfg), cfg.READY)
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
	-- The owner (2026-11-05, option B): the join screen in the Wild's feel, the card fan in front of a turning swirl
	-- over the First Spark cover's sky
	["the join screen swirls the Wild's spiral over the First Spark cover's sky"] = function()
		expect.equal(cfg.SWIRL, WildLoading.SWIRL, "the same spiral as the Wild's screen")
		expect.equal(cfg.BACKDROP, BinderCovers.SETS["First Spark"].art)
		local rect = cfg.BACKDROP_RECT
		expect.equal(rect[1] >= 0 and rect[2] >= 0 and rect[1] + rect[3] <= 680 and rect[2] + rect[4] <= 1014, true, "inside the 680 x 1014 painting")
		expect.equal(rect[2] < 300, true, "its sky: the golden star and the element orbs")
		expect.equal(cfg.SWIRL_SECONDS[1] > 0 and cfg.SWIRL_SECONDS[2] > 0, true, "both copies turn")
		expect.equal(#cfg.SWIRL_COLORS, 2)
	end,
}
