--!strict
-- The town's dressing on this client (owner 2026-11-19: "do town beauties"; Config/TownDress, Util/TownDressRules):
--   on a weekly event's day (Config/Events, Util/EventNow) a small banner with the event's picture hangs on every
--     street light, so Boss Rush and Lucky Sunday show in the world (the first build's string lights ran along the
--     shop fronts and covered their entrances: gone, owner 2026-11-19);
--   leaves drifting down from the plaza's planter trees, and a shooting star now and then deep in the night (both only
--     while the extras run, Util/Extras).
-- Built once from small parts and a few particles: no lights, no GUIs, nothing per frame. Main game only; nothing
-- replicates.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Soundscape = require(Config:WaitForChild("Soundscape"))
local TownDress = require(Config:WaitForChild("TownDress"))
local SharedUtil = Shared:WaitForChild("Util")
local EventNow = require(SharedUtil:WaitForChild("EventNow"))
local Place = require(SharedUtil:WaitForChild("Place"))
local SoundscapeRules = require(SharedUtil:WaitForChild("SoundscapeRules"))
local TownDressRules = require(SharedUtil:WaitForChild("TownDressRules"))

local Extras = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("Extras"))

local TownDressController = {}

local BANNERS = TownDress.BANNERS
local LEAVES = TownDress.LEAVES
local STAR = TownDress.STAR
local CHECK_EVERY = 1 -- seconds between updates (the night, the day's look, the next star)
local ROOT_WAIT = 60 -- seconds to wait for a folder the town's pieces are in
local LAMPS_WANTED = 8 -- the town's street lights; fewer after LAMP_WAIT still get their banners
local LAMP_WAIT = 20
local TREE_WAIT = 30 -- seconds for a planter tree's canopy to arrive

local folder: Folder
local lamps: { TownDressRules.Point } = {}
local banners: { Part } = {}
local leafEmitters: { ParticleEmitter } = {}
local treesDone: { [Instance]: boolean } = {}
local lookId: string? = nil -- the event whose banners hang ("" none)
local nextStar = 0
local rng = Random.new()

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- A small part nothing bumps into, sees or casts a shadow from
local function prop(name: string, size: Vector3, at: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = at
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- The day's banners: one on every lamp post on an event's day, none on a plain day
local function dress(eventId: string?)
	for _, banner in banners do
		banner:Destroy()
	end
	table.clear(banners)
	local look = TownDressRules.look(TownDress, eventId)
	if not look then
		return
	end
	for _, lamp in lamps do
		local x, y, z, faceZ = TownDressRules.banner(lamp, BANNERS)
		local at = Vector3.new(x, y, z)
		local banner = prop("Banner", Vector3.new(BANNERS.size.x, BANNERS.size.y, 0.08), CFrame.lookAt(at, at + Vector3.new(0, 0, faceZ)))
		banner.Material = Enum.Material.SmoothPlastic
		banner.Color = rgb(look.color)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local picture = Instance.new("Decal")
			picture.Face = face
			picture.Texture = look.image
			picture.Color3 = rgb(look.tint)
			picture.Parent = banner
		end
		banner.Parent = folder
		table.insert(banners, banner)
	end
end

-- Leaves drifting down from a planter tree's canopy
local function shed(tree: Instance)
	if treesDone[tree] or not tree:IsA("Model") or not table.find(LEAVES.models, tree.Name) then
		return
	end
	treesDone[tree] = true
	-- its planter arrives before its canopy: wait until the tree stands tall (else the leaves fell from the pot)
	local center, size = tree:GetBoundingBox()
	local started = os.clock()
	while size.Y < LEAVES.minHeight and os.clock() - started < TREE_WAIT do
		task.wait(1)
		if not tree.Parent then
			return
		end
		center, size = tree:GetBoundingBox()
	end
	if size.Y < LEAVES.minHeight then
		return
	end
	local top = center.Position + Vector3.new(0, size.Y / 2 - LEAVES.drop, 0)
	local canopy = prop("Leaves", Vector3.new(LEAVES.box, 1, LEAVES.box), CFrame.new(top))
	canopy.Transparency = 1
	canopy.Parent = folder
	local keys = {}
	for index, color in LEAVES.colors do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#LEAVES.colors - 1), rgb(color)))
	end
	local leaves = Instance.new("ParticleEmitter")
	leaves.Texture = LEAVES.texture
	leaves.Color = ColorSequence.new(keys)
	leaves.Shape = Enum.ParticleEmitterShape.Box
	leaves.EmissionDirection = Enum.NormalId.Bottom
	leaves.Lifetime = NumberRange.new(LEAVES.life[1], LEAVES.life[2])
	leaves.Speed = NumberRange.new(0.6, 1.2)
	leaves.SpreadAngle = Vector2.new(35, 35)
	leaves.Acceleration = Vector3.new(0.5, -0.5, 0.3) -- a light breeze
	leaves.Drag = 0.4
	leaves.Rotation = NumberRange.new(0, 360)
	leaves.RotSpeed = NumberRange.new(-110, 110)
	leaves.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.1, LEAVES.size),
		NumberSequenceKeypoint.new(0.85, LEAVES.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	leaves.LightInfluence = 1
	leaves.Rate = 0
	leaves.Parent = canopy
	table.insert(leafEmitters, leaves)
end

-- A shooting star: a short bright streak far off and high up, gone in a moment
local function shootStar()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local angle = rng:NextNumber(0, math.pi * 2)
	local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local from = camera.CFrame.Position + out * STAR.far + Vector3.new(0, rng:NextNumber(STAR.high[1], STAR.high[2]), 0)
	local heading = (out:Cross(Vector3.yAxis) * (if rng:NextNumber() < 0.5 then 1 else -1) - Vector3.yAxis * 0.35).Unit
	local star = prop("ShootingStar", Vector3.new(0.2, 0.2, 0.2), CFrame.new(from))
	star.Transparency = 1
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, STAR.width / 2, 0)
	top.Parent = star
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -STAR.width / 2, 0)
	bottom.Parent = star
	local streak = Instance.new("Trail")
	streak.Attachment0 = top
	streak.Attachment1 = bottom
	streak.FaceCamera = true
	streak.Lifetime = 0.45
	streak.LightEmission = 1
	streak.LightInfluence = 0
	streak.Color = ColorSequence.new(rgb(STAR.color))
	streak.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	streak.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	streak.Parent = star
	star.Parent = folder
	local fly = TweenService:Create(star, TweenInfo.new(STAR.seconds, Enum.EasingStyle.Linear), { CFrame = CFrame.new(from + heading * STAR.travel) })
	fly.Completed:Once(function()
		task.delay(streak.Lifetime + 0.1, function()
			star:Destroy()
		end)
	end)
	fly:Play()
