--!strict
-- Keeps the hand-placed town decor (assets/town/TownDecor.rbxm) out of the shops (spec 2026-11-23-shop-rooms-design:
-- the shops grew to 50 x 60 and reach into the old tree belts and gap groups). The rule lives in tools/town/decor_fit
-- (tests/TownDecorFit checks the file the same way).
--   lune run tools/town/fit_town_decor           lists the pieces in a shop's way (exit 1 when there are any)
--   lune run tools/town/fit_town_decor apply     fixes them and writes the file back (Rojo syncs it): the row ends'
--     corner pieces and signposts move out of the way the short way (TownLayout.clearOf, half a stud of air past the
--     wall; one that can't clear goes); the tree belts behind the shops and the gap groups go (the spec re-dresses the
--     gaps from the owner's pick of a mockup)
--   lune run tools/town/fit_town_decor place <before.rbxm>     dresses the four gaps between shops as the Garden alley
--     (owner 2026-11-24 picked A from the "Gaps" mockup board): flower beds along both walls, a bench by the street,
--     one small tree and two bushes at the back, cloned from the old gap groups in <before.rbxm>, a copy of the file
--     from before the shop rooms (`git show 18010e1:assets/town/TownDecor.rbxm > <before.rbxm>`); each gap's other
--     pieces but its planters go first
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local TownLayout = require("../../src/shared/Util/TownLayout")
local Town = require("../../src/shared/Config/Town")
local DecorFit = require("./decor_fit")

local PATH = "assets/town/TownDecor.rbxm"
-- Config/Plots numbers (Lune can't load it): 6 plots, 3 a row, 50 x 60, 14 apart, the street 96 wide
local WORLD = { plotCount = 6, perRow = 3, plotWidth = 50, plotDepth = 60, gap = 14, streetWidth = 96 }

local AIR = 0.5 -- studs past the wall a moved piece stands

-- The Garden alley's pieces in alley studs: `ax` across the gap from its -x wall's face (0..12), `az` back from the shop
-- fronts (0..60), `yaw` degrees turned about the piece's middle (90: a flower row or the bench along the wall, the bench
-- facing into the alley), `scale` its size (1 when left out)
local ALLEY: { { source: string, ax: number, az: number, yaw: number, scale: number? } } = {
	{ source = "GapEN/Bench", ax = 1.6, az = 7, yaw = 90 },
	{ source = "GapEN/FlowerPink", ax = 2.3, az = 15.5, yaw = 90 }, -- the deepest row (4.1): further off the wall
	{ source = "GapEN/FlowerYellow", ax = 1.6, az = 23.5, yaw = 90 },
	{ source = "GapEN/FlowerWhite", ax = 10.4, az = 15.5, yaw = 90 },
	{ source = "GapES/FlowerBlue", ax = 10.4, az = 23.5, yaw = 90 },
	-- the small tree, shrunk to fit: Studio boxes it 12.6 wide and the game takes away a tree that can't keep
	-- Town.LAYOUT.TREE_CLEARANCE from both walls of a 14-stud gap (TownService.clearTrees)
	{ source = "GapWN/TreeC", ax = 6, az = 44, yaw = 0, scale = 0.75 },
	{ source = "GapEN/BushB", ax = 3, az = 54, yaw = 0 },
	{ source = "GapEN/BushB", ax = 9, az = 54, yaw = 0 },
}
-- The four gaps: their TownDecor group, their middle across (x) and which way is back from the fronts (+1 north)
local GAPS = {
	{ group = "GapWN", x = -32, side = 1 },
	{ group = "GapEN", x = 32, side = 1 },
	{ group = "GapWS", x = -32, side = -1 },
	{ group = "GapES", x = 32, side = -1 },
}
local FRONT, HALF_GAP = 48, 6 -- the shop fronts at z +-48; 12 studs of open ground between the walls

local mode = process.args[1] or "check"
local roots = roblox.deserializeModel(fs.readFile(PATH))
local rects = TownLayout.plotRects(WORLD :: any)
local hits = DecorFit.inTheWay(roots[1], rects, Town.WALL_THICKNESS, DecorFit.ROOFLINE)

-- The row ends' pieces and the signposts stand beside a shop, not where one now is: they move
local function movable(group: string): boolean
	return group == "Signposts" or string.sub(group, 1, 6) == "Corner"
end

local function shift(piece: any, dx: number, dz: number)
	local offset = roblox.Vector3.new(dx, 0, dz)
	local parts = piece:GetDescendants()
	table.insert(parts, piece)
	for _, part in parts do
		if part:IsA("BasePart") then
			part.CFrame = part.CFrame + offset
		end
	end
	if piece:IsA("Model") then
		pcall(function()
			piece.WorldPivot = piece.WorldPivot + offset
		end)
	end
end

if mode == "check" then
	for _, hit in hits do
		print(`in a shop: {hit.group}/{hit.piece}`)
	end
	print(`{#hits} pieces in a shop's way`)
	process.exit(if #hits > 0 then 1 else 0)
elseif mode == "apply" then
	local moved, removed = 0, 0
	for _, hit in hits do
		local dx, dz, stuck = 0, 0, true
		if movable(hit.group) then
			dx, dz, stuck = TownLayout.clearOf(DecorFit.box(hit.instance), rects, Town.WALL_THICKNESS + AIR)
		end
		if stuck then
			hit.instance.Parent = nil
			removed += 1
		else
			shift(hit.instance, dx, dz)
			moved += 1
			print(string.format("moved %s/%s by %.1f, %.1f", hit.group, hit.piece, dx, dz))
		end
	end
	fs.writeFile(PATH, roblox.serializeModel(roots))
	print(`removed {removed} pieces, moved {moved}; wrote {PATH}`)
elseif mode == "place" then
	local sourcePath = process.args[2]
	if not sourcePath or not fs.isFile(sourcePath) then
		print("Usage: lune run tools/town/fit_town_decor place <before.rbxm>")
		process.exit(1)
	end
	local source = roblox.deserializeModel(fs.readFile(sourcePath :: string))[1]
	local decor = roots[1]
	local placed = 0
	for _, gap in GAPS do
		local group = decor:FindFirstChild(gap.group)
		if not group then
			print(`no group {gap.group}`)
			process.exit(1)
		end
		for _, piece in group:GetChildren() do
			if piece.Name ~= "Planter" then
				piece.Parent = nil
			end
		end
		-- and any other group's piece standing in the alley (bits of the old tree belts behind the shops)
		local nearZ, farZ = gap.side * FRONT, gap.side * 112
		local minZ, maxZ = math.min(nearZ, farZ), math.max(nearZ, farZ)
		for _, other in decor:GetChildren() do
			if other ~= group then
				for _, piece in other:GetChildren() do
					local box = DecorFit.box(piece)
					local x, z = (box.minX + box.maxX) / 2, (box.minZ + box.maxZ) / 2
					if math.abs(x - gap.x) < HALF_GAP and z > minZ and z < maxZ then
						print(`cleared {other.Name}/{piece.Name} out of {gap.group}`)
						piece.Parent = nil
					end
				end
			end
		end
		for _, spot in ALLEY do
			local groupName, pieceName = string.match(spot.source, "^(%w+)/(%w+)$")
			local from = source:FindFirstChild(groupName :: string)
			local original = if from then from:FindFirstChild(pieceName :: string) else nil
			if not original then
				print(`no source piece {spot.source}`)
				process.exit(1)
			end
			local piece = original:Clone()
			local box = DecorFit.box(piece)
			local cx, cz = (box.minX + box.maxX) / 2, (box.minZ + box.maxZ) / 2
			local tx, tz = gap.x - HALF_GAP + spot.ax, gap.side * (FRONT + spot.az)
			local turn = roblox.CFrame.Angles(0, math.rad(spot.yaw), 0)
			local scale = spot.scale or 1
			local parts = piece:GetDescendants()
			table.insert(parts, piece)
			for _, part in parts do
				if part:IsA("BasePart") then
					-- its place from the piece's middle on the ground, scaled and turned, at the spot; its own turn kept
					local offset = part.CFrame.Position - roblox.Vector3.new(cx, 0, cz)
					local spin = part.CFrame - part.CFrame.Position
					local at = roblox.Vector3.new(tx, 0, tz) + turn:VectorToWorldSpace(offset * scale)
					part.CFrame = roblox.CFrame.new(at.X, at.Y, at.Z) * turn * spin
					part.Size = part.Size * scale
				end
			end
			piece.Parent = group
			placed += 1
		end
	end
	fs.writeFile(PATH, roblox.serializeModel(roots))
	print(`placed {placed} pieces in {#GAPS} gaps; wrote {PATH}`)
else
	print("Usage: lune run tools/town/fit_town_decor [apply]")
	process.exit(1)
end
