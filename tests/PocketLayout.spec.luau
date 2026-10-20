--!strict
local PocketLayout = require("../src/client/Util/PocketLayout")
local expect = require("./lib/expect")

local OPTIONS = { aspect = 0.7, gap = 6, preferredColumns = 3, preferredRows = 3, minWidth = 70, maxColumns = 5, maxRows = 3, minPockets = 4 }

return {
	["desktop page keeps the 3 x 3 binder layout"] = function()
		local layout = PocketLayout.choose(430, 430, OPTIONS)
		expect.equal(layout.columns, 3, "columns")
		expect.equal(layout.rows, 3, "rows")
		assert(layout.width >= 70, `width {layout.width}`)
	end,

	["short phone page switches to one bigger row"] = function()
		local layout = PocketLayout.choose(240, 100, OPTIONS)
		expect.equal(layout.columns, 4, "columns")
		expect.equal(layout.rows, 1, "rows")
		expect.equal(layout.width, 52, "width") -- 3 x 3 would be about 22
		expect.equal(layout.height, math.floor(52 / 0.7), "height")
	end,

	["never fewer pockets than the minimum"] = function()
		local layout = PocketLayout.choose(120, 60, OPTIONS)
		assert(layout.columns * layout.rows >= 4, "at least 4 pockets")
		assert(layout.width >= 1 and layout.height >= 1, "positive size")
	end,
}
