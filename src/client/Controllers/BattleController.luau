--!strict
-- Wild fights on this client (battles part 1): "Fight" prompts on monsters, the Shop button while in the
-- wild, the fight bar (monster HP, your fighters with ability buttons, Call in, Run %), floating damage
-- numbers over the fighters, and the end screen. Boss fights add a wide HP bar at the top, banners when the boss
-- heals or enrages, and the loot on the end screen. In a group fight the bar shows your own creatures with their
-- buttons, a row with the other players' creatures and HP, and Run becomes Leave. The server decides everything; this only shows it and
-- sends intents (StartFight, CallIn, UseAbility, RunFight, WildTravel).
-- Boss fights put you in the fight (spec 2026-11-02-you-in-the-fight-design): the bar gives way to the combat HUD
-- (Util/CombatHud: your HP and your creature's, Attack / Dodge / Skill / Pet / Swap / Run) and SwordController runs
-- the sword; on PC Click attacks, Shift dodges, E is the sword skill, R the pet skill, 1-3 swap in a rested card.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Dungeon = require(Config:WaitForChild("Dungeon"))
local Cards = require(Config:WaitForChild("Cards"))
local Combat = require(Config:WaitForChild("Combat"))
local Items = require(Config:WaitForChild("Items"))
local Party = require(Config:WaitForChild("Party"))
local CardArtConfig = require(Config:WaitForChild("CardArt"))
local SuperFxConfig = require(Config:WaitForChild("SuperFx"))
local CombatHudConfig = require(Config:WaitForChild("CombatHud"))
local CardArt = require(Shared:WaitForChild("Util"):WaitForChild("CardArt"))
local PartyRules = require(Shared:WaitForChild("Util"):WaitForChild("PartyRules"))
-- The server wild map in the main game, the Frontier in the Frontier place
local Wild = require(Shared:WaitForChild("Util"):WaitForChild("Place")).getWorld()
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CombatHud = require(ClientUtil:WaitForChild("CombatHud"))
local HpBar = require(ClientUtil:WaitForChild("HpBar"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local HitFx = require(ClientUtil:WaitForChild("HitFx"))
local ElementFx = require(ClientUtil:WaitForChild("ElementFx"))
local RingFx = require(ClientUtil:WaitForChild("RingFx"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local MonsterController = require(Controllers:WaitForChild("MonsterController"))
local CreatureController = require(Controllers:WaitForChild("CreatureController"))
local DebuffFx = require(ClientUtil:WaitForChild("DebuffFx"))
local FightFx = require(ClientUtil:WaitForChild("FightFx"))
local CombatAssets = require(ClientUtil:WaitForChild("CombatAssets"))
local SwordController = require(Controllers:WaitForChild("SwordController"))
local Swords = require(Config:WaitForChild("Swords"))
local SwordFx = require(Config:WaitForChild("SwordFx"))
local DamagePop = require(Shared:WaitForChild("Util"):WaitForChild("DamagePop"))
local AttackFx = require(Config:WaitForChild("AttackFx"))
local UIController = require(Controllers:WaitForChild("UIController"))
local PartyController = require(Controllers:WaitForChild("PartyController"))
local PartyBarController = require(Controllers:WaitForChild("PartyBarController"))
local SwapKeys = require(Shared:WaitForChild("Util"):WaitForChild("SwapKeys"))
local SuperCinematic = require(ClientUtil:WaitForChild("SuperCinematic"))
local SkillCinematic = require(ClientUtil:WaitForChild("SkillCinematic"))
local BinderController = require(Controllers:WaitForChild("BinderController"))
local VictoryScreen = require(ClientUtil:WaitForChild("VictoryScreen"))
local DefeatScreen = require(ClientUtil:WaitForChild("DefeatScreen"))
local DefeatRules = require(Shared:WaitForChild("Util"):WaitForChild("DefeatRules"))
local Defeat = require(Config:WaitForChild("Defeat"))
local FightToast = require(ClientUtil:WaitForChild("FightToast"))
local VictoryRules = require(Shared:WaitForChild("Util"):WaitForChild("VictoryRules"))
local Victory = require(Config:WaitForChild("Victory"))

local player = Players.LocalPlayer

local BAR_MAX_WIDTH = 560
local BOSS_BAR_MAX_WIDTH = 640
local BOSS_BAR_TOP = 6 -- pixels from the very top of the screen
local BOSS_BAR_PHONE_MARGIN = 190 -- phones: the boss bar keeps this clear on each side (the Roblox menu buttons)
local BANNER_SECONDS = 1.4
local MONSTER_ID = "b:m" -- the monster's sim id (side B, as the server names it)
local INTRO_FLY = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HP_COLOR = Color3.fromRGB(90, 210, 110)
local MONSTER_HP_COLOR = Color3.fromRGB(220, 80, 70)
local TRACK_COLOR = Color3.fromRGB(25, 25, 35)
local ELITE_COLOR = Color3.fromRGB(255, 205, 60)
local STRONG_COLOR = Color3.fromRGB(255, 150, 40)
local CRIT_COLOR = Color3.fromRGB(199, 155, 255) -- a Haggle critical hit
local WEAK_COLOR = Color3.fromRGB(170, 170, 180)
local HEAL_COLOR = Color3.fromRGB(120, 230, 120)
local SHIELD_COLOR = Color3.fromRGB(150, 210, 255)
local POISON_COLOR = Color3.fromRGB(140, 230, 90)
local BURN_COLOR = Color3.fromRGB(255, 140, 50)
local NUMBER_LIFT = 4 -- studs over a fighter a damage number starts
-- HUD hidden while fighting so nothing gets tapped by mistake
local HUD_NAMES = { "HudSide", "HudBottom", "HudFan", "StatusRow", "ReturnToTown" } -- the Wild's pill sits in its holder

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
	fighters: { { id: string, hp: number, maxHp: number, element: string, abilityIn: number, signature: string?, superMeter: number, fainted: boolean, perk: { kind: string, value: number }? } },
	reserves: { string },
	benched: { string }, -- yours that fainted and were swapped out (the party strip shows them face down)
	callInFor: number,
	swaps: boolean, -- boss fights: reserves may be brought in any time (a swap)
	swapIn: number, -- seconds until my next swap
	runIn: number,
	runChance: number,
	enemies: { { id: string, hp: number, maxHp: number, element: string, fainted: boolean } },
	allies: { { id: string, hp: number, maxHp: number, element: string, fainted: boolean, left: boolean? } }, -- group fights
	adds: { { id: string, hp: number, maxHp: number, element: string, fainted: boolean } }, -- a boss's adds
	bossShield: number, -- HP the boss's shield still absorbs
	me: any?, -- boss fights: your player fighter (hp, maxHp, down, out)
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
local packFight = false -- a Dungeon room: several monsters, one small HP bar each (the PvP row)
local conquered: Frame? = nil -- the full-screen "DUNGEON CONQUERED"
local fighterRow: Frame
local actionRow: Frame
local runButton: TextButton
local countdownLabel: TextLabel -- arena: 3, 2, 1, FIGHT!
local countdownToken = 0
-- The foe's bar across the top (owner 2026-11-04, design A): a boss's plate or a monster's slim bar; each fight points
-- bossBar, bossName, bossHp and bossHpText at the one it uses
type TopBar = { frame: Frame, name: TextLabel, hp: HpBar.Bar, text: TextLabel }
local plate: TopBar
local slim: TopBar
local plateCrest: TextLabel -- the boss's element in the plate's ring (a phase change swaps it)
local plateTitle: TextLabel
local slimTag: TextLabel -- ELITE
local bossBar: Frame
local bossName: TextLabel
local bossHp: HpBar.Bar
local bossHpText: TextLabel
local addsRow: Frame -- boss fights: its adds' HP, under the boss bar
local addBars: { [string]: { fill: Frame, text: TextLabel, frame: Frame } } = {}
local bossId: string? = nil -- the boss being fought (Config/Bosses id)
local shopButton: TextButton
local introCard: Frame -- boss intro: the boss's name and title in the middle of the screen
local introName: TextLabel
local introTitle: TextLabel
local introToken = 0
local bossMusic: Sound? = nil

local fighting = false
local fightFx: FightFx.Dispatcher? = nil -- this fight's attack pictures
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
local combatHud: CombatHud.Hud? = nil -- boss and wild fights: the controls and HP instead of the bar (PvP keeps the bar)
local combatWild = false -- the combat HUD is a wild monster fight's
local combatSword = false -- the player fights in it with their sword (boss fights; wild ones once they have one)
local foeElite = false -- this fight's monster is an elite (bigger: a bigger sword target)
local COMBAT_ACTION = "BossCombat"
local COMBAT_KEYS = { Enum.KeyCode.LeftShift, Enum.KeyCode.E, Enum.KeyCode.R, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }

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
	local adds = {}
	for _, fighter in enemy.fighters do
		if fighter.id ~= MONSTER_ID and (bossId or combatWild) then
			table.insert(adds, fighter) -- a boss's adds, or a Dungeon room's other monsters
		end
	end
	-- Group fights: side A holds everyone's creatures (each tagged with its owner); yours get buttons, the others go in
	-- the ally row. Untagged fighters (PvP) are all yours.
	local myOwner = tostring(player.UserId)
	local own, allies, benched = {}, {}, {}
	local me = nil
	for _, fighter in mine.fighters do
		local owner = (fighter :: any).owner
		if (fighter :: any).player then
			me = if owner == myOwner then fighter else me
			continue -- boss fights: the players themselves (yours shows on the combat HUD)
		elseif (fighter :: any).benched then -- fainted and swapped out
			if owner == nil or owner == myOwner then
				table.insert(benched, fighter.id)
			end
		else
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
		adds = adds,
		bossShield = if typeof(enemy.shield) == "number" then enemy.shield else 0,
		fighters = own,
		allies = allies,
		reserves = reserves,
		benched = benched,
		callInFor = mine.callInFor,
		swaps = mine.swaps == true,
		swapIn = if typeof(mine.swapIn) == "table" then mine.swapIn[myOwner] or 0 else 0,
		runIn = mine.runIn,
		runChance = mine.runChance,
		enemies = enemy.fighters,
		me = me,
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

-- An add's marker can arrive just after the message naming it: wait for it in the Monsters folder
local function addMonsterMarkers(list: unknown)
	if typeof(list) ~= "table" then
		return
	end
	local folder = workspace:FindFirstChild("Monsters")
	for id, monsterId in list :: { [any]: any } do
		if folder and typeof(id) == "string" and typeof(monsterId) == "string" and not markers[id] then
			task.spawn(function()
				local marker = folder:WaitForChild(`Monster_{monsterId}`, 2)
				if marker and marker:IsA("BasePart") then
					markers[id] = marker
				end
			end)
		end
	end
end

-- A marker made the moment its creature joined (a swap, a call-in) arrives as nil: find it by its name (Util/MarkerNames)
local function addMarkers(list: unknown, names: unknown)
	if typeof(list) == "table" then
		for id, marker in list :: { [any]: any } do
			if typeof(id) == "string" and typeof(marker) == "Instance" and marker:IsA("BasePart") then
				markers[id] = marker
			end
		end
	end
	local folder = workspace:FindFirstChild("Creatures")
	if typeof(names) ~= "table" or not folder then
		return
	end
	for id, name in names :: { [any]: any } do
		if typeof(id) == "string" and typeof(name) == "string" and not markerFor(id) then
			task.spawn(function()
				local marker = folder:WaitForChild(name, 3)
				if marker and marker:IsA("BasePart") then
					markers[id] = marker
				end
			end)
		end
	end
end

-- Damage numbers pop (Util/DamagePop, AttackFx.NUMBERS): each bursts in big and settles, rises, drifts a little to one
-- side so numbers landing together don't sit on each other, and fades; one loop moves them all
type FloatingNumber = { gui: BillboardGui, label: TextLabel, stroke: UIStroke, scale: UIScale, style: string, born: number, drift: number }
local floating: { FloatingNumber } = {}
local floatingBound = false

local function stepNumbers()
	local now = os.clock()
	local keep = {}
	for _, number in floating do
		local t = now - number.born
		if t >= DamagePop.life(number.style, AttackFx.NUMBERS) then
			number.gui:Destroy()
			continue
		end
		local pose = DamagePop.at(t, number.style, AttackFx.NUMBERS)
		local progress = t / DamagePop.life(number.style, AttackFx.NUMBERS)
		number.gui.StudsOffset = Vector3.new(number.drift * progress, NUMBER_LIFT + pose.rise, 0)
		number.scale.Scale = pose.scale
		number.label.Rotation = pose.rotation
		number.label.TextTransparency = 1 - pose.alpha
		number.stroke.Transparency = 1 - pose.alpha
		table.insert(keep, number)
	end
	floating = keep
end

-- A number that pops over a fighter (style: "normal" | "crit" | "strong" | "weak" | "heal" | "tick"; big: a crit)
local function floatText(id: string, text: string, color: Color3, big: boolean?, style: string?)
	local marker = markerFor(id)
	if not marker then
		return
	end
	local kind = style or (if big then "crit" else "normal")
	local gui = Instance.new("BillboardGui")
	gui.Size = if kind == "crit" then UDim2.fromOffset(220, 58) else UDim2.fromOffset(150, 40)
	gui.StudsOffset = Vector3.new(0, NUMBER_LIFT, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = marker
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.AnchorPoint = Vector2.new(0.5, 0.5) -- pops from its middle
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
	-- White on top shading into the colour, with a thick dark outline: reads on any background
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.65), color)
	gradient.Rotation = 90
	gradient.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if kind == "crit" then 3 else 2.2
	stroke.Color = color:Lerp(Color3.new(0, 0, 0), 0.8)
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = label
	gui.Parent = player:WaitForChild("PlayerGui") -- a BillboardGui inside another ScreenGui never draws
	local drift = AttackFx.NUMBERS.DRIFT
	table.insert(floating, { gui = gui, label = label, stroke = stroke, scale = scale, style = kind, born = os.clock(), drift = (math.random() * 2 - 1) * drift })
	if not floatingBound then
		floatingBound = true
		RunService.RenderStepped:Connect(stepNumbers)
	end
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
				local full = fighter.superMeter >= 1
				view.signature.Text = if full then signature.name else `{signature.name}\n{math.floor(fighter.superMeter * 100)}%`
				local signatureReady = full and not fighter.fainted
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

-- A boss's adds as small HP bars under the boss bar
local addsKey = ""
local function buildAdds(snapshot: Snapshot)
	clear(addsRow)
	addBars = {}
	addsKey = idsOf(snapshot.adds)
	addsRow.Visible = #snapshot.adds > 0
	for index, add in snapshot.adds do
		local holder = Instance.new("Frame")
		holder.LayoutOrder = index
		holder.Size = UDim2.new(1 / math.max(#snapshot.adds, 1), -6, 1, 0)
		holder.BackgroundTransparency = 1
		holder.Parent = addsRow
		local name = UIKit.label(holder, `{elementIcon(add.element)} {if bossId then "Spawn" else fightNames[add.id] or "Monster"}`, Enum.Font.GothamBold, 11, UIKit.Colors.Text)
		name.Size = UDim2.new(1, 0, 0, 13)
		local track, fill, text = makeBar(holder, 12, MONSTER_HP_COLOR)
		track.Position = UDim2.fromOffset(0, 14)
		track.Size = UDim2.new(1, 0, 0, 12)
		text.TextSize = 10
		addBars[add.id] = { fill = fill, text = text, frame = holder }
	end
end

-- Your creature on the field (the first one standing)
local function myCreature(snapshot: Snapshot): any?
	for _, fighter in snapshot.fighters do
		if not fighter.fainted then
			return fighter
		end
	end
	return snapshot.fighters[1]
end

-- Wild fights: a second creature of yours standing on the field (a called-in one)
local function secondCreature(snapshot: Snapshot, lead: any?): any?
	for _, fighter in snapshot.fighters do
		if fighter ~= lead and not fighter.fainted then
			return fighter
		end
	end
	return nil
end

-- Boss fights' party strip (owner 2026-11-05, option A, look C): each party slot's card and what its key does now
local function partyTiles(snapshot: Snapshot): { CombatHud.PartyTile }
	local tiles = {}
	local beasts = BinderController.GetBeasts()
	local tileArt = if UIKit.isPhone() then CombatHudConfig.PARTY_STRIP.PHONE_TILE else CombatHudConfig.PARTY_STRIP.TILE
	-- The ones that fainted and were swapped out count as fainted fighters (they're face down, not resting)
	local roster: { { id: string, fainted: boolean } } = {}
	for _, fighter in snapshot.fighters do
		table.insert(roster, { id = fighter.id, fainted = fighter.fainted })
	end
	for _, id in snapshot.benched do
		table.insert(roster, { id = id, fainted = true })
	end
	for _, slot in SwapKeys.party(PartyController.GetSlots(), Party.PARTY_SIZE, snapshot.reserves, roster, snapshot.swaps, snapshot.swapIn) do
		local beast = beasts[slot.beastId]
		local card = if beast then Cards.ById[beast.cardId] else nil
		local name = fightNames[slot.simId] or (if card then card.name else nil)
		table.insert(tiles, {
			slot = slot.slot,
			simId = slot.simId,
			name = name or "Card",
			art = if name then CardArt.pick(name, tileArt, CardArtConfig) else nil,
			color = if card then Cards.ELEMENTS[card.element] or Color3.new(0.3, 0.3, 0.3) else Color3.new(0.3, 0.3, 0.3),
			state = slot.state,
		})
	end
	return tiles
end

-- The combat HUD's picture of a snapshot, and the pet skill, signature and swap cooldowns
local function updateHud(hud: CombatHud.Hud, snapshot: Snapshot)
	local me = snapshot.me
	local creature = myCreature(snapshot)
	local second = if combatWild then secondCreature(snapshot, creature) else nil
	local reserves = {}
	for _, id in snapshot.reserves do
		local name = fightNames[id]
		table.insert(reserves, { id = id, name = name or "Card", hp = 0, maxHp = 0, art = if name then CardArt.pick(name, 80, CardArtConfig) else nil })
	end
	hud.update({
		playerHp = if me then me.hp elseif combatSword then 0 else 1,
		playerMax = if me then me.maxHp elseif combatSword then Combat.PLAYER_HP else 1,
		down = me ~= nil and me.down == true,
		out = me ~= nil and me.out == true,
		creatureId = if creature then creature.id else "",
		creatureName = if creature then fightNames[creature.id] or "Creature" else "Creature",
		creatureArt = if creature and fightNames[creature.id]
			then CardArt.pick(fightNames[creature.id], CombatHudConfig.PORTRAIT.SIZE, CardArtConfig)
			else nil,
		creatureHp = if creature then creature.hp else 0,
		creatureMax = if creature then creature.maxHp else 1,
		hasSignature = creature ~= nil and creature.signature ~= nil,
		creatureElement = if creature then creature.element else "",
		perkText = if creature and creature.perk and Party.PERKS[creature.element]
			then `{Party.PERKS[creature.element].icon} {creature.perk.kind}: {PartyRules.describeFight(creature.perk)}`
			else nil,
		perkColor = if creature then Cards.ELEMENTS[creature.element] else nil,
		petMove = if creature and Combat.ABILITIES[creature.element] then Combat.ABILITIES[creature.element].name else "Pet move",
		signatureMove = if creature and creature.signature and Combat.SIGNATURES[creature.signature]
			then Combat.SIGNATURES[creature.signature].name
			else nil,
		reserves = reserves,
		party = if snapshot.swaps then partyTiles(snapshot) else nil,
		secondName = if second then fightNames[second.id] or "Creature" else nil,
		secondHp = if second then second.hp else nil,
		secondMax = if second then second.maxHp else nil,
		callInFor = if combatWild then snapshot.callInFor else nil,
		runChance = if combatWild then snapshot.runChance else nil,
	})
	if combatWild then
		-- The Pet button acts for whichever creature on the field is ready first (usePet), so its wait is the soonest
		local soonest, meter = math.huge, 0
		for _, fighter in snapshot.fighters do
			if not fighter.fainted then
				soonest = math.min(soonest, fighter.abilityIn)
				meter = math.max(meter, if fighter.signature then fighter.superMeter else 0)
			end
		end
		hud.setCooldown("pet", latestAt + (if soonest < math.huge then soonest else 0), Combat.ABILITY_COOLDOWN)
		hud.setMeter("signature", meter)
		hud.setCooldown("run", latestAt + snapshot.runIn, Combat.RUN_RETRY_SECONDS)
		return
	end
	local express = if creature and creature.perk and creature.perk.kind == "Express" then creature.perk.value else 0
	SwordController.SetSkillScale(1 - express) -- Express: the sword skill recharges faster too
	if creature then
		hud.setCooldown("pet", latestAt + creature.abilityIn, Combat.ABILITY_COOLDOWN * (1 - express))
		hud.setMeter("signature", creature.superMeter)
	end
	hud.setCooldown("swap", latestAt + snapshot.swapIn, Combat.BOSS_SWAP_SECONDS)
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
	if bossId or combatWild then
		bossHp.set(snapshot.monster.hp, snapshot.monster.maxHp)
		bossHpText.Text = `{math.max(0, math.round(snapshot.monster.hp))} / {math.round(snapshot.monster.maxHp)}`
		if snapshot.bossShield > 0 then
			bossHpText.Text ..= ` + {math.round(snapshot.bossShield)} shield`
		end
		if idsOf(snapshot.adds) ~= addsKey then
			buildAdds(snapshot)
		end
		for _, add in snapshot.adds do
			local view = addBars[add.id]
			if view then
				setBar(view.fill, view.text, add.hp, add.maxHp)
				view.frame.Visible = not add.fainted
			end
		end
	end
	if mode == "pvp" or packFight then
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
	if combatHud then
		updateHud(combatHud, snapshot)
	end
end

-- Camera shake (the roar, boss moments): a small random offset on top of the camera every frame for a moment
local shakeUntil, shakeStuds = 0, 0
local function shake(seconds: number, studs: number)
	shakeUntil = math.max(shakeUntil, os.clock() + seconds)
	shakeStuds = studs
end

local function stopMusic()
	local music = bossMusic
	bossMusic = nil
	if music then
		TweenService:Create(music, TweenInfo.new(Bosses.MUSIC_FADE), { Volume = 0 }):Play()
		task.delay(Bosses.MUSIC_FADE, function()
			music:Destroy()
		end)
	end
end

local function playMusic()
	stopMusic()
	if Bosses.MUSIC_ID == "" then
		return
	end
	local music = Instance.new("Sound")
	music.SoundId = `rbxassetid://{Bosses.MUSIC_ID}`
	music.Looped = true
	music.Volume = Bosses.MUSIC_VOLUME
	music.Parent = SoundService
	music:Play()
	bossMusic = music
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
			if child:IsA("Frame") and child.ZIndex >= UIKit.PANEL_Z_INDEX and child ~= bar and child ~= bossBar then
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
local CONQUERED_COLOR = Color3.fromRGB(255, 205, 80)
local CONQUERED_FADE = TweenInfo.new(0.6)
local CONQUERED_SECONDS = 4

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

local PLAYER_DAMAGE_COLOR = Color3.fromRGB(Swords.PLAYER_DAMAGE_COLOR[1], Swords.PLAYER_DAMAGE_COLOR[2], Swords.PLAYER_DAMAGE_COLOR[3])

-- A player's sword hit: their numbers in gold, sparks, a star burst (a ring too on a big one: the dash slash, or your
-- finisher) and a flash on what they hit, and the dash slash's cut lines; yours also freezes your swing a moment
-- (hit-stop) and shakes the camera, longer and harder for the finisher and the skill
local function swordHit(event: any)
	local marker = markerFor(event.to)
	local mine = event.from == `a:@{player.UserId}`
	local big = if mine then SwordController.IsBigHit(event.kind) else event.kind == "Skill"
	if marker then
		HitFx.sparks(marker.Position + Vector3.new(0, 3, 0))
		local attacker = Players:GetPlayerByUserId(tonumber(string.sub(event.from or "", 4)) or 0)
		local character = if attacker then attacker.Character else nil
		local slash = SwordController.SlashOf(character)
		local tint, element = SwordController.HitLook(character)
		local model = MonsterController.GetModel(marker)
		-- sized to the foe (owner 2026-11-08: bigger on bosses)
		local size = slash.scale * HitFx.scaleFor(model)
		local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		local at = (if root then SwordController.HitPoint(event.to, root.Position) else nil) or marker.Position + Vector3.new(0, 3, 0)
		-- Your own cuts burst as the blade landed (SwordController's reach check); everyone else's, every dash slash
		-- (on each foe it reached) and yours the reach check missed burst here
		if not mine or event.kind == "Skill" or not SwordController.HitSoundJustPlayed() then
			-- the packs' slash streaks in the weapon's colour with its element's particles (owner 2026-11-08), bigger on
			-- big hits
			HitFx.impact(at, size * (if big then SwordFx.IMPACT.big else 1), tint, element)
			if big then
				HitFx.ring(at, SwordFx.RING.size * size, tint)
			end
		end
		if event.kind == "Skill" and not SwordController.SkillLook(character) then
			HitFx.cutLines(at, size, tint) -- the dash slash's; a round 1 sword's skill draws its own (SwordSkillFx)
		end
		if model then
			HitFx.flash(model, Color3.new(1, 1, 1), SwordFx.FLASH_SECONDS, 0.35)
		end
	end
	if mine then
		-- The freeze already played when your own reach check connected (SwordController); a hit it missed freezes now
		local anims = SwordController.GetAnims()
		if anims and not SwordController.HitSoundJustPlayed() then
			anims.hitStop(if big then SwordFx.HIT_STOP.big else SwordFx.HIT_STOP.cut)
		end
		-- The finisher and the dash slash shake harder (sword-moves round)
		local strength = if big then SwordFx.SHAKE.skill else SwordFx.SHAKE.cut
		shake(strength.seconds, strength.studs)
		if not SwordController.HitSoundJustPlayed() then
			SwordController.PlayHit(big) -- your reach check missed it: the server's hit still sounds
		end
	end
end

-- The attack pictures for this fight (Util/FightFx): creatures charge, then their element's attack lands with the hit.
-- Every fight picture is checked again first, in case the loading screen's download failed
local function newFightFx(): FightFx.Dispatcher
	CombatAssets.ensureFight()
	return FightFx.new({
		marker = markerFor,
		creature = CreatureController.GetFightView,
		setCharging = CreatureController.SetCharging,
		pose = CreatureController.Pose,
		dash = CreatureController.Dash,
		blink = CreatureController.Blink,
		monster = MonsterController.GetFightView,
		playClip = MonsterController.PlayClip,
	})
end

-- A boss's debuff on a player in the fight (Util/DebuffFx): its effect on their character, and on yours the HUD's chip
-- and badge; going down takes it off; a Poison or Burn tick flashes them
local function showDebuff(event: any, me: string)
	local id = event.to
	if typeof(id) ~= "string" or string.sub(id, 1, 3) ~= "a:@" then
		return
	end
	local who = Players:GetPlayerByUserId(tonumber(string.sub(id, 4)) or 0)
	local character = if who then who.Character else nil
	if event.type == "debuff" and typeof(event.kind) == "string" and typeof(event.seconds) == "number" then
		if character then
			DebuffFx.show(character, event.kind, event.seconds)
		end
		if id == me and combatHud then
			combatHud.setDebuff(event.kind, event.seconds)
		end
	elseif event.type == "down" then
		if character then
			DebuffFx.clear(character)
		end
		if id == me and combatHud then
			combatHud.setDebuff(nil)
		end
	elseif event.type == "attack" and (event.kind == "Poison" or event.kind == "Burn") and character then
		DebuffFx.flash(character, event.kind)
	end
end

-- While your super's cinematic plays: the fight HUD out and your sword held (Util/SuperCinematic)
local function hideForSuper(hidden: boolean)
	if combatHud then
		combatHud.setVisible(not hidden)
	end
	SwordController.Pause(hidden)
end

-- Your own creature's super (spec 2026-11-05-super-moves-design): its cast plays the cinematic on your screen, its
-- landing the impact beat, a fizzle (it fainted first) cuts back at once
local function onSuperEvent(event: any)
	local marker = if typeof(event.from) == "string" then markerFor(event.from) else nil
	local view = if marker then CreatureController.GetFightView(marker) else nil
	if not view or not view.mine then
		return
	end
	if event.type == "cast" then
		local look = SuperFxConfig.LOOKS[event.look]
		if not look then
			return
		end
		local name = fightNames[event.from] or look.card
		local seconds = tonumber(event.seconds) or SuperFxConfig.TIERS[look.tier].windup
		SkillCinematic.stop() -- your skill's camera moment gives the camera back first (else the super keeps it stuck)
		SuperCinematic.play({
			look = event.look,
			tier = look.tier,
			grade = view.grade or "C",
			cardName = look.card,
			art = CardArt.pick(name, 320, CardArtConfig),
			color = Color3.fromRGB(look.color[1], look.color[2], look.color[3]),
			creature = view.root,
			height = view.height,
			target = if typeof(event.to) == "string" then markerFor(event.to) else nil,
			seconds = seconds,
			protect = tonumber(event.protect) or seconds + Combat.SUPER_PROTECT_TAIL,
			hideHud = hideForSuper,
		})
	elseif event.type == "ability" then
		SuperCinematic.impact()
	elseif event.type == "fizzle" then
		SuperCinematic.cut()
	end
end

local function onEvents(events: { any })
	if fightFx then
		-- Pictures only: a broken effect must never stop the damage numbers and HUD below
		local ok, err = pcall(fightFx.onEvents, events)
		if not ok then
			warn("[BattleController] fight effect failed:", err)
		end
	end
	local me = `a:@{player.UserId}`
	for _, event in events do
		showDebuff(event, me)
		if typeof(event.look) == "string" then
			local ok, err = pcall(onSuperEvent, event)
			if not ok then
				warn("[BattleController] super cinematic failed:", err)
			end
		end
		if event.type == "attack" and event.to and typeof(event.from) == "string" and string.sub(event.from, 1, 3) == "a:@" then
			if event.crit then
				floatText(event.to, `CRIT -{event.damage}`, CRIT_COLOR, true)
			else
				floatText(event.to, `-{event.damage}`, PLAYER_DAMAGE_COLOR)
			end
			swordHit(event)
		elseif event.type == "attack" and event.to == me and (event.kind == "Poison" or event.kind == "Burn") then
			-- A debuff's damage each second: its own colour, no flinch or shake
			floatText(event.to, `-{event.damage}`, if event.kind == "Poison" then POISON_COLOR else BURN_COLOR, false, "tick")
		elseif event.type == "attack" and event.to == me and not event.dodged then
			-- A boss hit you
			floatText(event.to, `-{event.damage}`, UIKit.Colors.Danger, false, "strong")
			shake(SwordFx.SHAKE.hurt.seconds, SwordFx.SHAKE.hurt.studs)
			local anims = SwordController.GetAnims()
			if anims then
				anims.play("flinch")
			end
		elseif event.type == "ring" and typeof(event.x) == "number" then
			RingFx.show({
				shape = event.kind,
				x = event.x,
				y = event.y,
				z = event.z,
				dirX = event.dirX,
				dirZ = event.dirZ,
				radius = event.radius,
				length = event.length,
				halfAngle = event.halfAngle,
				warning = event.seconds or 1,
			})
			if event.to == me then
				SwordController.PlaySound("ring")
			end
		elseif event.type == "down" and event.to == me then
			SwordController.Kneel()
			banner("Down!", UIKit.Colors.Danger)
		elseif event.type == "getUp" and event.to == me then
			SwordController.GetUp()
		elseif event.type == "out" and event.to == me then
			banner("You're out: watching", UIKit.Colors.Danger)
		elseif event.type == "attack" and event.to then
			if event.dodged then
				floatText(event.to, "Dodge", WEAK_COLOR, false, "weak")
			elseif event.crit then
				floatText(event.to, `CRIT -{event.damage}`, CRIT_COLOR, true)
			elseif event.strength == "strong" then
				floatText(event.to, `-{event.damage} STRONG!`, STRONG_COLOR, false, "strong")
			elseif event.strength == "weak" then
				floatText(event.to, `-{event.damage}`, WEAK_COLOR, false, "weak")
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
				floatText(event.to, `-{event.damage}`, if event.strength == "strong" then STRONG_COLOR else Color3.new(1, 1, 1), false, "strong")
			end
			if event.heal and event.from then
				floatText(event.from, `+{event.heal}`, HEAL_COLOR, false, "heal")
			end
		elseif event.type == "regen" and typeof(event.to) == "string" and string.sub(event.to, 1, 3) == "a:@" and event.heal then
			-- A Grade S Healing Rain tick on a player (creatures' ticks show through FightFx)
			floatText(event.to, `+{event.heal}`, HEAL_COLOR, false, "heal")
		elseif event.type == "swordHeal" and event.to and event.heal then
			-- A weapon's heal perk (the Verdant Blade's every 4th hit) on the creature
			floatText(event.to, `+{event.heal}`, HEAL_COLOR, false, "heal")
		elseif event.type == "swordErupt" and event.to then
			-- The Magma Halberd's Eruption on the foe (its extra hit shows as a sword hit of its own)
			local marker = markerFor(event.to)
			if marker then
				local erupt = SwordFx.ERUPT
				local tint = Color3.fromRGB(erupt.color[1], erupt.color[2], erupt.color[3])
				local at = marker.Position + Vector3.new(0, 3, 0)
				HitFx.burst(at, erupt.size, tint)
				HitFx.ring(at, erupt.ring, tint)
			end
		elseif event.type == "swordChain" and event.to then
			-- The Storm Reaper's Chain Lightning: a burst on the foe, a bolt from it to each foe it arcs to
			local marker = markerFor(event.to)
			if marker then
				local chain = SwordFx.CHAIN
				local tint = Color3.fromRGB(chain.color[1], chain.color[2], chain.color[3])
				local at = marker.Position + Vector3.new(0, 3, 0)
				HitFx.burst(at, chain.size, tint)
				HitFx.ring(at, chain.ring, tint)
				for _, id in (if typeof(event.arcs) == "table" then event.arcs else {}) :: { any } do
					local other = if typeof(id) == "string" then markerFor(id) else nil
					if other then
						ElementFx.bolt(at, other.Position + Vector3.new(0, 3, 0), tint, chain.boltSeconds)
					end
				end
			end
		elseif event.type == "swordExecute" and event.to then
			-- The Rift Reaper's Reap on a foe under 30% of its HP
			local marker = markerFor(event.to)
			if marker then
				local reap = SwordFx.EXECUTE
				local tint = Color3.fromRGB(reap.color[1], reap.color[2], reap.color[3])
				local at = marker.Position + Vector3.new(0, 3, 0)
				HitFx.burst(at, reap.size, tint)
				HitFx.ring(at, reap.ring, tint)
			end
		elseif event.type == "run" and event.ok == false then
			-- Owner 2026-11-09: say when getting away fails. The fight's centre banner (a toast sits under the fight
			-- buttons): a failed roll, the retry wait still running, or a fight you can't run from
			if event.kind == "failed" then
				banner("Couldn't get away!", UIKit.Colors.Danger)
			elseif event.kind == "wait" then
				local left = if typeof(event.left) == "number" then math.max(1, math.ceil(event.left)) else nil
				banner(if left then `Not yet! Run again in {left}s` else "Not yet!", UIKit.Colors.Danger)
			elseif event.kind == "none" then
				banner("You can't run from this fight!", UIKit.Colors.Danger)
			end
		elseif event.type == "callin" and event.from then
			floatText(event.from, "Joined!", HEAL_COLOR)
		elseif event.type == "heal" then
			if event.to and event.heal then
				floatText(event.to, `+{event.heal}`, HEAL_COLOR, false, "heal")
			end
			banner("Healing!", HEAL_COLOR)
			shake(Bosses.PHASE_SHAKE.seconds, Bosses.PHASE_SHAKE.studs)
		elseif event.type == "enrage" then
			banner("Enraged!", UIKit.Colors.Danger)
			shake(Bosses.PHASE_SHAKE.seconds, Bosses.PHASE_SHAKE.studs)
		elseif event.type == "shield" then
			banner("Ice shield!", SHIELD_COLOR)
			shake(Bosses.PHASE_SHAKE.seconds, Bosses.PHASE_SHAKE.studs)
		elseif event.type == "shieldBreak" then
			banner("Shield broken!", ELITE_COLOR)
			shake(Bosses.PHASE_SHAKE.seconds, Bosses.PHASE_SHAKE.studs)
		elseif event.type == "thunderclap" then
			banner("Thunderclap!", STRONG_COLOR)
			shake(Bosses.PHASE_SHAKE.seconds, Bosses.PHASE_SHAKE.studs)
		elseif event.type == "stun" and event.to then
			floatText(event.to, "Stunned", WEAK_COLOR)
		elseif event.type == "spawn" then
			banner("Rift Spawn!", UIKit.Colors.Danger)
			shake(Bosses.PHASE_SHAKE.seconds, Bosses.PHASE_SHAKE.studs)
		elseif event.type == "phase" and typeof(event.kind) == "string" then
			-- The final boss changes element (the server lights that head on its model)
			banner(`{elementIcon(event.kind)} {event.kind} phase!`, Cards.ELEMENTS[event.kind] or Color3.new(1, 1, 1))
			shake(Bosses.ROAR_SHAKE.seconds, Bosses.ROAR_SHAKE.studs)
			if bossId then
				plateCrest.Text = elementIcon(event.kind)
			end
		end
	end
end

-- PvP result with a countdown until the server sends both players home
local function showPvpEnd(summary: any)
	local outcome = summary.outcome
	local cash = if typeof(summary.cash) == "number" then summary.cash else 0
	local title = if outcome == "win" then (if summary.forfeit then "Opponent left · you win!" else "You win!")
		elseif outcome == "lose" then "You lose"
		else "Draw"
	local money = if cash > 0 then `+${cash}` elseif cash < 0 then `-${-cash}` elseif outcome == "draw" then "Bets returned" else "Friendly match"
	local opponent = if typeof(summary.opponentName) == "string" then ` vs {summary.opponentName}` else ""
	local seconds = if typeof(summary.returnIn) == "number" then summary.returnIn else 10
	VictoryScreen.show({
		kind = if outcome == "win" then "win" elseif outcome == "lose" then "lose" else "run",
		title = title,
		subtitle = `{money}{opponent}`,
		seconds = seconds,
	})
	task.spawn(function()
		for left = seconds, 1, -1 do
			if fighting then
				return -- a new fight started
			end
			VictoryScreen.setNotes({ `Going home in {left}...` })
			task.wait(1)
		end
	end)
end

-- Clearing the Dungeon for the first time: the whole screen says so for a few seconds
local function showConquered()
	if conquered then
		conquered:Destroy()
	end
	local overlay = Instance.new("Frame")
	overlay.Name = "DungeonConquered"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.ZIndex = 50
	overlay.Parent = screenGui
	local title = UIKit.label(overlay, "DUNGEON CONQUERED", Enum.Font.FredokaOne, 60, CONQUERED_COLOR)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.42)
	title.Size = UDim2.fromScale(0.9, 0.16)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextTransparency = 1
	title.ZIndex = 51
	local boss = Bosses.BOSSES[Dungeon.BOSS]
	local subtitle = UIKit.label(overlay, `The {boss.name}, {boss.title}, has fallen`, Enum.Font.GothamBold, 22, UIKit.Colors.Text)
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.fromScale(0.5, 0.52)
	subtitle.Size = UDim2.fromScale(0.9, 0.06)
	subtitle.TextScaled = true
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.TextTransparency = 1
	subtitle.ZIndex = 51
	conquered = overlay
	TweenService:Create(overlay, CONQUERED_FADE, { BackgroundTransparency = 0.35 }):Play()
	TweenService:Create(title, CONQUERED_FADE, { TextTransparency = 0 }):Play()
	TweenService:Create(subtitle, CONQUERED_FADE, { TextTransparency = 0 }):Play()
	shake(Bosses.ROAR_SHAKE.seconds, Bosses.ROAR_SHAKE.studs)
	task.delay(CONQUERED_SECONDS, function()
		if conquered ~= overlay then
			return
		end
		for _, item in { overlay, title, subtitle } do
			TweenService:Create(item, CONQUERED_FADE, if item == overlay then { BackgroundTransparency = 1 } else { TextTransparency = 1 }):Play()
		end
		task.delay(CONQUERED_FADE.Time, function()
			overlay:Destroy()
			if conquered == overlay then
				conquered = nil
			end
		end)
	end)
end

-- When a beaten party is back: "resting 5:00 · the plaza spring heals faster" (the Dungeon: out for the run)
local function restLine(): string
	local place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
	local spring = if place.isFrontier() then "the entrance spring" else "the plaza spring"
	return if place.isDungeon() then "Fainted creatures are out for the rest of this run"
		else `Rest {math.floor(Combat.REST_SECONDS / 60)}:00 · {spring} heals faster`
end

-- The fight's end: a boss's big screen (Util/VictoryScreen: title, rewards and party XP; a loss or a run in red or
-- grey), a toast for everything else (Util/FightToast; owner 2026-11-03), PvP its own
local function showEnd(summary: any, wasBoss: boolean, monsterAt: Vector2?)
	if summary.mode == "pvp" then
		showPvpEnd(summary)
		return
	end
	if not wasBoss then
		FightToast.show(VictoryRules.toast(summary, Cards.ById, if summary.result == "lose" then restLine() else nil))
		-- A won monster fight: XP sparks fly from the monster into the creatures that got it (round 3)
		local xp = tonumber(summary.xpEach) or 0
		if summary.result == "win" and xp > 0 and typeof(summary.party) == "table" then
			local gains = {}
			for _, entry in summary.party do
				if typeof(entry) == "table" and typeof(entry.id) == "string" then
					table.insert(gains, {
						id = entry.id,
						levelUp = entry.levelUp == true,
						from = tonumber(entry.fromLevel),
						to = tonumber(entry.level),
					})
				end
			end
			local screen = UIController.GetScreenGui().AbsoluteSize
			PartyBarController.ShowXpGains(monsterAt or Vector2.new(screen.X / 2, screen.Y / 2), gains, xp)
		end
		return
	end
	local result = summary.result
	if result == "win" then
		local firstConquest = typeof(summary.boss) == "table" and summary.boss.firstClear == true and summary.boss.bossId == Dungeon.BOSS
		if firstConquest then
			showConquered()
		end
		local party = {}
		for _, entry in (if typeof(summary.party) == "table" then summary.party else {}) do
			local card = Cards.ById[entry.cardId]
			if card then
				table.insert(party, {
					name = card.name,
					art = CardArt.pick(card.name, Victory.PORTRAIT, CardArtConfig),
					from = tonumber(entry.from) or 0,
					to = tonumber(entry.to) or 0,
					levelUp = entry.levelUp == true,
				})
			end
		end
		local notes = VictoryRules.notes(summary.boss)
		if typeof(summary.boss) == "table" and summary.boss.firstClear then
			table.insert(notes, 1, "First clear! The chest went into your Bag")
		end
		VictoryScreen.show({
			kind = if firstConquest then "conquered" else "win",
			title = if firstConquest then "DUNGEON CONQUERED!" else "VICTORY!",
			subtitle = VictoryRules.subtitle(summary.foe, summary.seconds),
			tiles = VictoryRules.tiles(summary, Items, Cards.ById),
			notes = notes,
			party = party,
		})
	elseif result == "lose" then
		-- The defeat screen (owner 2026-11-04, design A): the fight's numbers, a tip, the whole countdown to town
		local defeat = if typeof(summary.defeat) == "table" then summary.defeat else {}
		VictoryScreen.hide()
		countdownToken += 1 -- the "Down!" banner from going down would show through the card
		countdownLabel.Visible = false
		DefeatScreen.show({
			subtitle = DefeatRules.subtitle(defeat.foe, tonumber(defeat.seconds)),
			rows = if typeof(defeat.stats) == "table" then DefeatRules.rows(defeat.stats, Cards.ById, Defeat) else {},
			tip = if typeof(defeat.tip) == "string" then defeat.tip else restLine(),
			seconds = tonumber(summary.countdown) or Combat.END_SCREEN_SECONDS,
			art = function(cardId: string): string?
				local card = Cards.ById[cardId]
				return if card then CardArt.pick(card.name, Victory.PORTRAIT, CardArtConfig) else nil
			end,
		})
	else
		VictoryScreen.show({
			kind = "run",
			title = "Got away safely",
			notes = if typeof(summary.rested) == "table" and #summary.rested > 0 then { "Fainted cards are resting." } else {},
			seconds = Combat.END_SCREEN_SECONDS,
		})
	end
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

-- The boss intro: fly the camera to the boss with its name card and a roar, then hand back to the player for the
-- 3, 2, 1 (the server holds the fight until the intro is over)
local function playIntro(boss: any, seconds: number)
	introToken += 1
	local token = introToken
	local camera = workspace.CurrentCamera
	local marker = markerFor(MONSTER_ID) -- found by onStarted, which waits a moment for a just-spawned boss
	bar.Visible = false
	if combatHud then
		combatHud.setVisible(false)
	end
	bossBar.Visible = false
	introName.Text = `{elementIcon(boss.element)} {boss.name}`
	introTitle.Text = boss.title
	introCard.Visible = true
	if camera and marker then
		local look = marker.CFrame
		local shot = boss.introShot or Bosses.INTRO_SHOT -- a huge boss gets a camera further off
		local eye = look.Position + look.LookVector * shot.back + Vector3.new(0, shot.up, 0)
		camera.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(camera, INTRO_FLY, { CFrame = CFrame.lookAt(eye, look.Position + Vector3.new(0, 3, 0)) }):Play()
	end
	task.delay(Bosses.ROAR_SHAKE.at, function()
		if introToken == token then
			shake(Bosses.ROAR_SHAKE.seconds, Bosses.ROAR_SHAKE.studs)
		end
	end)
	task.delay(Bosses.INTRO_CAMERA_SECONDS, function()
		if introToken ~= token or not fighting then
			return
		end
		introCard.Visible = false
		if camera then
			camera.CameraType = Enum.CameraType.Custom
		end
		bar.Visible = combatHud == nil
		if combatHud then
			combatHud.setVisible(true)
		end
		bossBar.Visible = true
		showCountdown(seconds - Bosses.INTRO_CAMERA_SECONDS)
	end)
end

-- Who your sword can hit: the boss and its adds, with their sizes (soft aim; the server checks the real hits) and how
-- big a hit's effects are on each (its model's size, HitFx.scaleFor)
local function swordTargets(): { any }
	local list = {}
	local boss = if bossId then Bosses.BOSSES[bossId] else nil
	for id, marker in markers do
		if string.sub(id, 1, 2) == "b:" and marker.Parent then
			local radius = if id == MONSTER_ID and boss then (boss.ringRadius or Bosses.RING_RADIUS) * Bosses.HIT_RADIUS_SHARE
				elseif id == MONSTER_ID and foeElite then Bosses.ADD_HIT_RADIUS * Wild.ELITE_SIZE
				else Bosses.ADD_HIT_RADIUS
			local fx = HitFx.scaleFor(MonsterController.GetModel(marker))
			table.insert(list, { id = id, x = marker.Position.X, z = marker.Position.Z, radius = radius, fx = fx })
		end
	end
	return list
end

local function usePet(which: string)
	local snapshot = latest
	local creature = if snapshot then myCreature(snapshot) else nil
	if combatWild and snapshot then
		-- Wild fights can have a called-in creature on the field too: the first one ready acts
		local elapsed = os.clock() - latestAt
		for _, fighter in snapshot.fighters do
			local ready = if which == "signature" then fighter.signature ~= nil and fighter.superMeter >= 1 else fighter.abilityIn - elapsed <= 0.05
			if not fighter.fainted and ready then
				creature = fighter
				break
			end
		end
	end
	if creature and not creature.fainted then
		Remotes.UseAbility:FireServer(creature.id, which)
	end
end

local function swapTo(id: string)
	Remotes.CallIn:FireServer(id)
end

-- PC keys while the combat HUD is up (above the party bar's 1-3)
local function onCombatKey(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin or not combatHud or introCard.Visible then
		return Enum.ContextActionResult.Pass
	end
	if SuperCinematic.isPlaying() then
		return Enum.ContextActionResult.Sink -- your super's cinematic: fight keys wait for control to come back
	end
	local key = input.KeyCode
	if not combatSword and (key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.E) then
		return Enum.ContextActionResult.Pass -- no sword in this fight yet
	elseif key == Enum.KeyCode.LeftShift then
		SwordController.Dodge()
	elseif key == Enum.KeyCode.E then
		SwordController.Skill()
	elseif key == Enum.KeyCode.R then
		usePet("element")
	else
		-- 1-3: the party slot as the party bar numbers it (not the reserves' order), and a word when it can't come in
		local slot = table.find({ Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }, key)
		if slot and latest then
			local swapLeft = latestAt + latest.swapIn - os.clock()
			local action, value = SwapKeys.pick(PartyController.GetSlots()[slot], latest.reserves, latest.fighters, latest.swaps, swapLeft)
			if action == "swap" then
				swapTo(value)
			elseif action == "cooling" then
				UIController.Notify(`Swap ready in {math.ceil(value)}s`, true, 1.2)
			elseif action == "resting" then
				UIController.Notify("That creature is resting.", true, 1.2)
			end
		end
	end
	return Enum.ContextActionResult.Sink
end

-- Your weapon changing mid-fight (the quick switch): the skill button follows it
local weaponWatch: RBXScriptConnection? = nil

-- A boss fight: the combat HUD instead of the bar, and your sword on; a wild fight (`wild`): the same HUD, its buttons
-- always named, the sword on once the player has one (`sword`)
local function startCombat(showNames: boolean, wild: boolean?, sword: boolean?)
	combatWild = wild == true
	combatSword = sword ~= false
	local hud = CombatHud.new(screenGui, {
		attack = SwordController.Attack,
		dodge = SwordController.Dodge,
		skill = SwordController.Skill,
		pet = function()
			usePet("element")
		end,
		signature = function()
			usePet("signature")
		end,
		swap = swapTo,
		run = function()
			Remotes.RunFight:FireServer()
		end,
	}, showNames, wild, combatSword)
	combatHud = hud
	if combatSword then
		SwordController.SetCombat(true, swordTargets, hud.setCooldown)
		hud.setSkill(SwordController.EquippedMoveset())
		local character = player.Character
		if weaponWatch then
			weaponWatch:Disconnect()
		end
		weaponWatch = if character
			then character:GetAttributeChangedSignal("Sword"):Connect(function()
				if combatHud == hud then
					hud.setSkill(SwordController.EquippedMoveset())
				end
			end)
			else nil
	end
	ContextActionService:BindActionAtPriority(COMBAT_ACTION, onCombatKey, false, Enum.ContextActionPriority.High.Value + 1, table.unpack(COMBAT_KEYS))
end

local function stopCombat()
	SuperCinematic.release()
	local hud = combatHud
	combatHud = nil
	if weaponWatch then
		weaponWatch:Disconnect()
		weaponWatch = nil
	end
	if hud then
		hud.destroy()
		if combatSword then
			SwordController.SetCombat(false)
		end
		SwordController.SetFoeElement(nil)
		ContextActionService:UnbindAction(COMBAT_ACTION)
	end
end

local function onStarted(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.snapshot) ~= "table" then
		return
	end
	fighting = true
	mySide = if payload.side == "b" then "b" else "a"
	markers = {}
	addMarkers(payload.markers, payload.markerNames)
	if fightFx then
		fightFx.destroy()
	end
	fightFx = newFightFx()
	fightNames = if typeof(payload.names) == "table" then payload.names else {}
	for id, species in (if typeof(payload.foes) == "table" then payload.foes else {}) do
		if typeof(id) == "string" and typeof(species) == "string" then
			fightNames[id] = species -- a Dungeon room's monsters
		end
	end
	allyNames = {}
	addAllies(payload.allies)
	groupFight = payload.group == true
	allyBars = {}
	clear(allyRow)
	local view = toView(payload.snapshot)
	VictoryScreen.hide()
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
	-- Your Prism Blade's trail takes the colour strong against this foe
	local foeElement = if boss then boss.element elseif typeof(payload.element) == "string" then payload.element else nil
	SwordController.SetFoeElement(if mode == "wild" then foeElement else nil)
	-- The top bar: the plate for a boss, the slim bar for a monster (an elite's gold with its tag)
	local topBar = if boss then plate else slim
	local otherBar = if boss then slim else plate
	otherBar.frame.Visible = false
	bossBar, bossName, bossHp, bossHpText = topBar.frame, topBar.name, topBar.hp, topBar.text
	addsRow.Parent = bossBar
	local topSpec = CombatHudConfig.TOP_BAR
	if boss then
		monsterName.Text = `BOSS {elementIcon(boss.element)} {boss.name}`
		monsterName.TextColor3 = UIKit.Colors.Danger
		plateCrest.Text = elementIcon(boss.element)
		bossName.Text = boss.name
		plateTitle.Text = `{string.upper(boss.title)} · LV {boss.level}`
	else
		bossName.Text = `{elementIcon(payload.element or "")} {species} · Lv {payload.level or 1}`
		bossName.TextColor3 = if payload.elite then ELITE_COLOR else Color3.new(1, 1, 1)
		slimTag.Visible = payload.elite == true
		slim.hp.setLook(if payload.elite then CombatHudConfig.HP_BAR.ELITE else CombatHudConfig.HP_BAR.MONSTER)
	end
	stopCombat()
	combatWild = false
	combatSword = false
	foeElite = payload.elite == true
	if boss then
		startCombat(payload.buttonNames == true)
	elseif mode == "wild" then
		startCombat(true, true, payload.sword == true)
	end
	bossBar.Visible = boss ~= nil or combatWild
	bossHp.reset(view.monster.hp, view.monster.maxHp) -- a new foe starts at its own HP, no ghost from the last fight
	bossBar.Position = UDim2.new(0.5, 0, 0, BOSS_BAR_TOP - GuiService:GetGuiInset().Y) -- MainGui starts below the top bar
	local height = if boss then (if UIKit.isPhone() then topSpec.PLATE_PHONE_HEIGHT else topSpec.PLATE_HEIGHT) else topSpec.SLIM_NAME + topSpec.SLIM_BAR + 10
	bossBar.Size = if UIKit.isPhone() then UDim2.new(1, -BOSS_BAR_PHONE_MARGIN * 2, 0, height)
		else UDim2.new(if boss then 0.6 else topSpec.SLIM_WIDTH, 0, 0, height)
	packFight = mode == "wild" and boss == nil and #view.enemies > 1
	monsterTrack.Visible = mode == "wild" and boss == nil and not packFight -- a boss's HP is the bar at the top
	enemyRow.Visible = mode == "pvp" or packFight
	allyRow.Visible = groupFight -- group fights are boss fights: the HP bar is at the top, this row takes its place
	runButton.Visible = mode == "wild"
	layoutBar()
	if mode == "pvp" or packFight then
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
	bar.Visible = combatHud == nil
	for _, prompt in prompts do
		prompt.Enabled = false
	end
	if boss then
		-- The Wild's boss arenas have their own battle music (Config/Music WILD, MusicController); the drone is the
		-- Frontier's and the Dungeon's
		if boss.place ~= "Wild" then
			playMusic()
		end
		-- A boss spawns the moment its fight starts, so its marker can arrive just after this message
		if not markerFor(MONSTER_ID) and typeof(payload.monsterId) == "string" then
			local folder = workspace:FindFirstChild("Monsters")
			local marker = if folder then folder:WaitForChild(`Monster_{payload.monsterId}`, 2) else nil
			if marker and marker:IsA("BasePart") then
				markers[MONSTER_ID] = marker
			end
		end
		if typeof(payload.intro) == "number" and payload.intro > 0 then
			playIntro(boss, payload.intro)
		end
	end
end

local function onEnded(summary: any)
	fighting = false
	SuperCinematic.release() -- the fight ended mid-cinematic: a landed super plays out, else everything back now
	local wasBoss = bossId ~= nil
	-- Where the monster stood on screen, for the XP sparks (taken before the fight's markers go)
	local monsterAt: Vector2? = nil
	local marker = markerFor(MONSTER_ID)
	local camera = workspace.CurrentCamera
	if marker and camera then
		local point, visible = camera:WorldToScreenPoint(marker.Position)
		if visible then
			monsterAt = Vector2.new(point.X, point.Y)
		end
	end
	if fightFx then
		fightFx.destroy()
		fightFx = nil
	end
	DebuffFx.clearAll()
	-- A fight can end during the intro (a player left): give the camera back
	if introCard.Visible then
		introToken += 1
		introCard.Visible = false
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
		end
	end
	stopMusic()
	stopCombat()
	bar.Visible = false
	bossBar.Visible = false
	bossId = nil
	latest = nil
	setHudHidden(false)
	for marker, prompt in prompts do
		prompt.Enabled = marker:GetAttribute("Fighting") ~= true
	end
	if typeof(summary) == "table" then
		showEnd(summary, wasBoss, monsterAt)
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
	-- One line across the screen, shrinking to fit: "3" stays big, "Teleporting back to town in 3" fits a phone
	countdownLabel.Size = UDim2.new(0.9, 0, 0, 120)
	countdownLabel.TextWrapped = false
	countdownLabel.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 96
	fit.Parent = countdownLabel
	countdownLabel.TextXAlignment = Enum.TextXAlignment.Center
	countdownLabel.TextStrokeTransparency = 0.2
	countdownLabel.Visible = false
	countdownLabel.ZIndex = UIKit.PANEL_Z_INDEX + 2
	Instance.new("UIScale").Parent = countdownLabel

	-- The foe's bar at the very top, up in the Roblox top bar's row between its buttons (placed when a fight starts).
	-- Bosses: a gold-edged plate with the element crest, the name big with its title and level under it, and the bar
	-- with the HP number. Monsters: a slim bar with name and level over it, gold with an ELITE tag for an elite.
	local barSpec = CombatHudConfig.HP_BAR
	local topSpec = CombatHudConfig.TOP_BAR
	local phone = UIKit.isPhone()
	local function rgb(values: { number }): Color3
		return Color3.fromRGB(values[1], values[2], values[3])
	end
	local function holder(name: string): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.AnchorPoint = Vector2.new(0.5, 0)
		frame.BackgroundTransparency = 1
		frame.Visible = false
		frame.ZIndex = UIKit.PANEL_Z_INDEX + 1
		frame.Parent = screenGui
		local width = Instance.new("UISizeConstraint")
		width.MaxSize = Vector2.new(if name == "BossPlate" then BOSS_BAR_MAX_WIDTH else topSpec.SLIM_MAX_WIDTH, math.huge)
		width.Parent = frame
		return frame
	end
	-- A row of labels centred at the top of `parent`
	local function centredRow(parent: Frame, height: number, gap: number): Frame
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.AnchorPoint = Vector2.new(0.5, 0)
		row.Size = UDim2.fromOffset(0, height)
		row.AutomaticSize = Enum.AutomaticSize.X
		row.ZIndex = parent.ZIndex
		row.Parent = parent
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, gap)
		list.Parent = row
		return row
	end

	local plateFrame = holder("BossPlate")
	plateFrame.BackgroundColor3 = rgb(CombatHudConfig.PANEL_COLOR)
	plateFrame.BackgroundTransparency = 0.12
	UIKit.corner(plateFrame, 12)
	local plateEdge = Instance.new("UIStroke")
	plateEdge.Color = rgb(topSpec.GOLD)
	plateEdge.Thickness = 2
	plateEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	plateEdge.Parent = plateFrame
	local crestSize = if phone then 32 else topSpec.CREST
	local heading = centredRow(plateFrame, crestSize, 8)
	heading.Position = UDim2.new(0.5, 0, 0, 5)
	plateCrest = UIKit.label(heading, "", Enum.Font.GothamBold, math.round(crestSize * 0.55), Color3.new(1, 1, 1))
	plateCrest.LayoutOrder = 1
	plateCrest.Size = UDim2.fromOffset(crestSize, crestSize)
	plateCrest.TextXAlignment = Enum.TextXAlignment.Center
	plateCrest.BackgroundColor3 = rgb(topSpec.CREST_BACK)
	plateCrest.BackgroundTransparency = 0
	UIKit.corner(plateCrest, crestSize)
	local crestEdge = Instance.new("UIStroke")
	crestEdge.Color = rgb(topSpec.GOLD)
	crestEdge.Thickness = 2
	crestEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	crestEdge.Parent = plateCrest
	local words = Instance.new("Frame")
	words.LayoutOrder = 2
	words.BackgroundTransparency = 1
	words.AutomaticSize = Enum.AutomaticSize.XY
	words.ZIndex = plateFrame.ZIndex
	words.Parent = heading
	local wordsList = Instance.new("UIListLayout")
	wordsList.SortOrder = Enum.SortOrder.LayoutOrder
	wordsList.Parent = words
	local nameSize = if phone then 18 else topSpec.NAME_SIZE
	local titleSize = if phone then 10 else topSpec.TITLE_SIZE
	local plateName = UIKit.label(words, "", Enum.Font.FredokaOne, nameSize, rgb(topSpec.NAME_COLOR))
	plateName.LayoutOrder = 1
	plateName.TextWrapped = false
	plateName.Size = UDim2.fromOffset(0, nameSize + 2)
	plateName.AutomaticSize = Enum.AutomaticSize.X
	plateName.TextStrokeTransparency = 0.4
	plateTitle = UIKit.label(words, "", Enum.Font.GothamBold, titleSize, rgb(topSpec.TITLE_COLOR))
	plateTitle.LayoutOrder = 2
	plateTitle.TextWrapped = false
	plateTitle.Size = UDim2.fromOffset(0, titleSize + 2)
	plateTitle.AutomaticSize = Enum.AutomaticSize.X
	local plateHp = HpBar.new(plateFrame, barSpec.HEIGHT, barSpec.BOSS_PLATE, barSpec.BOSS_GHOST)
	plateHp.frame.AnchorPoint = Vector2.new(0, 1)
	plateHp.frame.Position = UDim2.new(0, 16, 1, -8)
	plateHp.frame.Size = UDim2.new(1, -32, 0, barSpec.HEIGHT)
	local plateText = UIKit.label(plateHp.frame, "", Enum.Font.GothamBold, 13, UIKit.Colors.Text)
	plateText.Size = UDim2.new(1, -14, 1, 0)
	plateText.TextXAlignment = Enum.TextXAlignment.Right
	plateText.TextStrokeTransparency = 0.5
	plateText.ZIndex = plateHp.topZIndex
	plate = { frame = plateFrame, name = plateName, hp = plateHp, text = plateText }

	local slimFrame = holder("MonsterBar")
	local slimHeading = centredRow(slimFrame, topSpec.SLIM_NAME + 2, 5)
	slimHeading.Position = UDim2.new(0.5, 0, 0, 0)
	slimTag = UIKit.label(slimHeading, "ELITE", Enum.Font.FredokaOne, 11, Color3.fromRGB(58, 42, 0))
	slimTag.LayoutOrder = 1
	slimTag.TextWrapped = false
	slimTag.TextXAlignment = Enum.TextXAlignment.Center
	slimTag.Size = UDim2.fromOffset(40, 15)
	slimTag.BackgroundColor3 = rgb(topSpec.ELITE_TAG)
	slimTag.BackgroundTransparency = 0
	slimTag.Visible = false
	UIKit.corner(slimTag, 4)
	local slimName = UIKit.label(slimHeading, "", Enum.Font.FredokaOne, topSpec.SLIM_NAME, Color3.new(1, 1, 1))
	slimName.LayoutOrder = 2
	slimName.TextWrapped = false
	slimName.Size = UDim2.fromOffset(0, topSpec.SLIM_NAME + 2)
	slimName.AutomaticSize = Enum.AutomaticSize.X
	slimName.TextStrokeTransparency = 0.3
	local slimHp = HpBar.new(slimFrame, topSpec.SLIM_BAR, barSpec.MONSTER, barSpec.GHOST)
	slimHp.frame.Position = UDim2.fromOffset(0, topSpec.SLIM_NAME + 6)
	slimHp.frame.Size = UDim2.new(1, 0, 0, topSpec.SLIM_BAR)
	local slimText = UIKit.label(slimHp.frame, "", Enum.Font.GothamBold, 10, UIKit.Colors.Text)
	slimText.Visible = false -- the slim bar shows no number
	slim = { frame = slimFrame, name = slimName, hp = slimHp, text = slimText }
	bossBar, bossName, bossHp, bossHpText = plateFrame, plateName, plateHp, plateText -- until a fight picks one

	addsRow = Instance.new("Frame")
	addsRow.Name = "BossAdds"
	addsRow.AnchorPoint = Vector2.new(0.5, 0)
	addsRow.Position = UDim2.new(0.5, 0, 1, 4)
	addsRow.Size = UDim2.new(1, 0, 0, 26)
	addsRow.BackgroundTransparency = 1
	addsRow.Visible = false
	addsRow.Parent = bossBar
	local addsLayout = Instance.new("UIListLayout")
	addsLayout.FillDirection = Enum.FillDirection.Horizontal
	addsLayout.Padding = UDim.new(0, 6)
	addsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	addsLayout.Parent = addsRow


	-- Back to your shop while in the wild: top centre (the left HUD stack has no room left on phones). A sky cotton
	-- candy pill (owner 2026-11-03, round 3): its holder opts into the soft buttons, as the binder's screen does
	local homeHolder = Instance.new("Frame")
	homeHolder.Name = "ReturnToTown"
	homeHolder.BackgroundTransparency = 1
	homeHolder.AnchorPoint = Vector2.new(0.5, 0)
	homeHolder.Position = UDim2.new(0.5, 0, 0, 8)
	homeHolder.Size = UDim2.fromOffset(Combat.HOME_BUTTON.width, Combat.HOME_BUTTON.height)
	homeHolder:SetAttribute("SoftButtons", true)
	homeHolder.Parent = screenGui
	Hud.hideWith(homeHolder) -- out of the way while the binder (or a pack opening) fills the screen (owner 2026-11-05)
	shopButton = UIKit.iconButton(homeHolder, "Return to town", "Travel", UIKit.Colors.Secondary)
	shopButton.Name = "ShopButton"
	shopButton.Size = UDim2.fromScale(1, 1)
	shopButton.Font = Enum.Font.FredokaOne
	shopButton.TextSize = Combat.HOME_BUTTON.textSize
	local round = shopButton:FindFirstChildOfClass("UICorner")
	if round then
		round.CornerRadius = UDim.new(0.5, 0) -- a pill
	end
	shopButton.Visible = false
	shopButton.Activated:Connect(function()
		Remotes.WildTravel:FireServer("home")
	end)

	introCard = Instance.new("Frame")
	introCard.Name = "BossIntro"
	introCard.AnchorPoint = Vector2.new(0.5, 0.5)
	introCard.Position = UDim2.fromScale(0.5, 0.74) -- under the boss
	introCard.Size = UDim2.fromOffset(520, 110)
	introCard.BackgroundTransparency = 1
	introCard.Visible = false
	introCard.ZIndex = UIKit.PANEL_Z_INDEX + 2
	introCard.Parent = screenGui
	introName = UIKit.label(introCard, "", Enum.Font.FredokaOne, 44, UIKit.Colors.Danger)
	introName.Size = UDim2.new(1, 0, 0, 56)
	introName.TextXAlignment = Enum.TextXAlignment.Center
	introName.TextStrokeTransparency = 0.2
	introTitle = UIKit.label(introCard, "", Enum.Font.FredokaOne, 22, Color3.new(1, 1, 1))
	introTitle.Position = UDim2.fromOffset(0, 58)
	introTitle.Size = UDim2.new(1, 0, 0, 30)
	introTitle.TextXAlignment = Enum.TextXAlignment.Center
	introTitle.TextStrokeTransparency = 0.3

	RunService:BindToRenderStep("FightShake", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		if camera and os.clock() < shakeUntil then
			local function jitter(): number
				return (math.random() * 2 - 1) * shakeStuds
			end
			camera.CFrame *= CFrame.new(jitter(), jitter(), 0)
		end
	end)
end

-- Click attacks in boss fights (not over a button or while typing)
local function onClick(input: InputObject, processed: boolean)
	if processed or not combatHud or not combatSword or introCard.Visible or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	SwordController.Attack()
end

-- A fight is on for this player (Pish's lesson visits wait for it to end)
function BattleController.IsFighting(): boolean
	return fighting
end

function BattleController.Start()
	build()
	UserInputService.InputBegan:Connect(onClick)
	Remotes.BattleStarted.OnClientEvent:Connect(onStarted)
	Remotes.BattleEvent.OnClientEvent:Connect(function(payload)
		if not fighting or typeof(payload) ~= "table" then
			return
		end
		addMarkers(payload.markers, payload.markerNames)
		addMonsterMarkers(payload.addMonsters)
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
		if where == "wild" or where == "home" then -- not "loading" / "stay" (the Wild's loading screen)
			shopButton.Visible = where == "wild" and not fighting
		end
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
