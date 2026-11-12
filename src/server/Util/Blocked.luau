--!strict
-- A player can't do that yet (owner 2026-11-12: "if something is not happening and is not a bug, let the player know
-- what the requirements are"): the reason goes to their screen as a big locked card (client BlockedController),
-- never a silent return or only a corner toast. Every requirement refusal on the server goes through here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Blocked = {}

-- `reason`: what's needed, in words ("The Prism Hydra opens at shop level 57.")
-- `extra`: another title and icon for the card (a knockout's), a shove for the player's client to apply
function Blocked.tell(player: Player, reason: string, extra: { title: string?, icon: string?, shove: Vector3? }?)
	if player.Parent then
		Remotes.Blocked:FireClient(player, {
			reason = reason,
			title = if extra then extra.title else nil,
			icon = if extra then extra.icon else nil,
			shove = if extra then extra.shove else nil,
		})
	end
end

return Blocked
