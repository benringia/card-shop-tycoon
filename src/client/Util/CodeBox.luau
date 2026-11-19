--!strict
-- The Store's code box (owner 2026-11-19: "yes do code box"; Config/Codes, Util/CodeRules): a card with a field to type
-- a code in, a Redeem button and the answer under them. It only sends what's typed (Remotes.RedeemCode); the server
-- checks and pays (CodeService) and answers with Remotes.CodeResult. The button waits out the server's cooldown, so a
-- try is never dropped without an answer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Codes = require(Config:WaitForChild("Codes"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local CodeRules = require(Shared:WaitForChild("Util"):WaitForChild("CodeRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UIKit = require(script.Parent:WaitForChild("UIKit"))

local CodeBox = {}

local INK = Color3.fromRGB(59, 42, 82)
local SOFT = Color3.fromRGB(122, 106, 146)
local ANSWER_WAIT = 6 -- seconds for the server's answer before the box gives up waiting

local field: TextBox? = nil
local result: TextLabel? = nil
local button: TextButton? = nil
local waiting = 0 -- the try an answer is awaited for (0: none)
local tries = 0
local listening = false

local function say(text: string, color: Color3)
	local label = result
	if label then
		label.Text = text
		label.TextColor3 = color
	end
end

local function setBusy(busy: boolean)
	local made = button
	if made then
		made.Active = not busy
		made.AutoButtonColor = not busy
		made.Text = if busy then "..." else "Redeem"
	end
end

local function redeem()
	local box = field
	if not box or waiting ~= 0 then
		return
	end
	-- the same tidy-up the server does, so nothing typed is sent that can't be a code
	if not CodeRules.normalize(box.Text, Codes.MAX_LENGTH) then
		say(if box.Text == "" then Codes.TEXT.empty else Codes.TEXT.unknown, UIStyle.CREAM.BAD)
		return
	end
	tries += 1
	local mine = tries
	waiting = mine
	setBusy(true)
	say("Checking...", SOFT)
	Remotes.RedeemCode:FireServer(box.Text)
	task.delay(ANSWER_WAIT, function()
		if waiting == mine then
			waiting = 0
			setBusy(false)
			say("No answer. Try again in a moment.", UIStyle.CREAM.BAD)
		end
	end)
end

local function onResult(ok: unknown, message: unknown)
	local mine = waiting
	if mine == 0 then
		return
	end
	say(if typeof(message) == "string" then message else "", if ok == true then UIStyle.CREAM.GOOD else UIStyle.CREAM.BAD)
	local box = field
	if ok == true and box then
		box.Text = ""
	end
	-- the next try once the server's cooldown is over
	task.delay(Codes.COOLDOWN + 0.2, function()
		if waiting == mine then
			waiting = 0
			setBusy(false)
		end
	end)
end

-- The card, in a list at `order` with its pieces at ZIndex `z` and up
function CodeBox.build(parent: Instance, order: number, z: number): Frame
	local look = Codes.BOX
	local card = Instance.new("Frame")
	card.Name = "CodeBox"
	card.LayoutOrder = order
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.Size = UDim2.new(1, -12, 0, look.height)
	card.ZIndex = z
	card.Parent = parent
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 14)
	round.Parent = card
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Color = UIStyle.BABY.lilac.fill
	rim.Thickness = 2
	rim.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = card

	local title = UIKit.label(card, "🎁 Got a code?", Enum.Font.FredokaOne, 16, INK)
	title.Size = UDim2.new(1, 0, 0, 20)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = z + 1
	local hint = UIKit.label(card, look.hint, Enum.Font.GothamBold, 10, SOFT)
	hint.Position = UDim2.fromOffset(0, 20)
	hint.Size = UDim2.new(1, 0, 0, 14)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextTruncate = Enum.TextTruncate.AtEnd
	hint.ZIndex = z + 1

	local box = Instance.new("TextBox")
	box.Name = "Code"
	box.Position = UDim2.fromOffset(0, 40)
	box.Size = UDim2.new(1, -96, 0, look.button)
	box.BackgroundColor3 = UIStyle.BABY.lilac.light
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.FredokaOne
	box.PlaceholderText = "Type a code"
	box.PlaceholderColor3 = SOFT
	box.Text = ""
	box.TextColor3 = INK
	box.TextSize = 18
	box.TextTruncate = Enum.TextTruncate.AtEnd
	box.ZIndex = z + 1
	box.Parent = card
	local boxRound = Instance.new("UICorner")
	boxRound.CornerRadius = UDim.new(0, 10)
	boxRound.Parent = box
	-- capitals as you type, never longer than the server reads
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local tidy = string.sub(string.upper(box.Text), 1, Codes.MAX_LENGTH * 2)
		if tidy ~= box.Text then
			box.Text = tidy
		end
	end)
	box.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			redeem()
		end
	end)

	local go = UIKit.button(card, "Redeem", UIKit.Colors.Accent)
	go.Name = "Redeem"
	go.AnchorPoint = Vector2.new(1, 0)
	go.Position = UDim2.new(1, 0, 0, 40)
	go.Size = UDim2.fromOffset(88, look.button)
	go.TextSize = 16
	go.ZIndex = z + 1
	go.Activated:Connect(redeem)

	local answer = UIKit.label(card, "", Enum.Font.GothamBold, 11, SOFT)
	answer.Name = "Answer"
	answer.Position = UDim2.fromOffset(0, 40 + look.button + 4)
	answer.Size = UDim2.new(1, 0, 0, 24)
	answer.TextWrapped = true
	answer.TextXAlignment = Enum.TextXAlignment.Left
	answer.TextYAlignment = Enum.TextYAlignment.Top
	answer.ZIndex = z + 1

	field, result, button = box, answer, go
	if not listening then
		listening = true
		Remotes.CodeResult.OnClientEvent:Connect(onResult)
	end
	return card
end

return CodeBox
