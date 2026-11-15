--!strict
-- Teams in the same world on this client (spec 2026-11-15-teams-design, Config/Teams; owner: the team strip "at the
-- right side"): a "Team up" prompt (Y) on every other player not on your team, the invite card ("<name> wants to team
-- up!", Join team / No thanks, its seconds), the team strip at the top right (under the cash row on a phone: each
-- teammate's face and name, a crown on the leader, a green dot when they're near enough for the hunting bonus, the
-- bonus itself, Leave), and the "Join the fight?" card when a teammate starts a boss. The server decides everything;
-- the dots and the bonus here only preview its count.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Items = require(Config:WaitForChild("Items"))
local Teams = require(Config:WaitForChild("Teams"))
local TeamRules = require(Shared:WaitForChild("Util"):WaitForChild("TeamRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local TeamController = {}

local STRIP = Teams.STRIP
local TEXT = Teams.TEXT
local LILAC = { top = Color3.fromRGB(191, 160, 255), bottom = Color3.fromRGB(162, 116, 255) }
local ORANGE = { top = Color3.fromRGB(255, 179, 107), bottom = Color3.fromRGB(255, 138, 58) }
local CARD_WIDTH = 340

type Invite = { fromId: number, members: { number }, seconds: number }
type Call = { bossId: string, fromId: number, joined: { number }, seconds: number }

local player = Players.LocalPlayer
local team: TeamRules.Team? = nil
local prompts: { [Player]: ProximityPrompt } = {}
local busy = false -- in a fight: no prompts
local column: Frame -- the strip and the bonus pill under it, top right
local strip: Frame
local faces: Frame
local bonusChip: TextLabel
local invites: { Invite } = {}
local showingInvite = false
local callCard: Frame? = nil
local currentCall: Call? = nil
local headshots: { [number]: string } = {}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function nameOf(userId: number): string
	local other = Players:GetPlayerByUserId(userId)
	return if other then other.DisplayName else "Someone"
end

-- A player's face (Roblox headshot), fetched once
local function headshot(userId: number): string
	local known = headshots[userId]
	if known then
		return known
	end
	local ok, image = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	local picture = if ok and typeof(image) == "string" then image else ""
	headshots[userId] = picture
	return picture
end

-- A round face: their headshot on a soft fill, a white rim; `crown` on the leader
local function face(parent: Instance, userId: number, size: number, crown: boolean): Frame
	local holder = Instance.new("Frame")
	holder.Name = `Face{userId}`
	holder.Size = UDim2.fromOffset(size, size)
	holder.BackgroundColor3 = Color3.fromRGB(240, 222, 245)
	holder.Parent = parent
	UIKit.corner(holder, size / 2)
	UIKit.outline(holder, Color3.new(1, 1, 1), 3)
	-- their first letter until (or if never) their picture comes: Studio's test players have none
	local letter = UIKit.label(holder, string.upper(string.sub(nameOf(userId), 1, 1)), Enum.Font.FredokaOne, size * 0.5, Color3.fromRGB(91, 61, 110))
	letter.Name = "Letter"
	letter.Size = UDim2.fromScale(1, 1)
	letter.TextXAlignment = Enum.TextXAlignment.Center
	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.Size = UDim2.fromScale(1, 1)
	picture.ZIndex = letter.ZIndex + 1
	picture.Parent = holder
	UIKit.corner(picture, size / 2)
	task.spawn(function()
		local image = headshot(userId)
		picture.Image = image
		letter.Visible = image == ""
	end)
	if crown then
		local mark = Icon.make(holder, "Crown", UDim2.fromOffset(size * 0.5, size * 0.5))
		mark.Name = "Crown"
		mark.AnchorPoint = Vector2.new(0.5, 0.75)
		mark.Position = UDim2.fromScale(0.5, 0)
		mark.ZIndex = holder.ZIndex + 2
	end
	return holder
end

-- A cotton candy card (white body, coloured band with its title and seconds) near the top middle
local function card(name: string, title: string, colors: { top: Color3, bottom: Color3 }, icon: string): (Frame, Frame, TextLabel)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 72)
	frame.Size = UDim2.fromOffset(CARD_WIDTH, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.ZIndex = 40
	frame.Parent = UIController.GetScreenGui()
	UIKit.creamWindow(frame)
	frame:SetAttribute("Overlay", true)
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.Size = UDim2.new(1, 0, 0, 44)
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.ZIndex = frame.ZIndex + 1
	band.Parent = frame
	UIKit.corner(band, 18)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(colors.top, colors.bottom)
	shade.Parent = band
	local badge = Icon.make(band, icon, UDim2.fromOffset(32, 32))
	badge.Position = UDim2.fromOffset(10, 6)
	badge.ZIndex = band.ZIndex + 1
	local heading = UIKit.label(band, title, Enum.Font.FredokaOne, 20, Color3.new(1, 1, 1))
	heading.Position = UDim2.fromOffset(48, 0)
	heading.Size = UDim2.new(1, -110, 1, 0)
	heading.ZIndex = band.ZIndex + 1
	UIKit.outlined(heading, 2)
	local seconds = UIKit.label(band, "", Enum.Font.FredokaOne, 18, Color3.new(1, 1, 1))
	seconds.Name = "Seconds"
	seconds.AnchorPoint = Vector2.new(1, 0)
	seconds.Position = UDim2.new(1, -12, 0, 0)
	seconds.Size = UDim2.fromOffset(44, 44)
	seconds.TextXAlignment = Enum.TextXAlignment.Right
	seconds.ZIndex = band.ZIndex + 1
	UIKit.outlined(seconds, 2)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 50)
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.ZIndex = frame.ZIndex + 1
	body.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = body
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = frame
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	return frame, body, seconds
end

local function line(body: Frame, order: number, text: string, size: number, bold: boolean): TextLabel
	local palette = UIKit.colorsFor(body)
	local label = UIKit.label(body, text, if bold then Enum.Font.FredokaOne else Enum.Font.GothamBold, size, if bold then palette.ink else palette.inkSoft)
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.ZIndex = body.ZIndex + 1
	return label
end

local function row(body: Frame, order: number, height: number): Frame
	local holder = Instance.new("Frame")
	holder.LayoutOrder = order
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, height)
	holder.ZIndex = body.ZIndex + 1
	holder.Parent = body
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder
	return holder
