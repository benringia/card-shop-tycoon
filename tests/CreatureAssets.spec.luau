--!strict
-- Creature models are free/bought assets: no script inside one may ever reach the game. A Script with
-- RunContext Server/Client runs from ReplicatedStorage before PartyService can strip it, so this test is the
-- real gate: it fails on any script in assets/creatures (and checks the scanner catches nested ones).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local FOLDER = "assets/creatures"

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

	["no creature model contains a script"] = function()
		if not fs.isDir(FOLDER) then
			return
		end
		local bad = {}
		for _, name in fs.readDir(FOLDER) do
			if string.match(name, "%.rbxmx?$") then
				local roots = roblox.deserializeModel(fs.readFile(`{FOLDER}/{name}`))
				for _, path in findScripts(roots) do
					table.insert(bad, `{name}: {path}`)
				end
			end
		end
		assert(#bad == 0, `scripts in creature models (delete them before saving):\n    {table.concat(bad, "\n    ")}`)
	end,
}
