--!strict
-- The 3D binder's scene (spec 2026-10-29-3d-binder-design.md sections 3 and 6): an open ring binder lying on a
-- wooden desk under painted lamp light, built once on a client-only stage far above the world (Config/BinderDesk
-- STAGE_POSITION) and kept for reuse. The desk, case and pages are drawn with SurfaceGuis that ignore the world's
-- lighting, so the scene looks the same at night and at every graphics quality. Each page carries a canvas with
-- nine pocket slots (BinderFit) that the binder fills with card faces. While shown, a Scriptable camera frames the
-- binder inside a rectangle of the screen, world sound stays at the character and on-top world tags are off.
-- Input is by raycast: pick() says which pocket, page or set tab is under a screen point.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Desk = require(Config:WaitForChild("BinderDesk"))
local Collection = require(Config:WaitForChild("Collection"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local BinderFit = require(Shared:WaitForChild("Util"):WaitForChild("BinderFit"))
local UiLayout = require(Shared:WaitForChild("Util"):WaitForChild("UiLayout"))

local ClientUtil = script.Parent :: Instance
local ListenAtCharacter = require(ClientUtil:WaitForChild("ListenAtCharacter"))
local WorldTags = require(ClientUtil:WaitForChild("WorldTags"))

export type Side = "Left" | "Right"
-- u: where across its page the point is (0 at the page's left edge, 1 at its right)
export type Pick = { kind: "pocket", side: Side, index: number, u: number } | { kind: "page", side: Side, u: number } | { kind: "tab", set: string }
-- A light card (art and rim only) for pages in motion; a page face is up to nine of them by pocket slot
export type Lite = { image: string, rim: Color3, missing: boolean, number: number }
export type Face = { [number]: Lite }

local BOOK = Collection.BOOK
local PAGE = Desk.PAGE_SIZE
local CASE_W = PAGE.X * 2 + Desk.SPINE_GAP + Desk.CASE_MARGIN * 2
local CASE_D = PAGE.Y + Desk.CASE_MARGIN * 2
local CASE_T = Desk.CASE_THICKNESS
local PAGE_T = 0.03
local PAGE_Y = CASE_T / 2 + PAGE_T / 2 + 0.005 -- the pages' centre height above the case's centre
local DESK_SIZE = 120
local DESK_PIXELS_PER_STUD = 6
local CASE_PIXELS_PER_STUD = 80
local REACH = 300 -- studs a pick ray looks
local HOVER_SCALE = 1.05 -- the pocket under the pointer rises a little
local HOVER_EDGE = 5 -- px of light round it (page canvas pixels)
local LIFT_ROOM = 0.45 -- how far toward the camera a picked card flies (share of the way)

local BinderDesk = {}

local folder: Folder? = nil
local centre = CFrame.new(Desk.STAGE_POSITION) -- the book's centre: x toward the right page, -z toward the page tops
local pageParts: { [Side]: Part } = {}
local canvases: { [Side]: Frame } = {}
local slots: { [Side]: { Frame } } = { Left = {}, Right = {} }
local tabParts: { Part } = {}
local pickables: { Instance } = {}
local shown = false
local inspecting = false
local saved: { cameraType: Enum.CameraType, cframe: CFrame, fov: number }? = nil
local lastRect: UiLayout.Rect? = nil
local cameraTween: Tween? = nil
local hovered: Frame? = nil -- the highlighted pocket slot
local lifted: Part? = nil -- a picked card on its way to the card view

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
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
	part.Parent = parent
	return part
end

-- A SurfaceGui on a top face reads along the part's -Z, with its top at -X. Parts that carry one are turned a
-- quarter about Y (and given their size as Vector3(depth, height, width)) so their GUI reads left to right along
-- the binder's x with its top at the far edge (-z)
local QUARTER = CFrame.Angles(0, -math.pi / 2, 0)
local function flatSize(width: number, height: number, depth: number): Vector3
	return Vector3.new(depth, height, width)
end

-- A SurfaceGui on the part's top that ignores the world's light; returns its full-size root frame
local function topCanvas(part: BasePart, pixelsPerStud: number, color: Color3): Frame
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = part
	local root = Instance.new("Frame")
	root.Name = "Canvas"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = color
	root.BorderSizePixel = 0
	root.Parent = gui
	return root
end

-- The desk: wood with plank lines, darkened toward the edges, and a warm painted pool of lamp light over the binder
local function buildDesk(parent: Instance)
	local desk = makePart("Desk", Vector3.new(DESK_SIZE, 1, DESK_SIZE), centre * CFrame.new(0, -0.5 - CASE_T / 2, 0), Desk.DESK_COLOR, Enum.Material.Wood, parent)
	local canvas = topCanvas(desk, DESK_PIXELS_PER_STUD, Desk.DESK_COLOR)
	local planks = math.floor(DESK_SIZE / Desk.DESK_PLANK_WIDTH)
	for index = 1, planks do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.Position = UDim2.fromScale(index / planks, 0)
		line.Size = UDim2.new(0, 2, 1, 0)
		line.BackgroundColor3 = Desk.DESK_PLANK_COLOR
		line.BackgroundTransparency = 0.3
		line.BorderSizePixel = 0
		line.ZIndex = 2
		line.Parent = canvas
	end
	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = Desk.VIGNETTE_TRANSPARENCY
	shade.BorderSizePixel = 0
	shade.ZIndex = 3
	shade.Parent = canvas
	local pool = Instance.new("ImageLabel")
	pool.Name = "LampPool"
	pool.AnchorPoint = Vector2.new(0.5, 0.5)
	pool.Position = UDim2.fromScale(0.5, 0.5)
	pool.Size = UDim2.fromScale(CASE_W * 2.4 / DESK_SIZE, CASE_W * 2.4 / DESK_SIZE)
	pool.BackgroundTransparency = 1
	pool.Image = CardDesign.IMAGES.GLOW
	pool.ImageColor3 = Desk.LAMP_COLOR
	pool.ImageTransparency = Desk.LAMP_TRANSPARENCY
	pool.ZIndex = 4
	pool.Parent = canvas
end

-- The leather case with a stitched border, and the chrome ring rail with three rings down the spine
local function buildCase(parent: Instance)
	local case = makePart("Case", flatSize(CASE_W, CASE_T, CASE_D), centre * QUARTER, BOOK.CASE, Enum.Material.Leather, parent)
	local leather = topCanvas(case, CASE_PIXELS_PER_STUD, BOOK.CASE)
	local grain = Instance.new("UIGradient")
	grain.Rotation = 90
	grain.Color = ColorSequence.new(BOOK.CASE, BOOK.CASE_DARK)
	grain.Parent = leather
	local stitch = Instance.new("Frame")
	stitch.AnchorPoint = Vector2.new(0.5, 0.5)
	stitch.Position = UDim2.fromScale(0.5, 0.5)
	stitch.Size = UDim2.new(1, -Desk.CASE_MARGIN * CASE_PIXELS_PER_STUD * 0.8, 1, -Desk.CASE_MARGIN * CASE_PIXELS_PER_STUD * 0.8)
	stitch.BackgroundTransparency = 1
	stitch.Parent = leather
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = stitch
	local thread = Instance.new("UIStroke")
	thread.Color = BOOK.STITCH
	thread.Thickness = 2
	thread.Transparency = 0.35
	thread.Parent = stitch

	local railHeight = PAGE_Y + PAGE_T / 2 + 0.03
	makePart("Rail", Vector3.new(0.16, 0.06, PAGE.Y * 0.94), centre * CFrame.new(0, railHeight, 0), BOOK.CHROME[2], Enum.Material.Metal, parent)
	-- Each ring a half circle over the rail, out of short cylinders
	local radius = Desk.RING_RADIUS
	local segments = Desk.RING_SEGMENTS
	local chord = 2 * radius * math.sin(math.pi / (2 * segments)) + 0.02
	for _, z in { -PAGE.Y * 0.32, 0, PAGE.Y * 0.32 } do
		for segment = 1, segments do
			local angle = math.pi * (segment - 0.5) / segments
			local mid = centre * CFrame.new(radius * math.cos(angle), railHeight + radius * math.sin(angle), z)
			local piece = makePart("Ring", Vector3.new(chord, 0.07, 0.07), mid * CFrame.Angles(0, 0, angle + math.pi / 2), BOOK.CHROME[1], Enum.Material.Metal, parent)
			piece.Shape = Enum.PartType.Cylinder
			piece.Reflectance = 0.25
		end
	end
end

-- One page lying on the case beside the spine: a canvas with nine pocket slots and a shade along its inner edge
local function buildPage(side: Side, parent: Instance)
	local x = (if side == "Right" then 1 else -1) * (Desk.SPINE_GAP / 2 + PAGE.X / 2)
	local page = makePart(`{side}Page`, flatSize(PAGE.X, PAGE_T, PAGE.Y), centre * CFrame.new(x, PAGE_Y, 0) * QUARTER, BOOK.PAGE_COLOR, Enum.Material.SmoothPlastic, parent)
	page.CanQuery = true
	pageParts[side] = page
	table.insert(pickables, page)
	local canvas = topCanvas(page, Desk.PAGE_PIXELS_PER_STUD, BOOK.PAGE_COLOR)
	canvases[side] = canvas
	local gutter = Instance.new("Frame")
	gutter.Name = "Gutter"
	gutter.AnchorPoint = Vector2.new(if side == "Right" then 0 else 1, 0)
	gutter.Position = UDim2.fromScale(if side == "Right" then 0 else 1, 0)
	gutter.Size = UDim2.fromScale(0.045, 1)
	gutter.BackgroundColor3 = Color3.new(0, 0, 0)
	gutter.BorderSizePixel = 0
	gutter.ZIndex = 40
	gutter.Parent = canvas
	local fade = Instance.new("UIGradient")
	fade.Rotation = if side == "Right" then 0 else 180
	fade.Transparency = NumberSequence.new(0.45, 1)
	fade.Parent = gutter
	for index = 1, Desk.POCKETS.columns * Desk.POCKETS.rows do
		local box = BinderFit.pocketBox(index, Desk.POCKETS)
		local slot = Instance.new("Frame")
		slot.Name = `Slot{index}`
		slot.Position = UDim2.fromScale(box.u0, box.v0)
		slot.Size = UDim2.fromScale(box.u1 - box.u0, box.v1 - box.v0)
		slot.BackgroundTransparency = 1
		slot.ZIndex = 2
		slot.Parent = canvas
		-- The hover look (highlight): a warm edge of light and a small rise, off until the pointer is over it
		local rise = Instance.new("UIScale")
		rise.Parent = slot
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = slot
		local glow = Instance.new("UIStroke")
		glow.Name = "Hover"
		glow.Color = Desk.LAMP_COLOR
		glow.Thickness = HOVER_EDGE
		glow.Enabled = false
		glow.Parent = slot
		slots[side][index] = slot
	end
end

-- Builds the scene once (later calls do nothing). It stays in the world, out of everyone's sight on its stage, so
-- its SurfaceGuis are laid out once: putting them in the world on each opening cost a 60 ms frame.
function BinderDesk.build()
	if folder then
		return
	end
	local root = Instance.new("Folder")
	root.Name = "BinderDesk"
	buildDesk(root)
	buildCase(root)
	buildPage("Left", root)
	buildPage("Right", root)
	root.Parent = workspace
	folder = root
end

-- The width the camera fits: the case plus room for the set tabs on both sides, so the binder stays centred
local function fittedSize(): (number, number)
	local tabs = Desk.TAB.stickOut + Desk.TAB.openExtra
	return CASE_W + 2 * tabs, CASE_D
end

-- The binder's shape on screen (width / height, tabs included, leaning back TILT degrees): the rectangle the
-- binder screen lays out for it
function BinderDesk.aspect(): number
	local w, h = fittedSize()
	return w / (h * math.cos(math.rad(Desk.TILT)))
end

-- The camera that shows the binder inside `rect` (viewport pixels), looking down at it TILT degrees off straight
local function cameraFor(rect: UiLayout.Rect): CFrame
	local camera = workspace.CurrentCamera
	local view = { w = camera.ViewportSize.X, h = camera.ViewportSize.Y }
	local w, h = fittedSize()
	local distance = BinderFit.distance({ w = w, h = h }, { w = rect.w, h = rect.h }, view, Desk.FIELD_OF_VIEW, Desk.TILT)
	local dx, dy = BinderFit.shift(rect, view, distance, Desk.FIELD_OF_VIEW)
	local tilt = math.rad(Desk.TILT)
	local focus = centre.Position
	local back = centre:VectorToWorldSpace(Vector3.new(0, math.cos(tilt), math.sin(tilt)))
	local up = centre:VectorToWorldSpace(Vector3.new(0, math.sin(tilt), -math.cos(tilt)))
	return CFrame.lookAt(focus + back * distance, focus, up) * CFrame.new(-dx, -dy, 0)
end

local function stopTween()
	if cameraTween then
		cameraTween:Cancel()
		cameraTween = nil
	end
end

function BinderDesk.show()
	BinderDesk.build()
	local camera = workspace.CurrentCamera
	if shown or not camera then
		return
	end
	saved = { cameraType = camera.CameraType, cframe = camera.CFrame, fov = camera.FieldOfView }
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Desk.FIELD_OF_VIEW
	if lastRect then
		camera.CFrame = cameraFor(lastRect)
	end
	ListenAtCharacter.hold("Binder")
	WorldTags.hide("Binder")
	shown = true
	inspecting = false
end

-- Lights up the pocket under the pointer (nil: none)
function BinderDesk.highlight(side: Side?, index: number?)
	local slot = if side and index then slots[side][index] else nil
	if slot == hovered then
		return
	end
	for _, frame in { hovered, slot } do
		if frame then
			local on = frame == slot
			local rise = frame:FindFirstChildOfClass("UIScale") :: UIScale
			local glow = frame:FindFirstChild("Hover") :: UIStroke
			rise.Scale = if on then HOVER_SCALE else 1
			glow.Enabled = on
			frame.ZIndex = if on then 3 else 2
		end
	end
	hovered = slot
end

local function dropLift()
	if lifted then
		lifted:Destroy()
		lifted = nil
	end
end

function BinderDesk.hide()
	if not shown then
		return
	end
	dropLift()
	BinderDesk.highlight(nil, nil)
	shown = false
	inspecting = false
	stopTween()
	local camera = workspace.CurrentCamera
	local before = saved
	if camera and before then
		camera.CFrame = before.cframe
		camera.FieldOfView = before.fov
		camera.CameraType = before.cameraType
		-- Roblox doesn't move a Scriptable camera's subject to a respawned character: follow the current one
		local character = Players.LocalPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if before.cameraType == Enum.CameraType.Custom and humanoid then
			camera.CameraSubject = humanoid
		end
	end
	saved = nil
	ListenAtCharacter.release("Binder")
	WorldTags.show("Binder")
end

function BinderDesk.isShown(): boolean
	return shown
end

-- Frames the binder inside `rect` (viewport pixels, Roblox's top bar strip included), at once or tweened
function BinderDesk.frame(rect: UiLayout.Rect, tween: boolean)
	lastRect = rect
	local camera = workspace.CurrentCamera
	if not shown or inspecting or not camera then
		return
	end
	stopTween()
	local target = cameraFor(rect)
	if tween then
		local info = TweenInfo.new(BOOK.SLIDE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		cameraTween = TweenService:Create(camera, info, { CFrame = target })
		;(cameraTween :: Tween):Play()
	else
		camera.CFrame = target
	end
end

function BinderDesk.pages(): (Frame, Frame)
	BinderDesk.build()
	return canvases.Left, canvases.Right
end

function BinderDesk.slot(side: Side, index: number): Frame
	BinderDesk.build()
	return slots[side][index]
end

-- The set dividers on the case's right edge, top down in `sets` order; the open one sticks out further
function BinderDesk.setTabs(sets: { string }, colors: { [string]: Color3 }, current: string)
	BinderDesk.build()
	for _, tab in tabParts do
		local at = table.find(pickables, tab)
		if at then
			table.remove(pickables, at)
		end
		tab:Destroy()
	end
	table.clear(tabParts)
	local look = Desk.TAB
	for order, set in sets do
		local reach = look.stickOut + (if set == current then look.openExtra else 0)
		local z = -CASE_D / 2 + look.top + look.depth / 2 + (order - 1) * (look.depth + look.gap)
		local length = reach + 0.2 -- tucked a little under the case's edge
		local cframe = centre * CFrame.new(CASE_W / 2 + reach - length / 2, CASE_T / 2 - 0.02, z)
		local color = colors[set] or BOOK.EDGE
		local tab = makePart(`Tab{order}`, flatSize(length, 0.03, look.depth), cframe * QUARTER, color, Enum.Material.SmoothPlastic, folder :: Folder)
		tab.CanQuery = true
		tab:SetAttribute("Set", set)
		local canvas = topCanvas(tab, Desk.PAGE_PIXELS_PER_STUD, color)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.25, 0)
		corner.Parent = canvas
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(1, 0.5)
		label.Position = UDim2.fromScale(1, 0.5)
		label.Size = UDim2.new(reach / length, -8, 0.7, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.Text = set
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.ZIndex = 2
		label.Parent = canvas
		local edge = Instance.new("UIStroke")
		edge.Color = BOOK.CASE_DARK
		edge.Thickness = 3
		edge.Parent = label
		table.insert(tabParts, tab)
		table.insert(pickables, tab)
	end
end

-- A page point as fractions (u from the page's left edge, v from its top, the far edge) and back; pages are turned a
-- quarter (QUARTER): their local -Z runs along the binder's x, their local X toward the near edge
local function pageUV(page: BasePart, world: Vector3): (number, number)
	local here = page.CFrame:PointToObjectSpace(world)
	return -here.Z / PAGE.X + 0.5, here.X / PAGE.Y + 0.5
end

local function pagePoint(u: number, v: number, height: number): Vector3
	return Vector3.new((v - 0.5) * PAGE.Y, height, -(u - 0.5) * PAGE.X)
end

-- What's under a screen point (GUI space, as InputObject.Position): a pocket, the page around it, or a set tab
function BinderDesk.pick(point: Vector2): Pick?
	local camera = workspace.CurrentCamera
	if not shown or inspecting or not camera then
		return nil
	end
	local ray = camera:ScreenPointToRay(point.X, point.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = pickables
	local hit = workspace:Raycast(ray.Origin, ray.Direction * REACH, params)
	if not hit then
		return nil
	end
	local set = hit.Instance:GetAttribute("Set")
	if typeof(set) == "string" then
		return { kind = "tab", set = set }
	end
	for side, page in pageParts do
		if page == hit.Instance then
			local u, v = pageUV(page, hit.Position)
			local index = BinderFit.pocketAt(u, v, Desk.POCKETS)
			if index then
				return { kind = "pocket", side = side, index = index, u = u }
			end
			return { kind = "page", side = side, u = u }
		end
	end
	return nil
end

-- The screen rectangle (GUI space) around a set of points on the binder
local function screenRect(points: { Vector3 }): UiLayout.Rect
	local camera = workspace.CurrentCamera
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, point in points do
		local screen = camera:WorldToScreenPoint(point)
		minX, minY = math.min(minX, screen.X), math.min(minY, screen.Y)
		maxX, maxY = math.max(maxX, screen.X), math.max(maxY, screen.Y)
	end
	return { x = minX, y = minY, w = maxX - minX, h = maxY - minY }
end

-- Where a pocket is on screen (GUI space)
function BinderDesk.pocketRect(side: Side, index: number): UiLayout.Rect
	local page = pageParts[side]
	local box = BinderFit.pocketBox(index, Desk.POCKETS)
	local top = PAGE_T / 2
	local points = {}
	for _, corner in { { box.u0, box.v0 }, { box.u1, box.v0 }, { box.u0, box.v1 }, { box.u1, box.v1 } } do
		table.insert(points, page.CFrame:PointToWorldSpace(pagePoint(corner[1], corner[2], top)))
	end
	return screenRect(points)
end

-- Where the whole binder (case) is on screen (GUI space)
function BinderDesk.bookRect(): UiLayout.Rect
	local points = {}
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		table.insert(points, centre:PointToWorldSpace(Vector3.new(corner[1] * CASE_W / 2, CASE_T / 2, corner[2] * CASE_D / 2)))
	end
	return screenRect(points)
end

-- A pocket's centre on its page (world CFrame, the page's orientation) and its size
function BinderDesk.pocketCFrame(side: Side, index: number): (CFrame, Vector3)
	local page = pageParts[side]
	local box = BinderFit.pocketBox(index, Desk.POCKETS)
	local u, v = (box.u0 + box.u1) / 2, (box.v0 + box.v1) / 2
	-- In the binder's axes (x right, -z to the page tops), not the page part's turned ones
	local cframe = CFrame.new(page.CFrame:PointToWorldSpace(pagePoint(u, v, PAGE_T / 2))) * centre.Rotation
	return cframe, Vector3.new((box.u1 - box.u0) * PAGE.X, 0.02, (box.v1 - box.v0) * PAGE.Y)
end

-- The spine at page height (x toward the right page, y up, -z toward the page tops) and a page's size: where a
-- turning page hinges
function BinderDesk.spine(): (CFrame, Vector2)
	return centre * CFrame.new(0, PAGE_Y + PAGE_T / 2, 0), PAGE
end

-- Where a screen point (GUI space) falls along the binder's width: studs from the spine, positive toward the right
-- page (on the pages' plane, even past their edges); nil when the ray runs along the plane
function BinderDesk.spineOffset(point: Vector2): number?
	local camera = workspace.CurrentCamera
	if not shown or not camera then
		return nil
	end
	local ray = camera:ScreenPointToRay(point.X, point.Y)
	local origin = centre:PointToObjectSpace(ray.Origin)
	local direction = centre:VectorToObjectSpace(ray.Direction)
	if math.abs(direction.Y) < 1e-6 then
		return nil
	end
	local along = (PAGE_Y + PAGE_T / 2 - origin.Y) / direction.Y
	return origin.X + direction.X * along
end

-- The card view takes the camera: give back the normal field of view (its card is sized by it); take the binder's
-- camera back when it closes
function BinderDesk.setInspecting(on: boolean)
	local camera = workspace.CurrentCamera
	local before = saved
	if not shown or not camera or not before then
		return
	end
	inspecting = on
	stopTween()
	if on then
		camera.FieldOfView = before.fov
		return
	end
	dropLift()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Desk.FIELD_OF_VIEW
	if lastRect then
		camera.CFrame = cameraFor(lastRect)
	end
end

-- A picked card slides up out of its sleeve and comes toward the camera (LIFT_SECONDS), then `done` runs (the card
-- view opens); the card goes when the binder takes the camera back. False when a card is already on its way.
function BinderDesk.lift(side: Side, index: number, card: Lite, done: () -> ()): boolean
	local camera = workspace.CurrentCamera
	if lifted or not shown or not camera or not folder then
		return false
	end
	local pocket, size = BinderDesk.pocketCFrame(side, index)
	local width = size.X
	local height = width / 0.7
	local up = pocket.UpVector
	-- Lying in its pocket face up (its front, -Z, toward the sky; top toward the far edge), a little raised
	local start = CFrame.lookAt(pocket.Position + up * 0.02, pocket.Position + up, -pocket.LookVector)
	local eye = camera.CFrame.Position
	local target = start.Position:Lerp(eye, LIFT_ROOM)
	local finish = CFrame.lookAt(target, eye, camera.CFrame.UpVector)
	local part = Instance.new("Part")
	part.Name = "LiftedCard"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Vector3.new(width, height, 0.02)
	part.CFrame = start
	part.Color = BOOK.CASE_DARK
	part.Parent = folder
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = Desk.PAGE_PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Parent = part
	local face = Instance.new("ImageLabel")
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = BOOK.SLEEVE
	face.Image = card.image
	face.ScaleType = Enum.ScaleType.Crop
	face.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = face
	local rim = Instance.new("UIStroke")
	rim.Color = card.rim
	rim.Thickness = 6
	rim.Parent = face
	lifted = part
	local fly = TweenService:Create(part, TweenInfo.new(Desk.LIFT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = finish })
	fly.Completed:Once(function()
		if lifted == part then
			done()
		end
	end)
	fly:Play()
	return true
end

return BinderDesk
