--!strict
-- A placed boss trophy's lights (Town.TROPHY_LOOK; owner 2026-11-23, the Blender trophies): its plinth's Gem lit Neon in
-- the boss's colour (Config/Shelves propColors Gem) and its glowing bits (parts Glow, GlowCore: the Warden's water, the
-- Colossus' lava and fire, the Frost Tyrant's snowflake...) Neon in GLOWS' colours. An imported part wears the pack's
-- palette texture, so it comes off for the colour to show. The code stand-in's Gem is a Neon part already.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Town = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Town"))

local TrophyLooks = {}

local function light(part: BasePart, color: Color3)
	if part:IsA("MeshPart") then
		pcall(function()
			part.TextureID = ""
		end)
	end
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	part.Material = Enum.Material.Neon
	part.Color = color
end

-- Lights `model` (the trophy drawn for slot `prop`): its Gem in `gem` (the boss's colour), its glow parts in theirs
function TrophyLooks.finish(model: Model, prop: string, gem: Color3?)
	local glows: { [string]: { number } } = Town.TROPHY_LOOK.GLOWS[prop] or {}
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local rgb = glows[part.Name]
		if part.Name == "Gem" and gem then
			light(part, gem)
		elseif rgb then
			light(part, Color3.fromRGB(rgb[1], rgb[2], rgb[3]))
		end
	end
end

return TrophyLooks
