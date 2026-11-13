--!strict
-- The character window's Stats tab (owner 2026-11-12: "their attack or defense", "add power so that player can compare
-- it to whatever boss their planning to take")
local CharacterStats = require("../src/shared/Util/CharacterStats")
local expect = require("./lib/expect")

return {
	-- owner 2026-11-13 (the character window, pick A): four progress tiles over the stats, goals at a glance
	["the progress tiles: level with its XP, cards, bosses and titles, each with how far along"] = function()
		local tiles = CharacterStats.progress({
			level = 57, into = 285, span = 18200,
			cards = 84, cardsTotal = 120,
			bosses = 5, bossesTotal = 7,
			titles = 6, titlesTotal = 18,
		})
		expect.equal(#tiles, 4)
		expect.equal(tiles[1].name, "Level")
		expect.equal(tiles[1].value, "57")
		expect.near(tiles[1].share, 285 / 18200, 1e-9, "the XP into the level")
		expect.equal(tiles[2].name, "Cards")
		expect.equal(tiles[2].value, "84/120")
		expect.near(tiles[2].share, 0.7, 1e-9)
		expect.equal(tiles[3].value, "5/7")
		expect.equal(tiles[4].value, "6/18")
		local empty = CharacterStats.progress({ level = 99, into = 0, span = 0, cards = 0, cardsTotal = 0, bosses = 0, bossesTotal = 0, titles = 0, titlesTotal = 0 })
		expect.equal(empty[1].share, 1, "the last level: a full bar")
		expect.equal(empty[2].share, 0, "nothing to collect: an empty bar, no error")
	end,

	["Power: the strongest card; Attack: the weapon's; Defense: the party added up"] = function()
		local stats = CharacterStats.compute({ 2614, 1200, 900 }, 1240)
		expect.equal(stats.power, 2614, "what the boss board compares")
		expect.equal(stats.attack, 1240)
		expect.equal(stats.defense, 4714)
	end,

	["an empty party and no weapon: zeros, no error"] = function()
		local stats = CharacterStats.compute({}, 0)
		expect.equal(stats.power, 0)
		expect.equal(stats.attack, 0)
		expect.equal(stats.defense, 0)
	end,
}