end

local function update()
	local night = SoundscapeRules.nightShare(Lighting.ClockTime, Soundscape.NIGHT)
	local event = EventNow.today()
	local id = if event then event.id else ""
	if id ~= lookId then
		lookId = id
		dress(if event then event.id else nil)
	end
	local extras = Extras.enabled()
	local rate = if extras then LEAVES.rate else 0
	for _, emitter in leafEmitters do
		emitter.Rate = rate
	end
	local now = os.clock()
	if now >= nextStar then
		if nextStar > 0 and extras and TownDressRules.starShows(night, STAR) then
			shootStar()
		end
		nextStar = SoundscapeRules.nextAt(now, STAR.every, rng:NextNumber())
	end
end

-- The town's street lights (their spot on the ground), once they're all in or LAMP_WAIT has passed
local function findLamps(): { TownDressRules.Point }
	local root = workspace:WaitForChild(BANNERS.root, ROOT_WAIT)
	local found: { TownDressRules.Point } = {}
	if not root then
		return found
	end
	local started = os.clock()
	repeat
		table.clear(found)
		for _, item in root:GetDescendants() do
			if item:IsA("Model") and item.Name == BANNERS.lamp then
				local center = item:GetBoundingBox()
				table.insert(found, { x = center.Position.X, z = center.Position.Z })
			end
		end
		if #found < LAMPS_WANTED then
			task.wait(1)
		end
	until #found >= LAMPS_WANTED or os.clock() - started > LAMP_WAIT
	return found
end

function TownDressController.Start()
	if Place.isFrontier() or Place.isDungeon() then
		return
	end
	task.spawn(function()
		folder = Instance.new("Folder")
		folder.Name = "TownDress"
		folder.Parent = workspace
		lamps = findLamps()
		for _, rootName in LEAVES.roots do
			task.spawn(function()
				local root = workspace:WaitForChild(rootName, ROOT_WAIT)
				if not root then
					return
				end
				for _, item in root:GetDescendants() do
					task.spawn(shed, item)
				end
				root.DescendantAdded:Connect(function(item)
					if item:IsA("Model") and table.find(LEAVES.models, item.Name) then
						task.wait(1) -- its parts arrive after it
						shed(item)
					end
				end)
			end)
		end
		workspace:GetAttributeChangedSignal(EventNow.OVERRIDE):Connect(update) -- Studio's /event
		while true do
			update()
			task.wait(CHECK_EVERY)
		end
	end)
end

return TownDressController
