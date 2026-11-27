--!strict
-- The admin panel: every dev chat command as a button (Config/AdminPanel), plus +1/+10 of every item and
-- Go/Fight/Group for every boss. Buttons send the command text through Remotes.DevPanel; DevService runs it after
-- Util/DevAccess says yes (Studio: anyone; the published game: the game's owner on their test save) and answers with its
-- usual notification.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AdminPanel = require(Config:WaitForChild("AdminPanel"))
local Bosses = require(Config:WaitForChild("Bosses"))
local Items = require(Config:WaitForChild("Items"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local UIController = require(Controllers:WaitForChild("UIController"))

local AdminPanelController = {}

local ROW_HEIGHT = 48
local BOX_SHARE = 0.55 -- of a row with a text box: the box; the rest is its button

local panel: Frame
local palette: UIKit.Palette -- the cream window's colours (UIKit.colorsFor), set when it's built
local list: ScrollingFrame
local order = 0

local function nextOrder(): number
	order += 1
	return order
end

local function send(command: string?)
	if command then
		Remotes.DevPanel:FireServer(command)
	end
end

local function heading(text: string)
	local label = UIKit.label(list, text, Enum.Font.FredokaOne, 18, palette.hint)
	label.LayoutOrder = nextOrder()
	label.Size = UDim2.new(1, 0, 0, 26)
end

-- A row of equal buttons, each sending its own command
local function buttonRow(entries: { { label: string, command: string } })
	local row = Instance.new("Frame")
	row.LayoutOrder = nextOrder()
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundTransparency = 1
	row.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row
	for _, entry in entries do
		local button = UIKit.button(row, entry.label, palette.row)
		button.Size = UDim2.new(1 / #entries, -6, 1, 0)
		button.TextSize = 14
		button.TextWrapped = true
		button.Activated:Connect(function()
			send(entry.command)
		end)
	end
end

-- A text box and a button that sends the command with what's typed
local function inputRow(entry: AdminPanel.Button)
	local row = Instance.new("Frame")
	row.LayoutOrder = nextOrder()
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundTransparency = 1
	row.Parent = list
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(BOX_SHARE, -6, 1, 0)
	box.BackgroundColor3 = palette.row
	box.ClearTextOnFocus = false
	box.PlaceholderText = entry.placeholder or ""
	box.Text = ""
	box.Font = Enum.Font.GothamBold
	box.TextSize = 14
	box.TextColor3 = palette.ink
	box.PlaceholderColor3 = palette.inkSoft
	box.Parent = row
	UIKit.corner(box, 10)
	UIKit.outline(box)
	local button = UIKit.button(row, entry.label, UIKit.Colors.Accent)
	button.Position = UDim2.new(BOX_SHARE, 0, 0, 0)
	button.Size = UDim2.new(1 - BOX_SHARE, 0, 1, 0)
	button.TextSize = 14
	button.TextWrapped = true
	button.Activated:Connect(function()
		local command = AdminPanel.fill(entry.command, box.Text)
		if not command then
			UIController.Notify(`Type {entry.placeholder or "something"} first`, true, 1.5)
		end
		send(command)
	end)
end

local function build()
	for _, section in AdminPanel.SECTIONS do
		heading(section.title)
		local plain = {}
		for _, entry in section.buttons do
			if string.find(entry.command, "%s", 1, true) then
				inputRow(entry)
			else
				table.insert(plain, entry)
				if #plain == 2 then
					buttonRow(plain)
					plain = {}
				end
			end
		end
		if #plain > 0 then
			buttonRow(plain)
		end
	end

	heading("Bosses")
	for index, bossId in Bosses.LADDER do
		local boss = Bosses.BOSSES[bossId]
		local label = UIKit.label(list, `{index}. {boss.name} ({boss.place})`, Enum.Font.GothamBold, 13, UIKit.Colors.Text)
		label.LayoutOrder = nextOrder()
		label.Size = UDim2.new(1, 0, 0, 18)
		buttonRow({
			{ label = "Go", command = `/boss {index}` },
			{ label = "Fight", command = `/boss {index} fight` },
			{ label = "Group", command = `/boss {index} group` },
		})
	end

	heading("Items")
	local ids = {}
	for id in Items.ITEMS do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local item = Items.ITEMS[id]
		local entries = {}
		for _, amount in AdminPanel.ITEM_AMOUNTS do
			table.insert(entries, { label = `+{amount} {item.name}`, command = `/item {id} {amount}` })
		end
		buttonRow(entries)
	end
end

local function toggle()
	panel.Visible = not panel.Visible
end

-- The Admin tile, in the Phone (owner 2026-11-13)
local function addTile(onClick: () -> ())
	Hud.tile({ id = "Admin", icon = "🛠", label = "Admin", group = "Side", order = 90, phoneApp = 90, phoneAlways = true, onClick = onClick })
end

-- The panel and its tile
local function buildPanel(title: string)
	panel, list = UIKit.panel(UIController.GetScreenGui(), "AdminPanel", title)
	palette = UIKit.colorsFor(panel)
	build()
	addTile(toggle)
end

function AdminPanelController.Start()
	if RunService:IsStudio() then
		buildPanel("🛠 Admin (Studio)")
		return
	end
	-- The published game (spec 2026-11-27-live-admin-creator-design): only the game's owner gets the server's Admin
	-- mark (DevService markAdmin). On their test save the panel; on the real one the tile alone, whose tap asks the server
	-- (it answers with the locked card saying how to get to the test save). The server checks every button anyway.
	local player = Players.LocalPlayer
	local built = false
	local function onMark()
		local mark = player:GetAttribute("AdminAccess")
		if built or (mark ~= "open" and mark ~= "mainSave") then
			return
		end
		built = true
		if mark == "open" then
			buildPanel("🛠 Admin")
		else
			addTile(function()
				send("/admin")
			end)
		end
	end
	player:GetAttributeChangedSignal("AdminAccess"):Connect(onMark)
	onMark()
end

return AdminPanelController
