--!strict
local PageCurl = require("../src/shared/Util/PageCurl")
local expect = require("./lib/expect")
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local equal, near = expect.equal, expect.near

return {
	["angles: flat at both ends, the outer edge leading mid-turn, never past flat"] = function()
		equal(table.concat(PageCurl.angles(0, 6, 40), ","), "0,0,0,0,0,0", "flat on the right")
		equal(table.concat(PageCurl.angles(1, 6, 40), ","), "180,180,180,180,180,180", "flat on the left")
		local mid = PageCurl.angles(0.5, 6, 40)
		near(mid[1], 90, 1e-6, "spine strip upright")
		near(mid[6], 130, 1e-6, "outer strip ahead by the full bend")
		for k = 2, 6 do
			equal(mid[k] >= mid[k - 1], true, `strip {k} at least as far over as strip {k - 1}`)
		end
		for k, angle in PageCurl.angles(0.9, 6, 40) do
			equal(angle >= 0 and angle <= 180, true, `strip {k} within flat-to-flat`)
		end
		local rigid = PageCurl.angles(0.3, 6, 0)
		for k = 2, 6 do
			near(rigid[k], rigid[1], 1e-9, `no bend: strip {k} matches the spine`)
		end
	end,
	["chain: hinge points out from the spine"] = function()
		local flat = PageCurl.chain({ 0, 0 }, 1)
		equal(#flat, 3, "one more point than strips")
		near(flat[3].x, 2, 1e-9, "flat right x")
		near(flat[3].y, 0, 1e-9, "flat right y")
		local over = PageCurl.chain({ 180, 180 }, 1)
		near(over[3].x, -2, 1e-9, "flat left x")
		near(over[3].y, 0, 1e-6, "flat left y")
		local up = PageCurl.chain({ 90 }, 2)
		near(up[2].x, 0, 1e-6, "upright x")
		near(up[2].y, 2, 1e-9, "upright y")
	end,
	["dragTurn: the pointer's distance from the spine is the turn"] = function()
		near(PageCurl.dragTurn(3, 3, true), 0, 1e-9, "forward: at the outer edge")
		near(PageCurl.dragTurn(0, 3, true), 0.5, 1e-9, "forward: over the spine")
		near(PageCurl.dragTurn(-3, 3, true), 1, 1e-9, "forward: across")
		near(PageCurl.dragTurn(9, 3, true), 0, 1e-9, "forward: clamped")
		near(PageCurl.dragTurn(-3, 3, false), 0, 1e-9, "back: at the left outer edge")
		near(PageCurl.dragTurn(3, 3, false), 1, 1e-9, "back: across")
	end,
	["finishes: past halfway or flicked on finishes, flicked back falls back"] = function()
		equal(PageCurl.finishes(0.6, 0, 1.5), true, "past halfway")
		equal(PageCurl.finishes(0.4, 0, 1.5), false, "short of halfway")
		equal(PageCurl.finishes(0.3, 2, 1.5), true, "flicked on")
		equal(PageCurl.finishes(0.7, -2, 1.5), false, "flicked back")
	end,
	["turnSeconds: faster the further there is to go"] = function()
		near(PageCurl.turnSeconds(0.5, 1, 4), 0.5, 1e-9, "one page")
		near(PageCurl.turnSeconds(0.5, 2, 4), 0.25, 1e-9, "two pages")
		near(PageCurl.turnSeconds(0.5, 10, 4), 0.125, 1e-9, "capped speed-up")
		near(PageCurl.turnSeconds(0.5, 0, 4), 0.5, 1e-9, "nothing left")
	end,
	["step: never past the first or last spread"] = function()
		equal(PageCurl.step(1, -1, 5), 1, "first")
		equal(PageCurl.step(5, 1, 5), 5, "last")
		equal(PageCurl.step(2, 1, 5), 3, "forward")
		equal(PageCurl.step(1, 1, 0), 1, "no spreads")
	end,
	["swipe and isTap: pointer gestures"] = function()
		equal(PageCurl.swipe(-80, 10, 60), 1, "left swipe: next")
		equal(PageCurl.swipe(80, 0, 60), -1, "right swipe: back")
		expect.isNil(PageCurl.swipe(30, 0, 60), "too short")
		expect.isNil(PageCurl.swipe(-80, 100, 60), "mostly vertical")
		equal(PageCurl.isTap(3, 4, 0.2, 10, 0.35), true, "short and still")
		equal(PageCurl.isTap(20, 0, 0.1, 10, 0.35), false, "moved")
		equal(PageCurl.isTap(0, 0, 0.5, 10, 0.35), false, "held")
	end,
	["config: Config/BinderDesk pockets are 3 x 3"] = function()
		-- Config/BinderDesk holds Vector3/Color3 values, so Lune can't load it; read its text instead
		local text = fs.readFile("src/shared/Config/BinderDesk.luau")
		local columns, rows = string.match(text, "POCKETS = { columns = (%d+), rows = (%d+)")
		equal(tonumber(columns), 3, "columns")
		equal(tonumber(rows), 3, "rows")
	end,
	["every rule exists as soon as the module loads (none nested inside another)"] = function()
		local fresh = luau.load(luau.compile(fs.readFile("src/shared/Util/PageCurl.luau")), { debugName = "PageCurl" })()
		for _, name in { "angles", "chain", "dragTurn", "finishes", "turnSeconds", "step", "swipe", "isTap" } do
			equal(typeof(fresh[name]), "function", name)
		end
	end,
}
