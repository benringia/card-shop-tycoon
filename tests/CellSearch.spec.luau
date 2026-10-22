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
}
