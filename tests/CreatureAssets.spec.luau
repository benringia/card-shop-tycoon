--!strict
-- Creature models are free/bought assets: no script inside one may ever reach the game. A Script with
-- RunContext Server/Client runs from ReplicatedStorage before PartyService can strip it, so this test is the
-- real gate: it fails on any script in assets/creatures, assets/monsters or assets/props (and checks the scanner
-- catches nested ones).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local FOLDERS = { "assets/creatures", "assets/monsters", "assets/props", "assets/town", "assets/place-props", "assets/packs" }
-- The 3D pack models (UI project 3): each file's model and the meshes the game looks up in it
local PACK_MODELS = {
	Pack = { "Body", "Strip", "BodyLow" },
	DeckBox = { "Box", "Lid" },
	DisplayBox = { "Tray", "Packs1", "Packs2", "Packs3", "Packs4", "Packs5", "Packs6" },
}

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

	["assets/packs holds Pack, DeckBox and DisplayBox with their meshes and a look each"] = function()
		local bad = {}
		for name, parts in PACK_MODELS do
			local path = `assets/packs/{name}.rbxm`
			if not fs.isFile(path) then
				table.insert(bad, `{path} missing`)
				continue
			end
			local model = roblox.deserializeModel(fs.readFile(path))[1]
			if not model or model.Name ~= name then
				table.insert(bad, `{path}: the model should be called {name}`)
				continue
			end
			for _, part in parts do
				local mesh = model:FindFirstChild(part)
				if not mesh or not mesh:IsA("MeshPart") then
					table.insert(bad, `{path}: no MeshPart {part}`)
				end
			end
			local looks = model:FindFirstChild("Looks")
			if not looks or #looks:GetChildren() == 0 then
				table.insert(bad, `{path}: no Looks folder with a look in it`)
			end
		end
		assert(#bad == 0, `pack models (docs/packs.md):\n    {table.concat(bad, "\n    ")}`)
	end,

	["portal models carry the parts the game dresses"] = function()
		-- A portal's model is optional (today's frame stands in, Util/PortalLooks.slot); once saved it must hold every
		-- part PortalBuild looks for (Frame, Opening, the effects' spots, the glowing parts), as MeshParts
		local town = require("../src/shared/Config/Town")
		local PortalLooks = require("../src/shared/Util/PortalLooks")
		local bad = {}
		for _, look in town.PORTAL_LOOKS do
			local path = `assets/props/{look.slot}.rbxm`
			if not fs.isFile(path) then
				continue
			end
			local model = roblox.deserializeModel(fs.readFile(path))[1]
			if not model or model.Name ~= look.slot then
				table.insert(bad, `{path}: the model should be called {look.slot}`)
				continue
			end
			for _, part in PortalLooks.parts(look) do
				local mesh = model:FindFirstChild(part)
				if not mesh or not mesh:IsA("MeshPart") then
					table.insert(bad, `{path}: no MeshPart {part}`)
				end
			end
		end
		assert(#bad == 0, `portal models (docs/props.md):\n    {table.concat(bad, "\n    ")}`)
	end,

	["each saved portal's ground part sits at its Blender height over what is buried"] = function()
		-- PortalBuild sinks a portal until its ground part's bottom stands PORTAL_LOOKS.ground.bottom over the ground; that
		-- only holds while the number matches the build: the part's bottom over the model's lowest point, less it, is
		-- what was built below the Blender ground (0 to 3 studs)
		local town = require("../src/shared/Config/Town")
		local bad = {}
		for _, look in town.PORTAL_LOOKS do
			local path = `assets/props/{look.slot}.rbxm`
			if not fs.isFile(path) then
				continue
			end
			local model = roblox.deserializeModel(fs.readFile(path))[1]
			local lowest = math.huge
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					lowest = math.min(lowest, part.CFrame.Position.Y - part.Size.Y / 2)
				end
			end
			local ground = model:FindFirstChild(look.ground.part)
			if not ground then
				table.insert(bad, `{path}: no {look.ground.part}`)
				continue
			end
			local buried = ground.CFrame.Position.Y - ground.Size.Y / 2 - lowest - look.ground.bottom
			if buried < -0.05 or buried > 3 then
				table.insert(bad, `{path}: {buried} studs built below the ground (ground.bottom {look.ground.bottom} doesn't match the build)`)
			end
		end
		assert(#bad == 0, `portal ground heights (Config/Town PORTAL_LOOKS.ground):\n    {table.concat(bad, "\n    ")}`)
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
