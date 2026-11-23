--!strict
-- Detail other shops drop on your screen (owner 2026-11-24: "add the two fixes", after six full shops were measured
-- against one; DESIGN 10.5): another player's shop screens draw from closer, and a far shop's shelf stock hides
local ShopLod = require("../src/shared/Util/ShopLod")
local ShopRooms = require("../src/shared/Util/ShopRooms")
local RoomsConfig = require("../src/shared/Config/ShopRooms")
local cfg = require("../src/shared/Config/ShopDetail")
local expect = require("./lib/expect")

return {
	["another player's shop screens draw from closer; yours keep the shop's distance"] = function()
		expect.equal(ShopLod.screenDistance(cfg, false, cfg.SCREEN_DISTANCE), cfg.VISITOR_SCREEN_DISTANCE)
		expect.equal(ShopLod.screenDistance(cfg, true, cfg.SCREEN_DISTANCE), cfg.SCREEN_DISTANCE)
		expect.equal(ShopLod.screenDistance(cfg, false, 0), 0, "a sign drawn from anywhere stays")
		expect.equal(ShopLod.screenDistance(cfg, false, cfg.FULL_CARD_DISTANCE), cfg.FULL_CARD_DISTANCE, "card faces keep theirs")
		expect.equal(cfg.VISITOR_SCREEN_DISTANCE < cfg.SCREEN_DISTANCE, true)
	end,

	["a visitor in the middle of a shop's hall still reads every tag in it"] = function()
		local hall = ShopRooms.hallRect(RoomsConfig, ShopRooms.grid(50, 60, 2)) -- Config/Plots WIDTH, DEPTH; GRID_SIZE 2
		local halfDiagonal = math.sqrt((hall.w * 2 / 2) ^ 2 + (hall.d * 2 / 2) ^ 2)
		expect.equal(cfg.VISITOR_SCREEN_DISTANCE >= halfDiagonal, true, `{cfg.VISITOR_SCREEN_DISTANCE} >= {halfDiagonal}`)
	end,

	["how far a shop is: the nearest point of its floor, across the ground"] = function()
		expect.near(ShopLod.footprintDistance(0, 0, 25, 30), 0, 1e-9, "standing in it")
		expect.near(ShopLod.footprintDistance(-35, 0, 25, 30), 10, 1e-9, "beside it")
		expect.near(ShopLod.footprintDistance(28, -34, 25, 30), 5, 1e-9, "off its corner")
	end,

	["a far shop's stock hides and shows again near, with no flicker at the edge"] = function()
		expect.equal(cfg.STOCK_SHOW < cfg.STOCK_HIDE, true, "it hides a little farther out than it shows")
		expect.equal(ShopLod.stockShown(cfg, 40, false), true)
		expect.equal(ShopLod.stockShown(cfg, cfg.STOCK_SHOW + 1, false), false, "hidden: stays hidden until within STOCK_SHOW")
		expect.equal(ShopLod.stockShown(cfg, cfg.STOCK_SHOW + 1, true), true, "shown: stays until past STOCK_HIDE")
		expect.equal(ShopLod.stockShown(cfg, cfg.STOCK_HIDE + 1, true), false)
	end,

	["a shop's stock outlasts its screens: no price tag over an empty-looking shelf"] = function()
		expect.equal(cfg.STOCK_SHOW > cfg.SCREEN_DISTANCE, true)
	end,
}
