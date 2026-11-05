--!strict
-- The finished Pet button moves' looks (spec 2026-11-05-pet-moves-design): Healing Rain, Vine Snare, Overcharge and
-- Curse, each bigger and richer with the creature's grade (Config/MoveFx; the grade that plays is picked by
-- Util/MoveFxRules in Util/FightFx, which calls these from the sim's events). Built from parts, beams and particles in
-- workspace.FightFx; every look cleans itself up, and the lasting ones return a stop.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("Config"):WaitForChild("AttackFx"))
local MoveFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("MoveFx"))
local MoveFxRules = require(Shared:WaitForChild("Util"):WaitForChild("MoveFxRules"))
local SoundLevels = require(Shared:WaitForChild("Config"):WaitForChild("SoundLevels"))
local SoundLevel = require(Shared:WaitForChild("Util"):WaitForChild("SoundLevel"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))
local ScreenFx = require((script.Parent :: Instance):WaitForChild("ScreenFx"))
local SoundBank = require((script.Parent :: Instance):WaitForChild("SoundBank"))

export type View = { root: BasePart, element: string, height: number, grade: string?, mine: boolean }

local MoveFx = {}

local WHITE = Color3.new(1, 1, 1)

local function rgb(list: { number }): Color3
	return Color3.fromRGB(list[1], list[2], list[3])
end

local function folder(): Folder
	local existing = workspace:FindFirstChild("FightFx")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "FightFx"
	made.Parent = workspace
	return made
end

-- An anchored, untouchable part in the effects folder
local function part(size: Vector3, color: Color3, at: CFrame, transparency: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = at
	p.Transparency = transparency or 0
	p.Parent = folder()
	return p
end

-- A looping or one-shot sound on `parent` (MoveFx SOUNDS; the fight sounds' volume and a little pitch spread)
local function sound(parent: Instance, id: string?, volume: number, looped: boolean?): Sound?
	if not id or id == "" then
		return nil
	end
	local s = SoundBank.make(id)
	s.Volume = AttackFx.VOLUME * volume * SoundLevel.gain(SoundLevels, id) -- loud ones brought down (Config/SoundLevels)
	s.PlaybackSpeed = 0.95 + math.random() * 0.1
	s.Looped = looped == true
	s.RollOffMaxDistance = 140
	s.Parent = parent
	s:Play()
	return s
end

-- Something that follows a moving creature every frame until it stops (a cloud over it, orbs round it)
local function follow(root: BasePart, step: (root: BasePart, dt: number) -> ()): () -> ()
	local connection = RunService.RenderStepped:Connect(function(dt)
		if root.Parent then
			step(root, dt)
		end
	end)
	return function()
		connection:Disconnect()
	end
end

-- Emitters stop, lights dim, sounds fade; then everything goes
local function fadeOut(items: { Instance }, seconds: number)
	for _, item in items do
		for _, child in item:GetDescendants() do
			if child:IsA("ParticleEmitter") then
				child.Rate = 0
			elseif child:IsA("Light") then
				TweenService:Create(child, TweenInfo.new(seconds), { Brightness = 0 }):Play()
			elseif child:IsA("Sound") then
				TweenService:Create(child, TweenInfo.new(seconds), { Volume = 0 }):Play()
			elseif child:IsA("Beam") then
				TweenService:Create(child, TweenInfo.new(seconds), { Width0 = 0, Width1 = 0 }):Play()
			end
		end
		Debris:AddItem(item, seconds + 1.2)
	end
end

-- A rising number over a creature (a heal tick): plain ASCII, its colour and size by grade
local function riseText(at: Vector3, text: string, color: Color3, scale: number)
	local anchor = part(Vector3.new(0.2, 0.2, 0.2), WHITE, CFrame.new(at), 1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(math.round(90 * scale), math.round(36 * scale))
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.35
	label.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(at + Vector3.new(0, 2.6, 0)) }):Play()
	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1.1)
end

-- ===================================================================================================================
-- Healing Rain (Tide)

-- The cloud's puffs: x, y, z offsets and diameter, as shares of its width
local PUFFS = {
	{ -0.3, 0, 0, 0.5 },
	{ -0.08, 0.14, 0, 0.62 },
	{ 0.17, 0.08, 0.04, 0.55 },
	{ 0.36, -0.03, 0, 0.42 },
	{ 0.02, -0.06, 0.16, 0.5 },
	{ 0.05, -0.04, -0.16, 0.5 },
}

