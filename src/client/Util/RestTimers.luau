--!strict
-- Which of your cards are resting after fainting in a fight, counting down locally between the server's
-- RestChanged updates (seconds left per card, and whether you stand at the plaza spring).
-- Used by the party bar and the Party panel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local RestTimers = {}

local untilClock: { [string]: number } = {} -- beastId -> os.clock() when it can fight again
local nearSpring = false
local changed = Instance.new("BindableEvent")

RestTimers.Changed = changed.Event

-- Whole seconds left (0 = rested)
function RestTimers.GetSeconds(beastId: string): number
	local untilTime = untilClock[beastId]
	return if untilTime then math.max(0, math.ceil(untilTime - os.clock())) else 0
end

function RestTimers.IsNearSpring(): boolean
	return nearSpring
end

function RestTimers.Format(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

Remotes.RestChanged.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.entries) ~= "table" then
		return
	end
	local now = os.clock()
	untilClock = {}
	for _, entry in payload.entries do
		if typeof(entry) == "table" and typeof(entry.beastId) == "string" and typeof(entry.seconds) == "number" then
			untilClock[entry.beastId] = now + entry.seconds
		end
	end
	nearSpring = payload.nearSpring == true
	changed:Fire()
end)

return RestTimers
