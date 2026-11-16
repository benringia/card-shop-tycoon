--!strict
-- The owner's test save (owner 2026-11-16: "is there anyway I can experience what new player experience without
-- wiping?"; Server/Util/SaveSlots): a "/slot" chat command, in every place and in the live game, that only the game's
-- owner can use (checked here on the server; anyone else's "/slot" does nothing). "/slot test" plays a separate save
-- from the start, "/slot main" goes back to the real one (never touched), "/slot reset" starts another fresh test save,
-- "/slot" alone says which one is loaded. The choice is stored (DataStore Data.SLOT_STORE) and takes effect on the
-- next join, in every place (DataService reads it before loading).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataConfig = require(Shared:WaitForChild("Config"):WaitForChild("Data"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))
local SaveSlots = require(ServerUtil:WaitForChild("SaveSlots"))

local SaveSlotService = {}

local allow = RateLimiter.new(2)

local function tell(player: Player, message: string, isError: boolean?)
	Remotes.Notify:FireClient(player, message, isError == true)
end

local function onCommand(player: Player, text: string)
	if not SaveSlots.isOwner(player.UserId, game.CreatorId, game.CreatorType.Name) or not allow(player) then
		return
	end
	local word = string.lower(string.match(text, "^/%w+%s+(%a+)") or "")
	local loaded = if DataService.IsTestSlot(player) then "your TEST save" else "your REAL save"
	if word == "" then
		tell(player, `You're playing {loaded}. /slot test, /slot main or /slot reset (then rejoin).`)
		return
	end
	local store = DataStoreService:GetDataStore(DataConfig.SLOT_STORE)
	local chosen: SaveSlots.State? = nil
	local valid = true
	local ok, err = pcall(function()
		store:UpdateAsync(tostring(player.UserId), function(raw)
			local after, known = SaveSlots.apply(SaveSlots.clean(raw), word)
			valid = known
			if not known then
				return nil -- nothing written
			end
			chosen = after
			return after
		end)
	end)
	if not valid then
		tell(player, "Use /slot test, /slot main or /slot reset.", true)
		return
	end
	if not ok or not chosen then
		warn(`[SaveSlotService] couldn't store the choice: {err}`)
		tell(player, "Couldn't save that choice. Try again in a moment.", true)
		return
	end
	local next = if (chosen :: SaveSlots.State).test then `TEST save #{(chosen :: SaveSlots.State).run}` else "REAL save"
	tell(player, `Next time you join you'll play your {next}. Rejoin now to switch (now: {loaded}).`)
end

function SaveSlotService.Start()
	-- On the test save: a reminder as you join, so it's never mistaken for the real one
	DataService.Register({
		name = "SaveSlotService",
		load = function(player)
			if DataService.IsTestSlot(player) then
				player:SetAttribute("TestSave", true)
				task.delay(8, function()
					if player.Parent then
						tell(player, "You're playing your TEST save. Type /slot main and rejoin to go back.")
					end
				end)
			end
		end,
		save = function() end,
		unload = function() end,
	})
	local command = Instance.new("TextChatCommand")
	command.Name = "OwnerSlot"
	command.PrimaryAlias = "/slot"
	command.Parent = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
	command.Triggered:Connect(function(source: TextSource, text: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		if player then
			onCommand(player, text)
		end
	end)
end

return SaveSlotService
