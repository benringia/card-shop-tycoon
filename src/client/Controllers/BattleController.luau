--!strict
-- Wild fights on this client (battles part 1): "Fight" prompts on monsters, the Shop button while in the
-- wild, the fight bar (monster HP, your fighters with ability buttons, Call in, Run %), floating damage
-- numbers over the fighters, and the end screen. Boss fights add a wide HP bar at the top, banners when the boss
-- heals or enrages, and the loot on the end screen. In a group fight the bar shows your own creatures with their
-- buttons, a row with the other players' creatures and HP, and Run becomes Leave. The server decides everything; this only shows it and
-- sends intents (StartFight, CallIn, UseAbility, RunFight, WildTravel).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Cards = require(Config:WaitForChild("Cards"))
local Combat = require(Config:WaitForChild("Combat"))
local Items = require(Config:WaitForChild("Items"))
local Party = require(Config:WaitForChild("Party"))
-- The server wild map in the main game, the Frontier in the Frontier place
local Wild = require(Shared:WaitForChild("Util"):WaitForChild("Place")).getWorld()
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local player = Players.LocalPlayer

local BAR_MAX_WIDTH = 560
local BOSS_BAR_MAX_WIDTH = 640
local BANNER_SECONDS = 1.4
local END_SCREEN_HEIGHT = 150
local END_LINE_HEIGHT = 18 -- the end screen grows by this per line past the third (boss loot)
local HP_COLOR = Color3.fromRGB(90, 210, 110)
local MONSTER_HP_COLOR = Color3.fromRGB(220, 80, 70)
local TRACK_COLOR = Color3.fromRGB(25, 25, 35)
local ELITE_COLOR = Color3.fromRGB(255, 205, 60)
local STRONG_COLOR = Color3.fromRGB(255, 150, 40)
local WEAK_COLOR = Color3.fromRGB(170, 170, 180)
local HEAL_COLOR = Color3.fromRGB(120, 230, 120)
local NUMBER_RISE = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- HUD hidden while fighting so nothing gets tapped by mistake
local HUD_NAMES = { "HudSide", "HudBottom", "HudFan", "StatusRow", "ShopButton" }

local BattleController = {}

-- Fight bar layout (pixels): kept short so the fight stays visible on a landscape phone
local PAD = 8
local HEADER_HEIGHT = 44 -- monster name + its HP (not in boss fights: the top bar shows the boss)
local ALLY_ROW_HEIGHT = 30
local FIGHTER_HEIGHT = 56 -- one row per creature: name and HP on the left, ability buttons on the right
local ACTION_HEIGHT = 48
local INFO_SHARE = 0.4 -- of a creature's card: name and HP; the rest is buttons

