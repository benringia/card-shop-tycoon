--!strict
-- The tutorial's cues (spec 2026-11-09-tutorial-pish-design 5, 6, 14): arrows on the ground to where to go, a bouncing
-- arrow (and a gold ring) over what to tap (a HUD button, a button in a window or a thing in the shop), the small Skip
-- at the top right and the tour card it opens (the step of the tour, the paw row, his gift, Keep going or Skip tour)
-- (Pish's words: Util/TutorialTalk). Each returns a remover, or is set again.
-- Owner 2026-11-21 ("make the highlight more noticeable, also make it fit the shape of what it is highlighting. also
-- make the pawprint more noticeable"; Config/Cues, Util/CueShape): the ring and the spotlight's hole take the button's
-- own corner (a round button gets a round ring), the ring is thicker with a dark line outside it and a second ring
-- pinging outward. Owner 2026-11-27 ("Maybe just use arrows instead of paws. to be simple", picks B and 1; spec
-- 2026-11-27-tutorial-arrows-design): a chunky gold arrow where the bouncing paw was, at the screen's edge when its
-- thing is off the screen, and arrows lying on the ground for the next stretch of the way where the paw prints were.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PishTalk = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PishTalk"))
local TrailRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("TrailRules"))
local ScreenEdges = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("ScreenEdges"))
local Cues = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Cues"))
local CueShape = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("CueShape"))
local TalkRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("TalkRules"))
local UIIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIIcons"))

