--!strict
-- Toasts as speech bubbles stacked over the cash pill (owner's pick A, 2026-11-06; Config/Toasts, client
-- UIController): what kind a toast is, how long it stays, what a new one does to the stack (the same message again
-- bumps the newest bubble; past the most, the oldest go) and when the HUD's Cindercub hops. Pure, Lune-tested.
local ToastRules = {}

export type Entry = { id: number, message: string } -- a bubble up now; the stack is oldest first

function ToastRules.kind(isError: boolean, money: boolean): string
	return if isError then "error" elseif money then "money" else "news"
end

-- Seconds a toast stays: its own `duration` times LONGER when it sets one, else ERROR_SECONDS for errors and SECONDS
-- for the rest
function ToastRules.seconds(cfg: any, kind: string, duration: number?): number
	if duration then
		return duration * cfg.LONGER
	end
	return if kind == "error" then cfg.ERROR_SECONDS else cfg.SECONDS
end

-- A new toast with `message` arriving: the id of the bubble to bump instead (the newest, saying the same), or nil and
-- the ids of the oldest bubbles to drop so the new one fits within `max`
function ToastRules.place(stack: { Entry }, message: string, max: number): (number?, { number })
	local newest = stack[#stack]
	if newest and newest.message == message then
		return newest.id, {}
	end
	local drop: { number } = {}
	for index = 1, #stack + 1 - max do
		table.insert(drop, stack[index].id)
	end
	return nil, drop
end

-- A message that starts with its own emoji ("😴 Nightowl is tired...") gives it to the icon chip: (the emoji, the
-- words after it), or (nil, the message) when it starts with plain text
function ToastRules.leadingEmoji(message: string): (string?, string)
	local emoji, rest = string.match(message, "^([\240-\244][\128-\191]+)%s+(.+)$")
	if emoji and rest then
		return emoji, rest
	end
	return nil, message
end

-- Whether Cindercub hops now: not since `lastHop` (nil: never) for `gap` seconds
function ToastRules.hopNow(lastHop: number?, now: number, gap: number): boolean
	return lastHop == nil or now - lastHop >= gap
end

return ToastRules
