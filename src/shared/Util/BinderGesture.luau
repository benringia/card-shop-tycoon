--!strict
-- Who owns a press on the 3D binder (pure, Lune-tested): one pointer at a time (a mouse, or the first finger down),
-- so a second finger or a stray move can't take over a page being dragged, a pointer pressing again after its
-- release went missing (let go outside the window) hands back the stale press to end, and a hold only counts while
-- the finger hasn't moved (a slow swipe stays a swipe). Pointer ids are anything comparable (an InputObject).
local BinderGesture = {}

export type Press = { id: unknown, startX: number, startY: number, x: number, y: number, at: number, moved: boolean }
export type State = { press: Press? }

function BinderGesture.new(): State
	return { press = nil }
end

function BinderGesture.active(state: State): boolean
	return state.press ~= nil
end

-- A pointer goes down. True when it now owns the gesture; a second pointer is refused (false). The same pointer
-- pressing again means its release was lost: the stale press comes back second, for the caller to end.
function BinderGesture.press(state: State, id: unknown, x: number, y: number, now: number): (boolean, Press?)
	local current = state.press
	if current and current.id ~= id then
		return false, nil
	end
	state.press = { id = id, startX = x, startY = y, x = x, y = y, at = now, moved = false }
	return true, current
end

-- The owner moves (other pointers are ignored: false). Once it has gone further than `tapPixels` from where it
-- started it counts as moved, even if it comes back.
function BinderGesture.move(state: State, id: unknown, x: number, y: number, tapPixels: number?): boolean
	local current = state.press
	if not current or current.id ~= id then
		return false
	end
	current.x, current.y = x, y
	local limit = tapPixels or 10
	local dx, dy = x - current.startX, y - current.startY
	if dx * dx + dy * dy > limit * limit then
		current.moved = true
	end
	return true
end

-- The owner lifts: its press ends and comes back; other pointers' lifts end nothing (nil)
function BinderGesture.release(state: State, id: unknown): Press?
	local current = state.press
	if not current or current.id ~= id then
		return nil
	end
	state.press = nil
	return current
end

-- Whether a held finger may show its tooltip: still pressed by it, and it hasn't moved
function BinderGesture.canHold(state: State, id: unknown, tapPixels: number): boolean
	local current = state.press
	if not current or current.id ~= id or current.moved then
		return false
	end
	local dx, dy = current.x - current.startX, current.y - current.startY
	return dx * dx + dy * dy <= tapPixels * tapPixels
end

-- Drops the press without a release (the window lost focus, the binder closed); it comes back to be ended
function BinderGesture.cancel(state: State): Press?
	local current = state.press
	state.press = nil
	return current
end

return BinderGesture
