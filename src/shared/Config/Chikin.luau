--!strict
-- Chikin, the combat tutorial's guide (spec docs/superpowers/specs/2026-11-10-chikin-combat-tutorial-design.md): the
-- owner's black Shih Tzu x toy poodle, Pish's buddy. His steps run on Pish's step machine (Util/TutorialRules) and are
-- saved as data.combat (CombatTutorialService); his lines are in Config/ChikinTalk. Plain data (Lune-tested: no
-- requires, so his numbers that match Pish's are written out; tests/ChikinRules checks they still match). His arrival
-- shot is Pish's (Config/Pish ARRIVAL).

return {
	-- His head as the model came looks about 20 degrees to his left (owner 2026-11-16: "chikin's head is slightly
	-- looking towards the side. straigten it so that he does not look like he's walking sideways"): turned back this
	-- many degrees about his up axis on top of every clip (Util/PishVisual; measured in Blender renders, 2026-11-16)
	HEAD_STRAIGHTEN = -20,
	-- Visit 1 right after Pish's goodbye, in the Wild (owner 2026-11-16: "chikin will make you fight a monster with your
	-- summoned pet. after the monster is dead, he will give you a sword and fight another monster. then will leave"): a
	-- fight with your creature, the free sword, a fight with it (Attack, Dodge, Skill), his goodbye; a hidden wait for
	-- shop level 4; visit 2 leads you to the Meadow Warden's portal. Saved progress is an index into this list.
	STEPS = { "hello", "party", "summon", "wild", "fight", "firstWin", "fight2", "swordWin", "level4", "sword", "wild2", "boss" },
	VISITS = {
		{ "hello", "party", "summon", "wild", "fight", "firstWin", "fight2", "swordWin" },
		{ "sword", "wild2", "boss" },
	},
	WAIT_STEP = "level4", -- no visit: done once the shop reaches SWORD_LEVEL
	SWORD_LEVEL = 4, -- Config/Swords UNLOCK_SHOP_LEVEL: everyone gets the starter sword here
	-- Steps whose last Next moves on (the server records them when the client says so): his hello, the first fight's
	-- end (the sword handed over), the sword fight's end (his goodbye), the level 4 hello and the boss goodbye. A fight
	-- step ends when the fight does (won, lost or run from)
	FINISH_STEPS = { hello = true, firstWin = true, swordWin = true, sword = true, boss = true } :: { [string]: boolean },
	-- Fights that must be won to move on (the sword's: "Great fighting!" after a loss would be wrong); a loss or a run
	-- keeps the step and he says ChikinTalk.RETRY. The first fight ends either way, with its own lost lines
	WIN_TO_PASS = { fight2 = true } :: { [string]: boolean },
	-- His fights where your creatures can't faint (owner 2026-11-17: "make sure pets doesnt die in the first tutorial";
	-- BattleSim `guarded`: they stop at 1 HP, so none rests 5 minutes after a new player's first fights)
	GUARDED_STEPS = { fight = true, fight2 = true } :: { [string]: boolean },
	-- ...and only against the monsters those fights are for: a normal monster up to this level (the Meadow's top,
	-- Wild.ZONES[1].maxLevel; Util/ChikinRules.guards). Elites, bosses and higher zones fight as always (owner
	-- 2026-11-19: a new player walked to a higher-level monster and killed it with creatures that couldn't faint)
	GUARDED_MAX_LEVEL = 5,
	-- His goodbyes: their last button says "Bye!" (a hello's says "Let's go!", Config/ChikinTalk GO)
	BYE_STEPS = { swordWin = true, boss = true } :: { [string]: boolean },
	-- His goodbye after the sword fight points at the town button from this line (owner 2026-11-18: "let the player know
	-- they can stay here and kill monsters to level 4 or go back to town (highlight the town icon) for faster shop
	-- exp"): the round ReturnToTown icon in Roblox's top bar (BattleController)
	TOWN_LINE = { step = "swordWin", from = 4 },
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
		swordWin = "Star",
		boss = "Trophy",
	} :: { [string]: string },
	-- Focus mode (the owner 2026-11-11: "the screen is really crowded", pick A): while he leads in town the calm HUD's
	-- pieces (Util/Hud: party, weapons, bosses, buffs, mascot) hide but those his step uses; the Wild keeps the whole
	-- HUD; the peeking Pish waits till the tour is over (Util/TutorialRules.chikinFocus)
	FOCUS = {
		summon = { "party" },
		-- his level 4 visit keeps the quest strip (owner 2026-11-19: "at level 4 when he appear. the quest disappears
		-- too. it should not")
		sword = { "weapons", "quests" },
		wild2 = { "quests" },
		boss = { "quests" },
	} :: { [string]: { string } },
	-- ...and the party bar stays through every step (owner 2026-11-20: "it should appear on the first time the player
	-- got a pet and then never disappear"; it used to go whenever he led, so it vanished when he came back at level 4)
	FOCUS_ALWAYS = { "party" },
	-- Steps whose waiting line has a "Got it!" that sends him off for good (owner 2026-11-19: "add a GOT IT for chikin
	-- too"): his level 4 visit's walk to the Wild, like Pish's lessons. His first visit keeps its Skip (ChikinRules.gotIt)
	GOT_IT_STEPS = { wild2 = true } :: { [string]: boolean },
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
		homeNap = 0.5,
		petHoldMax = 8, -- seconds petting can hold him in one place (Util/PishPath.holdEnd)
		idleClips = { "sit", "sniff", "bark", "playBow", "headTilt", "shake", "scratch", "happyHop", "dig", "tailChase" },
		-- He greets a player who comes within `range` studs (the owner 2026-11-11: "Make chicken greet you or other player
		-- when your at a certain distance from them"; Util/GreetRules): the nearest one he hasn't greeted in `cooldown`
		-- seconds, every `every` seconds at most; he stops `hold` seconds, faces them, plays one of `clips` and barks,
		-- and a bubble over him says one of ChikinTalk.GREETS with their name
		-- (owner 2026-11-12: a hello for walking up to him, again after `cooldown`; none in the first `joinGrace` seconds)
		greet = { range = 16, cooldown = 30, every = 0.5, hold = 2.5, joinGrace = 15, clips = { "playBow", "happyHop", "bark" } },
		stops = {
			{ x = 110, z = -20, weight = 3 }, -- the Wild's trailhead
			{ x = 110, z = 20, weight = 3 }, -- the Frontier's
			{ x = 126, z = -25, weight = 2 }, -- a little way up each
			{ x = 126, z = 25, weight = 2 },
			{ x = 96, z = 0, weight = 2 }, -- the street's east end
			{ x = 80, z = -14, weight = 1 },
			{ x = 80, z = 14, weight = 1 },
			-- home: in front of his bed by the dog house in the plaza (owner 2026-11-20: "add the dog house as a stop for
			-- both dogs"; the spot is PlazaLayout.dogHomes' second, Lune-checked); there he naps `homeNap` of the time
			{ x = 13.9, z = -8.34, weight = 2, home = true },
			{ x = -110, z = 0, weight = 1 }, -- the Arena's trailhead, across town
			{ x = -96, z = 0, weight = 1 },
		},
	},
	-- Chikin's Courage: petting him (anyone within `petRange` studs whose combat tour is done) makes their creatures hit
	-- `share` harder for `seconds`, once per `cooldown` per player (saved as data.combat's pishLuckAt; BattleSim boosts)
	COURAGE = { petRange = 12, seconds = 300, cooldown = 900, share = 0.1 },
}
