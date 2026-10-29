--!strict
-- The 3D pack opening's reveal as a state machine (UI project 3 spec section 4). Pure, Lune-tested.
-- The controller asks tap() what a tap does now and calls done() when the animation it started has finished:
--   Ready -tap-> Tearing -done-> Stacking -done-> Stacked -tap-> Flipping -done-> Shown
--   Shown -tap-> Stowing -done-> Flipping (the next card) ... the last Shown -tap-> Results
-- Taps while something plays do nothing, and a big flip's spotlight locks taps a moment (a double tap can't skip it).
export type Phase = "Ready" | "Tearing" | "Stacking" | "Stacked" | "Flipping" | "Shown" | "Stowing" | "Results"
export type Action = "Tear" | "Flip" | "Next" | "Results"
export type State = { phase: Phase, index: number, count: number, lockedUntil: number }

local OpeningFlow = {}

local function with(state: State, phase: Phase, index: number?, lockedUntil: number?): State
	return { phase = phase, index = index or state.index, count = state.count, lockedUntil = lockedUntil or state.lockedUntil }
end

function OpeningFlow.new(count: number): State
	return { phase = "Ready", index = 0, count = count, lockedUntil = 0 }
end

-- What a tap does now: the new state and the action to play, or nil (and the same state) when it does nothing
function OpeningFlow.tap(state: State, now: number): (State, Action?)
	if state.phase == "Ready" then
		return with(state, "Tearing"), "Tear"
	elseif state.phase == "Stacked" then
		return with(state, "Flipping", 1), "Flip"
	elseif state.phase == "Shown" and now >= state.lockedUntil then
		if state.index < state.count then
			return with(state, "Stowing"), "Next"
		end
		return with(state, "Results"), "Results"
	end
	return state, nil
end

-- The animation for the current phase finished; lock: seconds taps stay ignored after a flip (its spotlight)
function OpeningFlow.done(state: State, now: number, lock: number?): State
	if state.phase == "Tearing" then
		return with(state, "Stacking")
	elseif state.phase == "Stacking" then
		return with(state, if state.count > 0 then "Stacked" else "Results")
	elseif state.phase == "Flipping" then
		return with(state, "Shown", nil, now + (lock or 0))
	elseif state.phase == "Stowing" then
		return with(state, "Flipping", state.index + 1)
	end
	return state
end

-- Straight to the results (for a later Fast Open pass)
function OpeningFlow.skip(state: State): State
	return with(state, "Results", state.count)
end

return OpeningFlow
