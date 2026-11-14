--!strict
-- The Glass Showcase and Collector Case look, code-built: the museum vitrine (owner 2026-11-14, concept B "make it look
-- exactly like that. with the glows and everything"; Config/Town CASE_LOOK): a white pedestal with a warm glow strip
-- round its foot over a white lip and a pool of light on the floor, a silver plate on top (its top at
-- CaseLayout.UPRIGHT bedHeight, where the cards' feet are), a brass plaque on the front, and clear glass with bright
-- edges and two shine streaks. Parts named Support, Carpet, Frame, Glass and Strip so Shelves propColors can recolour
-- them. The cards, their pads, beams, spiral lights and sparkles come from the server's card parts and
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
	local bed = CaseLayout.UPRIGHT.bedHeight * h
	local white = rgb(look.SUPPORT)
	local smooth = Enum.Material.SmoothPlastic
	-- the pedestal: a white lip, the glow strip set into it, the body, the plate on top
	local stripTop = look.LIP + look.STRIP_HEIGHT
	addPart(model, "Support", Vector3.new(w - 0.04, look.LIP, d - 0.04), CFrame.new(0, look.LIP / 2, 0), white, smooth)
	local inset = look.STRIP_INSET
	addPart(model, "Strip", Vector3.new(w - 2 * inset, look.STRIP_HEIGHT, d - 2 * inset), CFrame.new(0, look.LIP + look.STRIP_HEIGHT / 2, 0), rgb(look.STRIP), Enum.Material.Neon)
	local bodyTop = bed - look.PLATE
	addPart(model, "Support", Vector3.new(w, bodyTop - stripTop, d), CFrame.new(0, (stripTop + bodyTop) / 2, 0), white, smooth)
	local plateInset = look.PLATE_INSET
	local plate = addPart(model, "Carpet", Vector3.new(w - 2 * plateInset, look.PLATE, d - 2 * plateInset), CFrame.new(0, bodyTop + look.PLATE / 2, 0), rgb(look.CARPET), smooth)
	plate.Reflectance = 0.1
	-- the brass plaque on the pedestal's front, in a darker rim
	local plaqueY = (stripTop + bodyTop) / 2
	local pw, ph = look.PLAQUE_SIZE[1], look.PLAQUE_SIZE[2]
	addPart(model, "PlaqueRim", Vector3.new(pw + 0.08, ph + 0.08, 0.03), CFrame.new(0, plaqueY, -d / 2 - 0.012), rgb(look.PLAQUE_EDGE), Enum.Material.Metal)
	addPart(model, "Plaque", Vector3.new(pw, ph, 0.03), CFrame.new(0, plaqueY, -d / 2 - 0.025), rgb(look.PLAQUE), Enum.Material.Metal)
	-- the pool of light on the floor round the foot: a glow picture on an invisible part's top
	local glow = look.FLOOR_GLOW
	local pool = addPart(model, "FloorGlow", Vector3.new(w + 2 * glow.reach, 0.02, d + 2 * glow.reach), CFrame.new(0, 0.012, 0), white, smooth)
	pool.Transparency = 1
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Top
	surface.LightInfluence = 0
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = glow.pixelsPerStud
	surface.Parent = pool
	local light = Instance.new("ImageLabel")
	light.BackgroundTransparency = 1
	light.Size = UDim2.fromScale(1, 1)
	light.Image = glow.image
	light.ImageColor3 = rgb(look.STRIP)
	light.ImageTransparency = glow.transparency
	light.Parent = surface
	-- the glass from the plate to the top: clear panes inside bright edges. Plain see-through plastic, not Glass
	-- material: Roblox doesn't draw see-through things (the card faces, beams, sparkles) behind Glass
	local edge = look.EDGE
	local glassHeight = h - bed
	local glassY = bed + glassHeight / 2
	local panes = {
		{ Vector3.new(w - 2 * edge, glassHeight - edge, 0.04), CFrame.new(0, glassY - edge / 2, -(d - edge) / 2) },
		{ Vector3.new(w - 2 * edge, glassHeight - edge, 0.04), CFrame.new(0, glassY - edge / 2, (d - edge) / 2) },
		{ Vector3.new(0.04, glassHeight - edge, d - 2 * edge), CFrame.new(-(w - edge) / 2, glassY - edge / 2, 0) },
		{ Vector3.new(0.04, glassHeight - edge, d - 2 * edge), CFrame.new((w - edge) / 2, glassY - edge / 2, 0) },
		{ Vector3.new(w - 2 * edge, 0.04, d - 2 * edge), CFrame.new(0, h - edge / 2, 0) },
	}
	for _, pane in panes do
		local glass = addPart(model, "Glass", pane[1], pane[2], rgb(look.GLASS), smooth)
		glass.Transparency = look.GLASS_TRANSPARENCY
		glass.Reflectance = look.GLASS_REFLECTANCE
	end
	local frame = rgb(look.FRAME)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			addPart(model, "Frame", Vector3.new(edge, glassHeight, edge), CFrame.new(x * (w - edge) / 2, glassY, z * (d - edge) / 2), frame, smooth)
		end
	end
	for _, y in { bed + edge / 2, h - edge / 2 } do
		for _, z in { -1, 1 } do
			addPart(model, "Frame", Vector3.new(w, edge, edge), CFrame.new(0, y, z * (d - edge) / 2), frame, smooth)
		end
		for _, x in { -1, 1 } do
			addPart(model, "Frame", Vector3.new(edge, edge, d), CFrame.new(x * (w - edge) / 2, y, 0), frame, smooth)
		end
	end
	-- two shine streaks slanting across the front glass
	local tilt = CFrame.Angles(0, 0, math.rad(-35))
	local front = -(d - edge) / 2 - 0.03
	for index, width in look.SHINE do
		local length = glassHeight * (if index == 1 then 0.55 else 0.38)
		local streak = addPart(model, "Shine", Vector3.new(width, length, 0.01), CFrame.new(-w * 0.27 + (index - 1) * 0.32, bed + glassHeight * 0.55, front) * tilt, Color3.new(1, 1, 1), smooth)
		streak.Transparency = look.SHINE_TRANSPARENCY
	end
end

return CaseLook
