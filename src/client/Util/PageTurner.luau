--!strict
-- The binder's turning page (spec 2026-10-29-3d-binder-design.md section 5): a chain of strips hinged at the spine
-- that bends as it turns (PageCurl), the outer edge leading, darkening as it stands up and casting a shadow on the
-- page under it, with a page sound. Each strip carries its slice of the page on both sides: the face it leaves
-- (front, on top while it lies right) and the one it lands with (back). The page shows light cards (art and rim,
-- BinderDesk.Lite), all built once, so a turn only swaps pictures. Parked out of view while no page turns.
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Desk = require(Config:WaitForChild("BinderDesk"))
local Collection = require(Config:WaitForChild("Collection"))
local BinderFit = require(Shared:WaitForChild("Util"):WaitForChild("BinderFit"))
local PageCurl = require(Shared:WaitForChild("Util"):WaitForChild("PageCurl"))

local ClientUtil = script.Parent :: Instance
local BinderDesk = require(ClientUtil:WaitForChild("BinderDesk"))

type Slot = { frame: Frame, art: ImageLabel, rim: UIStroke, mark: TextLabel }
type Side = { canvas: Frame, shade: Frame, slots: { [number]: Slot } } -- only the slots its slice shows
type Strip = { front: Part, back: Part, faces: { front: Side, back: Side } }

local BOOK = Collection.BOOK
local THICKNESS = 0.012
local QUARTER = CFrame.Angles(0, -math.pi / 2, 0) -- see BinderDesk: a top-face GUI reads along the part's -Z
local PARKED = CFrame.new(Desk.STAGE_POSITION - Vector3.new(0, 120, 0)) -- out of view under the desk while idle
local PAGE_PIXELS = Desk.PAGE_SIZE * Desk.PAGE_PIXELS_PER_STUD

local PageTurner = {}

local folder: Folder? = nil
local strips: { Strip } = {}
local shadow: Part
local shadowFill: Frame
local sound: Sound? = nil
local turning = false
local forwardTurn = true
local progress = 0
local animation: RBXScriptConnection? = nil

-- One page of light card slots, inside a strip's clipped window at its slice's offset
local function buildSide(part: Part, slice: number): Side
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = Desk.PAGE_PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = Desk.BINDER_BRIGHTNESS
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = part
	local window = Instance.new("Frame")
	window.Size = UDim2.fromScale(1, 1)
	window.BackgroundTransparency = 1
	window.ClipsDescendants = true
	window.Parent = gui
	local canvas = Instance.new("Frame")
	canvas.Name = "Page"
	canvas.Position = UDim2.fromOffset(-slice * PAGE_PIXELS.X / Desk.STRIPS, 0)
	canvas.Size = UDim2.fromOffset(PAGE_PIXELS.X, PAGE_PIXELS.Y)
	canvas.BackgroundColor3 = BOOK.PAGE_COLOR
	canvas.BorderSizePixel = 0
	canvas.Parent = window
	local slots = {}
	local sliceFrom, sliceTo = slice / Desk.STRIPS, (slice + 1) / Desk.STRIPS
	for index = 1, Desk.POCKETS.columns * Desk.POCKETS.rows do
		local box = BinderFit.pocketBox(index, Desk.POCKETS)
		-- A strip shows a sixth of the page: only the cards across that slice (fewer pictures to swap a turn)
		if box.u1 <= sliceFrom or box.u0 >= sliceTo then
			continue
		end
		local frame = Instance.new("Frame")
		frame.Position = UDim2.fromScale(box.u0, box.v0)
		frame.Size = UDim2.fromScale(box.u1 - box.u0, box.v1 - box.v0)
		frame.BackgroundColor3 = BOOK.SLEEVE
		frame.ZIndex = 2
		frame.Parent = canvas
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = frame
		local rim = Instance.new("UIStroke")
		rim.Thickness = 5
		rim.Parent = frame
		local art = Instance.new("ImageLabel")
		art.Size = UDim2.fromScale(1, 1)
		art.BackgroundTransparency = 1
		art.ScaleType = Enum.ScaleType.Crop
		art.ZIndex = 3
		art.Parent = frame
		local artCorner = corner:Clone()
		artCorner.Parent = art
		local mark = Instance.new("TextLabel")
		mark.Size = UDim2.fromScale(1, 1)
		mark.BackgroundTransparency = 1
		mark.Font = Enum.Font.FredokaOne
		mark.Text = "?"
		mark.TextScaled = true
		mark.TextColor3 = BOOK.SUBTEXT
		mark.ZIndex = 4
		mark.Parent = frame
		slots[index] = { frame = frame, art = art, rim = rim, mark = mark }
	end
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 1
	shade.BorderSizePixel = 0
	shade.ZIndex = 10
	shade.Parent = window
	return { canvas = canvas, shade = shade, slots = slots }
