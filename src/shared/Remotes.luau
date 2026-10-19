--!strict
-- Every RemoteEvent the game uses, defined in one place.
-- The server creates them on first require; clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"OpenOrderMenu", -- server → client: owner used their order computer
	"OrderProduct", -- client → server: (productId: string)
	"Notify", -- server → client: (message: string, isError: boolean)
}

local isServer = RunService:IsServer()
local folder: Instance
if isServer then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local remotes: { [string]: RemoteEvent } = {}
for _, name in NAMES do
	if isServer then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	else
		remotes[name] = folder:WaitForChild(name) :: RemoteEvent
	end
end

return {
	OpenOrderMenu = remotes.OpenOrderMenu,
	OrderProduct = remotes.OrderProduct,
	Notify = remotes.Notify,
}
