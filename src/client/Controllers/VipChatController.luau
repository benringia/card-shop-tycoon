--!strict
-- VIP's chat tag (spec 2026-11-28-robux-round-design; Config/Vip, Util/VipRules): a gold [VIP] in front of the chat
-- lines of a player who owns VIP (their HasVIP attribute, MonetizationService). The game sets no other
-- OnIncomingMessage callback; it never yields and returns nothing for everyone else.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Vip = require(Shared:WaitForChild("Config"):WaitForChild("Vip"))
local VipRules = require(Shared:WaitForChild("Util"):WaitForChild("VipRules"))

local VipChatController = {}

function VipChatController.Start()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
		local source = message.TextSource
		if not source then
			return nil
		end
		local speaker = Players:GetPlayerByUserId(source.UserId)
		if not speaker or speaker:GetAttribute("HasVIP") ~= true then
			return nil
		end
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = VipRules.chatPrefix(message.PrefixText, Vip)
		return properties
	end
end

return VipChatController
