--!strict
-- The swords on everyone's characters and the first-sword popup (spec 2026-11-02-you-in-the-fight-design). Every
-- client draws a sword for each character whose Sword attribute is set (SwordService): on the back, or in the right
-- hand while SwordDrawn. The model comes from ReplicatedStorage.WeaponModels (its origin the grip's centre, the
-- blade along +Y; a code-built stand-in until it's saved). Your own draw and put-away play their moves and move the
-- sword at the Grab / Release moment; others' swords move that long after their attribute changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Swords = require(Shared:WaitForChild("Config"):WaitForChild("Swords"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local SwordAnims = require(ClientUtil:WaitForChild("SwordAnims"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local player = Players.LocalPlayer

local SwordController = {}

-- One character's sword
type View = { swordId: string, model: Model, handle: BasePart, weld: Weld, grip: CFrame, inHand: boolean, token: number }

local views: { [Model]: View } = {}
local predictedUntil = 0 -- os.clock: your sword shows drawn until then, ahead of the server's SwordDrawn (an attack)
local mine: SwordAnims.Set? = nil -- your character's sword moves
local popup: Frame? = nil

-- A plain sword from parts, the same size as the real model, for while WeaponModels has no model yet
local function standIn(): Model
	local model = Instance.new("Model")
	model.Name = "StandInSword"
	local function part(name: string, shape: Enum.PartType, size: Vector3, y: number, color: Color3, material: Enum.Material): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.CFrame = CFrame.new(0, y, 0)
		p.Color = color
		p.Material = material
		p.Parent = model
		return p
	end
	local steel, gold = Color3.fromRGB(204, 217, 235), Color3.fromRGB(235, 179, 71)
	local grip = part("Handle", Enum.PartType.Cylinder, Vector3.new(0.9, 0.26, 0.26), 0, Color3.fromRGB(92, 56, 36), Enum.Material.SmoothPlastic)
	grip.CFrame = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder lies along X: stand it up
	part("Guard", Enum.PartType.Block, Vector3.new(1.25, 0.24, 0.34), 0.52, gold, Enum.Material.SmoothPlastic)
	part("Blade", Enum.PartType.Block, Vector3.new(0.5, 3.6, 0.13), 2.42, steel, Enum.Material.Metal)
	part("Pommel", Enum.PartType.Ball, Vector3.new(0.4, 0.4, 0.4), -0.62, gold, Enum.Material.SmoothPlastic)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Grip"
	attachment.CFrame = grip.CFrame:Inverse() -- the grip's centre, blade up
	attachment.Parent = grip
	model.PrimaryPart = grip
	return model
end

-- A fresh copy of a sword's model, every part welded to its handle and taking no part in physics
local function makeModel(swordId: string): (Model, BasePart, CFrame)
	local folder = ReplicatedStorage:FindFirstChild("WeaponModels")
	local template = if folder then folder:FindFirstChild(Swords.SWORDS[swordId].model) else nil
	local model = if template and template:IsA("Model") then template:Clone() else standIn()
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			item:Destroy() -- bought or imported models can carry scripts: none may run
		end
	end
	local handle = model.PrimaryPart or model:FindFirstChild("Handle") or model:FindFirstChildWhichIsA("BasePart", true)
	assert(handle and handle:IsA("BasePart"), "a sword model needs a part")
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Massless = true
			item.CastShadow = false
			if item ~= handle then
				-- A Weld with its offset fixed now (a WeldConstraint would take whatever offset it finds when it first
				-- switches on, after the handle has already moved to the character)
				local joint = Instance.new("Weld")
				joint.Name = "SwordPiece"
				joint.Part0, joint.Part1 = handle, item
				joint.C0 = handle.CFrame:ToObjectSpace(item.CFrame)
				joint.Parent = item
			end
		end
	end
	local attachment = handle:FindFirstChild("Grip")
	local grip = if attachment and attachment:IsA("Attachment") then attachment.CFrame else CFrame.identity
	model.PrimaryPart = handle
	handle.PivotOffset = grip -- PivotTo moves it by its grip, blade up
	return model, handle, grip
end

-- Into the right hand, or onto the back
local function place(view: View, character: Model, inHand: boolean)
	local hand = character:FindFirstChild("RightHand")
	local torso = character:FindFirstChild("UpperTorso")
	local hold, back = Swords.HAND_GRIP, Swords.BACK_GRIP
	if inHand and hand and hand:IsA("BasePart") then
		view.weld.Part0 = hand
		view.weld.C0 = CFrame.new(0, hold.y, 0) * CFrame.Angles(math.rad(hold.angleX), 0, 0)
	elseif torso and torso:IsA("BasePart") then
		view.weld.Part0 = torso
		view.weld.C0 = CFrame.new(back.x, back.y, back.z) * CFrame.Angles(0, 0, math.rad(back.angleZ))
	end
	view.weld.C1 = view.grip
	view.inHand = inHand
end

local function drop(character: Model)
	local view = views[character]
	if view then
		view.model:Destroy()
		views[character] = nil
	end
end

-- The character's Sword or SwordDrawn changed (or it just appeared): make, move or remove its sword
local function refresh(character: Model)
	local swordId = character:GetAttribute("Sword")
	if typeof(swordId) ~= "string" or not Swords.SWORDS[swordId] then
		drop(character)
		return
	end
	local view = views[character]
	if view and view.swordId ~= swordId then
		drop(character)
		view = nil
	end
	local drawn = character:GetAttribute("SwordDrawn") == true or (character == player.Character and os.clock() < predictedUntil)
	if not view then
		local model, handle, grip = makeModel(swordId)
		local weld = Instance.new("Weld")
		weld.Part1 = handle
		weld.Parent = handle
		local fresh: View = { swordId = swordId, model = model, handle = handle, weld = weld, grip = grip, inHand = drawn, token = 0 }
		views[character] = fresh
		place(fresh, character, drawn)
		model.Parent = character
		return
	end
	if view.inHand == drawn then
		return
	end
	-- Draw or put away: the move plays (yours here; others' replicate) and the sword changes place at its moment
	view.token += 1
	local token = view.token
	local own = character == player.Character
	if own and mine then
		mine.play(if drawn then "draw" else "sheath")
		if drawn then
			mine.play("ready", 1, 0.2)
		else
			mine.stop("ready")
		end
	end
	task.delay(if drawn then Swords.GRAB_SECONDS else Swords.RELEASE_SECONDS, function()
		if views[character] == view and view.token == token then
			place(view, character, drawn)
		end
	end)
end

local function watchCharacter(character: Model)
	refresh(character)
	character:GetAttributeChangedSignal("Sword"):Connect(function()
		refresh(character)
	end)
	character:GetAttributeChangedSignal("SwordDrawn"):Connect(function()
		refresh(character)
	end)
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			drop(character)
		end
	end)
	if character == player.Character then
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			mine = SwordAnims.load(humanoid, Swords.STARTER)
		end
	end
end

local function watchPlayer(other: Player)
	if other.Character then
		task.spawn(watchCharacter, other.Character)
	end
	other.CharacterAdded:Connect(watchCharacter)
end

-- Your character's sword moves (SwordAnims), once it has a humanoid
function SwordController.GetAnims(): SwordAnims.Set?
	return mine
end

-- Draw your sword now (an attack): shown at once, ahead of the server's SwordDrawn; if the server never confirms
-- (a refused attack) it goes back on the back after SHEATH_SECONDS like any draw
function SwordController.DrawNow()
	local character = player.Character
	if not character or not character:GetAttribute("Sword") then
		return
	end
	predictedUntil = os.clock() + Swords.SHEATH_SECONDS
	refresh(character)
	task.delay(Swords.SHEATH_SECONDS + 0.05, function()
		if player.Character == character then
			refresh(character)
		end
	end)
end

-- "You got your first sword!": the sword turning in a window, closed with Got it (saved by the server)
local function showPopup(swordId: string)
	if popup then
		popup.Visible = true
		return
	end
	local frame, list = UIKit.panel(UIController.GetScreenGui(), "FirstSword", "You got your first sword! ⚔️")
	popup = frame
	local view = Instance.new("ViewportFrame")
	view.Size = UDim2.new(1, 0, 0, 150)
	view.BackgroundTransparency = 1
	view.LayoutOrder = 1
	view.Parent = list
	local model = makeModel(swordId)
	for _, item in model:GetDescendants() do
		if item:IsA("Weld") then
			item:Destroy() -- a still picture: anchored parts turn as one with PivotTo (welds would drag each other)
		elseif item:IsA("BasePart") then
			item.Anchored = true
		end
	end
	model.Parent = view
	model:PivotTo(CFrame.new(0, -2, 0))
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.2, 8.5), Vector3.new(0, 0.2, 0))
	camera.FieldOfView = 40
	camera.Parent = view
	view.CurrentCamera = camera
	local name = UIKit.label(list, Swords.SWORDS[swordId].name, Enum.Font.GothamBold, UIKit.textSize("title"), UIKit.Colors.Text)
	name.LayoutOrder = 2
	name.Size = UDim2.new(1, 0, 0, 34)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local info = UIKit.label(list, "It's on your back now. Fight beside your creature in boss fights: tap Attack to swing, Dodge to roll out of the rings.", Enum.Font.GothamMedium, UIKit.textSize("body"), UIKit.Colors.Subtext)
	info.LayoutOrder = 3
	info.Size = UDim2.new(1, 0, 0, 60)
	info.TextWrapped = true
	info.TextXAlignment = Enum.TextXAlignment.Center
	local ok = UIKit.button(list, "Got it", UIKit.Colors.Accent)
	ok.LayoutOrder = 4
	ok.Size = UDim2.new(1, 0, 0, 52)
	ok.Activated:Connect(function()
		UIKit.closePanel(frame)
	end)
	local angle = 0
	local spin = RunService.RenderStepped:Connect(function(dt)
		angle += dt * Swords.POPUP_TURN
		model:PivotTo(CFrame.new(0, -2, 0) * CFrame.Angles(0, angle, math.rad(-20)))
	end)
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not frame.Visible then
			Remotes.SwordSeen:FireServer()
		end
	end)
	frame.Destroying:Connect(function()
		spin:Disconnect()
	end)
	frame.Visible = true
end

function SwordController.Start()
	Remotes.SwordState.OnClientEvent:Connect(function(state: any)
		if typeof(state) == "table" and state.popup == true and typeof(state.sword) == "string" and Swords.SWORDS[state.sword] then
			showPopup(state.sword)
		end
	end)
	Remotes.SwordState:FireServer()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
end

return SwordController
