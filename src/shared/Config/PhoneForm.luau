--!strict
-- The Phone's two forms (Util/Hud; Util/CompactHud.phoneForm; pre-launch QA 2026-11-19, owner: "do all"). Standing up
-- (`tall`) it is at most `fit` of the screen's height, which left its app tiles 31 px on a Galaxy A06 and 36 px on an
-- iPhone 17 Pro (the rule is 48). On a screen too short to keep the tiles `minTile` px it lies on its side (`wide`):
-- the shop's name and the dogs on the left (`wideSide` px), the apps beside them `wideColumns` to a row. `pageMax`: an
-- app page's content never wider than this (the pages were made for the standing phone). Plain data: tests/CompactHud;
-- Config/HudLayout PHONE reads the standing form's numbers from here.
return {
	tall = { w = 300, h = 580 },
	fit = 0.9,
	columns = 3,
	wide = { w = 660, h = 340 },
	wideFit = 0.94,
	wideColumns = 5,
	wideSide = 196,
	minTile = 48,
	pageMax = 400,
}
