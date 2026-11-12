--!strict
-- Defense from party strength (owner 2026-11-12: "lets do party strength for defense", "apply it to bosses too"; spec
-- 2026-11-12-wild-danger-character-window-design): a player's Defense is their party cards' Power added up; a fight's
-- reference is three cards at its recommended Power; hits on the player are scaled by reference over Defense, within
-- Config/Combat DEFENSE (never immune, never crushed). Pure, Lune-tested.
local DefenseRules = {}

-- The party's Power added up (an empty party: 0)
function DefenseRules.defense(powers: { number }): number
	local total = 0
	for _, power in powers do
		total += power
	end
	return total
end

-- A place's reference Defense: a full party at its recommended Power
function DefenseRules.reference(recommended: number, cfg: any): number
	return cfg.DEFENSE.partySize * recommended
end

-- How hard hits land on a player with this Defense against this reference (no Defense: the weakest)
function DefenseRules.scale(defense: number, reference: number, cfg: any): number
	local look = cfg.DEFENSE
	if defense <= 0 then
		return look.max
	end
	return math.clamp(reference / defense, look.min, look.max)
end

-- The ladder boss of a Wild or Frontier zone (its `place` and `zone`): a zone's own `recommended` is a level, so its
-- reference comes from its boss's recommended Power
function DefenseRules.zoneBoss(bosses: any, place: string, zone: number): string?
	for _, bossId in bosses.LADDER do
		local boss = bosses.BOSSES[bossId]
		if boss and boss.place == place and boss.zone == zone then
			return bossId
		end
	end
	return nil
end

-- A fight's reference: a boss's own; a wild fight's, its zone boss's; nil (no scaling) without either (a Dungeon room)
function DefenseRules.referenceFor(boss: any?, bosses: any, place: string, zone: number?, cfg: any): number?
	if boss then
		return DefenseRules.reference(boss.recommended, cfg)
	end
	local bossId = if zone then DefenseRules.zoneBoss(bosses, place, zone) else nil
	return if bossId then DefenseRules.reference(bosses.BOSSES[bossId].recommended, cfg) else nil
end

return DefenseRules
