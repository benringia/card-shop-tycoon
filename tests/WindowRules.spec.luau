--!strict
-- Shop windows (spec 2026-11-14-shop-windows-design): where a window may go, what a shop may buy, and the wall cut
-- into pieces round the windows' holes
local WindowRules = require("../src/shared/Util/WindowRules")
local Windows = require("../src/shared/Config/Windows")
local expect = require("./lib/expect")

local function window(style: string, side: string, at: number): WindowRules.Window
	return { style = style, side = side, at = at }
end

return {
	["a window's middle snaps to the grid"] = function()
		expect.equal(WindowRules.snap(Windows, 3.1), 4)
		expect.equal(WindowRules.snap(Windows, -2.9), -2)
		expect.equal(WindowRules.snap(Windows, 0.4), 0)
	end,

	["a window fits on a side or back wall, clear of the corners and of other windows"] = function()
		local ok = WindowRules.canPlace(Windows, {}, window("Square", "left", 0))
		expect.equal(ok, true, "the middle of a side wall")
		local edge, why = WindowRules.canPlace(Windows, {}, window("Wide", "back", 16))
		expect.equal(edge, false, "the wide window reaches the corner")
		expect.equal(type(why), "string")
		expect.equal((WindowRules.canPlace(Windows, {}, window("Wide", "back", 14))), true, "2 studs further in it fits")
		expect.equal((WindowRules.canPlace(Windows, {}, window("Square", "front", 0))), false, "never the glass front")
		expect.equal((WindowRules.canPlace(Windows, {}, window("Square", "left", 1))), false, "off the grid")
		expect.equal((WindowRules.canPlace(Windows, {}, window("Nope", "left", 0))), false, "unknown style")
		local placed = { window("Square", "left", 0) }
		expect.equal((WindowRules.canPlace(Windows, placed, window("Square", "left", 4))), false, "touching: no wall between")
		expect.equal((WindowRules.canPlace(Windows, placed, window("Square", "left", 6))), true, "a stud or more apart")
		expect.equal((WindowRules.canPlace(Windows, placed, window("Square", "right", 0))), true, "the other wall")
		expect.equal((WindowRules.canPlace(Windows, placed, window("Square", "left", 0), 1)), true, "moving it onto itself")
	end,

	["buying: the cap, the shop level, the achievement, then the cash"] = function()
		expect.equal((WindowRules.canBuy(Windows, "Square", 3, 300, true, 0)), true)
		local _, low = WindowRules.canBuy(Windows, "Square", 2, 300, true, 0)
		expect.equal(low, "Square Window unlocks at shop level 3.")
		local _, broke = WindowRules.canBuy(Windows, "Square", 3, 299, true, 0)
		expect.equal(broke, "You need $300 for Square Window.")
		local _, full = WindowRules.canBuy(Windows, "Square", 3, 300, true, Windows.MAX)
		expect.equal(full, "Your shop has room for 6 windows. Sell one to make space.")
		local _, locked = WindowRules.canBuy(Windows, "Stained", 50, 9999, false, 0)
		expect.equal(locked, "Stained Glass Window: Beat the Prism Hydra.")
		expect.equal((WindowRules.canBuy(Windows, "Stained", 1, 2500, true, 0)), true, "achieved: no level needed")
	end,

	["the wall cut round its holes: the pieces cover the wall but never a hole"] = function()
		local holes = {
			{ x0 = -10, x1 = -6, y0 = 4, y1 = 8 },
			{ x0 = 2, x1 = 10, y0 = 4, y1 = 8 },
		}
		local pieces = WindowRules.pieces(40, 18, holes)
		local area = 0
		for _, p in pieces do
			expect.equal(p.x0 >= -20 and p.x1 <= 20 and p.y0 >= 0 and p.y1 <= 18, true, "inside the wall")
			expect.equal(p.x1 > p.x0 and p.y1 > p.y0, true, "not empty")
			area += (p.x1 - p.x0) * (p.y1 - p.y0)
			for _, h in holes do
				local cut = p.x0 < h.x1 and h.x0 < p.x1 and p.y0 < h.y1 and h.y0 < p.y1
				expect.equal(cut, false, "no piece over a hole")
			end
		end
		expect.near(area, 40 * 18 - 16 - 32, 1e-6, "the wall less its holes")
		expect.equal(#WindowRules.pieces(40, 18, {}), 1, "no windows: one piece")
	end,

	["a window's hole on its wall"] = function()
		local hole = WindowRules.hole(Windows, window("Wide", "back", -6))
		expect.equal(hole.x0, -10)
		expect.equal(hole.x1, -2)
		expect.equal(hole.y0, Windows.SILL)
		expect.equal(hole.y1, Windows.SILL + 4)
	end,

	["loading: bad entries and windows that no longer fit come back as refunds"] = function()
		local kept, refunded = WindowRules.clean(Windows, {
			window("Square", "left", 0),
			window("Square", "left", 2), -- overlaps the first
			window("Nope", "left", 10),
			{ style = "Wide", side = "back", at = "x" } :: any,
			window("Arched", "right", 99), -- off the wall
			window("Porthole", "back", 0),
		})
		expect.equal(#kept, 2)
		expect.equal(kept[1].style, "Square")
		expect.equal(kept[2].style, "Porthole")
		local styles = Windows.STYLES
		expect.equal(refunded, styles.Square.price + styles.Wide.price + styles.Arched.price, "known styles paid back, unknown ones can't be priced")
		local many = {}
		for _, side in Windows.SIDES do
			for _, at in { -12, -6, 0, 6, 12 } do
				table.insert(many, window("Square", side, at))
			end
		end
		local capped, back = WindowRules.clean(Windows, many)
		expect.equal(#capped, Windows.MAX, "never over the cap")
		expect.equal(back, (#many - Windows.MAX) * styles.Square.price, "the ones over it paid back")
	end,

	["every style's hole fits under the ceiling and over the band"] = function()
		for _, id in Windows.ORDER do
			local style = Windows.STYLES[id]
			expect.equal(Windows.SILL + style.height <= 18 - 1, true, `{id}: under the ceiling`)
			expect.equal(style.width % Windows.GRID == 0, true, `{id}: whole grid steps wide`)
		end
	end,
}
