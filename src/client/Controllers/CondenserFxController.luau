--!strict
-- Spins and bobs every Rotor in the shops (a Model named Rotor with a RotorY attribute): the Card Condenser's core (a
-- crystal and floating cards) and the Grading Station's floating card and grade hologram, on this client only, so it
-- costs the server nothing. Props builds the machines; only ones near the camera move.
-- Numbers: Config/Town CONDENSER_LOOK.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Town = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Town"))

local CondenserFxController = {}

local rotors: { [Model]: boolean } = {}

local function track(instance: Instance)
	if not instance:IsA("Model") or instance.Name ~= "Rotor" then
		return
	end
	rotors[instance] = true
	instance.Destroying:Connect(function()
		rotors[instance] = nil
	end)
end

function CondenserFxController.Start()
	local plots = workspace:WaitForChild("Plots")
	for _, descendant in plots:GetDescendants() do
		track(descendant)
	end
	plots.DescendantAdded:Connect(track)

	local look = Town.CONDENSER_LOOK
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local t = os.clock()
		local bob = math.sin(t * math.pi * 2 / look.BOB_SECONDS) * look.BOB
		local spin = CFrame.Angles(0, math.rad(t * look.SPIN_SPEED % 360), 0)
		for rotor in rotors do
			local machine = rotor.Parent
			local height = rotor:GetAttribute("RotorY")
			if machine and machine:IsA("Model") and typeof(height) == "number" then
				local home = machine:GetPivot() * CFrame.new(0, height, 0)
				if (home.Position - camera.CFrame.Position).Magnitude <= look.FX_DISTANCE then
					rotor:PivotTo(home * CFrame.new(0, bob, 0) * spin)
				end
			end
		end
	end)
end

return CondenserFxController