end

local function button(parent: Instance, order: number, text: string, color: Color3): TextButton
	local made = UIKit.button(parent, text, color)
	made.LayoutOrder = order
	made.Size = UDim2.fromOffset(140, 48)
	made.Font = Enum.Font.FredokaOne
	made.TextSize = 18
	return made
end

-- Counts `seconds` down on `label`; true once `done()` says it's answered, false when time runs out
local function countDown(label: TextLabel, seconds: number, done: () -> boolean): boolean
	local ends = os.clock() + seconds
	while os.clock() < ends do
		if done() then
			return true
		end
		label.Text = tostring(math.ceil(ends - os.clock()))
		task.wait(0.1)
	end
	return done()
end

-- Invites, one card at a time
local function showInvites()
	if showingInvite then
		return
	end
	showingInvite = true
	while #invites > 0 do
		local invite = table.remove(invites, 1) :: Invite
		local frame, body, seconds = card("TeamInvite", "Team invite", LILAC, "Party")
		local top = row(body, 1, 70)
		face(top, invite.fromId, 64, true)
		line(body, 2, (string.gsub(TEXT.invite, "{name}", nameOf(invite.fromId))), 19, true)
		line(body, 3, TEXT.inviteLine, 13, false)
		local members = row(body, 4, 36)
		for _, userId in invite.members do
			face(members, userId, 32, false)
		end
		line(body, 5, `Team: {#invite.members} / {Teams.MAX}`, 13, false)
		local buttons = row(body, 6, 54)
		local answer: boolean? = nil
		button(buttons, 1, "Join team", UIKit.Colors.Success).Activated:Connect(function()
			answer = true
		end)
		button(buttons, 2, "No thanks", UIKit.Colors.Danger).Activated:Connect(function()
			answer = false
		end)
		countDown(seconds, invite.seconds, function()
			return answer ~= nil
		end)
		Remotes.TeamAnswer:FireServer(invite.fromId, answer == true)
		frame:Destroy()
	end
	showingInvite = false
