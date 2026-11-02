--!strict
-- Downloads the boss fight's art, sounds, moves and sword models while the loading screen is up (LoadingController;
-- Util/CombatPreload lists the ids), so the first fight's HUD isn't blank and its first swing isn't silent. Images
-- stay drawn, tiny and nearly invisible in a corner (like Util/Icon): Roblox only finishes loading an image once
-- something draws it.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CombatHudConfig = require(Config:WaitForChild("CombatHud"))
local SwordFx = require(Config:WaitForChild("SwordFx"))
local Swords = require(Config:WaitForChild("Swords"))
local AttackFx = require(Config:WaitForChild("AttackFx"))
local CombatPreload = require(Shared:WaitForChild("Util"):WaitForChild("CombatPreload"))

local CombatAssets = {}

function CombatAssets.preload()
	local ids = CombatPreload.collect(CombatHudConfig, SwordFx, Swords, AttackFx)
	local cache = Instance.new("ScreenGui")
	cache.Name = "CombatCache"
	cache.ResetOnSpawn = false
	cache.DisplayOrder = -10
	local list: { Instance } = {}
	for _, id in ids.images do
		local keep = Instance.new("ImageLabel")
		keep.BackgroundTransparency = 1
		keep.Size = UDim2.fromOffset(2, 2)
		keep.Image = id
		keep.ImageTransparency = 0.98
		keep.Parent = cache
		table.insert(list, keep)
	end
	for _, id in ids.sounds do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		table.insert(list, sound)
	end
	for _, id in ids.animations do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		table.insert(list, animation)
	end
	local models = ReplicatedStorage:FindFirstChild("WeaponModels")
	if models then
		table.insert(list, models)
	end
	cache.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	local ok, err = pcall(ContentProvider.PreloadAsync, ContentProvider, list)
	if not ok then
		warn("[CombatAssets] preload failed:", err)
	end
end

return CombatAssets
