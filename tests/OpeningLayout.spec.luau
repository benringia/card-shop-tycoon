--!strict
-- Where the opening's row and results lineup sit on screen (UI project 3 spec 4.6)
local OpeningLayout = require("../src/shared/Util/OpeningLayout")
local PackOpeningLayout = require("../src/shared/Config/PackOpeningLayout")
local expect = require("./lib/expect")

local equal, near = expect.equal, expect.near
local INSET = 36 -- Roblox's top bar on a phone
local PHONES = { { w = 667, h = 375 }, { w = 568, h = 320 } }

local function fits(rects: { OpeningLayout.Rect }, view: { w: number, h: number }, label: string)
	for i, r in rects do
		equal(r.x >= 0 and r.x + r.w <= view.w and r.y >= INSET and r.y + r.h <= view.h, true, `{label}: card {i} on screen`)
		near(r.h / r.w, 1.4, 1e-6, `{label}: card {i} is card-shaped`)
		if i > 1 then
			equal(r.x >= rects[i - 1].x + rects[i - 1].w, true, `{label}: card {i} clear of {i - 1}`)
		end
	end
end

return {
	["the row and the lineup fit a 568 x 320 phone under the top bar"] = function()
		for _, view in PHONES do
			fits(OpeningLayout.row(5, view, INSET, PackOpeningLayout.LAYOUT), view, `row {view.w}`)
			fits(OpeningLayout.lineup(5, view, INSET, PackOpeningLayout.LAYOUT), view, `lineup {view.w}`)
		end
	end,

	["the lineup is centred and bigger than the row; neither passes maxCard"] = function()
		local view = { w = 1600, h = 900 }
		local row = OpeningLayout.row(5, view, INSET, PackOpeningLayout.LAYOUT)
		local lineup = OpeningLayout.lineup(5, view, INSET, PackOpeningLayout.LAYOUT)
		near(lineup[1].x + (lineup[5].x + lineup[5].w) - view.w, 0, 1e-6, "centred")
		equal(lineup[1].w > row[1].w, true, "bigger")
		equal(lineup[1].w <= PackOpeningLayout.LAYOUT.maxCard, true, "maxCard")
	end,

	["depthFor: twice the pixels, half the distance"] = function()
		near(OpeningLayout.depthFor(100, 400, 70, 1.5) / OpeningLayout.depthFor(200, 400, 70, 1.5), 2, 1e-9, "inverse")
		-- a card as tall as the screen sits where the view is exactly its height across
		local depth = OpeningLayout.depthFor(400, 400, 70, 1.5)
		near(2 * depth * math.tan(math.rad(35)), 1.5, 1e-9, "fills the height")
	end,
}
