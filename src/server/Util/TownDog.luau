--!strict
-- A town dog on the server (Town Pish, PishService; Town Chikin, TownChikinService): an invisible marker it walks at a
-- dog's pace round the plaza fountain (Util/PishPath), facing the way it goes, idle clips named by its Clip attribute
-- (ClipId bumps each time; clients play it, Util/PishVisual), and holding still while it's petted, at most `holdMax`
-- seconds at a time so one player petting again and again can't keep it in one place.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Plaza = require(Shared:WaitForChild("Config"):WaitForChild("Plaza"))
local Wild = require(Shared:WaitForChild("Config"):WaitForChild("Wild"))
local PishPath = require(Shared:WaitForChild("Util"):WaitForChild("PishPath"))
local GreetRules = require(Shared:WaitForChild("Util"):WaitForChild("GreetRules"))

local TownDog = {}

local FOUNTAIN_CLEAR = 2 -- studs kept from the fountain's base
local PETTED_SECONDS = 2.5 -- it holds still this long for the "petted" clip

export type Dog = {
	marker: Part,
	holdMax: number,
	clipId: number,
	lastClip: string?,
	pettedUntil: number,
}

-- A spot on the town's ground
function TownDog.ground(x: number, z: number): Vector3
	return Vector3.new(x, Wild.SPRING.y, z)
end

-- An invisible marker `name` in a new folder `folderName` at `start`, its clip, move and petting attributes set, and a
-- "Pet" prompt reaching `petRange` (clients enable it only for a player who may pet it)
function TownDog.new(folderName: string, name: string, start: Vector3, petRange: number, holdMax: number): (Dog, ProximityPrompt)
	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = workspace
	local marker = Instance.new("Part")
	marker.Name = name
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(2, 2, 2)
	marker.CFrame = CFrame.new(start)
	marker:SetAttribute("Clip", "")
	marker:SetAttribute("ClipId", 0)
	marker:SetAttribute("Moving", false)
	marker:SetAttribute("Petting", 0)
	marker.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PetPrompt"
	prompt.ActionText = "Pet"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = petRange
	prompt.Parent = marker
	return { marker = marker, holdMax = holdMax, clipId = 0, lastClip = nil, pettedUntil = 0 }, prompt
end

function TownDog.play(dog: Dog, clip: string)
	dog.clipId += 1
	dog.lastClip = clip
	dog.marker:SetAttribute("Clip", clip)
	dog.marker:SetAttribute("ClipId", dog.clipId)
end

function TownDog.face(dog: Dog, point: Vector3)
	local at = dog.marker.Position
	local flat = Vector3.new(point.X, at.Y, point.Z)
	if (flat - at).Magnitude > 0.05 then
		dog.marker.CFrame = CFrame.lookAt(at, flat)
	end
end

-- Holds still while it's being petted, at most holdMax seconds at a time (PishPath.holdEnd)
local function waitWhilePetted(dog: Dog)
	local started = os.clock()
	while os.clock() < PishPath.holdEnd(dog.pettedUntil, started, dog.holdMax) do
		task.wait(0.1)
	end
end

function TownDog.waitFor(dog: Dog, seconds: number)
	local finish = os.clock() + seconds
	local holdLeft = dog.holdMax -- petting can stretch this wait by this much in all
	while os.clock() < finish do
		task.wait(0.1)
		if holdLeft > 0 and os.clock() < dog.pettedUntil then
			local before = os.clock()
			waitWhilePetted(dog)
			holdLeft -= os.clock() - before
		end
	end
end

-- Walks the marker to `target`, round the fountain, at `speed` studs a second
function TownDog.walkTo(dog: Dog, target: Vector3, speed: number)
	local marker = dog.marker
	local centre = { x = Wild.SPRING.x, z = Wild.SPRING.z }
	local here = marker.Position
	local points = PishPath.route({ x = here.X, z = here.Z }, { x = target.X, z = target.Z }, centre, Plaza.FOUNTAIN_RADIUS + FOUNTAIN_CLEAR)
	marker:SetAttribute("Moving", true)
	local holdLeft = dog.holdMax -- petting can stop this walk for this long in all
	for _, point in points do
		local goal = TownDog.ground(point.x, point.z)
		TownDog.face(dog, goal)
		while (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(marker.Position.X, 0, marker.Position.Z)).Magnitude > 0.2 do
			if holdLeft > 0 and os.clock() < dog.pettedUntil then
				marker:SetAttribute("Moving", false)
				local before = os.clock()
				waitWhilePetted(dog)
				holdLeft -= os.clock() - before
				marker:SetAttribute("Moving", true)
				TownDog.face(dog, goal)
			end
			local dt = RunService.Heartbeat:Wait()
			local at = marker.Position
			local step = goal - Vector3.new(at.X, goal.Y, at.Z)
			local move = math.min(step.Magnitude, speed * dt)
			local ahead = Vector3.new(at.X, goal.Y, at.Z) + step.Unit * move
			marker.CFrame = CFrame.lookAt(ahead, ahead + step.Unit)
		end
	end
	marker:SetAttribute("Moving", false)
