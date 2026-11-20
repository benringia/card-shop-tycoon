--!strict
-- The party dock (owner 2026-11-13: "lets make the party UI like this in palworld. pets carousel, then under it is the
-- character menu model then beside it is health. Both mobile and Desktop", no box): your team as a carousel, you under
-- it with your XP (the health bar went: "whats the point of this HP bar here", Util/PartyDock)
local PartyDock = require("../src/shared/Util/PartyDock")
local Party = require("../src/shared/Config/Party")
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

	-- Owner 2026-11-21: "I want it to be like the palword party style where 1 and 3 keys are the arrows to the carousel
	-- press a summon button (E Preffered) and whatever creature is in the middle will be summoned." On a keyboard the
	-- middle is the one you picked, out or not; 1 brings the left one round, 3 the right one, E calls the middle one
	["a keyboard's carousel: the one you picked stays in the middle, whoever is out"] = function()
		local full = { [1] = "a", [2] = "b", [3] = "c" }
		expect.equal(spots(PartyDock.carousel(full, 1, 3, 3, true)), "2,3,1", "picked 3 while 1 is out: 3 in the middle")
		expect.equal(spots(PartyDock.carousel(full, 1, nil, 3, true)), "3,1,2", "nothing picked yet: the one that's out")
		expect.equal(PartyDock.carousel({ [1] = "a", [2] = "b" }, 2, 3, 3, true).center, 2, "the picked slot emptied: the one that's out")
		expect.equal(PartyDock.carousel(full, 1, 3, 3).center, 1, "a phone (not picking): the one that's out, as before")
	end,

	["1 and 3 turn the carousel: the creature on that side comes to the middle, empty slots skipped"] = function()
		local full = { [1] = "a", [2] = "b", [3] = "c" }
		expect.equal(PartyDock.turn(full, 1, "left", 3), 3, "1: the left one (slot 3 sits left of slot 1)")
		expect.equal(PartyDock.turn(full, 1, "right", 3), 2, "3: the right one")
		expect.equal(PartyDock.turn(full, 3, "right", 3), 1, "wrapping round")
		local two = { [1] = "a", [2] = "b" }
		expect.equal(PartyDock.turn(two, 1, "left", 3), 2, "the left slot is empty: the next creature round that way")
		expect.equal(PartyDock.turn(two, 2, "right", 3), 1)
		expect.isNil(PartyDock.turn({ [2] = "b" }, 2, "left", 3), "one creature: nothing to turn to")
		expect.isNil(PartyDock.turn({}, 1, "right", 3), "no party")
		expect.equal(PartyDock.turn(two, 3, "right", 3), 1, "from an empty middle: the first creature that way")
	end,

	-- Owner 2026-11-21, with Palworld's picture: "Can you make the party keys positioned exactly like this? only the
	-- images switch. the keys stay still." Three key caps fixed round the carousel: 1 left of the left portrait, the
	-- summon key over the middle one, 3 right of the right one
	["the party's keys stay still round the carousel: 1 on its left, E over its middle, 3 on its right"] = function()
		local dock = Party.BAR.DOCK
		local portrait = Party.BAR.PORTRAIT
		local keys = dock.keys
		local spots = PartyDock.keySpots(dock, portrait)
		local half = keys.cap / 2
		local sideHalf = portrait * dock.side / 2
		assert(spots.left.x + half <= dock.sideX - sideHalf - keys.gap + 1e-6, "1 sits clear of the left portrait, outside it")
		assert(spots.right.x - half >= dock.width - dock.sideX + sideHalf + keys.gap - 1e-6, "3 clear of the right one")
		expect.equal(spots.left.x + spots.right.x, dock.width, "the two mirror each other")
		expect.equal(spots.left.y, spots.right.y, "level with the side portraits")
		expect.equal(spots.left.y, dock.height / 2 + dock.sideY)
		expect.equal(spots.top.x, dock.width / 2, "E over the middle")
		local middleTop = dock.height / 2 - portrait * dock.center / 2
		assert(spots.top.y + half <= middleTop - keys.rise + 1e-6, "over the middle portrait and its level chip")
		assert(keys.cap >= 16, "a key you can read")
	end,

	["your XP bar's words: the XP into the level over its total, short"] = function()
		expect.equal(PartyDock.xpText(850, 1200), "850 / 1.2K")
		expect.equal(PartyDock.xpText(99800, 226000), "99.8K / 226K")
		expect.equal(PartyDock.xpText(1250000, 2000000), "1.25M / 2M")
		expect.equal(PartyDock.xpText(0, 0), "MAX", "the last level")
	end,
}
