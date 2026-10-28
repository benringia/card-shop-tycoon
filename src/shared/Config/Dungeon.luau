--!strict
-- The Dungeon (spec 2026-10-29-dungeon-final-boss-design.md): a third place reached from the Frontier's Dungeon
-- portal, one run per (reserved) server. A prism-crystal cavern along +X: the entrance hall, three sealed rooms of
-- elite packs, then the Prism Hydra's chamber (its arena, built by WildService.BuildBossArenas at CHAMBER). Creatures
-- keep their HP from room to room. Monsters come from the Frontier's species. Plain data so Lune tests can load it.
return {
	BOSS = "prismHydra", -- the chamber's boss (Config/Bosses)
	-- Each room: a pack of `count` elites at `level`, names cycled through `species` (mixed elements)
	ROOMS = {
		{ species = { "Frost Wisp", "Shade Lynx" }, count = 2, level = 45 },
		{ species = { "Storm Hawk", "Lava Brute" }, count = 2, level = 47 },
		{ species = { "Rift Horror", "Prism Crab", "Lava Brute" }, count = 3, level = 50 },
	},

	ARRIVAL_WAIT = 20, -- seconds the run waits for the rest of its group before it starts without them
	OUT_DELAY = 4, -- seconds before a player who is out goes back to the Frontier
	ROOM_INTRO_SECONDS = 3, -- the room seals, then the pack appears after this

	-- Layout (studs). The hall runs from ORIGIN along +X; rooms follow, each ROOM_GAP after the one before; the chamber
	-- (Bosses.ARENA_RADIUS) comes after the third room, its gate on its -X side.
	ORIGIN = { x = 0, y = 0, z = 0 },
	HALL = { length = 40, width = 26, height = 32 },
	ROOM_RADIUS = 28,
	ROOM_GAP = 20, -- corridor between rings
	CORRIDOR_WIDTH = 14,
	CHAMBER = { x = 324, y = 0, z = 0 }, -- hall 40 + 3 rooms (20 + 56 each) + 20 + Bosses.ARENA_RADIUS 36
	WALL_HEIGHT = 30,

	COLORS = {
		FLOOR = { 46, 40, 62 },
		WALL = { 34, 29, 48 },
		DOOR = { 120, 90, 200 },
		CRYSTALS = { { 255, 120, 80 }, { 90, 170, 255 }, { 120, 220, 110 }, { 255, 220, 90 }, { 170, 100, 230 } }, -- the five elements
	},
	LIGHTING = { ambient = { 46, 36, 70 }, outdoorAmbient = { 30, 22, 50 }, brightness = 0.6, clockTime = 0, fogColor = { 18, 10, 32 }, fogEnd = 420 },
}
