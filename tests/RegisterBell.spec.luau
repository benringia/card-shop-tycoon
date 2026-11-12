--!strict
-- Owner 2026-11-12: "when a customer is at the cashier and there's no one there. play a 'Ding' sound then notification
-- 'someone is at the register'" (Util/RegisterBell, RegisterService)
local RegisterBell = require("../src/shared/Util/RegisterBell")
local cfg = require("../src/shared/Config/RegisterBell")
local expect = require("./lib/expect")

local function waiting(over: any): any
	local base = { now = 0, lastProgressAt = 0, lastRangAt = nil, rings = 0, attended = false, outOfTown = false }
	for key, value in over do
		base[key] = value
	end
	return base
end

return {
	-- owner 2026-11-12: "notification on cashier should only [show] once every two dings"
	["the bell's toast shows on every other ring, the first included"] = function()
		expect.equal(RegisterBell.says(1, cfg), true, "the first ding tells you why")
		expect.equal(RegisterBell.says(2, cfg), false, "the next one only rings")
		expect.equal(RegisterBell.says(3, cfg), true, "then the toast again")
		expect.equal(cfg.toastEvery, 2)
	end,

	["a customer waiting with nobody scanning rings once the grace is over"] = function()
		expect.equal(RegisterBell.due(waiting({ now = cfg.grace - 0.1 }), cfg), false, "a cashier gets its moment to start")
		expect.equal(RegisterBell.due(waiting({ now = cfg.grace }), cfg), true, "nobody came: ding")
	end,

	-- owner 2026-11-12: "the cashier bell ring should only be heard when I'm in town. also lower the volume"
	["no ring while you're out of town (the Wild), and a soft bell"] = function()
		expect.equal(RegisterBell.due(waiting({ now = 30, outOfTown = true }), cfg), false, "in the Wild: quiet")
		expect.equal(RegisterBell.due(waiting({ now = 30, outOfTown = false }), cfg), true, "in town: it rings")
		expect.equal(cfg.sound.volume <= 0.3, true, "softer than the first 0.5")
	end,

	["no ring while you're behind the counter or something was just scanned"] = function()
		expect.equal(RegisterBell.due(waiting({ now = 30, attended = true }), cfg), false, "you're there")
		expect.equal(RegisterBell.due(waiting({ now = 30, lastProgressAt = 29 }), cfg), false, "a cashier is scanning")
	end,

	["it rings again now and then while nobody comes, a few times at most"] = function()
		local first = cfg.grace
		expect.equal(RegisterBell.due(waiting({ now = first + cfg.every - 1, lastRangAt = first, rings = 1 }), cfg), false, "not straight again")
		expect.equal(RegisterBell.due(waiting({ now = first + cfg.every, lastRangAt = first, rings = 1 }), cfg), true, "a reminder")
		expect.equal(RegisterBell.due(waiting({ now = 1000, lastRangAt = 0, rings = cfg.max }), cfg), false, "then it stops")
		expect.equal(cfg.max >= 2 and cfg.every >= 10, true, "a reminder or two, not a nag")
	end,
}
