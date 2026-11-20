--!strict
-- Rules for the fight effects (Util/FightFx, Config/AttackFx): how many may play at once (fewer with the low-graphics
-- switch off, so a full group fight stays smooth on phones) and which attack an element does. Pure, Lune-tested.
local FightFxRules = {}

-- Whether one more effect may start with `active` already playing
function FightFxRules.budget(active: number, extras: boolean, cfg: any): boolean
	return active < (if extras then cfg.MAX_ACTIVE else cfg.MAX_ACTIVE_LOW)
end

-- A boss's rock fissure (Config/AttackFx BOSS fissure; ElementFx.rockFissure) at its size for this moment (owner
-- 2026-11-12, "4 people in a party ... ensure smoothness"): full when it's the only one; with the low-graphics switch
-- off fewer cracks, pieces and rocks and no caps but the tips' crystals (`spec.low`); `crowded` (another one just
-- tore open on this screen, a group's cone hitting several at once) a small crack with no spikes
export type FissureDetail = { cracks: number, segments: number, rocks: number, spikes: boolean, caps: boolean }
function FightFxRules.fissureDetail(spec: any, extras: boolean, crowded: boolean): FissureDetail
	if crowded then
		return { cracks = math.min(2, spec.cracks), segments = math.max(3, spec.segments - 3), rocks = math.min(2, spec.rocks), spikes = false, caps = false }
	end
	if not extras then
		return { cracks = spec.low.cracks, segments = spec.low.segments, rocks = spec.low.rocks, spikes = true, caps = false }
	end
	return { cracks = spec.cracks, segments = spec.segments, rocks = spec.rocks, spikes = true, caps = true }
end

-- Whether a fissure tearing open `now` comes within `window` seconds of the last full one (`last`, nil: none yet)
function FightFxRules.fissureCrowded(now: number, last: number?, window: number): boolean
	return last ~= nil and now - last < window
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

-- How many projectiles an element's basic attack throws at once: its own `shots` (Bloom's thorn volley), plus the
-- grade's `extra` for one with `gradeShots` (Ember: one more fireball at A, two at S)
function FightFxRules.shots(element: string, extra: number, cfg: any): number
	local entry = cfg.ELEMENT[element]
	if not entry then
		return 1
	end
	return (entry.shots or 1) + (if entry.gradeShots then extra else 0)
end

-- A thrown basic attack's own trail and landing (AttackFx.THROW): nil for the bolt (lightning stays as it is) and for
-- an element without an attack
function FightFxRules.throwLook(element: string, cfg: any): { trail: string, land: string, count: number }?
	local kind = FightFxRules.kindFor(element, cfg)
	if not kind or kind == "bolt" then
		return nil
	end
	return cfg.THROW.ELEMENT[element]
end

-- How big a creature's basic attack looks for its grade (AttackFx.GRADE; C for no grade or an unknown one)
function FightFxRules.tier(grade: string?, cfg: any): { scale: number, sparks: number, extra: number, shake: number }
	return (if grade then cfg.GRADE[grade] else nil) or cfg.GRADE.C
end

-- ...and for its card's rarity on top (AttackFx.RARITY): the grade's size, sparks and shake times the rarity's, the
-- size capped at MAX_SCALE, the grade's extras as they are, and the rarity's `flair` (0 none, 1 a sparkle, 2 a ring
-- too). No rarity or an unknown one: the grade alone
function FightFxRules.look(grade: string?, rarity: string?, cfg: any): { scale: number, sparks: number, extra: number, shake: number, flair: number }
	local tier = FightFxRules.tier(grade, cfg)
	local by = if rarity then cfg.RARITY[rarity] else nil
	if not by then
		return { scale = tier.scale, sparks = tier.sparks, extra = tier.extra, shake = tier.shake, flair = 0 }
	end
	return {
		scale = math.min(tier.scale * by.scale, cfg.MAX_SCALE),
		sparks = tier.sparks * by.sparks,
		extra = tier.extra,
		shake = tier.shake * by.shake,
		flair = by.flair,
	}
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

-- A boss's normal hit that travels (Config/AttackFx BOSS_HIT): how long after its charge it leaves and how long it flies,
-- so it lands as the hit does (`seconds`, the charge's wind-up): `travel` of the wind-up, within minTravel..maxTravel,
-- never longer than the wind-up itself
function FightFxRules.bossThrow(seconds: number, cfg: any): (number, number)
	local wanted = math.clamp(seconds * cfg.travel, cfg.minTravel, cfg.maxTravel)
	local travel = math.max(0, math.min(wanted, seconds))
	return math.max(0, seconds - travel), travel
end

-- What a boss's strike style throws at its target (BOSS_HIT throws); nil for a wild monster's strikes
function FightFxRules.throwStyle(strike: string?, cfg: any): string?
	return if strike then cfg.throws[strike] else nil
end

-- A creature's grade look in a boss fight (Config/AttackFx BOSS_TONE): smaller, fewer sparks, less shake, its extras
-- capped (no grade S sky strike, pillar or screen flash on every hit); as it is anywhere else
function FightFxRules.toned(tier: { scale: number, sparks: number, extra: number, shake: number, flair: number? }, bossFight: boolean, tone: any): { scale: number, sparks: number, extra: number, shake: number, flair: number }
	local flair = tier.flair or 0
	if not bossFight then
		return { scale = tier.scale, sparks = tier.sparks, extra = tier.extra, shake = tier.shake, flair = flair }
	end
	return {
		scale = tier.scale * tone.scale,
		sparks = tier.sparks * tone.sparks,
		extra = math.min(tier.extra, tone.extra),
		shake = tier.shake * tone.shake,
		flair = math.min(flair, tone.flair),
	}
end

-- How much bigger a creature's hits look on its foe (`foe`: PackHit.scaleFor its model), at most `foeMax` in a boss fight
function FightFxRules.foeCap(foe: number, bossFight: boolean, tone: any): number
	return if bossFight then math.min(foe, tone.foeMax) else foe
end

return FightFxRules
