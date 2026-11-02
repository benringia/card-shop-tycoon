--!strict
-- What the boss fight downloads ahead of time (BattleController preloads it a few seconds after joining), so the
-- HUD, the sword's sounds and its moves are ready the first time a fight starts: every image id in Config/CombatHud
-- and Config/SwordFx, and every sword's sounds and published animations (Config/Swords). Pure (callers pass the
-- configs in), so tests/ can run it in Lune.
local CombatPreload = {}

export type Ids = { images: { string }, sounds: { string }, animations: { string } }

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

function CombatPreload.collect(combatHud: any, swordFx: any, swords: any): Ids
	local ids: Ids = { images = {}, sounds = {}, animations = {} }
	local seenImages, seenSounds, seenAnimations = {}, {}, {}
	scan(combatHud, ids.images, seenImages)
	scan(swordFx, ids.images, seenImages)
	for _, sword in swords.SWORDS do
		scan(sword.sounds, ids.sounds, seenSounds)
		scan(sword.animations, ids.animations, seenAnimations)
	end
	return ids
end

return CombatPreload