local ClientUtil = script.Parent :: Instance
local Icon = require(ClientUtil:WaitForChild("Icon"))
local ScreenCover = require(ClientUtil:WaitForChild("ScreenCover"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

local TutorialCues = {}

local TRAIL = Cues.TRAIL -- the arrows lying on the ground
local OFFSCREEN = Cues.OFFSCREEN -- the arrow at the screen's edge for a thing off the screen
local FLOW_SPEED = 6 -- the glow flowing along the arrows on the ground toward the goal
local POINTER_SIZE = Cues.POINTER.size -- px: the bouncing arrow over a button (smaller over a small one, down to POINTER_MIN)
local POINTER_MIN = Cues.POINTER.min
local RING_PAD = Cues.RING.gap + 3 -- px the arrow keeps beside a ringed tile (the ring's own pad: shapeOf)
local RING_THICKNESS = Cues.RING.thickness
local BOUNCE = 10 -- px (studs * 0.4 on a thing in the shop)
local BOUNCE_SPEED = 6
local SCROLL_SWIPE = 60 -- px the scroll arrow slides down each time
local SCROLL_SPEED = 0.9 -- swipes a second
local GOLD = Color3.fromRGB(255, 214, 90)
-- The small Skip at the top right (round 3, owner's pick A) and the tour card it opens: the step of the tour, the paw
-- row, his gift at the end, Keep going and Skip tour. On a phone the HUD's right column (cash, weapon switch) runs
-- from the top, so Skip sits just left of it
local SKIP_SIZE = Vector2.new(84, 48) -- px (tap targets 48 px or more)
-- Docked to the talk card (the owner 2026-11-11, focus mode A: "Skip inside it"): a small pill hanging off the card's
-- bottom right (its top right while the card sits low), its tap area still 48 px tall
local SKIP_DOCKED = { pill = Vector2.new(68, 24), text = 14, icon = 14, inset = 12, overlap = 6 }
local SKIP_EDGE = 10 -- px from the screen's right edge, or from the HUD's right column beside it
local ROW_PAW = 26 -- px each paw on the tour card
local CARD_SIZE = Vector2.new(360, 250)
local CARD_GREY = Color3.fromRGB(190, 195, 205)
local DIM_COLOR = Color3.fromRGB(20, 10, 40) -- the spotlight's dimming
local DIM_TRANSPARENCY = Cues.SPOT.dim
local SPOT_PAD = Cues.SPOT.pad -- px of light round the button
local EDGE = Color3.fromRGB(Cues.EDGE[1], Cues.EDGE[2], Cues.EDGE[3])

local screen: ScreenGui? = nil
local skip: TextButton? = nil
local onSkipTap: (() -> ())? = nil
local skipWanted = false -- the controller wants Skip shown (a window open still hides it)
local spotTarget: GuiObject? = nil
local spotFrames: { Frame }? = nil
local card: Frame? = nil
local askCard: Frame? = nil -- the "tour again?" card (TutorialCues.askReplay)
local ASK_SIZE = Vector2.new(330, 150)
local ASK_EXTRA = 60 -- px taller with a second choice
-- The arrow over a thing in the world, for the talk card to keep clear of (TutorialCues.worldPointerBox): its holder
-- and the box it bounces in (the screen's px, as AbsolutePosition)
local worldHolder: Frame? = nil
local worldBox: TalkRules.Box? = nil
-- The newest arrow pointAt drew (on a button or over the world), for the What now? bubble to stand by
-- (TutorialCues.pointerOf, Util/HintBubble)
local pointerHolder: Frame? = nil
local pointerArrow: GuiObject? = nil

-- The cues' own screen, over the HUD
local function gui(): ScreenGui
	local made = screen
	if made and made.Parent then
		return made
	end
	local new = Instance.new("ScreenGui")
	new.Name = "TutorialCues"
	new.ResetOnSpawn = false
	new.IgnoreGuiInset = false -- the same space as the HUD, so a paw lines up with its button
	new.DisplayOrder = 30
	new.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	new.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen = new
	return new
end

local function fade(icon: Instance, transparency: number)
	for _, image in icon:GetDescendants() do
		if image:IsA("ImageLabel") then
			image.ImageTransparency = transparency
		end
	end
end

-- The chunky gold arrow filling `holder` (pick B: its own white edge and dark outline read on light floors and dark
-- streets alike; the paw before needed a dark backing and a halo), turned `rotation` degrees clockwise from pointing
-- down
local function arrowIn(holder: GuiObject, rotation: number): Frame
	local arrow = Icon.make(holder, "ArrowCue", UDim2.fromScale(1, 1))
	arrow.Name = "Arrow"
	arrow.Rotation = rotation
	return arrow
end

-- Which way an arrow turned `rotation` degrees points (screen px: x right, y down)
local function pointing(rotation: number): Vector2
	local turn = math.rad(rotation)
	return Vector2.new(-math.sin(turn), math.cos(turn))
end

-- The piece that holds the shape of the thing a cue is on: itself when it has a UICorner, else a face inside it that
-- fills it (a HUD tile's rounded face sits two frames down); nil when nothing is rounded
local function faceOf(target: GuiObject): GuiObject?
	if target:FindFirstChildOfClass("UICorner") then
		return target
	end
	local size = { w = target.AbsoluteSize.X, h = target.AbsoluteSize.Y }
	local function search(parent: Instance, depth: number): GuiObject?
		for _, child in parent:GetChildren() do
			if child:IsA("GuiObject") and child.Visible and CueShape.fills({ w = child.AbsoluteSize.X, h = child.AbsoluteSize.Y }, size) then
				if child:FindFirstChildOfClass("UICorner") and child.BackgroundTransparency < 1 then
					return child
				end
				if depth < 3 then
					local deeper = search(child, depth + 1)
					if deeper then
						return deeper
					end
				end
			end
		end
		return nil
	end
	return search(target, 1)
end

-- How much bigger a piece is drawn than designed: its own and its ancestors' UIScales (a computer's HUD grows, a
-- window pops in)
local function drawnScale(piece: Instance): number
	local scale = 1
	local at: Instance? = piece
	while at and not at:IsA("LayerCollector") do
		local own = at:FindFirstChildOfClass("UIScale")
		if own then
			scale *= own.Scale
		end
		at = at.Parent
	end
	return scale
end

-- The shape a ring (or the spotlight's hole) takes round `target` (owner 2026-11-20: "make sure every highlighted
-- elements fit the highlight border"): the face that holds its shape (its rect is what the ring goes round), that
-- face's corner as drawn, and how far off the ring stands: just outside the face's own outline
local function shapeOf(target: GuiObject): (GuiObject, CueShape.Corner?, number, number)
	local face = faceOf(target)
	local piece = face or target
	local scale = drawnScale(piece)
	local round = if face then face:FindFirstChildOfClass("UICorner") else nil
	local corner = if round then { scale = round.CornerRadius.Scale, offset = round.CornerRadius.Offset } else nil
	local outline: number? = nil
	for _, child in piece:GetChildren() do
		if child:IsA("UIStroke") and child.Enabled and child.Transparency < 1 and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			outline = math.max(outline or 0, child.Thickness)
		end
	end
	return piece, corner, scale, CueShape.pad(outline, scale, Cues.RING)
end

-- A see-through frame with a rounded outline (the gold ring, its dark edge, the ping)
local function outlineFrame(name: string, color: Color3, thickness: number, z: number): (Frame, UICorner, UIStroke)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.ZIndex = z
	frame.Parent = gui()
	local corner = Instance.new("UICorner")
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = frame
	return frame, corner, stroke
end

-- Where a point in the world shows on the cues' screen (it shares the HUD's inset), and how far it is; nil behind
-- the camera
local function onScreen(at: Vector3): (Vector2?, number)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil, 0
	end
	local point, visible = camera:WorldToScreenPoint(at)
	if point.Z <= 0 then
		return nil, 0
	end
	return if visible then Vector2.new(point.X, point.Y) else nil, point.Z
end

-- The walking route from `from` to `to` (owner 2026-11-16: "chikin paws are passes through things. fix it and make
-- the paws go through the correct path"): Roblox's pathfinding round walls, shops and props; a straight line when it
-- finds none (the ground under the target isn't walkable, say). Yields.
local function route(from: Vector3, to: Vector3): { TrailRules.Point }
	local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 4 })
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	local points: { TrailRules.Point } = {}
	if ok and path.Status == Enum.PathStatus.Success then
		for _, waypoint in path:GetWaypoints() do
			table.insert(points, { x = waypoint.Position.X, y = waypoint.Position.Y, z = waypoint.Position.Z })
		end
	end
	if #points < 2 then
		points = { { x = from.X, y = to.Y, z = from.Z }, { x = to.X, y = to.Y, z = to.Z } }
	end
	return points
end

-- One arrow lying on the ground: a small invisible part of this client's own with the Chevron picture on its top, drawn
-- over walls and doors (AlwaysOnTop; owner 2026-11-10: "paw prints are not visible when the door is closed")
local function chevronIn(folder: Instance): { part: BasePart, surface: SurfaceGui, image: ImageLabel, shown: number }
	local part = Instance.new("Part")
	part.Name = "Chevron"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(TRAIL.size, 0.05, TRAIL.size)
	part.Parent = folder
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Top
	surface.AlwaysOnTop = true
	surface.LightInfluence = 0
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = TRAIL.pixelsPerStud
	surface.Enabled = false
	surface.Parent = part
	local image = Instance.new("ImageLabel")
	image.Name = "Chevron"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = UIIcons.Chevron
	image.Rotation = TRAIL.rotation
	image.Parent = surface
	return { part = part, surface = surface, image = image, shown = 0 }
end

-- Arrows lying on the ground along the walking route from `from` to `to` (owner 2026-11-27, pick 1): only the next
-- stretch past the player (TrailRules.ahead; the whole route's paws piled into a gold smear at the horizon), a glow
-- flowing toward the goal, the last few fading out. The callers redraw it from where the player is every few studs;
-- in between, the stretch moves on with them
function TutorialCues.trail(from: Vector3, to: Vector3): () -> ()
	local folder = Instance.new("Folder")
	folder.Name = "ArrowTrail"
	folder.Parent = workspace
	local stopped = false
	local connection: RBXScriptConnection? = nil
	task.spawn(function()
		local points = route(from, to)
		if stopped then
			return
		end
		local marks = TrailRules.along(points, TRAIL.gap, TRAIL.max)
		local pool = {}
		for _ = 1, TRAIL.ahead do
			table.insert(pool, chevronIn(folder))
		end
		local started = os.clock()
		local fadeFrom = TRAIL.ahead - TRAIL.fade -- the slots past this one fade out
		connection = RunService.RenderStepped:Connect(function()
			local character = Players.LocalPlayer.Character
			local body = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local at = if body and body:IsA("BasePart") then body.Position else from
			local first, last = TrailRules.ahead(marks, TrailRules.progress(points, { x = at.X, y = at.Y, z = at.Z }), TRAIL.ahead)
			local wave = (os.clock() - started) * FLOW_SPEED
			for slot, chevron in pool do
				local index = first + slot - 1
				local mark = if index <= last then marks[index] else nil
				chevron.surface.Enabled = mark ~= nil
				if mark then
					if chevron.shown ~= index then
						chevron.shown = index
						chevron.part.CFrame = CFrame.new(mark.x, mark.y + TRAIL.lift, mark.z) * CFrame.Angles(0, -math.rad(mark.facing), 0)
					end
					-- the glow passing toward the goal, never fainter than TRAIL.dim; the last few fading out
					local glow = 0.5 + 0.5 * math.sin(wave - slot * 0.7)
					local base = TRAIL.dim * (1 - glow)
					local gone = math.max(0, slot - fadeFrom) / (TRAIL.fade + 1)
					chevron.image.ImageTransparency = base + (1 - base) * gone
				end
			end
		end)
	end)
	return function()
		stopped = true
		if connection then
			connection:Disconnect()
		end
		folder:Destroy()
	end
end

-- An arrow inside a scrolling list's bottom edge, pointing down, sliding downward again and again: scroll down (owner
-- 2026-11-16: the paw pointed at a tile out of view)
function TutorialCues.scrollHint(list: GuiObject): () -> ()
	local started = os.clock()
	local holder = Instance.new("Frame")
	holder.Name = "ScrollArrow"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Size = UDim2.fromOffset(POINTER_SIZE, POINTER_SIZE)
	holder.ZIndex = 20
	holder.Parent = gui()
	local arrow = arrowIn(holder, 0)
	local connection = RunService.RenderStepped:Connect(function()
		local at, size = list.AbsolutePosition, list.AbsoluteSize
		holder.Visible = list.Parent ~= nil and list.Visible and size.Y > POINTER_SIZE * 2
		-- a downward swipe: slides SCROLL_SWIPE px down, fading out at the bottom, then starts again
		local cycle = ((os.clock() - started) * SCROLL_SPEED) % 1
		holder.Position = UDim2.fromOffset(at.X + size.X / 2, at.Y + size.Y - 8 - SCROLL_SWIPE + cycle * SCROLL_SWIPE)
		fade(arrow, if cycle > 0.7 then (cycle - 0.7) / 0.3 else 0)
	end)
	return function()
		connection:Disconnect()
		holder:Destroy()
	end
end

-- What of a button shows on screen: its face as drawn (shapeOf), and only the part its scrolling list shows when it's
-- half scrolled out (so the ring and paw stay inside the list); `clipped` when its top is cut off
local function showing(gui: GuiObject): (Vector2, Vector2, boolean, CueShape.Corner?, number, number)
	local piece, pieceCorner, pieceScale, pad = shapeOf(gui)
	local at, size = piece.AbsolutePosition, piece.AbsoluteSize
	local list = gui:FindFirstAncestorWhichIsA("ScrollingFrame")
	local clipped = false
	if list then
		local top = math.max(at.Y, list.AbsolutePosition.Y)
		local bottom = math.min(at.Y + size.Y, list.AbsolutePosition.Y + list.AbsoluteSize.Y)
		clipped = top > at.Y
		at, size = Vector2.new(at.X, top), Vector2.new(size.X, math.max(0, bottom - top))
	end
	return at, size, clipped, pieceCorner, pieceScale, pad
end

-- A bouncing arrow pointing down at a HUD button, a button in a window or a thing in the shop; a button also gets a
-- pulsing gold ring round it (in a window full of items the arrow alone could pass for one of them). `around`: what
-- the ring goes round instead, the arrow staying on `target` (the rack's whole Shop tile, its arrow on Buy: spec
-- 2026-11-25-pish-first-steps-design 2)
function TutorialCues.pointAt(target: GuiObject | BasePart, around: GuiObject?): () -> ()
	local started = os.clock()
	if typeof(target) == "Instance" and target:IsA("GuiObject") then
		local ringOn = around or target
		local holder = Instance.new("Frame")
		holder.Name = "ArrowPointer"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 1)
		holder.ZIndex = 20
		holder.Parent = gui()
		local arrow = arrowIn(holder, 0) -- pointing down, toward the button
		pointerHolder, pointerArrow = holder, arrow
		-- the gold ring in the button's own shape, a dark line outside it, and a second ring pinging outward
		local ring, corner, stroke = outlineFrame("CueRing", GOLD, RING_THICKNESS, 19)
		local edge, edgeCorner, edgeStroke = outlineFrame("CueRingEdge", EDGE, Cues.RING.edge, 18)
		edgeStroke.Transparency = 0.35
		local ping, pingCorner, pingStroke = outlineFrame("CuePing", GOLD, Cues.PING.thickness, 18)
		local connection = RunService.RenderStepped:Connect(function()
			local elapsed = os.clock() - started
			local beat = math.abs(math.sin(elapsed * BOUNCE_SPEED))
			-- the arrow's button as it shows, and the ring's: the piece that holds its shape (a tile's face), its corner as
			-- drawn, and the ring's place just outside its own outline
			local at, size, clipped = showing(target)
			local ringAt, ringSize, _, pieceCorner, pieceScale, pad = showing(ringOn)
			local shown = target.Parent ~= nil and target.Visible and size.X > 0 and size.Y > 0
				and ringOn.Parent ~= nil and ringSize.X > 0 and ringSize.Y > 0
			local arrowSize = math.clamp(size.Y * 0.9, POINTER_MIN, POINTER_SIZE)
			holder.Visible = shown
			holder.Size = UDim2.fromOffset(arrowSize, arrowSize)
			-- above it, or just inside its top when that is the list's edge (not over the window's tabs); under it,
			-- pointing up, when there's no room above (a button in Roblox's top bar: the town button, owner 2026-11-18)
			local arrowBottom = if clipped then at.Y + arrowSize + 4 else at.Y - 4
			local under = not clipped and arrowBottom - arrowSize - BOUNCE < ScreenCover.rect(gui()).y
			-- a tile in the left side column: from its right, pointing left (CueShape.pointerSide)
			local layer = gui()
			local beside = not clipped and CueShape.pointerSide({ x = at.X - layer.AbsolutePosition.X, w = size.X }, layer.AbsoluteSize.X, Cues.POINTER.sideShare) == "right"
			arrow.Rotation = if beside then 90 elseif under then 180 else 0
			holder.AnchorPoint = if beside then Vector2.new(0, 0.5) else Vector2.new(0.5, if under then 0 else 1)
			if beside then
				holder.Position = UDim2.fromOffset(at.X + size.X + RING_PAD + RING_THICKNESS + 4 + beat * BOUNCE, at.Y + size.Y / 2)
			elseif under then
				holder.Position = UDim2.fromOffset(at.X + size.X / 2, at.Y + size.Y + 4 + beat * BOUNCE)
			else
				holder.Position = UDim2.fromOffset(at.X + size.X / 2, arrowBottom - beat * BOUNCE)
			end
			-- the ring: the button's own corner (a tile half out of its list keeps the list's square edge there)
			local radius = CueShape.radius({ w = ringSize.X, h = ringSize.Y }, pieceCorner, pad, Cues.RING.fallback, pieceScale)
			local pulse = Cues.RING.pulse
			ring.Visible = shown
			ring.Position = UDim2.fromOffset(ringAt.X - pad, ringAt.Y - pad)
			ring.Size = UDim2.fromOffset(ringSize.X + pad * 2, ringSize.Y + pad * 2)
			corner.CornerRadius = UDim.new(0, radius)
			stroke.Transparency = pulse[1] + beat * (pulse[2] - pulse[1])
			local out = pad + RING_THICKNESS
			edge.Visible = shown
			edge.Position = UDim2.fromOffset(ringAt.X - out, ringAt.Y - out)
			edge.Size = UDim2.fromOffset(ringSize.X + out * 2, ringSize.Y + out * 2)
			edgeCorner.CornerRadius = UDim.new(0, radius + RING_THICKNESS)
			local grow, gone = CueShape.ping(elapsed, Cues.PING)
			local far = out + grow
			ping.Visible = shown
			ping.Position = UDim2.fromOffset(ringAt.X - far, ringAt.Y - far)
			ping.Size = UDim2.fromOffset(ringSize.X + far * 2, ringSize.Y + far * 2)
			pingCorner.CornerRadius = UDim.new(0, radius + RING_THICKNESS + grow)
			pingStroke.Transparency = gone
		end)
		return function()
			connection:Disconnect()
			holder:Destroy()
			ring:Destroy()
			edge:Destroy()
			ping:Destroy()
			if pointerHolder == holder then
				pointerHolder, pointerArrow = nil, nil
			end
		end
	end
	local part = target :: BasePart
	-- On the screen over the world: walls and closed doors don't hide it. Off the screen or behind the camera, it waits
	-- at the screen's edge pointing the way to turn (CueShape.offscreen; owner 2026-11-27: today nothing showed)
	local holder = Instance.new("Frame")
	holder.Name = "ArrowPointer"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(POINTER_SIZE, POINTER_SIZE)
	holder.ZIndex = 20
	holder.Parent = gui()
	local arrow = arrowIn(holder, 0)
	worldHolder = holder
	pointerHolder, pointerArrow = holder, arrow
	local connection = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		holder.Visible = part.Parent ~= nil and camera ~= nil
		if not holder.Visible or not camera then
			worldBox = nil
			return
		end
		local beat = math.abs(math.sin((os.clock() - started) * BOUNCE_SPEED))
		local origin = gui().AbsolutePosition
		local top = part.Position + Vector3.new(0, part.Size.Y / 2 + 0.5, 0)
		local point = onScreen(top)
		if point then
			-- over it, pointing down: the box is where it bounces (for the talk card to keep clear of)
			holder.AnchorPoint = Vector2.new(0.5, 1)
			arrow.Rotation = 0
			holder.Position = UDim2.fromOffset(point.X, point.Y - beat * BOUNCE)
			worldBox = { x = origin.X + point.X - POINTER_SIZE / 2, y = origin.Y + point.Y - POINTER_SIZE - BOUNCE, w = POINTER_SIZE, h = POINTER_SIZE + BOUNCE }
			return
		end
		local rel = camera.CFrame:PointToObjectSpace(top)
		local view = gui().AbsoluteSize
		local spot = CueShape.offscreen({ x = rel.X, y = rel.Y, z = -rel.Z }, { w = view.X, h = view.Y }, OFFSCREEN)
		local way = pointing(spot.rotation)
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.Rotation = spot.rotation
		-- nudging toward the edge, the way it points
		holder.Position = UDim2.fromOffset(spot.x + way.X * beat * BOUNCE, spot.y + way.Y * beat * BOUNCE)
		local reach = POINTER_SIZE / 2 + BOUNCE
		worldBox = { x = origin.X + spot.x - reach, y = origin.Y + spot.y - reach, w = reach * 2, h = reach * 2 }
	end)
	return function()
		connection:Disconnect()
		holder:Destroy()
		if worldHolder == holder then
			worldHolder = nil
			worldBox = nil
		end
		if pointerHolder == holder then
			pointerHolder, pointerArrow = nil, nil
		end
	end
end

-- The newest arrow as drawn: its box on the screen (px, as AbsolutePosition) and its turn (0 points down, 90 left);
-- nil while none shows. The What now? bubble stands by it (Util/HintBubble, HintRules.bubbleAt)
function TutorialCues.pointerOf(): { box: TalkRules.Box, rotation: number }?
	local holder, arrow = pointerHolder, pointerArrow
	if not holder or not arrow or not holder.Parent or not holder.Visible then
		return nil
	end
	local at, size = holder.AbsolutePosition, holder.AbsoluteSize
	return { box = { x = at.X, y = at.Y, w = size.X, h = size.Y }, rotation = arrow.Rotation }
end

-- Where the arrow over a thing in the world bounces, in the screen's px (nil: none showing), for Pish's talk card to
-- keep clear of (Util/TutorialTalk; seen 2026-11-27: Chikin's card covered the Wild's paw)
function TutorialCues.worldPointerBox(): TalkRules.Box?
	local holder = worldHolder
	if not holder or not holder.Parent or not holder.Visible then
		return nil
	end
	return worldBox
end


-- The small Skip at the top right (a tap opens the tour card: TutorialController); shown or hidden
function TutorialCues.skipButton(shown: boolean, onTap: () -> ())
	local button = skip
	if not button or not button.Parent then
		-- The tap area (transparent) holds the pill you see: full size on its own, small when docked to the talk card
		local made = Instance.new("TextButton")
		made.Name = "TutorialSkip"
		made.Text = ""
		made.AnchorPoint = Vector2.new(1, 0)
		made.Size = UDim2.fromOffset(SKIP_SIZE.X, SKIP_SIZE.Y)
		made.BackgroundTransparency = 1
		made.AutoButtonColor = false
		made.ZIndex = 30
		made.Parent = gui()
		local pill = Instance.new("Frame")
		pill.Name = "Pill"
		pill.AnchorPoint = Vector2.new(0.5, 0)
		pill.Position = UDim2.fromScale(0.5, 0)
		pill.Size = UDim2.fromScale(1, 1)
		pill.BackgroundColor3 = Color3.new(1, 1, 1)
		pill.Active = false
		pill.Parent = made
		local pillCorner = Instance.new("UICorner")
		pillCorner.CornerRadius = UDim.new(0, 14)
		pillCorner.Parent = pill
		UIKit.outline(pill, Color3.fromRGB(255, 211, 234), 3)
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0, 4)
		list.Parent = pill
		local arrow = Icon.make(pill, "Next", UDim2.fromOffset(22, 22))
		arrow.LayoutOrder = 1
		local words = UIKit.label(pill, PishTalk.LABELS.skip, Enum.Font.FredokaOne, 19, Color3.fromRGB(90, 70, 110))
		words.LayoutOrder = 2
		words.AutomaticSize = Enum.AutomaticSize.X
		words.Size = UDim2.fromScale(0, 1)
		-- The pill's look: full (on its own, top right) or small (docked to the talk card)
		local docked: boolean? = nil
		local function dock(on: boolean, below: boolean)
			if docked ~= on then
				docked = on
				local size = SKIP_DOCKED
				pill.Size = if on then UDim2.fromOffset(size.pill.X, size.pill.Y) else UDim2.fromScale(1, 1)
				words.TextSize = if on then size.text else 19
				arrow.Size = if on then UDim2.fromOffset(size.icon, size.icon) else UDim2.fromOffset(22, 22)
				pillCorner.CornerRadius = UDim.new(0, if on then size.pill.Y / 2 else 14)
			end
			-- hanging off the card's bottom edge (or its top while the card sits low)
			pill.AnchorPoint = Vector2.new(0.5, if on and not below then 1 else 0)
			pill.Position = UDim2.fromScale(0.5, if on and not below then 1 else 0)
		end
		made.Activated:Connect(function()
			local tap = onSkipTap
			if tap then
				tap()
			end
		end)
		-- Docked to the talk card while it shows; else top right, or just left of the HUD's right column when it reaches
		-- the top (phones). Hidden while a window is open: on a phone it sat right on the window's X, which Pish points
		-- at to close it
		RunService.RenderStepped:Connect(function()
			made.Visible = skipWanted and not UIKit.anyPanelOpen()
			if not made.Visible then
				return
			end
			local talk = gui():FindFirstChild("PishTalk")
			if talk and talk:IsA("GuiObject") and talk.Visible then
				local size = SKIP_DOCKED
				local below = talk.AnchorPoint.Y < 0.5 -- the card sits at the top: Skip hangs under it
				local right = talk.AbsolutePosition.X + talk.AbsoluteSize.X - size.inset
				dock(true, below)
				if below then
					made.AnchorPoint = Vector2.new(1, 0)
					made.Position = UDim2.fromOffset(right, talk.AbsolutePosition.Y + talk.AbsoluteSize.Y - size.overlap)
				else
					made.AnchorPoint = Vector2.new(1, 1)
					made.Position = UDim2.fromOffset(right, talk.AbsolutePosition.Y + size.overlap)
				end
				return
			end
			dock(false, true)
			made.AnchorPoint = Vector2.new(1, 0)
			local screenSize = gui().AbsoluteSize
			local right = screenSize.X - SKIP_EDGE
			local main = Players.LocalPlayer:FindFirstChild("PlayerGui")
			local hud = main and main:FindFirstChild("MainGui")
			local column = hud and hud:FindFirstChild("StatusRow")
			if column and column:IsA("GuiObject") and column.Visible and column.AbsolutePosition.Y < SKIP_SIZE.Y + 8 then
				right = math.min(right, column.AbsolutePosition.X - SKIP_EDGE)
			end
			-- a computer's top-right cluster (the cash and, under it, your level: Config/DesktopHud) reaches under the
			-- top bar: Skip sits left of it too
			local cluster = hud and hud:FindFirstChild("TopRow")
			if cluster and cluster:IsA("GuiObject") and cluster.Visible and cluster.AbsoluteSize.X > 0 and cluster.AbsolutePosition.Y + cluster.AbsoluteSize.Y > 4 then
				right = math.min(right, cluster.AbsolutePosition.X - SKIP_EDGE)
			end
			made.Position = UDim2.fromOffset(right, 4)
		end)
		skip = made
		button = made
	end
	onSkipTap = onTap
	skipWanted = shown
	;(button :: TextButton).Visible = shown and not UIKit.anyPanelOpen()
