--!strict
-- The player in boss fights (spec 2026-11-02-you-in-the-fight-design): rest time, the boss attack ladder, the starter sword
local Bosses = require("../src/shared/Config/Bosses")
local Combat = require("../src/shared/Config/Combat")
local Swords = require("../src/shared/Config/Swords")
local SwordFx = require("../src/shared/Config/SwordFx")
local expect = require("./lib/expect")

local ANIMATIONS = { "draw", "sheath", "cut1", "cut2", "cut3", "skill", "dodge", "flinch", "down", "getUp", "ready", "run" }
local SOUNDS = { "swing1", "swing2", "swing3", "hit", "draw", "dodge", "ring", "down", "getUp" }

return {
	["drawing the sword gleams: a short flare at the blade's tip"] = function()
		local gleam = SwordFx.GLEAM
		expect.equal(gleam.seconds > 0 and gleam.seconds <= 0.5, true, "a short gleam")
		expect.equal(gleam.brightness > 0 and gleam.range > 0 and gleam.size > 0, true, "it shows")
		expect.equal(#gleam.color, 3)
	end,

	["the group retune leaves Dungeon room packs alone"] = function()
		expect.equal(Bosses.GROUP_ATK_STEP, 0.15, "rooms scale with the old step")
		for _, bossId in { "meadowWarden", "caveBroodQueen", "emberColossus" } do
			expect.equal(Bosses.BOSSES[bossId].groupAtkStep, 0.08, `{bossId} keeps its retuned step`)
		end
	end,

	["rest takes five minutes"] = function()
		expect.equal(Combat.REST_SECONDS, 300)
	end,

	["every ladder boss attacks players, harder up the ladder"] = function()
		local want = {
			{ 10, 1.4, 0.30, 0.10 },
			{ 9, 1.3, 0.35, 0.12 },
			{ 8, 1.2, 0.40, 0.14 },
			{ 7, 1.1, 0.45, 0.15 },
			{ 6.5, 1.0, 0.50, 0.17 },
			{ 6, 1.0, 0.55, 0.18 },
			{ 5, 0.9, 0.60, 0.20 },
		}
		expect.equal(#Bosses.LADDER, #want, "one row per ladder boss")
		for index, bossId in Bosses.LADDER do
			local attacks = Bosses.BOSSES[bossId].playerAttacks
			expect.equal(attacks.every, want[index][1], `{bossId} every`)
			expect.equal(attacks.warning, want[index][2], `{bossId} warning`)
			expect.near(attacks.big, want[index][3], 1e-9, `{bossId} big`)
			expect.near(attacks.quick, want[index][4], 1e-9, `{bossId} quick`)
		end
		expect.equal((Bosses.BOSSES.prismHydra.playerAttacks.doubleChance or 0) > 0, true, "the Hydra sometimes rings twice")
	end,

	["the starter sword has three cuts, a skill and every animation and sound key"] = function()
		local sword = Swords.SWORDS[Swords.STARTER]
		expect.equal(#sword.combo, 3)
		expect.equal(sword.skill.cooldown, 8)
		for _, key in ANIMATIONS do
			expect.equal(typeof(sword.animations[key]), "string", `animation {key}`)
		end
		for _, key in SOUNDS do
			expect.equal(typeof(sword.sounds[key]), "string", `sound {key}`)
		end
		expect.equal(Swords.UNLOCK_SHOP_LEVEL, Bosses.BOSSES[Bosses.LADDER[1]].shopLevel, "the sword comes when boss 1 opens")
	end,

	["each cut lands inside its own length"] = function()
		for _, sword in Swords.SWORDS do
			for index, cut in sword.combo do
				expect.equal(cut.hitAt > 0 and cut.hitAt < cut.length, true, `{sword.name} cut {index}`)
			end
			expect.equal(sword.skill.hitAt > 0 and sword.skill.hitAt < sword.skill.length, true, `{sword.name} skill`)
		end
	end,
	["every sword has its slash look, the starter a plain steel one"] = function()
		for id, sword in Swords.SWORDS do
			expect.equal(sword.slash ~= nil and #sword.slash.color == 3, true, `{id} colour`)
			expect.equal(sword.slash.scale > 0, true, `{id} size`)
		end
		local starter = Swords.SWORDS.starterSword.slash
		expect.equal(starter.scale, 1, "the starter is the base size")
		expect.equal(starter.color[3] >= starter.color[1], true, "a cool steel colour, no element")
	end,
}
