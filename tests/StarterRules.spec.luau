--!strict
-- The Starter Pack's card (spec 2026-11-28-robux-round-design, Starter A): an hour of play counted after Pish's first
-- visit in the main place, shown once at a calm moment, never to an owner or where chance-based buys are restricted
local StarterRules = require("../src/shared/Util/StarterRules")
local Starter = require("../src/shared/Config/Starter")
local expect = require("./lib/expect")

local CALM = {
	ready = true,
	panelOpen = false,
	screenClear = true,
	stageShown = false,
	revealing = false,
	fighting = false,
	tour = false,
	register = false,
}

return {
	["play counts only after the first visit, in the main place, up to an hour"] = function()
		expect.equal(Starter.PLAY_SECONDS, 3600)
		expect.equal(StarterRules.played(10, false, true, Starter), 10, "before Pish's visit is done")
		expect.equal(StarterRules.played(10, true, false, Starter), 10, "not in the Frontier or Dungeon")
		expect.equal(StarterRules.played(10, true, true, Starter), 11)
		expect.equal(StarterRules.played(3600, true, true, Starter), 3600, "stops at an hour")
	end,

	["a saved state is cleaned"] = function()
		local state = StarterRules.clean({ played = 99999, shown = "yes" }, Starter)
		expect.equal(state.played, 3600)
		expect.equal(state.shown, false)
		expect.equal(StarterRules.clean(nil, Starter).played, 0)
		expect.equal(StarterRules.clean({ played = -5, shown = true }, Starter).played, 0)
		expect.equal(StarterRules.clean({ played = 12.7, shown = true }, Starter).played, 12)
		expect.equal(StarterRules.clean({ played = 0 / 0 }, Starter).played, 0, "NaN")
		expect.equal(StarterRules.clean({ shown = true }, Starter).shown, true)
	end,

	["the card is due after an hour, once, unowned, not restricted"] = function()
		local due = { played = 3600, shown = false }
		expect.equal(StarterRules.offerDue(due, false, false, Starter), true)
		expect.equal(StarterRules.offerDue({ played = 3599, shown = false }, false, false, Starter), false)
		expect.equal(StarterRules.offerDue({ played = 3600, shown = true }, false, false, Starter), false)
		expect.equal(StarterRules.offerDue(due, true, false, Starter), false, "owned")
		expect.equal(StarterRules.offerDue(due, false, true, Starter), false, "restricted")
	end,

	["the card waits for a calm moment"] = function()
		expect.equal(StarterRules.mayShow(CALM), true)
		for _, busy in { "panelOpen", "stageShown", "revealing", "fighting", "tour", "register" } do
			local facts = table.clone(CALM)
			facts[busy] = true
			expect.equal(StarterRules.mayShow(facts), false, busy)
		end
		local notReady = table.clone(CALM)
		notReady.ready = false
		expect.equal(StarterRules.mayShow(notReady), false, "not ready")
		local covered = table.clone(CALM)
		covered.screenClear = false
		expect.equal(StarterRules.mayShow(covered), false, "a purchase dialog or Roblox menu open")
	end,

	["the card's words call it a pack, never a gift"] = function()
		local words = Starter.CARD
		assert(words.title and words.line and words.later and words.foot and #words.rows == 3, "every line there")
		for _, text in { words.title, words.line, words.later, words.foot } do
			assert(not string.find(string.lower(text), "gift"), `"{text}" never says gift`)
		end
		for _, row in words.rows do
			assert(row.name and row.line, "each row has a name and a line")
			assert(not string.find(string.lower(row.name .. row.line), "gift"), "a row never says gift")
		end
	end,
}