end

-- Where Skip's tap area would sit docked to a talk card at `talk` (hanging under it when `below`, else over its top),
-- the same as skipButton docks it; nil while Skip is hidden (not wanted, or a window open). The card's spot keeps it
-- off what Pish points at too (TalkRules.cardPlace; spec 2026-11-25-pish-first-steps-design 1)
function TutorialCues.skipBox(talk: TalkRules.Box, below: boolean): TalkRules.Box?
	if not skipWanted or UIKit.anyPanelOpen() then
		return nil
	end
	local right = talk.x + talk.w - SKIP_DOCKED.inset
	local y = if below then talk.y + talk.h - SKIP_DOCKED.overlap else talk.y + SKIP_DOCKED.overlap - SKIP_SIZE.Y
	return { x = right - SKIP_SIZE.X, y = y, w = SKIP_SIZE.X, h = SKIP_SIZE.Y }
end

-- Skip's pill as drawn (nil while it's hidden): kept clear with the talk card (Util/FightToast slides in under them)
function TutorialCues.skipPill(): TalkRules.Box?
	local button = skip
	if not button or not button.Parent or not button.Visible then
		return nil
	end
	local pill = button:FindFirstChild("Pill")
	if not pill or not pill:IsA("GuiObject") then
		return nil
	end
	return { x = pill.AbsolutePosition.X, y = pill.AbsolutePosition.Y, w = pill.AbsoluteSize.X, h = pill.AbsoluteSize.Y }