end

local function closeCall()
	if callCard then
		callCard:Destroy()
		callCard = nil
	end
	currentCall = nil
end

-- A teammate's boss fight forming: who's in, Join the fight! / Not now, until its group starts
local function showCall(call: Call)
	local same = currentCall ~= nil and currentCall.bossId == call.bossId
	closeCall()
	currentCall = call
	local boss = Bosses.BOSSES[call.bossId]
	local trophy = Items.ITEMS[`trophy_{call.bossId}`]
	local picture = if trophy then trophy.icon else "Trophy"
	local frame, body, seconds = card("TeamFight", "Boss fight!", ORANGE, picture)
	callCard = frame
	if same then
		local scale = frame:FindFirstChildOfClass("UIScale")
		if scale then
			scale.Scale = 1 -- an update to the card already showing: no pop
		end
	end
	local art = Icon.make(body, picture, UDim2.fromOffset(84, 84))
	art.LayoutOrder = 1
	local fight = (string.gsub(TEXT.fight, "{name}", nameOf(call.fromId)))
	line(body, 2, (string.gsub(fight, "{boss}", if boss then boss.name else "boss")), 19, true)
	local joined = row(body, 3, 36)
	for _, userId in call.joined do
		face(joined, userId, 32, userId == call.fromId)
	end
	line(body, 4, `{#call.joined} in · the group starts soon`, 13, false)
	local buttons = row(body, 5, 54)
	button(buttons, 1, "Join the fight!", UIKit.Colors.Success).Activated:Connect(function()
		Remotes.TeamFight:FireServer(call.bossId)
		closeCall()
	end)
	button(buttons, 2, "Not now", UIKit.Colors.Danger).Activated:Connect(closeCall)
	task.spawn(function()
		countDown(seconds, call.seconds, function()
			return callCard ~= frame
		end)
		if callCard == frame then
			closeCall()
		end
	end)
end

-- The strip: your teammates' faces (not you), the leader's crown, the near dots, the bonus, Leave
local function drawStrip()
	for _, child in faces:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local current = team
	strip.Visible = current ~= nil
	if not current then
		return
	end
	for order, userId in current.members do
		if userId == player.UserId then
			continue
		end
		local slot = Instance.new("Frame")
		slot.Name = `Mate{userId}`
		slot.LayoutOrder = order
		slot.BackgroundTransparency = 1
		slot.Size = UDim2.fromOffset(STRIP.face + 14, STRIP.face + 16)
		slot.Parent = faces
		local round = face(slot, userId, STRIP.face, userId == current.leader)
		round.AnchorPoint = Vector2.new(0.5, 0)
		round.Position = UDim2.fromScale(0.5, 0)
		local dot = Instance.new("Frame")
		dot.Name = "Near"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(1, -4, 0, 6)
		dot.Size = UDim2.fromOffset(14, 14)
		dot.BackgroundColor3 = rgb(STRIP.near)
		dot.Visible = false
		dot.ZIndex = round.ZIndex + 3
		dot.Parent = round
		UIKit.corner(dot, 7)
		UIKit.outline(dot, Color3.new(1, 1, 1), 2)
		local name = UIKit.label(slot, nameOf(userId), Enum.Font.FredokaOne, 11, Color3.new(1, 1, 1))
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.fromScale(0.5, 1)
		name.Size = UDim2.new(1, 8, 0, 14)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextTruncate = Enum.TextTruncate.AtEnd
		UIKit.outlined(name, 1.5)
	end
end

local function rootOf(other: Player): BasePart?
	local character = other.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- The near dots and the bonus, as the server will count them at a win
