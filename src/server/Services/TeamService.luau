--!strict
-- Teams in the same world (spec 2026-11-15-teams-design, Config/Teams, Util/TeamRules): up to 4 players in this server.
-- An invite (the "Team up" prompt on another player) waits INVITE_SECONDS for its answer; joining someone on a team
-- joins that team; leaving passes the lead on and a team of one ends. Nothing is saved: a team lasts while its players
-- stay in this server. BossService asks for a player's teammates (a teammate's boss fight calls the others) and
-- BattleService for the hunting bonus (teammates near you at a monster win). Clients get their team through
-- Remotes.TeamState and draw it (TeamController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Teams = require(Shared:WaitForChild("Config"):WaitForChild("Teams"))
local TeamRules = require(Shared:WaitForChild("Util"):WaitForChild("TeamRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ServerUtil = ((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util")
local Blocked = require(ServerUtil:WaitForChild("Blocked"))
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))

local TeamService = {}

local REACH_SLACK = 8 -- studs past the prompt's range an invite still counts (they stepped back as they pressed)

local teamIdOf: { [number]: number } = {} -- userId -> team id
local teamsById: { [number]: TeamRules.Team } = {}
local nextTeamId = 0
local invites: { [number]: { [number]: number } } = {} -- invited userId -> inviter userId -> os.clock it runs out
local inviteLimit = RateLimiter.new(1)
local answerLimit = RateLimiter.new(0.5)
local leaveLimit = RateLimiter.new(1)

local function teamOf(userId: number): TeamRules.Team?
	local id = teamIdOf[userId]
	return if id then teamsById[id] else nil
end

local function words(text: string, name: string): string
	local filled = string.gsub(text, "{name}", name)
	return filled
end

local function tell(player: Player, message: string)
	Remotes.Notify:FireClient(player, message, false)
end

local function refuse(player: Player, why: string, name: string)
	Blocked.tell(player, words((Teams.REFUSALS :: any)[why] or "You can't team up right now.", name), { title = "Team" })
end

