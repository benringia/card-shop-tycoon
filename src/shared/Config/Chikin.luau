--!strict
-- Chikin, the combat tutorial's guide (spec docs/superpowers/specs/2026-11-10-chikin-combat-tutorial-design.md): the
-- owner's black Shih Tzu x toy poodle, Pish's buddy. His steps run on Pish's step machine (Util/TutorialRules) and are
-- saved as data.combat (CombatTutorialService); his lines are in Config/ChikinTalk. Plain data (Lune-tested: no
-- requires, so his numbers that match Pish's are written out; tests/ChikinRules checks they still match). His arrival
-- shot is Pish's (Config/Pish ARRIVAL).

return {
	-- Visit 1 right after Pish's goodbye (the first fight with a creature), a hidden wait for shop level 4, visit 2
	-- with the free sword (Attack, Dodge, Skill), ending at the Meadow Warden's portal
	STEPS = { "hello", "party", "summon", "wild", "fight", "firstWin", "level4", "sword", "wild2", "fight2", "boss" },
	VISITS = {
		{ "hello", "party", "summon", "wild", "fight", "firstWin" },
		{ "sword", "wild2", "fight2", "boss" },
	},
	WAIT_STEP = "level4", -- no visit: done once the shop reaches SWORD_LEVEL
	SWORD_LEVEL = 4, -- Config/Swords UNLOCK_SHOP_LEVEL: everyone gets the starter sword here
	-- Steps whose last Next moves on (the server records them when the client says so): his hello, the first fight's
	-- end, the sword's hello and his goodbye. A fight step ends when the fight does (won, lost or run from)
	FINISH_STEPS = { hello = true, firstWin = true, sword = true, boss = true } :: { [string]: boolean },
	-- Fights that must be won to move on (the sword's: "Great fighting!" after a loss would be wrong); a loss or a run
	-- keeps the step and he says ChikinTalk.RETRY. The first fight ends either way, with its own lost lines
	WIN_TO_PASS = { fight2 = true } :: { [string]: boolean },
	-- His goodbyes: their last button says "Bye!" (a hello's says "Let's go!", Config/ChikinTalk GO)
	BYE_STEPS = { firstWin = true, boss = true } :: { [string]: boolean },
	-- Each step's picture on his talk card (Config/UIIcons)
	STEP_ICONS = {
		hello = "Paw",
		party = "Party",
		summon = "Summon",
		wild = "Travel",
		fight = "Attack",
		firstWin = "Star",
		sword = "Sword",
		wild2 = "Travel",
		fight2 = "Sword",
		boss = "Trophy",
	} :: { [string]: string },
	-- Focus mode (the owner 2026-11-11: "the screen is really crowded", pick A): while he leads in town the calm HUD's
	-- pieces (Util/Hud: party, weapons, bosses, buffs, mascot) hide but those his step uses; the Wild keeps the whole
	-- HUD; the peeking Pish waits till the tour is over (Util/TutorialRules.chikinFocus)
	FOCUS = {
		summon = { "party" },
		sword = { "weapons" },
	} :: { [string]: { string } },
	HEIGHT = 2.6, -- studs: Pish's size
	-- Pish's licensed barks (Config/Pish SOUNDS), pitched up a little: a smaller, higher dog
	SOUNDS = {
		bark = "rbxassetid://9113955093",
		whimper = "rbxassetid://9113951583",
		yawn = "",
		yip = "rbxassetid://9113955748",
		dig = "rbxassetid://9114083746",
	} :: { [string]: string },
	SOUND_PITCH = { bark = 1.55, whimper = 1.2, yip = 1.9 } :: { [string]: number },
	SOUND_VOLUME = 1,
	FIGHT_TIP_SECONDS = 7, -- a tip in a fight moves on after this long unused
	FIRST_TIP_SECONDS = 3.5, -- the first ("your creature fights by itself"): a new player's first fight lasts ~12 s
	CHECK_SECONDS = 1, -- how often the server looks at the party, the summon, the Wild and the level

	-- Town Chikin (the owner 2026-11-11: "after chikin's tutorial he will become an NPC too like pish, walking around the
	-- town"; his picks: the portal side of town, a combat buff for 5 minutes; TownChikinService): one dog everyone sees,
	-- walking between `stops` (x, z in the town; picked by `weight`, never the one he's at, Util/PishPath.pickStop):
	-- mostly the Wild and Frontier trailheads at the east end, sometimes across town to the Arena's. He trots past
	-- `trotFrom` studs. Pish keeps the shops and the fountain.
	TOWN = {
		speed = 5,
		trotSpeed = 9,
		trotFrom = 60,
		idleEvery = { 4, 9 },
		napChance = 0.06,
		petHoldMax = 8, -- seconds petting can hold him in one place (Util/PishPath.holdEnd)
		idleClips = { "sit", "sniff", "bark", "playBow", "headTilt", "shake", "scratch", "happyHop", "dig", "tailChase" },
		-- He greets a player who comes within `range` studs (the owner 2026-11-11: "Make chicken greet you or other player
		-- when your at a certain distance from them"; Util/GreetRules): the nearest one he hasn't greeted in `cooldown`
		-- seconds, every `every` seconds at most; he stops `hold` seconds, faces them, plays one of `clips` and barks,
		-- and a bubble over him says one of ChikinTalk.GREETS with their name
		greet = { range = 16, cooldown = 120, every = 0.5, hold = 2.5, clips = { "playBow", "happyHop", "bark" } },
		stops = {
			{ x = 110, z = -20, weight = 3 }, -- the Wild's trailhead
			{ x = 110, z = 20, weight = 3 }, -- the Frontier's
			{ x = 126, z = -25, weight = 2 }, -- a little way up each
			{ x = 126, z = 25, weight = 2 },
			{ x = 96, z = 0, weight = 2 }, -- the street's east end
			{ x = 80, z = -14, weight = 1 },
			{ x = 80, z = 14, weight = 1 },
			{ x = -110, z = 0, weight = 1 }, -- the Arena's trailhead, across town
			{ x = -96, z = 0, weight = 1 },
		},
	},
	-- Chikin's Courage: petting him (anyone within `petRange` studs whose combat tour is done) makes their creatures hit
	-- `share` harder for `seconds`, once per `cooldown` per player (saved as data.combat's pishLuckAt; BattleSim boosts)
	COURAGE = { petRange = 12, seconds = 300, cooldown = 900, share = 0.1 },
}
