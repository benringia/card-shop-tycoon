--!strict
-- One rounded font everywhere (Fredoka, built into Roblox): screens, card faces, name tags. Code across the
-- game still sets the older fonts (FredokaOne for titles and buttons, Gotham for text); every text object that
-- appears is switched to Fredoka here: bold ones to Fredoka Bold, plain Gotham to Fredoka SemiBold.
-- Weights: Config/UIFonts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIFonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIFonts"))

local FontStyle = {}

local OLD_FAMILIES = {
	["rbxasset://fonts/families/FredokaOne.json"] = "BOLD",
	["rbxasset://fonts/families/GothamSSm.json"] = "BODY",
}

local function restyle(text: TextLabel | TextButton | TextBox)
	local face = text.FontFace
	local role = OLD_FAMILIES[face.Family]
	if not role then
		return
	end
	-- Gotham's bold and black weights read as headings; its regular and medium as body text
	if role == "BODY" and (face.Weight == Enum.FontWeight.Bold or face.Weight == Enum.FontWeight.Heavy) then
		role = "BOLD"
	end
	text.FontFace = Font.new(UIFonts.FAMILY, if role == "BOLD" then UIFonts.BOLD else UIFonts.BODY, face.Style)
end

local function watch(instance: Instance)
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		restyle(instance)
		-- Code that sets .Font again later (a label reused for a new state) gets restyled too
		instance:GetPropertyChangedSignal("FontFace"):Connect(function()
			restyle(instance)
		end)
	end
end

local function cover(root: Instance)
	for _, item in root:GetDescendants() do
		watch(item)
	end
	root.DescendantAdded:Connect(watch)
end

-- Starts first on the client: the player's screens and every gui in the world (card faces, tags)
function FontStyle.start()
	cover(Players.LocalPlayer:WaitForChild("PlayerGui"))
	cover(workspace)
end

return FontStyle