local function updateNear()
	local current = team
	local mine = rootOf(player)
	if not current or not mine then
		bonusChip.Visible = false
		return
	end
	local near = 0
	for _, userId in current.members do
		local other = Players:GetPlayerByUserId(userId)
		local root = if other and other ~= player then rootOf(other) else nil
		local close = root ~= nil and (root.Position - mine.Position).Magnitude <= Teams.BONUS_RANGE
		if close then
			near += 1
		end
		local slot = faces:FindFirstChild(`Mate{userId}`)
		local dot = if slot then slot:FindFirstChild("Near", true) else nil
		if dot and dot:IsA("GuiObject") then
			dot.Visible = close
		end
	end
	local bonus = TeamRules.bonus(near, Teams)
	bonusChip.Visible = bonus > 0 -- (no team: hidden above)
	bonusChip.Text = `  {TEXT.bonus} {TeamRules.percent(bonus)}  ` -- joined, not gsub'd: "%" is special there
end

-- Top right on a computer; just under the cash row on a phone (it sits at the top right there)
local function placeStrip()
	if UIController.IsCompact() then
		local status = UIController.GetStatusRow()
		local bottom = status.AbsolutePosition.Y + status.AbsoluteSize.Y
		column.Position = UDim2.new(1, -STRIP.right, 0, bottom + 8)
	else
		column.Position = UDim2.new(1, -STRIP.right, 0, STRIP.top)
	end
end

local function buildStrip()
	-- The HUD hides this holder in fights and full-screen views; only your team decides the strip inside it (owner
	-- 2026-11-15: "the team strip should only appear when your in a team")
	local holder = Instance.new("Frame")
	holder.Name = "TeamHud"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = UIController.GetScreenGui()
	Hud.hideWith(holder)
	column = Instance.new("Frame")
	column.Name = "TeamColumn"
	column.AnchorPoint = Vector2.new(1, 0)
	column.BackgroundTransparency = 1
	column.Size = UDim2.fromOffset(0, 0)
	column.AutomaticSize = Enum.AutomaticSize.XY
	column.Parent = holder
	local stack = Instance.new("UIListLayout")
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Right
	stack.Padding = UDim.new(0, 8)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = column
	strip = Instance.new("Frame")
	strip.Name = "TeamStrip"
	strip.LayoutOrder = 1
	strip.Size = UDim2.fromOffset(0, 0)
	strip.AutomaticSize = Enum.AutomaticSize.XY
	strip.BackgroundColor3 = rgb(STRIP.fill)
	strip.BackgroundTransparency = STRIP.transparency
	strip.Visible = false
	strip.Parent = column
	UIKit.corner(strip, 18)
	local rim = UIKit.outline(strip, Color3.new(1, 1, 1), 2)
	rim.Transparency = 0.3
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = strip
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = strip
	local title = UIKit.label(strip, "Team", Enum.Font.FredokaOne, 14, Color3.new(1, 1, 1))
	title.LayoutOrder = 1
	title.Size = UDim2.fromOffset(60, 18)
	title.TextXAlignment = Enum.TextXAlignment.Center
	UIKit.outlined(title, 1.5)
	faces = Instance.new("Frame")
	faces.Name = "Faces"
	faces.LayoutOrder = 2
	faces.BackgroundTransparency = 1
	faces.Size = UDim2.fromOffset(0, 0)
	faces.AutomaticSize = Enum.AutomaticSize.XY
	faces.Parent = strip
	local room = Instance.new("UIPadding")
	room.PaddingTop = UDim.new(0, 12) -- the leader's crown sits over the top face
	room.Parent = faces
	local faceList = Instance.new("UIListLayout")
	faceList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	faceList.Padding = UDim.new(0, STRIP.gap + 6)
	faceList.SortOrder = Enum.SortOrder.LayoutOrder
	faceList.Parent = faces
	-- the bonus as its own pill under the strip (owner 2026-11-15: "move the team bonus text outside the team strip")
	bonusChip = UIKit.label(column, "", Enum.Font.FredokaOne, 14, Color3.new(1, 1, 1))
	bonusChip.Name = "Bonus"
	bonusChip.LayoutOrder = 2
	bonusChip.Size = UDim2.fromOffset(0, 28)
	bonusChip.AutomaticSize = Enum.AutomaticSize.X
	bonusChip.BackgroundColor3 = LILAC.bottom
	bonusChip.BackgroundTransparency = 0
	bonusChip.Visible = false
	UIKit.corner(bonusChip, 14)
	UIKit.outline(bonusChip, Color3.new(1, 1, 1), 2)
	UIKit.outlined(bonusChip, 1.5)
	local holder = Instance.new("Frame")
	holder.Name = "LeaveHolder"
	holder.LayoutOrder = 4
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(48, 48)
	holder:SetAttribute("SoftButtons", true)
	holder.Parent = strip
	local leave = UIKit.button(holder, "", UIKit.Colors.Danger)
	leave.Name = "Leave"
	UIKit.makeRound(leave, 40)
	leave.AnchorPoint = Vector2.new(0.5, 0.5)
	leave.Position = UDim2.fromScale(0.5, 0.5)
	local cross = Icon.make(leave, "Close", UDim2.fromScale(0.6, 0.6))
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Position = UDim2.fromScale(0.5, 0.5)
	cross.ZIndex = leave.ZIndex + 1
	leave.Activated:Connect(function()
		Remotes.TeamState:FireServer() -- leave
	end)
	placeStrip()
	UIController.OnCompact(function()
		task.defer(placeStrip)
	end)
