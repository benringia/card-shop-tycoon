--!strict
local CellSearch = require("../src/shared/Util/CellSearch")
local expect = require("./lib/expect")

return {
	["the start cell comes first, then its neighbours"] = function()
		local cells = CellSearch.byDistance(5, 5, 10, 10)
		expect.equal(cells[1].x, 5, "first x")
		expect.equal(cells[1].z, 5, "first z")
		local second = cells[2]
		expect.equal(math.abs(second.x - 5) + math.abs(second.z - 5), 1, "second is next door")
	end,

	["every cell in the area is tried exactly once"] = function()
		local cells = CellSearch.byDistance(0, 0, 4, 3)
		expect.equal(#cells, 20, "5 x 4 cells (0..4, 0..3)")
		local seen: { [string]: boolean } = {}
		for _, cell in cells do
			local key = `{cell.x},{cell.z}`
			assert(not seen[key], `{key} twice`)
			seen[key] = true
			assert(cell.x >= 0 and cell.x <= 4 and cell.z >= 0 and cell.z <= 3, `{key} out of range`)
		end
	end,

	["cells come out nearest first"] = function()
		local cells = CellSearch.byDistance(2, 2, 6, 6)
		local last = -1
		for _, cell in cells do
			local distance = (cell.x - 2) ^ 2 + (cell.z - 2) ^ 2
			assert(distance >= last, "out of order")
			last = distance
		end
	end,

	["a start outside the area is clamped in"] = function()
		local cells = CellSearch.byDistance(30, -4, 10, 10)
		expect.equal(cells[1].x, 10, "clamped x")
		expect.equal(cells[1].z, 0, "clamped z")
	end,

	-- a new shelf's preview starts on the free cell nearest a spot in view (spec 2026-11-25-pish-first-steps-design 5)
	["the nearest free cell within reach"] = function()
		local onlyOne = function(x: number, z: number): boolean
			return x == 7 and z == 5
		end
		local found = CellSearch.nearest(5, 5, 10, 10, 3, onlyOne)
		expect.equal(found and found.x, 7)
		expect.equal(found and found.z, 5)
		expect.equal(CellSearch.nearest(5, 5, 10, 10, 1, onlyOne), nil, "nothing within reach")
		local any = CellSearch.nearest(-3, 20, 10, 10, 2, function(): boolean
			return true
		end)
		expect.equal(any and any.x, 0, "start clamped into range")
		expect.equal(any and any.z, 10)
	end,
}
