--!strict
-- A price being tapped up and down (the Prices window's steppers, a card case's): what to show while the taps are on
-- their way to the server. Pure, Lune-tested (tests/PriceTaps).
--
-- Taps collect in `pending` and go to the server together a moment after the last one (`flush`). A sent price keeps
-- showing until the server's own price says the same (or `wait` seconds pass: the server changed or refused it).
-- Owner 2026-11-20: "pressing the + and - sometimes goes down suddenly": the sent taps used to be forgotten at once, so
-- for the moment before the server's price came back the old one showed, and the next tap started again from it.
local PriceTaps = {}

type Sent = { price: number, at: number }
export type State = {
	wait: number,
	pending: { [any]: number }, -- tapped, not sent yet
	sent: { [any]: Sent }, -- sent, the server's price not back yet
}

-- `wait`: seconds a sent price shows without the server agreeing (Config/Pricing ECHO_SECONDS)
function PriceTaps.new(wait: number): State
	return { wait = wait, pending = {}, sent = {} }
end

-- The price to show for `key` (a product id, a case's slot) when the server says `server`, at time `now`
function PriceTaps.shown(state: State, key: any, server: number, now: number): number
	local tapped = state.pending[key]
	if tapped then
		return tapped
	end
	local sent = state.sent[key]
	if not sent then
		return server
	end
	if math.abs(sent.price - server) < 0.005 or now - sent.at >= state.wait then
		state.sent[key] = nil -- it arrived, or the server had other ideas: its word from here on
		return server
	end
	return sent.price
end

function PriceTaps.tap(state: State, key: any, price: number)
	state.pending[key] = price
end

-- The taps to send now ({ [key] = price }), nil when there are none; they keep showing until the server answers
function PriceTaps.flush(state: State, now: number): { [any]: number }?
	if next(state.pending) == nil then
		return nil
	end
	local changes = state.pending
	for key, price in changes do
		state.sent[key] = { price = price, at = now }
	end
	state.pending = {}
	return changes
end

-- Forgets one key's taps (its card left the case), or all of them (nil: another case opened)
function PriceTaps.forget(state: State, key: any?)
	if key == nil then
		state.pending = {}
		state.sent = {}
		return
	end
	state.pending[key] = nil
	state.sent[key] = nil
end

return PriceTaps