-- A rain cloud over a creature for `seconds`: rain falling on it, a soft glow round it, and by grade ripples at its
-- feet (B), rising healing motes (A) and water rings plus a rainbow over the cloud (S). Returns a stop.
function MoveFx.rain(view: View, grade: string, seconds: number, sounds: boolean?): () -> ()
	local look = MoveFxConfig.RAIN[grade]
	local root = view.root
	local height = math.max(view.height, 2)
	local above = height + 2.6 -- the cloud's height over the creature's feet (a fight view's root is at its feet)
	local cloudColor = rgb(look.cloudColor)
	local water = Color3.fromRGB(125, 211, 252)
	local heal = Color3.fromRGB(110, 231, 183)
	local items: { Instance } = {}

	-- The cloud: a cartoon cloud of round puffs (grey and small at C, bright white at S), popping in. `cloud` is an
	-- invisible slab at its base that the rain hangs from
	local width = look.cloud * math.clamp(height / 3, 0.8, 2.5) -- bigger over a bigger creature
	local cloud = part(Vector3.new(width * 0.8, 0.4, width * 0.4), cloudColor, CFrame.new(root.Position + Vector3.new(0, above, 0)), 1)
	table.insert(items, cloud)
	local puffs: { { part: Part, offset: Vector3 } } = {}
	for _, puff in PUFFS do
		local size = puff[4] * width
		local ball = part(Vector3.one * 0.05, cloudColor, cloud.CFrame, 0)
		ball.Shape = Enum.PartType.Ball
		ball.Material = Enum.Material.SmoothPlastic
		table.insert(items, ball)
		table.insert(puffs, { part = ball, offset = Vector3.new(puff[1], puff[2] + 0.35, puff[3]) * width })
		TweenService:Create(ball, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = Vector3.one * size }):Play()
	end
	if grade == "A" or grade == "S" then
		-- A silver lining (A), a soft glow (S)
		local sheen = Instance.new("PointLight")
		sheen.Color = Color3.fromRGB(224, 242, 254)
		sheen.Range = width * 1.6
		sheen.Brightness = look.glow * 0.8
		sheen.Shadows = false
		sheen.Parent = cloud
	end

	-- The healing glow round it, and what grows with grade at its feet
	local feet = part(Vector3.new(0.2, 0.2, 0.2), WHITE, CFrame.new(root.Position + Vector3.new(0, 0.15, 0)), 1)
	table.insert(items, feet)

	-- The rain: thin falling streaks (beams from the cloud to the ground with the drop texture scrolling down them),
	-- more and thicker with grade
	local streams = math.max(3, math.round(look.drops / 5))
	for _ = 1, streams do
		local angle = math.random() * math.pi * 2
		local reach = width * 0.36 * math.sqrt(math.random())
		local offset = Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach * 0.6)
		local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
		top.Position = offset
		bottom.Position = offset
		top.Parent = cloud
		bottom.Parent = feet
		local stream = Instance.new("Beam")
		stream.Attachment0 = top
		stream.Attachment1 = bottom
		stream.Texture = MoveFxConfig.TEXTURES.raindrop
		stream.TextureMode = Enum.TextureMode.Static
		stream.TextureLength = 1.1 + math.random() * 0.8
		stream.TextureSpeed = -(2.2 + math.random() * 1.2)
		stream.Width0 = look.drop * 9
		stream.Width1 = look.drop * 9
		stream.Color = ColorSequence.new(water:Lerp(WHITE, 0.35))
		stream.LightEmission = 1
		stream.Brightness = 3
		stream.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.12, 0.1),
			NumberSequenceKeypoint.new(0.9, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		stream.FaceCamera = true
		stream.Segments = 1
		stream.Parent = cloud
	end

	local glow = Instance.new("PointLight")
	glow.Color = heal
	glow.Range = 6 + height
	glow.Brightness = look.glow
	glow.Shadows = false
	glow.Parent = feet
	local halo = ElementFx.emitter(feet, "glow", heal, { size = { height * 1.1, height * 1.3 }, life = 0.7, locked = true, brightness = look.glow, fade = 0.4, start = 0.45 })
	halo.Rate = 2.5
	if look.ripple then
		local ripples = ElementFx.emitter(feet, "ring", water, { size = { 0.5, height * 1.4 }, life = 0.8, speed = 0.01, rotation = 0,
			orientation = Enum.ParticleOrientation.VelocityPerpendicular, fade = 0.2, brightness = 1.4 })
		ripples.Rate = 2.5
	end
	if look.motes then
		local motes = ElementFx.emitter(feet, "spark", heal, { size = { 0.35, 0.1 }, life = { 1, 1.4 }, speed = { 3, 5 }, spread = 25,
			rotation = 0, brightness = 2, fade = 0.5 })
		motes.Rate = 10
	end
	if look.rings then
		local rings = ElementFx.emitter(feet, "ring", water, { size = { height * 1.2, height * 0.7 }, life = 1.1, speed = { 4, 4 },
			rotation = 0, orientation = Enum.ParticleOrientation.VelocityPerpendicular, fade = 0.3, brightness = 1.8 })
		rings.Rate = 2.8
	end
	if look.rainbow then
		-- Five thin coloured arcs rising over the cloud (their attachments' axes point up, so the beams bow upward)
		local colors = { { 248, 113, 113 }, { 251, 191, 36 }, { 74, 222, 128 }, { 96, 165, 250 }, { 167, 139, 250 } }
		for index, color in colors do
			local span = width * 0.62 - (index - 1) * 0.22
			local left, right = Instance.new("Attachment"), Instance.new("Attachment")
			left.Position = Vector3.new(-span, width * 0.15, -width * 0.1)
			right.Position = Vector3.new(span, width * 0.15, -width * 0.1)
			left.Axis = Vector3.yAxis
			right.Axis = Vector3.yAxis
			left.Parent = cloud
			right.Parent = cloud
			local arc = Instance.new("Beam")
			arc.Attachment0 = left
			arc.Attachment1 = right
			arc.CurveSize0 = span * 1.25
			arc.CurveSize1 = -span * 1.25
			arc.Width0 = 0.24
			arc.Width1 = 0.24
			arc.Color = ColorSequence.new(rgb(color))
			arc.LightEmission = 0.25
			arc.Transparency = NumberSequence.new(0.2)
			arc.FaceCamera = true
			arc.Segments = 20
			arc.Parent = cloud
		end
	end

	local looks = MoveFxConfig.SOUNDS.Rain
	if sounds ~= false then
		sound(cloud, looks.cast, 0.8)
		sound(cloud, looks.loop, 0.55, true)
		if grade == "A" or grade == "S" then
			sound(cloud, looks.layer, 0.35, true)
		end
	end

	local unfollow = follow(root, function(at)
		cloud.CFrame = CFrame.new(at.Position + Vector3.new(0, above, 0))
		for _, puff in puffs do
			puff.part.CFrame = cloud.CFrame + puff.offset
		end
		feet.CFrame = CFrame.new(at.Position + Vector3.new(0, 0.15, 0))
	end)
	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		unfollow()
		for _, puff in puffs do
			TweenService:Create(puff.part, TweenInfo.new(0.5), { Transparency = 1, Size = puff.part.Size * 0.6 }):Play()
		end
		fadeOut(items, 0.6)
	end
	task.delay(seconds, stop)
	return stop
end

-- One Healing Rain tick on a creature: a rising "+N" (green, gold at S, bigger with grade), a soft chime and a pulse
function MoveFx.rainTick(view: View, grade: string, amount: number)
	local look = MoveFxConfig.RAIN[grade]
	local top = view.root.Position + Vector3.new((math.random() - 0.5) * 1.2, math.max(view.height, 2) * 1.05, 0)
	riseText(top, `+{math.round(amount)}`, rgb(look.tickColor), look.tick)
	local pulse = part(Vector3.new(0.2, 0.2, 0.2), WHITE, CFrame.new(view.root.Position + Vector3.new(0, view.height * 0.5, 0)), 1)
	ElementFx.emitter(pulse, "glow", Color3.fromRGB(110, 231, 183), { size = { view.height * 0.8, view.height * 1.6 * look.tick }, life = 0.45, brightness = look.glow * 1.4, fade = 0.3 }):Emit(1)
	Debris:AddItem(pulse, 1)
	sound(pulse, MoveFxConfig.SOUNDS.Rain.tick, 0.5)
end

-- ===================================================================================================================
-- Vine Snare (Bloom)

local VINE_STEPS = 10 -- stem pieces per vine, bottom to top
local VINE_GROW = 0.4 -- seconds a vine takes to climb
local VINE_WITHER = 0.6 -- seconds it takes to wither at the end
local BROWN = Color3.fromRGB(110, 78, 46)

-- The ground under a point (terrain or parts below it), else `fallback`
local function groundUnder(at: Vector3, fallback: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder() }
	local hit = workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position.Y else fallback
end

-- Vines (C, B) or thorny roots (A, S) bursting out of the ground under a target and climbing round it for `seconds`,
-- then withering: by grade more and thicker, leaves (B), thorns and a spray of dirt (A), a glowing crack, flowers and
-- pollen (S). `target` is the foe's root part, `height` its height. Returns a stop.
function MoveFx.vines(target: BasePart, height: number, grade: string, seconds: number): () -> ()
	local look = MoveFxConfig.VINES[grade]
	local tall = math.max(height, 2)
	local centre = target.Position
	-- Wrap the foe's real body (its model's box), not a share of its height: bulky foes hid vines sized by height
	local model = target:FindFirstAncestorOfClass("Model")
	local halfWidth: number? = nil
	if model then
		local box, size = model:GetBoundingBox()
		centre = Vector3.new(box.Position.X, centre.Y, box.Position.Z)
		halfWidth = math.max(size.X, size.Z) / 2
	end
	local groundY = groundUnder(centre, centre.Y - tall * 0.5)
	local base = Vector3.new(centre.X, groundY, centre.Z)
	local radius = MoveFxRules.wrapRadius(halfWidth, tall)
	local thick = look.thickness * math.clamp(tall / 5, 1, 1.7) -- thicker on a big foe, but never a wall of green
	local color = rgb(look.color)
	local woody = grade == "A" or grade == "S"
	local items: { Instance } = {}
	local holder = part(Vector3.new(0.2, 0.2, 0.2), WHITE, CFrame.new(base), 1)
	table.insert(items, holder)

	-- The vines: solid tapering stems (lit, not flat ribbons; the owner: "make the vines more visible"), a rounded joint
	-- at each bend, climbing piece by piece. On a foe wider than it is tall they wind fewer times, so they climb it
	-- rather than ring it like a cage
	local stopped = false
	local segments: { Part } = {}
	local tips: { Vector3 } = {} -- points along the vines, for leaves, thorns and flowers
	local material = if woody then Enum.Material.Wood else Enum.Material.SmoothPlastic
	local turns = look.turns * math.clamp(tall * look.reach / (radius * 2.2), 0.45, 1)
	for index = 1, look.count do
		local path = MoveFxRules.vinePath(index, look.count, tall * look.reach, radius, turns, VINE_STEPS)
		for step = 2, #path do
			local p0, p1 = path[step - 1], path[step]
			local from = base + Vector3.new(p0.x, p0.y + 0.1, p0.z)
			local to = base + Vector3.new(p1.x, p1.y + 0.1, p1.z)
			local share = (step - 2) / VINE_STEPS
			local width = thick * (1 - share * 0.5)
			local stem = part(Vector3.new((to - from).Magnitude + width * 0.3, width, width), color, CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0), 1)
			stem.Shape = Enum.PartType.Cylinder
			stem.Material = material
			local joint = part(Vector3.one * width, color, CFrame.new(to), 1)
			joint.Shape = Enum.PartType.Ball
			joint.Material = material
			for _, piece in { stem, joint } do
				table.insert(items, piece)
				table.insert(segments, piece)
			end
			if step % 3 == 0 then
				table.insert(tips, to)
			end
			-- It climbs: each piece appears as the vine reaches it
			task.delay(VINE_GROW * share, function()
				if not stopped then
					stem.Transparency = 0
					joint.Transparency = 0
				end
			end)
		end
	end

	-- Leaves, thorns and flowers along the vines once they've climbed
	local function dot(shape: Enum.PartType, size: Vector3, tint: Color3, at: Vector3, material: Enum.Material?)
		local piece = part(Vector3.one * 0.05, tint, CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6), 0)
		piece.Shape = shape
		piece.Material = material or Enum.Material.SmoothPlastic
		table.insert(items, piece)
		task.delay(VINE_GROW, function()
			TweenService:Create(piece, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = size }):Play()
		end)
		return piece
	end
	local leafSize = math.clamp(thick * 1.3, 0.6, 2)
	for index = 1, look.leaves do
		local at = tips[(index * 3) % #tips + 1]
		dot(Enum.PartType.Block, Vector3.new(leafSize, leafSize * 0.12, leafSize * 0.6), Color3.fromRGB(134, 239, 172), at)
	end
	for index = 1, look.thorns do
		local at = tips[(index * 5 + 2) % #tips + 1]
		dot(Enum.PartType.Block, Vector3.new(0.25, 0.9, 0.25) * math.min(thick, 1.6), Color3.fromRGB(231, 229, 228), at)
	end
	for index = 1, look.blossoms do
		local at = tips[(index * 7 + 1) % #tips + 1]
		local bloom = math.clamp(thick * 0.9, 0.5, 1.6)
		dot(Enum.PartType.Ball, Vector3.one * bloom, Color3.fromRGB(249, 168, 212), at)
		dot(Enum.PartType.Ball, Vector3.one * bloom * 0.4, Color3.fromRGB(253, 224, 71), at + Vector3.new(0, bloom * 0.3, 0), Enum.Material.Neon)
	end

	-- The ground breaking: dirt flying (A), a glowing crack and pollen (S)
	if look.dirt then
		local chunks = ElementFx.emitter(holder, "shard", BROWN, { size = { thick * 0.6, thick * 0.3 }, life = { 0.6, 0.9 }, speed = { 8, 14 },
			spread = 55, rotation = { 0, 360 }, spin = { -200, 200 }, accel = Vector3.new(0, -40, 0), light = 0, brightness = 1, fade = 0.7 })
		chunks:Emit(if grade == "S" then 22 else 14)
	end
	if look.crack then
		local crack = part(Vector3.new(0.1, radius * 3.2, radius * 3.2), Color3.fromRGB(74, 222, 128), CFrame.new(base + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)), 0.45)
		crack.Shape = Enum.PartType.Cylinder
		table.insert(items, crack)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(74, 222, 128)
		light.Range = radius * 4
		light.Brightness = 1.5
		light.Shadows = false
		light.Parent = crack
	end
	if look.pollen then
		local pollen = ElementFx.emitter(holder, "spark", Color3.fromRGB(253, 230, 138), { size = { 0.3, 0.1 }, life = { 1.2, 1.8 }, speed = { 1, 2.5 },
			spread = 60, rotation = 0, brightness = 2, fade = 0.5 })
		pollen.Rate = 14
	end

	local sounds = MoveFxConfig.SOUNDS.Snare
	sound(holder, sounds.burst, 0.9)
	sound(holder, sounds.wrap, 0.6)
	sound(holder, sounds.creak, 0.5)
	if woody then
		sound(holder, sounds.layer, 0.6)
	end

	local function stop()
		if stopped then
			return
		end
		stopped = true
		for _, piece in segments do
			TweenService:Create(piece, TweenInfo.new(VINE_WITHER * 0.5), { Color = BROWN }):Play()
		end
		for _, item in items do
			if item:IsA("BasePart") and item ~= holder then
				TweenService:Create(item, TweenInfo.new(VINE_WITHER), { Transparency = 1, CFrame = item.CFrame - Vector3.new(0, thick, 0) }):Play()
			end
		end
		fadeOut(items, VINE_WITHER)
	end
	task.delay(math.max(0, seconds - VINE_WITHER), stop)
	return stop
end

-- ===================================================================================================================
-- Overcharge (Volt)

export type OrbSet = {
	view: View,
	grade: string,
	orbs: { Part },
	items: { Instance },
	unfollow: () -> (),
	done: boolean,
}

-- Three electric orbs circling a creature (one per Overcharge fast attack): bigger, brighter, faster with grade, sparks
-- jumping between them (A) and a crackling ring at its feet (S), humming while any remain
function MoveFx.orbs(view: View, grade: string): OrbSet
	local look = MoveFxConfig.ORBS[grade]
	local root = view.root
	local tall = math.max(view.height, 2)
	local scale = math.clamp(tall / 3, 0.8, 2.2)
	local radius = math.max(1.2, look.radius * tall)
	local color, core = rgb(look.color), rgb(look.core)
	local items: { Instance } = {}
	local orbs: { Part } = {}
	for _ = 1, 3 do
		local orb = part(Vector3.one * 0.05, core, CFrame.new(root.Position), 0)
		orb.Shape = Enum.PartType.Ball
		local halo = ElementFx.emitter(orb, "glow", color, { size = { look.size * scale * 2.6, look.size * scale * 3 }, life = 0.25, locked = true, brightness = 1.5 + look.glow, fade = 0.4 })
		halo.Rate = 14
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 4 + look.size * 6
		light.Brightness = look.light
		light.Shadows = false
		light.Parent = orb
		TweenService:Create(orb, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = Vector3.one * look.size * scale }):Play()
		table.insert(orbs, orb)
		table.insert(items, orb)
	end
	-- Sparks jumping orb to orb (A, S): bolt beams that flicker
	local arcs: { Beam } = {}
	if look.arcs then
		for index, orb in orbs do
			local nextOrb = orbs[index % #orbs + 1]
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Parent = orb
			a1.Parent = nextOrb
			local arc = Instance.new("Beam")
			arc.Attachment0 = a0
			arc.Attachment1 = a1
			arc.Texture = AttackFx.TEXTURES.bolt
			arc.TextureMode = Enum.TextureMode.Stretch
			arc.Width0 = 0.5 * scale
			arc.Width1 = 0.5 * scale
			arc.Color = ColorSequence.new(color:Lerp(WHITE, 0.4))
			arc.LightEmission = 1
			arc.Brightness = 3
			arc.FaceCamera = true
			arc.Parent = orb
			table.insert(arcs, arc)
		end
	end
	local feet = part(Vector3.new(0.2, 0.2, 0.2), WHITE, CFrame.new(root.Position + Vector3.new(0, 0.15, 0)), 1)
	table.insert(items, feet)
	if look.ring then
		local ring = ElementFx.emitter(feet, "ring", color, { size = { radius * 2.2, radius * 2.4 }, life = 0.3, speed = 0.01, rotation = { 0, 360 },
			orientation = Enum.ParticleOrientation.VelocityPerpendicular, brightness = 2.5, fade = 0.3 })
		ring.Rate = 8
		local crackle = ElementFx.emitter(feet, "spark", color, { size = { 0.5, 0.15 }, life = 0.25, speed = { 6, 10 }, spread = 80, rotation = 0,
			orientation = Enum.ParticleOrientation.VelocityParallel, brightness = 2.5 })
		crackle.Rate = 20
	end
	local sounds = MoveFxConfig.SOUNDS.Overcharge
	sound(feet, sounds.cast, 0.8)
	sound(feet, sounds.hum, 0.35, true)

	local angle = math.random() * math.pi * 2
	local flicker = 0
	local set: OrbSet
	local unfollow = follow(root, function(at, dt)
		angle += look.spin * 2 * math.pi * dt
		local middle = at.Position + Vector3.new(0, tall * 0.55, 0)
		for index, orb in set.orbs do
			local a = angle + (index - 1) * 2 * math.pi / 3
			orb.CFrame = CFrame.new(middle + Vector3.new(math.cos(a) * radius, math.sin(a * 2) * radius * 0.18, math.sin(a) * radius))
		end
		feet.CFrame = CFrame.new(at.Position + Vector3.new(0, 0.15, 0))
		flicker += dt
		if flicker > 0.07 then
			flicker = 0
			for _, arc in arcs do
				arc.Enabled = math.random() < 0.75
				arc.CurveSize0 = (math.random() - 0.5) * 1.5
				arc.CurveSize1 = (math.random() - 0.5) * 1.5
			end
		end
	end)
	set = { view = view, grade = grade, orbs = orbs, items = items, unfollow = unfollow, done = false }
	return set
end

-- All the orbs left fade and the hum stops (the fast attacks are over, or the creature left)
function MoveFx.clearOrbs(set: OrbSet)
	if set.done then
		return
	end
	set.done = true
	set.unfollow()
	for _, orb in set.orbs do
		TweenService:Create(orb, TweenInfo.new(0.3), { Size = Vector3.one * 0.05, Transparency = 1 }):Play()
	end
	fadeOut(set.items, 0.3)
end

-- One orb spent by a fast attack: it flies to the target and bursts there (with a bolt at A, a thunderbolt from the sky
-- at S); `mine` adds a flash on your screen at S
function MoveFx.spendOrb(set: OrbSet, target: Vector3, mine: boolean)
	local orb = table.remove(set.orbs, 1)
	if not orb then
		return
	end
	local look = MoveFxConfig.ORBS[set.grade]
	local color = rgb(look.color)
	local scale = math.clamp(math.max(set.view.height, 2) / 3, 0.8, 2.2)
	local from = orb.Position
	orb:Destroy()
	local sounds = MoveFxConfig.SOUNDS.Overcharge
	ElementFx.projectile(from, function()
		return target
	end, color, 0.16, 0.6, function(at)
		ElementFx.burst(at, color, look.size * scale * 1.6)
		if look.bolt then
			ElementFx.bolt(from, at, color, 0.18, look.size * 1.5)
		end
		if look.flash then
			ElementFx.skyStrike(at, color, look.size * 1.4)
			ElementFx.sound(sounds.thunder, at, 0.55)
			if mine then
				ScreenFx.flash(color, 0.35, 0.18)
			end
		end
		ElementFx.sound(sounds.zap, at, 0.8)
	end, { scale = look.size * scale * 1.5, sparkle = look.flash })
	if #set.orbs == 0 then
		MoveFx.clearOrbs(set)
	end
end

-- An orb whose fast attack was missed (stunned): it pops where it is
function MoveFx.fizzleOrb(set: OrbSet)
	local orb = table.remove(set.orbs, 1)
	if not orb then
		return
	end
	local look = MoveFxConfig.ORBS[set.grade]
	ElementFx.burst(orb.Position, rgb(look.color), look.size * 0.6)
	orb:Destroy()
	if #set.orbs == 0 then
		MoveFx.clearOrbs(set)
	end
end

-- ===================================================================================================================
-- Curse (Shade)

local SHADOW = Color3.fromRGB(46, 16, 101)

-- A flat image on the ground at `at`, `size` studs across, its texture tinted and glowing; returns the part and label
local function groundImage(at: Vector3, size: number, image: string, color: Color3, brightness: number): (Part, ImageLabel)
	local disc = part(Vector3.new(size, 0.05, size), WHITE, CFrame.new(at), 1)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(512, 512)
	gui.LightInfluence = 0
	gui.Brightness = brightness
	gui.Parent = disc
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.3, 0.3)
	label.Image = image
	label.ImageColor3 = color
	label.ImageTransparency = 1
	label.Parent = gui
	return disc, label
end

-- The rune circle opening under the caster as it casts a Curse (a seven-point star in rings, spinning): bigger and
-- brighter with grade, a second ring turning the other way (A), a third and violet flames (S)
function MoveFx.curseCircle(view: View, grade: string, seconds: number)
	local look = MoveFxConfig.CURSE[grade]
	local color = rgb(look.color)
	local at = view.root.Position + Vector3.new(0, 0.08, 0)
	local size = look.circle * math.clamp(view.height / 3, 0.8, 2.2)
	local items: { Instance } = {}
	local labels: { { label: ImageLabel, spin: number } } = {}
	local disc, rune = groundImage(at, size, MoveFxConfig.TEXTURES.rune, color, 1.5 + look.aura * 2)
	table.insert(items, disc)
	table.insert(labels, { label = rune, spin = look.spin * 360 })
	for ring = 2, look.rings do
		local outer, label = groundImage(at, size * (1 + 0.16 * (ring - 1)), AttackFx.TEXTURES.ring, color, 2)
		table.insert(items, outer)
		table.insert(labels, { label = label, spin = -look.spin * 360 * ring * 0.7 })
	end
	for _, entry in labels do
		TweenService:Create(entry.label, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.fromScale(1, 1), ImageTransparency = 0 }):Play()
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = size * 1.4
	light.Brightness = 1 + look.aura * 2
	light.Shadows = false
	light.Parent = disc
	if look.flames then
		local flames = ElementFx.emitter(disc, "flame", Color3.fromRGB(192, 38, 211), { size = { size * 0.12, size * 0.04 }, life = { 0.5, 0.8 }, speed = { 3, 5 },
			rotation = { -10, 10 }, brightness = 2.2, fade = 0.4 })
		flames.Rate = 40
	end
	sound(disc, MoveFxConfig.SOUNDS.Curse.swell, 0.8)
	local spinning = RunService.RenderStepped:Connect(function(dt)
		for _, entry in labels do
			entry.label.Rotation += entry.spin * dt
		end
	end)
	task.delay(seconds, function()
		for _, entry in labels do
			TweenService:Create(entry.label, TweenInfo.new(0.4), { ImageTransparency = 1 }):Play()
		end
		fadeOut(items, 0.4)
		task.delay(0.45, function()
			spinning:Disconnect()
		end)
	end)
