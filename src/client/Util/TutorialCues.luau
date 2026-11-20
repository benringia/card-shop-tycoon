--!strict
-- The tutorial's cues (spec 2026-11-09-tutorial-pish-design 5, 6, 14): glowing paw prints on the ground to where to go,
-- a bouncing paw (and a gold ring) over what to tap (a HUD button, a button in a window or a thing in the shop), the
-- small Skip at the top right and the tour card it opens (the step of the tour, the paw row, his gift, Keep going or
-- Skip tour) (Pish's words: Util/TutorialTalk). Each returns a remover, or is set again.
-- Owner 2026-11-21 ("make the highlight more noticeable, also make it fit the shape of what it is highlighting. also
-- make the pawprint more noticeable"; Config/Cues, Util/CueShape): the ring and the spotlight's hole take the button's
-- own corner (a round button gets a round ring), the ring is thicker with a dark line outside it and a second ring
-- pinging outward, and every paw is bigger with a dark backing (and the bouncing one a gold halo).
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PishTalk = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PishTalk"))
local TrailRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("TrailRules"))
local ScreenEdges = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("ScreenEdges"))
local Cues = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Cues"))
local CueShape = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("CueShape"))

local ClientUtil = script.Parent :: Instance
local Icon = require(ClientUtil:WaitForChild("Icon"))
local ScreenCover = require(ClientUtil:WaitForChild("ScreenCover"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

local TutorialCues = {}

local PRINT_GAP = 3 -- studs between paw prints
local PRINT_MAX = 48 -- a walking route to the Wild runs ~300 studs: about one paw every 6
local PRINT_PX = Cues.PRINT.px -- px: a paw print up close (PRINT_NEAR studs away), smaller further off down to PRINT_MIN
local PRINT_NEAR = Cues.PRINT.near
local PRINT_MIN = Cues.PRINT.min
local PAW_SIZE = Cues.PAW.size -- px: the bouncing paw over a button (smaller over a small one, down to PAW_MIN)
local PAW_MIN = Cues.PAW.min
local RING_PAD = Cues.RING.gap + 3 -- px the paw keeps beside a ringed tile (the ring's own pad: shapeOf)
local RING_THICKNESS = Cues.RING.thickness
local BOUNCE = 10 -- px (studs * 0.4 on a thing in the shop)
local BOUNCE_SPEED = 6
local SCROLL_SWIPE = 60 -- px the scroll paw slides down each time
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
local BACKING = Color3.fromRGB(Cues.BACKING[1], Cues.BACKING[2], Cues.BACKING[3])
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

-- Gold paws: white ones vanished against the shop's white walls and light floors
local function tint(icon: Instance, color: Color3)
	for _, image in icon:GetDescendants() do
		if image:IsA("ImageLabel") then
			image.ImageColor3 = color
		end
	end
end

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

-- A gold paw filling `holder` with a dark backing a little bigger behind it (a bare gold one was hard to see on light
-- floors and walls). Returns the paw and its backing.
local function pawIn(holder: GuiObject, rotation: number): (Frame, Frame)
	local back = Icon.make(holder, "Paw", UDim2.fromScale(Cues.PAW.back, Cues.PAW.back))
	back.Name = "Backing"
	back.AnchorPoint = Vector2.new(0.5, 0.5)
	back.Position = UDim2.fromScale(0.5, 0.5)
	back.Rotation = rotation
	tint(back, BACKING)
	local paw = Icon.make(holder, "Paw", UDim2.fromScale(1, 1))
	paw.Rotation = rotation
	paw.ZIndex = back.ZIndex + 1
	tint(paw, GOLD)
	return paw, back
end

-- A soft gold disc behind the bouncing paw, breathing with its bounce
local function haloIn(holder: GuiObject): Frame
	local halo = Instance.new("Frame")
	halo.Name = "Halo"
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromScale(Cues.PAW.halo, Cues.PAW.halo)
	halo.BackgroundColor3 = GOLD
	halo.BackgroundTransparency = Cues.PAW.haloDim
	halo.BorderSizePixel = 0
	halo.ZIndex = 0 -- under the paw and its backing (siblings in the holder)
	halo.Parent = holder
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = halo
	return halo
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

-- Glowing paw prints along the walking route from `from` to `to`, lighting up one after another. Drawn on the screen
-- over the world (owner 2026-11-10: "paw prints are not visible when the door is closed"), smaller further away
function TutorialCues.trail(from: Vector3, to: Vector3): () -> ()
	local holder = Instance.new("Frame")
	holder.Name = "PawTrail"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 5
	holder.Parent = gui()
	local prints: { { at: Vector3, holder: Frame, paw: Frame, back: Frame } } = {}
	local stopped = false
	local connection: RBXScriptConnection? = nil
	task.spawn(function()
		local paws = TrailRules.along(route(from, to), PRINT_GAP, PRINT_MAX)
		if stopped then
			return
		end
		for _, spot in paws do
			local print = Instance.new("Frame")
			print.Name = "Print"
			print.BackgroundTransparency = 1
			print.AnchorPoint = Vector2.new(0.5, 0.5)
			print.Size = UDim2.fromOffset(PRINT_PX, PRINT_PX)
			print.Visible = false
			print.Parent = holder
			local paw, back = pawIn(print, spot.facing)
			table.insert(prints, { at = Vector3.new(spot.x, spot.y + 0.15, spot.z), holder = print, paw = paw, back = back })
		end
		local started = os.clock()
		connection = RunService.RenderStepped:Connect(function()
			local wave = (os.clock() - started) * 6
			for i, entry in prints do
				local point, depth = onScreen(entry.at)
				entry.holder.Visible = point ~= nil
				if point then
					-- the wave passing: each print swells and brightens in turn, never fainter than PRINT.dim
					local glow = 0.5 + 0.5 * math.sin(wave - i * 0.7)
					local size = math.clamp(PRINT_PX * PRINT_NEAR / depth, PRINT_MIN, PRINT_PX) * (0.9 + 0.2 * glow)
					entry.holder.Position = UDim2.fromOffset(point.X, point.Y)
					entry.holder.Size = UDim2.fromOffset(size, size)
					local dim = Cues.PRINT.dim * (1 - glow)
					fade(entry.paw, dim)
					fade(entry.back, 0.2 + dim)
				end
			end
		end)
	end)
	return function()
		stopped = true
		if connection then
			connection:Disconnect()
		end
		holder:Destroy()
	end
end

-- A paw inside a scrolling list's bottom edge, toes down, sliding downward again and again: scroll down (owner
-- 2026-11-16: the paw pointed at a tile out of view)
function TutorialCues.scrollPaw(list: GuiObject): () -> ()
	local started = os.clock()
	local holder = Instance.new("Frame")
	holder.Name = "ScrollPaw"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Size = UDim2.fromOffset(PAW_SIZE, PAW_SIZE)
	holder.ZIndex = 20
	holder.Parent = gui()
	local paw, back = pawIn(holder, 180)
	local connection = RunService.RenderStepped:Connect(function()
		local at, size = list.AbsolutePosition, list.AbsoluteSize
		holder.Visible = list.Parent ~= nil and list.Visible and size.Y > PAW_SIZE * 2
		-- a downward swipe: slides SCROLL_SWIPE px down, fading out at the bottom, then starts again
		local cycle = ((os.clock() - started) * SCROLL_SPEED) % 1
		holder.Position = UDim2.fromOffset(at.X + size.X / 2, at.Y + size.Y - 8 - SCROLL_SWIPE + cycle * SCROLL_SWIPE)
		local gone = if cycle > 0.7 then (cycle - 0.7) / 0.3 else 0
		fade(paw, gone)
		fade(back, gone)
	end)
	return function()
		connection:Disconnect()
		holder:Destroy()
	end
end

-- A bouncing paw pointing down at a HUD button, a button in a window or a thing in the shop; a button also gets a
-- pulsing gold ring round it (in a window full of items the paw alone could pass for one of them)
function TutorialCues.pawOn(target: GuiObject | BasePart): () -> ()
	local started = os.clock()
	if typeof(target) == "Instance" and target:IsA("GuiObject") then
		local holder = Instance.new("Frame")
		holder.Name = "PawPointer"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 1)
		holder.ZIndex = 20
		holder.Parent = gui()
		local paw, back = pawIn(holder, 180) -- toes down, toward the button
		local halo = haloIn(holder)
		-- the gold ring in the button's own shape, a dark line outside it, and a second ring pinging outward
		local ring, corner, stroke = outlineFrame("PawRing", GOLD, RING_THICKNESS, 19)
		local edge, edgeCorner, edgeStroke = outlineFrame("PawRingEdge", EDGE, Cues.RING.edge, 18)
		edgeStroke.Transparency = 0.35
		local ping, pingCorner, pingStroke = outlineFrame("PawPing", GOLD, Cues.PING.thickness, 18)
		local connection = RunService.RenderStepped:Connect(function()
			local elapsed = os.clock() - started
			local beat = math.abs(math.sin(elapsed * BOUNCE_SPEED))
			-- the piece that holds its shape (a tile's face), its corner as drawn, and the ring's place just outside its
			-- own outline
			local piece, pieceCorner, pieceScale, pad = shapeOf(target)
			local at, size = piece.AbsolutePosition, piece.AbsoluteSize
			-- a tile half scrolled out of its list: only the part showing, so the ring and paw stay inside the list
			local list = target:FindFirstAncestorWhichIsA("ScrollingFrame")
			local clipped = false
			if list then
				local top = math.max(at.Y, list.AbsolutePosition.Y)
				local bottom = math.min(at.Y + size.Y, list.AbsolutePosition.Y + list.AbsoluteSize.Y)
				clipped = top > at.Y
				at, size = Vector2.new(at.X, top), Vector2.new(size.X, math.max(0, bottom - top))
			end
			local shown = target.Parent ~= nil and target.Visible and size.X > 0 and size.Y > 0
			local pawSize = math.clamp(size.Y * 0.9, PAW_MIN, PAW_SIZE)
			holder.Visible = shown
			holder.Size = UDim2.fromOffset(pawSize, pawSize)
			-- above it, or just inside its top when that is the list's edge (not over the window's tabs); under it, toes
			-- up, when there's no room above (a button in Roblox's top bar: the town button, owner 2026-11-18)
			local pawBottom = if clipped then at.Y + pawSize + 4 else at.Y - 4
			local under = not clipped and pawBottom - pawSize - BOUNCE < ScreenCover.rect(gui()).y
			-- a tile in the left side column: from its right, toes pointing left (CueShape.pawSide)
			local layer = gui()
			local beside = not clipped and CueShape.pawSide({ x = at.X - layer.AbsolutePosition.X, w = size.X }, layer.AbsoluteSize.X, Cues.PAW.sideShare) == "right"
			paw.Rotation = if beside then -90 elseif under then 0 else 180
			back.Rotation = paw.Rotation
			halo.BackgroundTransparency = Cues.PAW.haloDim + beat * (1 - Cues.PAW.haloDim) * 0.6
			holder.AnchorPoint = if beside then Vector2.new(0, 0.5) else Vector2.new(0.5, if under then 0 else 1)
			if beside then
				holder.Position = UDim2.fromOffset(at.X + size.X + RING_PAD + RING_THICKNESS + 4 + beat * BOUNCE, at.Y + size.Y / 2)
			elseif under then
				holder.Position = UDim2.fromOffset(at.X + size.X / 2, at.Y + size.Y + 4 + beat * BOUNCE)
			else
				holder.Position = UDim2.fromOffset(at.X + size.X / 2, pawBottom - beat * BOUNCE)
			end
			-- the ring: the button's own corner (a tile half out of its list keeps the list's square edge there)
			local radius = CueShape.radius({ w = size.X, h = size.Y }, pieceCorner, pad, Cues.RING.fallback, pieceScale)
			local pulse = Cues.RING.pulse
			ring.Visible = shown
			ring.Position = UDim2.fromOffset(at.X - pad, at.Y - pad)
			ring.Size = UDim2.fromOffset(size.X + pad * 2, size.Y + pad * 2)
			corner.CornerRadius = UDim.new(0, radius)
			stroke.Transparency = pulse[1] + beat * (pulse[2] - pulse[1])
			local out = pad + RING_THICKNESS
			edge.Visible = shown
			edge.Position = UDim2.fromOffset(at.X - out, at.Y - out)
			edge.Size = UDim2.fromOffset(size.X + out * 2, size.Y + out * 2)
			edgeCorner.CornerRadius = UDim.new(0, radius + RING_THICKNESS)
			local grow, gone = CueShape.ping(elapsed, Cues.PING)
			local far = out + grow
			ping.Visible = shown
			ping.Position = UDim2.fromOffset(at.X - far, at.Y - far)
			ping.Size = UDim2.fromOffset(size.X + far * 2, size.Y + far * 2)
			pingCorner.CornerRadius = UDim.new(0, radius + RING_THICKNESS + grow)
			pingStroke.Transparency = gone
		end)
		return function()
			connection:Disconnect()
			holder:Destroy()
			ring:Destroy()
			edge:Destroy()
			ping:Destroy()
		end
	end
	local part = target :: BasePart
	-- On the screen over the world, like the trail: walls and closed doors don't hide it
	local holder = Instance.new("Frame")
	holder.Name = "PawPointer"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Size = UDim2.fromOffset(PAW_SIZE, PAW_SIZE)
	holder.ZIndex = 20
	holder.Parent = gui()
	pawIn(holder, 180)
	local halo = haloIn(holder)
	local connection = RunService.RenderStepped:Connect(function()
		local point = onScreen(part.Position + Vector3.new(0, part.Size.Y / 2 + 0.5, 0))
		holder.Visible = point ~= nil and part.Parent ~= nil
		if point then
			local beat = math.abs(math.sin((os.clock() - started) * BOUNCE_SPEED))
			holder.Position = UDim2.fromOffset(point.X, point.Y - beat * BOUNCE)
			halo.BackgroundTransparency = Cues.PAW.haloDim + beat * (1 - Cues.PAW.haloDim) * 0.6
		end
	end)
	return function()
		connection:Disconnect()
		holder:Destroy()
	end
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
