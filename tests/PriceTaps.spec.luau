--!strict
-- A price being tapped (the Prices window's - and +, a card case's): owner 2026-11-20, "Fix boosterbox price also:
-- pressing the + and - sometimes goes down suddenly". The taps were forgotten the moment they were sent, so until the
-- server's price came back the window showed the old price, and a tap in that gap started again from it: twenty taps
-- up, a pause, one more tap, and the price fell back to one step over where it began.
local PriceTaps = require("../src/shared/Util/PriceTaps")
local Pricing = require("../src/shared/Config/Pricing")
local expect = require("./lib/expect")

local WAIT = Pricing.ECHO_SECONDS

return {
	["a tapped price shows at once"] = function()
		local taps = PriceTaps.new(WAIT)
		expect.equal(PriceTaps.shown(taps, "FirstSparkBox", 120, 0), 120, "the server's price")
		PriceTaps.tap(taps, "FirstSparkBox", 120.25)
		expect.equal(PriceTaps.shown(taps, "FirstSparkBox", 120, 0), 120.25)
		expect.equal(PriceTaps.shown(taps, "DeckBox", 9, 0), 9, "another product keeps its own")
	end,

	["a sent price keeps showing until the server's comes back (the sudden drop)"] = function()
		local taps = PriceTaps.new(WAIT)
		PriceTaps.tap(taps, "FirstSparkBox", 125)
		local sent = PriceTaps.flush(taps, 10)
		expect.equal(sent and sent.FirstSparkBox, 125, "what goes to the server")
		-- the server still says 120 for a moment
		expect.equal(PriceTaps.shown(taps, "FirstSparkBox", 120, 10.1), 125, "not back to the old price")
		-- a tap in that moment goes on from the price shown
		PriceTaps.tap(taps, "FirstSparkBox", PriceTaps.shown(taps, "FirstSparkBox", 120, 10.1) + Pricing.PRICE_STEP)
		expect.equal(PriceTaps.shown(taps, "FirstSparkBox", 120, 10.2), 125.25)
		-- the first send comes back while the new tap waits
		expect.equal(PriceTaps.shown(taps, "FirstSparkBox", 125, 10.3), 125.25)
		local again = PriceTaps.flush(taps, 10.6)
		expect.equal(again and again.FirstSparkBox, 125.25)
		expect.equal(PriceTaps.shown(taps, "FirstSparkBox", 125, 10.7), 125.25, "the second send on its way")
		expect.equal(PriceTaps.shown(taps, "FirstSparkBox", 125.25, 10.8), 125.25, "arrived")
	end,

	["nothing to send, nothing sent"] = function()
		local taps = PriceTaps.new(WAIT)
		expect.isNil(PriceTaps.flush(taps, 0))
		PriceTaps.tap(taps, 3, 12)
		expect.equal((PriceTaps.flush(taps, 0) :: any)[3], 12, "a card case's slots are numbers")
		expect.isNil(PriceTaps.flush(taps, 0.1), "only once")
	end,

	["a price the server changed or refused shows the server's after a moment"] = function()
		local taps = PriceTaps.new(WAIT)
		PriceTaps.tap(taps, "FirstSparkBox", 999)
		PriceTaps.flush(taps, 0)
		expect.equal(PriceTaps.shown(taps, "FirstSparkBox", 120, WAIT - 0.1), 999, "still waiting")
		expect.equal(PriceTaps.shown(taps, "FirstSparkBox", 360, WAIT + 0.1), 360, "the server's word")
		expect.equal(PriceTaps.shown(taps, "FirstSparkBox", 360, 0.5), 360, "and it stays the server's")
	end,

	["once the server's price has arrived, a later change of it shows (another window, a reset)"] = function()
		local taps = PriceTaps.new(WAIT)
		PriceTaps.tap(taps, "FirstSparkBox", 125)
		PriceTaps.flush(taps, 0)
		expect.equal(PriceTaps.shown(taps, "FirstSparkBox", 125, 0.2), 125)
		expect.equal(PriceTaps.shown(taps, "FirstSparkBox", 130, 0.4), 130)
	end,

	["forgetting a key or everything"] = function()
		local taps = PriceTaps.new(WAIT)
		PriceTaps.tap(taps, 1, 5)
		PriceTaps.tap(taps, 2, 6)
		PriceTaps.flush(taps, 0)
		PriceTaps.tap(taps, 2, 7)
		PriceTaps.forget(taps, 2)
		expect.equal(PriceTaps.shown(taps, 2, 1, 0.1), 1)
		expect.equal(PriceTaps.shown(taps, 1, 1, 0.1), 5)
		PriceTaps.forget(taps, nil)
		expect.equal(PriceTaps.shown(taps, 1, 1, 0.1), 1)
	end,

	["the wait for the server is short"] = function()
		assert(WAIT >= 1 and WAIT <= 5, "long enough for a slow connection, short enough to notice a refusal")
	end,
}
