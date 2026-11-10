--!strict
-- Splits an imported prop pack (one FBX of many props, e.g. tools/blender/build_frontier_props.py's FrontierProps) into
-- one assets/props/<Name>.rbxm per prop, as the game expects (ScenePieces.placeModel finds PropModels.<Name>).
-- The pack's parts are named <Name>__<Part> (Frame, Glow); wherever the importer put them, each prop's parts are
-- gathered by that prefix into a Model named <Name>, renamed to <Part>, the Frame made its PrimaryPart and the model's
-- pivot set to the bottom centre of its parts (the game stands a prop by its pivot), level and unturned.
-- Usage: lune run tools/props/split_pack <pack.rbxm> [out folder, default assets/props]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local FILE = process.args[1]
local OUT = process.args[2] or "assets/props"
assert(FILE, "usage: lune run tools/props/split_pack <pack.rbxm> [out folder]")

local roots = roblox.deserializeModel(fs.readFile(FILE))
local groups: { [string]: { any } } = {}
local order: { string } = {}
for _, root in roots do
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") then
			local name, piece = string.match(part.Name, "^(.-)__(.+)$")
			if name and piece then
				if not groups[name] then
					groups[name] = {}
					table.insert(order, name)
				end
				table.insert(groups[name], part)
			end
		end
	end
end
assert(#order > 0, `{FILE} has no parts named <Name>__<Part>`)

-- The world-space box round a part (its CFrame turned box)
local function corners(part: any): { any }
	local half = part.Size / 2
	local list = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(list, part.CFrame * Vector3.new(half.X * x, half.Y * y, half.Z * z))
			end
		end
	end
	return list
end

for _, name in order do
	local model = roblox.Instance.new("Model")
	model.Name = name
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxZ = -math.huge, -math.huge
	local frame = nil
	for _, part in groups[name] do
		part.Name = string.match(part.Name, "__(.+)$") :: string
		part.Parent = model
		for _, corner in corners(part) do
			minX, minY, minZ = math.min(minX, corner.X), math.min(minY, corner.Y), math.min(minZ, corner.Z)
			maxX, maxZ = math.max(maxX, corner.X), math.max(maxZ, corner.Z)
		end
		if part.Name == "Frame" then
			frame = part
		end
	end
	frame = frame or groups[name][1]
	local bottom = CFrame.new((minX + maxX) / 2, minY, (minZ + maxZ) / 2)
	for _, part in groups[name] do
		part.PivotOffset = CFrame.new() -- the importer can turn it; set below for the primary part only
	end
	frame.PivotOffset = frame.CFrame:Inverse() * bottom
	model.PrimaryPart = frame
	local path = `{OUT}/{name}.rbxm`
	fs.writeFile(path, roblox.serializeModel({ model }))
	print(`{path}: {#groups[name]} part(s)`)
end
