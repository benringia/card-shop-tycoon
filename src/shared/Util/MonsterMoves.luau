--!strict
-- Which attack clip a boss's or wild monster's body plays for each fight event (spec 2026-11-02-attack-animations-
-- design; Util/FightFx plays them through Util/ClipPlayer). One body, one move at a time:
--   charge (its auto-attack on a creature soon) or telegraph (a quick hit on a player soon): "windup" over the warning,
--     held a little for its hit; never over another move
--   attack on a creature, or a quick hit landing (dodged or not): "strike", chained onto a wind-up; never over another
--     strike (a group hit in one moment is one strike) or a special
--   ring: "specialWindup" over the warning, cutting in over a wind-up or a strike; nothing interrupts it
--   a ring's hit landing (Slam or Swipe, dodged or not): "specialRelease", once for every ring landing together
--   a warned thunderclap (the Storm Sovereign, owner 2026-11-11): "clapWindup" over its warning (its storm circle's
--     "clap" rings play nothing), then "clapRelease" as it claps; a body without them uses its special clips; nothing
--     cuts into either
-- A body without a clip skips that move. Pure, Lune-tested.
local MonsterMoves = {}

export type State = { clip: string?, endsAt: number }
export type Play = { clip: string, speed: number, hold: number }
-- The clips a body has: name -> length in seconds
export type Lengths = { [string]: number }
-- CHARGE_GRACE (Config/AttackFx): how long a wind-up holds past its end for its hit; HIT_GRACE (Config/Combat): how
-- long after its warning a hit on a player lands
export type Cfg = { CHARGE_GRACE: number, HIT_GRACE: number }

local MIN_SPEED, MAX_SPEED = 0.25, 4

function MonsterMoves.new(): State
	return { clip = nil, endsAt = 0 }
end

-- A clip `length` long played over `seconds`
local function speedFor(length: number, seconds: any): number
	local over = tonumber(seconds) or 0
	if over <= 0 then
		return MAX_SPEED
	end
	return math.clamp(length / over, MIN_SPEED, MAX_SPEED)
end

-- The clip to play for `event` now, if any; remembers it in `state`
function MonsterMoves.decide(state: State, event: any, now: number, lengths: Lengths, cfg: Cfg): Play?
	local active = if state.clip and now < state.endsAt then state.clip else nil
	local special = active == "specialWindup" or active == "specialRelease" or active == "clapWindup" or active == "clapRelease"
	local clip: string
	local timed = false -- played over the event's warning
	local hold = 0
	if event.type == "charge" or event.type == "telegraph" then
		if active then
			return nil
		end
		clip, timed = "windup", true
		hold = cfg.CHARGE_GRACE + (if event.type == "telegraph" then cfg.HIT_GRACE else 0)
	elseif event.type == "thunderclap" and event.kind == "windup" then
		if active == "clapWindup" or active == "clapRelease" then
			return nil
		end
		clip, timed = if lengths.clapWindup then "clapWindup" else "specialWindup", true
		hold = cfg.CHARGE_GRACE + cfg.HIT_GRACE
	elseif event.type == "thunderclap" and event.kind == "clap" then
		if active == "clapRelease" then
			return nil
		end
		clip = if lengths.clapRelease then "clapRelease" else "specialRelease"
	elseif event.type == "ring" then
		if special or event.kind == "clap" then
			return nil
		end
		clip, timed = "specialWindup", true
		hold = cfg.CHARGE_GRACE + cfg.HIT_GRACE
	elseif event.type == "attack" and (event.kind == "Slam" or event.kind == "Swipe" or event.kind == "Spikes") then
		if active == "specialRelease" then
			return nil
		end
		clip = "specialRelease"
	elseif event.type == "attack" then
		if active and active ~= "windup" then
			return nil
		end
		clip = "strike"
	else
		return nil
	end
	local length = lengths[clip]
	if not length then
		return nil
	end
	local speed = if timed then speedFor(length, event.seconds) else 1
	state.clip = clip
	state.endsAt = now + length / speed + hold
	return { clip = clip, speed = speed, hold = hold }
end

return MonsterMoves
