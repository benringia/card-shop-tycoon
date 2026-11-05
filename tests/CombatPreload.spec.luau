--!strict
local CombatPreload = require("../src/shared/Util/CombatPreload")
local CombatHud = require("../src/shared/Config/CombatHud")
local SwordFx = require("../src/shared/Config/SwordFx")
local Swords = require("../src/shared/Config/Swords")
local AttackFx = require("../src/shared/Config/AttackFx")
local Victory = require("../src/shared/Config/Victory")
local MoveFx = require("../src/shared/Config/MoveFx")
local Bosses = require("../src/shared/Config/Bosses")
local Party = require("../src/shared/Config/Party")
local LevelUpFx = require("../src/shared/Config/LevelUpFx")
local SuperFx = require("../src/shared/Config/SuperFx")
local expect = require("./lib/expect")

local function has(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

return {
	["every HUD and sword effect texture is preloaded"] = function()
		local ids = CombatPreload.collect(CombatHud, SwordFx, Swords)
		for _, id in { CombatHud.SLANT_FILL, CombatHud.SLANT_EDGE, CombatHud.HIT_FLASH.IMAGE, SwordFx.RING_OUTLINE, SwordFx.CONE_GLOW } do
			expect.equal(has(ids.images, id), true, id)
		end
		for _, key in { "BACK", "EDGE", "FILL", "TICK" } do
			expect.equal(has(ids.images, CombatHud.HP_BAR[key]), true, key)
		end
	end,

	["every sword's sounds and published moves are preloaded"] = function()
		local ids = CombatPreload.collect(CombatHud, SwordFx, Swords)
		local published = 0
		for _, sword in Swords.SWORDS do
			for move, id in sword.animations do
				if id ~= "" then
					published += 1
					expect.equal(has(ids.animations, id), true, move)
				end
			end
			for moment, id in sword.sounds do
				expect.equal(has(ids.sounds, id), true, moment)
			end
		end
		-- every published move (a move waiting to be published, its id empty, plays from its KeyframeSequence in Studio)
		expect.equal(#ids.animations, published, "every published move, once")
		expect.equal(published >= 12, true, "all 12 of the starter sword's moves, published (the sword-moves round's too)")
	end,

	["no empty or repeated ids"] = function()
		local ids = CombatPreload.collect(CombatHud, SwordFx, Swords)
		for kind, list in ids :: any do
			local seen = {}
			for _, id in list do
				expect.equal(string.sub(id, 1, 13), "rbxassetid://", kind)
				expect.equal(seen[id], nil, `{kind} {id} twice`)
				seen[id] = true
			end
		end
	end,

	["the attack effects' textures and sounds are fetched ahead too"] = function()
		local ids = CombatPreload.collect(CombatHud, SwordFx, Swords, AttackFx)
		for name, id in AttackFx.TEXTURES do
			expect.equal(has(ids.images, id), true, name)
		end
		expect.equal(has(ids.sounds, AttackFx.SOUNDS.charge), true, "charge")
		expect.equal(has(ids.sounds, AttackFx.SOUNDS.boom), true, "boom")
		expect.equal(has(ids.sounds, AttackFx.BOSS.meadowWarden.sounds.release), true, "a boss's")
		expect.equal(has(ids.sounds, AttackFx.MONSTER.Mossling.sounds.strike), true, "a monster's")
		expect.equal(has(ids.images, AttackFx.SOUNDS.charge), false, "sounds aren't images")
	end,
	["the end screen's sounds are fetched ahead, so the fanfare plays on time"] = function()
		local ids = CombatPreload.collect(CombatHud, SwordFx, Swords, AttackFx, Victory)
		for moment, id in Victory.SOUNDS do
			expect.equal(has(ids.sounds, id), true, moment)
		end
	end,
	-- The owner (2026-11-05): "some are delay some doesnt play specially on combat (skills/attack/bosses)". A sound made
	-- on the spot waits for its download (seconds at a fight's start, longer than its holder lives: silent), so every
	-- sound a fight can play is fetched ahead and kept loaded (Util/SoundBank)
	["the pet moves, the bosses' roars, summons, creature voices and level-ups are fetched ahead too"] = function()
		local more = { moveFx = MoveFx, bosses = Bosses, party = Party, levelUp = LevelUpFx }
		local ids = CombatPreload.collect(CombatHud, SwordFx, Swords, AttackFx, Victory, more)
		for move, set in MoveFx.SOUNDS do
			for moment, id in set do
				expect.equal(has(ids.sounds, id), true, `{move} {moment}`)
			end
		end
		for name, id in MoveFx.TEXTURES do
			expect.equal(has(ids.images, id), true, name)
		end
		local roars = 0
		for bossId, boss in Bosses.BOSSES do
			if boss.moments then
				roars += 1
				expect.equal(has(ids.sounds, boss.moments.roar), true, bossId)
			end
		end
		expect.equal(roars >= 3, true, "the three Wild bosses roar")
		expect.equal(has(ids.sounds, Party.SUMMON_SOUNDS.summon.id), true, "summon")
		expect.equal(has(ids.sounds, Party.SUMMON_SOUNDS.unsummon.id), true, "unsummon")
		for _, id in Party.VOICE.small do
			expect.equal(has(ids.sounds, id), true, "a small creature's chirp")
		end
		expect.equal(has(ids.sounds, Party.VOICE.big[1]), true, "a big creature's huff")
		local set = LevelUpFx.SOUNDS.sets[LevelUpFx.SOUNDS.default]
		expect.equal(has(ids.sounds, set.sound.id), true, "level-up")
		expect.equal(has(ids.sounds, set.sting.id), true, "level-up sting")
		expect.equal(has(ids.sounds, Party.SUMMON_SOUNDS.options.summon[1].id), false, "not the Studio-only options")
	end,
	-- Super moves (spec 2026-11-05-super-moves-design): their sounds and textures kept loaded like every fight sound
	["the super moves' sounds and textures are fetched ahead too"] = function()
		local copy = table.clone(SuperFx)
		copy.SOUNDS = { Inferno = { call = "rbxassetid://123" } }
		copy.TEXTURES = { crack = "rbxassetid://456" }
		local ids = CombatPreload.collect(CombatHud, SwordFx, Swords, AttackFx, Victory, { superFx = copy })
		expect.equal(has(ids.sounds, "rbxassetid://123"), true, "a super's sound")
		expect.equal(has(ids.images, "rbxassetid://456"), true, "a super's texture")
	end,
}
