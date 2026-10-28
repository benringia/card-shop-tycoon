--!strict
-- The boss board (HUD tile "Bosses"): the boss ladder (Config/Bosses) with each boss's lock and fragments, the
-- recommended Power against your strongest party card, when full loot is ready again, today's rewarded wins and the
-- trophy once cleared. Data comes from BossService (BossesChanged); the loot timers count down here between updates.
-- Also: the leader of a group forming at a gate sees "Start now" on its group prompt.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Cards = require(Config:WaitForChild("Cards"))
local Items = require(Config:WaitForChild("Items"))
local WildConfig = require(Config:WaitForChild("Wild"))
local FrontierConfig = require(Config:WaitForChild("Frontier"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local BossRules = require(Shared:WaitForChild("Util"):WaitForChild("BossRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type BossState = { unlocked: boolean, cleared: boolean, lootIn: number, rewardedToday: number, fragments: number }

local ROW_HEIGHT = 112
local LOCKED_COLOR = UIKit.Colors.Subtext
local READY_COLOR = UIKit.Colors.Success

local BossBoardController = {}

local panel: Frame
local list: ScrollingFrame
local states: { [string]: BossState } = {}
local receivedAt = 0 -- os.clock() when `states` arrived (lootIn counts down from then)
local partyIds: { string } = {}
local lootLabels: { [string]: TextLabel } = {} -- bossId -> its loot timer line

local function clock(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- The strongest party card's Power (what the over-power rule and the recommended Power compare)
local function bestPower(): number
	local beasts = BinderController.GetBeasts()
	local best = 0
	for _, beastId in partyIds do
		local beast = beasts[beastId]
		local card = if beast then Cards.ById[beast.cardId] else nil
		if beast and card then
			best = math.max(best, BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade))
		end
	end
	return math.floor(best)
end

local function lootText(state: BossState): (string, Color3)
	local left = math.max(0, math.ceil(state.lootIn - (os.clock() - receivedAt)))
	return if left > 0 then `Full loot in {clock(left)}` else "Full loot ready", if left > 0 then LOCKED_COLOR else READY_COLOR
end

local function addText(row: GuiObject, text: string, y: number, height: number, font: Enum.Font, size: number, color: Color3): TextLabel
	local label = UIKit.label(row, text, font, size, color)
	label.Position = UDim2.fromOffset(14, y)
	label.Size = UDim2.new(1, -28, 0, height)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return label
end

local function buildRow(index: number, bossId: string, power: number)
	local boss = Bosses.BOSSES[bossId]
	local state = states[bossId]
	local row = Instance.new("Frame")
	row.LayoutOrder = index
	row.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
	row.BackgroundColor3 = UIKit.Colors.Row
	row.Parent = list
	UIKit.corner(row, 10)
	local stroke = UIKit.outline(row, Cards.ELEMENTS[boss.element])
	stroke.Thickness = 1.5

	local zone = (if boss.place == "Frontier" then FrontierConfig else WildConfig).ZONES[boss.zone]
	local away = (boss.place == "Frontier") ~= Place.isFrontier() -- its arena is in the other place
	local trophy = if state and state.cleared then " 🏆" else ""
	addText(row, `{index}. {boss.name}{trophy}`, 8, 22, Enum.Font.FredokaOne, 18, UIKit.Colors.Text)
	local where = if zone then `{zone.name} arena{if away then ` (the {boss.place})` else ""} · ` else ""
	local powerColor = if power >= boss.recommended then READY_COLOR else UIKit.Colors.Danger
	addText(row, `{where}Power {boss.recommended} · your best {power}`, 32, 18, Enum.Font.GothamBold, 13, powerColor)

	local unlock = boss.unlock
	if not state or (not state.unlocked and unlock) then
		local have = if state then state.fragments else 0
		local need = if unlock then unlock.count else 0
		local fragment = if unlock then Items.ITEMS[unlock.item] else nil
		local previous = Bosses.BOSSES[Bosses.LADDER[index - 1] or ""]
		addText(row, `🔒 {fragment and fragment.icon or ""} Fragments {have}/{need}`, 54, 20, Enum.Font.GothamBold, 15, if have >= need then READY_COLOR else LOCKED_COLOR)
		addText(row, if previous then `Beat the {previous.name} to collect them.` else "", 78, 18, Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
		return
	end
	local text, color = lootText(state)
	lootLabels[bossId] = addText(row, text, 54, 20, Enum.Font.GothamBold, 15, color)
	local today = `Wins today: {state.rewardedToday}`
	if state.rewardedToday >= Bosses.SOFT_CAP_AFTER then
		today ..= " · reduced drops"
	elseif power > boss.recommended * Bosses.OVERPOWER_RATIO then
		today ..= " · reduced drops (party too strong)"
	end
	addText(row, today, 78, 18, Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
end

local function render()
	if not panel.Visible then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	lootLabels = {}
	local power = bestPower()
	for index, bossId in Bosses.LADDER do
		buildRow(index, bossId, power)
	end
end

local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		Remotes.RequestBosses:FireServer()
		render()
	end
end

-- The server's group prompt text is for everyone else ("Join group"); its leader's copy says "Start now"
local function watchGroupPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local function refresh()
		local members = prompt:GetAttribute("Members")
		if prompt:GetAttribute("LeaderId") == Players.LocalPlayer.UserId and typeof(members) == "number" then
			prompt.ActionText = BossRules.groupPromptText(Bosses, members, true)
		end
	end
	prompt:GetAttributeChangedSignal("LeaderId"):Connect(refresh)
	prompt:GetAttributeChangedSignal("Members"):Connect(refresh)
	prompt:GetPropertyChangedSignal("ActionText"):Connect(refresh)
	refresh()
end

function BossBoardController.Start()
	CollectionService:GetInstanceAddedSignal("BossGroupPrompt"):Connect(watchGroupPrompt)
	for _, prompt in CollectionService:GetTagged("BossGroupPrompt") do
		watchGroupPrompt(prompt)
	end
	local screenGui = UIController.GetScreenGui()
	panel, list = UIKit.panel(screenGui, "Bosses", "👑 Boss Ladder")
	Hud.tile({ id = "Bosses", icon = "👑", label = "Bosses", key = "K", group = "Bottom", order = 3, onClick = toggle })

	Remotes.BossesChanged.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		states = {}
		for bossId, state in payload do
			if Bosses.BOSSES[bossId] and typeof(state) == "table" and typeof(state.lootIn) == "number" then
				states[bossId] = state
			end
		end
		receivedAt = os.clock()
		render()
	end)
	Remotes.PartyChanged.OnClientEvent:Connect(function(payload)
		partyIds = {}
		if typeof(payload) == "table" and typeof(payload.slots) == "table" then
			for _, entry in payload.slots do
				if typeof(entry) == "table" and typeof(entry.beastId) == "string" then
					table.insert(partyIds, entry.beastId)
				end
			end
		end
		render()
	end)
	-- Levels and stars change your best Power
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		task.defer(render)
	end)
	Remotes.RequestBosses:FireServer()

	local sinceTick = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceTick += dt
		if sinceTick < 1 or not panel.Visible then
			return
		end
		sinceTick = 0
		for bossId, label in lootLabels do
			local state = states[bossId]
			if state then
				label.Text, label.TextColor3 = lootText(state)
			end
		end
	end)
end

return BossBoardController
