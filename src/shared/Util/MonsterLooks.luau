--!strict
-- How a wild monster looks (spec 2026-11-01-wild-monster-models-design): its height (each species its own, elites
-- ELITE_SIZE times that, bosses by their scale), which style moves its bones (only a monster with a model has bones),
-- and when its small effects run. Pure, Lune-tested; MonsterController draws with it.
local MonsterLooks = {}

-- Studs tall. world: Config/Wild or Config/Frontier (its SPECIES, MONSTER_HEIGHT, ELITE_SIZE). A boss: its own height
-- when it has one (Config/Bosses height), else MONSTER_HEIGHT times its scale
function MonsterLooks.height(world: any, species: string, elite: boolean, bossScale: number?, bossHeight: number?): number
	if bossHeight then
		return bossHeight
	end
	if bossScale then
		return world.MONSTER_HEIGHT * bossScale
	end
	local info = world.SPECIES[species]
	local height = if info and info.height then info.height else world.MONSTER_HEIGHT
	return if elite then height * world.ELITE_SIZE else height
end

-- The Party.CREATURE_STYLE / SIGNATURE key its bones move by: a boss's id, else its species; nil for a placeholder
function MonsterLooks.styleKey(species: string, bossId: string?, hasModel: boolean): string?
	if not hasModel then
		return nil
	end
	return bossId or species
end

-- The models (MonsterModels names) a place downloads in the background: its bosses' ids in ladder order (a fight's
-- intro shows its boss at once), then its world's species by name. bosses: Config/Bosses; place: "Wild" |
-- "Frontier" | "Dungeon"
function MonsterLooks.preloadOrder(world: any, bosses: any, place: string): { string }
	local order = {}
	for _, id in bosses.LADDER do
		if bosses.BOSSES[id].place == place then
			table.insert(order, id)
		end
	end
	local species = {}
	for name in world.SPECIES do
		table.insert(species, name)
	end
	table.sort(species)
	for _, name in species do
		table.insert(order, name)
	end
	return order
end

-- Whether a monster's small effects (sparks, smoke) run: within range of the camera, with the extras
-- on (Util/Extras turns them off on a struggling device)
function MonsterLooks.effectsOn(distance: number, range: number, extras: boolean): boolean
	return extras and distance <= range
end

return MonsterLooks
