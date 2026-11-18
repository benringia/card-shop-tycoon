--!strict
-- What the player is doing right now, so a guide never cuts in (owner 2026-11-18: "do not popup when the player is
-- currently doing something. like manning the cashier"): facts for Shared/Util/LessonRules.busyWith, read by Pish's
-- lesson visits and nudges (TutorialController) and Chikin's arrival (ChikinController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LessonRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("LessonRules"))

local ClientUtil = script.Parent :: Instance
local Controllers = (ClientUtil.Parent :: Instance):WaitForChild("Controllers")
local Hud = require(ClientUtil:WaitForChild("Hud"))
local OpeningStage = require(ClientUtil:WaitForChild("OpeningStage"))
local ScreenClear = require(ClientUtil:WaitForChild("ScreenClear"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local BattleController = require(Controllers:WaitForChild("BattleController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))
local RegisterController = require(Controllers:WaitForChild("RegisterController"))
local RegisterStationController = require(Controllers:WaitForChild("RegisterStationController"))
local WeaponRevealController = require(Controllers:WaitForChild("WeaponRevealController"))
local WindowController = require(Controllers:WaitForChild("WindowController"))

local PlayerBusy = {}

local player = Players.LocalPlayer

-- Cards and cinematics that hold the screen while they show (each made for its moment and gone after)
local POPUPS = { "LevelUpCard", "GiftWin", "StoreWin", "BlockedCard", "BossChests", "Welcome", "Prologue", "DogArrivalName" }
local SHOWS = { "BulkOpening" } -- kept, turned on while they play

local function anyShown(names: { string }): boolean
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	for _, name in names do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") and gui.Enabled then
			return true
		end
	end
	return false
end

function PlayerBusy.facts(): LessonRules.Busy
	return {
		fight = BattleController.IsFighting(),
		show = OpeningStage.isShown()
			or WeaponRevealController.IsPlaying()
			or anyShown(SHOWS)
			or player:GetAttribute("WelcomePlaying") == true,
		popup = anyShown(POPUPS) or not ScreenClear.isClear(),
		register = RegisterStationController.IsManned()
			or RegisterController.IsShowing()
			or player:GetAttribute("ManningRegister") == true,
		carrying = (tonumber(player:GetAttribute("CarryCount")) or 0) > 0,
		building = PlacementController.IsActive() or WindowController.IsActive(),
		window = UIKit.anyPanelOpen() or Hud.isTrayOpen() or player:GetAttribute("ReadingBinder") == true,
	}
end

-- What keeps the player busy now (nil: free); `allowed`: what the guide's own visit uses
function PlayerBusy.reason(allowed: { [string]: boolean }?): string?
	return LessonRules.busyWith(PlayerBusy.facts(), allowed)
end

return PlayerBusy
