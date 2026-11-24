--!strict
-- Main quests (owner 2026-11-18: "when items like forge is unlocked and the players couldnt afford it yet, add it to
-- their main quests, so that when they finish all daily quest, there's always something to do"; look A of artifact
-- Evh8Gx9pN61R5GkodcwR3C): the next thing to build for the shop, pinned at the bottom of the quest strip with the cash
-- filling its bar (Util/MainQuestRules, MainQuestService, client Util/MainQuest). Plain data (tests/MainQuestRules).
return {
	-- The Build menu's racks, cases and machines (Config/Shelves ids; decor and trophies stay out; Pish explains the cases and machines once placed),
	-- with their Config/UIIcons icons. One is open once the shop's level unlocks it and none stands in the shop.
	ITEMS = {
		{ id = "GlassShowcase", icon = "Cases" },
		{ id = "CollectorCase", icon = "Cases" },
		{ id = "WallShelf", icon = "Shelves" },
		{ id = "Condenser", icon = "Condenser" },
		{ id = "StorageRack", icon = "Box" }, -- spec 2026-11-24-storage-racks-design: Pish explains it once placed
		{ id = "Forge", icon = "Forge" },
		{ id = "AccessoryHook", icon = "Shelves" },
		{ id = "BigDisplayRack", icon = "Shelves" },
		{ id = "BulkBin", icon = "Copies" },
		{ id = "Recycler", icon = "Copies" },
		{ id = "GradingStation", icon = "GradingSeal" },
	},
	XP_SHARE = 0.1, -- building one for the first time pays this share of its price in shop XP (the Forge: +150)
	LEVEL_ICON = "Level", -- everything built: the next unlock's level is the goal
	HOLD_SECONDS = 1.8, -- the done moment stays on the row this long before the next goal slides in
}
