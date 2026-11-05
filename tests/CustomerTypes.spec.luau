--!strict
-- Customer types (spec 2026-11-06-customers-design): plain, kid, collector, bargain hunter, big spender, each wanting
-- something different
local CustomerTypes = require("../src/shared/Util/CustomerTypes")
local Customers = require("../src/shared/Config/Customers")
local Pricing = require("../src/shared/Config/Pricing")
local expect = require("./lib/expect")

local OPEN = { hasShowcase = true, shopLevel = 20 }
local BANDS = Pricing.BUY_BANDS

return {
	["the mix: weights by type, gated by showcase and shop level"] = function()
		local expected = { [0.0] = "plain", [0.54] = "plain", [0.56] = "kid", [0.76] = "collector", [0.86] = "bargain", [0.96] = "bigSpender" }
		for roll, kind in expected do
			expect.equal(CustomerTypes.pick(Customers, OPEN, roll), kind, `roll {roll}`)
		end
		local counts = {}
		for step = 0, 999 do
			local kind = CustomerTypes.pick(Customers, { hasShowcase = false, shopLevel = 20 }, step / 1000)
			counts[kind] = (counts[kind] or 0) + 1
		end
		expect.equal(counts.collector, nil, "no showcase: no collectors")
		expect.equal(counts.plain > 550, true, "the others share the collectors' share")
		for step = 0, 999 do
			assert(CustomerTypes.pick(Customers, { hasShowcase = true, shopLevel = 10 }, step / 1000) ~= "bigSpender", "no big spenders before shop level 11")
		end
	end,

	["bargain hunters and big spenders tolerate one band more"] = function()
		expect.equal(CustomerTypes.tolerance(Customers, "plain"), 0)
		expect.equal(CustomerTypes.tolerance(Customers, "bargain"), 1)
		expect.equal(CustomerTypes.tolerance(Customers, "bigSpender"), 1)
		expect.equal(CustomerTypes.buys(Customers, "plain", 1.3, 1, 0.3, 0, BANDS), false, "band 3 (15%) at roll 0.3")
		expect.equal(CustomerTypes.buys(Customers, "bargain", 1.3, 1, 0.3, 0, BANDS), true, "one band cheaper: 50%")
		expect.equal(CustomerTypes.buys(Customers, "plain", 1.6, 1, 0.0, 0, BANDS), false, "over every band: never")
		expect.equal(CustomerTypes.buys(Customers, "bigSpender", 1.6, 1, 0.1, 0, BANDS), true, "over every band, one more: band 3")
		expect.equal(CustomerTypes.buys(Customers, "plain", 1.3, 1, 0.16, 0.1, BANDS), true, "a perk bonus (Haggle) raises the chance")
	end,

	-- Past even a tolerant type's last band they won't buy and get annoyed, as a plain customer does past the last band
	["out of reach: past the last band, a tolerant type's one band later"] = function()
		expect.equal(CustomerTypes.outOfReach(Customers, "plain", 1.6, 1, BANDS), true)
		expect.equal(CustomerTypes.outOfReach(Customers, "plain", 1.5, 1, BANDS), false)
		expect.equal(CustomerTypes.outOfReach(Customers, "bargain", 1.6, 1, BANDS), false, "one band more")
		expect.equal(CustomerTypes.outOfReach(Customers, "bargain", 1.8, 1, BANDS), false, "the next band is as wide as the last (1.5 to 1.8)")
		expect.equal(CustomerTypes.outOfReach(Customers, "bargain", 1.81, 1, BANDS), true, "past that, out of reach")
		expect.equal(CustomerTypes.buys(Customers, "bargain", 9, 1, 0, 0, BANDS), false, "far past every band: never")
		expect.equal(CustomerTypes.outOfReach(Customers, "kid", 1.6, 1, BANDS), true)
	end,

	["every type has an icon and props"] = function()
		for _, kind in Customers.TYPE_ORDER do
			local spec = Customers.TYPES[kind]
			assert(spec and spec.weight > 0, `{kind}: a weight`)
			if kind ~= "plain" then
				assert(#spec.props > 0, `{kind}: props`)
				for _, prop in spec.props do
					assert(#prop.size == 3 and #prop.offset == 3 and #prop.color == 3, `{kind}: prop numbers`)
				end
				assert(kind == "collector" or (typeof(spec.icon) == "string" and spec.icon ~= ""), `{kind}: an arrival icon`)
			end
		end
		expect.equal(Customers.TYPES.kid.scale, 0.82)
		expect.equal(Customers.TYPES.collector.needsShowcase, true)
		expect.equal(Customers.TYPES.bigSpender.minLevel, 11)
	end,
}
