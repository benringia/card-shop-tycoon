--!strict
-- The Creator aura (owner 2026-11-27: "Dev exclusive title and aura", pick C "orbiting cards"; spec
-- 2026-11-27-live-admin-creator-design): three card backs circling the owner at chest height
local CreatorAura = require("../src/shared/Config/CreatorAura")
local CreatorAuraRules = require("../src/shared/Util/CreatorAuraRules")
local expect = require("./lib/expect")

local function angleOf(x: number, z: number): number
	return math.atan2(z, x)
end

return {
	["three cards, a third of a lap apart"] = function()
		expect.equal(CreatorAura.COUNT, 3)
		local x1, _, z1 = CreatorAuraRules.place(CreatorAura, 2.5, 1)
		local x2, _, z2 = CreatorAuraRules.place(CreatorAura, 2.5, 2)
		local gap = (angleOf(x2, z2) - angleOf(x1, z1)) % (2 * math.pi)
		expect.near(gap, 2 * math.pi / 3, 1e-6, "the next card a third of a lap on")
	end,

	["each card circles at the radius, around chest height"] = function()
		for _, t in { 0, 1.3, 4.7 } do
			for index = 1, CreatorAura.COUNT do
				local x, y, z = CreatorAuraRules.place(CreatorAura, t, index)
				expect.near(math.sqrt(x * x + z * z), CreatorAura.RADIUS, 1e-6, "on the circle")
				expect.near(y, CreatorAura.HEIGHT, CreatorAura.BOB + 1e-6, "bobbing a little")
			end
		end
	end,

	["a lap takes LAP seconds, bob and all"] = function()
		local x1, y1, z1 = CreatorAuraRules.place(CreatorAura, 1.7, 2)
		local x2, y2, z2 = CreatorAuraRules.place(CreatorAura, 1.7 + CreatorAura.LAP, 2)
		expect.near(x2, x1, 1e-6)
		expect.near(y2, y1, 1e-6)
		expect.near(z2, z1, 1e-6)
		local x3, _, z3 = CreatorAuraRules.place(CreatorAura, 1.7 + CreatorAura.LAP / 2, 2)
		expect.near(x3, -x1, 1e-6, "half a lap: the other side")
		expect.near(z3, -z1, 1e-6)
	end,

	["a card is card-shaped and its glow is behind it, bigger"] = function()
		expect.equal(CreatorAura.CARD.h > CreatorAura.CARD.w, true, "taller than wide")
		expect.equal(CreatorAura.GLOW.size > 1, true, "the glow reaches past the card")
	end,
}