local function send(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		Remotes.TeamState:FireClient(player, teamOf(userId))
	end
end

-- Puts `team` under `id` (nil ends it) and tells everyone who was or is on it
local function store(id: number, team: TeamRules.Team?, before: { number })
	teamsById[id] = team
	for _, userId in before do
		if teamIdOf[userId] == id then
			teamIdOf[userId] = nil
		end
	end
	for _, userId in if team then team.members else {} do
		teamIdOf[userId] = id
	end
	local told: { [number]: boolean } = {}
	for _, list in { before, if team then team.members else {} } do
		for _, userId in list do
			if not told[userId] then
				told[userId] = true
				send(userId)
			end
		end
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function leave(player: Player)
	local id = teamIdOf[player.UserId]
	local team = if id then teamsById[id] else nil
	if not id or not team then
		return
	end
	local before = table.clone(team.members)
	store(id, TeamRules.remove(team, player.UserId), before)
	for _, userId in before do
		local other = Players:GetPlayerByUserId(userId)
		if other and other ~= player then
			tell(other, words(Teams.TEXT.left, player.DisplayName))
		end
	end
end

local function onInvite(player: Player, targetId: unknown)
	if typeof(targetId) ~= "number" or not inviteLimit(player) then
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	if not target then
		return
	end
	local mine, theirs = rootOf(player), rootOf(target)
	if not mine or not theirs or (mine.Position - theirs.Position).Magnitude > Teams.PROMPT.range + REACH_SLACK then
		return -- the prompt only shows up close
	end
	local fromTeam = teamOf(player.UserId)
	local ok, why = TeamRules.canInvite(fromTeam, teamOf(target.UserId), player.UserId, target.UserId, Teams)
	if not ok then
		refuse(player, why or "", target.DisplayName)
		return
	end
	invites[target.UserId] = invites[target.UserId] or {}
	invites[target.UserId][player.UserId] = os.clock() + Teams.INVITE_SECONDS
	Remotes.TeamInvite:FireClient(target, player.UserId, if fromTeam then fromTeam.members else { player.UserId }, Teams.INVITE_SECONDS)
	tell(player, `Team invite sent to {target.DisplayName}.`)
end

local function onAnswer(player: Player, fromId: unknown, join: unknown)
	if typeof(fromId) ~= "number" or typeof(join) ~= "boolean" or not answerLimit(player) then
		return
	end
	local mine = invites[player.UserId]
	local expires = if mine then mine[fromId] else nil
	if mine then
		mine[fromId] = nil
	end
	local inviter = Players:GetPlayerByUserId(fromId)
	if not join then
		if inviter then
			tell(inviter, `{player.DisplayName} can't team up right now.`)
		end
		return
	end
	if not expires or os.clock() > expires then
		refuse(player, "expired", "")
		return
	end
	if not inviter then
		refuse(player, "gone", "")
		return
	end
	if teamOf(player.UserId) then
		Blocked.tell(player, "You're on a team already. Leave it first to join another.", { title = "Team" })
		return
	end
	local id = teamIdOf[inviter.UserId]
	local team = if id then teamsById[id] else nil
	if not id or not team then
		nextTeamId += 1
		id = nextTeamId
		team = TeamRules.new(inviter.UserId)
	end
	local before = table.clone((team :: TeamRules.Team).members)
	local grown, added = TeamRules.add(team :: TeamRules.Team, player.UserId, Teams)
	if not added then
		refuse(player, "full", inviter.DisplayName)
		return
	end
	store(id :: number, grown, before)
	for _, userId in grown.members do
		local member = Players:GetPlayerByUserId(userId)
		if member and member ~= player then
			tell(member, words(Teams.TEXT.joined, player.DisplayName))
		end
	end
	tell(player, `You joined {inviter.DisplayName}'s team!`)
end

-- `player`'s teammates still in this server (not themselves)
function TeamService.MatesOf(player: Player): { Player }
	local team = teamOf(player.UserId)
	local mates = {}
	if team then
		for _, userId in team.members do
			local other = Players:GetPlayerByUserId(userId)
			if other and other ~= player then
				table.insert(mates, other)
			end
		end
	end
	return mates
end

function TeamService.AreMates(a: Player, b: Player): boolean
	local team = teamOf(a.UserId)
	return a ~= b and team ~= nil and TeamRules.has(team, b.UserId)
end

-- The hunting bonus now: teammates within BONUS_RANGE of `player` (alive, in this server), as a share to add
function TeamService.HuntBonus(player: Player): number
	local mine = rootOf(player)
	if not mine then
		return 0
	end
	local points: { TeamRules.Point } = {}
	for _, mate in TeamService.MatesOf(player) do
		local root = rootOf(mate)
		local humanoid = if mate.Character then mate.Character:FindFirstChildOfClass("Humanoid") else nil
		if root and humanoid and humanoid.Health > 0 then
			table.insert(points, { x = root.Position.X, y = root.Position.Y, z = root.Position.Z })
		end
	end
	local at = mine.Position
	return TeamRules.bonus(TeamRules.nearCount({ x = at.X, y = at.Y, z = at.Z }, points, Teams.BONUS_RANGE), Teams)
end

function TeamService.Start()
	Remotes.TeamInvite.OnServerEvent:Connect(onInvite)
	Remotes.TeamAnswer.OnServerEvent:Connect(onAnswer)
	Remotes.TeamState.OnServerEvent:Connect(function(player)
		if leaveLimit(player) then
			leave(player)
		end
	end)
	-- Teams aren't saved: leaving the server (a teleport too) leaves the team, and its invites go
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		invites[player.UserId] = nil
		for _, byInviter in invites do
			byInviter[player.UserId] = nil
		end
	end)
end

return TeamService
