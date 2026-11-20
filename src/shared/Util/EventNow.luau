--!strict
-- The weekly event on right now (Config/Events, Util/EventRules), for the server (EventService, BossService) and the
-- client (the chip, the Boss Ladder): the UTC day by the server's clock on both sides. In Studio the Workspace
-- attribute EventOverride (set by the server's /event command only) forces an event or switches them off; the live
-- game never reads it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Config"):WaitForChild("Events"))
local EventRules = require(script.Parent:WaitForChild("EventRules"))

local EventNow = {}

EventNow.OVERRIDE = "EventOverride"

local studio = RunService:IsStudio()

-- Unix time by the server's clock (a client's best guess of it)
function EventNow.unix(): number
	return workspace:GetServerTimeNow()
end

function EventNow.override(): string?
	if not studio then
		return nil
	end
	local value = workspace:GetAttribute(EventNow.OVERRIDE)
	return if typeof(value) == "string" and value ~= "" then value else nil
end

-- The event on now, or nil
function EventNow.today(): Events.Event?
	return EventRules.today(Events, EventNow.unix(), EventNow.override())
end

-- The chip's words and whether an event is on (nil words: nothing to show)
function EventNow.chip(): (string?, boolean)
	return EventRules.chip(Events, EventNow.unix(), EventNow.override())
end

-- Whether the chip shows now (an event on, or about to start: EventRules.chipShown)
function EventNow.chipShown(): boolean
	return EventRules.chipShown(Events, EventNow.unix(), EventNow.override())
end

return EventNow
