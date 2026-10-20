--!strict
-- Shows server-wide pull announcements ("n0gginss pulled a FOIL Solarion!") as system chat messages.
-- The server only sends other players' pulls, after the puller has flipped the card. Your own pulls
-- are shown by PackOpeningController at the moment you flip them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Announcements = require(Config:WaitForChild("Announcements"))
local Cards = require(Config:WaitForChild("Cards"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local CardFace = require((Controllers.Parent :: Instance):WaitForChild("Util"):WaitForChild("CardFace"))
local UIController = require(Controllers:WaitForChild("UIController"))

type Card = typeof(Cards.List[1])

local RICH_TEXT_ESCAPES = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&apos;" }

local AnnouncementController = {}

local function escape(text: string): string
	return (string.gsub(text, "[&<>\"']", RICH_TEXT_ESCAPES))
end

local function getGeneralChannel(): TextChannel?
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	return if general and general:IsA("TextChannel") then general else nil
end

function AnnouncementController.Show(displayName: string, card: Card, foil: boolean)
	local format = if foil then Announcements.FOIL_FORMAT else Announcements.NORMAL_FORMAT
	local plain = string.format(format, displayName, card.name)

	local channel = getGeneralChannel()
	if not channel then
		-- Legacy chat: fall back to a toast
		UIController.Notify(plain, false)
		return
	end
	local color = CardFace.getRarityColor(card.rarity):ToHex()
	local text = string.format(format, escape(displayName), card.name)
	channel:DisplaySystemMessage(`<font color="#{color}"><b>{text}</b></font>`)
end

function AnnouncementController.Start()
	Remotes.PullAnnouncement.OnClientEvent:Connect(function(displayName: string, cardId: string, foil: boolean)
		local card = Cards.ById[cardId]
		if card and typeof(displayName) == "string" then
			AnnouncementController.Show(displayName, card, foil == true)
		end
	end)
end

return AnnouncementController
