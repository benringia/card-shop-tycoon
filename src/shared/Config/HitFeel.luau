--!strict
-- Hit feel (spec 2026-11-25-hit-feel-design; owner: "the hits feel weak and monsters just stand there"; the numbers
-- the owner felt in a test: "strong feels good", "stepping feels good now"): how a monster reacts to a hit and how a
-- wild monster moves between its attacks. Plain data (tests/HitFeel); Util/HitFeel, MonsterController.
return {
	-- A hit on a monster: a white flash (`flash` fill transparency at its strongest, fading over `flashSeconds`), a jolt
	-- `knock` studs away from the hitter and a lean back `tilt` degrees, out in `out` s and back over `back` s, a pop to
	-- `pop` of its size, its own clip frozen `stop` s. A big hit (your finisher, the dash slash, a creature's finishing
	-- hit, a super) knocks `bigKnock`, leans `bigTilt` times as far, comes back `bigBack` times as slow and freezes
	-- `bigStop` times as long. A boss takes `bossShare` of the jolt and the lean, and never pops.
	REACT = {
		knock = 1.1,
		bigKnock = 2.6,
		tilt = 15,
		bigTilt = 1.4,
		pop = 1.08,
		flash = 0.05,
		flashSeconds = 0.2,
		out = 0.05,
		back = 0.32,
		bigBack = 1.6,
		stop = 0.07,
		bigStop = 1.5,
		bossShare = 0.35,
	},
	-- A wild monster's steps round its spot between attacks (as the Dungeon packs', Config/Bosses IDLE_PACK, but calm;
	-- owner: the test's 0.4-1.2 s at 8 studs/s was "a bit twitchy"): a step every `gap` s at `speed` studs/s, within
	-- `radius` studs (`front` x radius ahead, `back` x radius behind), turning only `turn` of the way toward it so it
	-- keeps facing the fight
	STEP = { gap = { 1.6, 3.2 }, radius = 2.2, front = 0.4, back = 0.5, speed = 4, turn = 0.3 },
	-- Its lunge into a strike: `studs` forward, all the way out by `rise` of the clip, held to `hold`, back by its end
	LUNGE = { studs = 2.6, rise = 0.3, hold = 0.55 },
	-- Studs its steps and lunge may take it from its server spot (where sword hits are judged); a hit's jolt sits on top
	MAX_DRIFT = 3,
}
