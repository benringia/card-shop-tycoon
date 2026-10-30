--!strict
-- Spins each town portal's vortex on this client (spec 2026-10-30-town-portals-design; Server/Util/PortalBuild builds
-- the portals, tagged TownPortal, with a part named Vortex facing down the trail and the swirl beam across it). It
-- turns about its own look axis only while the camera is within Town.PORTAL_FX.SPIN_RANGE and the extras are on
-- (Util/Extras); otherwise it stands still at rest, still showing. A portal streaming out drops off the list.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local Extras = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("Extras"))

local PortalFxController = {}

local TAG = "TownPortal"

type Spin = { part: BasePart, rest: CFrame, speed: number, turning: boolean }

local spins: { [Instance]: Spin } = {}

-- The look whose slot the portal model is named after (Props names a placed model after its slot)
local function lookFor(model: Instance): any?
	for _, look in Town.PORTAL_LOOKS do
		if look.slot == model.Name then
			return look
		end
	end
	return nil
end

local function track(model: Instance)
	local part = model:FindFirstChild("Vortex")
	local look = lookFor(model)
	if not (part and part:IsA("BasePart") and look) or spins[model] then
		return
	end
	spins[model] = { part = part, rest = part.CFrame, speed = look.vortex.spin, turning = false }
end

function PortalFxController.Start()
	for _, model in CollectionService:GetTagged(TAG) do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
		spins[model] = nil
	end)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera.CFrame.Position
		local now = os.clock()
		local enabled = Extras.enabled()
		for _, spin in spins do
			local turning = enabled and (spin.rest.Position - camera).Magnitude <= Town.PORTAL_FX.SPIN_RANGE
			if turning then
				spin.part.CFrame = spin.rest * CFrame.Angles(0, 0, math.rad(spin.speed * now))
			elseif spin.turning then
				spin.part.CFrame = spin.rest
			end
			spin.turning = turning
		end
	end)
end

return PortalFxController
