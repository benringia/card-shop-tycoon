--!strict
-- The finishing blow (owner 2026-11-25: picked it "but no KO popout", felt a test: "strong feels good, freeze the
-- creature too"; spec 2026-11-25-finishing-blow-design): your own fight's last hit holds everything a beat (the monster
-- white, your character mid-swing, every creature in the fight), punches your camera in and lands a deep thud; a wild
-- monster's knockout then launches harder (Util/MonsterKO), a boss flashes your screen white before its death scene.
-- Client Util/FinishingBlow, rules Util/FinishingBlowRules. Seconds, degrees; shake in Config/AttackFx SHAKE units.
-- Plain data (Lune-tested: tests/FinishingBlowRules).
return {
	WILD = {
		hold = 0.16, -- everything holds this long (a plain knockout's own beat: Config/MonsterKO hitStop 0.07)
		power = 1.25, -- its launch, times a plain knockout's (an elite's extra on top)
		shake = 0.6, -- the camera kick (a plain knockout's: 0.3; an elite's extra on top)
		zoom = 8, -- degrees your camera punches in...
		zoomIn = 0.05, -- ...this fast, holds, then eases back...
		back = 0.35, -- ...over this long
		sound = "rbxassetid://9117330384", -- Pick Impacts 1 (heavy dirt and rock hits; Magma Golem's strike)
		volume = 0.7,
		flash = 0, -- no screen flash
	},
	BOSS = {
		hold = 0.4, -- the boss's whole body too: its clip, its tip-over, the Hydra's heads wait
		power = 1, -- a boss isn't launched (its death scene plays)
		shake = 1.2,
		zoom = 11,
		zoomIn = 0.05,
		back = 0.35,
		sound = "rbxassetid://9125484367", -- Deep Hits Big Reverberant Booms Rumbling Tail 2 (in use on supers)
		volume = 0.7,
		flash = 0.3, -- your screen goes white this strong, fading over the hold and FLASH_TAIL
	},
	FLASH_TAIL = 0.2, -- seconds the screen flash fades past the hold
	BODY_FLASH = { fill = 0.7, tail = 0.25 }, -- a boss's white body flash: its strongest fill, seconds past the hold
	MARGIN = 0.1, -- seconds a knockout with the wild hold still ends before the server lets the monster go (latency)
}
