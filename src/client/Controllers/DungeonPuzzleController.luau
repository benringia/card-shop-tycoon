--!strict
-- The Dungeon's puzzles on this client (spec 2026-11-11-dungeon-puzzles; the puzzles themselves are
-- DungeonPuzzleService's): draws a chest on every chest anchor the server places (Util/ChestModel), opens its lid with
-- a sparkle for the player who opened it (Remotes.DungeonChest; its prompt then hides for them), and swings your sword
-- when you break the cracked wall or strike a lock crystal. Opening a chest (owner 2026-11-12: "more immersive, what
-- they get more noticeable"): it rattles with a creak, the lid bursts open with a flash, a column of light and a
-- shower of sparkles, and a big reward card pops in the middle of the screen (Config/Dungeon CHEST_REVEAL).
-- Dungeon place only.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BossChests = require(Config:WaitForChild("BossChests"))
local Dungeon = require(Config:WaitForChild("Dungeon"))
local Items = require(Config:WaitForChild("Items"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local ChestModel = require(ClientUtil:WaitForChild("ChestModel"))
local SwordController = require(Controllers:WaitForChild("SwordController"))
local UIController = require(Controllers:WaitForChild("UIController"))

local DungeonPuzzleController = {}

local LID_OPEN = math.rad(BossChests.LOOK.lidOpen)
local LID_SECONDS = BossChests.LOOK.openSeconds
local SPARKLE = Color3.fromRGB(255, 226, 122)
local SWINGS = { BreakWall = true, StrikeCrystal = true } -- prompts your sword swings at

type Drawn = { chest: ChestModel.Chest, pivot: CFrame, anchor: BasePart }
local drawn: { [string]: Drawn } = {}
local openedKeys: { [string]: boolean } = {} -- chests you opened (drawn open again if one streams out and back in)

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- A chest on a server anchor (its bottom's middle under the anchor's centre)
local function draw(anchor: BasePart)
	local key = anchor:GetAttribute("ChestKey")
	-- (a chest that streamed out and back in comes back as a new anchor: drawn again)
	if typeof(key) ~= "string" or (drawn[key] and drawn[key].anchor == anchor) then
		return
	end
	local colors = BossChests.LOOK.colors
	local chest = ChestModel.new(anchor, Dungeon.CHEST.WIDTH, { wood = rgb(colors.wood), woodDark = rgb(colors.woodDark), trim = rgb(colors.trim) })
	local pivot = anchor.CFrame * CFrame.new(0, -anchor.Size.Y / 2, 0)
	if openedKeys[key] then
		chest.lid = LID_OPEN
		local open = anchor:WaitForChild("OpenChest", 2)
		if open and open:IsA("ProximityPrompt") then
			open.Enabled = false
		end
	end
	ChestModel.place(chest, pivot)
	drawn[key] = { chest = chest, pivot = pivot, anchor = anchor }
end

local function watch(folder: Instance)
	for _, item in folder:GetChildren() do
		if item:IsA("BasePart") and item.Name == "DungeonChest" then
			draw(item)
		end
	end
	folder.ChildAdded:Connect(function(item)
		if item:IsA("BasePart") and item.Name == "DungeonChest" then
			draw(item)
		end
	end)
end

local function sparkle(at: Vector3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = at
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(SPARKLE)
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Acceleration = Vector3.new(0, -8, 0)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = part
	part.Parent = workspace
	emitter:Emit(30)
	task.delay(2, part.Destroy, part)
end

-- What your chest held: one line per reward
local function prizeLines(payload: any): { string }
	if typeof(payload.title) == "string" then
		return { "A secret!", `New title: {payload.title}` }
	elseif typeof(payload.item) == "string" then
		local item = Items.ITEMS[payload.item]
		return { `+{payload.count or 1} {if item then item.name else payload.item}` }
	end
	local lines = {}
	if typeof(payload.cash) == "number" and payload.cash > 0 then
		table.insert(lines, `+${payload.cash}`)
	end
	if typeof(payload.xp) == "number" and payload.xp > 0 then
		table.insert(lines, `+{payload.xp} XP for each party card`)
	end
	return if #lines > 0 then lines else { "The chest is empty." }
end

local function playSound(key: string)
	local spec = (Dungeon.PUZZLE_SOUNDS :: any)[key]
	if not spec then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = spec.id
	sound.Volume = spec.volume
	sound.PlaybackSpeed = spec.pitch or 1
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 8)
end

local function cardLine(card: Frame, text: string, size: number, color: Color3, order: number, phone: boolean)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = if phone then math.floor(size * 0.8) else size
	label.TextColor3 = color
	label.Text = text
	label.TextWrapped = true
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.LayoutOrder = order
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 12, 30)
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = card
end

-- The big reward card in the middle of the screen: pops in, stays, floats up and fades
local function rewardCard(lines: { string })
	local look = Dungeon.CHEST_REVEAL
	local camera = workspace.CurrentCamera
	local phone = camera ~= nil and camera.ViewportSize.X < 900
	local gui = Instance.new("ScreenGui")
	gui.Name = "DungeonReward"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.IgnoreGuiInset = true
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.Size = UDim2.fromOffset(if phone then 300 else 420, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromRGB(22, 16, 34)
	card.BackgroundTransparency = 0.05
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = card
	local edge = Instance.new("UIStroke")
	edge.Color = SPARKLE
	edge.Thickness = 3
	edge.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = card
	cardLine(card, look.title, 30, SPARKLE, 1, phone)
	for index, text in lines do
		cardLine(card, text, 26, Color3.new(1, 1, 1), index + 1, phone)
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = card
	card.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	playSound("reward")
	task.delay(look.seconds, function()
		local away = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(card, away, { Position = UDim2.fromScale(0.5, 0.3), BackgroundTransparency = 1 }):Play()
		TweenService:Create(edge, away, { Transparency = 1 }):Play()
		for _, label in card:GetChildren() do
			if label:IsA("TextLabel") then
				TweenService:Create(label, away, { TextTransparency = 1 }):Play()
			end
		end
		task.delay(0.45, gui.Destroy, gui)
	end)
end

-- A column of light out of the open chest and a flash, fading
local function lightBurst(at: Vector3)
	local look = Dungeon.CHEST_REVEAL
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = at
	local from = Instance.new("Attachment")
	from.Parent = part
	local to = Instance.new("Attachment")
	to.Position = Vector3.new(0, look.column, 0)
	to.Parent = part
	local beam = Instance.new("Beam")
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Color = ColorSequence.new(SPARKLE)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Width0 = 3
	beam.Width1 = 1
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	beam.Parent = part
	local flash = Instance.new("PointLight")
	flash.Color = SPARKLE
	flash.Range = 20
	flash.Brightness = 6
	flash.Parent = part
	part.Parent = workspace
	TweenService:Create(flash, TweenInfo.new(1.4), { Brightness = 0 }):Play()
	TweenService:Create(beam, TweenInfo.new(1.6), { Width0 = 0, Width1 = 0 }):Play()
	Debris:AddItem(part, 2)
end

-- Your chest opens: it rattles, the lid bursts up with the light inside, a column of light, sparkles, the reward card
local function opened(payload: any)
	local look = Dungeon.CHEST_REVEAL
	local entry = if typeof(payload) == "table" then drawn[payload.key] else nil
	local lines = prizeLines(payload)
	if typeof(payload) == "table" and typeof(payload.key) == "string" then
		openedKeys[payload.key] = true
	end
	UIController.Notify(table.concat(lines, " · "), false, 5) -- what you got, also in the notifications (owner 2026-11-12)
	if not entry then
		rewardCard(lines)
		return
	end
	local open = entry.anchor:FindFirstChild("OpenChest")
	if open and open:IsA("ProximityPrompt") then
		open.Enabled = false
	end
	playSound("chestOpen")
	local started = os.clock()
	local burst = false
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		if elapsed < look.rattle then
			-- the rattle: it shakes harder and harder, light leaking out
			local shake = look.shake * (elapsed / look.rattle)
			ChestModel.place(entry.chest, entry.pivot * CFrame.Angles(0, 0, math.sin(elapsed * 40) * shake))
			ChestModel.light(entry.chest, SPARKLE, elapsed / look.rattle * 0.3)
			return
		end
		if not burst then
			burst = true
			local top = entry.anchor.Position + Vector3.new(0, entry.anchor.Size.Y / 2, 0)
			rewardCard(lines) -- first: no effect may ever keep what you got from showing
			sparkle(top)
			sparkle(top)
			lightBurst(top)
		end
		local t = math.min(1, (elapsed - look.rattle) / LID_SECONDS)
		entry.chest.lid = LID_OPEN * TweenService:GetValue(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		ChestModel.place(entry.chest, entry.pivot)
		ChestModel.light(entry.chest, SPARKLE, t)
		if t >= 1 and connection then
			connection:Disconnect()
		end
	end)
end

-- Your character swings its sword at the wall or crystal you tapped (a look only; the server counts the tap)
local function swing(prompt: ProximityPrompt)
	if not SWINGS[prompt.Name] then
		return
	end
	local anims = SwordController.GetAnims()
	if anims then
		SwordController.DrawNow()
		anims.play("cut1")
	end
end

function DungeonPuzzleController.Start()
	task.spawn(function()
		watch(workspace:WaitForChild("Dungeon"))
	end)
	Remotes.DungeonChest.OnClientEvent:Connect(opened)
	ProximityPromptService.PromptTriggered:Connect(swing)
end

return DungeonPuzzleController
