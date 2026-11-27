--!strict
-- The one gate in front of every dev command (spec docs/superpowers/specs/2026-11-27-live-admin-creator-design.md):
-- gathers Util/DevRules' facts for a player and answers whether a command may run. DevService's panel remote asks it
-- before running anything; every service's dev function asks it again. It fails closed: the owner is the game's
-- creator (Util/SaveSlots), the test save is the attribute the server set when that save loaded (SaveSlotService), so
-- nothing a client says counts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AdminPanel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AdminPanel"))
local Util = script.Parent :: Instance
local Blocked = require(Util:WaitForChild("Blocked"))
local DevRules = require(Util:WaitForChild("DevRules"))
local SaveSlots = require(Util:WaitForChild("SaveSlots"))

local DevAccess = {}

-- What DevRules decides from, for this player now
function DevAccess.facts(player: Player): DevRules.Facts
	return {
		studio = RunService:IsStudio(),
		owner = SaveSlots.isOwner(player.UserId, game.CreatorId, game.CreatorType.Name),
		testSlot = player:GetAttribute("TestSave") == true,
		players = #Players:GetPlayers(),
		privateOwner = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == player.UserId,
	}
end

-- Whether a dev function of `scope` ("own" by default) may run for this player. No player: Studio only
function DevAccess.can(player: Player?, scope: DevRules.Scope?): boolean
	if not player then
		return RunService:IsStudio()
	end
	local ok = DevRules.check(DevAccess.facts(player), scope or "own")
	return ok
end

-- Whether the command `alias` may run for this player, and why not
function DevAccess.check(player: Player, alias: string): (boolean, DevRules.Reason?)
	return DevRules.check(DevAccess.facts(player), DevRules.scope(AdminPanel, alias))
end

-- A refusal's locked card; anyone but the owner gets nothing (only an exploit can send them here)
function DevAccess.refuse(player: Player, reason: DevRules.Reason?)
	local words = if reason and reason ~= "notOwner" then AdminPanel.REFUSE[reason] else nil
	if words then
		Blocked.tell(player, words, { title = "Admin", icon = "🛠" })
	end
end

return DevAccess