type Snapshot = {
	time: number,
	monster: { hp: number, maxHp: number, element: string, elite: boolean },
	fighters: { { id: string, hp: number, maxHp: number, element: string, abilityIn: number, signature: string?, signatureIn: number, fainted: boolean } },
	reserves: { string },
	callInFor: number,
	swaps: boolean, -- boss fights: reserves may be brought in any time (a swap)
	swapIn: number, -- seconds until my next swap
	runIn: number,
	runChance: number,
	enemies: { { id: string, hp: number, maxHp: number, element: string, fainted: boolean } },
	allies: { { id: string, hp: number, maxHp: number, element: string, fainted: boolean, left: boolean? } }, -- group fights
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
local monsterTrack: Frame
local enemyRow: Frame -- PvP: one small HP bar per enemy creature
local enemyBars: { [string]: { fill: Frame, text: TextLabel, frame: Frame } } = {}
local allyRow: Frame -- group fights: the other players' creatures
local allyBars: { [string]: { fill: Frame, text: TextLabel, frame: Frame } } = {}
local allyNames: { [string]: string } = {} -- sim id -> "<Player> · <Card>" (from the server)
local groupFight = false
local mode = "wild" -- "wild" | "pvp"
local fighterRow: Frame
local actionRow: Frame
local runButton: TextButton
local endScreen: Frame
local countdownLabel: TextLabel -- arena: 3, 2, 1, FIGHT!
local countdownToken = 0
local endTitle: TextLabel
local endBody: TextLabel
local bossBar: Frame -- boss fights: name and HP across the top of the screen
local bossName: TextLabel
local bossHpFill: Frame
local bossHpText: TextLabel
local bossId: string? = nil -- the boss being fought (Config/Bosses id)
local shopButton: TextButton

local fighting = false
local fightNames: { [string]: string } = {}
local mySide = "a" -- which side of the fight is mine ("a" in the wild)
local markers: { [string]: BasePart } = {} -- sim fighter id -> its marker part, from the server
local latest: Snapshot? = nil
local latestAt = 0 -- os.clock() when `latest` arrived, to count cooldowns down between snapshots
local fighterViews: { [string]: FighterView } = {}
local callInButtons: { TextButton } = {}
local fighterKey = "" -- the fighter ids the bar was built for (a swap changes them)
local reserveKey = "" -- the reserve ids the call-in buttons were built for
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

-- Stack the bar's rows for this fight (no header in boss fights, the ally row only in groups) and fit its height
local function layoutBar()
	local y = PAD
	monsterName.Visible = bossId == nil
	if bossId == nil then
		monsterName.Position = UDim2.fromOffset(12, y - 2)
		monsterTrack.Position = UDim2.fromOffset(12, y + 22)
		enemyRow.Position = UDim2.fromOffset(12, y + 18)
		y += HEADER_HEIGHT
	end
	if groupFight then
		allyRow.Position = UDim2.fromOffset(12, y)
		y += ALLY_ROW_HEIGHT
	end
	fighterRow.Position = UDim2.fromOffset(12, y)
	y += FIGHTER_HEIGHT + PAD
	actionRow.Position = UDim2.fromOffset(12, y)
	runButton.Position = UDim2.new(1, -12, 0, y)
	y += ACTION_HEIGHT + PAD
	bar.Size = UDim2.new(0.92, 0, 0, y)
end

-- Markers -------------------------------------------------------------------------------------------------

local function markerFor(id: string): BasePart?
	local marker = markers[id]
	return if marker and marker.Parent then marker else nil
end

-- The server's two-sided snapshot as the bar's view: my fighters, my call-ins and run, and the enemy's first
-- fighter as "the monster" (wild fights have exactly one)
local function toView(raw: any): Snapshot
	local mine = raw.sides[mySide]
	local enemy = raw.sides[if mySide == "a" then "b" else "a"]
	local foe = enemy.fighters[1] or { hp = 0, maxHp = 1, element = "", elite = false }
	-- Group fights: side A holds everyone's creatures (each tagged with its owner); yours get buttons, the others go in
	-- the ally row. Untagged fighters (PvP) are all yours.
	local myOwner = tostring(player.UserId)
	local own, allies = {}, {}
	for _, fighter in mine.fighters do
		local owner = (fighter :: any).owner
		if not (fighter :: any).benched then -- fainted and swapped out
			table.insert(if owner == nil or owner == myOwner then own else allies, fighter)
		end
	end
	local reserves = {}
	for _, id in mine.reserves do
		if not groupFight or fightNames[id] then
			table.insert(reserves, id)
		end
	end
	return {
		time = raw.time,
		monster = { hp = foe.hp, maxHp = foe.maxHp, element = foe.element, elite = foe.elite == true },
		fighters = own,
		allies = allies,
		reserves = reserves,
		callInFor = mine.callInFor,
		swaps = mine.swaps == true,
		swapIn = if typeof(mine.swapIn) == "table" then mine.swapIn[myOwner] or 0 else 0,
		runIn = mine.runIn,
		runChance = mine.runChance,
		enemies = enemy.fighters,
	}
end

-- The server names the other players' creatures as they join the fight
local function addAllies(list: unknown)
	if typeof(list) ~= "table" then
		return
	end
	for id, name in list :: { [any]: any } do
		if typeof(id) == "string" and typeof(name) == "string" then
			allyNames[id] = name
		end
	end
end

local function addMarkers(list: unknown)
	if typeof(list) ~= "table" then
		return
	end
	for id, marker in list :: { [any]: any } do
		if typeof(id) == "string" and typeof(marker) == "Instance" and marker:IsA("BasePart") then
			markers[id] = marker
		end
	end
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
	gui.Parent = player:WaitForChild("PlayerGui") -- a BillboardGui inside another ScreenGui never draws
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

local function idsOf(list: { any }): string
	local ids = {}
	for _, entry in list do
		table.insert(ids, if typeof(entry) == "table" then entry.id else entry)
	end
	return table.concat(ids, ",")
end

local function buildFighters(snapshot: Snapshot)
	clear(fighterRow)
	fighterViews = {}
	fighterKey = idsOf(snapshot.fighters)
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
		name.Position = UDim2.fromOffset(8, 6)
		name.Size = UDim2.new(INFO_SHARE, -12, 0, 16)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local track, fill, text = makeBar(frame, 16, HP_COLOR)
		track.Position = UDim2.fromOffset(8, 30)
		track.Size = UDim2.new(INFO_SHARE, -12, 0, 16)

		local element = Combat.ABILITIES[fighter.element]
		local signature = if fighter.signature then Combat.SIGNATURES[fighter.signature] else nil
		local buttons = if signature then 2 else 1
		local function abilityButton(order: number, which: string): TextButton
			local button = UIKit.button(frame, "", UIKit.Colors.Accent)
			local share = (1 - INFO_SHARE) / buttons
			button.Position = UDim2.new(INFO_SHARE + (order - 1) * share, 0, 0, 4)
			button.Size = UDim2.new(share, -6, 0, ACTION_HEIGHT)
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
	reserveKey = idsOf(snapshot.reserves)
	if snapshot.callInFor <= 0 and not snapshot.swaps then
		return
	end
	-- Boss fights: "Bring in" (a call-in early on, later a swap for your most hurt creature)
	for index, beastId in snapshot.reserves do
		local name = fightNames[beastId] or "card"
		local button = UIKit.button(actionRow, `{if snapshot.swaps then "Bring in" else "Call in"} {name}`, UIKit.Colors.Row)
		button:SetAttribute("Card", name)
		button.LayoutOrder = index
		button.Size = UDim2.new(0, 150, 0, ACTION_HEIGHT)
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
	-- No swap wait when none of yours is standing
	local anyStanding = false
	for _, fighter in snapshot.fighters do
		anyStanding = anyStanding or not fighter.fainted
	end
	local swapLeft = if anyStanding then snapshot.swapIn - elapsed else 0
	for _, button in callInButtons do
		local name = button:GetAttribute("Card") or "card"
		if snapshot.swaps then
			button.Text = if swapLeft > 0.05 then `Bring in {name}\n{math.ceil(swapLeft)}s` else `Bring in {name}`
			button.BackgroundColor3 = if swapLeft > 0.05 then UIKit.Colors.Locked else UIKit.Colors.Row
		else
			button.Visible = callInLeft > 0
			button.Text = `Call in {name}\n{math.max(0, math.ceil(callInLeft))}s`
		end
	end
	if groupFight then
		runButton.Text = "Leave" -- in a group you just step out; the others fight on
		runButton.BackgroundColor3 = UIKit.Colors.Danger
		return
	end
	local runWait = snapshot.runIn - elapsed
	runButton.Text = if runWait > 0.05 then `Run {math.ceil(runWait)}s` else `Run {math.round(snapshot.runChance * 100)}%`
	runButton.BackgroundColor3 = if runWait > 0.05 then UIKit.Colors.Locked else UIKit.Colors.Danger
end

-- One small HP bar per other player's creature
local function buildAllies(snapshot: Snapshot)
	clear(allyRow)
	allyBars = {}
	local count = math.max(#snapshot.allies, 1)
	for index, ally in snapshot.allies do
		local holder = Instance.new("Frame")
		holder.LayoutOrder = index
		holder.Size = UDim2.new(1 / count, -6, 1, 0)
		holder.BackgroundTransparency = 1
		holder.Parent = allyRow
		local name = UIKit.label(holder, `{elementIcon(ally.element)} {allyNames[ally.id] or "Ally"}`, Enum.Font.GothamBold, 11, UIKit.Colors.Text)
		name.Size = UDim2.new(1, 0, 0, 13)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local track, fill, text = makeBar(holder, 12, HP_COLOR)
		track.Position = UDim2.fromOffset(0, 14)
		track.Size = UDim2.new(1, 0, 0, 12)
		text.TextSize = 10
		allyBars[ally.id] = { fill = fill, text = text, frame = holder }
	end
end

-- PvP: the other player's creatures as compact HP bars across the top
local function buildEnemies(snapshot: Snapshot)
	clear(enemyRow)
	enemyBars = {}
	local count = math.max(#snapshot.enemies, 1)
	for index, enemy in snapshot.enemies do
		local holder = Instance.new("Frame")
		holder.LayoutOrder = index
		holder.Size = UDim2.new(1 / count, -6, 1, 0)
		holder.BackgroundTransparency = 1
		holder.Parent = enemyRow
		local name = UIKit.label(holder, `{elementIcon(enemy.element)} {fightNames[enemy.id] or "?"}`, Enum.Font.GothamBold, 11, UIKit.Colors.Text)
		name.Size = UDim2.new(1, 0, 0, 13)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local track, fill, text = makeBar(holder, 12, MONSTER_HP_COLOR)
		track.Position = UDim2.fromOffset(0, 14)
		track.Size = UDim2.new(1, 0, 0, 12)
		text.TextSize = 10
		enemyBars[enemy.id] = { fill = fill, text = text, frame = holder }
	end
end

local function applySnapshot(snapshot: Snapshot)
	if idsOf(snapshot.fighters) ~= fighterKey then
		buildFighters(snapshot)
	end
	if snapshot.swaps and idsOf(snapshot.reserves) ~= reserveKey then
		buildCallIns(snapshot)
	elseif not snapshot.swaps and #callInButtons > 0 and (snapshot.callInFor <= 0 or #snapshot.reserves == 0) then
		buildCallIns(snapshot)
	end
	latest, latestAt = snapshot, os.clock()
	setBar(monsterHpFill, monsterHpText, snapshot.monster.hp, snapshot.monster.maxHp)
	if bossId then
		setBar(bossHpFill, bossHpText, snapshot.monster.hp, snapshot.monster.maxHp)
	end
	if mode == "pvp" then
		for _, enemy in snapshot.enemies do
			local view = enemyBars[enemy.id]
			if view then
				setBar(view.fill, view.text, enemy.hp, enemy.maxHp)
				view.frame.BackgroundTransparency = 1
			end
		end
	end
	for _, fighter in snapshot.fighters do
		local view = fighterViews[fighter.id]
		if view then
			setBar(view.hpFill, view.hpText, fighter.hp, fighter.maxHp)
			view.frame.BackgroundTransparency = if fighter.fainted then 0.6 else 0
		end
	end
	if groupFight then
		local allyCount = 0
		for _ in allyBars do
			allyCount += 1
		end
		if allyCount ~= #snapshot.allies then
			buildAllies(snapshot)
		end
		for _, ally in snapshot.allies do
			local view = allyBars[ally.id]
			if view then
				setBar(view.fill, view.text, if ally.left then 0 else ally.hp, ally.maxHp)
				for _, child in view.frame:GetDescendants() do
					if child:IsA("TextLabel") then
						child.TextTransparency = if ally.fainted or ally.left then 0.5 else 0
					end
				end
			end
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
			if child:IsA("Frame") and child.ZIndex >= UIKit.PANEL_Z_INDEX and child ~= bar and child ~= endScreen and child ~= bossBar then
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

local COUNTDOWN_POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- A word that pops up in the middle of the screen for a moment (the arena countdown's label)
local function banner(text: string, color: Color3)
	countdownToken += 1
	local token = countdownToken
	local scale = countdownLabel:FindFirstChildOfClass("UIScale") :: UIScale
	countdownLabel.Text = text
	countdownLabel.TextColor3 = color
	countdownLabel.Visible = true
	scale.Scale = 1.8
	TweenService:Create(scale, COUNTDOWN_POP, { Scale = 1 }):Play()
	task.delay(BANNER_SECONDS, function()
		if countdownToken == token then
			countdownLabel.Visible = false
		end
	end)
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
		elseif event.type == "heal" then
			if event.to and event.heal then
				floatText(event.to, `+{event.heal}`, HEAL_COLOR)
			end
			banner("Healing!", HEAL_COLOR)
		elseif event.type == "enrage" then
			banner("Enraged!", UIKit.Colors.Danger)
		end
	end
end

-- PvP result with a countdown until the server sends both players home
local function showPvpEnd(summary: any)
	local outcome = summary.outcome
	local cash = if typeof(summary.cash) == "number" then summary.cash else 0
	if outcome == "win" then
		endTitle.Text = if summary.forfeit then "Opponent left · you win!" else "You win!"
		endTitle.TextColor3 = HEAL_COLOR
	elseif outcome == "lose" then
		endTitle.Text = "You lose"
		endTitle.TextColor3 = UIKit.Colors.Danger
	else
		endTitle.Text = "Draw"
		endTitle.TextColor3 = UIKit.Colors.Text
	end
	local money = if cash > 0 then `+${cash}` elseif cash < 0 then `-${-cash}` elseif outcome == "draw" then "Bets returned" else "Friendly match"
	local opponent = if typeof(summary.opponentName) == "string" then ` vs {summary.opponentName}` else ""
	local seconds = if typeof(summary.returnIn) == "number" then summary.returnIn else 10
	endScreen.Visible = true
	task.spawn(function()
		for left = seconds, 1, -1 do
			if fighting then
				return -- a new fight started
			end
			endBody.Text = `{money}{opponent}\nGoing home in {left}...`
			task.wait(1)
		end
		if not fighting then
			endScreen.Visible = false
		end
	end)
end

-- "12:34"
local function clock(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- What a boss win gave (summary.boss from BossService)
local function bossLines(boss: any): { string }
	local lines = {}
	if boss.firstClear then
		table.insert(lines, "🏆 First clear!")
	end
	for _, entry in (if typeof(boss.items) == "table" then boss.items else {}) do
		local item = Items.ITEMS[entry.item]
		if item then
			local icon = if string.match(item.icon, "^%a") then "" else `{item.icon} ` -- emoji icons only
			table.insert(lines, `{icon}+{entry.count} {item.name}`)
		end
	end
	if boss.bonus then
		table.insert(lines, "🎁 Daily bonus!")
	end
	if boss.carried then
		table.insert(lines, "Carried: smaller loot (deal 10% of the damage or take 15% of the hits for full loot)")
	end
	if boss.flagged then
		table.insert(lines, "Too fast for drops this time")
	elseif boss.reduced then
		table.insert(lines, "Reduced drops (many wins today or a much stronger party)")
	end
	if typeof(boss.lootIn) == "number" and boss.lootIn > 0 then
		table.insert(lines, `Full loot again in {clock(boss.lootIn)}`)
	end
	return lines
end

local function showEnd(summary: any)
	endScreen.Size = UDim2.fromOffset(360, END_SCREEN_HEIGHT)
	if summary.mode == "pvp" then
		showPvpEnd(summary)
		return
	end
	local result = summary.result
	if result == "win" then
		endTitle.Text = "Victory!"
		endTitle.TextColor3 = HEAL_COLOR
		local names = {}
		for _, beastId in (if typeof(summary.partyIds) == "table" then summary.partyIds else {}) do
			table.insert(names, fightNames[`a:{beastId}`] or "card")
		end
		local lines = { `+{summary.xpEach or 0} XP each: {table.concat(names, ", ")}`, string.format("+$%.2f", summary.cash or 0) }
		if typeof(summary.shards) == "number" and summary.shards > 0 then
			table.insert(lines, `✨ +{summary.shards} Star Shard{if summary.shards == 1 then "" else "s"}`)
		end
		if typeof(summary.card) == "table" and Cards.ById[summary.card.cardId] then
			local found = Cards.ById[summary.card.cardId]
			table.insert(lines, if found.set == "Frontier" then `✨ FRONTIER CARD: {found.name}!` else `🎴 New card: {found.name} (grade {summary.card.grade})`)
		end
		if typeof(summary.boss) == "table" then
			for _, line in bossLines(summary.boss) do
				table.insert(lines, line)
			end
		end
		endScreen.Size = UDim2.fromOffset(360, END_SCREEN_HEIGHT + math.max(0, #lines - 3) * END_LINE_HEIGHT)
		endBody.Text = table.concat(lines, "\n")
	elseif result == "lose" then
		endTitle.Text = "Your party fainted"
		endTitle.TextColor3 = UIKit.Colors.Danger
		local spring = if require(Shared:WaitForChild("Util"):WaitForChild("Place")).isFrontier() then "the entrance spring" else "the plaza spring"
		endBody.Text = `Rest {math.floor(Combat.REST_SECONDS / 60)}:00 · {spring} heals faster`
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

-- Big numbers in the middle of the screen before an arena fight starts
local function showCountdown(seconds: number)
	countdownToken += 1
	local token = countdownToken
	local scale = countdownLabel:FindFirstChildOfClass("UIScale") :: UIScale
	task.spawn(function()
		for left = seconds, 0, -1 do
			if countdownToken ~= token or not fighting then
				countdownLabel.Visible = false
				return
			end
			countdownLabel.Text = if left > 0 then tostring(left) else "FIGHT!"
			countdownLabel.TextColor3 = if left > 0 then Color3.new(1, 1, 1) else ELITE_COLOR
			countdownLabel.Visible = true
			scale.Scale = 1.8
			TweenService:Create(scale, COUNTDOWN_POP, { Scale = 1 }):Play()
			task.wait(if left > 0 then 1 else 0.8)
		end
		if countdownToken == token then
			countdownLabel.Visible = false
		end
	end)
end

local function onStarted(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.snapshot) ~= "table" then
		return
	end
	fighting = true
	mySide = if payload.side == "b" then "b" else "a"
	markers = {}
	addMarkers(payload.markers)
	fightNames = if typeof(payload.names) == "table" then payload.names else {}
	allyNames = {}
	addAllies(payload.allies)
	groupFight = payload.group == true
	allyBars = {}
	clear(allyRow)
	local view = toView(payload.snapshot)
	endScreen.Visible = false
	local species = if typeof(payload.species) == "string" then payload.species else "Monster"
	mode = if payload.mode == "pvp" then "pvp" else "wild"
	if mode == "pvp" then
		local bet = if typeof(payload.bet) == "number" and payload.bet > 0 then ` · bet ${payload.bet}` else " · Friendly"
		monsterName.Text = `⚔ vs {payload.opponentName or "Opponent"}{bet}`
		monsterName.TextColor3 = UIKit.Colors.Text
	else
		monsterName.Text = `{if payload.elite then "ELITE " else ""}{elementIcon(payload.element or "")} {species} · Lv {payload.level or 1}`
		monsterName.TextColor3 = if payload.elite then ELITE_COLOR else UIKit.Colors.Text
	end
	local boss = if mode == "wild" and typeof(payload.boss) == "string" then Bosses.BOSSES[payload.boss] else nil
	bossId = if boss then payload.boss else nil
	if boss then
		monsterName.Text = `BOSS {elementIcon(boss.element)} {boss.name}`
		monsterName.TextColor3 = UIKit.Colors.Danger
		bossName.Text = `{elementIcon(boss.element)} {boss.name} · Lv {boss.level}`
	end
	bossBar.Visible = boss ~= nil
	monsterTrack.Visible = mode == "wild" and boss == nil -- a boss's HP is the bar at the top
	enemyRow.Visible = mode == "pvp"
	allyRow.Visible = groupFight -- group fights are boss fights: the HP bar is at the top, this row takes its place
	runButton.Visible = mode == "wild"
	layoutBar()
	if mode == "pvp" then
		buildEnemies(view)
	end
	if typeof(payload.startsIn) == "number" and payload.startsIn > 0 then
		showCountdown(payload.startsIn)
	end
	fighterViews = {}
	buildFighters(view)
	buildCallIns(view)
	applySnapshot(view)
	setHudHidden(true)
	bar.Visible = true
	for _, prompt in prompts do
		prompt.Enabled = false
	end
end

local function onEnded(summary: any)
	fighting = false
	bar.Visible = false
	bossBar.Visible = false
	bossId = nil
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
	-- Bosses start at their arena gate, never from a prompt on them
	if not marker:IsA("BasePart") or prompts[marker] or marker:GetAttribute("Boss") ~= nil then
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
	bar.Size = UDim2.new(0.92, 0, 0, 160) -- layoutBar fits it to each fight
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
	monsterTrack = track

	enemyRow = Instance.new("Frame")
	enemyRow.Position = UDim2.fromOffset(12, 24)
	enemyRow.Size = UDim2.new(1, -24, 0, 26)
	enemyRow.BackgroundTransparency = 1
	enemyRow.Visible = false
	enemyRow.Parent = bar
	local enemyLayout = Instance.new("UIListLayout")
	enemyLayout.FillDirection = Enum.FillDirection.Horizontal
	enemyLayout.Padding = UDim.new(0, 6)
	enemyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	enemyLayout.Parent = enemyRow

	allyRow = Instance.new("Frame")
	allyRow.Size = UDim2.new(1, -24, 0, ALLY_ROW_HEIGHT - 4)
	allyRow.BackgroundTransparency = 1
	allyRow.Visible = false
	allyRow.Parent = bar
	local allyLayout = Instance.new("UIListLayout")
	allyLayout.FillDirection = Enum.FillDirection.Horizontal
	allyLayout.Padding = UDim.new(0, 6)
	allyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	allyLayout.Parent = allyRow

	fighterRow = Instance.new("Frame")
	fighterRow.Size = UDim2.new(1, -24, 0, FIGHTER_HEIGHT)
	fighterRow.BackgroundTransparency = 1
	fighterRow.Parent = bar
	local fighterLayout = Instance.new("UIListLayout")
	fighterLayout.FillDirection = Enum.FillDirection.Horizontal
	fighterLayout.Padding = UDim.new(0, 6)
	fighterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	fighterLayout.Parent = fighterRow

	actionRow = Instance.new("Frame")
	actionRow.Size = UDim2.new(1, -140, 0, ACTION_HEIGHT)
	actionRow.BackgroundTransparency = 1
	actionRow.Parent = bar
	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal
	actionLayout.Padding = UDim.new(0, 6)
	actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionLayout.Parent = actionRow

	runButton = UIKit.button(bar, "Run", UIKit.Colors.Danger)
	runButton.AnchorPoint = Vector2.new(1, 0)
	runButton.Size = UDim2.fromOffset(116, ACTION_HEIGHT)
	runButton.TextSize = 15
	runButton.Activated:Connect(function()
		Remotes.RunFight:FireServer()
	end)

	countdownLabel = UIKit.label(screenGui, "", Enum.Font.FredokaOne, 96, Color3.new(1, 1, 1))
	countdownLabel.Name = "FightCountdown"
	countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	countdownLabel.Position = UDim2.fromScale(0.5, 0.38)
	countdownLabel.Size = UDim2.fromOffset(400, 120)
	countdownLabel.TextXAlignment = Enum.TextXAlignment.Center
	countdownLabel.TextStrokeTransparency = 0.2
	countdownLabel.Visible = false
	countdownLabel.ZIndex = UIKit.PANEL_Z_INDEX + 2
	Instance.new("UIScale").Parent = countdownLabel

	-- Boss HP at the very top, just under the Roblox top bar (MainGui keeps the inset)
	bossBar = Instance.new("Frame")
	bossBar.Name = "BossBar"
	bossBar.AnchorPoint = Vector2.new(0.5, 0)
	bossBar.Position = UDim2.new(0.5, 0, 0, 4)
	bossBar.Size = UDim2.new(0.6, 0, 0, 46)
	bossBar.BackgroundColor3 = UIKit.Colors.Panel
	bossBar.BackgroundTransparency = 0.1
	bossBar.Visible = false
	bossBar.ZIndex = UIKit.PANEL_Z_INDEX + 1
	bossBar.Parent = screenGui
	UIKit.corner(bossBar, 12)
	local bossWidth = Instance.new("UISizeConstraint")
	bossWidth.MaxSize = Vector2.new(BOSS_BAR_MAX_WIDTH, math.huge)
	bossWidth.Parent = bossBar
	bossName = UIKit.label(bossBar, "", Enum.Font.FredokaOne, 16, UIKit.Colors.Danger)
	bossName.Position = UDim2.fromOffset(12, 3)
	bossName.Size = UDim2.new(1, -24, 0, 18)
	bossName.TextXAlignment = Enum.TextXAlignment.Center
	bossName.TextTruncate = Enum.TextTruncate.AtEnd
	local bossTrack, bossFill, bossText = makeBar(bossBar, 18, MONSTER_HP_COLOR)
	bossTrack.Position = UDim2.fromOffset(12, 23)
	bossTrack.Size = UDim2.new(1, -24, 0, 18)
	bossHpFill, bossHpText = bossFill, bossText
	bossHpText.TextSize = 14

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
		addMarkers(payload.markers)
		addAllies(payload.allies)
		if typeof(payload.events) == "table" then
			onEvents(payload.events)
		end
		if typeof(payload.snapshot) == "table" and typeof(payload.snapshot.sides) == "table" then
			applySnapshot(toView(payload.snapshot))
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
