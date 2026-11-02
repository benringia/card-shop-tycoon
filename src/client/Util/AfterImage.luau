--!strict
-- Dodge after-images (spec 2026-11-02-you-in-the-fight-design): glowing copies of a character left behind along its
-- dash, each fading out. Local only; every part copy is anchored and takes no part in physics.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local AfterImage = {}

local COLOR = Color3.fromRGB(120, 190, 255)
local START_TRANSPARENCY = 0.45

local function folder(): Folder
	local existing = workspace:FindFirstChild("AfterImages")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "AfterImages"
	made.Parent = workspace
	return made
end

-- One frozen glowing copy of the character as it stands now
local function ghostOf(character: Model, seconds: number)
	local ghost = Instance.new("Model")
	ghost.Name = "AfterImage"
	local fade = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, part in character:GetDescendants() do
		if not part:IsA("BasePart") or part.Name == "HumanoidRootPart" or part.Transparency >= 1 then
			continue
		end
		local mesh = part:FindFirstChildOfClass("SpecialMesh") -- accessory handles keep their shape in one
		local copy = part:Clone()
		copy:ClearAllChildren()
		if mesh then
			mesh:Clone().Parent = copy
		end
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanQuery = false
		copy.CanTouch = false
		copy.CastShadow = false
		copy.Material = Enum.Material.Neon
		copy.Color = COLOR
		copy.Transparency = START_TRANSPARENCY
		if copy:IsA("MeshPart") then
			copy.TextureID = ""
		end
		copy.Parent = ghost
		TweenService:Create(copy, fade, { Transparency = 1 }):Play()
	end
	ghost.Parent = folder()
	Debris:AddItem(ghost, seconds + 0.1)
end

-- `count` copies spread over the dash, each fading over `seconds`
function AfterImage.spawn(character: Model, count: number, seconds: number)
	task.spawn(function()
		for _ = 1, count do
			if not character.Parent then
				return
			end
			ghostOf(character, seconds)
			task.wait(seconds / (count + 1))
		end
	end)
end

return AfterImage
