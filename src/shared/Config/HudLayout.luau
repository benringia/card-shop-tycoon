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
		icon = "Phone", -- Config/UIIcons (owner 2026-11-13 pick P1; the 📱 emoji before)
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
	-- touchScale: the cash pill smaller on a touch screen, under your row (owner 2026-11-13: "make the coins smaller");
	-- touchCoin: its coin inside the pill there, not bigger than it (declutter pick A)
	CASH = { top = Color3.fromRGB(142, 224, 154), bottom = Color3.fromRGB(63, 179, 90), touchScale = 0.72, touchCoin = 34 },
	PILL_EDGE = Color3.fromRGB(236, 224, 208), -- the white pills' soft edge
	STATUS_ICON = 54, -- the coin, bigger than its pill
	-- The whole HUD shrinks with the screen's height on small screens (landscape phones): 1 at REFERENCE_HEIGHT
	-- and up, never below MIN (tiles stay over 48 px to tap)
	-- TOUCH_MIN: the corner (cash and the party dock) never smaller than this on a touch screen (owner 2026-11-13: "make
	-- them look pretty", the dock read too small on a phone)
	SCALE = { REFERENCE_HEIGHT = 560, MIN = 0.7, TOUCH_MIN = 0.85 },
	-- The phone's buffs (owner 2026-11-13, buffs pick A; BuffController): round icons `icon` px stacked left of your face
	-- in a `width` px wide tap area (one tap: every buff in a tooltip), a timed one in a `ring` px ring that empties
	BUFF_ICONS = { icon = 26, ring = 3, gap = 4, width = 56, track = Color3.fromRGB(255, 255, 255) },
	-- The quick weapon switch (spec 2026-11-07-weapons-round2-design 6), the medallion dial (owner 2026-11-14 pick C):
	-- the weapon in hand in a `chip` px medallion, its rarity's ring `ring` px with a shine going round every
	-- shineSeconds, its inside the element's colour; the others `side` px (a `hit` px tap area) on a track `arc` px from
	-- its middle at `angles` (degrees: 180 left, 90 up), the one after next faded (laterFade) and smaller (laterScale);
	-- a switch rolls them along the track in `roll` s. The name and its line show left of the track for nameSeconds
	-- after a switch (owner: "only briefly"); a swipe of `swipe` px on the medallion steps too. Placed by
	-- UiLayout.weaponSwitch: never scaled under 48 px tap areas, above the fight buttons in a fight. Phones: the
	-- medallion alone (`compactChip`), its "2/6" count `countText` px
	WEAPON_SWITCH = {
		chip = 72, side = 36, arc = 70, hit = 48, gap = 6, right = 12, ring = 4, shineSeconds = 4,
		angles = { before = 180, after = 90, later = 135 },
		sideFade = 0.15, laterFade = 0.55, laterScale = 0.8, roll = 0.28, nameSeconds = 1.5, swipe = 30,
		compactChip = 64, countText = 12,
	},
}
