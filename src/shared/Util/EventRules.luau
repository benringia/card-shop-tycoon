--!strict
-- Weekly events (Config/Events): which one a moment falls in, what it changes, and the chip's words. Pure (callers
-- pass the config and the time), Lune-tested. The server decides (EventService); the client reads the same rules for
-- what it shows.
local EventRules = {}

type Event = {
	id: string,
	name: string,
	lootCooldown: number?,
	chestMaterial: number?,
	luck: { strength: string, seconds: number }?,
}
type Config = { DAYS: { [number]: any } }

local DAY = 86400

-- The UTC weekday of a Unix time: 1 Monday .. 7 Sunday (1970-01-01 was a Thursday)
function EventRules.weekday(unix: number): number
	return (math.floor(unix / DAY) + 3) % 7 + 1
end

function EventRules.dayNumber(unix: number): number
	return math.floor(unix / DAY)
end

-- The event on at this time, or nil. `override` (Studio's /event): an event's id forces it, "off" none; anything else
-- is the calendar
function EventRules.today(cfg: Config, unix: number, override: string?): any?
	if override == "off" then
		return nil
	end
	if override then
		for _, event in cfg.DAYS do
			if event.id == override then
				return event
			end
		end
	end
	return cfg.DAYS[EventRules.weekday(unix)]
end

-- Seconds until the UTC day ends
function EventRules.secondsLeft(unix: number): number
	return DAY - unix % DAY
end

-- The next day's event after today and the seconds until it starts (nil when the calendar is empty)
function EventRules.next(cfg: Config, unix: number): (any?, number)
	local untilMidnight = EventRules.secondsLeft(unix)
	local weekday = EventRules.weekday(unix)
	for ahead = 1, 7 do
		local event = cfg.DAYS[(weekday + ahead - 1) % 7 + 1]
		if event then
			return event, untilMidnight + (ahead - 1) * DAY
		end
	end
	return nil, 0
end

-- A boss's loot timer during this event
function EventRules.lootCooldown(event: Event?, base: number): number
	return if event and event.lootCooldown then math.floor(base * event.lootCooldown) else base
end

-- More of its material in the boss chest you pick
function EventRules.chestBonus(event: Event?): number
	return if event and event.chestMaterial then event.chestMaterial else 0
end

-- The event's free luck, once a UTC day: nil when it has none or `lastDay` (the day it was last given) is today
function EventRules.luckGift(event: Event?, lastDay: number, today: number): { strength: string, seconds: number }?
	if not event or not event.luck or lastDay == today then
		return nil
	end
	return event.luck
end

-- The toast when you arrive or the day turns: `gifted` when the event's luck was given just now; an event that gives
-- luck says its `again` words otherwise (it's already yours)
function EventRules.toast(event: { toast: string, again: string?, luck: any? }, gifted: boolean): string
	if event.luck and not gifted and event.again then
		return event.again
	end
	return event.toast
end

-- A length of time in a few words: "2d", "1d 2h", "5h", "42 min" (never under a minute)
function EventRules.span(seconds: number): string
	local minutes = math.max(1, math.floor(seconds / 60))
	if minutes < 60 then
		return `{minutes} min`
	end
	local hours = minutes // 60
	if hours < 24 then
		return `{hours}h`
	end
	local days, rest = hours // 24, hours % 24
	return if rest > 0 then `{days}d {rest}h` else `{days}d`
end

-- The chip's words and whether an event is on now: "Boss Rush · 5h left", or "Next: Boss Rush in 2h"; nil with an
-- empty calendar
function EventRules.chip(cfg: Config, unix: number, override: string?): (string?, boolean)
	local event = EventRules.today(cfg, unix, override)
	if event then
		return `{event.name} · {EventRules.span(EventRules.secondsLeft(unix))} left`, true
	end
	local coming, wait = EventRules.next(cfg, unix)
	if not coming then
		return nil, false
	end
	return `Next: {coming.name} in {EventRules.span(wait)}`, false
end

-- A saved state made safe: the UTC day the event's free luck was last given (-1: never)
function EventRules.clean(saved: unknown): { luckDay: number }
	local day = if typeof(saved) == "table" then (saved :: any).luckDay else nil
	if typeof(day) ~= "number" or day ~= day or day < 0 or day == math.huge then
		return { luckDay = -1 }
	end
	return { luckDay = math.floor(day) }
end

return EventRules
