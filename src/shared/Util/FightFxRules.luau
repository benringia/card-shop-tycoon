--!strict
-- Rules for the fight effects (Util/FightFx, Config/AttackFx): how many may play at once (fewer with the low-graphics
-- switch off, so a full group fight stays smooth on phones) and which attack an element does. Pure, Lune-tested.
local FightFxRules = {}

-- Whether one more effect may start with `active` already playing
function FightFxRules.budget(active: number, extras: boolean, cfg: any): boolean
	return active < (if extras then cfg.MAX_ACTIVE else cfg.MAX_ACTIVE_LOW)
end

-- "projectile" | "combo" | "bolt" | "slash" for an element, nil for one without an attack
function FightFxRules.kindFor(element: string, cfg: any): string?
	local entry = cfg.ELEMENT[element]
	return if entry then entry.kind else nil
end

-- Whether an element's creatures attack from range (a projectile or a bolt): they stand further back in a fight
-- (Combat.RANGED_BACK); combo attackers stay up close
function FightFxRules.isRanged(element: string, cfg: any): boolean
	local kind = FightFxRules.kindFor(element, cfg)
	return kind == "projectile" or kind == "bolt" or kind == "slash"
end

-- How big a creature's basic attack looks for its grade (AttackFx.GRADE; C for no grade or an unknown one)
function FightFxRules.tier(grade: string?, cfg: any): { scale: number, sparks: number, extra: number, shake: number }
	return (if grade then cfg.GRADE[grade] else nil) or cfg.GRADE.C
end

-- Whether an element's basic attack cuts (the Bloom combo, the Shade moon slash): its hits land with the slash
-- streaks; a fireball or bolt lands without them (owner 2026-11-09)
function FightFxRules.cuts(element: string, cfg: any): boolean
	local kind = FightFxRules.kindFor(element, cfg)
	return kind == "combo" or kind == "slash"
end

-- A hit's pack emitters (Config/SwordFx IMPACT and ELEMENT_HIT): the impact's, less the slash streaks and arc (`cut`
-- flagged) when it isn't a cut, then `element`'s own particles
function FightFxRules.hitSpecs(swordFx: any, element: string?, cut: boolean): { any }
	local specs = {}
	for _, spec in swordFx.IMPACT.emitters do
		if cut or not spec.cut then
			table.insert(specs, spec)
		end
	end
	local own = if element then swordFx.ELEMENT_HIT[element] else nil
	for _, spec in own or {} do
		table.insert(specs, spec)
	end
	return specs
end

-- Whether a Pet button move or super move (its kind: "Fireball", "Inferno", ...) has an effect (AttackFx.SPECIALS)
function FightFxRules.hasEffect(kind: string, cfg: any): boolean
	return cfg.SPECIALS[kind] ~= nil
end

-- Whether creatures' basic attacks keep out of the picture at `now` (the owner 2026-11-10: "special skills
-- animation/fx should always be visible"): while a special holds the spotlight (till `holdUntil`: your sword skill, a
-- super) or a camera moment plays (`cinematic`)
function FightFxRules.quiet(now: number, holdUntil: number, cinematic: boolean): boolean
	return cinematic or now < holdUntil
end

-- When the spotlight ends once a special of `seconds` starts at `now`: its length and a `tail` while its effects fade,
-- never sooner than a hold already running (`current`)
function FightFxRules.spotlightUntil(now: number, current: number, seconds: number, tail: number): number
	return math.max(current, now + seconds + tail)
end

return FightFxRules
