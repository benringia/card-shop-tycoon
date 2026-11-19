--!strict
-- The town's dressing (owner 2026-11-19: "do town beauties"; TownDressController, Util/TownDressRules). All client
-- side, built once, and cheap by design (the town's budget goes to the shops' GUIs): small parts with no lights or
-- GUIs, a handful of particles, nothing per frame. Plain data, read by Lune (tests/TownDressRules). Studs, seconds.
--   BANNERS: on a weekly event's day (LOOKS by Config/Events id) a small banner with the event's picture on every
--     street light (`lamp` models in the `root` folder), `out` studs beside its pole at `height`, facing the street,
--     so an event shows in the world and not only on the HUD. Nothing on a plain day. The lamp posts stand in the
--     gaps between the shops: the first build's string lights and pennants ran along the shop fronts ("it's too much.
--     its also covering the shops entrances", the owner the same day) and are gone.
--   LEAVES: leaves drifting down from the plaza's planter trees (`models` in the `roots` folders), `rate` a second
--     each, tinted from `colors`; only while the extras run (Util/Extras).
--   STAR: a shooting star `every` (min, max) seconds once the night is at least `night` deep: a streak `far` studs
--     away and `high` up that crosses `travel` studs in `seconds`.
return {
	BANNERS = {
		lamp = "StreetLight",
		root = "Town",
		height = 7.4,
		out = 1.2,
		size = { x = 1.7, y = 2.6 },
	},
	LOOKS = {
		bossRush = { color = { 150, 40, 60 }, image = "rbxassetid://118220724387080", tint = { 255, 214, 102 } }, -- UIIcons.Trophy
		luckySunday = { color = { 30, 130, 80 }, image = "rbxassetid://95135931686221", tint = { 235, 255, 235 } }, -- Luck.AURA.CLOVER
	},
	LEAVES = {
		models = { "PlanterTree" },
		roots = { "Scenery", "TownDecor" },
		texture = "rbxassetid://75803301364201", -- assets/ui/fx-town/leaf.png (tools/textures/make_leaf.py)
		rate = 1.2,
		life = { 5, 7 },
		size = 0.42,
		colors = { { 150, 205, 95 }, { 205, 190, 80 }, { 230, 150, 70 } },
		box = 6, -- the canopy's footprint the leaves leave from
		drop = 2.5, -- under the tree's top
		minHeight = 6, -- a planter tree stands 9-10 studs: shorter and its canopy hasn't arrived yet
	},
	STAR = {
		every = { 45, 110 },
		night = 0.7,
		far = 520,
		high = { 260, 380 },
		travel = 260,
		seconds = 1.1,
		width = 2.4,
		color = { 255, 250, 225 },
	},
}
