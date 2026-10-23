--!strict
-- NPC customer behaviour. See DESIGN.md section 4.5.
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
		Color3.fromRGB(255, 220, 185),
		Color3.fromRGB(234, 184, 146),
		Color3.fromRGB(198, 134, 94),
		Color3.fromRGB(141, 85, 54),
		Color3.fromRGB(95, 60, 40),
	},
	CLOTHES_COLORS = {
		Color3.fromRGB(200, 60, 60),
		Color3.fromRGB(60, 110, 200),
		Color3.fromRGB(70, 160, 90),
		Color3.fromRGB(230, 180, 50),
		Color3.fromRGB(130, 80, 170),
		Color3.fromRGB(50, 50, 60),
		Color3.fromRGB(220, 220, 225),
	},
}
