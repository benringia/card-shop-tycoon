--!strict
-- The town's day cycle on this client (Portal Worlds spec): from the server's start time (workspace attribute
-- DayCycleStart, set by TownService in the main game only), the blended look for now (Util/DayCycle), applied a few
-- times a second. Outside the town (the Wild, the Arena) the fixed afternoon look shows at once; in a Wild boss's
-- arena copy, that arena's own look (Config/DayCycle ARENA_LOOKS, never night); in a valley area with a look of its
-- own (AREA_LOOKS: the Caves), that look blends in over AREA_BLEND seconds and out again as you leave.
-- Nothing is replicated: every client works the same time out from the server clock.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cycle = require(Shared:WaitForChild("Config"):WaitForChild("DayCycle"))
local Bosses = require(Shared:WaitForChild("Config"):WaitForChild("Bosses"))
local Valley = require(Shared:WaitForChild("Config"):WaitForChild("WildValley"))
local SharedUtil = Shared:WaitForChild("Util")
local DayCycle = require(SharedUtil:WaitForChild("DayCycle"))
local WildValley = require(SharedUtil:WaitForChild("WildValley"))
local SkyLook = require(SharedUtil:WaitForChild("SkyLook"))

local DayCycleController = {}

function DayCycleController.Start()
	local elapsed = math.huge
	local mix = 0 -- how far the valley area's own look has blended in
	local mixZone: number? = nil -- the area whose look is blending (kept while it blends out on the pass)
	local lastUpdate = os.clock()
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / Cycle.UPDATE_HZ then
			return
		end
		elapsed = 0
		local start = workspace:GetAttribute("DayCycleStart")
		if typeof(start) ~= "number" or SkyLook.isHeld() then
			return
		end
		-- Where the player is (the camera's focus while they have no character)
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local at = if root and root:IsA("BasePart") then root.Position else workspace.CurrentCamera.Focus.Position
		local now = os.clock()
		local step = now - lastUpdate
		lastUpdate = now
		local arena = WildValley.arenaZoneAt(Valley, Bosses.ARENA_COPIES, at.X, at.Z)
		if arena and Cycle.ARENA_LOOKS[arena] then
			mix = 0
			SkyLook.apply(Cycle.ARENA_LOOKS[arena])
		elseif DayCycle.inTown(Cycle, at.X, at.Z) then
			mix = 0
			SkyLook.apply(DayCycle.lookAt(Cycle, workspace:GetServerTimeNow() - start))
		else
			local zone = WildValley.zoneAt(Valley, { x = at.X, z = at.Z })
			local inside = zone ~= nil and Cycle.AREA_LOOKS[zone] ~= nil
			if inside then
				mixZone = zone
			end
			mix = DayCycle.areaMix(mix, inside, step, Cycle.AREA_BLEND)
			local fixed = DayCycle.fixedLook(Cycle)
			if mix > 0 and mixZone then
				SkyLook.apply(DayCycle.blend(fixed, Cycle.AREA_LOOKS[mixZone], mix))
			else
				SkyLook.apply(fixed)
			end
		end
	end)
end

return DayCycleController
