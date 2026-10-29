--!strict
-- The Glass Showcase and Collector Case look (UI project 3 spec section 3), code-built: a dark base with the bed on
-- top (the cards' feet sit at CaseLayout.UPRIGHT bedHeight), chrome corner posts and top rails, tall glass sides and
-- lid, and a light strip along the top front edge. Parts are named Support, Carpet, Frame, Glass and Strip so Shelves
-- propColors can recolour them. The cards and their light beams come from the server's card parts and
-- CaseSpinController. Bottom centre at the origin, front facing -Z.
local Config = (script.Parent :: Instance).Parent:WaitForChild("Config")
local Town = require(Config:WaitForChild("Town"))
local CaseLayout = require(Config:WaitForChild("CaseLayout"))

local CaseLook = {}

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function addPart(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

function CaseLook.draw(model: Model, size: Vector3)
	local look = Town.CASE_LOOK
	local w, h, d = size.X, size.Y, size.Z
	local post = look.POST
	local bed = CaseLayout.UPRIGHT.bedHeight * h
	addPart(model, "Support", Vector3.new(w, bed - look.BED, d), CFrame.new(0, (bed - look.BED) / 2, 0), rgb(look.SUPPORT), Enum.Material.SmoothPlastic)
	addPart(model, "Carpet", Vector3.new(w - 2 * post, look.BED, d - 2 * post), CFrame.new(0, bed - look.BED / 2, 0), rgb(look.CARPET), Enum.Material.Fabric)
	-- corner posts and the rails round the top
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			addPart(model, "Frame", Vector3.new(post, h - bed, post), CFrame.new(x * (w - post) / 2, bed + (h - bed) / 2, z * (d - post) / 2), rgb(look.FRAME), Enum.Material.Metal)
		end
	end
	for _, z in { -1, 1 } do
		addPart(model, "Frame", Vector3.new(w, post, post), CFrame.new(0, h - post / 2, z * (d - post) / 2), rgb(look.FRAME), Enum.Material.Metal)
	end
	for _, x in { -1, 1 } do
		addPart(model, "Frame", Vector3.new(post, post, d), CFrame.new(x * (w - post) / 2, h - post / 2, 0), rgb(look.FRAME), Enum.Material.Metal)
	end
	-- the glass: front, back, ends and lid. Plain see-through plastic, not Glass material: Roblox doesn't draw
	-- see-through things (the card faces, beams, sparkles) behind Glass
	local glassHeight = h - bed - post
	local glassY = bed + glassHeight / 2
	local panes = {
		{ Vector3.new(w - 2 * post, glassHeight, 0.05), CFrame.new(0, glassY, -(d - post) / 2) },
		{ Vector3.new(w - 2 * post, glassHeight, 0.05), CFrame.new(0, glassY, (d - post) / 2) },
		{ Vector3.new(0.05, glassHeight, d - 2 * post), CFrame.new(-(w - post) / 2, glassY, 0) },
		{ Vector3.new(0.05, glassHeight, d - 2 * post), CFrame.new((w - post) / 2, glassY, 0) },
		{ Vector3.new(w - 2 * post, 0.05, d - 2 * post), CFrame.new(0, h - post / 2, 0) },
	}
	for _, pane in panes do
		local glass = addPart(model, "Glass", pane[1], pane[2], rgb(look.GLASS), Enum.Material.SmoothPlastic)
		glass.Transparency = look.GLASS_TRANSPARENCY
		glass.Reflectance = look.GLASS_REFLECTANCE
	end
	-- the light strip along the top front edge, just under the rail
	addPart(model, "Strip", Vector3.new(w - 2 * post, look.STRIP_HEIGHT, 0.06), CFrame.new(0, h - post - look.STRIP_HEIGHT / 2, -d / 2 + 0.02), rgb(look.STRIP), Enum.Material.Neon)
end

return CaseLook
