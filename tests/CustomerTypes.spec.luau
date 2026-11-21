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
		expect.equal(CustomerTypes.buys(Customers, "plain", 1.3, 1, 0.3, 0, BANDS), false, "a third up band 3: 20%, at roll 0.3")
		expect.equal(CustomerTypes.buys(Customers, "bargain", 1.3, 1, 0.3, 0, BANDS), true, "one band cheaper: over half")
		expect.equal(CustomerTypes.buys(Customers, "plain", 1.6, 1, 0.0, 0, BANDS), false, "over every band: never")
		expect.equal(CustomerTypes.buys(Customers, "bigSpender", 1.6, 1, 0.05, 0, BANDS), true, "over every band, one more: band 3")
		expect.equal(CustomerTypes.buys(Customers, "plain", 1.3, 1, 0.21, 0, BANDS), false, "20% a third of the way up band 3")
		expect.equal(CustomerTypes.buys(Customers, "plain", 1.3, 1, 0.21, 0.1, BANDS), true, "a perk bonus (Haggle) raises the chance")
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

	-- Owner 2026-11-16: "customers that bought something should carry a shopping bag on their way out. shopping bag
	-- should have pish and chikin design on them"
	["the shop bag: an uploaded face picture, in the free left hand, a sensible size"] = function()
		local bag = Customers.BAG
		expect.equal(typeof(bag), "table")
		expect.equal(string.match(bag.image, "^rbxassetid://[1-9]%d*$") ~= nil, true, "an uploaded picture")
		expect.equal(bag.hand, "LeftHand", "the right hand holds a kid's pack or a coupon")
		for _, kind in { "kid", "bargain" } do
			for _, prop in Customers.TYPES[kind].dressedProps do
				expect.equal(prop.part ~= bag.hand, true, `{kind}'s prop is in the other hand`)
			end
		end
		local width, height, depth = bag.size[1], bag.size[2], bag.size[3]
		expect.equal(width > depth and height >= width and height <= 1.5, true, "a paper bag about knee high")
		expect.equal(bag.handle.width < width, true, "handles inside the bag's width")
	end,
	-- How much they buy (owner 2026-11-19: "make them buy like 3 or 4 minimum. rarely just 1. specially if its market
	-- price. to speed up gold in early game", then "add your suggestions": a new shop boost that fades by shop level 15)
	["a new shop's shopping lists are usually 3 or 4 things, rarely just 1"] = function()
		expect.equal(CustomerTypes.listSize(Customers, 0, 1), 1, "the rare single")
		local counts = { 0, 0, 0, 0 }
		local steps = 1000
		for i = 0, steps - 1 do
			local size = CustomerTypes.listSize(Customers, (i + 0.5) / steps, 1)
			counts[size] += 1
		end
		expect.equal(counts[1] / steps <= 0.06, true, "1 thing at most 6% of the time")
		expect.equal((counts[3] + counts[4]) / steps >= 0.75, true, "3 or 4 things at least 3 in 4 times")
		expect.equal(CustomerTypes.listSize(Customers, 0.9999, 1), 4, "the most")
		expect.equal(CustomerTypes.meanListSize(Customers, 1) >= 3, true, "about 3 on average")
		expect.equal(CustomerTypes.meanListSize(Customers, Customers.NEW_SHOP.fullUntil), CustomerTypes.meanListSize(Customers, 1), "the same up to its last full level")
	end,

	["from shop level 15 the lists are as before: 1 to 3 things, fading in between"] = function()
		local late = Customers.NEW_SHOP.goneAt
		local counts = { 0, 0, 0, 0 }
		for i = 0, 999 do
			local size = CustomerTypes.listSize(Customers, (i + 0.5) / 1000, late)
			counts[size] += 1
		end
		expect.equal(counts[4], 0, "never 4")
		for size = 1, 3 do
			expect.near(counts[size] / 1000, 1 / 3, 0.01, `{size} things a third of the time`)
		end
		expect.near(CustomerTypes.meanListSize(Customers, 40), 2, 1e-6, "2 on average, like before")
		local middle = CustomerTypes.meanListSize(Customers, 12)
		expect.equal(middle > 2 and middle < CustomerTypes.meanListSize(Customers, 1), true, "fading in between")
	end,

	["a new shop's kids buy 2 or 3 packs, later 1 or 2 like before"] = function()
		local ones = 0
		for i = 0, 999 do
			local units = CustomerTypes.kidUnits(Customers, (i + 0.5) / 1000, 1)
			expect.equal(units >= 1 and units <= 3, true, "1 to 3")
			ones += if units == 1 then 1 else 0
		end
		expect.equal(ones / 1000 <= 0.2, true, "1 pack at most a fifth of the time")
		expect.equal(CustomerTypes.meanKidUnits(Customers, 1) >= 2, true, "2 or more on average")
		expect.near(CustomerTypes.meanKidUnits(Customers, 30), 1.5, 1e-6, "1 or 2 from shop level 15")
		expect.equal(CustomerTypes.kidUnits(Customers, 0.9999, 30), 2, "never 3 then")
	end,

	["a new shop's customers take all they wanted at market price, one fewer a bit above, one well above"] = function()
		expect.equal(CustomerTypes.unitsAt(Customers, "plain", 4, 3, 3, BANDS, 1), 4, "at market price: all 4")
		expect.equal(CustomerTypes.unitsAt(Customers, "plain", 4, 2.5, 3, BANDS, 1), 4, "below it: all 4")
		expect.equal(CustomerTypes.unitsAt(Customers, "plain", 4, 3.5, 3, BANDS, 1), 3, "a bit above: one fewer")
		expect.equal(CustomerTypes.unitsAt(Customers, "plain", 1, 3.5, 3, BANDS, 1), 1, "never fewer than one")
		expect.equal(CustomerTypes.unitsAt(Customers, "plain", 4, 4.4, 3, BANDS, 1), 1, "well above: just one")
		expect.equal(CustomerTypes.unitsAt(Customers, "bargain", 4, 3.5, 3, BANDS, 1), 4, "a bargain hunter's band is a step higher")
		expect.equal(CustomerTypes.unitsAt(Customers, "plain", 3, 4.4, 3, BANDS, 30), 3, "from shop level 15: all they wanted, like before")
	end,

	["a new shop's customers come about 1.4x as often, fading back by shop level 15"] = function()
		local cfg = Customers.NEW_SHOP
		expect.near(CustomerTypes.newShopGap(Customers, 1), cfg.gap, 1e-6, "level 1")
		expect.near(CustomerTypes.newShopGap(Customers, cfg.fullUntil), cfg.gap, 1e-6, "its last full level")
		expect.equal(CustomerTypes.newShopGap(Customers, cfg.goneAt), 1, "back to normal")
		expect.equal(CustomerTypes.newShopGap(Customers, 60), 1)
		local middle = CustomerTypes.newShopGap(Customers, 12)
		expect.equal(middle > cfg.gap and middle < 1, true, "fading in between")
		expect.equal(1 / cfg.gap >= 1.35 and 1 / cfg.gap <= 1.5, true, "about 1.4x the customers")
	end,
	-- owner 2026-11-20: "In tutorial. when pish says LOOK A CUSTOMER LET THEM SHOP. the customer should always buy so
	-- that players dont have to wait for a buying customer"
	["Pish's customer always buys: whatever the price, whatever the roll"] = function()
		expect.equal(CustomerTypes.decides(Customers, "plain", 100, 10, 0.99, 0, BANDS, true), "buy", "ten times market, the worst roll")
		expect.equal(CustomerTypes.decides(Customers, "plain", 10, 10, 0.99, 0, BANDS, true), "buy")
		-- anyone else decides as before
		expect.equal(CustomerTypes.decides(Customers, "plain", 100, 10, 0, 0, BANDS, false), "pricey", "out of reach: the annoyed bubble")
		expect.equal(CustomerTypes.decides(Customers, "plain", 10, 10, 0, 0, BANDS, false), "buy", "market price, a good roll")
		expect.equal(CustomerTypes.decides(Customers, "plain", 10, 10, 0.9999, 0, BANDS, false), if CustomerTypes.buys(Customers, "plain", 10, 10, 0.9999, 0, BANDS) then "buy" else "pass")
		local sure = Customers.SURE
		assert(sure.browse <= 1, "it doesn't dawdle at the shelf")
		assert(sure.units >= 1, "it takes something")
		assert(Customers.AFTER_PISH_CUSTOMER <= 25, "the shop's own customers follow soon after his")
	end,

	-- owner 2026-11-20: "The prices can be abused. from always buy to sometimes buy specially on boxes take alot of
	-- steps. so the players set prices to the final step of the sometimes buy": the chance was flat across a band, so
	-- its dearest price cost nothing. Now it slides: a band starts at its own chance and ends at the next band's
	["at market price and under, customers almost always buy, as before"] = function()
		expect.equal(CustomerTypes.plainChance(3, 3, BANDS), BANDS[1].chance)
		expect.equal(CustomerTypes.plainChance(1, 3, BANDS), BANDS[1].chance)
		expect.equal(CustomerTypes.plainChance(120, 120, BANDS), BANDS[1].chance)
	end,

	["a band starts at its own chance and ends at the next band's"] = function()
		local function near(a: number, b: number): boolean
			return math.abs(a - b) < 0.012
		end
		assert(near(CustomerTypes.plainChance(1.001, 1, BANDS), BANDS[2].chance), "just over market: Sometimes' chance")
		assert(near(CustomerTypes.plainChance(BANDS[2].maxRatio, 1, BANDS), BANDS[3].chance), "its last step: Rarely's")
		assert(near(CustomerTypes.plainChance(BANDS[3].maxRatio, 1, BANDS), 0), "Rarely's last step: nobody")
		expect.equal(CustomerTypes.plainChance(BANDS[3].maxRatio + 0.01, 1, BANDS), 0, "past every band")
		expect.equal(CustomerTypes.plainChance(5, 0, BANDS), 0, "no market price")
	end,

	["every step up costs buyers: no free steps (the booster box's 96 steps of Sometimes)"] = function()
		local market, step = 120, Pricing.PRICE_STEP
		local last = CustomerTypes.plainChance(market, market, BANDS)
		local lastTakings = market * last
		local price = market + step
		while price <= market * BANDS[#BANDS].maxRatio + 1e-9 do
			local chance = CustomerTypes.plainChance(price, market, BANDS)
			assert(chance < last, `${price}: fewer buy than a step cheaper`)
			assert(price * chance < lastTakings, `${price}: it takes less per customer than a step cheaper`)
			last, lastTakings = chance, price * chance
			price += step
		end
		-- the abused price: the dearest of Sometimes sells like Rarely, not like Sometimes
		local top = CustomerTypes.plainChance(market * BANDS[2].maxRatio, market, BANDS)
		expect.equal(top, BANDS[3].chance, "it sells like Rarely's first step")
		assert(top <= BANDS[2].chance * 0.5, "half of Sometimes' first step at the most")
	end,

	["customer types slide in their own bands"] = function()
		expect.equal(CustomerTypes.chance(Customers, "plain", 1.1, 1, BANDS), CustomerTypes.plainChance(1.1, 1, BANDS))
		expect.equal(CustomerTypes.chance(Customers, "bargain", 1.1, 1, BANDS), BANDS[1].chance, "a band cheaper: its best band, flat")
		local bargain = CustomerTypes.chance(Customers, "bargain", 1.3, 1, BANDS)
		assert(bargain < BANDS[2].chance and bargain > BANDS[3].chance, "a third of the way from Sometimes to Rarely")
		expect.equal(CustomerTypes.chance(Customers, "plain", 1.6, 1, BANDS), 0)
		assert(CustomerTypes.chance(Customers, "bigSpender", 1.6, 1, BANDS) > 0, "one band more")
	end,

	["the Prices window says how many buy at this price"] = function()
		local never = Pricing.NEVER_TAG
		expect.equal(CustomerTypes.priceTag(3, 3, BANDS, never), BANDS[1].tag, "market price: the band's own words")
		expect.equal(CustomerTypes.priceTag(3.3, 3, BANDS, never), "48% buy", "half way up Sometimes")
		expect.equal(CustomerTypes.priceTag(3.6, 3, BANDS, never), "30% buy")
		expect.equal(CustomerTypes.priceTag(4.4, 3, BANDS, never), "3% buy")
		expect.equal(CustomerTypes.priceTag(4.5, 3, BANDS, never), never, "nobody buys: say so")
		expect.equal(CustomerTypes.priceTag(9, 3, BANDS, never), never)
		for cents = 300, 460 do
			assert(#CustomerTypes.priceTag(cents / 100, 3, BANDS, never) <= 10, "fits the row's tag")
		end
	end,

	-- owner 2026-11-20: "also do the same with glass prices": a card in a Glass Showcase steps 10% of its market value
	-- a tap (Config/Showcase PRICE_STEP_RATIO), and both steps of Sometimes sold at 50%
	["a card's price steps in a Glass Showcase cost buyers too"] = function()
		local market, step = 40, 4
		local last = CustomerTypes.plainChance(market, market, BANDS)
		for taps = 1, 5 do
			local chance = CustomerTypes.plainChance(market + step * taps, market, BANDS)
			assert(chance < last, `{taps} taps up: fewer buy than a tap cheaper`)
			last = chance
		end
		expect.equal(CustomerTypes.priceTag(market + step, market, BANDS, Pricing.NEVER_TAG), "48% buy", "110% of market")
		expect.equal(CustomerTypes.priceTag(market + 2 * step, market, BANDS, Pricing.NEVER_TAG), "30% buy", "120%")
		expect.equal(CustomerTypes.priceTag(market + 5 * step, market, BANDS, Pricing.NEVER_TAG), Pricing.NEVER_TAG, "150%")
	end,

	-- owner 2026-11-20, a few hours after the sliding chance: "Rework prices. make it a little bit more forgiving"
	["a little over market still sells: about two in three just over it, about one in three at +20%"] = function()
		expect.equal(BANDS[1].chance, 0.95, "market price as before")
		expect.equal(BANDS[2].chance, 0.65)
		expect.equal(BANDS[3].chance, 0.3)
		assert(CustomerTypes.plainChance(1.1, 1, BANDS) >= 0.45, "+10%: nearly half")
		assert(CustomerTypes.plainChance(1.35, 1, BANDS) >= 0.14, "+35%: still some")
		expect.equal(CustomerTypes.plainChance(1.51, 1, BANDS), 0, "past +50%: nobody, as before")
	end,

	-- owner 2026-11-21: "lets add occasional tips from customers. to slightly boost gold earn"
	["a plain customer tips now and then when every price was fair; a big spender always"] = function()
		local tips = Customers.TIPS
		assert(tips.chance >= 0.1 and tips.chance <= 0.2, "occasional")
		assert(tips.share[1] >= 0.05 and tips.share[2] <= 0.25 and tips.share[1] < tips.share[2], "a little extra")
		-- the roll under the chance: a share of the total between the two ends, to the cent
		expect.equal(CustomerTypes.tip(Customers, "plain", 10, true, 0, 0), math.round(10 * tips.share[1] * 100) / 100)
		expect.equal(CustomerTypes.tip(Customers, "plain", 10, true, 0, 1), math.round(10 * tips.share[2] * 100) / 100)
		expect.equal(CustomerTypes.tip(Customers, "plain", 10, true, tips.chance, 0.5), 0, "the chance missed")
		expect.equal(CustomerTypes.tip(Customers, "plain", 10, true, 0.99, 0.5), 0)
		-- never when a price was over market, never on nothing
		expect.equal(CustomerTypes.tip(Customers, "plain", 10, false, 0, 0.5), 0)
		expect.equal(CustomerTypes.tip(Customers, "plain", 0, true, 0, 0.5), 0)
		-- a small sale still leaves something worth a toast
		expect.equal(CustomerTypes.tip(Customers, "plain", 1, true, 0, 0), tips.min)
		-- the others: a kid's pocket money, a collector's card and a bargain hunter's deal leave none
		for _, kind in { "kid", "collector", "bargain" } do
			expect.equal(CustomerTypes.tip(Customers, kind, 10, true, 0, 0.5), 0, kind)
		end
		-- the big spender's sure tip, as before (BIG_SPENDER.tip of the total at fair prices)
		expect.equal(CustomerTypes.tip(Customers, "bigSpender", 120, true, 0.99, 0.5), 12)
		expect.equal(CustomerTypes.tip(Customers, "bigSpender", 120, false, 0, 0.5), 0)
		-- "slightly": plain customers' tips add under 3% to their sales
		local average = tips.chance * (tips.share[1] + tips.share[2]) / 2
		assert(average > 0.01 and average < 0.03, `{average} of a plain customer's sales`)
	end,
}
