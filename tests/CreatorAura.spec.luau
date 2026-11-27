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
		expect.equal(CreatorAura.GLOW.reach > 0, true, "the glow reaches past the card")
	end,

	-- Owner 2026-11-27 on seeing it: "make the cards around me glow"
	["the cards glow: a strong breathing halo, a gold rim and a light of their own"] = function()
		local glow = CreatorAura.GLOW
		expect.equal(glow.transparency <= 0.15, true, "a strong halo")
		expect.equal(glow.breathe.low < glow.breathe.high and glow.breathe.seconds > 0, true, "it breathes")
		expect.equal(CreatorAura.RIM.thickness > 0 and #CreatorAura.RIM.color == 3, true, "a gold rim")
		expect.equal(CreatorAura.LIGHT.brightness > 0 and CreatorAura.LIGHT.range > 0, true, "lights what's near")
		-- in daylight the halo alone read faint (Studio check 2026-11-27): a brighter halo layer and a sparkle trail
		-- the particles' soft glow was nearly see-through in an ImageLabel: the cards' own card-shaped glow picture
		-- (Config/GradeLook IMAGES.glow, a Grade S card's), reaching further than a Grade S card's
		expect.equal(glow.reach >= 0.4 and glow.brightness > 1, true, "a big, bright card-shaped halo")
		local sparkles = CreatorAura.SPARKLES
		expect.equal(sparkles.rate > 0 and sparkles.lightEmission == 1 and sparkles.lifetime > 0, true, "glowing sparkles trail each card")
	end,
}
