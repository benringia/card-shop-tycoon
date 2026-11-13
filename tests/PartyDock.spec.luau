--!strict
-- The party dock (owner 2026-11-13: "lets make the party UI like this in palworld. pets carousel, then under it is the
-- character menu model then beside it is health. Both mobile and Desktop", no box): your team as a carousel, you under
-- it with your XP (the health bar went: "whats the point of this HP bar here", Util/PartyDock)
local PartyDock = require("../src/shared/Util/PartyDock")
local expect = require("./lib/expect")

local function spots(c: PartyDock.Carousel): string
	return `{c.left},{c.center},{c.right}`
end

return {
	["the creature that's out sits in the middle, its neighbours either side, wrapping round"] = function()
		local full = { [1] = "a", [2] = "b", [3] = "c" }
		expect.equal(spots(PartyDock.carousel(full, 1, nil, 3)), "3,1,2")
		expect.equal(spots(PartyDock.carousel(full, 2, nil, 3)), "1,2,3")
		expect.equal(spots(PartyDock.carousel(full, 3, nil, 3)), "2,3,1")
	end,

	["nothing out: the one last in the middle stays there, else the first card, else slot 1"] = function()
		local full = { [1] = "a", [2] = "b", [3] = "c" }
		expect.equal(PartyDock.carousel(full, nil, 3, 3).center, 3, "sent back in: it stays in the middle")
		expect.equal(PartyDock.carousel({ [2] = "b" }, nil, 3, 3).center, 2, "the middle one left the party: the first card")
		expect.equal(PartyDock.carousel({}, nil, nil, 3).center, 1, "no party: the empty first slot (its tap picks a card)")
		expect.equal(PartyDock.carousel({ [1] = "a" }, 3, nil, 3).center, 1, "out but its slot emptied: the first card")
	end,

	["your XP bar's words: the XP into the level over its total, short"] = function()
		expect.equal(PartyDock.xpText(850, 1200), "850 / 1.2K")
		expect.equal(PartyDock.xpText(99800, 226000), "99.8K / 226K")
		expect.equal(PartyDock.xpText(1250000, 2000000), "1.25M / 2M")
		expect.equal(PartyDock.xpText(0, 0), "MAX", "the last level")
	end,
}
