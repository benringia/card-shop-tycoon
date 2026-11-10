--!strict
-- Creature models are free/bought assets: no script inside one may ever reach the game. A Script with
-- RunContext Server/Client runs from ReplicatedStorage before PartyService can strip it, so this test is the
-- real gate: it fails on any script in assets/creatures, assets/monsters or assets/props (and checks the scanner
-- catches nested ones).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local expect = require("./lib/expect")

local FOLDERS = { "assets/creatures", "assets/monsters", "assets/props", "assets/town", "assets/place-props", "assets/packs", "assets/weapons", "assets/fx-models", "assets/npcs" }
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

-- A long weapon (a spear or a scythe) is a Head and a Shaft, the Shaft its PrimaryPart (where the hand holds it: the
-- model's origin), every pivot straight (lune run tools/weapons/finish_sword)
local function checkShafted(name: string)
	local path = `assets/weapons/{name}.rbxm`
	assert(fs.isFile(path), `{path} is missing (the owner imports the FBX; docs/weapons.md)`)
	local model = roblox.deserializeModel(fs.readFile(path))[1]
	assert(model and model:IsA("Model") and model.Name == name, `{path} holds the {name} model`)
	assert(model:FindFirstChild("Head") and model:FindFirstChild("Shaft"), `{name} has its Head and Shaft`)
	assert(model.PrimaryPart and model.PrimaryPart.Name == "Shaft", `{name}: the Shaft is its PrimaryPart (lune run tools/weapons/finish_sword)`)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.PivotOffset:GetComponents()
			local straight = r00 == 1 and r11 == 1 and r22 == 1 and r01 == 0 and r02 == 0 and r10 == 0 and r12 == 0 and r20 == 0 and r21 == 0
			assert(straight, `{name} {part.Name}'s PivotOffset is turned (lune run tools/weapons/finish_sword)`)
		end
	end
end

return {
	-- The Frontier valley (spec 2026-11-10-frontier-valley-design, plan Tasks 7 and 8): every Frontier monster and boss
	-- has its own Meshy model, rigged, with its bone clips
	["every Frontier species and boss has its model"] = function()
		local frontier = require("../src/shared/Config/Frontier")
		local bosses = require("../src/shared/Config/Bosses")
		for species in frontier.SPECIES do
			assert(fs.isFile(`assets/monsters/{species}.rbxm`), `assets/monsters/{species}.rbxm is missing`)
		end
		for bossId, boss in bosses.BOSSES do
			if (boss :: any).place == "Frontier" then
				assert(fs.isFile(`assets/monsters/{bossId}.rbxm`), `assets/monsters/{bossId}.rbxm is missing`)
			end
		end
	end,

	["every Frontier boss has its four clips, every Frontier species its two"] = function()
		local frontier = require("../src/shared/Config/Frontier")
		for species in frontier.SPECIES do
			for _, clip in { "windup", "strike" } do
				assert(fs.isFile(`assets/monster-animations/{species}/{clip}.rbxm`), `{species} has no {clip}`)
			end
		end
		for _, bossId in { "frostTyrant", "stormSovereign", "riftDevourer" } do
			for _, clip in { "windup", "strike", "specialWindup", "specialRelease" } do
				assert(fs.isFile(`assets/monster-animations/{bossId}/{clip}.rbxm`), `{bossId} has no {clip}`)
			end
		end
	end,

	["every Frontier model is one rigged MeshPart with its glow"] = function()
		local frontier = require("../src/shared/Config/Frontier")
		local bosses = require("../src/shared/Config/Bosses")
		local names = {}
		for species in frontier.SPECIES do
			table.insert(names, species)
		end
		for bossId, boss in bosses.BOSSES do
			if (boss :: any).place == "Frontier" then
				table.insert(names, bossId)
			end
		end
		for _, name in names do
			local path = `assets/monsters/{name}.rbxm`
			if fs.isFile(path) then
				local model = roblox.deserializeModel(fs.readFile(path))[1]
				expect.equal(model.Name, name, `{path}'s model name`)
				local body = model:FindFirstChildWhichIsA("MeshPart")
				assert(body, `{name} has no MeshPart`)
				assert(body:FindFirstChild("Root", true), `{name} has no bones`)
				assert(body:FindFirstChildWhichIsA("SurfaceAppearance"), `{name} has no SurfaceAppearance (its glow)`)
			end
		end
	end,

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

	["the weapon folder is scanned too, and the starter sword is finished"] = function()
		assert(table.find(FOLDERS, "assets/weapons"), "assets/weapons is not in FOLDERS")
		local roots = roblox.deserializeModel(fs.readFile("assets/weapons/StarterSword.rbxm"))
		local model = roots[1]
		assert(model and model:IsA("Model") and model.Name == "StarterSword", "StarterSword.rbxm holds the StarterSword model")
		for _, name in { "Blade", "Guard", "Grip", "Pommel" } do
			assert(model:FindFirstChild(name), `the sword has its {name}`)
		end
		assert(model.PrimaryPart and model.PrimaryPart.Name == "Grip", "the grip is its PrimaryPart (lune run tools/weapons/finish_sword)")
		-- The importer turns each mesh's pivot: the game reads the grip's frame from the pivot, so it must be straight
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.PivotOffset:GetComponents()
				local straight = r00 == 1 and r11 == 1 and r22 == 1 and r01 == 0 and r02 == 0 and r10 == 0 and r12 == 0 and r20 == 0 and r21 == 0
				assert(straight, `{part.Name}'s PivotOffset is turned (lune run tools/weapons/finish_sword)`)
			end
		end
	end,

	-- Weapons round 2 (spec 2026-11-07-weapons-round2-design 7): each spear is a Head and a Shaft, the Shaft its PrimaryPart
	-- (where the hand holds it: the model's origin, 31% up from the butt), every pivot straight (finish_sword)
	["every spear model is in and finished: Head and Shaft, the Shaft its PrimaryPart"] = function()
		local names = { "MagmaHalberd", "TidalTrident", "TitansLance" }
		for _, element in { "Ember", "Tide", "Bloom", "Volt", "Shade" } do
			table.insert(names, `ForgeSpear_{element}`)
		end
		for _, name in names do
			checkShafted(name)
		end
	end,

	-- Weapons round 3 (spec 2026-11-09-weapons-round3-scythes-design): a scythe is shaped like a spear (Head and Shaft, the
	-- grip a third up the shaft); every scythe marked ready has its model in and finished (this gates `ready`)
	["every ready scythe's model is in and finished: Head and Shaft, the Shaft its PrimaryPart"] = function()
		local weapons = require("../src/shared/Config/Weapons")
		for _, weapon in weapons.WEAPONS do
			if weapon.family == "scythe" and weapon.ready then
				assert(weapon.model, `{weapon.id} is ready but names no model`)
				checkShafted(weapon.model)
			end
		end
	end,

	-- Thousand Cuts' Grim Reaper (spec 2026-11-09-weapons-round3-scythes-design 5.4): one mesh, Reaper, its PrimaryPart,
	-- the model's pivot at the bottom centre (where it rises from the rift; Util/SwordSkillFx moves it by its pivot)
	["the Grim Reaper model is in: its Reaper mesh the PrimaryPart, the pivot at its bottom, straight"] = function()
		local path = "assets/fx-models/GrimReaper.rbxm"
		assert(fs.isFile(path), `{path} is missing (the owner imports tools/blender/build_grim_reaper.py's FBX)`)
		local model = roblox.deserializeModel(fs.readFile(path))[1]
		assert(model and model:IsA("Model") and model.Name == "GrimReaper", `{path} holds the GrimReaper model`)
		local reaper = model:FindFirstChild("Reaper")
		assert(reaper and reaper:IsA("MeshPart"), "its Reaper mesh")
		assert(model.PrimaryPart == reaper, "the Reaper is its PrimaryPart")
		local offset = reaper.PivotOffset
		expect.near(offset.Position.Y, -reaper.Size.Y / 2, 0.05, "the pivot at the bottom")
		local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = offset:GetComponents()
		local straight = r00 == 1 and r11 == 1 and r22 == 1 and r01 == 0 and r02 == 0 and r10 == 0 and r12 == 0 and r20 == 0 and r21 == 0
		assert(straight, "its PivotOffset isn't turned")
	end,

	-- Pish, the tutorial's guide puppy (spec 2026-11-09-tutorial-pish-design): the rig rig_pish.py builds, so his clips
	-- (assets/monster-animations/Pish) find every bone, and the walk (Util/PetAnimator) its PetRig names
	["Pish's model is in: his mesh the PrimaryPart, every bone his clips move, no scripts"] = function()
		local path = "assets/npcs/Pish.rbxm"
		assert(fs.isFile(path), `{path} is missing (the owner saves the imported Pish.fbx model from Studio)`)
		local roots = roblox.deserializeModel(fs.readFile(path))
		local model = roots[1]
		assert(model and model:IsA("Model") and model.Name == "Pish", `{path} holds the Pish model`)
		local mesh = model:FindFirstChild("Pish_Dog")
		assert(mesh and mesh:IsA("MeshPart"), "his Pish_Dog mesh")
		assert(model.PrimaryPart == mesh, "the mesh is his PrimaryPart")
		-- The importer turns the pivot (he'd be drawn on his side): straight, at his feet
		local offset = mesh.PivotOffset
		expect.near(offset.Position.Y, -mesh.Size.Y / 2, 0.05, "the pivot at his feet")
		local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = offset:GetComponents()
		local straight = r00 == 1 and r11 == 1 and r22 == 1 and r01 == 0 and r02 == 0 and r10 == 0 and r12 == 0 and r20 == 0 and r21 == 0
		assert(straight, "his PivotOffset isn't turned")
		local bones = {}
		for _, item in model:GetDescendants() do
			if item:IsA("Bone") then
				bones[item.Name] = true
			end
		end
		local wanted = { "Pelvis", "Spine_0", "Spine_1", "Neck", "Head_0", "Jaw_0", "Ear_Left_0", "Ear_Right_0", "Tail_0", "Tail_1", "Tail_2" }
		for _, leg in { "0_Left", "0_Right", "1_Left", "1_Right" } do
			for i = 0, 2 do
				table.insert(wanted, `{leg}_Limb_{i}`)
			end
		end
		for _, name in wanted do
			assert(bones[name], `his bone {name}`)
		end
		expect.equal(#findScripts(roots), 0, "no scripts")
	end,

	-- Chikin, the combat tutorial's guide (spec 2026-11-10-chikin-combat-tutorial-design): rig_chikin.py's rig, Pish's bones
	-- without the jaw, so Pish's clips (assets/monster-animations/Chikin) find every bone
	["Chikin's model is in: his mesh the PrimaryPart, every bone his clips move, no scripts"] = function()
		local path = "assets/npcs/Chikin.rbxm"
		assert(fs.isFile(path), `{path} is missing (the owner saves the imported Chikin.fbx model from Studio)`)
		local roots = roblox.deserializeModel(fs.readFile(path))
		local model = roots[1]
		assert(model and model:IsA("Model") and model.Name == "Chikin", `{path} holds the Chikin model`)
		local mesh = model:FindFirstChild("Chikin_Dog")
		assert(mesh and mesh:IsA("MeshPart"), "his Chikin_Dog mesh")
		assert(model.PrimaryPart == mesh, "the mesh is his PrimaryPart")
		local offset = mesh.PivotOffset
		expect.near(offset.Position.Y, -mesh.Size.Y / 2, 0.05, "the pivot at his feet")
		local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = offset:GetComponents()
		local straight = r00 == 1 and r11 == 1 and r22 == 1 and r01 == 0 and r02 == 0 and r10 == 0 and r12 == 0 and r20 == 0 and r21 == 0
		assert(straight, "his PivotOffset isn't turned")
		local bones = {}
		for _, item in model:GetDescendants() do
			if item:IsA("Bone") then
				bones[item.Name] = true
			end
		end
		local wanted = { "Pelvis", "Spine_0", "Spine_1", "Neck", "Head_0", "Ear_Left_0", "Ear_Right_0", "Tail_0", "Tail_1", "Tail_2" }
		for _, leg in { "0_Left", "0_Right", "1_Left", "1_Right" } do
			for i = 0, 2 do
				table.insert(wanted, `{leg}_Limb_{i}`)
			end
		end
		for _, name in wanted do
			assert(bones[name], `his bone {name}`)
		end
		expect.equal(#findScripts(roots), 0, "no scripts")
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

	["every synced creature model is used"] = function()
		-- assets/creatures replicates to every player at join: a model no card or town animal uses is download and memory
		-- for nothing (the bought packs once held 45 such models with 93% of the meshes). Unused packs live in
		-- assets/creature-packs-unused, not synced.
		local party = require("../src/shared/Config/Party")
		local ambient = require("../src/shared/Config/Ambient")
		local used: { [string]: boolean } = {}
		for _, entry in party.CREATURE_MODELS do
			used[(entry.pack or "") .. "/" .. entry.model] = true
		end
		for _, critter in ambient.CRITTERS do
			used["CutePets/" .. critter.model] = true
		end
		local bad = {}
		for _, file in fs.readDir("assets/creatures") do
			if string.sub(file, -5) == ".rbxm" then
				for _, root in roblox.deserializeModel(fs.readFile(`assets/creatures/{file}`)) do
					local pack = if root:IsA("Folder") then root.Name else ""
					local models = if root:IsA("Folder") then root:GetChildren() else { root }
					for _, model in models do
						if model:IsA("Model") and not used[pack .. "/" .. model.Name] then
							table.insert(bad, `{file}: {model.Name}`)
						end
					end
				end
			end
		end
		table.sort(bad)
		assert(#bad == 0, `unused creature models synced to every player:\n    {table.concat(bad, "\n    ")}`)
	end,

	["every town animal's colour variant is in its Cute Pets model"] = function()
		local ambient = require("../src/shared/Config/Ambient")
		local bad = {}
		for _, critter in ambient.CRITTERS do
			if critter.variant then
				local model = findPackModel("CutePets", critter.model)
				local variants = model and model:FindFirstChild("Variants")
				if not (variants and variants:FindFirstChild(critter.variant)) then
					table.insert(bad, `{critter.model}: no variant {critter.variant}`)
				end
			end
		end
		assert(#bad == 0, `town animals (Config/Ambient CRITTERS):\n    {table.concat(bad, "\n    ")}`)
	end,

	-- The valley scenery round (spec 2026-11-04-valley-scenery-design): each of the fifteen saved with the parts
	-- SceneryService dresses (Frame; Glow on the glowing ones), and every model the valley places has a saved file
	["the valley's props are saved with their named parts"] = function()
		local glowing = { "Frame", "Glow" }
		local plain = { "Frame" }
		local wanted = {
			GlowMushroomTall = glowing, GlowMushroomCluster = glowing, GlowMushroomSmall = glowing, GlowTuft = glowing,
			GlowFlowers = glowing, MossRockA = plain, MossRockB = plain, RuinArch = plain, RuinPillar = plain,
			RuinPillarBroken = plain, RuinPillarFallen = plain, RuinWall = plain, Toadstool = { "Frame" },
			EmberTree = glowing, DragonSkeleton = glowing,
			GiantTreeA = plain, GiantTreeB = plain, GiantTreeC = plain, MountainSnow = plain, MountainDark = plain, -- round 2
		}
		local bad = {}
		for name, parts in wanted do
			local path = `assets/props/{name}.rbxm`
			if not fs.isFile(path) then
				table.insert(bad, `{path}: not saved`)
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
		end
		local valley = require("../src/shared/Config/WildValley")
		local WildValley = require("../src/shared/Util/WildValley")
		local placed = WildValley.scenery(valley)
		for _, list in { valley.BACKDROP, valley.MOUNTAINS, WildValley.passProps(valley) } do -- round 2, the passes' banks
			for _, spot in list do
				table.insert(placed, spot)
			end
		end
		for _, spot in placed do
			if spot.model and not fs.isFile(`assets/props/{spot.model}.rbxm`) then
				table.insert(bad, `{spot.model} at {spot.x}, {spot.z}: no assets/props/{spot.model}.rbxm`)
			end
		end
		assert(#bad == 0, `valley scenery props (docs/props.md):\n    {table.concat(bad, "\n    ")}`)
	end,

	["the caldera's props carry the parts the game dresses"] = function()
		-- optional until saved (the canyon builds without them); once saved, every part SceneryService looks for
		local wanted = { Volcano = { "Body", "Lava", "Fx_Smoke" }, ObsidianShards = { "Frame", "Lava" }, CharredTree = { "Frame" } }
		local bad = {}
		for name, parts in wanted do
			local path = `assets/props/{name}.rbxm`
			if not fs.isFile(path) then
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
		end
		assert(#bad == 0, `caldera props (docs/props.md):\n    {table.concat(bad, "\n    ")}`)
	end,

	["the volcano's lava streaks face the canyon"] = function()
		-- the saved model's lava (streaks and crater) leans to one side of its crater axis: turned by VOLCANO.yaw (placeModel
		-- turns about y), that side must face the canyon and the town (east), or players see the streaks edge-on
		local scenery = require("../src/shared/Config/Scenery")
		local town = require("../src/shared/Config/Town")
		local path = "assets/props/Volcano.rbxm"
		if not fs.isFile(path) then
			return
		end
		local model = roblox.deserializeModel(fs.readFile(path))[1]
		local lava, axis = model:FindFirstChild("Lava"), model:FindFirstChild("Fx_Smoke")
		local dx = lava.CFrame.Position.X - axis.CFrame.Position.X
		local dz = lava.CFrame.Position.Z - axis.CFrame.Position.Z
		local yaw = math.rad(scenery.VOLCANO.yaw)
		local wx, wz = dx * math.cos(yaw) + dz * math.sin(yaw), -dx * math.sin(yaw) + dz * math.cos(yaw)
		local arena = town.PORTAL_AREAS[3].trail[#town.PORTAL_AREAS[3].trail]
		local tx, tz = arena.x - scenery.VOLCANO.x, arena.z - scenery.VOLCANO.z
		local facing = (wx * tx + wz * tz) / (math.sqrt(wx * wx + wz * wz) * math.sqrt(tx * tx + tz * tz))
		assert(facing > 0.8, `the volcano's lava faces {facing} of the way toward the canyon (VOLCANO.yaw {scenery.VOLCANO.yaw})`)
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
