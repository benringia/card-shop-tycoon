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

-- The toast stack's bottom-right corner (screen px) so a bubble's tail, `tailRight` px in from its right edge, ends
-- just over `head` (Pish over the cash pill, owner 2026-11-12: "make it seem like he's saying the notification"), at the
-- HUD's `scale`
function ToastRules.stackCorner(head: { x: number, y: number }, tailRight: number, tail: number, scale: number): { x: number, y: number }
	return { x = head.x + tailRight * scale, y = head.y - tail / 2 * scale - 2 }
end

-- How the bubbles sit (owner 2026-11-21): "down" on a touch screen (the stack hangs under the corner's column, tails on
-- top), "row" on a computer with Pish perched on the quest strip (side by side along the top bar's strip, the newest
-- over his head: a stack beside him covered an open window's close button), "up" over the cash at the bottom
-- In a fight (`fight`, owner 2026-11-20: the combat HUD tidy) they hang "under" the foe's bar at the top centre: in
-- the lower right they landed on the skill buttons
function ToastRules.mode(touch: boolean, perched: boolean, fight: boolean?): "down" | "row" | "up" | "under"
	if fight then
		return "under"
	end
	return if touch then "down" elseif perched then "row" else "up"
end

-- A fight's stack: its top-centre point (px) under the foe's bar (`bar`), below whatever hangs from the bar (`hang`:
-- the lowest foot of its states and adds; 0 for none), `gap` px clear
function ToastRules.under(bar: { x: number, y: number, w: number, h: number }, hang: number, gap: number): { x: number, y: number }
	return { x = bar.x + bar.w / 2, y = math.max(bar.y + bar.h, hang) + gap }
end

-- A phone's stack (owner 2026-11-28 "make sure no overlapping elements"): it hangs from `top` (px) across `stack`'s
-- left..right, `reach` px down at most; while the What now? bubble (`keep`) sits there, it hangs `gap` px under it
function ToastRules.hangBelow(top: number, stack: { left: number, right: number }, keep: { x: number, y: number, w: number, h: number }?, reach: number, gap: number): number
	if not keep then
		return top
	end
	local across = keep.x < stack.right and stack.left < keep.x + keep.w
	local down = keep.y < top + reach and top < keep.y + keep.h
	if not (across and down) then
		return top
	end
	return keep.y + keep.h + gap
end

-- Whether a bubble has a tail: someone says it (`speaker`: Pish is on the HUD), or it hangs from a phone's column;
-- a computer's bubbles with no Pish are plain
function ToastRules.tail(mode: string, speaker: boolean): boolean
	if mode == "under" then
		return false -- a fight's toasts under the foe's bar: nobody says them
	end
	return speaker or mode == "down"
end

-- How many bubbles show at once: fewer where there's less room (a phone's short screen, the row along the top)
function ToastRules.max(mode: string, cfg: { MAX: number, MAX_TOUCH: number }): number
	return if mode == "up" then cfg.MAX else cfg.MAX_TOUCH
end

-- Whether the mascot hops now: not since `lastHop` (nil: never) for `gap` seconds
function ToastRules.hopNow(lastHop: number?, now: number, gap: number): boolean
	return lastHop == nil or now - lastHop >= gap
end

return ToastRules
