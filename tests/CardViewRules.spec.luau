--!strict
-- Owner 2026-11-21 (the binder's card view): "make this suitable for a person with low attention span. relayout this,
-- only display what is important". The view opens on a few things (this copy: grade, level, stars, one big Power, its
-- XP and next star; what it's strong and weak against); skills, buffs, the wheel's numbers, the other stats and the
-- sell hint wait behind "More about this card".
local CardViewRules = require("../src/shared/Util/CardViewRules")
local Config = require("../src/shared/Config/CardView")
local expect = require("./lib/expect")

local function same(a: { string }, b: { string }, why: string?)
	expect.equal(table.concat(a, ","), table.concat(b, ","), why)
end

return {
	["the card view opens on what matters: this copy, its matchups and the More button"] = function()
		same(CardViewRules.sections(false, 1), { "copy", "matchups", "toggle" }, "one copy: nothing else")
		same(CardViewRules.sections(false, 3), { "copy", "matchups", "toggle", "copies" }, "several copies: the list, to pick one")
		assert(#CardViewRules.sections(false, 3) <= Config.SIMPLE_MAX, "never more than a handful of things at once")
	end,

	["More about this card: skills, buffs, elements and every copy"] = function()
		same(CardViewRules.sections(true, 1), { "copy", "matchups", "toggle", "skills", "buffs", "elements", "copies" })
		same(CardViewRules.sections(true, 4), { "copy", "matchups", "toggle", "skills", "buffs", "elements", "copies" })
		expect.equal(CardViewRules.sellHint(false), false, "the sell hint waits with the details")
		expect.equal(CardViewRules.sellHint(true), true)
	end,

	["one big number first: Power; the other stats with the details"] = function()
		same(CardViewRules.stats(false), { "Power" })
		same(CardViewRules.stats(true), { "Power", "Hp", "Atk", "Spd" })
	end,

	["the More button says what a tap does"] = function()
		expect.equal(CardViewRules.toggleWords(false, Config), Config.TOGGLE.more)
		expect.equal(CardViewRules.toggleWords(true, Config), Config.TOGGLE.less)
		assert(Config.TOGGLE.more ~= Config.TOGGLE.less)
		assert(Config.TOGGLE_HEIGHT >= 48, "a tap target")
	end,

	["the bars' words: plain, no arrows"] = function()
		expect.equal(CardViewRules.xpWords(1, 0, 50), "Level 2: 0/50 XP")
		expect.equal(CardViewRules.xpWords(7, 120, 400), "Level 8: 120/400 XP")
		expect.equal(CardViewRules.xpWords(30, 0, 0), "Max level")
		expect.equal(CardViewRules.starWords(1, 4), "Next star: 1/4 copies")
		expect.equal(CardViewRules.starWords(0, nil), "Max stars")
		for _, words in { CardViewRules.xpWords(1, 0, 50), CardViewRules.starWords(1, 4), Config.TOGGLE.more, Config.TOGGLE.less } do
			assert(not string.find(words, "->", 1, true), "no arrows")
		end
	end,

	["matchup chips: Strong vs and Weak vs, in the elements' plain names"] = function()
		local names = { Ember = "Fire", Tide = "Water", ORDER = { "Ember", "Tide" } }
		local chips = CardViewRules.matchups({ strong = { "Ember" }, weak = { "Tide" } }, names)
		expect.equal(#chips, 2)
		expect.equal(chips[1].words, "Strong vs Fire")
		expect.equal(chips[1].good, true)
		expect.equal(chips[1].element, "Ember", "the icon keeps the key")
		expect.equal(chips[2].words, "Weak vs Water")
		expect.equal(chips[2].good, false)
		expect.equal(#CardViewRules.matchups({ strong = {}, weak = {} }, names), 0, "no matchups: no chips")
	end,
	-- owner 2026-11-20 (a screenshot of the short view): "theres a huge space here on this window fix it": the panel
	-- is as tall as what it shows (header, body, buttons), never taller than the room, centred in it
	["the card view's panel fits what it shows, centred in the room, never past it"] = function()
		local fit = CardViewRules.fitPanel(300, 130, { top = 84, bottom = 947 }, 260)
		expect.equal(fit.height, 430, "the short view: its content and chrome, no empty space")
		expect.equal(fit.top, 84 + (863 - 430) / 2, "centred in the room")
		local tall = CardViewRules.fitPanel(2000, 130, { top = 84, bottom = 947 }, 260)
		expect.equal(tall.height, 863, "the long view (More, many copies): the whole room, it scrolls")
		expect.equal(tall.top, 84)
		local small = CardViewRules.fitPanel(40, 130, { top = 84, bottom = 947 }, 260)
		expect.equal(small.height, 260, "never smaller than its least")
		local full = CardViewRules.fitPanel(300, 130, { top = 84, bottom = 947 }, 260, true)
		expect.equal(full.height, 863, "a chooser open (party, job): the whole room")
	end,
}
