--!strict
-- Jobs panel: your shop job slots. Each slot shows the working card (face, grade, level, stars), its job,
-- what it's doing right now, XP, speed and mistake chance, and Unassign. Locked slots say when they open;
-- the pass slot offers the Extra Job Slot pass (or "Coming soon" before the pass exists).
-- Cards are assigned from the binder card view. The server sends JobsChanged on every change.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Jobs = require(Config:WaitForChild("Jobs"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local JobRules = require(Shared:WaitForChild("Util"):WaitForChild("JobRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type SlotInfo = { slot: number, beastId: string, job: string, status: string }
type JobsState = {
	slotCount: number,
	maxSlots: number,
	unlockLevel: number,
	hasPass: boolean,
	passId: number,
	slots: { SlotInfo },
}

local ROW_HEIGHT = 112
local FACE_SIZE = Vector2.new(70, 100)
local XP_BAR_COLOR = Color3.fromRGB(90, 160, 255)
local XP_TRACK_COLOR = Color3.fromRGB(25, 25, 35)

local player = Players.LocalPlayer

local JobsController = {}

local panel: Frame
local list: ScrollingFrame
local state: JobsState? = nil

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function makeRow(order: number): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
	row.BackgroundColor3 = UIKit.Colors.Row
	row.Parent = list
	UIKit.corner(row, 10)
	return row
end

local function addText(row: GuiObject, text: string, x: number, y: number, width: UDim, height: number, font: Enum.Font, size: number, color: Color3): TextLabel
	local label = UIKit.label(row, text, font, size, color)
	label.Position = UDim2.new(0, x, 0, y)
	label.Size = UDim2.new(width.Scale, width.Offset, 0, height)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return label
end

-- A slot you can't use yet: locked by level, or the pass slot
local function buildLockedRow(slot: number, current: JobsState)
	local row = makeRow(slot)
	addText(row, `Slot {slot}`, 14, 12, UDim.new(1, -150), 22, Enum.Font.GothamBold, 17, UIKit.Colors.Text)
	local needsPass = slot > Jobs.FREE_SLOTS
	local level = player:GetAttribute("Level")
	local detail = if not needsPass or (typeof(level) == "number" and level < current.unlockLevel)
		then `Unlocks at shop level {current.unlockLevel}.`
		else "Extra Job Slot game pass: one more card working in your shop."
	addText(row, detail, 14, 40, UDim.new(1, -150), 40, Enum.Font.Gotham, 13, UIKit.Colors.Subtext).TextWrapped = true
	if needsPass and not current.hasPass then
		local available = current.passId ~= 0
		local buy = UIKit.button(row, if available then "Buy slot" else "Coming soon", if available then UIKit.Colors.Accent else UIKit.Colors.Locked)
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -12, 0.5, 0)
		buy.Size = UDim2.fromOffset(124, 48)
		buy.TextSize = 15
		buy.AutoButtonColor = available
		buy.Activated:Connect(function()
			if available then
				MarketplaceService:PromptGamePassPurchase(player, current.passId)
			end
		end)
	end
end

local function buildEmptyRow(slot: number)
	local row = makeRow(slot)
	addText(row, `Slot {slot} · empty`, 14, 12, UDim.new(1, -150), 22, Enum.Font.GothamBold, 17, UIKit.Colors.Text)
	addText(row, "Pick a card in your binder and press Assign to job.", 14, 40, UDim.new(1, -150), 40, Enum.Font.Gotham, 13, UIKit.Colors.Subtext).TextWrapped = true
	local assign = UIKit.button(row, "Assign", UIKit.Colors.Accent)
	assign.AnchorPoint = Vector2.new(1, 0.5)
	assign.Position = UDim2.new(1, -12, 0.5, 0)
	assign.Size = UDim2.fromOffset(124, 48)
	assign.TextSize = 15
	assign.Activated:Connect(function()
		panel.Visible = false
		BinderController.Open("Tap a card, then Assign to job.")
	end)
end

local function buildWorkerRow(slot: number, info: SlotInfo)
	local row = makeRow(slot)
	local beast = BinderController.GetBeasts()[info.beastId]
	local card = if beast then Cards.ById[beast.cardId] else nil
	if not beast or not card then
		addText(row, `Slot {slot} · {info.job}`, 14, 12, UDim.new(1, -28), 22, Enum.Font.GothamBold, 17, UIKit.Colors.Text)
		return
	end

	local faceHolder = Instance.new("Frame")
	faceHolder.Position = UDim2.fromOffset(8, 6)
	faceHolder.Size = UDim2.fromOffset(FACE_SIZE.X, FACE_SIZE.Y)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = row
	local face = Instance.new("Frame")
	face.Size = UDim2.fromScale(1, 1)
	face.Parent = faceHolder
	UIKit.corner(face, 8)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = face
	CardFace.render(face, stroke, card, beast.foil, false)

	local x = FACE_SIZE.X + 18
	local title = `{info.job} · {card.name}{if beast.foil then " FOIL" else ""}`
	addText(row, title, x, 6, UDim.new(1, -(x + 120)), 20, Enum.Font.GothamBold, 15, UIKit.Colors.Text)
	addText(row, `{BeastRules.describeGrade(beast.grade)} · {BeastRules.describeGrowth(beast.level, beast.stars)}`, x, 27, UDim.new(1, -(x + 120)), 16, Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
	local stats = BeastRules.getStats(card, beast.foil, beast.level, beast.stars, beast.grade)
	local power = BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade)
	local speed = JobRules.getSpeedFactor(Jobs, stats.spd)
	local mistakes = JobRules.getMistakeChance(Jobs, power)
	addText(row, string.format("Speed x%.2f · Mistakes %d%%", speed, math.round(mistakes * 100)), x, 45, UDim.new(1, -(x + 12)), 16, Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
	addText(row, info.status, x, 63, UDim.new(1, -(x + 12)), 18, Enum.Font.GothamBold, 13, UIKit.Colors.Accent)

	-- XP bar
	local toNext = BeastRules.getXpToNext(beast.level)
	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(x, 86)
	track.Size = UDim2.new(1, -(x + 12), 0, 16)
	track.BackgroundColor3 = XP_TRACK_COLOR
	track.Parent = row
	UIKit.corner(track, 6)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(if toNext > 0 then math.clamp(beast.xp / toNext, 0, 1) else 1, 1)
	fill.BackgroundColor3 = if toNext > 0 then XP_BAR_COLOR else UIKit.Colors.Accent
	fill.Parent = track
	UIKit.corner(fill, 6)
	local xpText = UIKit.label(track, if toNext > 0 then `XP {beast.xp} / {toNext} · +{Jobs.XP_PER_MINUTE}/min` else "MAX LEVEL", Enum.Font.GothamBold, 11, UIKit.Colors.Text)
	xpText.Size = UDim2.fromScale(1, 1)
	xpText.TextXAlignment = Enum.TextXAlignment.Center

	local unassign = UIKit.button(row, "Unassign", UIKit.Colors.Danger)
	unassign.AnchorPoint = Vector2.new(1, 0)
	unassign.Position = UDim2.new(1, -10, 0, 6)
	unassign.Size = UDim2.fromOffset(104, 48)
	unassign.TextSize = 14
	unassign.Activated:Connect(function()
		Remotes.UnassignJob:FireServer(slot)
	end)
end

local function render()
	if not panel.Visible then
		return
	end
	clear(list)
	local current = state
	if not current then
		local wait = UIKit.label(list, "Loading...", Enum.Font.GothamBold, 15, UIKit.Colors.Subtext)
		wait.Size = UDim2.new(1, 0, 0, 30)
		return
	end
	local bySlot: { [number]: SlotInfo } = {}
	for _, info in current.slots do
		bySlot[info.slot] = info
	end
	for slot = 1, current.maxSlots do
		local info = bySlot[slot]
		if slot > current.slotCount then
			buildLockedRow(slot, current)
		elseif info then
			buildWorkerRow(slot, info)
		else
			buildEmptyRow(slot)
		end
	end
end

local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		Remotes.RequestJobs:FireServer()
		render()
	end
end

function JobsController.Start()
	local screenGui = UIController.GetScreenGui()
	panel, list = UIKit.panel(screenGui, "Jobs", "Shop Jobs")
	local subtitle = UIKit.label(panel, "Cards working in your shop. They earn XP while you play.", Enum.Font.Gotham, 14, UIKit.Colors.Subtext)
	subtitle.Position = UDim2.fromOffset(16, 56)
	subtitle.Size = UDim2.new(1, -32, 0, 22)
	list.Position = UDim2.fromOffset(12, 84)
	list.Size = UDim2.new(1, -24, 1, -96)

	Hud.fanButton({ id = "Jobs", icon = "👷", label = "Jobs", order = 3, onClick = toggle })

	Remotes.JobsChanged.OnClientEvent:Connect(function(payload: JobsState)
		if typeof(payload) ~= "table" then
			return
		end
		state = payload
		render()
	end)
	-- Levels and XP change as cards work; redraw with the new binder
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		task.defer(render)
	end)
end

return JobsController
