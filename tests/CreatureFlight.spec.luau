--!strict
-- Which creatures fly (hover over their feet), shared by the client's drawing and the server's shop-worker name tags
-- (owner 2026-11-06: a flying worker's name sat in its wings, hard to read)
local CreatureFlight = require("../src/shared/Util/CreatureFlight")
local Party = require("../src/shared/Config/Party")
local expect = require("./lib/expect")

return {
	["Nightowl flies, Cindercub walks"] = function()
		expect.equal(CreatureFlight.isFlying(Party, "Nightowl"), true)
		expect.equal(CreatureFlight.isFlying(Party, "Cindercub"), false)
	end,

	["a flying creature's top is its height plus the hover"] = function()
		expect.equal(CreatureFlight.top(Party, "Cindercub", 3), 3)
		expect.equal(CreatureFlight.top(Party, "Nightowl", 3), 3 + Party.MOTION.HOVER_HEIGHT)
	end,
}
