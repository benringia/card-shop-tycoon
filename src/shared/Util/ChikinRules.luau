--!strict
-- Chikin's combat tutorial rules that the server enforces (Config/Chikin). Pure (callers pass the config), Lune-tested.
local ChikinRules = {}

type Config = { GUARDED_STEPS: { [string]: boolean }, GUARDED_MAX_LEVEL: number, STEPS: { string } }
type Foe = { level: number?, elite: boolean?, boss: string? }

-- Whether a fight keeps this player's creatures from fainting (BattleSim `guarded`): only in his fight steps, and only
-- against the monsters those fights are for: a normal Meadow monster. Against an elite, a boss or a higher zone's
-- monster the creatures faint as always (owner 2026-11-19: a new player could kill anything with creatures that can't
-- faint)
function ChikinRules.guards(cfg: Config, step: string?, foe: Foe): boolean
	if not step or cfg.GUARDED_STEPS[step] ~= true then
		return false
	end
	if foe.boss ~= nil or foe.elite == true then
		return false
	end
	local level = foe.level
	return typeof(level) == "number" and level == level and level <= cfg.GUARDED_MAX_LEVEL
end

-- Whether his arrival plays its cinematic (the camera on his run-in, his name card): only for his very first step.
-- Every later arrival (his second visit at shop level 4, a rejoin mid-visit, back in town) he simply comes to the
-- player (owner 2026-11-20: "chikin cinematic should only appear once. only on its first appearance")
function ChikinRules.arrivesWithCinematic(cfg: { STEPS: { string } }, step: string): boolean
	return step ~= "" and step == cfg.STEPS[1]
end

return ChikinRules
