--!strict
-- How each boss looks in the UI (the boss ladder and the Bag): its icon (its element's; the Prism Hydra, which has
-- every element, a gem) and the tint of the key fragments that open it (its element's colour; the Hydra's
-- UIStyle.KEY_TINT_PRISM), so every key looks different.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Cards = require(Config:WaitForChild("Cards"))
local UIStyle = require(Config:WaitForChild("UIStyle"))

local BossTints = {}

local WHITE = Color3.new(1, 1, 1)

function BossTints.icon(bossId: string): string
	local boss = Bosses.BOSSES[bossId]
	if not boss then
		return "Trophy"
	end
	return if boss.phases then "Gem" else boss.element
end

function BossTints.key(bossId: string): Color3
	local boss = Bosses.BOSSES[bossId]
	if not boss then
		return WHITE
	end
	return if boss.phases then UIStyle.KEY_TINT_PRISM else Cards.ELEMENTS[boss.element] or WHITE
end

return BossTints
