--!strict
-- The Dungeon's objective (spec 2026-11-12-dungeon-atmosphere; the owner: "simple, no textbox"): plain text at the
-- top right, a small "OBJECTIVE" label over one short line and its progress ("2 / 3"). The stage comes from the run's
-- DungeonRun message; the progress from what every client already sees: the pack's markers, the plates' Held / Needed,
-- room 3's pylons' Broken, the lock's sockets' Lit (Util/ObjectiveRules, lines in Config/Dungeon OBJECTIVES). A soft
-- chime and a small pop when the line changes; hidden while the Hydra's welcome plays. In a puzzle room its name is the
-- label and a clue sits under the line, a new one every CLUE_EVERY seconds there (Config/Dungeon OBJECTIVE_LABELS,
-- CLUES). Dungeon place only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bosses = require(Shared:WaitForChild("Config"):WaitForChild("Bosses"))
local Dungeon = require(Shared:WaitForChild("Config"):WaitForChild("Dungeon"))
local ObjectiveRules = require(Shared:WaitForChild("Util"):WaitForChild("ObjectiveRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local DungeonObjectiveController = {}

local CHECK_EVERY = 0.25
local SIZES = { label = 13, line = 20, progress = 18, clue = 15, width = 340, right = 18, top = 12 }
local PHONE = { label = 11, line = 15, progress = 14, clue = 12, width = 230 }
local LABEL_COLOR = Color3.fromRGB(255, 216, 107)
local CLUE_COLOR = Color3.fromRGB(214, 196, 255)
local OUTLINE = Color3.fromRGB(20, 14, 30)

local player = Players.LocalPlayer
local state: any = nil -- the last DungeonRun message
local holder: Frame
local lineLabel: TextLabel
local progressLabel: TextLabel
local titleLabel: TextLabel
local clueLabel: TextLabel
local stageSince = os.clock()
local lockOrder = "" -- the lock's order in words, for its last clue
local scale: UIScale
local lastKey = ""
local chime: Sound

local function textLabel(parent: Instance, name: string, text: string, size: number, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, size + 4)
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function count(prefix: string, attribute: string, wanted: any): (number, number)
	local folder = workspace:FindFirstChild("Dungeon")
	local done, total = 0, 0
	-- (descendants: the lock's sockets sit on its seal)
	for _, piece in if folder then folder:GetDescendants() else {} do
		if string.sub(piece.Name, 1, #prefix) == prefix and piece:GetAttribute(attribute) ~= nil then
			total += 1
			if piece:GetAttribute(attribute) == wanted then
				done += 1
			end
		end
	end
	return done, total
end

-- The stage's key and its progress, from the run's message and what this client sees
local function current(): (string, number?, number?)
	local stage = if state then state.stage else "waiting"
	if stage == "room" then
		local shield = workspace:FindFirstChild("Dungeon") and workspace.Dungeon:FindFirstChild("PylonShield")
		if shield and shield:GetAttribute("Up") == true then
			local broken, total = count("Pylon", "Broken", true)
			return "pylons", broken, total
		end
		local room = Dungeon.ROOMS[state.room or 1]
		local alive = 0
		local monsters = workspace:FindFirstChild("Monsters")
		for _, marker in if monsters then monsters:GetChildren() else {} do
			if marker:GetAttribute("Elite") and not marker:GetAttribute("Boss") then
				alive += 1
			end
		end
		if alive > 0 and room then
			return "room", math.max(0, room.count - alive), room.count
		end
		return "room", nil, nil
	elseif stage == "plates" then
		local folder = workspace:FindFirstChild("Dungeon")
		local held, needed = 0, 0
		for _, plate in if folder then folder:GetChildren() else {} do
			if string.sub(plate.Name, 1, 5) == "Plate" and plate:GetAttribute("Needed") == true then
				needed += 1
				if plate:GetAttribute("Held") == true then
					held += 1
				end
			end
		end
		return "plates", held, needed
	elseif stage == "gather" then
		return "gather", state.here, state.total
	elseif stage == "lock" then
		local lit, total = count("LockSocket", "Lit", true)
		return "lock", lit, total
	end
	return stage, nil, nil
end

local function update()
	local hidden = state == nil or player:GetAttribute("DungeonIntroPlaying") == true
	holder.Visible = not hidden
	if hidden then
		return
	end
	local stage, done, total = current()
	local line = ObjectiveRules.line(stage, done, total, Dungeon.OBJECTIVES)
	lineLabel.Text = line.text
	progressLabel.Text = line.progress or ""
	progressLabel.Visible = line.progress ~= nil
	titleLabel.Text = ObjectiveRules.label(stage, Dungeon.OBJECTIVE_LABELS)
	if stage ~= lastKey then
		stageSince = os.clock()
	end
	local clue = ObjectiveRules.hint(stage, os.clock() - stageSince, Dungeon.CLUES, Dungeon.CLUE_EVERY)
	clueLabel.Text = if clue then string.gsub(clue, "{order}", lockOrder) else ""
	clueLabel.Visible = clue ~= nil
	-- A new step: chime and pop (not for its progress ticking)
	if stage ~= lastKey then
		lastKey = stage
		chime:Play()
		scale.Scale = 1.15
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

function DungeonObjectiveController.Start()
	local gui = UIController.GetScreenGui()
	local phone = UIKit.isPhone()
	local sizes = if phone then PHONE else SIZES
	holder = Instance.new("Frame")
	holder.Name = "DungeonObjective"
	holder.BackgroundTransparency = 1
	-- top right; on touch screens the cash and level column is there (UIController), so top centre
	local touch = UserInputService.TouchEnabled
	local align = if touch then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Right
	holder.AnchorPoint = if touch then Vector2.new(0.5, 0) else Vector2.new(1, 0)
	holder.Position = if touch then UDim2.new(0.5, 0, 0, SIZES.top) else UDim2.new(1, -SIZES.right, 0, SIZES.top)
	holder.Size = UDim2.fromOffset(sizes.width, 60)
	holder.Visible = false
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = align
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = holder
	scale = Instance.new("UIScale")
	scale.Parent = holder
	titleLabel = textLabel(holder, "Label", "OBJECTIVE", sizes.label, LABEL_COLOR, Enum.Font.FredokaOne)
	titleLabel.LayoutOrder = 1
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromOffset(0, sizes.line + 6)
	row.LayoutOrder = 2
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = align
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.Parent = row
	row.Parent = holder
	lineLabel = textLabel(row, "Line", "", sizes.line, Color3.new(1, 1, 1), Enum.Font.FredokaOne)
	lineLabel.LayoutOrder = 1
	progressLabel = textLabel(row, "Progress", "", sizes.progress, LABEL_COLOR, Enum.Font.FredokaOne)
	progressLabel.LayoutOrder = 2
	clueLabel = textLabel(holder, "Clue", "", sizes.clue, CLUE_COLOR, Enum.Font.GothamBold)
	clueLabel.LayoutOrder = 3
	clueLabel.AutomaticSize = Enum.AutomaticSize.Y
	clueLabel.Size = UDim2.fromOffset(sizes.width, 0)
	clueLabel.TextWrapped = true
	clueLabel.TextXAlignment = if touch then Enum.TextXAlignment.Center else Enum.TextXAlignment.Right
	clueLabel.Visible = false
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Parent = gui
	local names = {}
	for _, phase in Bosses.BOSSES[Dungeon.BOSS].phases do
		table.insert(names, phase.element)
	end
	lockOrder = table.concat(names, ", ")

	chime = Instance.new("Sound")
	chime.Name = "DungeonObjectiveChime"
	chime.SoundId = Dungeon.SOUNDS.chime.id
	chime.Volume = Dungeon.SOUNDS.chime.volume
	chime.PlaybackSpeed = Dungeon.SOUNDS.chime.pitch or 1
	chime.Parent = SoundService

	Remotes.DungeonRun.OnClientEvent:Connect(function(message)
		if typeof(message) == "table" then
			state = message
		end
	end)
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since >= CHECK_EVERY then
			since = 0
			update()
		end
	end)
end

return DungeonObjectiveController
