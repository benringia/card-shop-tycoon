--!strict
-- NPC customer behaviour. See DESIGN.md section 4.5. Plain data (colours as { r, g, b }) so Lune tests can load it.
return {
	MAX_PER_PLOT = 4,
	FIRST_SPAWN_DELAY = 5, -- seconds after a shop is claimed
	SPAWN_INTERVAL_MIN = 8, -- seconds between customers; shop rating will shorten this later
	SPAWN_INTERVAL_MAX = 15,
	SPAWN_CHECK_INTERVAL = 1,

	ITEMS_MIN = 1, -- shopping list size
	ITEMS_MAX = 3,

	WALK_SPEED = 10,
	BROWSE_SECONDS = 1.5, -- time spent looking at a shelf
	SHELF_STAND_DISTANCE = 2.5, -- studs in front of a shelf's front face
	SEARCH_SHELVES = 2, -- more shelves a customer checks when something on their list isn't on the shelves
	ENTRY_DISTANCE = 8, -- studs out on the street from the shop front, where customers appear and leave

	QUEUE_PATIENCE = 40, -- seconds in the register queue before giving up (Bigger Queue upgrade +50% later)
	CHECKOUT_PATIENCE = 60, -- once scanning starts, seconds after the latest scan before giving up
	QUEUE_SPACING = 3,
	QUEUE_CHECK_INTERVAL = 0.5,
	COUNTER_ARRIVE_DISTANCE = 1.5, -- close enough to a queue slot to count as standing there

	MAX_LIFETIME = 180, -- safety net: customers stuck outside the queue are removed after this many seconds
	LIFETIME_RECHECK = 10, -- queued customers have their own timers, so the safety net checks again later

	BUBBLE_SECONDS = 2.5,
	-- Config/UIIcons names (anything else shows as text)
	BUBBLE_ANNOYED = "Angry", -- price over the top band
	BUBBLE_NO_STOCK = "Thinking", -- nothing they wanted on the shelves
	BUBBLE_GAVE_UP = "⌛", -- waited too long in the queue
	BUBBLE_HAPPY = "Happy", -- paid at the register

	PATH_AGENT = {
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true, -- the plot floor is a 1-stud step up from the street
	},

	-- Roblox default R15 animations
	WALK_ANIMATION = "rbxassetid://507777826",
	IDLE_ANIMATION = "rbxassetid://507766666",

	SKIN_COLORS = {
		{ 255, 220, 185 },
		{ 234, 184, 146 },
		{ 198, 134, 94 },
		{ 141, 85, 54 },
		{ 95, 60, 40 },
	},
	CLOTHES_COLORS = {
		{ 200, 60, 60 },
		{ 60, 110, 200 },
		{ 70, 160, 90 },
		{ 230, 180, 50 },
		{ 130, 80, 170 },
		{ 50, 50, 60 },
		{ 220, 220, 225 },
	},

	-- Customer types (spec 2026-11-06-customers-design, owner's pick B: props plus an icon as they walk in). weight:
	-- their share of customers (Util/CustomerTypes, in TYPE_ORDER); needsShowcase: only shops with a Glass Showcase
	-- holding a card; minLevel: from that shop level; tolerance: price bands higher than a plain customer they still
	-- buy in; icon: over them as they come through the door (a UIIcons name or an emoji; the collector shows its card
	-- instead); scale: the rig's size; colors: their clothes (rgb, picked at random); props: parts welded to a body
	-- part, size and offset in studs (offset from the part's centre, -Z the front), plain colours
	TYPE_ORDER = { "plain", "kid", "collector", "bargain", "bigSpender" },
	TYPES = {
		plain = { weight = 0.55, props = {} },
		kid = {
			weight = 0.20,
			icon = "🎒",
			scale = 0.82,
			colors = { torso = { { 79, 195, 255 }, { 255, 140, 66 }, { 110, 214, 92 } }, legs = { { 58, 123, 213 }, { 70, 70, 90 } } },
			props = {
				{ part = "Head", size = { 1.3, 0.35, 1.3 }, offset = { 0, 0.68, 0.05 }, color = { 255, 95, 143 }, shape = "Block" }, -- cap
				{ part = "Head", size = { 0.9, 0.12, 0.6 }, offset = { 0, 0.52, -0.8 }, color = { 255, 95, 143 }, shape = "Block" }, -- its peak
				{ part = "RightHand", size = { 0.5, 0.7, 0.1 }, offset = { 0, -0.35, -0.25 }, color = { 255, 122, 182 }, shape = "Block" }, -- a pack
			},
		},
		collector = {
			weight = 0.10,
			needsShowcase = true,
			colors = { torso = { { 142, 111, 216 }, { 96, 84, 140 } }, legs = { { 75, 63, 107 }, { 50, 50, 60 } } },
			props = {
				{ part = "Head", size = { 1.0, 0.25, 0.1 }, offset = { 0, 0.1, -0.62 }, color = { 43, 37, 64 }, shape = "Block" }, -- glasses
				{ part = "UpperTorso", size = { 0.25, 1.1, 0.85 }, offset = { 1.15, -0.1, 0 }, color = { 124, 92, 255 }, shape = "Block" }, -- a binder under its arm
			},
		},
		bargain = {
			weight = 0.10,
			icon = "🏷️",
			tolerance = 1,
			colors = { torso = { { 242, 165, 65 }, { 200, 150, 90 } }, legs = { { 107, 90, 70 }, { 90, 80, 60 } } },
			props = {
				{ part = "Head", size = { 1.55, 0.45, 1.55 }, offset = { 0, 0.68, 0 }, color = { 124, 196, 107 }, shape = "Block" }, -- bucket hat
				{ part = "RightHand", size = { 0.6, 0.35, 0.05 }, offset = { 0, -0.35, -0.25 }, color = { 255, 243, 168 }, shape = "Block" }, -- a coupon
			},
		},
		bigSpender = {
			weight = 0.05,
			icon = "💎",
			minLevel = 11, -- the booster box unlocks there
			tolerance = 1,
			colors = { torso = { { 43, 37, 64 }, { 30, 30, 40 } }, legs = { { 29, 24, 48 } } },
			props = {
				{ part = "Head", size = { 1.05, 0.22, 0.1 }, offset = { 0, 0.1, -0.62 }, color = { 20, 18, 30 }, shape = "Block" }, -- shades
				{ part = "UpperTorso", size = { 1.0, 0.12, 0.1 }, offset = { 0, 0.55, -0.52 }, color = { 245, 197, 66 }, shape = "Block" }, -- gold chain
				{ part = "UpperTorso", size = { 0.3, 0.3, 0.08 }, offset = { 0, 0.25, -0.53 }, color = { 245, 197, 66 }, shape = "Ball" }, -- its medallion
			},
		},
	},
}