end

-- A random idle clip from `clips` (never the same twice running) or, by `napChance`, a nap
function TownDog.idle(dog: Dog, clips: { string }, napChance: number, rng: Random)
	if rng:NextNumber() < napChance then
		TownDog.play(dog, "nap")
		return
	end
	local clip = clips[rng:NextInteger(1, #clips)]
	if clip == dog.lastClip then
		clip = clips[(table.find(clips, clip) :: number) % #clips + 1]
	end
	TownDog.play(dog, clip)
end

-- It stops `seconds`, faces `from` and plays `clip` (Town Chikin greeting a player who came near)
function TownDog.hold(dog: Dog, from: Vector3, clip: string, seconds: number)
	dog.pettedUntil = os.clock() + seconds
	TownDog.face(dog, from)
	TownDog.play(dog, clip)
end

-- A player at `from` pets it: it holds still, faces them and plays "petted" (marker Petting: their UserId, for a moment)
function TownDog.petted(dog: Dog, from: Vector3, userId: number)
	dog.pettedUntil = os.clock() + PETTED_SECONDS
	TownDog.face(dog, from)
	dog.marker:SetAttribute("Petting", userId)
	TownDog.play(dog, "petted")
	task.delay(PETTED_SECONDS, function()
		if os.clock() >= dog.pettedUntil then
			dog.marker:SetAttribute("Petting", 0)
		end
	end)
end

-- Greeting players who come near (Town Chikin, the owner 2026-11-11; Town Pish, 2026-11-12: "npc pish should also greet
-- people like chikin"; Util/GreetRules): every `cfg.every` seconds the nearest player who just walked within
-- `cfg.range` and it hasn't greeted in `cfg.cooldown` (not `skip`ped: one its tutorial self is leading; not in their
-- first `cfg.joinGrace` seconds after spawning: the loading screen) gets a hello: it stops, faces them and plays one of
-- `cfg.clips`, and the marker's GreetUserId / GreetLine (1 to `lines` hellos, then `thanks` thank-yous for a supporter,
-- "Support the dev" owner 2026-11-12; never the same twice running) / GreetId tell clients to show its bubble
-- (Util/GreetBubble)
function TownDog.greet(dog: Dog, cfg: { range: number, cooldown: number, every: number, hold: number, joinGrace: number, clips: { string } }, lines: number, thanks: number, skip: (player: Player) -> boolean, rng: Random)
	local greetedAt: { [string]: number } = {} -- os.clock() it last greeted each player, by UserId
	local spawnedAt: { [Player]: number } = {}
	local inside: { [string]: boolean } = {} -- who was in range on its last look (a hello is for walking up)
	local lastLine: number? = nil
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			spawnedAt[player] = os.clock()
		end)
		if player.Character then
			spawnedAt[player] = os.clock()
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		greetedAt[tostring(player.UserId)] = nil
		inside[tostring(player.UserId)] = nil
		spawnedAt[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(cfg.every)
			if os.clock() < dog.pettedUntil then
				continue -- being petted or already saying hello
			end
			local here = dog.marker.Position
			local near: { GreetRules.Near } = {}
			local byKey: { [string]: Player } = {}
			local nowInside: { [string]: boolean } = {}
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
				if root then
					local key = tostring(player.UserId)
					local distance = (root.Position - here).Magnitude
					local settling = os.clock() - (spawnedAt[player] or 0) < cfg.joinGrace
					if distance <= cfg.range then
						-- joining (or tutored) beside it counts as already there: no hello till they walk off and back
						nowInside[key] = true
						if settling or skip(player) then
							inside[key] = true
						end
					end
					if not settling and not skip(player) then
						table.insert(near, { key = key, distance = distance })
						byKey[key] = player
					end
				end
			end
			local key = GreetRules.pick(near, greetedAt, os.clock(), cfg, inside)
			inside = nowInside
			local player = if key then byKey[key] else nil
			local character = if player then player.Character else nil
			local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			if key and player and root then
				greetedAt[key] = os.clock()
				TownDog.hold(dog, root.Position, cfg.clips[rng:NextInteger(1, #cfg.clips)], cfg.hold)
				local supporter = (tonumber(player:GetAttribute("SupporterTier")) or 0) > 0
				lastLine = GreetRules.pickLine(lines, thanks, supporter, rng:NextNumber(), lastLine)
				dog.marker:SetAttribute("GreetUserId", player.UserId)
				dog.marker:SetAttribute("GreetLine", lastLine)
				dog.marker:SetAttribute("GreetId", ((dog.marker:GetAttribute("GreetId") :: number?) or 0) + 1)
			end
		end
	end)
end

return TownDog
