--!strict
-- Wild fights on this client (battles part 1): "Fight" prompts on monsters, the Shop button while in the
-- wild, the fight bar (monster HP, your fighters with ability buttons, Call in, Run %), floating damage
-- numbers over the fighters, and the end screen. The server decides everything; this only shows it and
-- sends intents (StartFight, CallIn, UseAbility, RunFight, WildTravel).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Combat = require(Config:WaitForChild("Combat"))
local Party = require(Config:WaitForChild("Party"))
local Wild = require(Config:WaitForChild("Wild"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local player = Players.LocalPlayer

local BAR_MAX_WIDTH = 560
local HP_COLOR = Color3.fromRGB(90, 210, 110)
local MONSTER_HP_COLOR = Color3.fromRGB(220, 80, 70)
local TRACK_COLOR = Color3.fromRGB(25, 25, 35)
local ELITE_COLOR = Color3.fromRGB(255, 205, 60)
local STRONG_COLOR = Color3.fromRGB(255, 150, 40)
local WEAK_COLOR = Color3.fromRGB(170, 170, 180)
local HEAL_COLOR = Color3.fromRGB(120, 230, 120)
local NUMBER_RISE = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- HUD hidden while fighting so nothing gets tapped by mistake
local HUD_NAMES = { "PartyButton", "JobsButton", "BinderButton", "BuildButton", "PricesButton", "StatusRow", "ShopButton" }

local BattleController = {}

type Snapshot = {
	time: number,
	monster: { hp: number, maxHp: number, element: string, elite: boolean },
	fighters: { { id: string, hp: number, maxHp: number, element: string, abilityIn: number, signature: string?, signatureIn: number, fainted: boolean } },
	reserves: { string },
	callInFor: number,
	runIn: number,
	runChance: number,
}

type FighterView = {
	frame: Frame,
	hpFill: Frame,
	hpText: TextLabel,
	ability: TextButton,
	signature: TextButton?,
}

local screenGui: ScreenGui
local bar: Frame
local monsterName: TextLabel
local monsterHpFill: Frame
local monsterHpText: TextLabel
local fighterRow: Frame
local actionRow: Frame
local runButton: TextButton
local endScreen: Frame
local endTitle: TextLabel
local endBody: TextLabel
local shopButton: TextButton

local fighting = false
local fightNames: { [string]: string } = {}
local monsterId: string? = nil
local latest: Snapshot? = nil
local latestAt = 0 -- os.clock() when `latest` arrived, to count cooldowns down between snapshots
local fighterViews: { [string]: FighterView } = {}
local callInButtons: { TextButton } = {}
local hiddenHud: { GuiObject } = {}
local prompts: { [BasePart]: ProximityPrompt } = {}

local function elementIcon(element: string): string
	local perk = Party.PERKS[element]
	return if perk then perk.icon else ""
end

local function makeBar(parent: Instance, height: number, fillColor: Color3): (Frame, Frame, TextLabel)
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, height)
	track.BackgroundColor3 = TRACK_COLOR
	track.Parent = parent
	UIKit.corner(track, 6)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = fillColor
	fill.Parent = track
	UIKit.corner(fill, 6)
	local text = UIKit.label(track, "", Enum.Font.GothamBold, 12, UIKit.Colors.Text)
	text.Size = UDim2.fromScale(1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextStrokeTransparency = 0.5
	text.ZIndex = 3
	return track, fill, text
end

local function setBar(fill: Frame, text: TextLabel, hp: number, maxHp: number)
	fill.Size = UDim2.fromScale(math.clamp(hp / math.max(maxHp, 1), 0, 1), 1)
	text.Text = `{math.max(0, math.round(hp))} / {math.round(maxHp)}`
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Markers -------------------------------------------------------------------------------------------------

local function markerFor(id: string): BasePart?
	if id == "monster" then
		local folder = workspace:FindFirstChild("Monsters")
		return if folder and monsterId then folder:FindFirstChild(`Monster_{monsterId}`) :: BasePart? else nil
	end
	local creatures = workspace:FindFirstChild("Creatures")
	if not creatures then
		return nil
	end
	return (creatures:FindFirstChild(`Creature_{player.UserId}_{id}`) or creatures:FindFirstChild(`Creature_{player.UserId}`)) :: BasePart?
end

-- A number that floats up over a fighter and fades
local function floatText(id: string, text: string, color: Color3)
	local marker = markerFor(id)
	if not marker then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 36)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = marker
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = screenGui
	TweenService:Create(gui, NUMBER_RISE, { StudsOffset = Vector3.new(0, 7, 0) }):Play()
	TweenService:Create(label, NUMBER_RISE, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(NUMBER_RISE.Time, function()
		gui:Destroy()
	end)
end

-- Fight bar -----------------------------------------------------------------------------------------------

local function abilityLabel(name: string, seconds: number): string
	return if seconds > 0.05 then `{name}\n{math.ceil(seconds)}s` else name
end

local function buildFighters(snapshot: Snapshot)
	clear(fighterRow)
	fighterViews = {}
	for index, fighter in snapshot.fighters do
		local frame = Instance.new("Frame")
		frame.LayoutOrder = index
		frame.Size = UDim2.new(1 / math.max(#snapshot.fighters, 1), -6, 1, 0)
		frame.BackgroundColor3 = UIKit.Colors.Row
		frame.Parent = fighterRow
		UIKit.corner(frame, 8)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Cards.ELEMENTS[fighter.element] or UIKit.Colors.Accent
		stroke.Thickness = 1.5
		stroke.Parent = frame
		local name = UIKit.label(frame, `{elementIcon(fighter.element)} {fightNames[fighter.id] or "Creature"}`, Enum.Font.GothamBold, 13, UIKit.Colors.Text)
		name.Position = UDim2.fromOffset(8, 4)
		name.Size = UDim2.new(1, -16, 0, 16)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local track, fill, text = makeBar(frame, 14, HP_COLOR)
		track.Position = UDim2.fromOffset(8, 22)
		track.Size = UDim2.new(1, -16, 0, 14)

		local element = Combat.ABILITIES[fighter.element]
		local signature = if fighter.signature then Combat.SIGNATURES[fighter.signature] else nil
		local buttons = if signature then 2 else 1
		local function abilityButton(order: number, which: string): TextButton
			local button = UIKit.button(frame, "", UIKit.Colors.Accent)
			button.Position = UDim2.new((order - 1) / buttons, if order == 1 then 8 else 4, 0, 42)
			button.Size = UDim2.new(1 / buttons, -12, 0, 48)
			button.TextSize = 13
			button.TextWrapped = true
			button.Activated:Connect(function()
				Remotes.UseAbility:FireServer(fighter.id, which)
			end)
			return button
		end
		local view: FighterView = {
			frame = frame,
			hpFill = fill,
			hpText = text,
			ability = abilityButton(1, "element"),
			signature = if signature then abilityButton(2, "signature") else nil,
		}
		view.ability.Text = if element then element.name else "-"
		if view.signature and signature then
			view.signature.Text = signature.name
			view.signature.BackgroundColor3 = ELITE_COLOR:Lerp(Color3.new(0, 0, 0), 0.35)
		end
		fighterViews[fighter.id] = view
	end
end

local function buildCallIns(snapshot: Snapshot)
	for _, button in callInButtons do
		button:Destroy()
	end
	callInButtons = {}
	if snapshot.callInFor <= 0 then
		return
	end
	for index, beastId in snapshot.reserves do
		local button = UIKit.button(actionRow, `Call in {fightNames[beastId] or "card"}`, UIKit.Colors.Row)
		button.LayoutOrder = index
		button.Size = UDim2.new(0, 150, 0, 48)
		button.TextSize = 13
		button.TextWrapped = true
		button.Activated:Connect(function()
			Remotes.CallIn:FireServer(beastId)
		end)
		table.insert(callInButtons, button)
	end
end

-- Cooldowns and the call-in countdown tick down between snapshots
local function refreshTimers()
	local snapshot = latest
	if not snapshot then
		return
	end
	local elapsed = os.clock() - latestAt
	for _, fighter in snapshot.fighters do
		local view = fighterViews[fighter.id]
		if view then
			local element = Combat.ABILITIES[fighter.element]
			local wait = fighter.abilityIn - elapsed
			view.ability.Text = abilityLabel(if element then element.name else "-", wait)
			local ready = wait <= 0.05 and not fighter.fainted
			view.ability.BackgroundColor3 = if ready then UIKit.Colors.Accent else UIKit.Colors.Locked
			view.ability.AutoButtonColor = ready
			local signature = if fighter.signature then Combat.SIGNATURES[fighter.signature] else nil
			if view.signature and signature then
				local signatureWait = fighter.signatureIn - elapsed
				view.signature.Text = abilityLabel(signature.name, signatureWait)
				local signatureReady = signatureWait <= 0.05 and not fighter.fainted
				view.signature.BackgroundColor3 = if signatureReady then ELITE_COLOR:Lerp(Color3.new(0, 0, 0), 0.35) else UIKit.Colors.Locked
				view.signature.AutoButtonColor = signatureReady
			end
		end
	end
	local callInLeft = snapshot.callInFor - elapsed
	for _, button in callInButtons do
		button.Visible = callInLeft > 0
		local name = string.match(button.Text, "^Call in ([^\n]+)") or "card"
		button.Text = `Call in {name}\n{math.max(0, math.ceil(callInLeft))}s`
	end
	local runWait = snapshot.runIn - elapsed
	runButton.Text = if runWait > 0.05 then `Run {math.ceil(runWait)}s` else `Run {math.round(snapshot.runChance * 100)}%`
	runButton.BackgroundColor3 = if runWait > 0.05 then UIKit.Colors.Locked else UIKit.Colors.Danger
end

local function applySnapshot(snapshot: Snapshot)
	local fighterCount = 0
	for _ in fighterViews do
		fighterCount += 1
	end
	if fighterCount ~= #snapshot.fighters then
		buildFighters(snapshot)
	end
	if #callInButtons > 0 and (snapshot.callInFor <= 0 or #snapshot.reserves == 0) then
		buildCallIns(snapshot)
	end
	latest, latestAt = snapshot, os.clock()
	setBar(monsterHpFill, monsterHpText, snapshot.monster.hp, snapshot.monster.maxHp)
	for _, fighter in snapshot.fighters do
		local view = fighterViews[fighter.id]
		if view then
			setBar(view.hpFill, view.hpText, fighter.hp, fighter.maxHp)
			view.frame.BackgroundTransparency = if fighter.fainted then 0.6 else 0
		end
	end
	refreshTimers()
end

local function setHudHidden(hidden: boolean)
	if hidden then
		hiddenHud = {}
		for _, name in HUD_NAMES do
			local item = screenGui:FindFirstChild(name)
			if item and item:IsA("GuiObject") and item.Visible then
				item.Visible = false
				table.insert(hiddenHud, item)
			end
		end
		-- Close any open panel (binder, party...) so the fight bar is on top
		for _, child in screenGui:GetChildren() do
			if child:IsA("Frame") and child.ZIndex >= UIKit.PANEL_Z_INDEX and child ~= bar and child ~= endScreen then
				child.Visible = false
			end
		end
	else
		for _, item in hiddenHud do
			item.Visible = true
		end
		hiddenHud = {}
	end
end

local function onEvents(events: { any })
	for _, event in events do
		if event.type == "attack" and event.to then
			if event.dodged then
				floatText(event.to, "Dodge", WEAK_COLOR)
			elseif event.strength == "strong" then
				floatText(event.to, `-{event.damage} STRONG!`, STRONG_COLOR)
			elseif event.strength == "weak" then
				floatText(event.to, `-{event.damage}`, WEAK_COLOR)
			else
				floatText(event.to, `-{event.damage}`, Color3.new(1, 1, 1))
			end
		elseif event.type == "ability" then
			local ability = Combat.SIGNATURES[fightNames[event.from or ""] or ""] or nil
			local name = if ability and ability.kind == event.kind then ability.name else nil
			for _, entry in Combat.ABILITIES do
				if entry.kind == event.kind then
					name = entry.name
				end
			end
			if event.from then
				floatText(event.from, name or event.kind or "", ELITE_COLOR)
			end
			if event.damage and event.to then
				floatText(event.to, `-{event.damage}`, if event.strength == "strong" then STRONG_COLOR else Color3.new(1, 1, 1))
			end
			if event.heal and event.from then
				floatText(event.from, `+{event.heal}`, HEAL_COLOR)
			end
		elseif event.type == "run" and event.ok == false and event.kind == "failed" then
			UIController.Notify("Couldn't get away!", true, 1.5)
		elseif event.type == "callin" and event.from then
			floatText(event.from, "Joined!", HEAL_COLOR)
		end
	end
end

local function showEnd(summary: any)
	local result = summary.result
	if result == "win" then
		endTitle.Text = "Victory!"
		endTitle.TextColor3 = HEAL_COLOR
		local names = {}
		for _, beastId in (if typeof(summary.partyIds) == "table" then summary.partyIds else {}) do
			table.insert(names, fightNames[beastId] or "card")
		end
		local lines = { `+{summary.xpEach or 0} XP each: {table.concat(names, ", ")}`, string.format("+$%.2f", summary.cash or 0) }
		if typeof(summary.card) == "table" and Cards.ById[summary.card.cardId] then
			table.insert(lines, `🎴 New card: {Cards.ById[summary.card.cardId].name} (grade {summary.card.grade})`)
		end
		endBody.Text = table.concat(lines, "\n")
	elseif result == "lose" then
		endTitle.Text = "Your party fainted"
		endTitle.TextColor3 = UIKit.Colors.Danger
		endBody.Text = `Rest {math.floor(Combat.REST_SECONDS / 60)}:00 · the plaza spring heals faster`
	else
		endTitle.Text = "Got away safely"
		endTitle.TextColor3 = UIKit.Colors.Text
		endBody.Text = if typeof(summary.rested) == "table" and #summary.rested > 0 then "Fainted cards are resting." else ""
	end
	endScreen.Visible = true
	task.delay(Combat.END_SCREEN_SECONDS, function()
		if not fighting then
			endScreen.Visible = false
		end
	end)
end

local function onStarted(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.snapshot) ~= "table" then
		return
	end
	fighting = true
	monsterId = payload.monsterId
	fightNames = if typeof(payload.names) == "table" then payload.names else {}
	endScreen.Visible = false
	local species = if typeof(payload.species) == "string" then payload.species else "Monster"
	monsterName.Text = `{if payload.elite then "ELITE " else ""}{elementIcon(payload.element or "")} {species} · Lv {payload.level or 1}`
	monsterName.TextColor3 = if payload.elite then ELITE_COLOR else UIKit.Colors.Text
	fighterViews = {}
	buildFighters(payload.snapshot)
	buildCallIns(payload.snapshot)
	applySnapshot(payload.snapshot)
	setHudHidden(true)
	bar.Visible = true
	for _, prompt in prompts do
		prompt.Enabled = false
	end
end

local function onEnded(summary: any)
	fighting = false
	bar.Visible = false
	latest = nil
	setHudHidden(false)
	for marker, prompt in prompts do
		prompt.Enabled = marker:GetAttribute("Fighting") ~= true
	end
	if typeof(summary) == "table" then
		showEnd(summary)
	end
end

-- Prompts and travel --------------------------------------------------------------------------------------

local function watchMonster(marker: Instance)
	if not marker:IsA("BasePart") or prompts[marker] then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Fight"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Wild.PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	local function refresh()
		local species = marker:GetAttribute("Species")
		local level = marker:GetAttribute("Level")
		prompt.ObjectText = `{if marker:GetAttribute("Elite") then "ELITE " else ""}{if typeof(species) == "string" then species else "Monster"} · Lv {level or 1}`
		prompt.Enabled = not fighting and marker:GetAttribute("Fighting") ~= true
	end
	refresh()
	marker.AttributeChanged:Connect(refresh)
	prompt.Triggered:Connect(function()
		local id = marker:GetAttribute("MonsterId")
		if typeof(id) == "string" then
			Remotes.StartFight:FireServer(id)
		end
	end)
	prompt.Parent = marker
	prompts[marker] = prompt
end

local function build()
	screenGui = UIController.GetScreenGui()

	bar = Instance.new("Frame")
	bar.Name = "FightBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -10)
	bar.Size = UDim2.new(0.92, 0, 0, 212)
	bar.BackgroundColor3 = UIKit.Colors.Panel
	bar.BackgroundTransparency = 0.1
	bar.Visible = false
	bar.ZIndex = UIKit.PANEL_Z_INDEX + 1
	bar.Parent = screenGui
	UIKit.corner(bar, 12)
	local maxWidth = Instance.new("UISizeConstraint")
	maxWidth.MaxSize = Vector2.new(BAR_MAX_WIDTH, math.huge)
	maxWidth.Parent = bar
	UIKit.hideTouchControlsWhileVisible(bar)

	monsterName = UIKit.label(bar, "", Enum.Font.FredokaOne, 17, UIKit.Colors.Text)
	monsterName.Position = UDim2.fromOffset(12, 6)
	monsterName.Size = UDim2.new(1, -24, 0, 20)
	monsterName.TextTruncate = Enum.TextTruncate.AtEnd
	local track, fill, text = makeBar(bar, 14, MONSTER_HP_COLOR)
	track.Position = UDim2.fromOffset(12, 28)
	track.Size = UDim2.new(1, -24, 0, 14)
	monsterHpFill, monsterHpText = fill, text

	fighterRow = Instance.new("Frame")
	fighterRow.Position = UDim2.fromOffset(12, 48)
	fighterRow.Size = UDim2.new(1, -24, 0, 96)
	fighterRow.BackgroundTransparency = 1
	fighterRow.Parent = bar
	local fighterLayout = Instance.new("UIListLayout")
	fighterLayout.FillDirection = Enum.FillDirection.Horizontal
	fighterLayout.Padding = UDim.new(0, 6)
	fighterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	fighterLayout.Parent = fighterRow

	actionRow = Instance.new("Frame")
	actionRow.Position = UDim2.fromOffset(12, 152)
	actionRow.Size = UDim2.new(1, -140, 0, 52)
	actionRow.BackgroundTransparency = 1
	actionRow.Parent = bar
	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal
	actionLayout.Padding = UDim.new(0, 6)
	actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionLayout.Parent = actionRow

	runButton = UIKit.button(bar, "Run", UIKit.Colors.Danger)
	runButton.AnchorPoint = Vector2.new(1, 0)
	runButton.Position = UDim2.new(1, -12, 0, 154)
	runButton.Size = UDim2.fromOffset(116, 48)
	runButton.TextSize = 15
	runButton.Activated:Connect(function()
		Remotes.RunFight:FireServer()
	end)

	endScreen = Instance.new("Frame")
	endScreen.Name = "FightEnd"
	endScreen.AnchorPoint = Vector2.new(0.5, 0.5)
	endScreen.Position = UDim2.fromScale(0.5, 0.4)
	endScreen.Size = UDim2.fromOffset(360, 150)
	endScreen.BackgroundColor3 = UIKit.Colors.Panel
	endScreen.BackgroundTransparency = 0.05
	endScreen.Visible = false
	endScreen.ZIndex = UIKit.PANEL_Z_INDEX + 1
	endScreen.Parent = screenGui
	UIKit.corner(endScreen, 14)
	endTitle = UIKit.label(endScreen, "", Enum.Font.FredokaOne, 28, UIKit.Colors.Text)
	endTitle.Position = UDim2.fromOffset(12, 12)
	endTitle.Size = UDim2.new(1, -24, 0, 34)
	endTitle.TextXAlignment = Enum.TextXAlignment.Center
	endBody = UIKit.label(endScreen, "", Enum.Font.GothamBold, 14, UIKit.Colors.Text)
	endBody.Position = UDim2.fromOffset(12, 54)
	endBody.Size = UDim2.new(1, -24, 1, -64)
	endBody.TextWrapped = true
	endBody.TextYAlignment = Enum.TextYAlignment.Top
	endBody.TextXAlignment = Enum.TextXAlignment.Center

	-- Back to your shop while in the wild: top centre (the left HUD stack has no room left on phones)
	shopButton = UIKit.button(screenGui, "🏠 Shop", UIKit.Colors.Row)
	shopButton.Name = "ShopButton"
	shopButton.AnchorPoint = Vector2.new(0.5, 0)
	shopButton.Position = UDim2.new(0.5, 0, 0, 8)
	shopButton.Size = UDim2.fromOffset(120, 48)
	shopButton.TextSize = 17
	shopButton.Visible = false
	shopButton.Activated:Connect(function()
		Remotes.WildTravel:FireServer("home")
	end)
end

function BattleController.Start()
	build()
	Remotes.BattleStarted.OnClientEvent:Connect(onStarted)
	Remotes.BattleEvent.OnClientEvent:Connect(function(payload)
		if not fighting or typeof(payload) ~= "table" then
			return
		end
		if typeof(payload.events) == "table" then
			onEvents(payload.events)
		end
		if typeof(payload.snapshot) == "table" then
			applySnapshot(payload.snapshot)
		end
	end)
	Remotes.BattleEnded.OnClientEvent:Connect(onEnded)
	Remotes.WildTravel.OnClientEvent:Connect(function(where)
		shopButton.Visible = where == "wild" and not fighting
	end)

	local folder = workspace:WaitForChild("Monsters")
	folder.ChildAdded:Connect(watchMonster)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			prompts[child] = nil
		end
	end)
	for _, child in folder:GetChildren() do
		watchMonster(child)
	end

	local sinceTimers = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceTimers += dt
		if fighting and sinceTimers >= 0.2 then
			sinceTimers = 0
			refreshTimers()
		end
	end)
end

return BattleController
