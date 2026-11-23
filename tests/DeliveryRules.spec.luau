--!strict
-- Deliveries (owner 2026-11-23, mockups A + 1 + 3: "go A with 1 and 3"): the packenship.co van's trip down the street,
-- its stop by the pad, the boxes hopping out, and the packs hopping onto a shelf
local DeliveryRules = require("../src/shared/Util/DeliveryRules")
local Delivery = require("../src/shared/Config/Delivery")
local expect = require("./lib/expect")

local TRIP = Delivery.TRIP

return {
	["the van stops on the lane past the curb: 6.75 studs out from the pad's centre"] = function()
		-- the pad's centre is 4.6 studs out from the shop's footprint (wall 1, gap 0.6, half its 6), the sidewalk 8 wide
		expect.near(DeliveryRules.laneOffset({ padCentre = 4.6, sidewalk = 8, curb = Delivery.VAN.curb, vanWidth = Delivery.VAN.width }), 6.75, 0.01)
	end,

	["boxes leave the van one after another, the first a moment after it stops"] = function()
		local times = DeliveryRules.hopTimes(3, TRIP)
		expect.equal(#times, 3)
		expect.near(times[1], TRIP.firstHop, 1e-6)
		expect.near(times[2] - times[1], TRIP.hopGap, 1e-6)
		expect.near(times[3] - times[2], TRIP.hopGap, 1e-6)
		expect.equal(#DeliveryRules.hopTimes(0, TRIP), 0)
	end,

	["the van waits for the last box to land, then a little more, before it drives off"] = function()
		local one = DeliveryRules.stay(1, TRIP)
		expect.near(one, TRIP.firstHop + TRIP.hopTime + TRIP.linger, 1e-6)
		expect.near(DeliveryRules.stay(12, TRIP) - one, 11 * TRIP.hopGap, 1e-6)
		assert(DeliveryRules.stay(12, TRIP) < 8, "a full pad's 12 boxes still under 8 s at the curb")
	end,

	["it slows into the stop, stands still, then speeds away: never jumping"] = function()
		local arrive, leave = 100, 104
		expect.equal(DeliveryRules.offset(arrive, arrive, leave, TRIP), 0)
		expect.equal(DeliveryRules.offset(102, arrive, leave, TRIP), 0)
		expect.equal(DeliveryRules.offset(leave, arrive, leave, TRIP), 0)
		assert(DeliveryRules.offset(arrive - 1, arrive, leave, TRIP) < 0, "coming: before the stop")
		assert(DeliveryRules.offset(leave + 1, arrive, leave, TRIP) > 0, "going: past the stop")
		local last = DeliveryRules.offset(arrive - 10, arrive, leave, TRIP)
		local step = 1 / 60
		local t = arrive - 10
		while t < leave + 10 do
			t += step
			local now = DeliveryRules.offset(t, arrive, leave, TRIP)
			assert(now >= last - 1e-9, `never backwards at {t}`)
			assert(now - last <= TRIP.speed * step + 1e-6, `never faster than its speed at {t}`)
			last = now
		end
		-- gentle: the last stretch before the stop is slower than the cruise
		local nearStop = -DeliveryRules.offset(arrive - 0.1, arrive, leave, TRIP)
		assert(nearStop < TRIP.speed * 0.1, "slowing down at the end")
	end,

	["it comes from the street's end behind it and leaves by the one ahead"] = function()
		local route = DeliveryRules.route(-64, 1, 110, Delivery.STREET.endInset)
		expect.near(route.inDistance, 110 - Delivery.STREET.endInset - 64, 1e-6, "from x -106 to -64")
		expect.near(route.outDistance, 64 + 110 - Delivery.STREET.endInset, 1e-6)
		local back = DeliveryRules.route(-64, -1, 110, Delivery.STREET.endInset)
		expect.near(back.inDistance, 64 + 110 - Delivery.STREET.endInset, 1e-6, "driving the other way it comes from x 106")
	end,

	["it shows only while on the street, fading in and out at its ends"] = function()
		local route = { inDistance = 40, outDistance = 160 }
		local fade = Delivery.STREET.fade
		expect.equal(DeliveryRules.opacity(-41, route, fade), 0, "not on the street yet")
		expect.equal(DeliveryRules.opacity(-40, route, fade), 0, "just appearing")
		expect.equal(DeliveryRules.opacity(-20, route, fade), 1)
		expect.equal(DeliveryRules.opacity(0, route, fade), 1)
		expect.equal(DeliveryRules.opacity(161, route, fade), 0, "gone")
		local mid = DeliveryRules.opacity(-40 + fade / 2, route, fade)
		assert(mid > 0 and mid < 1, "half faded in")
	end,

	["a quick delivery (Pish's 1 s) still arrives on time: the van starts partway down the street"] = function()
		local arrive = 10
		local start = arrive - 1 -- ordered 1 s before
		local offset = DeliveryRules.offset(start, arrive, arrive + 2, TRIP)
		assert(-offset < 40, "already close to the stop when it shows")
		assert(-offset > 0, "still coming")
	end,

	["a box flies on an arc from the van's door to its place on the pad"] = function()
		local from = { x = 0, y = 3, z = 0 }
		local to = { x = 0, y = 1, z = -6 }
		local start = DeliveryRules.hopPoint(from, to, 0, Delivery.HOP.peak)
		local finish = DeliveryRules.hopPoint(from, to, 1, Delivery.HOP.peak)
		expect.near(start.y, 3, 1e-6)
		expect.near(finish.z, -6, 1e-6)
		expect.near(finish.y, 1, 1e-6)
		local mid = DeliveryRules.hopPoint(from, to, 0.5, Delivery.HOP.peak)
		assert(mid.y > 3, "over the van's door at its middle")
	end,

	["unboxing: a box's units split into a few hopping packs that add up"] = function()
		local function sum(list: { number }): number
			local total = 0
			for _, value in list do
				total += value
			end
			return total
		end
		local max = Delivery.UNBOX.items
		for _, added in { 1, 3, 6, 7, 20, 24, 48, 96 } do
			local shares = DeliveryRules.shares(added, max)
			expect.equal(sum(shares), added, `{added}`)
			assert(#shares <= max and #shares >= 1, `{added}: 1 to {max} packs`)
			for index = 2, #shares do
				assert(shares[index] <= shares[index - 1], "the bigger shares first")
				assert(shares[1] - shares[index] <= 1, "as even as they can be")
			end
		end
		expect.equal(#DeliveryRules.shares(0, max), 0)
	end,

	["the waiting chip in plain words"] = function()
		expect.equal(DeliveryRules.waitingWords(1), "1 box waiting")
		expect.equal(DeliveryRules.waitingWords(3), "3 boxes waiting")
	end,

	-- owner 2026-11-24: "make this pill visible only when a player is near it"
	["the waiting chip shows only while you stand near your pad, with no flicker at the edge"] = function()
		local CHIP = Delivery.CHIP
		expect.equal(CHIP.near < CHIP.far, true, "it hides a little farther out than it shows")
		expect.equal(DeliveryRules.chipShows(3, CHIP.near - 1, false, CHIP), true, "walking up to the pad")
		expect.equal(DeliveryRules.chipShows(3, CHIP.near + 1, false, CHIP), false, "not yet near")
		expect.equal(DeliveryRules.chipShows(3, CHIP.near + 1, true, CHIP), true, "shown: stays until past `far`")
		expect.equal(DeliveryRules.chipShows(3, CHIP.far + 1, true, CHIP), false, "walked away")
		expect.equal(DeliveryRules.chipShows(0, 2, true, CHIP), false, "no boxes waiting")
		expect.equal(DeliveryRules.chipShows(3, nil, true, CHIP), false, "no character or pad")
	end,
}
