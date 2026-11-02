--!strict
-- Rules for the fight effects (Util/FightFx, Config/AttackFx): how many may play at once (fewer with the low-graphics
-- switch off, so a full group fight stays smooth on phones) and which attack an element does. Pure, Lune-tested.
local FightFxRules = {}

-- Whether one more effect may start with `active` already playing
function FightFxRules.budget(active: number, extras: boolean, cfg: any): boolean
	return active < (if extras then cfg.MAX_ACTIVE else cfg.MAX_ACTIVE_LOW)
end

-- "projectile" | "combo" | "zip" for an element, nil for one without an attack
function FightFxRules.kindFor(element: string, cfg: any): string?
	local entry = cfg.ELEMENT[element]
	return if entry then entry.kind else nil
end

return FightFxRules
