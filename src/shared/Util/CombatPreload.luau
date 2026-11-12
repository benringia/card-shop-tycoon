--!strict
-- What the boss fight downloads ahead of time (BattleController preloads it a few seconds after joining), so the
-- HUD, the sword's sounds and its moves are ready the first time a fight starts: every image id in Config/CombatHud
-- and Config/SwordFx, and every sword's sounds and published animations (Config/Swords); with Config/AttackFx, the
-- attack effects' textures (a beam draws as a blank slab until its texture is in) and every attack sound; with
-- Config/Victory, the end screen's sounds (made on the spot they played late); with `more`, the pet moves' sounds and
-- textures (Config/MoveFx), the bosses' roars (Config/Bosses moments), summon sounds and creature voices (Config/Party)
-- the level-up sounds (Config/LevelUpFx default set) and the super moves' (Config/SuperFx): every sound a fight can play (owner 2026-11-05: "some are
-- delay some doesnt play"), kept loaded by Util/SoundBank. Pure (callers pass the configs in), so tests/ can run it in
-- Lune.
local CombatPreload = {}

export type Ids = { images: { string }, sounds: { string }, animations: { string } }
export type More = { moveFx: any?, bosses: any?, party: any?, levelUp: any?, superFx: any?, defeat: any?, weaponLooks: any? }

local PREFIX = "rbxassetid://"

local function add(list: { string }, seen: { [string]: boolean }, id: any)
	if typeof(id) == "string" and string.sub(id, 1, #PREFIX) == PREFIX and #id > #PREFIX and not seen[id] then
		seen[id] = true
		table.insert(list, id)
	end
end

-- Every asset id string anywhere inside a config table
local function scan(value: any, list: { string }, seen: { [string]: boolean })
	if typeof(value) == "table" then
		for _, child in value do
			scan(child, list, seen)
		end
	else
		add(list, seen, value)
	end
end

function CombatPreload.collect(combatHud: any, swordFx: any, swords: any, attackFx: any?, victory: any?, more: More?): Ids
	local ids: Ids = { images = {}, sounds = {}, animations = {} }
	local seenImages, seenSounds, seenAnimations = {}, {}, {}
	for key, value in combatHud do
		if key ~= "SOUNDS" then
			scan(value, ids.images, seenImages)
		end
	end
	scan(combatHud.SOUNDS, ids.sounds, seenSounds) -- the low-HP heartbeat
	scan(swordFx, ids.images, seenImages)
	for _, sword in swords.SWORDS do
		scan(sword.sounds, ids.sounds, seenSounds)
		scan(sword.animations, ids.animations, seenAnimations)
	end
	if attackFx then
		scan(attackFx.TEXTURES, ids.images, seenImages)
		scan(attackFx.SOUNDS, ids.sounds, seenSounds)
		add(ids.sounds, seenSounds, attackFx.SPECIAL_SOUND)
		for _, entry in attackFx.BOSS do
			scan(entry.sounds, ids.sounds, seenSounds)
		end
		for _, entry in attackFx.MONSTER do
			scan(entry.sounds, ids.sounds, seenSounds)
		end
		-- the Frost Tyrant's ice and the Storm Sovereign's thunderclap (Util/IceFx, Util/StormFx)
		for _, kit in { attackFx.ICE, attackFx.STORM } do
			if kit and kit.sounds then
				scan(kit.sounds, ids.sounds, seenSounds)
			end
		end
	end
	if victory then
		scan(victory.SOUNDS, ids.sounds, seenSounds)
	end
	if more and more.moveFx then
		scan(more.moveFx.SOUNDS, ids.sounds, seenSounds)
		scan(more.moveFx.TEXTURES, ids.images, seenImages)
	end
	if more and more.bosses then
		for _, boss in more.bosses.BOSSES do
			if boss.moments then
				add(ids.sounds, seenSounds, boss.moments.roar)
			end
		end
		-- the Frontier's and the Dungeon's boss drone (a bare number in the config)
		if typeof(more.bosses.MUSIC_ID) == "string" and more.bosses.MUSIC_ID ~= "" then
			add(ids.sounds, seenSounds, PREFIX .. more.bosses.MUSIC_ID)
		end
	end
	-- Owner 2026-11-09 ("make sure all effects/models etc are loaded before any fight starts"): the defeat screen's
	-- music, and every weapon's portrait (the fight's weapon chip)
	if more and more.defeat then
		add(ids.sounds, seenSounds, more.defeat.MUSIC)
	end
	if more and more.weaponLooks then
		for _, look in more.weaponLooks.WEAPONS do
			add(ids.images, seenImages, look.portrait)
		end
	end
	if more and more.party then
		add(ids.sounds, seenSounds, more.party.SUMMON_SOUNDS.summon.id)
		add(ids.sounds, seenSounds, more.party.SUMMON_SOUNDS.unsummon.id)
		scan(more.party.VOICE.small, ids.sounds, seenSounds)
		scan(more.party.VOICE.big, ids.sounds, seenSounds)
	end
	if more and more.superFx then
		-- The super moves' sounds and textures (Config/SuperFx, spec 2026-11-05-super-moves-design)
		scan(more.superFx.SOUNDS, ids.sounds, seenSounds)
		scan(more.superFx.TEXTURES, ids.images, seenImages)
	end
	if more and more.levelUp then
		local set = more.levelUp.SOUNDS.sets[more.levelUp.SOUNDS.default]
		if set then
			add(ids.sounds, seenSounds, set.sound.id)
			add(ids.sounds, seenSounds, set.sting.id)
		end
	end
	return ids
end

return CombatPreload
