--!strict
-- Animates each town portal's swirl on this client (spec 2026-10-30-town-portals-design; Server/Util/PortalBuild builds
-- the portals, tagged TownPortal, with a still panel named Vortex in the opening carrying, per face, a glowing core, the
-- swirl and a smaller inner swirl). The swirls turn in their own plane (ImageLabel.Rotation; the inner one the other way,
-- faster) and the core and the portal's light breathe (Util/PortalLooks.animate), so nothing tilts. Only while the
-- camera is within Town.PORTAL_FX.SPIN_RANGE and the extras are on (Util/Extras); otherwise the layers stand still,
-- still showing. The panels are looked up every frame (three portals), so a portal that streamed back in still moves.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local PortalLooks = require(Shared:WaitForChild("Util"):WaitForChild("PortalLooks"))
local Extras = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("Extras"))

local PortalFxController = {}

local TAG = "TownPortal"

-- The look PortalBuild.dress stamped on the model (its PORTAL_LOOKS key): the Boss and Arena looks share one model,
-- and boss portals are renamed after the boss, so the model's name can't say which look it wears
local function lookFor(model: Instance): any?
	local key = model:GetAttribute("PortalLook")
	return if type(key) == "string" then Town.PORTAL_LOOKS[key] else nil
end

local function pose(part: BasePart, look: any, swirl: number, inner: number, glow: number, light: number)
	for _, gui in part:GetChildren() do
		if gui:IsA("SurfaceGui") then
			local outer = gui:FindFirstChild("Swirl")
			if outer and outer:IsA("ImageLabel") then
				outer.Rotation = swirl
			end
			local small = gui:FindFirstChild("Inner")
			if small and small:IsA("ImageLabel") then
				small.Rotation = inner
			end
			local core = gui:FindFirstChild("Glow")
			if core and core:IsA("ImageLabel") then
				core.ImageTransparency = glow
			end
		elseif gui:IsA("PointLight") then
			gui.Brightness = look.light.brightness * light
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
				if enabled and (part.Position - camera).Magnitude <= Town.PORTAL_FX.SPIN_RANGE then
					local at = PortalLooks.animate(now, look, Town)
					pose(part, look, at.swirl, at.inner, at.glow, at.light)
				else
					pose(part, look, 0, 0, Town.PORTAL_FX.PULSE.glow[1], 1)
				end
			end
		end
	end)
end

return PortalFxController
