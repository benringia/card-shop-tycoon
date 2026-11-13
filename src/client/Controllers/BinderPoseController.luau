--!strict
-- Reading your binder in the world, drawn on every client (owner 2026-11-13: "Opening the binder should also show the
-- character opening a binder, so that other players know you are opening a binder", "like reading a book"; pose and
-- binder only; Config/BinderPose): any player whose ReadingBinder attribute is on (BinderReadService) eases their arms
-- forward round a small open binder held at chest height and tips their head down; a page turns over now and then; it
-- all eases back and goes when they close it. The arms and head are posed through their joints' Transform after the
-- animations each frame (PreSimulation), blended from whatever the walk or idle plays: player joints are
-- AnimationConstraints since Roblox's avatar joint upgrade (Motor6Ds on older rigs; both have Transform, C0 only the
-- Motor6D). R15 bodies only (SwordService gives everyone the standard one).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BinderPose = require(Config:WaitForChild("BinderPose"))
local Collection = require(Config:WaitForChild("Collection"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BinderPoseRules = require(Shared:WaitForChild("Util"):WaitForChild("BinderPoseRules"))

local BinderPoseController = {}

local ATTRIBUTE = "ReadingBinder"
local POSE = BinderPose.POSE
local BOOK = BinderPose.BOOK
local COLORS = Collection.BOOK

type Joint = Motor6D | AnimationConstraint
type Reader = {
	character: Model?,
	open: boolean,
	since: number,
	joints: { [string]: Joint },
	book: Model?,
	turner: Weld?,
	flipAt: number,
	flipFrom: number?,
}

local readers: { [Player]: Reader } = {}
local rng = Random.new()

local JOINTS = {
	rightShoulder = { "RightUpperArm", "RightShoulder" },
	leftShoulder = { "LeftUpperArm", "LeftShoulder" },
	rightElbow = { "RightLowerArm", "RightElbow" },
	leftElbow = { "LeftLowerArm", "LeftElbow" },
	neck = { "Head", "Neck" },
}
-- The arms' pose at full weight, in each joint's own frame (shoulders forward and a little inward, elbows bent)
local INWARD, FORWARD, ELBOW = math.rad(POSE.inward), math.rad(POSE.shoulder), math.rad(POSE.elbow)
local ARM_POSE: { [string]: CFrame } = {
	rightShoulder = CFrame.Angles(0, INWARD, 0) * CFrame.Angles(FORWARD, 0, 0),
	leftShoulder = CFrame.Angles(0, -INWARD, 0) * CFrame.Angles(FORWARD, 0, 0),
	rightElbow = CFrame.Angles(ELBOW, 0, 0),
	leftElbow = CFrame.Angles(ELBOW, 0, 0),
}

local function piece(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function weld(part: BasePart, to: BasePart, offset: CFrame): Weld
	local made = Instance.new("Weld")
	made.Part0 = to
	made.Part1 = part
	made.C0 = offset
	made.Parent = part
	return made
end

-- Bright cards in the pockets, so it reads as a card binder from across the plaza (the rarities' own colours)
local function cardColors(count: number): { Color3 }
	local colors: { Color3 } = {}
	for index = 1, count do
		local rarity = Rarities.Tiers[BOOK.cardRarities[(index - 1) % #BOOK.cardRarities + 1]]
		table.insert(colors, if rarity then rarity.color else COLORS.SLEEVE)
	end
	rng:Shuffle(colors)
	return colors
end

-- A small open binder held at chest height (its spine on the body's middle line, its pages facing the reader): two
-- covers in a shallow V, a page on each with four cards in their pockets, chrome rings down the spine, and a loose
-- page that turns over now and then
local function buildBook(torso: BasePart): (Model, Weld)
	local model = Instance.new("Model")
	model.Name = "HeldBinder"
	local cw, ch, ct = BOOK.cover[1], BOOK.cover[2], BOOK.cover[3]
	local pw, ph, pt = BOOK.page[1], BOOK.page[2], BOOK.page[3]
	-- in front of the chest, its pages (+Z) toward the reader and tipped up to their face
	local hold = CFrame.new(0, -BOOK.down, -BOOK.forward) * CFrame.Angles(-math.rad(BOOK.lean), 0, 0)
	local colors = cardColors(8)
	local spine = piece(model, "Spine", Vector3.new(0.12, ch, ct * 2), COLORS.CASE_DARK, Enum.Material.Leather)
	weld(spine, torso, hold)
	for _, side in { -1, 1 } do
		local tilt = CFrame.Angles(0, -math.rad(BOOK.open) * side, 0) -- outer edges toward the reader
		local cover = piece(model, "Cover", Vector3.new(cw, ch, ct), COLORS.CASE, Enum.Material.Leather)
		weld(cover, spine, tilt * CFrame.new(side * cw / 2, 0, 0))
		-- outside: gold stitching round the edge and a gold diamond in the middle, what onlookers in front see
		local back = tilt * CFrame.new(side * cw / 2, 0, -ct / 2 - 0.006)
		local inset = 0.07
		for _, edge in { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } } do
			local across = edge[2] ~= 0
			local size = if across then Vector3.new(cw - inset * 2, 0.025, 0.01) else Vector3.new(0.025, ch - inset * 2, 0.01)
			local stitch = piece(model, "Stitch", size, COLORS.STITCH)
			weld(stitch, spine, back * CFrame.new(edge[1] * (cw / 2 - inset), edge[2] * (ch / 2 - inset), 0))
		end
		local emblem = piece(model, "Emblem", Vector3.new(cw * 0.3, cw * 0.3, 0.012), COLORS.STITCH, Enum.Material.Metal)
		weld(emblem, spine, back * CFrame.Angles(0, 0, math.rad(45)))
		local page = piece(model, "Page", Vector3.new(pw, ph, pt), COLORS.PAGE_COLOR)
		weld(page, spine, tilt * CFrame.new(side * (pw / 2 + 0.05), 0, ct / 2 + pt / 2))
		for row = -1, 1, 2 do
			for column = -1, 1, 2 do
				local at = tilt * CFrame.new(side * (pw / 2 + 0.05) + column * pw * 0.23, row * ph * 0.23, ct / 2 + pt)
				local border = piece(model, "CardBorder", Vector3.new(pw * 0.4, ph * 0.4, 0.01), COLORS.CHROME[1])
				weld(border, spine, at * CFrame.new(0, 0, 0.006))
				local card = piece(model, "Card", Vector3.new(pw * 0.32, ph * 0.33, 0.01), table.remove(colors) or COLORS.SLEEVE)
				weld(card, spine, at * CFrame.new(0, 0, 0.012))
			end
		end
	end
	for index = 1, BOOK.rings do
		local y = (index - (BOOK.rings + 1) / 2) * ch / (BOOK.rings + 0.5)
		local ring = piece(model, "Ring", Vector3.new(0.05, BOOK.ring, BOOK.ring), COLORS.CHROME[1], Enum.Material.Metal)
		ring.Shape = Enum.PartType.Cylinder
		weld(ring, spine, CFrame.new(0, y, ct + BOOK.ring / 2))
	end
	-- the turning page: hinged at the spine, lying on the right page until it turns
	local loose = piece(model, "TurningPage", Vector3.new(pw, ph, 0.02), COLORS.PAGE_COLOR)
	loose.Transparency = 1
	local turner = weld(loose, spine, CFrame.new(0, 0, ct / 2 + pt + 0.02))
	model.Parent = torso.Parent
	return model, turner
end

local function jointsOf(character: Model): { [string]: Joint }
	local joints: { [string]: Joint } = {}
	for key, path in JOINTS do
		local limb = character:FindFirstChild(path[1])
		local joint = if limb then limb:FindFirstChild(path[2]) else nil
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			joints[key] = joint
		end
	end
	return joints
end

local function dropBook(reader: Reader)
	if reader.book then
		reader.book:Destroy()
	end
	reader.book = nil
	reader.turner = nil
	reader.flipFrom = nil
end

local function readerOf(player: Player): Reader
	local reader = readers[player]
	if not reader then
		reader = { character = nil, open = false, since = -math.huge, joints = {}, book = nil, turner = nil, flipAt = 0, flipFrom = nil }
		readers[player] = reader
	end
	return reader
end

local function onAttribute(player: Player)
	local reader = readerOf(player)
	local open = player:GetAttribute(ATTRIBUTE) == true
	if open == reader.open then
		return
	end
	-- carry on from where the ease was, so a quick close and reopen never snaps
	local now = os.clock()
	local weight = BinderPoseRules.weight(reader.since, now, BinderPose.EASE, reader.open)
	reader.open = open
	local done = if open then weight else 1 - weight
	reader.since = now - done * BinderPose.EASE
	reader.flipAt = now + BinderPoseRules.nextFlip(rng:NextNumber(), BinderPose.FLIP.every)
end

local function watch(player: Player)
	player:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
		onAttribute(player)
	end)
	player.CharacterRemoving:Connect(function()
		local reader = readers[player]
		if reader then
			dropBook(reader)
			reader.joints = {}
			reader.character = nil
		end
	end)
	onAttribute(player)
end

-- One frame for one reader: their weight, the binder, the page turn (the pose itself is set after the animations)
local function step(player: Player, reader: Reader, now: number, camera: Vector3)
	local weight = BinderPoseRules.weight(reader.since, now, BinderPose.EASE, reader.open)
	local character = player.Character
	local torso = if character then character:FindFirstChild("UpperTorso") else nil
	if weight <= 0 or not character or not torso or not torso:IsA("BasePart") then
		reader.joints = {}
		dropBook(reader)
		return
	end
	if reader.character ~= character then
		reader.joints = {}
		dropBook(reader)
		reader.character = character
	end
	if not next(reader.joints) then
		reader.joints = jointsOf(character)
	end
	if not reader.book then
		reader.book, reader.turner = buildBook(torso)
	end
	-- the binder only shows once the arms are up to it
	local book = reader.book
	if book then
		for _, part in book:GetChildren() do
			if part:IsA("BasePart") and part.Name ~= "TurningPage" then
				part.LocalTransparencyModifier = 1 - math.clamp((weight - 0.35) / 0.4, 0, 1)
			end
		end
	end
	-- a page turning over from right to left (only for readers near enough to see it)
	local turner = reader.turner
	if turner and reader.open and weight >= 1 and (torso.Position - camera).Magnitude <= BinderPose.RANGE then
		local page = turner.Part1 :: BasePart
		if not reader.flipFrom and now >= reader.flipAt then
			reader.flipFrom = now
		end
		local from = reader.flipFrom
		if from then
			local t = math.clamp((now - from) / BinderPose.FLIP.seconds, 0, 1)
			local base = CFrame.new(0, 0, BOOK.cover[3] / 2 + BOOK.page[3] + 0.02)
			turner.C0 = base * CFrame.Angles(0, -math.pi * t, 0) * CFrame.new(BOOK.page[1] / 2 + 0.05, 0, 0)
			page.Transparency = if t < 1 then 0 else 1
			if t >= 1 then
				reader.flipFrom = nil
				reader.flipAt = now + BinderPoseRules.nextFlip(rng:NextNumber(), BinderPose.FLIP.every)
			end
		end
	end
end

function BinderPoseController.Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		local reader = readers[player]
		if reader then
			dropBook(reader)
		end
		readers[player] = nil
	end)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local origin = if camera then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		for player, reader in readers do
			step(player, reader, now, origin)
		end
	end)
	-- after the animations: the arms blended from the walk or idle into holding the binder, the head tipped down
	RunService.PreSimulation:Connect(function()
		local now = os.clock()
		for _, reader in readers do
			if not next(reader.joints) then
				continue
			end
			local weight = BinderPoseRules.weight(reader.since, now, BinderPose.EASE, reader.open)
			if weight <= 0 then
				continue
			end
			for key, pose in ARM_POSE do
				local joint = reader.joints[key]
				if joint and joint.Parent then
					joint.Transform = joint.Transform:Lerp(pose, weight)
				end
			end
			local neck = reader.joints.neck
			if neck and neck.Parent then
				local angles = BinderPoseRules.angles(POSE, weight)
				neck.Transform = neck.Transform * CFrame.Angles(-math.rad(angles.neck), 0, 0)
			end
		end
	end)
end

return BinderPoseController
