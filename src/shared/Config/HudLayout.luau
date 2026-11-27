--!strict
-- The HUD layout (client only): candy icon tiles on the left (Manage, with its tray) and bottom centre (Cards,
-- Bag, Bosses, and contextual tiles like Rip a pack). Cash, shards and level sit in the bottom-right corner (UIController). Pixels. See DESIGN.md (UI) and Util/Hud.
-- The tiles in the cotton candy look (Config/SoftHud, Config/BabyColors; spec 2026-11-03-cotton-candy-ui-design): a
-- squircle in a baby colour, its gradient from the light shade at the top to the full colour, a white label outlined
-- in the deep shade. Unknown ids look like Manage.
local Config = script.Parent :: Instance
local SoftHud = require(Config:WaitForChild("SoftHud"))
local PhoneForm = require(Config:WaitForChild("PhoneForm"))
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
	SIDE_TOP = 22, -- a phone's side column hangs from here (px under the top bar: room for the first icon over its tile)
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
		size = { PhoneForm.tall.w, PhoneForm.tall.h }, -- standing up; on a short screen it lies on its side (Config/PhoneForm)
		fit = PhoneForm.fit,
		dim = 0.5,
		bezel = { 43, 35, 64 },
		wall = { { 255, 224, 240 }, { 217, 204, 255 }, { 194, 230, 255 } },
		ink = { 91, 61, 110 },
		picture = "rbxassetid://131467700155398",
		-- Pish and Chikin over the apps: px tall standing up and lying on its side (owner 2026-11-20: "make pish and
		-- chikin icon a bit smaller"; 110 and 150 before). The apps move up by what the picture gave back
		pictureHeight = { tall = 86, wide = 118 },
		title = "%s's shop",
		slide = 0.35,
		columns = PhoneForm.columns,
		badge = { 255, 79, 106 },
		-- The Phone tile's notification on a computer (owner 2026-11-21; Util/PhoneNotice kinds, Util/Hud.notice): rings
		-- in the badge's colour growing `grow` px off the tile and fading over `seconds`, `rings` of them `gap` s apart;
		-- its icon rocks `wiggle` degrees `rocks` times; its count pops from `pop` times its size
		notice = {
			ping = { rings = 2, grow = 30, seconds = 0.75, gap = 0.3, wiggle = 12, rocks = 3, pop = 1.7 },
			nudge = { rings = 1, grow = 14, seconds = 0.5, gap = 0, wiggle = 6, rocks = 1, pop = 1.25 },
			thickness = 4,
		},
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
	-- The row (owner 2026-11-27 pick B, the twin of the party dock; UiLayout.switchBox, WeaponSwitch.rowSpot): the one
	-- before and the next (`side`) `row` px off the weapon in hand (`chip`) and `drop` px lower, its level pill reaching
	-- `rise` px over it, its name's line `name` px under it (`nameGap` px clear of the Z and Q keys either side, so
	-- they never read as one line), its grade's medal `medal` px on its top-left corner (the cards' medal)
	-- Its top edge (owner 2026-11-28: "make sure no overlapping elements"; WeaponSwitch.chipTop): the medal and the
	-- mutation's mark `medal` px on the `chip` px medallion (in step on a phone's), `overhang` px over its top and at
	-- least that past its sides, further when the level's pill needs `topGap` px either side: `pill` px wide ("+10", its
	-- widest, 17 px at `pillText` px, with the party dock's 5 px padding), `pillHeight` tall, a `pillEdge` px white
	-- outline like the dock's level chip; `rise` holds the pill and its outline. A phone's swipe chevrons `hint` px past
	-- its edge, clear of the pill
	WEAPON_SWITCH = {
		chip = 72, side = 44, hit = 48, gap = 6, right = 12, ring = 4, shineSeconds = 4,
		row = 8, drop = 8, rise = 10, name = 20, nameGap = 9, medal = 24,
		overhang = 7, pill = 27, pillHeight = 17, pillText = 12, pillEdge = 1.5, topGap = 3, hint = 18,
		sideFade = 0.15, roll = 0.28, nameSeconds = 1.5, swipe = 30,
		compactChip = 64, countText = 12,
		fightScale = 0.7, -- in a computer's fight: 180 px wide -> 126, over the compact buttons (UiLayout.weaponSwitch)
	},
}