end

local function refreshPrompts()
	local current = team
	local full = current ~= nil and #current.members >= Teams.MAX
	for other, prompt in prompts do
		prompt.Enabled = not busy and not full and not (current ~= nil and TeamRules.has(current, other.UserId))
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
	prompt.Name = "TeamUp"
	prompt.ActionText = Teams.PROMPT.text
	prompt.ObjectText = other.DisplayName
	prompt.KeyboardKeyCode = (Enum.KeyCode :: any)[Teams.PROMPT.key]
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Teams.PROMPT.range
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(Teams.PROMPT.offset[1], Teams.PROMPT.offset[2]) -- above the Challenge prompt
	prompt.Triggered:Connect(function()
		Remotes.TeamInvite:FireServer(other.UserId)
	end)
	prompt.Parent = root
	prompts[other] = prompt
	refreshPrompts()
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

function TeamController.Start()
	buildStrip()
	Remotes.TeamState.OnClientEvent:Connect(function(next: any)
		team = if typeof(next) == "table" and typeof(next.members) == "table" then next :: TeamRules.Team else nil
		drawStrip()
		updateNear()
		refreshPrompts()
	end)
	Remotes.TeamInvite.OnClientEvent:Connect(function(fromId: any, members: any, seconds: any)
		if typeof(fromId) ~= "number" then
			return
		end
		table.insert(invites, {
			fromId = fromId,
			members = if typeof(members) == "table" then members else { fromId },
			seconds = if typeof(seconds) == "number" then seconds else Teams.INVITE_SECONDS,
		})
		task.spawn(showInvites)
	end)
	Remotes.TeamFight.OnClientEvent:Connect(function(bossId: any, fromId: any, joined: any, seconds: any)
		if typeof(bossId) ~= "string" or typeof(fromId) ~= "number" or not Bosses.BOSSES[bossId] then
			return
		end
		showCall({
			bossId = bossId,
			fromId = fromId,
			joined = if typeof(joined) == "table" then joined else { fromId },
			seconds = if typeof(seconds) == "number" then seconds else Bosses.JOIN_SECONDS,
		})
	end)
	-- Fights hide the prompts (and a call card: you're busy) until they end
	Remotes.BattleStarted.OnClientEvent:Connect(function()
		busy = true
		closeCall()
		refreshPrompts()
	end)
	Remotes.BattleEnded.OnClientEvent:Connect(function()
		busy = false
		refreshPrompts()
	end)
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(other)
		local prompt = prompts[other]
		if prompt then
			prompt:Destroy()
		end
		prompts[other] = nil
	end)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			updateNear()
		end
	end)
end

return TeamController
