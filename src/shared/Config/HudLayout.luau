--!strict
-- The HUD layout (client only): candy icon tiles on the left (Manage, with its tray) and bottom centre (Cards,
-- Bag, Bosses, and contextual tiles like Rip a pack). Cash, shards and level sit in the bottom-right corner (UIController). Pixels. See DESIGN.md (UI) and Util/Hud.
-- The tiles in the cotton candy look (Config/SoftHud, Config/BabyColors; spec 2026-11-03-cotton-candy-ui-design): a
-- squircle in a baby colour, its gradient from the light shade at the top to the full colour, a white label outlined
-- in the deep shade. Unknown ids look like Manage.
local Config = script.Parent :: Instance
local SoftHud = require(Config:WaitForChild("SoftHud"))
local BabyColors = require(Config:WaitForChild("BabyColors"))
local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end
local function candyOf(name: string): { top: Color3, bottom: Color3, deep: Color3 }
	local shades = BabyColors.COLORS[name]
	return { top = rgb(shades.light), bottom = rgb(shades.fill), deep = rgb(shades.deep) }
end
local candy = {}
for id, name in SoftHud.COLORS do
	candy[id] = candyOf(name)
end
local fanCandy = {}
for index, name in SoftHud.FAN do
	fanCandy[index] = candyOf(name)
end
local TILE = SoftHud.TILE

return {
	TOWN_CHECK = 0.5, -- seconds between checks of whether you're in town (the Manage tray shows only there: Util/Hud)
	TILE_SIZE = Vector2.new(TILE.size, TILE.size),
	SIDE_X = 12, -- left edge of the side column
	BOTTOM_MARGIN = 16, -- the bottom row sits this far above the screen's bottom
	GAP = TILE.gap,
	SIDE_GAP = TILE.gap + math.ceil(TILE.size * TILE.iconRise), -- the left column: room for each icon over its tile's top
	TRAY = { PADDING = 8, TRANSPARENCY = 0.35 }, -- the bar the Manage tiles slide out in
	-- The phone (owner 2026-11-13: "no more manage button. replace it with a phone", pick B: it rises in the middle
	-- like you're holding it, the world dimmed behind; Util/Hud): the Manage tile is the Phone tile (`icon`, `label`;
	-- town only), and its apps (the old tray's Shop, Prices, Jobs, Party, and Reviews) sit on its home screen. `size` px
	-- at most `fit` of the screen's height; `dim` the world's darkness behind it; `picture` on the home screen (Pish and
	-- Chikin, Config/Support CARD.picture); `title` the shop's name ("%s": the player's)
	PHONE = {
		icon = "📱",
		label = "Phone",
		size = { 300, 580 },
		fit = 0.9,
		dim = 0.5,
		bezel = { 43, 35, 64 },
		wall = { { 255, 224, 240 }, { 217, 204, 255 }, { 194, 230, 255 } },
		ink = { 91, 61, 110 },
		picture = "rbxassetid://131467700155398",
		title = "%s's shop",
		slide = 0.35,
		columns = 3,
		badge = { 255, 79, 106 },
	},
	KEY_CHIP = rgb(BabyColors.INK), -- the key letter in its white circle
	CANDY = candy, -- by tile id: Manage butter, Cards sky, Bag pink, Bosses lilac, Admin grey-lilac, Rip and Drop peach
	CANDY_FAN = fanCandy, -- the Manage tray's tiles by their order, round and round: mint, peach, sky, lilac
	CANDY_OPEN_SHADE = TILE.openShade, -- the Manage tile deepens this much while its tray is open
	OUTLINE = TILE.outline, -- the tiles' white outline (px at full scale); the cash pill's too
	KEY_SIZE = TILE.keySize,
	-- The status corner in the same look: a green cash pill with a gold coin, a white level pill with a gold star and
	-- the XP big with a thin bar (Util/XpPill), a white buff chip
	CASH = { top = Color3.fromRGB(142, 224, 154), bottom = Color3.fromRGB(63, 179, 90) },
	PILL_EDGE = Color3.fromRGB(236, 224, 208), -- the white pills' soft edge
	-- The level pill's XP (owner 2026-11-03, round 3 pick B; Util/XpPill): the XP into the level big ("99,800 XP"),
	-- the level's total small after it ("/ 226,000"), a thin bar under them (lilac to sky); a change counts up over
	-- countSeconds. Sizes in px.
	XP_PILL = {
		width = 150,
		amountText = 16,
		totalText = 11,
		bar = 6,
		gap = 2,
		ink = rgb(BabyColors.INK),
		soft = rgb({ 123, 90, 142 }),
		fillLeft = rgb(BabyColors.COLORS.lilac.fill),
		fillRight = rgb(BabyColors.COLORS.sky.fill),
		track = rgb({ 243, 230, 248 }),
		countSeconds = 0.6,
	},
	STATUS_ICON = 54, -- the coin and the star, bigger than their pills
	-- The whole HUD shrinks with the screen's height on small screens (landscape phones): 1 at REFERENCE_HEIGHT
	-- and up, never below MIN (tiles stay over 48 px to tap)
	SCALE = { REFERENCE_HEIGHT = 560, MIN = 0.7 },
	-- The quick weapon switch (spec 2026-11-07-weapons-round2-design 6, the owner's pick A): a round chip on the right
	-- edge at mid height with your weapon's picture in its rarity's ring, < and > either side; its name shows under it
	-- (in `name` px of room) for nameSeconds after a switch; a swipe of `swipe` px on the chip steps too. Placed by
	-- UiLayout.weaponSwitch: never scaled under 48 px arrows, above the fight buttons in a fight
	-- the carousel (owner 2026-11-12: smaller buttons, the weapons before and after smaller beside it, a tooltip): px
	WEAPON_SWITCH = { chip = 58, side = 40, arrow = 30, hit = 48, gap = 6, right = 12, name = 22, ring = 3, nameSeconds = 1.5, swipe = 30, slide = 0.18, sideFade = 0.35, compactChip = 64, dots = 12, dot = 6, maxDots = 7 },
	-- The phone HUD, slimmed (owner 2026-11-13, pick A: "the UI on phone is really crowded"): on touch screens one pill
	-- holds the cash ("$53,661") and the level badge, its XP in a `ring`-thick ring round it (`track` behind, `fill` as
	-- it fills); the rating chip and the XP pill hide (the rating is on the Phone's status bar and in Reviews); the
	-- party bar drops its "Party" word (Party is a Phone app); the weapon switch is one bigger chip (WEAPON_SWITCH
	-- compactChip: tap for the next, swipe back) with a dot per weapon
	COMPACT = { badge = 38, ring = 4, track = Color3.fromRGB(225, 215, 240), fill = Color3.fromRGB(150, 110, 255) },
}
