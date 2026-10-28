--!strict
-- The Frontier's Dungeon portal (spec 2026-10-29-dungeon-final-boss-design.md), in the Frontier place only. "Enter"
-- takes one player; the group prompt forms a group the way boss gates do (2-4 players, JOIN_SECONDS to join, the leader
-- starts it early). Everyone is checked here (shop level, the Hydra open or its fragments owned, a creature ready to
-- fight), then one teleport takes them all into a reserved Dungeon server of their own (DungeonService runs it there).
-- The fragments are taken only when the Hydra fight first starts (BossService), so a lost run costs none.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Dungeon = require(Config:WaitForChild("Dungeon"))
local Frontier = require(Config:WaitForChild("Frontier"))
local Items = require(Config:WaitForChild("Items"))
local Places = require(Config:WaitForChild("Places"))
local BossRules = require(Shared:WaitForChild("Util"):WaitForChild("BossRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local BattleService = require(Services:WaitForChild("BattleService"))
local BossService = require(Services:WaitForChild("BossService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local WildService = require(Services:WaitForChild("WildService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

local DungeonGateService = {}

local PORTAL_SPOT = Vector3.new(Frontier.DUNGEON_PORTAL.x, Frontier.DUNGEON_PORTAL.y, Frontier.DUNGEON_PORTAL.z)

local lobby: { members: { Player } }? = nil -- a group forming at the portal (the first member leads)
local groupPrompt: ProximityPrompt? = nil
local allowEnter = RateLimiter.new(Bosses.START_COOLDOWN)
local allowGroup = RateLimiter.new(Bosses.START_COOLDOWN)

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

-- Why this player can't go into the Dungeon now, or nil
local function whyNot(player: Player): string?
	local boss = Bosses.BOSSES[Dungeon.BOSS]
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root or not player.Parent then
		return "You can't enter right now."
	end
	if (root.Position - PORTAL_SPOT).Magnitude > Bosses.GATE_DISTANCE * 2 then
		return "Get closer to the portal."
	end
	if not BossRules.levelReady(boss.shopLevel, EconomyService.GetLevel(player)) then
		return `The Dungeon opens at shop level {boss.shopLevel}.`
	end
	local record = BossService.GetRecord(player, Dungeon.BOSS)
	if not record then
		return "You can't enter right now."
	end
	local unlock = boss.unlock
	local owned = if unlock then ItemService.GetCount(player, unlock.item) else 0
	if unlock and not BossRules.canStart(record, unlock, owned) then
		local item = Items.ITEMS[unlock.item]
		return `Needs {unlock.count} {if item then item.name else unlock.item}s (you have {owned}). The Rift Devourer drops them.`
	end
	return BattleService.WhyNotFight(player)
end

-- One teleport for everyone: a new reserved Dungeon server, told how many to wait for
local function teleport(players: { Player })
	if Places.DUNGEON_PLACE_ID == 0 then
		for _, player in players do
			notify(player, "The Dungeon is coming soon!", false)
		end
		return
	end
	if RunService:IsStudio() then
		for _, player in players do
			notify(player, "Teleports only work in the published game. Test the run in the Dungeon window.", false)
		end
		return
	end
	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	options:SetTeleportData({ runSize = #players })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(Places.DUNGEON_PLACE_ID, players, options)
	end)
	if not ok then
		warn(`[DungeonGateService] teleport failed: {err}`)
		for _, player in players do
			notify(player, "The teleport didn't work. Try again in a moment.", true)
		end
	end
end

local function updatePrompt()
	local prompt = groupPrompt
	if not prompt then
		return
	end
	local members = if lobby then #lobby.members else 0
	prompt.ActionText = BossRules.groupPromptText(Bosses, members, false)
	prompt:SetAttribute("Members", members)
	prompt:SetAttribute("LeaderId", if lobby then lobby.members[1].UserId else nil)
end

-- Players who left the game are dropped (the next member leads); an empty group closes
local function pruneLobby()
	local current = lobby
	if not current then
		return
	end
	local present = {}
	for _, member in current.members do
		if member.Parent then
			table.insert(present, member)
		end
	end
	current.members = present
	if #present == 0 then
		lobby = nil
	end
end

-- The group goes (time up, full, or the leader starts it): those who still pass the checks teleport together
local function closeLobby(closing: { members: { Player } })
	if lobby ~= closing then
		return -- already gone
	end
	lobby = nil
	updatePrompt()
	local ready = {}
	for _, player in closing.members do
		local reason = whyNot(player)
		if reason then
			if player.Parent then
				notify(player, `You weren't let into the Dungeon: {reason}`, true)
			end
		else
			table.insert(ready, player)
		end
	end
	if #ready > 0 then
		teleport(ready)
	end
end

local function onEnter(player: Player)
	if not allowEnter(player) then
		return
	end
	if lobby and table.find(lobby.members, player) then
		notify(player, "You're in the group forming here: it goes soon (the leader can start it now with F).", true)
		return
	end
	local reason = whyNot(player)
	if reason then
		notify(player, reason, true)
		return
	end
	teleport({ player })
end

local function onGroup(player: Player)
	if not allowGroup(player) then
		return
	end
	pruneLobby()
	local current = lobby
	if current then
		if current.members[1] == player then
			closeLobby(current)
		elseif table.find(current.members, player) then
			notify(player, `Waiting for {current.members[1].DisplayName} to start ({#current.members}/{Bosses.GROUP_MAX}).`, false)
		elseif #current.members >= Bosses.GROUP_MAX then
			notify(player, "That group is full.", true)
		else
			local reason = whyNot(player)
			if reason then
				notify(player, reason, true)
				return
			end
			table.insert(current.members, player)
			updatePrompt()
			for _, member in current.members do
				notify(member, `{player.DisplayName} joined the Dungeon group ({#current.members}/{Bosses.GROUP_MAX}).`, false)
			end
			if #current.members >= Bosses.GROUP_MAX then
				closeLobby(current)
			end
		end
		return
	end
	local reason = whyNot(player)
	if reason then
		notify(player, reason, true)
		return
	end
	local created = { members = { player } }
	lobby = created
	updatePrompt()
	notify(player, `Dungeon group open: others have {Bosses.JOIN_SECONDS} s to join (F again to go now).`, false)
	task.delay(Bosses.JOIN_SECONDS, closeLobby, created)
end

function DungeonGateService.Start()
	WildService.SetDungeonHandler(onEnter)
	-- The group prompt sits on the portal ring WildService built (the plaza's "Dungeon")
	local plaza = workspace:WaitForChild("Plaza")
	local ring = plaza:WaitForChild("Dungeon") :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GroupPrompt"
	prompt.ObjectText = `The Dungeon · 2-{Bosses.GROUP_MAX} players`
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Bosses.GATE_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.UIOffset = Vector2.new(0, Bosses.GROUP_PROMPT_OFFSET)
	prompt.Parent = ring
	CollectionService:AddTag(prompt, "BossGroupPrompt") -- the leader's copy says "Start now" (BossBoardController)
	prompt.Triggered:Connect(onGroup)
	groupPrompt = prompt
	updatePrompt()
end

return DungeonGateService
