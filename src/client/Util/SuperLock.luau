--!strict
-- Whether your creature's super is locked (owner 2026-11-19: "only epics and legendary super skills locked until you
-- have same element weapon"; the Prism Blade unlocks every one): the plain name of the element it needs ("Fire"), or nil
-- when the weapon in hand fits. The server decides (WeaponService.SuperScale refuses with the locked card); this only
-- draws the combat HUD's lock (Util/CombatHud) from the character's Sword attribute (WeaponService.ApplyAttributes).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared:WaitForChild("Config"):WaitForChild("Weapons"))
local ElementNamesConfig = require(Shared:WaitForChild("Config"):WaitForChild("ElementNames"))
local WeaponRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponRules"))
local ElementNames = require(Shared:WaitForChild("Util"):WaitForChild("ElementNames"))

local SuperLock = {}

-- `element`: the creature's element key; `free`: a fight whose supers need no weapon (the prologue's lent party)
function SuperLock.need(element: string?, free: boolean?): string?
	if free or not element or element == "" then
		return nil
	end
	local character = Players.LocalPlayer.Character
	local held = if character then character:GetAttribute("Sword") else nil
	if WeaponRules.superUnlocked(Weapons, if typeof(held) == "string" then held else nil, element) then
		return nil
	end
	return ElementNames.display(element, ElementNamesConfig)
end

return SuperLock
