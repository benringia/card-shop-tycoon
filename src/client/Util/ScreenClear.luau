--!strict
-- Cinematics wait for a clear screen (owner 2026-11-13: "when a player donates then clicks OK ... the cinematic stops,
-- make the cinematic start only after the player screen is clear. same with other cinematics"; Util/ScreenClearRules):
-- a purchase dialog open (the game's own buttons call ScreenClear.prompt before prompting; Roblox's
-- PromptProductPurchaseFinished / PromptGamePassPurchaseFinished say it closed, once its OK or Cancel is pressed) or the
-- Roblox menu holds them back. ScreenClear.wait() yields till it's clear, then a short beat.
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScreenClearRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("ScreenClearRules"))

local ScreenClear = {}

local MAX_PROMPT = 120 -- seconds: a dialog that never reports closing stops holding cinematics
local BEAT = 0.4 -- seconds after it clears, so the dialog is gone from the screen
local CHECK = 0.2

local promptSince: number? = nil

local function closed()
	promptSince = nil
end
MarketplaceService.PromptProductPurchaseFinished:Connect(closed)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(closed)

-- A purchase dialog is about to open (call right before MarketplaceService:Prompt...Purchase)
function ScreenClear.prompt()
	promptSince = os.clock()
end

function ScreenClear.isClear(): boolean
	return ScreenClearRules.clear({ promptSince = promptSince, menuOpen = GuiService.MenuIsOpen, now = os.clock() }, MAX_PROMPT)
end

-- Yields till the screen is clear (and a short beat after, if it wasn't)
function ScreenClear.wait()
	if ScreenClear.isClear() then
		return
	end
	repeat
		task.wait(CHECK)
	until ScreenClear.isClear()
	task.wait(BEAT)
end

return ScreenClear
