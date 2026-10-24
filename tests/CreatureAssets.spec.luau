--!strict
-- Creature models are free/bought assets: no script inside one may ever reach the game. A Script with
-- RunContext Server/Client runs from ReplicatedStorage before PartyService can strip it, so this test is the
-- real gate: it fails on any script in assets/creatures, assets/monsters or assets/props (and checks the scanner
-- catches nested ones).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local FOLDERS = { "assets/creatures", "assets/monsters", "assets/props", "assets/town", "assets/place-props" }

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

-- A creature model in a pack file: assets/creatures/<pack>.rbxm holds a folder of models
local function findPackModel(pack: string, model: string): any?
	local path = `assets/creatures/{pack}.rbxm`
	if not fs.isFile(path) then
		return nil
	end
	for _, root in roblox.deserializeModel(fs.readFile(path)) do
		local found = if root.Name == model then root else root:FindFirstChild(model)
		if found then
			return found
		end
	end
	return nil
end

return {
	["every card's creature model is in its pack, with the colour variant it asks for"] = function()
		local party = require("../src/shared/Config/Party")
		local cards = require("../src/shared/Config/CardList")
		local names: { [string]: boolean } = {}
		for _, rows in cards do
			for _, row in rows do
				names[row[1]] = true
			end
		end
		local bad = {}
		for card, entry in party.CREATURE_MODELS do
			if not names[card] then
				table.insert(bad, `{card}: not a card`)
			end
			local model = findPackModel(entry.pack, entry.model)
			if not model then
				table.insert(bad, `{card}: no {entry.model} in assets/creatures/{entry.pack}.rbxm`)
			elseif entry.variant then
				local variants = model:FindFirstChild("Variants")
				if not variants or not variants:FindFirstChild(entry.variant) then
					table.insert(bad, `{card}: {entry.model} has no {entry.variant} variant`)
				end
			end
		end
		assert(#bad == 0, `creature models (Party.CREATURE_MODELS):\n    {table.concat(bad, "\n    ")}`)
	end,

	["scanner finds a nested script"] = function()
		local model = roblox.Instance.new("Model")
		local folder = roblox.Instance.new("Folder")
		folder.Parent = model
		local script = roblox.Instance.new("Script")
		script.Parent = folder
		assert(#findScripts({ model }) == 1, "nested script not found")
	end,

	["the prop folder is scanned too"] = function()
		assert(table.find(FOLDERS, "assets/props"), "assets/props is not in FOLDERS")
		assert(table.find(FOLDERS, "assets/town"), "assets/town is not in FOLDERS")
		assert(table.find(FOLDERS, "assets/place-props"), "assets/place-props is not in FOLDERS")
	end,

	["no Rojo-synced prop holds a union (Rojo live sync drops union shapes)"] = function()
		local bad = {}
		for _, folder in { "assets/props", "assets/town" } do
			if fs.isDir(folder) then
				for _, name in fs.readDir(folder) do
					if string.match(name, "%.rbxmx?$") then
						for _, root in roblox.deserializeModel(fs.readFile(`{folder}/{name}`)) do
							for _, instance in { root, table.unpack(root:GetDescendants()) } do
								if instance:IsA("UnionOperation") then
									table.insert(bad, `{folder}/{name}: {instance:GetFullName()}`)
								end
							end
						end
					end
				end
			end
		end
		assert(#bad == 0, `models with unions go in assets/place-props (Insert from File into ReplicatedStorage.PlaceProps):\n    {table.concat(bad, "\n    ")}`)
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
		assert(#bad == 0, `scripts in creature, monster or prop models (delete them before saving):\n    {table.concat(bad, "\n    ")}`)
	end,
}
