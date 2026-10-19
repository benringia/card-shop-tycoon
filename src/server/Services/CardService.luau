--!strict
-- Each player's card collection: { [cardId] = { normal = n, foil = n } }.
-- Binder and quick sell build on this. No saving yet.
-- (DESIGN.md calls this CollectionService; renamed to avoid clashing with Roblox's own service.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Cards"))

export type Owned = { normal: number, foil: number }

local CardService = {}

local collections: { [Player]: { [string]: Owned } } = {}

function CardService.AddCard(player: Player, cardId: string, foil: boolean)
	local collection = collections[player]
	if not collection or not Cards.ById[cardId] then
		return
	end
	local owned = collection[cardId]
	if not owned then
		owned = { normal = 0, foil = 0 }
		collection[cardId] = owned
	end
	if foil then
		owned.foil += 1
	else
		owned.normal += 1
	end
end

function CardService.GetCollection(player: Player): { [string]: Owned }
	return collections[player] or {}
end

function CardService.Start()
	Players.PlayerAdded:Connect(function(player)
		collections[player] = {}
	end)
	Players.PlayerRemoving:Connect(function(player)
		collections[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		collections[player] = collections[player] or {}
	end
end

return CardService
