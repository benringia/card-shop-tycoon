--!strict
-- Town Chikin (the owner 2026-11-11: "after chikin's tutorial he will become an NPC too like pish, walking around the
-- town"; his picks: the portal side of town, a combat buff for 5 minutes): one dog per server that everyone sees, the
-- owner's other dog. The server moves an invisible marker (workspace.ChikinNpc.TownChikin) between the portal-side
-- stops (Config/Chikin TOWN.stops, by weight, never the one he's at: Util/PishPath.pickStop), trotting the long ways,
-- with idle clips and naps between (Util/TownDog, Town Pish's walk). Clients draw him (TownChikinController).
-- Petting him (a ProximityPrompt on the marker; anyone within COURAGE.petRange whose combat tour is done, player
-- attribute CombatDone; the client shows the prompt only then) gives Chikin's Courage: their creatures hit
-- COURAGE.share harder for COURAGE.seconds (player attribute ChikinCourageUntil, os.time; BattleService boosts the
-- fight), once per COURAGE.cooldown. CombatTutorialService loads and saves the last time (data.combat's pishLuckAt).
-- He greets a player who comes near (the owner 2026-11-11; Chikin.TOWN.greet, Util/GreetRules): the nearest he hasn't
-- greeted lately; he stops, faces them and plays a clip, and the marker's GreetUserId / GreetLine / GreetId tell clients
-- to show his bubble (TownChikinController). Not a player his tutorial self is leading (they don't see Town Chikin).
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Chikin = require(Shared:WaitForChild("Config"):WaitForChild("Chikin"))
local ChikinTalk = require(Shared:WaitForChild("Config"):WaitForChild("ChikinTalk"))
local GreetRules = require(Shared:WaitForChild("Util"):WaitForChild("GreetRules"))
local LuckRules = require(Shared:WaitForChild("Util"):WaitForChild("LuckRules"))
local PishPath = require(Shared:WaitForChild("Util"):WaitForChild("PishPath"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))
local TownDog = require(ServerUtil:WaitForChild("TownDog"))

local TownChikinService = {}

local PET_COOLDOWN = 2 -- seconds between one player's pets (the cuddle plays every time)

local rng = Random.new()
local dog: TownDog.Dog? = nil
local courageAt: { [Player]: number } = {} -- os.time of each player's last Courage from him (CombatTutorialService saves it)
local allowPet = RateLimiter.new(PET_COOLDOWN)
local greetedAt: { [string]: number } = {} -- os.clock() he last greeted each player, by UserId
local lastLine: number? = nil

local function day(walker: TownDog.Dog)
	local town = Chikin.TOWN
	local current: number? = nil
	while true do
		local index = PishPath.pickStop(town.stops, rng:NextNumber(), current)
		if index then
			local stop = town.stops[index]
			local target = TownDog.ground(stop.x, stop.z)
			local far = (target - walker.marker.Position).Magnitude > town.trotFrom
			TownDog.walkTo(walker, target, if far then town.trotSpeed else town.speed)
			current = index
			TownDog.idle(walker, town.idleClips, town.napChance, rng)
		end
		TownDog.waitFor(walker, rng:NextNumber(town.idleEvery[1], town.idleEvery[2]))
	end
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- A player his tutorial self is leading right now (Town Chikin is hidden on their screen)
local function inHisTour(player: Player): boolean
	local step = player:GetAttribute("CombatStep")
	return typeof(step) == "string" and step ~= "" and step ~= Chikin.WAIT_STEP
end

-- Every few moments: the nearest player he hasn't greeted lately, if one has come near, gets a hello
local function greetLoop(walker: TownDog.Dog)
	local cfg = Chikin.TOWN.greet
	while true do
		task.wait(cfg.every)
		if os.clock() < walker.pettedUntil then
			continue -- being petted or already saying hello
		end
		local here = walker.marker.Position
		local near: { GreetRules.Near } = {}
		local byKey: { [string]: Player } = {}
		for _, player in Players:GetPlayers() do
			local root = characterRoot(player)
			if root and not inHisTour(player) then
				local key = tostring(player.UserId)
				table.insert(near, { key = key, distance = (root.Position - here).Magnitude })
				byKey[key] = player
			end
		end
		local key = GreetRules.pick(near, greetedAt, os.clock(), cfg)
		local player = if key then byKey[key] else nil
		local root = if player then characterRoot(player) else nil
		if key and player and root then
			greetedAt[key] = os.clock()
			TownDog.hold(walker, root.Position, cfg.clips[rng:NextInteger(1, #cfg.clips)], cfg.hold)
			lastLine = GreetRules.line(#ChikinTalk.GREETS, rng:NextNumber(), lastLine)
			walker.marker:SetAttribute("GreetUserId", player.UserId)
			walker.marker:SetAttribute("GreetLine", lastLine)
			walker.marker:SetAttribute("GreetId", ((walker.marker:GetAttribute("GreetId") :: number?) or 0) + 1)
		end
	end
end

local function onPet(player: Player)
	local walker = dog
	if not walker or not allowPet(player) then
		return
	end
	local root = characterRoot(player)
	if not root then
		return
	end
	local courage = Chikin.COURAGE
	local near = (root.Position - walker.marker.Position).Magnitude <= courage.petRange + 2
	if not near or player:GetAttribute("CombatDone") ~= true then
		return -- after his combat tour (the client shows the prompt only then)
	end
	TownDog.petted(walker, root.Position, player.UserId)
	local now = os.time()
	local granted = LuckRules.canGrant(courageAt[player], now, courage.cooldown)
	if granted then
		courageAt[player] = now
		player:SetAttribute("ChikinCourageUntil", now + courage.seconds)
	end
	Remotes.ChikinPetted:FireAllClients(player.UserId, granted)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, "ChikinPetted", if granted then 1 else 0)
	end)
end

-- The last time a player had Courage from him, and setting it: CombatTutorialService loads it (petting gives nothing
-- until then), saves it and forgets it on unload, so it lives in DataService's lifecycle. Loading puts a Courage still
-- running back on the player (it carries into the Frontier and the Dungeon).
function TownChikinService.GetCourageAt(player: Player): number
	return courageAt[player] or 0
end

function TownChikinService.SetCourageAt(player: Player, at: number)
	courageAt[player] = at
	local untilTime = at + Chikin.COURAGE.seconds
	if at > 0 and untilTime > os.time() then
		player:SetAttribute("ChikinCourageUntil", untilTime)
	end
end

function TownChikinService.ForgetCourage(player: Player)
	courageAt[player] = nil
end

-- Studio's /townchikin: Town Chikin comes to you (so petting can be tried)
function TownChikinService.ComeTo(player: Player)
	local root = characterRoot(player)
	if root and dog then
		dog.marker.CFrame = CFrame.new(TownDog.ground(root.Position.X + 4, root.Position.Z))
	end
end

function TownChikinService.Start()
	-- No model, no Town Chikin (the Frontier and the Dungeon have none): a marker would carry a prompt on nothing
	local models = ReplicatedStorage:FindFirstChild("NpcModels")
	if not models or not models:FindFirstChild("Chikin") then
		return
	end
	local first = Chikin.TOWN.stops[1]
	local made, prompt = TownDog.new("ChikinNpc", "TownChikin", TownDog.ground(first.x, first.z), Chikin.COURAGE.petRange, Chikin.TOWN.petHoldMax)
	dog = made
	prompt.Triggered:Connect(onPet)
	task.spawn(day, made)
	task.spawn(greetLoop, made)
	Players.PlayerRemoving:Connect(function(player)
		greetedAt[tostring(player.UserId)] = nil
	end)
end

return TownChikinService
