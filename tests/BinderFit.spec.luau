--!strict
local BinderFit = require("../src/shared/Util/BinderFit")
local expect = require("./lib/expect")
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local equal, near = expect.equal, expect.near
local L: BinderFit.Layout = { columns = 3, rows = 3, padX = 0.05, padY = 0.04, gap = 0.03 }
local VIEW = { w = 1000, h = 500 }

return {
	["pocketBox: pockets inside the pads, gaps between them"] = function()
		local first = BinderFit.pocketBox(1, L)
		near(first.u0, 0.05, 1e-9, "first left")
		near(first.v0, 0.04, 1e-9, "first top")
		near(first.u1, 0.33, 1e-9, "first right")
		near(first.v1, 0.04 + 0.86 / 3, 1e-9, "first bottom")
		local last = BinderFit.pocketBox(9, L)
		near(last.u1, 0.95, 1e-9, "last right")
		near(last.v1, 0.96, 1e-9, "last bottom")
	end,
	["pocketAt: the pocket under a point, nil in pads and gaps"] = function()
		equal(BinderFit.pocketAt(0.1, 0.1, L), 1, "top left")
		equal(BinderFit.pocketAt(0.5, 0.5, L), 5, "middle")
		equal(BinderFit.pocketAt(0.9, 0.9, L), 9, "bottom right")
		expect.isNil(BinderFit.pocketAt(0.345, 0.1, L), "the gap between pockets 1 and 2")
		expect.isNil(BinderFit.pocketAt(0.02, 0.5, L), "the left pad")
		expect.isNil(BinderFit.pocketAt(1.2, 0.5, L), "off the page")
		for index = 1, 9 do
			local box = BinderFit.pocketBox(index, L)
			equal(BinderFit.pocketAt((box.u0 + box.u1) / 2, (box.v0 + box.v1) / 2, L), index, `pocket {index}'s centre`)
		end
	end,
	["distance: the camera distance that fits the binder in the rect"] = function()
		near(BinderFit.distance({ w = 4, h = 2 }, VIEW, VIEW, 60, 0), 1.7320508, 1e-5, "fills the view")
		near(BinderFit.distance({ w = 4, h = 2 }, { w = 500, h = 250 }, VIEW, 60, 0), 3.4641016, 1e-5, "half the view: twice as far")
		near(BinderFit.distance({ w = 4, h = 2 }, VIEW, VIEW, 60, 60), 1.7320508, 1e-5, "tilted: the width binds")
	end,
	["shift: the binder's centre lands on the rect's centre"] = function()
		local dx, dy = BinderFit.shift({ x = 0, y = 0, w = 1000, h = 500 }, VIEW, 1.7320508, 60)
		near(dx, 0, 1e-9, "centred x")
		near(dy, 0, 1e-9, "centred y")
		dx, dy = BinderFit.shift({ x = 600, y = 250, w = 400, h = 250 }, VIEW, 1.7320508, 60)
		near(dx, 1.2, 1e-5, "right of centre")
		near(dy, -0.5, 1e-5, "below centre")
	end,
	["every rule exists as soon as the module loads (none nested inside another)"] = function()
		local fresh = luau.load(luau.compile(fs.readFile("src/shared/Util/BinderFit.luau")), { debugName = "BinderFit" })()
		for _, name in { "pocketBox", "pocketAt", "distance", "shift" } do
			equal(typeof(fresh[name]), "function", name)
		end
	end,
}
