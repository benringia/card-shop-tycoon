--!strict
-- Spins each town portal's vortex on this client (spec 2026-10-30-town-portals-design; Server/Util/PortalBuild builds
-- the portals, tagged TownPortal, with a part named Vortex facing down the trail and a round swirl beam on it). The
-- swirl turns about its own middle (the part's look axis) only while the camera is within Town.PORTAL_FX.SPIN_RANGE and
-- the extras are on (Util/Extras); otherwise it stands still at rest, still showing. The vortexes are looked up every
-- frame (three portals), so a portal that streamed out and back in spins its new copy, never a stale one.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local Extras = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("Extras"))

local PortalFxController = {}

local TAG = "TownPortal"

type Spin = { rest: CFrame, speed: number, turning: boolean }

-- By vortex part; weak keys, so a part that streamed out is forgotten with it
local spins: { [BasePart]: Spin } = setmetatable({}, { __mode = "k" }) :: any

-- The look whose slot the portal model is named after (Props names a placed model after its slot)
local function lookFor(model: Instance): any?
	for _, look in Town.PORTAL_LOOKS do
		if look.slot == model.Name then
			return look
		end
	end
	return nil
end

local function spinFor(model: Instance): (BasePart?, Spin?)
	local part = model:FindFirstChild("Vortex")
	if not (part and part:IsA("BasePart")) then
		return nil, nil
	end
	local spin = spins[part]
	if not spin then
		local look = lookFor(model)
		if not look then
			return nil, nil
		end
		spin = { rest = part.CFrame, speed = look.vortex.spin, turning = false }
		spins[part] = spin
	end
	return part, spin
end

function PortalFxController.Start()
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera.CFrame.Position
		local now = os.clock()
		local enabled = Extras.enabled()
		for _, model in CollectionService:GetTagged(TAG) do
			local part, spin = spinFor(model)
			if part and spin then
				local turning = enabled and (spin.rest.Position - camera).Magnitude <= Town.PORTAL_FX.SPIN_RANGE
				if turning then
					part.CFrame = spin.rest * CFrame.Angles(0, 0, math.rad(spin.speed * now))
				elseif spin.turning then
					part.CFrame = spin.rest
				end
				spin.turning = turning
			end
		end
	end)
end

return PortalFxController
