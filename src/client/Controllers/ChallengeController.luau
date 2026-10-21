--!strict
-- PvP challenges on this client: a "Challenge" prompt (key C) on every other player, the bet popup (presets,
-- -/+ steps up to the cap both players allow, both parties' Power) and the incoming challenge popup with a
-- countdown. The server checks everything again; this only previews and sends intents.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Pvp = require(Config:WaitForChild("Pvp"))
local PvpRules = require(Shared:WaitForChild("Util"):WaitForChild("PvpRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local player = Players.LocalPlayer

local POPUP_SIZE = Vector2.new(340, 230)

local ChallengeController = {}

local sendPopup: Frame
local sendTitle: TextLabel
local sendPower: TextLabel
local betLabel: TextLabel
local incomingPopup: Frame
local incomingTitle: TextLabel
local incomingBody: TextLabel
local incomingTimer: TextLabel
local target: Player? = nil
local bet = 0
local busy = false -- in a challenge, the queue or a fight: no prompts
local incomingToken = 0
local prompts: { [Player]: ProximityPrompt } = {}

local function number(of: Player, name: string): number
	local value = of:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function getCap(other: Player): number
	return PvpRules.getBetCap(Pvp, number(player, "Cash"), number(other, "Cash"), number(player, "Level"), number(other, "Level"))
end

local function describeBet(amount: number): string
	return if amount > 0 then `Bet ${amount}` else "Friendly (no bet)"
end

local function setBusy(value: boolean)
	busy = value
	for _, prompt in prompts do
		prompt.Enabled = not value
	end
end

local function refreshBet()
	local other = target
	if not other then
		return
	end
	local cap = getCap(other)
	bet = math.clamp(bet, 0, cap)
	betLabel.Text = `{describeBet(bet)} · max ${cap}`
end

local function popup(name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.45)
	frame.Size = UDim2.fromOffset(POPUP_SIZE.X, POPUP_SIZE.Y)
	frame.BackgroundColor3 = UIKit.Colors.Panel
	frame.Visible = false
	frame.ZIndex = UIKit.PANEL_Z_INDEX + 2
	frame.Parent = UIController.GetScreenGui()
	UIKit.corner(frame, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIKit.Colors.Accent
	stroke.Parent = frame
	UIKit.hideTouchControlsWhileVisible(frame)
	return frame
end

local function text(parent: Frame, y: number, height: number, font: Enum.Font, size: number, color: Color3): TextLabel
	local label = UIKit.label(parent, "", font, size, color)
	label.Position = UDim2.fromOffset(14, y)
	label.Size = UDim2.new(1, -28, 0, height)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextWrapped = true
	return label
end

local function button(parent: Frame, label: string, color: Color3, x: UDim, y: number, width: UDim, onClick: () -> ()): TextButton
	local b = UIKit.button(parent, label, color)
	b.Position = UDim2.new(x.Scale, x.Offset, 0, y)
	b.Size = UDim2.new(width.Scale, width.Offset, 0, 48)
	b.TextSize = 14
	b.Activated:Connect(onClick)
	return b
end

local function openSend(other: Player)
	if busy then
		return
	end
	target = other
	bet = 0
	sendTitle.Text = `Challenge {other.DisplayName}`
	sendPower.Text = `Your Power {number(player, "PartyPower")} vs {number(other, "PartyPower")}`
	refreshBet()
	sendPopup.Visible = true
end

local function buildSend()
	sendPopup = popup("ChallengeSend")
	sendPopup.Size = UDim2.fromOffset(POPUP_SIZE.X, 286)
	sendTitle = text(sendPopup, 10, 26, Enum.Font.FredokaOne, 22, UIKit.Colors.Text)
	sendPower = text(sendPopup, 38, 18, Enum.Font.GothamBold, 13, UIKit.Colors.Subtext)
	betLabel = text(sendPopup, 60, 22, Enum.Font.GothamBold, 16, UIKit.Colors.Accent)

	-- Presets: Friendly, $10, $25, $50, Max
	local presets = {}
	for _, amount in Pvp.BET_PRESETS do
		table.insert(presets, { label = if amount == 0 then "Free" else `${amount}`, amount = amount })
	end
	table.insert(presets, { label = "Max", amount = math.huge })
	local count = #presets
	for index, preset in presets do
		button(sendPopup, preset.label, UIKit.Colors.Row, UDim.new((index - 1) / count, if index == 1 then 12 else 3), 88, UDim.new(1 / count, -9), function()
			bet = if preset.amount == math.huge then (if target then getCap(target) else 0) else preset.amount
			refreshBet()
		end)
	end
	button(sendPopup, "-", UIKit.Colors.Row, UDim.new(0, 12), 142, UDim.new(0.5, -18), function()
		bet = math.max(0, bet - Pvp.BET_STEP)
		refreshBet()
	end)
	button(sendPopup, "+", UIKit.Colors.Row, UDim.new(0.5, 6), 142, UDim.new(0.5, -18), function()
		bet += Pvp.BET_STEP
		refreshBet()
	end)
	button(sendPopup, "Send", UIKit.Colors.Accent, UDim.new(0, 12), 222, UDim.new(0.5, -18), function()
		local other = target
		sendPopup.Visible = false
		if other then
			Remotes.Challenge:FireServer(other.UserId, bet)
		end
	end)
	button(sendPopup, "Cancel", UIKit.Colors.Danger, UDim.new(0.5, 6), 222, UDim.new(0.5, -18), function()
		sendPopup.Visible = false
	end)
end

local function respond(accept: boolean)
	incomingToken += 1
	incomingPopup.Visible = false
	Remotes.ChallengeRespond:FireServer(accept)
end

local function buildIncoming()
	incomingPopup = popup("ChallengeIncoming")
	incomingTitle = text(incomingPopup, 12, 28, Enum.Font.FredokaOne, 22, UIKit.Colors.Text)
	incomingBody = text(incomingPopup, 46, 60, Enum.Font.GothamBold, 14, UIKit.Colors.Subtext)
	incomingTimer = text(incomingPopup, 110, 20, Enum.Font.GothamBold, 13, UIKit.Colors.Accent)
	button(incomingPopup, "Accept", UIKit.Colors.Accent, UDim.new(0, 12), 168, UDim.new(0.5, -18), function()
		respond(true)
	end)
	button(incomingPopup, "Decline", UIKit.Colors.Danger, UDim.new(0.5, 6), 168, UDim.new(0.5, -18), function()
		respond(false)
	end)
end

local function onIncoming(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	sendPopup.Visible = false
	incomingTitle.Text = `{payload.fromName or "Someone"} challenges you!`
	incomingBody.Text = `{describeBet(if typeof(payload.bet) == "number" then payload.bet else 0)}\nYour Power {payload.yourPower or 0} vs {payload.theirPower or 0}`
	incomingPopup.Visible = true
	incomingToken += 1
	local token = incomingToken
	local seconds = if typeof(payload.seconds) == "number" then payload.seconds else Pvp.CHALLENGE_SECONDS
	task.spawn(function()
		for left = seconds, 1, -1 do
			if incomingToken ~= token then
				return
			end
			incomingTimer.Text = `Answer in {left}s`
			task.wait(1)
		end
		if incomingToken == token then
			incomingPopup.Visible = false -- no answer counts as a decline (the server times it out)
		end
	end)
end

local STATUS_TEXT = {
	sent = "Challenge sent.",
	declined = "Challenge declined.",
	expired = "No answer.",
	starting = "To the arena!",
}

local function onStatus(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local state = payload.state
	if state == "expired" or state == "cancelled" or state == "refused" or state == "declined" then
		incomingToken += 1
		incomingPopup.Visible = false
		setBusy(false)
	elseif state == "sent" or state == "queued" or state == "starting" then
		setBusy(true)
	end
	local message = if typeof(payload.message) == "string" then payload.message else STATUS_TEXT[state]
	if state == "queued" then
		local ahead = if typeof(payload.position) == "number" then payload.position - 1 else 0
		message = if ahead > 0 then `Waiting for the arena... {ahead} match{if ahead == 1 then "" else "es"} ahead` else "Waiting for the arena..."
	end
	if message then
		UIController.Notify(message, state == "refused" or state == "declined", 3)
	end
end

local function watchCharacter(other: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local old = prompts[other]
	if old then
		old:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Challenge"
	prompt.ObjectText = other.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.C
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Pvp.CHALLENGE_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = not busy
	prompt.Triggered:Connect(function()
		openSend(other)
	end)
	prompt.Parent = root
	prompts[other] = prompt
end

local function watchPlayer(other: Player)
	if other == player then
		return
	end
	other.CharacterAdded:Connect(function(character)
		watchCharacter(other, character)
	end)
	if other.Character then
		task.spawn(watchCharacter, other, other.Character)
	end
end

function ChallengeController.Start()
	buildSend()
	buildIncoming()
	Remotes.ChallengeIncoming.OnClientEvent:Connect(onIncoming)
	Remotes.ChallengeStatus.OnClientEvent:Connect(onStatus)
	-- Fights (wild or PvP) hide the prompts until they end
	Remotes.BattleStarted.OnClientEvent:Connect(function()
		sendPopup.Visible = false
		setBusy(true)
	end)
	Remotes.BattleEnded.OnClientEvent:Connect(function(summary)
		local wait = if typeof(summary) == "table" and summary.mode == "pvp" then Pvp.RETURN_SECONDS else 0
		task.delay(wait, setBusy, false)
	end)

	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(other)
		prompts[other] = nil
		if target == other then
			sendPopup.Visible = false
			target = nil
		end
	end)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
end

return ChallengeController
