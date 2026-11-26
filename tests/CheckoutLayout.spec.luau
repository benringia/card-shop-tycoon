--!strict
-- The movable register (testers 2026-11-26: "Make the cash register Moveable", the owner's pick A): the checkout moves
-- as one box on the shop's grid, the counter, its cashier step behind and the customers' queue in front
local CheckoutLayout = require("../src/shared/Util/CheckoutLayout")
local expect = require("./lib/expect")

return {
	["the checkout's box: the counter, its step behind and the queue in front"] = function()
		local box = CheckoutLayout.box({ x = 6, z = 2 }, { width = 5, depth = 2.6 }, 1.6, { width = 4, length = 18 })
		expect.near(box.width, 6, 1e-9, "as wide as its widest piece (the counter)")
		expect.near(box.depth, 22.9, 1e-9, "the queue's 18, the counter's 2 and the step's 2.9")
		expect.near(box.registerZ, 7.55, 1e-9, "the counter toward the back, the queue filling the front")
		local wide = CheckoutLayout.box({ x = 6, z = 2 }, { width = 8, depth = 2.6 }, 1.6, { width = 4, length = 18 })
		expect.near(wide.width, 8, 1e-9, "a wider step widens it")
	end,

	["the box from the configs, and the ghost's pieces where the real ones stand"] = function()
		local plots = { REGISTER_SIZE = { X = 6, Y = 2.5, Z = 2 }, QUEUE_ZONE_WIDTH = 4, QUEUE_ZONE_LENGTH = 18 }
		local town = { COUNTER = { STEP = { width = 5, depth = 2.6, height = 1 }, STAFF_BEHIND = 1.6 } }
		local box = CheckoutLayout.fromConfig(plots, town)
		expect.near(box.depth, 22.9, 1e-9)
		local pieces = CheckoutLayout.pieces(plots, town, box)
		local byName = {}
		for _, piece in pieces do
			byName[piece.name] = piece
		end
		expect.near(byName.Counter.z, 7.55, 1e-9, "the counter at the box's back half")
		expect.near(byName.Counter.y, 0, 1e-9, "as high as the box")
		expect.near(byName.Step.z, 7.55 + 1 + 1.6, 1e-9, "the step behind the counter, where the cashier stands")
		expect.near(byName.Step.y, -2.5 / 2 + 0.5, 1e-9, "on the floor")
		expect.near(byName.Queue.z, 7.55 - 10, 1e-9, "the queue in front, its far end the box's front")
		expect.near(byName.Queue.z - byName.Queue.d / 2, -22.9 / 2, 1e-9)
		expect.near(byName.Step.z + byName.Step.d / 2, 22.9 / 2, 1e-9, "the step's back the box's back")
	end,

	["the checkout stays in the hall, clear of the rooms' wall"] = function()
		expect.equal(CheckoutLayout.inHall(7, 12, 20), true, "the default spot")
		expect.equal(CheckoutLayout.inHall(8, 12, 20), true, "its back on the hall's last row")
		expect.equal(CheckoutLayout.inHall(9, 12, 20), false, "into the rooms' wall")
		expect.equal(CheckoutLayout.inHall(-1, 12, 20), false, "past the street")
		expect.equal(CheckoutLayout.inHall(0, 3, 20), true, "turned: 3 deep at the front")
	end,
}
