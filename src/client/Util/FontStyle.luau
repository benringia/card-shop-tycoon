--!strict
-- Rounded fonts everywhere: screens, card faces, name tags. Code across the game still sets Gotham for text;
-- every text object that appears is switched here: bold Gotham to the title font (FredokaOne), plain Gotham to
-- the body font (Nunito). Fonts: Config/UIFonts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIFonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIFonts"))

local FontStyle = {}

local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"

local function restyle(text: TextLabel | TextButton | TextBox)
	local face = text.FontFace
	if face.Family ~= GOTHAM then
		return
	end
	-- Gotham's bold and black weights read as headings; its regular and medium as body text
	local bold = face.Weight == Enum.FontWeight.Bold or face.Weight == Enum.FontWeight.Heavy
	text.FontFace = if bold then UIFonts.BOLD else UIFonts.BODY
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
