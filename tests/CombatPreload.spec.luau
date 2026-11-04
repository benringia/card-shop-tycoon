--!strict
local CombatPreload = require("../src/shared/Util/CombatPreload")
local CombatHud = require("../src/shared/Config/CombatHud")
local SwordFx = require("../src/shared/Config/SwordFx")
local Swords = require("../src/shared/Config/Swords")
local AttackFx = require("../src/shared/Config/AttackFx")
local Victory = require("../src/shared/Config/Victory")
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
		expect.equal(published >= 8, true, "the starter sword's moves beyond the sword-moves round's four")
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
}
