--!strict
-- Keeps the game's sounds heard at your character while the camera is away on a stage (the 3D binder, the card
-- view), instead of at the far-off camera. Reference-counted by key: while any key is held the listener follows
-- the current character (respawns included); with none held it goes back to the camera.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local ListenAtCharacter = {}

local held: { [string]: boolean } = {}
local characterConnection: RBXScriptConnection? = nil

local function anyHeld(): boolean
	return next(held) ~= nil
end

local function follow(character: Model?)
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		SoundService:SetListener(Enum.ListenerType.ObjectCFrame, root)
	else
		SoundService:SetListener(Enum.ListenerType.Camera)
	end
end

function ListenAtCharacter.hold(key: string)
	held[key] = true
	local player = Players.LocalPlayer
	follow(player.Character)
	if not characterConnection then
		characterConnection = player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 5)
			if anyHeld() then
				follow(character)
			end
		end)
	end
end

function ListenAtCharacter.release(key: string)
	held[key] = nil
	if anyHeld() then
		return
	end
	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end
	SoundService:SetListener(Enum.ListenerType.Camera)
end

return ListenAtCharacter