end

-- The tour card (Skip tapped): "Pish's Tour · 3 of 8", the paw row, his gift and what you'd miss, a big green Keep
-- going and a small grey Skip tour
function TutorialCues.tourCard(done: number, total: number, onKeep: () -> (), onSkip: () -> (), custom: { tour: string?, tourGift: string?, icon: string? }?)
	if card and card.Parent then
		return
	end
	local labels = PishTalk.LABELS
	local made = Instance.new("Frame")
	made.Name = "TourCard"
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	made.Position = UDim2.fromScale(0.5, 0.5)
	made.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	made.ZIndex = 40
	made.Parent = gui()
	UIKit.creamWindow(made)
	local ink = UIKit.colorsFor(made).ink
	local own = custom or {}
	local title = UIKit.label(made, string.format(own.tour or labels.tour, math.min(done + 1, total), total), Enum.Font.FredokaOne, 24, ink)
	title.Position = UDim2.fromOffset(0, 12)
	title.Size = UDim2.new(1, 0, 0, 30)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local paws = Instance.new("Frame")
	paws.BackgroundTransparency = 1
	paws.AnchorPoint = Vector2.new(0.5, 0)
	paws.Position = UDim2.new(0.5, 0, 0, 48)
	paws.AutomaticSize = Enum.AutomaticSize.X
	paws.Size = UDim2.fromOffset(0, ROW_PAW)
	paws.Parent = made
	local pawList = Instance.new("UIListLayout")
	pawList.FillDirection = Enum.FillDirection.Horizontal
	pawList.Padding = UDim.new(0, 4)
	pawList.SortOrder = Enum.SortOrder.LayoutOrder
	pawList.Parent = paws
	for i = 1, total do
		local paw = Icon.make(paws, "Paw", UDim2.fromOffset(ROW_PAW, ROW_PAW))
		paw.LayoutOrder = i
		for _, image in paw:GetDescendants() do
			if image:IsA("ImageLabel") then
				image.ImageTransparency = if i <= done then 0 else 0.6
				image.ImageColor3 = if i <= done then GOLD else Color3.fromRGB(200, 190, 210)
			end
		end
	end
	local gift = Icon.make(made, own.icon or "PishGift", UDim2.fromOffset(72, 72))
	gift.AnchorPoint = Vector2.new(0.5, 0)
	gift.Position = UDim2.new(0.5, 0, 0, 82)
	local line = UIKit.label(made, own.tourGift or labels.tourGift, Enum.Font.FredokaOne, 19, ink)
	line.Position = UDim2.fromOffset(0, 156)
	line.Size = UDim2.new(1, 0, 0, 24)
	line.TextXAlignment = Enum.TextXAlignment.Center
	local keep = UIKit.button(made, labels.keepGoing, UIKit.Colors.Success)
	keep.Name = "Keep"
	keep.AnchorPoint = Vector2.new(0, 1)
	keep.Position = UDim2.new(0, 16, 1, -14)
	keep.Size = UDim2.fromOffset(190, 52)
	keep.Font = Enum.Font.FredokaOne
	keep.TextSize = 22
	local skipTour = UIKit.button(made, labels.skipYes, CARD_GREY)
	skipTour.Name = "ReallySkip"
	skipTour.AnchorPoint = Vector2.new(1, 1)
	skipTour.Position = UDim2.new(1, -16, 1, -16)
	skipTour.Size = UDim2.fromOffset(122, 48)
	skipTour.Font = Enum.Font.FredokaOne
	skipTour.TextSize = 18
	local function close()
		made:Destroy()
		card = nil
	end
	keep.Activated:Connect(function()
		close()
		onKeep()
	end)
	skipTour.Activated:Connect(function()
		close()
		onSkip()
	end)
	card = made
