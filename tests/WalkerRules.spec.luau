--!strict
-- Town walkers (spec 2026-11-06-customers-design, phase 2): customers who stroll the plaza, sit on benches, then pick an
-- open shop by its rating and what they want
local WalkerRules = require("../src/shared/Util/WalkerRules")
local Customers = require("../src/shared/Config/Customers")
local expect = require("./lib/expect")

local function counts(shops, rolls: number): { [number]: number }
	local result: { [number]: number } = {}
	for step = 0, rolls - 1 do
		local id = WalkerRules.chooseShop(Customers, shops, (step + 0.5) / rolls)
		if id then
			result[id] = (result[id] or 0) + 1
		end
	end
	return result
end

return {
	["walkers only go to open shops"] = function()
		local closed = { { id = 1, rating = 5, open = false, hasWanted = false }, { id = 2, rating = 3, open = false, hasWanted = false } }
		expect.equal(WalkerRules.chooseShop(Customers, closed, 0.5), nil)
		local oneOpen = { { id = 1, rating = 5, open = false, hasWanted = true }, { id = 2, rating = 1, open = true, hasWanted = false } }
		for _, roll in { 0, 0.5, 0.99 } do
			expect.equal(WalkerRules.chooseShop(Customers, oneOpen, roll), 2)
		end
	end,

	["better rated shops draw more walkers"] = function()
		local result = counts({ { id = 1, rating = 5, open = true, hasWanted = false }, { id = 2, rating = 3, open = true, hasWanted = false } }, 1000)
		local ratio = (result[1] or 0) / math.max(1, result[2] or 0)
		assert(ratio > 2.4 and ratio < 3.2, `about (5/3)^2 = 2.78, got {ratio}`)
	end,

	["a collector heads for the shop showing its card"] = function()
		local result = counts({ { id = 1, rating = 3, open = true, hasWanted = true }, { id = 2, rating = 3, open = true, hasWanted = false } }, 1000)
		local ratio = (result[1] or 0) / math.max(1, result[2] or 0)
		assert(ratio > 2.6 and ratio < 3.4, `wantedBonus 3, got {ratio}`)
	end,

	["they sit on free benches only"] = function()
		local stops = { { kind = "bench", free = false }, { kind = "fountain", free = true } }
		expect.equal(WalkerRules.nextStop(Customers, stops, 0.1), 2, "the bench is taken")
		expect.equal(WalkerRules.nextStop(Customers, { { kind = "bench", free = false } }, 0.5), nil, "nowhere free")
		local free = { { kind = "bench", free = true }, { kind = "spot", free = true } }
		expect.equal(WalkerRules.nextStop(Customers, free, 0.1), 1, "under sitChance: the bench")
		expect.equal(WalkerRules.nextStop(Customers, free, 0.9), 2, "over it: a spot")
		expect.equal(WalkerRules.nextStop(Customers, { { kind = "bench", free = true } }, 0.9), 1, "only a bench free: sit anyway")
	end,
}
