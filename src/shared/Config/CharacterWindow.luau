--!strict
-- The character window (owner 2026-11-12, layout A: spec 2026-11-12-wild-danger-character-window-design): your
-- character on the left, Stats / Elements / Titles tabs on the right, your weapon along the bottom. Words are plain
-- ASCII (icons are images). Opened from your face on the party bar (owner 2026-11-12, pick B) or the P key.
return {
	FACE = { key = "P", ring = { 255, 255, 255 }, hover = 1.08 }, -- your headshot first on the party bar (Party.BAR sizes)
	MAX_SIZE = { 920, 600 }, -- px, desktop (owner 2026-11-13: "make this window bigger. it looks cramped up")
	BODY_HEIGHT = 470, -- px: the stage and tabs (a tall screen stacks them: PHONE_BODY_HEIGHT)
	MIN_BODY_HEIGHT = 330, -- px: side by side on a short screen, the window's room but never less (it scrolls then)
	PHONE_BODY_HEIGHT = 580,
	IDLE_FALLBACK = "rbxassetid://507766666", -- Roblox's default R15 idle, for an avatar without its own
	STAGE_SHARE = 0.34, -- the stage's share of the width (a phone: above the tabs, this share of the height)
	STAT_ROW = 72, -- px: a stat's row (name, number, a two-line note)
	TABS = { "Stats", "Elements", "Titles" },
	STATS = {
		{ key = "power", icon = "Power", name = "Power", line = "Your strongest card. Bosses check it." },
		{ key = "attack", icon = "Atk", name = "Attack", line = "How much harder your sword hits." },
		{ key = "defense", icon = "Shield", name = "Defense", line = "Your party's Power added up: softer hits on you." },
	},
	-- The Elements tab: the element wheel (owner 2026-11-12, pick A; Util/ElementWheel). px in a `size` box (scaled down
	-- to fit), icon centres in `nodes`: Fire, Nature, Water as a triangle, Electric and Dark side by side
	WHEEL = {
		size = { x = 260, y = 218 },
		icon = 52,
		gap = 5, -- px between an icon's edge and an arrow's end
		pairOffset = 11, -- px a both-ways pair's arrows sit apart from the line
		nameHeight = 18, -- px for the name under (or over) an icon
		nameText = 16, -- its text size
		line = 4, -- px thick
		head = 13, -- px: an arrowhead's arms
		color = { 160, 122, 192 },
		glow = { 255, 216, 74 }, -- the ring round an element in your party
		-- nameAbove: its name over the icon (the top row: its arrows leave downward)
		nodes = {
			Ember = { x = 86, y = 48, nameAbove = true },
			Bloom = { x = 32, y = 164 },
			Tide = { x = 142, y = 164 },
			Volt = { x = 220, y = 48, nameAbove = true },
			Shade = { x = 220, y = 164 },
		},
	},
	WHEEL_TITLE = "Who beats who",
	-- beside the wheel ({strong} / {weak}: Combat.STRONG / WEAK); below it when the tab is narrow
	LEGEND = { "Arrow = {strong}x damage, the other way {weak}x", "Glowing = in your party" },
	LEGEND_WIDTH = 150, -- px
	TITLES_AUTO = { name = "Automatic", how = "Shows your best title" },
	-- The Titles tab, the dot and the "New title!" card (owner 2026-11-13: "add a notification when a new title is
	-- unlocked, and make the character menu have a little notification indicator ... which will lead them to the titles
	-- tab"): new titles first with a NEW tag, then the ones to earn with how far they are; the dot on your face while
	-- one is new; the card pops in at the top for `seconds` (its button opens the Titles tab)
	TITLES = {
		hint = "Tap Equip to show a title over your name.",
		new = "NEW",
		wear = "Equip", -- owner 2026-11-13: "change 'Wear' to 'Equip'"
		worn = "Equipped",
		unlocked = "New title!",
		show = "Equip it",
		seconds = 7,
		width = 320,
		top = 160, -- px from the top: under Pish's talk card
		sound = { id = "rbxassetid://9116223893", volume = 0.45, pitch = 1.25 }, -- the objective chime, brighter
		dot = { size = 16, color = { 255, 80, 95 } },
	},
	NO_WEAPON = "No weapon yet",
	-- On the stage (owner 2026-11-13: "move [the weapon] to the top right of the character model's section as a small box
	-- with the weapon's model and the details as tool tip. also add the equipped title inside"): the weapon's picture in a
	-- `box` px square at the top right (its name, grade, level and element on hover or hold), the title worn at the top
	WEAPON_BOX = { box = 64, inset = 10 },
	STAGE_TITLE = { height = 26, maxText = 20, inset = 10 },
}
