--!strict
-- The shop windows' models (spec docs/superpowers/specs/2026-11-14-shop-windows-design.md; Config/Windows): code-built,
-- filling a rectangular hole in the wall (PlotService.SetWindows), the server's real windows and the owner's placing
-- ghost alike (WindowController). Round and arched tops are filled with the frame's colour round the curve (stepped
-- pieces under a ring that hides the steps), so every hole stays a rectangle. The origin is the hole's middle on the
-- wall's centre plane; -Z faces into the shop. A Root part (invisible, the hole's size) is the PrimaryPart.
local WindowLooks = {}

local DEPTH = 1.3 -- the frame's depth: through the wall (1) and the inner layer (0.1), a little proud each side
local FRONT = -0.05 -- the frame's middle along Z (the inner layer makes the wall deeper on the room side)
local GLASS = Color3.fromRGB(210, 232, 255)
local WHITE = Color3.fromRGB(246, 246, 250)
local WOOD = Color3.fromRGB(150, 104, 70)
local BRASS = Color3.fromRGB(206, 166, 82)
local LEAD = Color3.fromRGB(58, 60, 70)
local STAINED = {
	Color3.fromRGB(150, 90, 230),
	Color3.fromRGB(80, 140, 255),
	Color3.fromRGB(60, 200, 200),
	Color3.fromRGB(255, 200, 60),
}

