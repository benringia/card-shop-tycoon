--!strict
-- Element callouts (spec 2026-11-25-element-callouts-design; owner picked A, "a chip in your creature's status row"):
-- the chip a matchup shows, its words and strength tag
local MatchupRules = require("../src/shared/Util/MatchupRules")
local Combat = require("../src/shared/Config/Combat")
local Names = require("../src/shared/Config/ElementNames")
local expect = require("./lib/expect")

return {
	["weak: red, the foe's name and how hard you hit"] = function()
		local chip = MatchupRules.chip(Combat, "Bloom", "Ember", Names)
		assert(chip, "Nature against Fire shows a chip")
		expect.equal(chip.good, false, "weak")
		expect.equal(chip.words, "Weak vs Fire")
		expect.equal(chip.tag, "0.75x")
		expect.equal(chip.element, "Ember", "the foe's icon")
	end,

	["strong: green"] = function()
		local chip = MatchupRules.chip(Combat, "Bloom", "Tide", Names)
		assert(chip, "Nature against Water shows a chip")
		expect.equal(chip.good, true)
		expect.equal(chip.words, "Strong vs Water")
		expect.equal(chip.tag, "1.5x")
		expect.equal(chip.element, "Tide")
	end,

	["an even fight shows nothing"] = function()
		expect.isNil(MatchupRules.chip(Combat, "Bloom", "Volt", Names), "Nature against Electric")
		expect.isNil(MatchupRules.chip(Combat, "Ember", "Ember", Names), "Fire against Fire")
	end,

	["Electric and Dark beat each other: green both ways"] = function()
		local volt = MatchupRules.chip(Combat, "Volt", "Shade", Names)
		local shade = MatchupRules.chip(Combat, "Shade", "Volt", Names)
		assert(volt and shade, "both show a chip")
		expect.equal(volt.good, true, "Electric against Dark")
		expect.equal(volt.words, "Strong vs Dark")
		expect.equal(shade.good, true, "Dark against Electric")
		expect.equal(shade.words, "Strong vs Electric")
	end,

	["a boss changing element changes the chip"] = function()
		local before = MatchupRules.chip(Combat, "Tide", "Ember", Names)
		local after = MatchupRules.chip(Combat, "Tide", "Bloom", Names)
		assert(before and after, "both show a chip")
		expect.equal(before.good, true, "Water against Fire")
		expect.equal(after.good, false, "Water against Nature")
	end,

	["no element, no foe or an unknown one: nothing"] = function()
		expect.isNil(MatchupRules.chip(Combat, nil, "Ember", Names), "no creature element")
		expect.isNil(MatchupRules.chip(Combat, "Bloom", nil, Names), "no monster foe (the arena)")
		expect.isNil(MatchupRules.chip(Combat, "", "Ember", Names), "an empty element")
		expect.isNil(MatchupRules.chip(Combat, "Bloom", "Glitter", Names), "an element the wheel doesn't know")
	end,

	["the strength tag in plain numbers"] = function()
		expect.equal(MatchupRules.tag(1.5), "1.5x")
		expect.equal(MatchupRules.tag(0.75), "0.75x")
		expect.equal(MatchupRules.tag(2), "2x")
	end,
}
