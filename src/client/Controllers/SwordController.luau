--!strict
-- The swords on everyone's characters and the first-sword popup (spec 2026-11-02-you-in-the-fight-design). Every
-- client draws a sword for each character whose Sword attribute is set (SwordService): on the back, or in the right
-- hand while SwordDrawn. The model comes from ReplicatedStorage.WeaponModels (its origin the grip's centre, the
-- blade along +Y; a code-built stand-in until it's saved). Your own draw and put-away play their moves and move the
-- sword at the Grab / Release moment; others' swords move that long after their attribute changes.
-- In boss fights (BattleController calls SetCombat) it also runs your sword: Attack (soft aim, the combo's next cut
-- as the server will pick it), Skill, Dodge (a dash with after-images) on their own cooldowns, and no jumping (the
-- dodge replaces it; Roblox's touch jump button hides itself at jump height 0). Shift Lock moves to Ctrl so Shift
-- can dodge.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared:WaitForChild("Config"):WaitForChild("Combat"))
local Swords = require(Shared:WaitForChild("Config"):WaitForChild("Swords"))
local SwordFx = require(Shared:WaitForChild("Config"):WaitForChild("SwordFx"))
local SwordRules = require(Shared:WaitForChild("Util"):WaitForChild("SwordRules"))
local SwordArcRules = require(Shared:WaitForChild("Util"):WaitForChild("SwordArcRules"))
local SwingGate = require(Shared:WaitForChild("Util"):WaitForChild("SwingGate"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local AfterImage = require(ClientUtil:WaitForChild("AfterImage"))
local HitFx = require(ClientUtil:WaitForChild("HitFx"))
local SwordAnims = require(ClientUtil:WaitForChild("SwordAnims"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local player = Players.LocalPlayer

local SwordController = {}

-- One character's sword
type View = { swordId: string, model: Model, handle: BasePart, weld: Weld, grip: CFrame, inHand: boolean, token: number, trail: Trail? }

local views: { [Model]: View } = {}
local predictedUntil = 0 -- os.clock: your sword shows drawn until then, ahead of the server's SwordDrawn (an attack)
local snapToHand = false -- the next draw of yours goes straight into the hand (an attack doesn't wait for the draw move)
local mine: SwordAnims.Set? = nil -- your character's sword moves
local popup: Frame? = nil
local sounds: { [string]: Sound } = {} -- your sword's sounds by moment, kept loaded on your root part
local hitSoundAt = 0 -- os.clock: when your own reach check last played the hit sound
local skillScale = 1 -- the sword skill's cooldown share: an Express creature shortens it (the server does the same)

-- Boss fights only
local combatTargets: (() -> { SwordRules.Target })? = nil -- the boss and its adds, for soft aim
local onCooldown: ((name: string, readyAt: number, total: number) -> ())? = nil -- the HUD's drains
local lastCut: SwordRules.LastCut? = nil
local skillReadyAt, dodgeReadyAt = 0, 0
local jumpLock: RBXScriptConnection? = nil
local kneeling = false -- your knocked-down pose is on
local jumpBefore: number? = nil
local stopPush: (() -> ())? = nil -- ends the push moving you now (a lunge, the dash slash or a dodge)
local held: Humanoid? = nil -- your humanoid while a swing holds your walking (holdControls)
local holdToken = 0
local autoRotateBefore = true
local wantedMove = Vector3.zero -- what your walking input asks for under a hold (a dodge goes that way)
local HOLD_STEP = "SwordHold"
-- Which of your sword actions is still live: a dodge, a knock-down or the fight's end cancels a cut queued for its
-- cancel point; no cut starts during the dash slash; the last cut that struck (Util/SwingGate)
local gate = SwingGate.new()

-- Moves you `studs` along `direction` (flat, unit) over `seconds`: a velocity constraint in the ground plane (gravity
-- stays free; walls, the arena's barrier, still stop it). Setting the velocity each frame lost half a dash to the
-- character's own braking. One push at a time: a new one (a dodge mid-lunge) ends the last. `plant`: stop dead at the
-- end (a lunge or the dash slash: the feet are planted, no slide; the dodge keeps its glide out).
local function push(root: BasePart, direction: Vector3, studs: number, seconds: number, name: string, plant: boolean)
	if stopPush then
		stopPush()
	end
	local speed = studs / seconds
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.new(direction.X * speed, direction.Z * speed)
	velocity.MaxForce = Combat.DODGE_FORCE
	velocity.Parent = root
	local function stop()
		if not velocity.Parent then
			return
		end
		velocity:Destroy()
		attachment:Destroy()
		if stopPush == stop then
			stopPush = nil
		end
		if plant and root.Parent then
			root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end
	end
	stopPush = stop
	task.delay(seconds, stop)
end

-- Gives your walking back (and auto-turning): at a swing's cancel point, on a dodge, a knock-down, the fight's end or
-- a new character
local function releaseHold()
	holdToken += 1
	if not held then
		return
	end
	RunService:UnbindFromRenderStep(HOLD_STEP)
	if held.Parent then
		held.AutoRotate = autoRotateBefore
	end
	held = nil
	wantedMove = Vector3.zero
end

-- Holds your walking input for `seconds` (spec 2026-11-04-sword-moves-design, "walking pauses during a swing"): the
-- lunge carries you, planted feet don't slide and walking can't push you into a boss. After Roblox's controls each
-- frame (they move the humanoid at Input priority) the move is set back to nothing. The latest hold wins.
local function holdControls(humanoid: Humanoid, seconds: number)
	releaseHold()
	held = humanoid
	autoRotateBefore = humanoid.AutoRotate
	humanoid.AutoRotate = false
	RunService:BindToRenderStep(HOLD_STEP, Enum.RenderPriority.Input.Value + 1, function()
		if held and held.Parent then
			wantedMove = held.MoveDirection
			held:Move(Vector3.zero)
		end
	end)
	local token = holdToken
	task.delay(seconds, function()
		if holdToken == token then
			releaseHold()
		end
	end)
end

-- Your sword's sound for a moment, made once on your root part and kept (so it's loaded when it plays)
local function soundFor(key: string, root: BasePart, id: string): Sound
	local sound = sounds[key]
	if sound and sound.Parent == root and sound.SoundId == id then
		return sound
	end
	if sound then
		sound:Destroy()
	end
	local made = Instance.new("Sound")
	made.Name = `Sword_{key}`
	made.SoundId = id
	made.Volume = (Swords.SOUND_VOLUMES :: any)[key] or Swords.SOUND_VOLUME
	made.Parent = root
	sounds[key] = made
	return made
end

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
	local handle = model.PrimaryPart or model:FindFirstChild("Handle") or model:FindFirstChild("Grip") or model:FindFirstChildWhichIsA("BasePart", true)
	assert(handle and handle:IsA("BasePart"), "a sword model needs a part")
	-- Where the hand holds it: its Grip attachment, else the model's pivot (an imported model's: the grip's centre,
	-- blade up). Made an attachment either way, so scaling the model (bigger on the back) moves it too.
	local attachment = handle:FindFirstChild("Grip")
	if not attachment or not attachment:IsA("Attachment") then
		local made = Instance.new("Attachment")
		made.Name = "Grip"
		made.CFrame = handle.CFrame:ToObjectSpace(model:GetPivot())
		made.Parent = handle
		attachment = made
	end
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
	local grip = (attachment :: Attachment).CFrame
	model.PrimaryPart = handle
	handle.PivotOffset = grip -- PivotTo moves it by its grip, blade up
	return model, handle, grip
end

-- Into the right hand, or onto the back (bigger there: BACK_SCALE, so the sword, and any look on it, shows)
local function place(view: View, character: Model, inHand: boolean)
	local scale = if inHand then 1 else Swords.BACK_SCALE
	if math.abs(view.model:GetScale() - scale) > 1e-3 then
		view.model:ScaleTo(scale)
	end
	local attachment = view.handle:FindFirstChild("Grip")
	view.grip = if attachment and attachment:IsA("Attachment") then attachment.CFrame else view.grip
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
		local fresh: View = { swordId = swordId, model = model, handle = handle, weld = weld, grip = grip, inHand = drawn, token = 0, trail = nil }
		if character == player.Character then
			-- The slash trail along your blade, on while a cut or the skill swings
			local blade = SwordFx.TRAIL_BLADE
			local base, tip = Instance.new("Attachment"), Instance.new("Attachment")
			base.CFrame, tip.CFrame = grip * CFrame.new(0, blade.base, 0), grip * CFrame.new(0, blade.tip, 0)
			base.Parent, tip.Parent = handle, handle
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = base, tip
			trail.Lifetime = SwordFx.TRAIL_LIFETIME
			trail.Color = ColorSequence.new(Color3.fromRGB(SwordFx.TRAIL_COLOR[1], SwordFx.TRAIL_COLOR[2], SwordFx.TRAIL_COLOR[3]))
			trail.Transparency = NumberSequence.new(0.2, 1)
			trail.LightEmission = 1
			trail.FaceCamera = true
			trail.Enabled = false
			trail.Parent = handle
			fresh.trail = trail
		end
		views[character] = fresh
		place(fresh, character, drawn)
		model.Parent = character
		return
	end
	if view.inHand == drawn then
		return
	end
	-- Your draw gleams: a flash of light and a glint at the blade's tip
	local function gleam()
		local tip = if view.trail then view.trail.Attachment1 else nil
		if not tip then
			return
		end
		local spec = SwordFx.GLEAM
		local tint = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = tint, spec.range, spec.brightness
		light.Parent = tip
		TweenService:Create(light, TweenInfo.new(spec.seconds), { Brightness = 0 }):Play()
		local glint = Instance.new("ParticleEmitter")
		glint.Enabled = false
		glint.Color = ColorSequence.new(tint)
		glint.LightEmission = 1
		glint.Lifetime = NumberRange.new(spec.seconds)
		glint.Speed = NumberRange.new(0)
		glint.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.4, spec.size),
			NumberSequenceKeypoint.new(1, 0),
		})
		glint.RotSpeed = NumberRange.new(180)
		glint.Parent = tip
		glint:Emit(1)
		task.delay(spec.seconds * 2, function()
			light:Destroy()
			glint:Destroy()
		end)
	end
	-- Draw or put away: the move plays (yours here; others' replicate) and the sword changes place at its moment
	view.token += 1
	local token = view.token
	local own = character == player.Character
	if own and drawn and snapToHand then
		snapToHand = false
		place(view, character, true) -- an attack: straight into the hand, the cut is the move
		if mine then
			mine.play("ready", 1, 0.2)
		end
		SwordController.PlaySound("draw")
		gleam()
		return
	end
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
			if own and drawn then
				gleam()
			end
		end
	end)
end

local function watchCharacter(character: Model)
	-- The body arrives after CharacterAdded: a sword placed before its UpperTorso exists hangs on nothing and falls out
	-- of the world (the owner's sword vanished from their back), so wait for the torso first
	character:WaitForChild("UpperTorso", Swords.BODY_WAIT)
	refresh(character)
	-- A body part replaced later (a new body applied) leaves the weld on a part that's gone: put the sword on the new one
	character.ChildAdded:Connect(function(child)
		local view = views[character]
		if view and (child.Name == "UpperTorso" or child.Name == "RightHand") then
			place(view, character, view.inHand)
		end
	end)
	character:GetAttributeChangedSignal("Sword"):Connect(function()
		refresh(character)
	end)
	character:GetAttributeChangedSignal("SwordDrawn"):Connect(function()
		refresh(character)
	end)
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			drop(character)
			if held and held:IsDescendantOf(character) then
				releaseHold()
			end
		end
	end)
	if character == player.Character then
		releaseHold() -- a hold left on the last character
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			mine = SwordAnims.load(humanoid, Swords.STARTER)
			kneeling = false
		end
		-- Every sound ready on the new root part before the first swing
		local root = character:WaitForChild("HumanoidRootPart", 10)
		local sword = Swords.SWORDS[Swords.STARTER]
		if root and root:IsA("BasePart") and sword then
			for key, id in sword.sounds do
				if id ~= "" then
					soundFor(key, root, id)
				end
			end
		end
		-- The server clearing Downed (you got up, or the fight ended) always stands you up
		character:GetAttributeChangedSignal("Downed"):Connect(function()
			if not character:GetAttribute("Downed") then
				SwordController.GetUp()
			end
		end)
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
	snapToHand = true
	refresh(character)
	snapToHand = false
	task.delay(Swords.SHEATH_SECONDS + 0.05, function()
		if player.Character == character then
			refresh(character)
		end
	end)
end

-- One of your sword's sounds (Config/Swords sounds; silent while its id is empty). Each stays on your root part,
-- loaded, and replays from the start: a new Sound per swing could start late while it loaded.
function SwordController.PlaySound(key: string)
	local character = player.Character
	local swordId = if character then character:GetAttribute("Sword") else nil
	local sword = if typeof(swordId) == "string" then Swords.SWORDS[swordId] else Swords.SWORDS[Swords.STARTER]
	local id = if sword then sword.sounds[key] else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not id or id == "" or not root then
		return
	end
	local sound = soundFor(key, root :: BasePart, id)
	sound.TimePosition = 0
	-- A different pitch each time (owner 2026-11-04: the same swing and hit over and over got tiring)
	local pitch = Swords.SOUND_PITCH
	sound.PlaybackSpeed = pitch[1] + math.random() * (pitch[2] - pitch[1])
	sound:Play()
end

-- Boss fights: the share of the sword skill's cooldown it takes now (1 - an Express creature's perk)
function SwordController.SetSkillScale(scale: number)
	skillScale = math.clamp(scale, 0.1, 1)
end

-- Whether the hit sound just played from your own reach check (BattleController skips the server's late copy)
function SwordController.HitSoundJustPlayed(): boolean
	return os.clock() - hitSoundAt < Swords.HIT_SOUND_WINDOW
end

-- The trail along your blade for one swing
local function swingTrail()
	local view = if player.Character then views[player.Character] else nil
	local trail = if view then view.trail else nil
	if not trail then
		return
	end
	trail.Enabled = true
	task.delay(SwordFx.TRAIL_SECONDS, function()
		trail.Enabled = false
	end)
end

-- Knocked down (the "down" event): the down move held at its Hold marker until GetUp, which the getUp event, the
-- server clearing Downed or the fight ending (SetCombat false) calls, whichever comes first. A loss lands in the same
-- step you go down, so its Downed attribute can clear before the event arrives; the fight's end stands you up then.
function SwordController.Kneel()
	if kneeling then
		return
	end
	kneeling = true
	SwingGate.cancel(gate)
	releaseHold()
	if stopPush then
		stopPush()
	end
	local set = mine
	local track = if set then set.play("down") else nil
	if track then
		track:GetMarkerReachedSignal("Hold"):Once(function()
			track:AdjustSpeed(0)
		end)
	end
	SwordController.PlaySound("down")
end

function SwordController.GetUp()
	if not kneeling then
		return
	end
	kneeling = false
	if mine then
		mine.stop("down", 0.1)
		mine.play("getUp")
	end
	SwordController.PlaySound("getUp")
end

local function ownParts(): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not character or not root or not root:IsA("BasePart") or not humanoid or character:GetAttribute("Downed") then
		return nil, nil, nil
	end
	return character, root, humanoid
end

-- Turn to the nearest target in front of you, if one is close (SwordRules.aimTarget)
local function softAim(root: BasePart)
	if not combatTargets then
		return
	end
	local targets = combatTargets()
	local look = root.CFrame.LookVector
	local id = SwordRules.aimTarget(root.Position.X, root.Position.Z, look.X, look.Z, targets, Swords.SOFT_AIM_RANGE, Swords.SOFT_AIM_ANGLE)
	for _, target in targets do
		if target.id == id then
			root.CFrame = CFrame.lookAt(root.Position, Vector3.new(target.x, root.Position.Y, target.z))
		end
	end
end

-- Boss fights: start or stop running your sword. targets: the boss and its adds now; cooldown: the HUD's drains.
function SwordController.SetCombat(active: boolean, targets: (() -> { SwordRules.Target })?, cooldown: ((name: string, readyAt: number, total: number) -> ())?)
	combatTargets = if active then targets else nil
	onCooldown = if active then cooldown else nil
	lastCut = nil
	SwingGate.cancel(gate)
	if not active then
		SwordController.GetUp()
		releaseHold()
	end
	if jumpLock then
		jumpLock:Disconnect()
		jumpLock = nil
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then
		return
	end
	if active then
		jumpBefore = if humanoid.JumpHeight > 0 then humanoid.JumpHeight else jumpBefore
		humanoid.JumpHeight = 0
		-- The server puts it back when you get up: keep it at 0 for the fight
		jumpLock = humanoid:GetPropertyChangedSignal("JumpHeight"):Connect(function()
			if humanoid.JumpHeight ~= 0 then
				jumpBefore = humanoid.JumpHeight
				humanoid.JumpHeight = 0
			end
		end)
	elseif jumpBefore then
		humanoid.JumpHeight = jumpBefore
	end
end

-- Whether a hit of yours of this kind ("Sword" or "Skill", the server's) is a big one: the skill, or the combo's last
-- cut (the last cut whose strike frame came, not your latest tap: the server's hit is a round trip behind). Big hits
-- freeze longer (SwordFx.HIT_STOP) and shake harder.
function SwordController.IsBigHit(kind: string): boolean
	local character = player.Character
	local swordId = if character then character:GetAttribute("Sword") else nil
	local sword = if typeof(swordId) == "string" then Swords.SWORDS[swordId] else nil
	return kind == "Skill" or (sword ~= nil and SwingGate.lastStruck(gate) == #sword.combo)
end

-- The hit sound and the hit-stop the moment the blade lands, when your own reach check says it connects: the server's
-- hit comes a round trip later (the spec's anti-goal: hits that land later than the swing shows)
-- Where a hit's star burst goes: on target `id`'s side facing `from` (an attacker's root), or on the nearest target's
-- when no id is given (SwordArcRules.hitPoint), a little above the attacker's root
local function burstPoint(targets: { SwordRules.Target }, from: Vector3, id: string?): Vector3?
	local best: SwordRules.Target? = nil
	local nearest = math.huge
	for _, target in targets do
		local distance = Vector2.new(target.x - from.X, target.z - from.Z).Magnitude - target.radius
		if (id == nil or target.id == id) and distance < nearest then
			best, nearest = target, distance
		end
	end
	if not best then
		return nil
	end
	local x, z = SwordArcRules.hitPoint(best.x, best.z, best.radius, from.X, from.Z, SwordFx.BURST.share)
	return Vector3.new(x, from.Y + SwordFx.BURST.up, z)
end

-- Boss fights: where a sword hit on target `id` bursts, struck from `from` (BattleController's hits)
function SwordController.HitPoint(id: string, from: Vector3): Vector3?
	return if combatTargets then burstPoint(combatTargets(), from, id) else nil
end

-- move: the cut (1-3) or "skill". A cut's star burst (and on the finisher its ring) pops at once; the dash slash's
-- bursts and cut lines come with the server's hit, on each foe it reached (BattleController)
local function predictHit(connects: (root: BasePart, targets: { SwordRules.Target }) -> boolean, move: number | string, last: boolean)
	local character, root = ownParts()
	if not root or not combatTargets then
		return
	end
	local targets = combatTargets()
	if not connects(root, targets) then
		return
	end
	hitSoundAt = os.clock()
	SwordController.PlaySound("hit")
	if mine then
		mine.hitStop(if move == "skill" or last then SwordFx.HIT_STOP.big else SwordFx.HIT_STOP.cut)
	end
	local sword = if character then Swords.SWORDS[character:GetAttribute("Sword") :: string] else nil
	local at = burstPoint(targets, root.Position, nil)
	if not sword or move == "skill" or not at then
		return
	end
	local tint = Color3.fromRGB(sword.slash.color[1], sword.slash.color[2], sword.slash.color[3])
	local burst = SwordFx.BURST
	HitFx.burst(at, (if last then burst.big else burst.size) * sword.slash.scale, tint)
	if last then
		HitFx.ring(at, SwordFx.RING.size * sword.slash.scale, tint)
	end
end

-- Your flat facing (unit)
local function facing(root: BasePart): Vector3
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
end

-- Is this swing still the one playing (no newer cut, skill or dodge, still in the fight, still standing)?
local function stillSwinging(token: number): boolean
	return SwingGate.live(gate, token) and combatTargets ~= nil and not kneeling
end

-- An Attack tap: the combo's next cut (the server picks the same one and checks reach), facing the nearest target.
-- Cuts chain at their cancel point (SwordRules.nextCut); each holds your walking until then and lunges you in, stopping
-- short of a foe (SwordRules.lungeLength). The animations are in place: the lunge is the real movement.
function SwordController.Attack()
	local character, root = ownParts()
	local sword = if character then Swords.SWORDS[character:GetAttribute("Sword") :: string] else nil
	if not character or not root or not sword then
		return
	end
	local now = os.clock()
	if not SwingGate.canAttack(gate, now) then
		return -- the dash slash is playing
	end
	local index, startAt = SwordRules.nextCut(sword.combo, lastCut, now, Swords.COMBO_RESET)
	if not index or not startAt then
		return
	end
	lastCut = { index = index, startedAt = startAt }
	local token = SwingGate.begin(gate)
	local cut = sword.combo[index]
	SwordController.DrawNow()
	Remotes.SwordAttack:FireServer()
	-- The server strikes this cut then whatever happens here: what landed is this cut (IsBigHit)
	task.delay(startAt - now + cut.hitAt, SwingGate.struck, gate, index)
	task.delay(startAt - now, function()
		local _, at, humanoid = ownParts()
		if not at or not humanoid or not stillSwinging(token) then
			return -- a dodge, the dash slash, a knock-down or the fight's end came first
		end
		softAim(at)
		holdControls(humanoid, cut.cancelAt or cut.length)
		if mine then
			mine.play(`cut{index}`)
		end
		swingTrail()
		SwordController.PlaySound(`swing{index}`)
		-- The candy sparkle arc as the blade comes round, and the finisher's dust where it lands
		local arc = (SwordFx.ARCS :: any)[`cut{index}`] :: HitFx.ArcLook?
		if arc then
			task.delay(arc.from, function()
				local _, arcRoot = ownParts()
				if arcRoot and stillSwinging(token) then
					HitFx.swingArc(arcRoot.CFrame, arc, sword.slash)
				end
			end)
		end
		if index == #sword.combo then
			task.delay(cut.hitAt, function()
				local _, feetRoot, feetHumanoid = ownParts()
				if feetRoot and feetHumanoid and stillSwinging(token) then
					HitFx.dust(feetRoot.Position - Vector3.new(0, feetHumanoid.HipHeight + feetRoot.Size.Y / 2, 0))
				end
			end)
		end
		local lunge = cut.lunge
		if lunge then
			task.delay(lunge.from, function()
				local _, lungeRoot = ownParts()
				if not lungeRoot or not stillSwinging(token) then
					return
				end
				local direction = facing(lungeRoot)
				local targets = if combatTargets then combatTargets() else {}
				local studs = SwordRules.lungeLength(lungeRoot.Position.X, lungeRoot.Position.Z, direction.X, direction.Z, targets, lunge.studs, Swords.LUNGE_STOP)
				if studs > 0.05 then
					push(lungeRoot, direction, studs, lunge.to - lunge.from, "SwordLunge", true)
				end
			end)
		end
		task.delay(cut.hitAt, function()
			if stillSwinging(token) then
				predictHit(function(hitRoot: BasePart, targets: { SwordRules.Target }): boolean
					local look = hitRoot.CFrame.LookVector
					return SwordRules.anyInReach(hitRoot.Position.X, hitRoot.Position.Z, look.X, look.Z, targets, cut)
				end, index, index == #sword.combo)
			end
		end)
	end)
end

-- The sword skill, the dash slash (spec 2026-11-04-sword-moves-design), on its cooldown: a draw stance, then a dash
-- along your facing that goes through foes (SwordRules.dashLength) with after-images, and at its hit frame every foe
-- along the path from where you started is hit (the server checks the same path, clamped)
function SwordController.Skill()
	local character, root, humanoid = ownParts()
	local sword = if character then Swords.SWORDS[character:GetAttribute("Sword") :: string] else nil
	if not character or not root or not humanoid or not sword or os.clock() < skillReadyAt then
		return
	end
	local skill = sword.skill
	local cooldown = skill.cooldown * skillScale
	skillReadyAt = os.clock() + cooldown
	if onCooldown then
		onCooldown("skill", skillReadyAt, cooldown)
	end
	SwordController.DrawNow()
	Remotes.SwordSkill:FireServer()
	local token = SwingGate.startSkill(gate, os.clock(), skill.length)
	softAim(root)
	holdControls(humanoid, skill.length)
	if mine then
		mine.play("skill")
	end
	swingTrail()
	SwordController.PlaySound("swing3")
	local arc = SwordFx.ARCS.skill :: HitFx.ArcLook
	task.delay(arc.from, function()
		local _, arcRoot = ownParts()
		if arcRoot and stillSwinging(token) then
			HitFx.swingArc(arcRoot.CFrame, arc, sword.slash)
		end
	end)
	local dash = skill.dash
	local startX, startZ = root.Position.X, root.Position.Z
	task.delay(dash.from, function()
		local own, at = ownParts()
		if not own or not at or not stillSwinging(token) then
			return
		end
		local direction = facing(at)
		local targets = if combatTargets then combatTargets() else {}
		local studs = SwordRules.dashLength(at.Position.X, at.Position.Z, direction.X, direction.Z, targets, dash.studs, dash.margin, dash.maxStuds)
		AfterImage.spawn(own, 4, dash.to - dash.from + 0.15)
		push(at, direction, studs, dash.to - dash.from, "SwordDash", true)
	end)
	task.delay(skill.hitAt, function()
		if stillSwinging(token) then
			predictHit(function(hitRoot: BasePart, targets: { SwordRules.Target }): boolean
				return SwordRules.anyInDashPath(startX, startZ, hitRoot.Position.X, hitRoot.Position.Z, targets, dash.width)
			end, "skill", false)
		end
	end)
end

-- A dodge: untouchable for a moment (the server's), a dash the way you're moving (backward when still), after-images.
-- It cancels a swing: your walking comes back and the swing's lunge or dash stops.
function SwordController.Dodge()
	local character, root, humanoid = ownParts()
	if not character or not root or not humanoid or os.clock() < dodgeReadyAt then
		return
	end
	dodgeReadyAt = os.clock() + Combat.DODGE_COOLDOWN
	if onCooldown then
		onCooldown("dodge", dodgeReadyAt, Combat.DODGE_COOLDOWN)
	end
	local input = if held then wantedMove else humanoid.MoveDirection
	SwingGate.cancel(gate)
	releaseHold()
	Remotes.Dodge:FireServer()
	SwordController.PlaySound("dodge")
	local move = Vector3.new(input.X, 0, input.Z)
	local direction = if move.Magnitude > 0.1 then move.Unit else -facing(root)
	-- Through foes: a dash that would end inside a boss or monster carries on out of it (SwordRules.dashLength)
	local length = SwordRules.dashLength(root.Position.X, root.Position.Z, direction.X, direction.Z, if combatTargets then combatTargets() else {}, Combat.DODGE_STUDS, Combat.DODGE_PASS_MARGIN, Combat.DODGE_MAX_STUDS)
	if mine then
		mine.play("dodge")
	end
	AfterImage.spawn(character, 4, Combat.DODGE_SECONDS + 0.15)
	push(root, direction, length, Combat.DODGE_SECONDS, "DodgeAttachment", false)
end

-- Shift dodges in boss fights, so Shift Lock moves to Ctrl (Roblox's camera reads its keys from this value)
local function moveShiftLock()
	local scripts = player:WaitForChild("PlayerScripts", 10)
	local module = if scripts then scripts:WaitForChild("PlayerModule", 10) else nil
	local camera = if module then module:WaitForChild("CameraModule", 10) else nil
	local lock = if camera then camera:WaitForChild("MouseLockController", 10) else nil
	local keys = if lock then lock:WaitForChild("BoundKeys", 10) else nil
	if keys and keys:IsA("StringValue") then
		keys.Value = "LeftControl,RightControl"
	end
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
	-- With a mouse there's no Attack button (a click attacks)
	local how = if UserInputService.MouseEnabled then "click to swing, Shift to dodge" else "tap Attack to swing, Dodge to roll out of the way"
	local info = UIKit.label(list, `It's on your back now. Fight beside your creature against bosses and wild monsters: {how}.`, Enum.Font.GothamMedium, UIKit.textSize("body"), UIKit.Colors.Subtext)
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
	task.spawn(moveShiftLock)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
end

return SwordController
