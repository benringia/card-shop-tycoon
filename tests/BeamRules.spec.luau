--!strict
local BeamRules = require("../src/shared/Util/BeamRules")
local Dungeon = require("../src/shared/Config/Dungeon")
local expect = require("./lib/expect")

return {
	["trace: a straight beam reaches a prism in line"] = function()
		local layout = { width = 5, height = 1, gem = { x = 1, y = 1, dir = 0 }, prism = { x = 5, y = 1 }, mirrors = {} }
		local out = BeamRules.trace(layout, {})
		expect.equal(out.reached, true, "reached")
		expect.equal(#out.path, 5, "every cell, the gem's first")
		expect.equal(out.path[1].x, 1, "starts at the gem")
	end,

	["trace: a mirror turns the beam; its back stops it"] = function()
		local layout = { width = 3, height = 3, gem = { x = 1, y = 1, dir = 0 }, prism = { x = 3, y = 3 }, mirrors = { { x = 3, y = 1, facing = 1 } } }
		-- in through side 2 (-x); facing 2 connects sides 2 and 3: travels -y, off the grid
		expect.equal(BeamRules.trace(layout, { 2 }).reached, false, "wrong facing")
		-- facing 1 connects sides 1 and 2: in through 2, out toward +y, down to the prism
		expect.equal(BeamRules.trace(layout, { 1 }).reached, true, "right facing")
		local back = BeamRules.trace(layout, { 0 })
		expect.equal(back.reached, false, "back of the mirror stops it")
		expect.equal(back.path[#back.path].x, 3, "stops at the mirror")
	end,

	["trace: off the grid stops at the last cell"] = function()
		local layout = { width = 3, height = 2, gem = { x = 1, y = 1, dir = 0 }, prism = { x = 1, y = 2 }, mirrors = {} }
		local out = BeamRules.trace(layout, {})
		expect.equal(out.reached, false, "missed")
		expect.equal(#out.path, 3, "to the wall")
	end,

	["trace: a loop of mirrors ends"] = function()
		-- gem (2,1) east -> (3,1) south -> (3,2) west -> (2,2) -> (1,2) north -> (1,1) east -> back at the gem going east
		local layout = {
			width = 3,
			height = 2,
			gem = { x = 2, y = 1, dir = 0 },
			prism = { x = 9, y = 9 },
			mirrors = { { x = 3, y = 1, facing = 1 }, { x = 3, y = 2, facing = 2 }, { x = 1, y = 2, facing = 3 }, { x = 1, y = 1, facing = 0 } },
		}
		local out = BeamRules.trace(layout, { 1, 2, 3, 0 })
		expect.equal(out.reached, false, "no prism, no hang")
		expect.equal(#out.path <= 3 * 2 * 4, true, "stopped on the repeat")
	end,

	["turn: a quarter, round and round"] = function()
		expect.equal(BeamRules.turn(0), 1, "0 -> 1")
		expect.equal(BeamRules.turn(3), 0, "3 -> 0")
	end,

	["solvable: finds a way or says none"] = function()
		local ok = { width = 3, height = 3, gem = { x = 1, y = 1, dir = 0 }, prism = { x = 3, y = 3 }, mirrors = { { x = 3, y = 1, facing = 0 } } }
		expect.equal(BeamRules.solvable(ok), true, "a turn away")
		local blocked = { width = 3, height = 3, gem = { x = 1, y = 1, dir = 0 }, prism = { x = 1, y = 3 }, mirrors = {} }
		expect.equal(BeamRules.solvable(blocked), false, "no mirror can reach it")
	end,

	["layouts: three, 4 mirrors each, not solved at the start, solvable, inside the grid"] = function()
		expect.equal(#Dungeon.BEAMS.LAYOUTS, 3, "three")
		for index, layout in Dungeon.BEAMS.LAYOUTS do
			expect.equal(#layout.mirrors, 4, `layout {index} mirrors`)
			local start = {}
			for i, mirror in layout.mirrors do
				start[i] = mirror.facing
				expect.equal(mirror.x >= 1 and mirror.x <= layout.width and mirror.y >= 1 and mirror.y <= layout.height, true, `layout {index} mirror {i} on the grid`)
			end
			expect.equal(BeamRules.trace(layout, start).reached, false, `layout {index} unsolved at start`)
			expect.equal(BeamRules.solvable(layout), true, `layout {index} solvable`)
		end
	end,

	["layouts: every mirror is needed (turning any one off the solution breaks it)"] = function()
		for index, layout in Dungeon.BEAMS.LAYOUTS do
			local solution = BeamRules.solve(layout) :: { number }
			expect.equal(solution ~= nil, true, `layout {index} has a solution`)
			for i in layout.mirrors do
				local changed = table.clone(solution)
				local broken = true
				for _ = 1, 3 do
					changed[i] = BeamRules.turn(changed[i])
					if BeamRules.trace(layout, changed).reached then
						broken = false
					end
				end
				expect.equal(broken, true, `layout {index} mirror {i} on the path`)
			end
		end
	end,
}