end

-- Tapping the peeking Pish (round 5: he's the Pish button): "Want my shop tour again?" with a big green Yes and a
-- small grey Not now, so a stray tap never restarts it; `extra` adds a wide button above them (Chikin's fight lesson)
function TutorialCues.askReplay(onYes: () -> (), extra: { label: string, onTap: () -> () }?)
	if askCard and askCard.Parent then
		return
	end
	local labels = PishTalk.LABELS
	local made = Instance.new("Frame")
	made.Name = "AskReplay"
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	made.Position = UDim2.fromScale(0.5, 0.5)
	made.Size = UDim2.fromOffset(ASK_SIZE.X, ASK_SIZE.Y + (if extra then ASK_EXTRA else 0))
	made.ZIndex = 40
	made.Parent = gui()
	UIKit.creamWindow(made)
	local ink = UIKit.colorsFor(made).ink
	local face = Icon.make(made, "Paw", UDim2.fromOffset(34, 34))
	face.Position = UDim2.fromOffset(16, 16)
	local line = UIKit.label(made, labels.replayAsk, Enum.Font.FredokaOne, 22, ink)
	line.Position = UDim2.fromOffset(58, 16)
	line.Size = UDim2.new(1, -74, 0, 34)
	local yes = UIKit.button(made, labels.replayYes, UIKit.Colors.Success)
	yes.Name = "Yes"
	yes.AnchorPoint = Vector2.new(0, 1)
	yes.Position = UDim2.new(0, 16, 1, -16)
	yes.Size = UDim2.fromOffset(170, 52)
	yes.Font = Enum.Font.FredokaOne
	yes.TextSize = 22
	local no = UIKit.button(made, labels.replayNo, CARD_GREY)
	no.Name = "No"
	no.AnchorPoint = Vector2.new(1, 1)
	no.Position = UDim2.new(1, -16, 1, -18)
	no.Size = UDim2.fromOffset(112, 48)
	no.Font = Enum.Font.FredokaOne
	no.TextSize = 18
	local function close()
		made:Destroy()
		askCard = nil
	end
	yes.Activated:Connect(function()
		close()
		onYes()
	end)
	no.Activated:Connect(close)
	if extra then
		local other = UIKit.button(made, extra.label, UIKit.Colors.Accent)
		other.Name = "Extra"
		other.Position = UDim2.fromOffset(16, 60)
		other.Size = UDim2.new(1, -32, 0, 48)
		other.Font = Enum.Font.FredokaOne
		other.TextSize = 20
		other.Activated:Connect(function()
			close()
			extra.onTap()
		end)
	end
	askCard = made
end

function TutorialCues.isTourCardOpen(): boolean
	return card ~= nil and card.Parent ~= nil
end

-- The tour card away (the first visit ended under it)
function TutorialCues.closeTourCard()
	if card then
		card:Destroy()
		card = nil
	end
end

-- The spotlight (round 3, pick A): everything dims but the button Pish points at (his card, the paw and Skip stay
-- above it); nil takes it away. Four dim frames round the button, following it
function TutorialCues.spotlight(target: GuiObject?)
	spotTarget = target
	if spotFrames or not target then
		return
	end
	local frames = {}
	for i = 1, 4 do
		local dim = Instance.new("Frame")
		dim.Name = "Dim" .. i
		dim.BackgroundColor3 = DIM_COLOR
		dim.BackgroundTransparency = DIM_TRANSPARENCY
		dim.BorderSizePixel = 0
		dim.ZIndex = 15
		dim.Active = false
		dim.Visible = false
		dim.Parent = gui()
		table.insert(frames, dim)
	end
	spotFrames = frames
	-- The hole in the button's shape: the four dims leave a box; inside it (clipped to it) a thick outline in the dim's
	-- colour fills the box's corners round the button's own rounding
	local box = Instance.new("Frame")
	box.Name = "DimCorners"
	box.BackgroundTransparency = 1
	box.ClipsDescendants = true
	box.ZIndex = 15
	box.Active = false
	box.Visible = false
	box.Parent = gui()
	local shape = Instance.new("Frame")
	shape.BackgroundTransparency = 1
	shape.Size = UDim2.fromScale(1, 1)
	shape.ZIndex = 15
	shape.Parent = box
	local shapeCorner = Instance.new("UICorner")
	shapeCorner.Parent = shape
	local shapeStroke = Instance.new("UIStroke")
	shapeStroke.Color = DIM_COLOR
	shapeStroke.Transparency = DIM_TRANSPARENCY
	shapeStroke.Parent = shape
	RunService.RenderStepped:Connect(function()
		local current = spotTarget
		local shown = current ~= nil and current.Parent ~= nil and current.Visible and current.AbsoluteSize.X > 0
		for _, dim in frames do
			dim.Visible = shown
		end
		box.Visible = shown
		if not shown or not current then
			return
		end
		-- The whole screen, the top bar and a phone's notch bands too, but the button
		local screen = gui()
		local origin = screen.AbsolutePosition
		local hole = {
			x = current.AbsolutePosition.X - origin.X - SPOT_PAD,
			y = current.AbsolutePosition.Y - origin.Y - SPOT_PAD,
			w = current.AbsoluteSize.X + SPOT_PAD * 2,
			h = current.AbsoluteSize.Y + SPOT_PAD * 2,
		}
		for index, rect in ScreenEdges.around(ScreenCover.rect(screen), hole) do
			frames[index].Position = UDim2.fromOffset(rect.x, rect.y)
			frames[index].Size = UDim2.fromOffset(rect.w, rect.h)
		end
		local _, spotCorner, spotScale = shapeOf(current)
		local radius = CueShape.radius({ w = current.AbsoluteSize.X, h = current.AbsoluteSize.Y }, spotCorner, SPOT_PAD, 0, spotScale)
		box.Position = UDim2.fromOffset(hole.x, hole.y)
		box.Size = UDim2.fromOffset(hole.w, hole.h)
		shapeCorner.CornerRadius = UDim.new(0, radius)
		shapeStroke.Thickness = radius -- reaches the box's corners (they are radius * 0.42 away)
	end)
end

-- A burst of sparkles at a point (a step done)
function TutorialCues.sparkle(at: Vector3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = at
	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
	burst.LightEmission = 1
	burst.Size = NumberSequence.new(0.5, 0)
	burst.Lifetime = NumberRange.new(0.5, 0.9)
	burst.Speed = NumberRange.new(6, 12)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.Parent = anchor
	anchor.Parent = workspace
	burst:Emit(30)
	task.delay(1.5, function()
		anchor:Destroy()
	end)
end

-- The cues' screen, for the controller's own pieces (the skip button and card)
function TutorialCues.screen(): ScreenGui
	return gui()
end

-- Who wants the cues hidden now (Pish while an opening, a fight or a weapon reveal has the screen; Chikin keeps his up
-- in a fight): the screen shows while nobody does
local quietBy: { [string]: boolean } = {}
function TutorialCues.quiet(who: string, on: boolean)
	quietBy[who] = if on then true else nil
	gui().Enabled = next(quietBy) == nil
end

return TutorialCues
