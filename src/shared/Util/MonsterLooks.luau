--!strict
-- How a wild monster looks (spec 2026-11-01-wild-monster-models-design): its height (each species its own, elites
-- ELITE_SIZE times that, bosses by their scale), which style moves its bones (only a monster with a model has bones),
-- and how strongly its glow shines (the golem's lava pulses). Pure, Lune-tested; MonsterController draws with it.
local MonsterLooks = {}

export type Glow = { strength: number, pulse: { low: number, high: number, seconds: number }? }

-- Studs tall. world: Config/Wild or Config/Frontier (its SPECIES, MONSTER_HEIGHT, ELITE_SIZE)
function MonsterLooks.height(world: any, species: string, elite: boolean, bossScale: number?): number
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

-- The emissive strength at this moment: steady, or pulsing from low (at 0) to high (half a cycle) and back
function MonsterLooks.glowStrength(glow: Glow?, now: number): number?
	if not glow then
		return nil
	end
	local pulse = glow.pulse
	if not pulse then
		return glow.strength
	end
	return pulse.low + (pulse.high - pulse.low) * (0.5 - 0.5 * math.cos(2 * math.pi * now / pulse.seconds))
end

return MonsterLooks
