--!strict
-- Chikin, the combat tutorial's guide (spec docs/superpowers/specs/2026-11-10-chikin-combat-tutorial-design.md): the
-- owner's black Shih Tzu x toy poodle, Pish's buddy. His steps run on Pish's step machine (Util/TutorialRules) and are
-- saved as data.combat (CombatTutorialService); his lines are in Config/ChikinTalk. Plain data (Lune-tested: no
-- requires, so his numbers that match Pish's are written out; tests/ChikinRules checks they still match). His arrival
-- shot is Pish's (Config/Pish ARRIVAL).

return {
	-- Visit 1 right after Pish's goodbye (the first fight with a creature), a hidden wait for shop level 4, visit 2
	-- with the free sword (Attack, Dodge, Skill), ending at the Meadow Warden's portal
	STEPS = { "party", "summon", "wild", "fight", "firstWin", "level4", "sword", "wild2", "fight2", "boss" },
	VISITS = {
		{ "party", "summon", "wild", "fight", "firstWin" },
		{ "sword", "wild2", "fight2", "boss" },
	},
	WAIT_STEP = "level4", -- no visit: done once the shop reaches SWORD_LEVEL
	SWORD_LEVEL = 4, -- Config/Swords UNLOCK_SHOP_LEVEL: everyone gets the starter sword here
	-- Steps whose last Next moves on (the server records them when the client says so)
	FINISH_STEPS = { firstWin = true, boss = true },
	-- Each step's picture on his talk card (Config/UIIcons)
	STEP_ICONS = {
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
	CHECK_SECONDS = 1, -- how often the server looks at the party, the summon, the Wild and the level
}
