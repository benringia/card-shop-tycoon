--!strict
-- The Starter Pack's card (spec 2026-11-28-robux-round-design, Starter A): the play counter (after Pish's first visit,
-- in the main place, up to Config/Starter PLAY_SECONDS), when the card is due (an hour played, never shown, not owned,
-- not restricted) and when it may show (a calm moment). Pure; tested in tests/StarterRules. `cfg` is Config/Starter.
local StarterRules = {}

export type State = { played: number, shown: boolean }

-- What the client knows about its screen right now (StarterController gathers them)
export type Facts = {
	ready: boolean, -- loaded, the prologue and welcome seen, Pish's first visit done
	panelOpen: boolean, -- a window open
	screenClear: boolean, -- no purchase dialog or Roblox menu (Util/ScreenClear)
	stageShown: boolean, -- the binder or a pack opening on the stage
	revealing: boolean, -- a weapon reveal playing
	fighting: boolean,
	tour: boolean, -- Pish's or Chikin's tour leading
	register: boolean, -- manning the register
}

-- A save's state made safe: played a whole number from 0 to the hour, shown only when true
function StarterRules.clean(saved: any, cfg: any): State
	local played = if typeof(saved) == "table" then saved.played else nil
	local seconds = if typeof(played) == "number" and played == played then math.floor(played) else 0
	return {
		played = math.clamp(seconds, 0, cfg.PLAY_SECONDS),
		shown = typeof(saved) == "table" and saved.shown == true,
	}
end

-- One more second of play, counted only once Pish's first visit is done and only in the main place, up to the hour
function StarterRules.played(played: number, tutorialDone: boolean, mainPlace: boolean, cfg: any): number
	if not tutorialDone or not mainPlace or played >= cfg.PLAY_SECONDS then
		return played
	end
	return played + 1
end

-- Whether the server sends the card: an hour played, never shown, not owned, not restricted
function StarterRules.offerDue(state: State, owned: boolean, restricted: boolean, cfg: any): boolean
	return state.played >= cfg.PLAY_SECONDS and not state.shown and not owned and not restricted
end

-- Whether the client may show it now: ready, nothing on screen and nothing going on
function StarterRules.mayShow(facts: Facts): boolean
	return facts.ready
		and not facts.panelOpen
		and facts.screenClear
		and not facts.stageShown
		and not facts.revealing
		and not facts.fighting
		and not facts.tour
		and not facts.register
end

return StarterRules
