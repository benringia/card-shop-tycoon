--!strict
-- The stations' jobs on this client (spec 2026-11-12-timed-upgrades-revive-design; Server/Services/UpgradeJobService
-- sends them as Remotes.UpgradeJobs): what each station holds and how long it has left, counted down here from when the
-- server last said. Read by the station windows' job panel (Util/JobPanel) and the timers over the machines
-- (StationTimerController).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local StationJobs = {}

export type Job = { kind: string, left: number, total: number, name: string, detail: string }

local jobs: { [string]: Job } = {}
local receivedAt = 0
local listeners: { () -> () } = {}
local started = false

local function start()
	if started then
		return
	end
	started = true
	Remotes.UpgradeJobs.OnClientEvent:Connect(function(view: unknown)
		if typeof(view) ~= "table" then
			return
		end
		local fresh: { [string]: Job } = {}
		for station, job in view :: any do
			if typeof(station) == "string" and typeof(job) == "table" and typeof(job.left) == "number" and typeof(job.total) == "number" then
				fresh[station] = {
					kind = tostring(job.kind),
					left = job.left,
					total = math.max(1, job.total),
					name = tostring(job.name),
					detail = tostring(job.detail),
				}
			end
		end
		jobs = fresh
		receivedAt = os.clock()
		for _, listener in listeners do
			task.spawn(listener)
		end
	end)
	Remotes.UpgradeJobs:FireServer() -- the jobs now, in case they were sent before this listened
end

-- A station's job with its time left counted down to now, or nil when it's free
function StationJobs.get(station: string): Job?
	start()
	local job = jobs[station]
	if not job then
		return nil
	end
	local left = math.max(0, job.left - (os.clock() - receivedAt))
	return { kind = job.kind, left = left, total = job.total, name = job.name, detail = job.detail }
end

-- Told whenever the server sends the jobs again (one started, finished or was skipped)
function StationJobs.onChanged(callback: () -> ())
	start()
	table.insert(listeners, callback)
end

return StationJobs
