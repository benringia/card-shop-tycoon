--!strict
-- The Shop window's tiles (BuildController's shelves, Util/LookTiles' looks, WindowController.Tiles' windows: all
-- three build the same tile: a picture, a name, a line, a button). On a phone the full tile (224 px) was taller than
-- the list (100 px on a Galaxy A06, 140 on an iPhone 17 Pro), so a picture and its price never showed together
-- (pre-launch QA 2026-11-19; owner: "do all"): phones get a row tile, picture on the left, two to a row, and a taller
-- window with slimmer tabs (client Util/ShopTile, Util/ShopTileRules). Plain data: tests/ShopTileRules.
return {
	FULL = { width = 160, height = 224, picture = 110, gap = 10 },
	-- name / detail: where the two lines sit; button: its height (a finger-sized target)
	PHONE = { columns = 2, height = 100, picture = 84, gap = 8, nameSize = 15, detailSize = 12, button = 44 },
	-- header: UIKit.HEADER_HEIGHT; height: the window's share of the screen's height; tabs: their row's height; chrome:
	-- everything of the window that isn't the list (the header, the tabs and the margins round them)
	WINDOW = {
		header = 60,
		height = 0.85,
		tabs = 48,
		chrome = 138, -- 60 + 10 + 48 + 10 over the list, 10 under it
		phoneHeight = 0.96,
		phoneTabs = 44,
		phoneChrome = 124, -- 60 + 6 + 44 + 6 over the list, 8 under it
	},
}
