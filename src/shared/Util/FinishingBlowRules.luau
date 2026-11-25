--!strict
-- The finishing blow's rules (Config/FinishingBlow; spec 2026-11-25-finishing-blow-design): whose last hit gets the
-- moment, a knockout's beat, launch and kick with or without it, and how long the whole knockout takes. Pure, no
-- requires (Lune-tested: tests/FinishingBlowRules).
local FinishingBlowRules = {}

export type Moment = {
	hold: number,
	power: number,
	shake: number,
	zoom: number,
	zoomIn: number,
	back: number,
	sound: string,
	volume: number,
	flash: number,
}

-- The bits of Config/MonsterKO these rules read
export type Knockout = {
	hitStop: number,
	shake: number,
	maxFlight: number,
	settleSeconds: number,
	holdSeconds: number,
	poofSeconds: number,
	elite: { power: number, shake: number },
}

-- A beaten monster gets the moment on your screen only while your fight is running and it is that fight's monster
-- (you ran or lost and someone else beat it: no)
function FinishingBlowRules.mine(fighting: boolean, isFightMonster: boolean): boolean
	return fighting and isFightMonster
end

-- The beat holds one of your character's playing animations only while it moves: one already paused (the sword's own
-- hit-stop, a kneel) stays its owner's to let go
function FinishingBlowRules.freezes(speed: number): boolean
	return speed > 0
end

-- The speed a held animation goes back to once the beat is over: its own from before, only while it's still paused
-- (its owner didn't change it meanwhile); nil: leave it. Never back to a stop (owner 2026-11-25: "character has no
-- animation after the boss fight": a cut paused by its own hit-stop as the boss fell was put back to 0 for good)
function FinishingBlowRules.release(before: number, current: number): number?
	if before <= 0 or current ~= 0 then
		return nil
	end
	return before
end

-- A knockout's beat (seconds), launch (times a plain one's) and camera kick: a moment's when there is one, an elite's
-- extra launch and kick on top either way
function FinishingBlowRules.knockout(ko: Knockout, elite: boolean, moment: Moment?): (number, number, number)
	local hitStop = if moment then moment.hold else ko.hitStop
	local power = (if moment then moment.power else 1) * (if elite then ko.elite.power else 1)
	local shake = (if moment then moment.shake else ko.shake) * (if elite then ko.elite.shake else 1)
	return hitStop, power, shake
end

-- The longest a knockout with this beat takes: the beat, the longest flight, settling, the dizzy stars and the poof
function FinishingBlowRules.knockoutSeconds(ko: Knockout, hitStop: number): number
	return hitStop + ko.maxFlight + ko.settleSeconds + ko.holdSeconds + ko.poofSeconds
end

return FinishingBlowRules
