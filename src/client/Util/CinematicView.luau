--!strict
-- What stands between a camera moment and what it must show (moved out of Util/SuperCinematic so a sword skill's camera
-- moment uses it too: the owner 2026-11-11, "the camera just zooms in with the boss blocking so my animation/skill
-- effects is invisible on cinematic"). Players' characters, creatures, monsters and bosses near it: creatures, monsters
-- and bosses are drawn as models at the top of the workspace marked with the BODY attribute (Util/CreatureVisuals; most
-- monsters and bosses have no AnimationController, so that can't tell them apart) and their parts can't be raycast
-- (CanQuery off), so their bounding boxes are tested. A body in the way can be faded out of it, on this screen only
-- (LocalTransparencyModifier).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SuperFxRules = require(Shared:WaitForChild("Util"):WaitForChild("SuperFxRules"))

local CinematicView = {}

-- The attribute CreatureVisuals marks every model it draws with
CinematicView.BODY = "CinematicBody"

local REACH = 80 -- studs from the first point a body is checked within
local SHRINK = 0.8 -- of a body's bounding box counts (boxes are bigger than the bodies in them)

local function vec(v: Vector3): SuperFxRules.Vec
	return { x = v.X, y = v.Y, z = v.Z }
end

local function candidates(): { Model }
	local list: { Model } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and child:GetAttribute(CinematicView.BODY) then
			table.insert(list, child)
		end
	end
	return list
end

-- Whether `point` (in a body's box space) is inside its box of `size`, grown `grow` studs each way
local function inside(point: Vector3, size: Vector3, grow: number): boolean
	local half = size * 0.5 + Vector3.one * grow
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

-- Whether the line from `from` (box space) to `point` (world) crosses the body's box; `landed`: a point an effect lands
-- on, and a body it is inside is what it shows (a skill landing on the boss), not in its way
local function crosses(box: CFrame, size: Vector3, from: SuperFxRules.Vec, point: Vector3, landed: boolean): boolean
	local at = box:PointToObjectSpace(point)
	if landed and inside(at, size, 0) then
		return false
	end
	return SuperFxRules.segmentHitsBox(from, vec(at), vec(size * 0.5 * SHRINK))
end

-- The bodies between `eye` and any of `points` (you, a caster: whoever stands in front of them is in the way) or of
-- `shown` (where an effect lands: the body it lands on isn't) (`own`, the one being filmed, left out)
function CinematicView.blockers(eye: Vector3, points: { Vector3 }, own: Instance?, shown: { Vector3 }?): { Model }
	local found: { Model } = {}
	local landing = shown or {}
	local near = points[1] or landing[1]
	if not near then
		return found
	end
	for _, body in candidates() do
		if body ~= own and body.Parent and (body:GetPivot().Position - near).Magnitude < REACH then
			local box, size = body:GetBoundingBox()
			local from = vec(box:PointToObjectSpace(eye))
			local blocked = false
			for _, point in points do
				if crosses(box, size, from, point, false) then
					blocked = true
					break
				end
			end
			if not blocked then
				for _, point in landing do
					if crosses(box, size, from, point, true) then
						blocked = true
						break
					end
				end
			end
			if blocked then
				table.insert(found, body)
			end
		end
	end
	return found
end

-- The biggest body standing at `point` (its bounding box grown `grow` studs round it; `own` left out) and its reach:
-- the studs from its middle to its side, 0 when nobody is there
function CinematicView.reachAt(point: Vector3, grow: number, own: Instance?): number
	local reach = 0
	for _, body in candidates() do
		if body ~= own and body.Parent then
			local box, size = body:GetBoundingBox()
			if inside(box:PointToObjectSpace(point), size, grow) then
				reach = math.max(reach, math.max(size.X, size.Z) * 0.5)
			end
		end
	end
	return reach
end

-- Effects wrapped round a body (the Frost Tyrant's ice shield, the ice a frozen fighter is locked in: Util/IceFx) are
-- drawn apart from it; attached, they fade with it
local covers: { [Instance]: { Instance } } = setmetatable({} :: any, { __mode = "k" })
function CinematicView.attach(body: Instance?, cover: Instance)
	if not body then
		return
	end
	local list = covers[body]
	if not list then
		list = {}
		covers[body] = list
	end
	for index = #list, 1, -1 do
		if not list[index].Parent then
			table.remove(list, index)
		end
	end
	table.insert(list, cover)
end

local function fadeParts(root: Instance, amount: number)
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			item.LocalTransparencyModifier = amount
		end
	end
end

-- A body faded (or back), with whatever covers it: every part's LocalTransparencyModifier, this screen only
function CinematicView.fade(model: Model, amount: number)
	fadeParts(model, amount)
	for _, cover in covers[model] or {} do
		if cover.Parent then
			fadeParts(cover, amount)
		end
	end
end

export type Fader = { update: (eye: Vector3, points: { Vector3 }, own: Instance?, shown: { Vector3 }?) -> (), restore: () -> () }

-- Fades whatever body stands between the camera and the points each frame (`amount`), and brings back the ones no
-- longer in the way; restore() brings every one back
function CinematicView.newFader(amount: number): Fader
	local faded: { [Model]: boolean } = {}
	local function update(eye: Vector3, points: { Vector3 }, own: Instance?, shown: { Vector3 }?)
		local now: { [Model]: boolean } = {}
		for _, body in CinematicView.blockers(eye, points, own, shown) do
			now[body] = true
			if not faded[body] then
				CinematicView.fade(body, amount)
			end
		end
		for body in faded do
			if not now[body] and body.Parent then
				CinematicView.fade(body, 0)
			end
		end
		faded = now
	end
	local function restore()
		for body in faded do
			if body.Parent then
				CinematicView.fade(body, 0)
			end
		end
		faded = {}
	end
	return { update = update, restore = restore }
end

return CinematicView
