--!strict
-- Per-player cooldown for remotes that can be spammed.
-- Usage: local allow = RateLimiter.new(0.5); if not allow(player) then return end
local Players = game:GetService("Players")

local RateLimiter = {}

function RateLimiter.new(cooldownSeconds: number): (player: Player) -> boolean
	local lastCall: { [Player]: number } = {}

	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)

	return function(player: Player): boolean
		local now = os.clock()
		local last = lastCall[player]
		if last and now - last < cooldownSeconds then
			return false
		end
		lastCall[player] = now
		return true
	end
end

return RateLimiter