end

-- The curse landing on a target for `seconds`: a hex flying across (B), shadow chains hooking it (A), then a big curse
-- sigil over it, a dark aura and smoke round it (A), the target darkened, a low drone. Returns a stop (the target died,
-- or the fight ended).
function MoveFx.curse(caster: Vector3, target: BasePart, height: number, grade: string, seconds: number): () -> ()
	local look = MoveFxConfig.CURSE[grade]
	local color = rgb(look.color)
	local tall = math.max(height, 2)
	local model = target:FindFirstAncestorOfClass("Model")
	local top = target.Position.Y + tall * 0.5
	if model then
		local box, boxSize = model:GetBoundingBox()
		top = box.Position.Y + boxSize.Y / 2
	end
	local above = top - target.Position.Y -- the target's top over its root
	local middle = target.Position + Vector3.new(0, above - tall * 0.5, 0)
	local items: { Instance } = {}
	local sounds = MoveFxConfig.SOUNDS.Curse
	local delay = 0
	if look.hex then
		delay = 0.25
		ElementFx.projectile(caster, function()
			return middle
		end, Color3.fromRGB(107, 33, 168), delay, 1.2, function(at)
			ElementFx.burst(at, color, 0.8 + look.aura)
		end, { scale = 0.7 + look.aura * 0.6 })
	end
	if look.chains then
		local from = part(Vector3.new(0.2, 0.2, 0.2), WHITE, CFrame.new(caster - Vector3.new(0, 1, 0)), 1)
		local to = part(Vector3.new(0.2, 0.2, 0.2), WHITE, CFrame.new(middle), 1)
		for side = -1, 1, 2 do
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position = Vector3.new(side * 0.6, 0, 0)
			a1.Position = Vector3.new(side * tall * 0.25, 0, 0)
			a0.Parent = from
			a1.Parent = to
			local chain = Instance.new("Beam")
			chain.Attachment0 = a0
			chain.Attachment1 = a1
			chain.Texture = AttackFx.TEXTURES.bolt
			chain.TextureMode = Enum.TextureMode.Stretch
			chain.CurveSize0 = side * 2
			chain.CurveSize1 = -side * 2
			chain.Width0 = 0.5
			chain.Width1 = 0.35
			chain.Color = ColorSequence.new(SHADOW:Lerp(color, 0.35))
			chain.LightEmission = 0.4
			chain.FaceCamera = true
			chain.Segments = 12
			chain.Parent = from
		end
		fadeOut({ from, to }, 0.6)
	end

	-- What stays on the target for the curse: the sigil over it, the aura and smoke, the darkening
	local anchor = part(Vector3.new(0.2, 0.2, 0.2), WHITE, CFrame.new(middle), 1)
	table.insert(items, anchor)
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = target
	billboard.Size = UDim2.fromScale(look.sigil * math.clamp(tall / 4, 0.8, 2.5), look.sigil * math.clamp(tall / 4, 0.8, 2.5))
	billboard.StudsOffsetWorldSpace = Vector3.new(0, above + look.sigil * 0.55, 0)
	billboard.LightInfluence = 0
	billboard.Brightness = 1.5 + look.aura * 2
	billboard.Parent = anchor
	local mark = Instance.new("ImageLabel")
	mark.BackgroundTransparency = 1
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(0.5, 0.5)
	mark.Size = UDim2.fromScale(2.2, 2.2)
	mark.Image = MoveFxConfig.TEXTURES.sigil
	mark.ImageColor3 = if grade == "S" then Color3.fromRGB(240, 171, 252) else color
	mark.ImageTransparency = 1
	mark.Parent = billboard
	local aura = ElementFx.emitter(anchor, "glow", Color3.fromRGB(88, 28, 135), { size = { tall * 1.1, tall * 1.4 }, life = 0.8, locked = true,
		light = 0.2, brightness = 1 + look.aura, fade = 0.4, start = 1 - look.aura })
	aura.Rate = 4
	if look.smoke > 0 then
		local smoke = ElementFx.emitter(anchor, "smoke", SHADOW, { size = { tall * 0.25, tall * 0.6 }, life = { 1.2, 1.6 }, speed = { 1.5, 3 }, spread = 40,
			rotation = { 0, 360 }, spin = { -30, 30 }, light = 0, brightness = 1, fade = 0.4, start = 0.2 })
		smoke.Rate = look.smoke
	end
	local highlight = Instance.new("Highlight")
	highlight.Adornee = model or target
	highlight.FillColor = Color3.fromRGB(20, 0, 35)
	highlight.FillTransparency = 1
	highlight.OutlineColor = color
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = anchor

	local pulse: Tween? = nil
	task.delay(delay, function()
		if not anchor.Parent then
			return
		end
		TweenService:Create(mark, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.fromScale(1, 1), ImageTransparency = 0 }):Play()
		TweenService:Create(highlight, TweenInfo.new(0.3), { FillTransparency = 1 - look.darken, OutlineTransparency = 1 - look.aura * 0.8 }):Play()
		pulse = TweenService:Create(mark, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0.3), { ImageTransparency = 0.25 })
		if pulse then
			pulse:Play()
		end
		sound(anchor, sounds.hex, 0.9)
		sound(anchor, sounds.drone, 0.4, true)
		if grade == "A" or grade == "S" then
			sound(anchor, sounds.layer, 0.35, true)
		end
	end)
	local unfollow = follow(target, function(at)
		anchor.CFrame = CFrame.new(at.Position + Vector3.new(0, above - tall * 0.5, 0))
	end)
	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		unfollow()
		if pulse then
			pulse:Cancel()
		end
		TweenService:Create(mark, TweenInfo.new(0.4), { ImageTransparency = 1, Size = UDim2.fromScale(0.6, 0.6) }):Play()
		TweenService:Create(highlight, TweenInfo.new(0.4), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
		fadeOut(items, 0.4)
	end
	task.delay(delay + seconds, stop)
	return stop
end

return MoveFx
