--!strict
-- Shop workers get tired now and then (owner 2026-11-06): after a stretch of work a Restocker or Cashier works slower
-- for a while, never stopping, then it's back to normal; the owner can step in at the register meanwhile
local TiredRules = require("../src/shared/Util/TiredRules")
local Jobs = require("../src/shared/Config/Jobs")
local expect = require("./lib/expect")

local TIRED = Jobs.TIRED

return {
	["a worker starts rested, with a stretch of work before it tires"] = function()
		local early = TiredRules.start(TIRED, 0)
		local late = TiredRules.start(TIRED, 1)
		expect.equal(early.workLeft, TIRED.every[1])
		expect.equal(late.workLeft, TIRED.every[2])
		expect.equal(early.tiredLeft, 0)
		expect.equal(TiredRules.isTired(early), false)
	end,

	["after its stretch of work it tires, for TIRED.seconds"] = function()
		local clock = { workLeft = 10, tiredLeft = 0 }
		local after, event = TiredRules.step(clock, 4, TIRED, 0.5)
		expect.equal(event, nil)
		expect.equal(after.workLeft, 6)
		local tired, turned = TiredRules.step(after, 6, TIRED, 0.5)
		expect.equal(turned, "tired")
		expect.equal(TiredRules.isTired(tired), true)
		expect.equal(tired.tiredLeft, TIRED.seconds)
	end,

	["then it's rested and works a new stretch"] = function()
		local clock = { workLeft = 0, tiredLeft = 3 }
		local still, none = TiredRules.step(clock, 2, TIRED, 0)
		expect.equal(none, nil)
		expect.equal(TiredRules.isTired(still), true)
		local rested, event = TiredRules.step(still, 1, TIRED, 0)
		expect.equal(event, "rested")
		expect.equal(TiredRules.isTired(rested), false)
		expect.equal(rested.workLeft, TIRED.every[1])
	end,

	["tired, it works slower and slips up more, but never stops"] = function()
		expect.equal(TiredRules.speed(TIRED, false), 1)
		expect.equal(TiredRules.speed(TIRED, true), TIRED.speed)
		assert(TIRED.speed > 0.3 and TIRED.speed < 1, "slower, still working")
		expect.equal(TiredRules.mistake(TIRED, 0.1, false), 0.1)
		expect.near(TiredRules.mistake(TIRED, 0.1, true), 0.1 * TIRED.mistakes, 1e-9)
		expect.equal(TiredRules.mistake(TIRED, 0.9, true), TIRED.mistakeCap, "capped")
	end,

	["about five tired minutes after every 10-15 of work (owner's numbers)"] = function()
		expect.equal(TIRED.seconds, 300)
		assert(TIRED.every[1] >= 600 and TIRED.every[2] <= 900, "10-15 minutes of work between")
	end,
}
