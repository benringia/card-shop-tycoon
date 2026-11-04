--!strict
-- Which of your sword actions is still live (Util/SwingGate; final review of the sword-moves round): a dodge, the dash
-- slash, a knock-down or the fight's end cancels a cut that was queued for its cancel point, no cut starts while the
-- dash slash plays, and a big hit is the cut that struck, not the latest tap
local SwingGate = require("../src/shared/Util/SwingGate")
local expect = require("./lib/expect")

return {
	["a dodge cancels a queued cut"] = function()
		local gate = SwingGate.new()
		local queued = SwingGate.begin(gate)
		SwingGate.cancel(gate)
		expect.equal(SwingGate.live(gate, queued), false)
	end,

	["a newer action takes over from the last"] = function()
		local gate = SwingGate.new()
		local first = SwingGate.begin(gate)
		local second = SwingGate.begin(gate)
		expect.equal(SwingGate.live(gate, first), false, "the older one")
		expect.equal(SwingGate.live(gate, second), true, "the newest")
	end,

	["no cut starts while the dash slash plays"] = function()
		local gate = SwingGate.new()
		expect.equal(SwingGate.canAttack(gate, 10), true, "nothing playing")
		SwingGate.startSkill(gate, 10, 1.0)
		expect.equal(SwingGate.canAttack(gate, 10.5), false, "mid dash slash")
		expect.equal(SwingGate.canAttack(gate, 11.0), true, "once it ends")
	end,

	["a dodge out of the dash slash frees the attack button"] = function()
		local gate = SwingGate.new()
		local skill = SwingGate.startSkill(gate, 10, 1.0)
		SwingGate.cancel(gate)
		expect.equal(SwingGate.canAttack(gate, 10.2), true)
		expect.equal(SwingGate.live(gate, skill), false, "the dash slash stops")
	end,

	["a big hit is the cut that struck, not the latest tap"] = function()
		local gate = SwingGate.new()
		expect.isNil(SwingGate.lastStruck(gate))
		SwingGate.struck(gate, 3)
		SwingGate.begin(gate) -- a mash tap queues cut 1 while the finisher's hit is on its way back from the server
		expect.equal(SwingGate.lastStruck(gate), 3)
		SwingGate.struck(gate, 1)
		expect.equal(SwingGate.lastStruck(gate), 1)
	end,
}