local function add(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function glass(model: Model, w: number, h: number, at: CFrame?)
	local pane = add(model, "Glass", Vector3.new(w, h, 0.05), (at or CFrame.new()) * CFrame.new(0, 0, FRONT), GLASS)
	pane.Transparency = 0.82
	pane.Reflectance = 0.2
	pane.CastShadow = false
end

-- Four boards round the hole, `t` thick
local function border(model: Model, w: number, h: number, t: number, color: Color3, material: Enum.Material?)
	for _, y in { -1, 1 } do
		add(model, "Frame", Vector3.new(w, t, DEPTH), CFrame.new(0, y * (h / 2 - t / 2), FRONT), color, material)
	end
	for _, x in { -1, 1 } do
		add(model, "Frame", Vector3.new(t, h - 2 * t, DEPTH), CFrame.new(x * (w / 2 - t / 2), 0, FRONT), color, material)
	end
end

-- A thin bar across the glass, from `a` to `b` (in the hole's plane)
local function bar(model: Model, a: Vector2, b: Vector2, thick: number, color: Color3, depth: number?, material: Enum.Material?)
	local middle = (a + b) / 2
	local length = (b - a).Magnitude
	local angle = math.atan2(b.Y - a.Y, b.X - a.X)
	add(model, "Frame", Vector3.new(length + thick, thick, depth or 0.3), CFrame.new(middle.X, middle.Y, FRONT) * CFrame.Angles(0, 0, angle), color, material)
end

-- The part of a box corner outside a circle (centre `c`, radius `r`), in stepped slabs out to `edge` (x, y half sizes
-- from the centre), on the quadrants `quads` ({ sx, sy } signs)
local function fillCorners(model: Model, c: Vector2, r: number, edge: Vector2, quads: { { number } }, color: Color3, material: Enum.Material?)
	local steps = 8
	for _, quad in quads do
		local sx, sy = quad[1], quad[2]
		for i = 0, steps - 1 do
			local y0, y1 = r * i / steps, r * (i + 1) / steps
			local mid = (y0 + y1) / 2
			local inner = math.sqrt(math.max(0, r * r - mid * mid))
			local width = edge.X - inner
			if width > 0.01 then
				add(model, "Frame", Vector3.new(width, y1 - y0 + 0.01, DEPTH * 0.9), CFrame.new(c.X + sx * (inner + width / 2), c.Y + sy * (y0 + y1) / 2, FRONT), color, material)
			end
		end
		if edge.Y > r then
			add(model, "Frame", Vector3.new(edge.X, edge.Y - r, DEPTH * 0.9), CFrame.new(c.X + sx * edge.X / 2, c.Y + sy * (r + (edge.Y - r) / 2), FRONT), color, material)
		end
	end
end

-- A ring of `count` bars round a circle (centre `c`, radius `r`) from `from` to `to` degrees
local function ring(model: Model, c: Vector2, r: number, from: number, to: number, count: number, thick: number, color: Color3, material: Enum.Material?)
	for k = 0, count - 1 do
		local a0 = math.rad(from + (to - from) * k / count)
		local a1 = math.rad(from + (to - from) * (k + 1) / count)
		bar(model, c + Vector2.new(math.cos(a0), math.sin(a0)) * r, c + Vector2.new(math.cos(a1), math.sin(a1)) * r, thick, color, DEPTH, material)
	end
end

local function sill(model: Model, w: number, h: number, color: Color3)
	add(model, "Sill", Vector3.new(w + 0.5, 0.16, 0.55), CFrame.new(0, -h / 2 + 0.08, -0.6 - 0.25), color)
end

local STYLES: { [string]: (model: Model, w: number, h: number) -> () } = {
	Square = function(model, w, h)
		glass(model, w - 0.1, h - 0.1)
		border(model, w, h, 0.3, WHITE)
		bar(model, Vector2.new(0, -h / 2 + 0.3), Vector2.new(0, h / 2 - 0.3), 0.14, WHITE)
		bar(model, Vector2.new(-w / 2 + 0.3, 0), Vector2.new(w / 2 - 0.3, 0), 0.14, WHITE)
		sill(model, w, h, WHITE)
	end,
	Wide = function(model, w, h)
		glass(model, w - 0.1, h - 0.1)
		border(model, w, h, 0.3, WHITE)
		for _, x in { -w / 6, w / 6 } do
			bar(model, Vector2.new(x, -h / 2 + 0.3), Vector2.new(x, h / 2 - 0.3), 0.14, WHITE)
		end
		sill(model, w, h, WHITE)
		-- a flower box on the sill, inside
		local boxY, boxZ = -h / 2 + 0.16 + 0.22, -0.6 - 0.3
		add(model, "FlowerBox", Vector3.new(w * 0.8, 0.44, 0.5), CFrame.new(0, boxY, boxZ), Color3.fromRGB(176, 116, 74), Enum.Material.Wood)
		local colors = { Color3.fromRGB(255, 140, 180), Color3.fromRGB(255, 214, 90), Color3.fromRGB(190, 140, 255) }
		for k = 0, 8 do
			local x = -w * 0.36 + k * w * 0.09
			local leaf = add(model, "Leaf", Vector3.new(0.42, 0.34, 0.38), CFrame.new(x, boxY + 0.3, boxZ), Color3.fromRGB(96, 178, 96))
			leaf.Shape = Enum.PartType.Ball
			if k % 2 == 0 then
				local flower = add(model, "Flower", Vector3.new(0.24, 0.24, 0.24), CFrame.new(x + 0.1, boxY + 0.5, boxZ - 0.08), colors[(k // 2) % #colors + 1], Enum.Material.Neon)
				flower.Shape = Enum.PartType.Ball
			end
		end
	end,
	Arched = function(model, w, h)
		local t = 0.35
		local r = w / 2 - t
		local centre = Vector2.new(0, h / 2 - t - r)
		glass(model, w - 0.1, h - 0.1)
		border(model, w, h, t, WOOD, Enum.Material.Wood)
		fillCorners(model, centre, r, Vector2.new(r, r), { { -1, 1 }, { 1, 1 } }, WOOD, Enum.Material.Wood)
		ring(model, centre, r - 0.1, 0, 180, 12, 0.3, WOOD, Enum.Material.Wood)
		bar(model, Vector2.new(0, -h / 2 + t), Vector2.new(0, centre.Y + r - 0.2), 0.14, WOOD, nil, Enum.Material.Wood)
		bar(model, Vector2.new(-r, centre.Y), Vector2.new(r, centre.Y), 0.14, WOOD, nil, Enum.Material.Wood)
		sill(model, w, h, WOOD)
	end,
	Porthole = function(model, w, h)
		local t = 0.3
		local r = math.min(w, h) / 2 - t
		glass(model, w - 0.1, h - 0.1)
		border(model, w, h, t, BRASS, Enum.Material.Metal)
		fillCorners(model, Vector2.zero, r, Vector2.new(r, r), { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }, BRASS, Enum.Material.Metal)
		ring(model, Vector2.zero, r - 0.12, 0, 360, 20, 0.34, BRASS, Enum.Material.Metal)
		for k = 0, 7 do
			local a = math.rad(22.5 + k * 45)
			local rivet = add(model, "Rivet", Vector3.new(0.14, 0.14, 0.14), CFrame.new(math.cos(a) * (r + 0.05), math.sin(a) * (r + 0.05), -0.72), Color3.fromRGB(150, 116, 52), Enum.Material.Metal)
			rivet.Shape = Enum.PartType.Ball
		end
	end,
	Stained = function(model, w, h)
		local t = 0.25
		local cols, rows = 3, 5
		local pw, ph = (w - 2 * t) / cols, (h - 2 * t) / rows
		for row = 0, rows - 1 do
			for col = 0, cols - 1 do
				local color = STAINED[(row + col * 2) % #STAINED + 1]
				local pane = add(model, "Glass", Vector3.new(pw, ph, 0.05), CFrame.new(-w / 2 + t + pw * (col + 0.5), -h / 2 + t + ph * (row + 0.5), FRONT), color)
				pane.Transparency = 0.3
				pane.CastShadow = false
			end
		end
		border(model, w, h, t, LEAD)
		for col = 1, cols - 1 do
			local x = -w / 2 + t + pw * col
			bar(model, Vector2.new(x, -h / 2 + t), Vector2.new(x, h / 2 - t), 0.08, LEAD, 0.12)
		end
		for row = 1, rows - 1 do
			local y = -h / 2 + t + ph * row
			bar(model, Vector2.new(-w / 2 + t, y), Vector2.new(w / 2 - t, y), 0.08, LEAD, 0.12)
		end
		sill(model, w, h, Color3.fromRGB(236, 230, 220))
	end,
}

-- Where a window's model goes in a shop (the server's windows, the owner's ghost): its hole's middle on its wall's
-- centre plane, facing into the shop. `floor` is the shop's floor part (its CFrame is the plot's), `cfg` Config/Windows,
-- `width` / `depth` the floor's (Config/Plots), `thick` the walls' (Config/Town WALL_THICKNESS).
function WindowLooks.cframe(floor: BasePart, window: { style: string, side: string, at: number }, cfg: any, width: number, depth: number, thick: number): CFrame
	local style = cfg.STYLES[window.style]
	local y = floor.Size.Y / 2 + cfg.SILL + style.height / 2
	local middle = thick / 2
	local position, inward
	if window.side == "back" then
		position, inward = Vector3.new(window.at, y, depth / 2 + middle), Vector3.new(0, 0, -1)
	elseif window.side == "left" then
		position, inward = Vector3.new(-(width / 2 + middle), y, window.at), Vector3.new(1, 0, 0)
	else
		position, inward = Vector3.new(width / 2 + middle, y, window.at), Vector3.new(-1, 0, 0)
	end
	return floor.CFrame * CFrame.lookAt(position, position + inward)
end

-- A window of `style` for a `w` x `h` hole (Config/Windows sizes), its origin the hole's middle on the wall's centre
-- plane, -Z into the shop
function WindowLooks.build(style: string, w: number, h: number): Model
	local model = Instance.new("Model")
	model.Name = "Window"
	local root = add(model, "Root", Vector3.new(w, h, DEPTH), CFrame.new(0, 0, FRONT), WHITE)
	root.Transparency = 1
	model.PrimaryPart = root
	local draw = STYLES[style] or STYLES.Square
	draw(model, w, h)
	return model
end

return WindowLooks
