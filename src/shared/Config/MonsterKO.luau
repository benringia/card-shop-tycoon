--!strict
-- A beaten wild monster's knockout (owner 2026-11-18: "after killing a normal monster, add some satisfying immersive
-- elements like seeing the monster die or physics or something"; pick A of three storyboards, "make it smooth"): the
-- last hit freezes it a beat and flashes it white, it's launched away from the winner tumbling end over end on its own
-- gravity (Util/MonsterKOMotion: bouncing on the ground, bumping off walls and rocks), plops onto its back with dizzy
-- stars, then poofs into smoke and sparkles as your coins, the reward toast and the XP sparks come (client
-- Util/MonsterKO, MonsterController, BattleController). The server keeps it `SERVER_SECONDS`, locked and marked Fainted,
-- so everyone near sees it (WildService.KnockOut). Not bosses: they keep their own death scenes. Studs and seconds.
-- Plain data (Lune-tested: tests/MonsterKOMotion).
return {
	hitStop = 0.07, -- the frozen beat on the last hit
	pop = 1.08, -- it swells this much in that beat
	speed = 13, -- studs a second away from the winner
	up = 21, -- studs a second up
	gravity = 75, -- studs a second squared: floatier than Roblox's 196 for a cartoon arc
	spin = 900, -- degrees a second end over end as it's launched
	restitution = 0.42, -- of its fall speed it keeps on a bounce
	friction = 0.62, -- of its speed along the ground it keeps on a bounce
	spinKeep = 0.55, -- of its spin it keeps on a bounce
	bounces = 2, -- it settles on this bounce...
	rest = 3, -- ...or once a bounce would be slower than this (studs a second)
	maxFlight = 1.4, -- seconds: it settles by now whatever happens
	bump = 0.5, -- of its speed it keeps bouncing off a wall or a rock
	settleSeconds = 0.3, -- easing onto its back (a little overshoot: a plop)
	holdSeconds = 0.55, -- dizzy stars before the poof
	poofSeconds = 0.18, -- shrinking into the smoke
	range = 160, -- studs from the camera it plays; further away it simply goes
	shake = 0.3, -- the camera kick (Config/AttackFx SHAKE units: a Pet move's)
	bounceShake = 0.08,
	elite = { power = 1.3, shake = 1.6, coins = 2 }, -- elites fly further, kick harder and give twice the coins
	coins = 5, -- coins popping into your cash at the poof (Util/CoinBurst; the winner's screen only)
	stars = { count = 3, size = 0.28, orbit = 0.42, speed = 1.6, above = 0.25 }, -- times the monster's height; turns a second
	-- Particles: sizes times the monster's height (start, end), speeds in studs a second for a 3-stud monster (more for
	-- bigger ones); Roblox's own soft round puff for the dust and the poof's cloud (checked in Studio: the sword's
	-- smoke sheet read as a thin haze)
	PUFF = "rbxasset://textures/particles/smoke_main.dds",
	dust = { count = 8, size = { 0.25, 0.6 }, speed = { 4, 8 }, lifetime = { 0.35, 0.6 } }, -- a bounce's puff
	smoke = { count = 22, size = { 0.55, 1.3 }, speed = { 5, 11 }, lifetime = { 0.5, 0.8 } }, -- the poof's cloud
	sparkles = { count = 14, size = { 0.3, 0.08 }, speed = { 8, 14 }, lifetime = { 0.4, 0.7 } }, -- gold stars out of it
	-- Licensed Pro Sound Effects (all in use elsewhere): the launch, each bounce, the poof, the coins
	sounds = {
		launch = { id = "rbxassetid://9120717850", volume = 0.5 }, -- Whoosh Fast Swish By 4
		bounce = { id = "rbxassetid://9118685591", volume = 0.6 }, -- Rocks Dirt Impacts In Ground 12 (muted thud)
		poof = { id = "rbxassetid://9117841516", volume = 0.55 }, -- Pop Airy 2
		coins = { id = "rbxassetid://9113849492", volume = 0.35 }, -- Coins Or Keys Jingle 6
	},
	SERVER_SECONDS = 2.6, -- the server keeps a beaten monster (locked, Fainted) this long, then it goes
}
