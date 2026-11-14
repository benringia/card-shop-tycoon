--!strict
-- The prologue (owner 2026-11-14, spec 2026-11-14-prologue-hydra-design): on a new player's very first join, you at
-- your strongest fight a two-headed Prism Hydra in the real boss fight (BattleService, the boss HUD), then it takes
-- everything; then the welcome flight and Pish's tutorial as before. The cinematics play on that player's screen only
-- (PrologueController); the fight's loadout is lent and never saved (PrologueService; Util/PrologueRules). Plain data.
return {
	-- The Hydra's HP share where the fight ends and act 3 begins
	END_SHARE = 0.25,
	-- Seconds: its HP can't drain faster than reaching END_SHARE at `min` (spamming can't end it early), and always gets
	-- there by `max` (idling still gets there). `atk`: its attack in this fight (the real Prism Hydra's is 46)
	FIGHT = { min = 35, max = 60, atk = 30 },
	-- What you hold and who fights with you: the best (all max level, max stars, Grade S, foil). `weapon`: a
	-- Config/Weapons id, in hand (a boss fight keeps one weapon); creatures: card names, the first out, the others
	-- your swaps
	LOADOUT = {
		weapon = "riftReaper",
		creatures = { "Solarion", "Voidmaw", "Stormking" },
	},
	-- The Hydra: `boss` is the Config/Bosses id the fight uses (its stats, clips, phases); `model` the MonsterModels model it
	-- is drawn with: the young Hydra, one head and two crystal buds on its chest where the others will grow, in the
	-- Dungeon's Prism Hydra's look (owner's pick A 2026-11-15; Meshy, tools/blender/rig_prismHydraYoung.py with the boss's
	-- bone names), the boss's own five-headed model until it's in the game
	HYDRA = { boss = "prismHydra", model = "prismHydraYoung" },
	ACT1 = 15, -- seconds
	-- Seconds into act 3 before the Skip button shows: the opening and the fight can't be skipped (owner 2026-11-15: "the
	-- first fight should not be skippable. only after the fight when hydra is taking your cards"), and the fight has no
	-- Run (BattleService: NO_RUN if it's asked for anyway)
	SKIP_AFTER = 1,
	NO_RUN = "No running from this fight!",
	-- Act 3 (owner 2026-11-15): the Hydra's blow knocks you down (`hit`: the share of its strike clip where it lands;
	-- `seconds` in the air, thrown `back` studs and `height` up, tumbling `flip` degrees backwards onto your face; `lie`:
	-- your middle's height above the floor lying down; `margin`: studs it always keeps you inside the floor's edge;
	-- `near`: studs from you the Hydra stands for it, looming)
	KNOCK = { hit = 0.45, seconds = 0.9, back = 10, height = 6, flip = 270, lie = 0.6, margin = 4, near = 13 },
	-- Then you crawl toward it while it takes everything: `strokes` strokes of `stroke` seconds, a `step` (studs) each;
	-- each arm sweeps along the floor from `reach` (raised past your head) to `pull` (out to the side), elbows
	-- `elbowReach` to `elbowPull`, head lifted `head`, hips `hip`, knees `knee` (degrees); after the last stroke your
	-- head sinks over `collapse` seconds
	CRAWL = { stroke = 1.4, strokes = 4, step = 0.7, reach = 170, pull = 85, elbowReach = 5, elbowPull = 30, head = 40, hip = 6, knee = 35, collapse = 1.2 },
	-- The cards it takes: `count` in all, one every `every` seconds, each flying `seconds`, `size` studs (wide, tall), into
	-- its `mouth` (shares of its height: up from its feet, out in front of its middle)
	CARDS = { count = 20, every = 0.24, seconds = 1.5, size = { 1.4, 1.95 }, mouth = { 0.72, 0.3 } },
	-- You black out: the world blurs (`blur`) and goes dark over `seconds`
	BLACKOUT = { seconds = 2.4, blur = 28 },
	-- You wake in town, on your back in front of your shop: your eyes open by `lids` ({ seconds, open 0-1 }, a blink
	-- between), the world sharp again as they do (`blur` while shut); Pish and Chikin stand over you, `beyond` studs past
	-- your head and `side` to each side, leaning in `lean` degrees; then you get up
	WAKE = {
		lids = { { 0, 0 }, { 1, 0 }, { 1.7, 0.35 }, { 2.1, 0.05 }, { 2.6, 0.05 }, { 3.4, 0.7 }, { 3.8, 0.2 }, { 4.6, 1 } },
		blur = 24,
		beyond = 2.8,
		side = 1.8,
		lean = 24,
		-- how you lie (degrees, PrologueRules.CrawlPose keys): arms a little out from your sides, knees soft
		pose = { rightShoulder = 12, leftShoulder = 12, rightElbow = 12, leftElbow = 12, neck = 0, rightHip = 0, leftHip = 0, rightKnee = 10, leftKnee = 10, advance = 0 },
	},
	-- The lair, built on your screen high above the world: each player's its own `spacing` studs apart (PrologueRules
	-- .arenaCentre). Its floor reaches `radius` + `rim`; where the Hydra and you start (studs from the middle; the
	-- Hydra's leash stays on the floor, tests/PrologueRules)
	ARENA = { height = 1500, spacing = 2000, radius = 60, rim = 15, hydra = { 0, 0, -12 }, player = { 0, 3, 24 } },
	-- How far from your lair's middle the server lets the fight start (your character must be up there)
	START_REACH = 80,
	CAPTIONS = {
		open = "Long ago, you were the greatest card master...",
		fight = "FIGHT!",
		took = "...until the Hydra took everything.",
		-- in town, as your eyes open
		wake = {
			{ dog = "Pish", text = "Hey! Wake up!" },
			{ dog = "Pish", text = "Are you okay?" },
			{ dog = "Chikin", text = "The Hydra took it all? Let's get it all back!" },
		},
	},
}
