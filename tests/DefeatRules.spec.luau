--!strict
local DefeatRules = require("../src/shared/Util/DefeatRules")
local Defeat = require("../src/shared/Config/Defeat")
local Bosses = require("../src/shared/Config/Bosses")
local expect = require("./lib/expect")

local CARDS = { c1 = { name = "Ashbeak" }, c2 = { name = "Mossmole" }, c3 = { name = "Zappit" }, c4 = { name = "Petalpaw" } }

return {
	["the card: your sword, your creatures by damage, the boss's HP left, rings dodged"] = function()
		local rows = DefeatRules.rows({
			sword = 1240,
			creatures = { { cardId = "c2", damage = 610 }, { cardId = "c1", damage = 2860 } },
			hpShare = 0.384,
			rings = 7,
			dodged = 4,
		}, CARDS, Defeat)
		expect.equal(#rows, 5)
		expect.equal(rows[1].kind, "sword")
		expect.equal(rows[1].value, "1,240")
		expect.equal(rows[2].label, "Ashbeak", "the bigger hitter first")
		expect.equal(rows[2].value, "2,860")
		expect.equal(rows[2].cardId, "c1")
		expect.equal(rows[3].label, "Mossmole")
		expect.equal(rows[4].kind, "hp")
		expect.equal(rows[4].value, "38%")
		expect.near(rows[4].share :: number, 0.384, 1e-9)
		expect.equal(rows[5].value, "4 / 7")
	end,

	["no sword row without a sword, no rings row without rings, at most the top creatures"] = function()
		local creatures = {}
		for index, id in { "c1", "c2", "c3", "c4" } do
			table.insert(creatures, { cardId = id, damage = index * 100 })
		end
		local rows = DefeatRules.rows({ creatures = creatures, hpShare = 1, rings = 0, dodged = 0 }, CARDS, Defeat)
		local kinds = {}
		for _, row in rows do
			table.insert(kinds, row.kind)
		end
		expect.equal(table.concat(kinds, ","), string.rep("creature,", Defeat.MAX_CREATURES) .. "hp")
		expect.equal(rows[1].label, "Petalpaw")
		expect.equal(DefeatRules.rows({ creatures = { { cardId = "gone", damage = 5 } }, hpShare = 0.5, rings = 0, dodged = 0 }, CARDS, Defeat)[1].kind, "hp", "an unknown card is left out")
	end,

	["numbers read well"] = function()
		expect.equal(DefeatRules.number(7), "7")
		expect.equal(DefeatRules.number(12345.6), "12,346")
		expect.equal(DefeatRules.number(1000000), "1,000,000")
		expect.equal(DefeatRules.subtitle("Cave Brood Queen", 102), "Cave Brood Queen won · 1:42")
		expect.equal(DefeatRules.subtitle(nil, nil), "Your party fainted")
	end,

	["every boss has its own tips, and a general one when it has none"] = function()
		for _, bossId in Bosses.LADDER do
			local tips = Defeat.TIPS[bossId]
			expect.equal(tips ~= nil and #tips >= 1, true, bossId)
		end
		expect.equal(DefeatRules.tip("caveBroodQueen", 0, Defeat), Defeat.TIPS.caveBroodQueen[1])
		expect.equal(DefeatRules.tip("caveBroodQueen", 0.999, Defeat), Defeat.TIPS.caveBroodQueen[#Defeat.TIPS.caveBroodQueen])
		expect.equal(DefeatRules.tip("nobody", 0, Defeat), Defeat.TIPS.general[1])
		for _, list in Defeat.TIPS do
			for _, line in list do
				expect.equal(string.find(line, "[^%w%s%p]") == nil, true, `plain text: {line}`)
			end
		end
	end,
}
