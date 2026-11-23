--!strict
-- Keeps the hand-placed town decor (assets/town/TownDecor.rbxm) out of the shops (spec 2026-11-23-shop-rooms-design:
-- the shops grew to 50 x 60 and reach into the old tree belts and gap groups). The rule lives in tools/town/decor_fit
-- (tests/TownDecorFit checks the file the same way).
--   lune run tools/town/fit_town_decor           lists the pieces in a shop's way (exit 1 when there are any)
--   lune run tools/town/fit_town_decor apply     fixes them and writes the file back (Rojo syncs it): the row ends'
--     corner pieces and signposts move out of the way the short way (TownLayout.clearOf, half a stud of air past the
--     wall; one that can't clear goes); the tree belts behind the shops and the gap groups go (the spec re-dresses the
--     gaps from the owner's pick of a mockup)
-- The pieces the owner picks to add back into the gaps and row ends come later (plan Task 8: `place`).
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
else
	print("Usage: lune run tools/town/fit_town_decor [apply]")
	process.exit(1)
end
