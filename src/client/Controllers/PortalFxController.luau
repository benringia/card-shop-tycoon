--!strict
-- Spins each town portal's swirl on this client (spec 2026-10-30-town-portals-design; Server/Util/PortalBuild builds
-- the portals, tagged TownPortal, with a still part named Vortex in the opening carrying one round swirl image per
-- face). Only the images turn, in their own plane (ImageLabel.Rotation), so the swirl spins about its middle and nothing
-- tilts; a beam turned with its part twisted out of the opening. It turns only while the camera is within
-- Town.PORTAL_FX.SPIN_RANGE and the extras are on (Util/Extras); otherwise it stands still, still showing. The swirls
-- are looked up every frame (three portals), so a portal that streamed out and back in turns its new copy.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local Extras = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("Extras"))

local PortalFxController = {}

local TAG = "TownPortal"

-- The look whose slot the portal model is named after (Props names a placed model after its slot)
local function lookFor(model: Instance): any?
	for _, look in Town.PORTAL_LOOKS do
		if look.slot == model.Name then
			return look
		end
	end
	return nil
end

local function turn(part: BasePart, degrees: number)
	for _, gui in part:GetChildren() do
		local swirl = gui:IsA("SurfaceGui") and gui:FindFirstChild("Swirl")
		if swirl and swirl:IsA("ImageLabel") then
			swirl.Rotation = degrees
		end
	end
end

function PortalFxController.Start()
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera.CFrame.Position
		local now = os.clock()
		local enabled = Extras.enabled()
		for _, model in CollectionService:GetTagged(TAG) do
			local part = model:FindFirstChild("Vortex")
			local look = lookFor(model)
			if part and part:IsA("BasePart") and look then
				local turning = enabled and (part.Position - camera).Magnitude <= Town.PORTAL_FX.SPIN_RANGE
				turn(part, if turning then (look.vortex.spin * now) % 360 else 0)
			end
		end
	end)
end

return PortalFxController