end

local function makePart(name: string, size: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = size
	part.Color = BOOK.PAGE_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

-- Builds the strips, the shadow and the sound once (later calls do nothing). They stay in the world, parked out of
-- view while no page turns: their SurfaceGuis are laid out once instead of on every turn.
function PageTurner.build()
	if folder then
		return
	end
	local root = Instance.new("Folder")
	root.Name = "PageTurner"
	local width = Desk.PAGE_SIZE.X / Desk.STRIPS
	local depth = Desk.PAGE_SIZE.Y
	for index = 1, Desk.STRIPS do
		-- Turned a quarter like the pages, so the GUIs read along the binder; size as (depth, height, width)
		local front = makePart(`Strip{index}Front`, Vector3.new(depth, THICKNESS, width), root)
		local back = makePart(`Strip{index}Back`, Vector3.new(depth, THICKNESS, width), root)
		-- The front shows slice index - 1 of the right page; the back, lying left after the turn, the mirrored slice
		strips[index] = {
			front = front,
			back = back,
			faces = { front = buildSide(front, index - 1), back = buildSide(back, Desk.STRIPS - index) },
		}
	end
	shadow = makePart("TurnShadow", Vector3.new(depth, 0.004, 1), root)
	shadow.Transparency = 1
	local shadowGui = Instance.new("SurfaceGui")
	shadowGui.Face = Enum.NormalId.Top
	shadowGui.LightInfluence = 0
	shadowGui.Parent = shadow
	shadowFill = Instance.new("Frame")
	shadowFill.Size = UDim2.fromScale(1, 1)
	shadowFill.BackgroundColor3 = Color3.new(0, 0, 0)
	shadowFill.BorderSizePixel = 0
	shadowFill.Parent = shadowGui
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new(0, 1)
	fade.Parent = shadowFill
	if Desk.TURN_SOUND_ID ~= "" then
		local turnSound = Instance.new("Sound")
		turnSound.Name = "PageTurn"
		turnSound.SoundId = `rbxassetid://{Desk.TURN_SOUND_ID}`
		turnSound.Volume = Desk.TURN_SOUND_VOLUME
		turnSound.Parent = SoundService
		sound = turnSound
		task.spawn(function()
			ContentProvider:PreloadAsync({ turnSound }) -- so the first turn isn't silent
		end)
	end
	root.Parent = workspace
	folder = root
	for _, strip in strips do
		strip.front.CFrame = PARKED
		strip.back.CFrame = PARKED
	end
	shadow.CFrame = PARKED
end

local function fill(side: Side, face: BinderDesk.Face)
	for index, slot in side.slots do
		local card = face[index]
		slot.frame.Visible = card ~= nil
		if card then
			slot.art.Image = if card.missing then "" else card.image
			slot.rim.Color = if card.missing then BOOK.SLEEVE_EDGE else card.rim
			slot.mark.Visible = card.missing
		end
	end
end

-- Lays the page out at progress t: the strips along the curl, each side shaded as it stands up, the shadow on the
-- page it hangs over
local function pose(t: number)
	progress = math.clamp(t, 0, 1)
	local spine, size = BinderDesk.spine()
	local width = size.X / Desk.STRIPS
	local angles = PageCurl.angles(progress, Desk.STRIPS, Desk.BEND_DEGREES)
	if not forwardTurn then
		for k, angle in angles do
			angles[k] = 180 - angle
		end
	end
	local points = PageCurl.chain(angles, width)
	for k, strip in strips do
		local radians = math.rad(angles[k])
		local middle = Vector3.new((points[k].x + points[k + 1].x) / 2, (points[k].y + points[k + 1].y) / 2, 0)
		local hinge = spine * CFrame.new(middle) * CFrame.Angles(0, 0, radians)
		strip.front.CFrame = hinge * CFrame.new(0, THICKNESS / 2, 0) * QUARTER
		strip.back.CFrame = hinge * CFrame.Angles(0, 0, math.pi) * CFrame.new(0, THICKNESS / 2, 0) * QUARTER
		local stand = math.sin(radians)
		strip.faces.front.shade.BackgroundTransparency = 1 - Desk.TURN_SHADE * stand
		strip.faces.back.shade.BackgroundTransparency = 1 - Desk.TURN_SHADE * stand * 0.7
	end
	-- The shadow falls on the page under the leaf, out to where its tip is over the desk
	local tip = points[#points].x
	local reach = math.clamp(math.abs(tip), 0.05, size.X)
	local onRight = tip >= 0
	shadow.Size = Vector3.new(size.Y, 0.004, reach)
	shadow.CFrame = spine * CFrame.new((if onRight then 1 else -1) * reach / 2, 0.003, 0) * QUARTER
	local gradient = shadowFill:FindFirstChildOfClass("UIGradient") :: UIGradient
	gradient.Rotation = if onRight then 0 else 180
	shadowFill.BackgroundTransparency = 1 - (1 - Desk.SHADOW_TRANSPARENCY) * math.sin(math.pi * progress)
end

local function stop()
	if animation then
		animation:Disconnect()
		animation = nil
	end
end

local function show(forward: boolean, leaving: BinderDesk.Face, arriving: BinderDesk.Face)
	PageTurner.build()
	stop()
	forwardTurn = forward
	turning = true
	-- A forward turn lifts the right page (its top shows what it leaves); a back turn the left (its underside does)
	for _, strip in strips do
		fill(strip.faces.front, if forward then leaving else arriving)
		fill(strip.faces.back, if forward then arriving else leaving)
	end
	pose(0)
end

local function hide()
	stop()
	turning = false
	for _, strip in strips do
		strip.front.CFrame = PARKED
		strip.back.CFrame = PARKED
	end
	if shadow then
		shadow.CFrame = PARKED
	end
end

-- Runs progress from where it is to `target` over `seconds`, then calls done
local function animate(target: number, seconds: number, done: () -> ())
	stop()
	local from = progress
	local started = os.clock()
	animation = RunService.RenderStepped:Connect(function()
		local share = if seconds > 0 then math.min(1, (os.clock() - started) / seconds) else 1
		pose(from + (target - from) * share)
		if share >= 1 then
			stop()
			done()
		end
	end)
end

-- Turns a page by itself: forward lifts the right page over to the left, back the left page to the right
function PageTurner.play(forward: boolean, leaving: BinderDesk.Face, arriving: BinderDesk.Face, seconds: number, onLanded: () -> ())
	show(forward, leaving, arriving)
	if sound then
		sound.PlaybackSpeed = math.clamp(Desk.TURN_SECONDS / math.max(seconds, 0.05), 1, 1.6)
		SoundService:PlayLocalSound(sound)
	end
	animate(1, seconds, function()
		hide()
		onLanded()
	end)
end

-- Picks a page up by its edge (a drag): it follows pose() until release()
function PageTurner.grab(forward: boolean, leaving: BinderDesk.Face, arriving: BinderDesk.Face)
	show(forward, leaving, arriving)
end

function PageTurner.pose(t: number)
	if turning then
		pose(t)
	end
end

-- Lets a dragged page go: it finishes the turn or falls back, then onDone says which
function PageTurner.release(finish: boolean, onDone: (finished: boolean) -> ())
	local target = if finish then 1 else 0
	if finish and sound then
		sound.PlaybackSpeed = 1
		SoundService:PlayLocalSound(sound)
	end
	animate(target, Desk.TURN_SECONDS * math.abs(target - progress), function()
		hide()
		onDone(finish)
	end)
end

function PageTurner.busy(): boolean
	return turning
end

return PageTurner
