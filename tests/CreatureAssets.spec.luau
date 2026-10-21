--!strict
-- Creature models are free/bought assets: no script inside one may ever reach the game. A Script with
-- RunContext Server/Client runs from ReplicatedStorage before PartyService can strip it, so this test is the
-- real gate: it fails on any script in assets/creatures or assets/monsters (and checks the scanner catches nested ones).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local FOLDERS = { "assets/creatures", "assets/monsters" }

local function findScripts(roots: { any }): { string }
	local found = {}
	for _, root in roots do
		for _, instance in { root, table.unpack(root:GetDescendants()) } do
			if instance:IsA("LuaSourceContainer") then
				table.insert(found, instance:GetFullName())
			end
		end
	end
	return found
end

return {
	["scanner finds a nested script"] = function()
		local model = roblox.Instance.new("Model")
		local folder = roblox.Instance.new("Folder")
		folder.Parent = model
		local script = roblox.Instance.new("Script")
		script.Parent = folder
		assert(#findScripts({ model }) == 1, "nested script not found")
	end,

	["no creature or monster model contains a script"] = function()
		local bad = {}
		for _, folder in FOLDERS do
			if fs.isDir(folder) then
				for _, name in fs.readDir(folder) do
					if string.match(name, "%.rbxmx?$") then
						local roots = roblox.deserializeModel(fs.readFile(`{folder}/{name}`))
						for _, path in findScripts(roots) do
							table.insert(bad, `{folder}/{name}: {path}`)
						end
					end
				end
			end
		end
		assert(#bad == 0, `scripts in creature models (delete them before saving):\n    {table.concat(bad, "\n    ")}`)
	end,
}
