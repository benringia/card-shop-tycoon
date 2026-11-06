--!strict
-- The swords on everyone's characters and the first-sword popup (spec 2026-11-02-you-in-the-fight-design). Every
-- client draws a sword for each character whose Sword attribute is set (WeaponService: a Config/Weapons id, with
-- SwordGrade and SwordLevel): on the back, or in the right hand while SwordDrawn. The model comes from
-- ReplicatedStorage.WeaponModels (its origin the grip's centre, the blade along +Y; a code-built stand-in until it's
-- saved), with its glow ladder (Util/WeaponLook); its moves are its moveset's (Config/Swords). Your own draw and put-away play their moves and move the
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
local Weapons = require(Shared:WaitForChild("Config"):WaitForChild("Weapons"))
local SwordFx = require(Shared:WaitForChild("Config"):WaitForChild("SwordFx"))
local WeaponLooks = require(Shared:WaitForChild("Config"):WaitForChild("WeaponLooks"))
local SwordRules = require(Shared:WaitForChild("Util"):WaitForChild("SwordRules"))
local SwordArcRules = require(Shared:WaitForChild("Util"):WaitForChild("SwordArcRules"))
local SwingGate = require(Shared:WaitForChild("Util"):WaitForChild("SwingGate"))
local WeaponLookRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponLookRules"))
local SwordSkillFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("SwordSkillFx"))
local SwordSkillFxRules = require(Shared:WaitForChild("Util"):WaitForChild("SwordSkillFxRules"))
local SoundLevel = require(Shared:WaitForChild("Util"):WaitForChild("SoundLevel"))
local SoundLevels = require(Shared:WaitForChild("Config"):WaitForChild("SoundLevels"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local AfterImage = require(ClientUtil:WaitForChild("AfterImage"))
local HitFx = require(ClientUtil:WaitForChild("HitFx"))
local SwordAnims = require(ClientUtil:WaitForChild("SwordAnims"))
local SwordSkillFx = require(ClientUtil:WaitForChild("SwordSkillFx"))
local SkillCinematic = require(ClientUtil:WaitForChild("SkillCinematic"))
local ScreenFx = require(ClientUtil:WaitForChild("ScreenFx"))
local WeaponLook = require(ClientUtil:WaitForChild("WeaponLook"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local player = Players.LocalPlayer

local SwordController = {}

-- One character's sword: its weapon (a Config/Weapons id), grade and level
type View = {
	swordId: string,
	grade: string,
	level: number,
	model: Model,
	handle: BasePart,
	weld: Weld,
	grip: CFrame,
	inHand: boolean,
	token: number,
	trail: Trail?,
}

local views: { [Model]: View } = {}

-- A weapon's moveset id (Config/Swords); nil for anything that isn't a built weapon
local function movesetOf(weaponId: unknown): string?
	local weapon = if typeof(weaponId) == "string" then Weapons.ById[weaponId] else nil
	local moveset = if weapon then weapon.moveset else nil
	return if moveset and Swords.SWORDS[moveset] then moveset else nil
end

-- The moves a weapon swings (its Config/Swords moveset); nil for anything that isn't a built weapon
local function swordOf(weaponId: unknown): Swords.Sword?
	local moveset = movesetOf(weaponId)
	return if moveset then Swords.SWORDS[moveset] else nil
end

local foeElement: string? = nil -- the element of what you're fighting (BattleController), for the Prism Blade's colour

-- A character's slash colour and size: its weapon's trail colour (the Steel Sword keeps its moves' pale steel; your
-- own Prism Blade takes the colour strong against your foe)
local function slashOf(character: Model?, sword: Swords.Sword): { color: { number }, scale: number }
	local weaponId = if character then character:GetAttribute("Sword") else nil
	local foe = if character ~= nil and character == player.Character then foeElement else nil
	local trail = if typeof(weaponId) == "string" then WeaponLook.trailColor(weaponId, foe) else nil
	return if trail then { color = trail, scale = sword.slash.scale } else sword.slash
end

-- A character's weapon grade and level (C, +0 when unset)
local function gradeAndLevel(character: Model): (string, number)
	local grade = character:GetAttribute("SwordGrade")
	local level = character:GetAttribute("SwordLevel")
	return if typeof(grade) == "string" then grade else "C", if typeof(level) == "number" then level else 0
end
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
local paused = false -- a super's cinematic is playing on your screen: no cuts, skill or dodge (Util/SuperCinematic)
local othersFull = 0 -- other players' sword effects drawing in full now (SwordSkillFxRules.drawsOthers)

-- A character's round 1 sword effects (spec 2026-11-06-sword-skills-design 4): its moveset's looks, its weapon's
-- colours and the size its level gives; nil for the Steel Sword (none)
type Effects = { fx: Swords.SwordFx, colors: SwordSkillFx.Colors, scale: number }
local function effectsOf(character: Model): Effects?
	local weaponId = character:GetAttribute("Sword")
	local weapon = if typeof(weaponId) == "string" then Weapons.ById[weaponId] else nil
	local sword = swordOf(weaponId)
	if not weapon or not sword or not sword.fx then
		return nil
	end
	local grade, level = gradeAndLevel(character)
	local layers = WeaponLookRules.layers(WeaponLooks, weapon.rarity, level, grade, "hand")
	return { fx = sword.fx, colors = SwordSkillFx.colorsOf(weapon.id), scale = SwordSkillFxRules.scale(layers.trailScale) }
end

-- Where a character's skill lands, as the server will count it from where it stands now (SwordRules.skillImpact, at
-- its root's height): a crescent's burst on the first foe it touches (the end of its run when none, or outside a boss
-- fight), the judged foe; nil for the skills drawn around it or along its facing
local function skillAim(character: Model, sword: Swords.Sword): Vector3?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local look = root.CFrame.LookVector
	local x, z = SwordRules.skillImpact(sword.skill.shape, root.Position.X, root.Position.Z, look.X, look.Z, if combatTargets then combatTargets() else {})
	return if x and z then Vector3.new(x, root.Position.Y, z) else nil
end

-- A character's blade (its sword in the world): the handle and the blade's base and tip, for effects along it
local function bladeOf(character: Model): SwordSkillFx.Blade?
	local view = views[character]
	if not view or not view.handle.Parent then
		return nil
	end
	local blade = SwordFx.TRAIL_BLADE
	return { part = view.handle, base = view.grip * CFrame.new(0, blade.base, 0), tip = view.grip * CFrame.new(0, blade.tip, 0) }
end

-- A cut's effects on a character: its slash as the blade comes round, and on the finisher the slam's burst
-- (`finisher` false: the slash only, another player's light version)
local function cutEffects(character: Model, sword: Swords.Sword, effects: Effects, index: number, finisher: boolean, live: () -> boolean)
	local arc = (SwordFx.ARCS :: any)[`cut{index}`]
	task.delay(if arc then arc.from else 0, function()
		if live() then
			SwordSkillFx.slash(character, effects.fx.slash, index, effects.colors, effects.scale, bladeOf(character))
		end
	end)
	if finisher and index == #sword.combo then
		task.delay(sword.combo[index].hitAt, function()
			local at = SwordSkillFx.slamPoint(character)
			if at and live() then
				SwordSkillFx.finisher(at, effects.fx.finisher, effects.colors, effects.scale)
			end
		end)
	end
end

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
	-- Its level, a loud one turned down to the others' (Config/SoundLevels; an unmeasured sound as it is)
	made.Volume = ((Swords.SOUND_VOLUMES :: any)[key] or Swords.SOUND_VOLUME) * SoundLevel.gain(SoundLevels, id)
	made.Parent = root
	sounds[key] = made
	return made
end

-- A fresh copy of a weapon's model (a stand-in in its colours while WeaponModels has none) with its glow ladder,
-- every part welded to its handle and taking no part in physics
local function makeModel(weaponId: string, grade: string, level: number): (Model, BasePart, CFrame)
	local folder = ReplicatedStorage:FindFirstChild("WeaponModels")
	local modelName = (Weapons.ById[weaponId] :: Weapons.Weapon).model
	local template = if folder and modelName then folder:FindFirstChild(modelName) else nil
	local model = if template and template:IsA("Model") then template:Clone() else WeaponLook.standIn(weaponId)
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			item:Destroy() -- bought or imported models can carry scripts: none may run
		end
	end
	WeaponLook.apply(model, weaponId, grade, level)
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
	WeaponLook.setPlace(view.model, view.swordId, view.grade, view.level, if inHand then "hand" else "back")
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
	if typeof(swordId) ~= "string" or not swordOf(swordId) then
		drop(character)
		return
	end
	local grade, level = gradeAndLevel(character)
	local view = views[character]
	if view and (view.swordId ~= swordId or view.grade ~= grade or view.level ~= level) then
		drop(character)
		view = nil
	end
	local drawn = character:GetAttribute("SwordDrawn") == true or (character == player.Character and os.clock() < predictedUntil)
	if not view then
		local model, handle, grip = makeModel(swordId, grade, level)
		local weld = Instance.new("Weld")
		weld.Part1 = handle
		weld.Parent = handle
		local fresh: View = {
			swordId = swordId,
			grade = grade,
			level = level,
			model = model,
			handle = handle,
			weld = weld,
			grip = grip,
			inHand = drawn,
			token = 0,
			trail = nil,
		}
		if character == player.Character then
			-- The slash trail along your blade, on while a cut or the skill swings
			local blade = SwordFx.TRAIL_BLADE
			local base, tip = Instance.new("Attachment"), Instance.new("Attachment")
			base.CFrame, tip.CFrame = grip * CFrame.new(0, blade.base, 0), grip * CFrame.new(0, blade.tip, 0)
			base.Parent, tip.Parent = handle, handle
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = base, tip
			trail.Lifetime = SwordFx.TRAIL_LIFETIME
			-- In the weapon's trail colour, wider from +7 (its look's layers); the Steel Sword keeps its pale steel
			local trailColor = WeaponLook.trailColor(swordId, foeElement) or SwordFx.TRAIL_COLOR
			local layers = WeaponLook.layers(swordId, grade, level, "hand")
			trail.Color = ColorSequence.new(Color3.fromRGB(trailColor[1], trailColor[2], trailColor[3]))
			trail.WidthScale = NumberSequence.new(if layers then layers.trailScale else 1)
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
	-- An upgrade or a reforge: the look rebuilt at its new level or grade
	character:GetAttributeChangedSignal("SwordGrade"):Connect(function()
		refresh(character)
	end)
	character:GetAttributeChangedSignal("SwordLevel"):Connect(function()
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
		local root = character:WaitForChild("HumanoidRootPart", 10)
		-- Your moves and sounds are your equipped sword's moveset's (its own skill: Sunfall Cleave's jump, not the dash
		-- slash), loaded again whenever you equip another; every sound ready on the root part before the first swing
		local function loadMoves()
			local moveset = movesetOf(character:GetAttribute("Sword")) or Swords.STARTER
			local sword = Swords.SWORDS[moveset]
			if humanoid and humanoid:IsA("Humanoid") then
				mine = SwordAnims.load(humanoid, moveset)
			end
			if root and root:IsA("BasePart") then
				for key, id in sword.sounds do
					if id ~= "" then
						soundFor(key, root, id)
					end
				end
			end
		end
		loadMoves()
		kneeling = false
		character:GetAttributeChangedSignal("Sword"):Connect(loadMoves)
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
	local sword = swordOf(if character then character:GetAttribute("Sword") else nil) or Swords.SWORDS[Swords.STARTER]
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

-- A sword hit's sound: the blade's slice with a thud under it, and on a big hit (the finisher, the dash slash) a beefy
-- burst on top
function SwordController.PlayHit(big: boolean)
	SwordController.PlaySound("hit")
	SwordController.PlaySound("hitThud")
	if big then
		SwordController.PlaySound("hitBig")
	end
end

-- Boss fights: the share of the sword skill's cooldown it takes now (1 - an Express creature's perk)
function SwordController.SetSkillScale(scale: number)
	skillScale = math.clamp(scale, 0.1, 1)
end

-- Whether the hit sound just played from your own reach check (BattleController skips the server's late copy)
function SwordController.HitSoundJustPlayed(): boolean
	return os.clock() - hitSoundAt < Swords.HIT_SOUND_WINDOW
end

-- What you're fighting's element (BattleController, nil when the fight ends): your Prism Blade's trail and slashes take
-- the colour strong against it
function SwordController.SetFoeElement(element: string?)
	foeElement = element
	local view = if player.Character then views[player.Character] else nil
	if view and view.trail then
		local color = WeaponLook.trailColor(view.swordId, element) or SwordFx.TRAIL_COLOR
		view.trail.Color = ColorSequence.new(Color3.fromRGB(color[1], color[2], color[3]))
	end
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
	local sword = swordOf(if character then character:GetAttribute("Sword") else nil)
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

-- A character's sword hit colour and size (BattleController's hit bursts): its weapon's trail colour
function SwordController.SlashOf(character: Model?): { color: { number }, scale: number }
	local sword = swordOf(if character then character:GetAttribute("Sword") else nil) or Swords.SWORDS[Swords.STARTER]
	return slashOf(character, sword)
end

-- A character's blade in the world (its drawn or carried sword), for effects along it (MovePreviewController)
function SwordController.BladeOf(character: Model): SwordSkillFx.Blade?
	return bladeOf(character)
end

-- A character's own skill look (a round 1 sword's, Config/SwordSkillFx), nil for the Steel Sword's dash slash
function SwordController.SkillLook(character: Model?): string?
	local effects = if character then effectsOf(character) else nil
	return if effects then effects.fx.skill else nil
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
	SwordController.PlayHit(move == "skill" or last)
	if mine then
		mine.hitStop(if move == "skill" or last then SwordFx.HIT_STOP.big else SwordFx.HIT_STOP.cut)
	end
	local sword = swordOf(if character then character:GetAttribute("Sword") else nil)
	local at = burstPoint(targets, root.Position, nil)
	if not sword or move == "skill" or not at then
		return
	end
	local slash = slashOf(character, sword)
	local tint = Color3.fromRGB(slash.color[1], slash.color[2], slash.color[3])
	local burst = SwordFx.BURST
	HitFx.burst(at, (if last then burst.big else burst.size) * slash.scale, tint)
	-- The finisher's ring; from +7 an element burst on every hit (the weapon's layers)
	local view = if character then views[character] else nil
	local layers = if view then WeaponLook.layers(view.swordId, view.grade, view.level, "hand") else nil
	if last or (layers and layers.burst) then
		HitFx.ring(at, SwordFx.RING.size * slash.scale, tint)
	end
end

-- Your flat facing (unit)
local function facing(root: BasePart): Vector3
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
end

-- A finisher's hang (Swords cut `hang`): your camera eases in a little over `seconds`, then back as the fall starts,
-- whatever happened meanwhile (a dodge mid-hang still gets the view back)
local function hangZoom(seconds: number)
	local camera = workspace.CurrentCamera
	local zoom = SwordFx.HANG_ZOOM
	local before = camera.FieldOfView
	local easeIn = TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { FieldOfView = before - zoom.degrees })
	easeIn:Play()
	task.delay(seconds, function()
		easeIn:Cancel()
		TweenService:Create(camera, TweenInfo.new(zoom.back, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = before }):Play()
	end)
end

-- Is this swing still the one playing (no newer cut, skill or dodge, still in the fight, still standing)?
local function stillSwinging(token: number): boolean
	return SwingGate.live(gate, token) and combatTargets ~= nil and not kneeling
end

-- A move's sounds at their moments (Config/Swords cues): the swish with the swing, the finisher's jump and slam, the
-- dash slash's draw, dash and cut lines; a dodge or anything that ends the swing stops the ones still to come
local function playCues(sword: Swords.Sword, move: string, token: number)
	for _, cue in sword.cues[move] or {} do
		task.delay(cue.at, function()
			if stillSwinging(token) then
				SwordController.PlaySound(cue.key)
			end
		end)
	end
end

-- A held skill's pose (Config/Swords skill.hold: Thornline's blade in the ground) frozen at its `at` for `seconds`
-- (SwordRules.holdFor), so its next key plays as the skill reaches its foe; `live()` false (a dodge): no hold
local function holdPose(track: AnimationTrack, hold: Swords.Hold?, seconds: number, live: () -> boolean)
	if not hold or seconds <= 0 then
		return
	end
	task.delay(hold.at, function()
		if not live() or not track.IsPlaying then
			return
		end
		track:AdjustSpeed(0)
		task.delay(seconds, function()
			if track.IsPlaying then
				track:AdjustSpeed(1)
			end
		end)
	end)
end

-- A skill's held pose on a track playing it (MovePreviewController): held until the skill reaches its foe `travel`
-- seconds after its hit moment; returns how much longer the move runs
function SwordController.HoldSkill(track: AnimationTrack, skill: Swords.Skill, travel: number): number
	local held = if skill.hold then SwordRules.holdFor(skill.hitAt, travel, skill.hold.snap) else 0
	holdPose(track, skill.hold, held, function(): boolean
		return track.IsPlaying
	end)
	return held
end

-- A move's sound cues on your character without swinging (MovePreviewController's /skillfx, out of a fight): the
-- equipped sword's sounds at their moments, as a fight plays them
function SwordController.PlayCues(move: string)
	local character = player.Character
	local sword = swordOf(if character then character:GetAttribute("Sword") else nil)
	for _, cue in (if sword then sword.cues[move] else nil) or {} do
		task.delay(cue.at, SwordController.PlaySound, cue.key)
	end
end

-- An Attack tap: the combo's next cut (the server picks the same one and checks reach), facing the nearest target.
-- Cuts chain at their cancel point (SwordRules.nextCut); each holds your walking until then and lunges you in, stopping
-- short of a foe (SwordRules.lungeLength). The animations are in place: the lunge is the real movement.
-- Holds your sword still while a super's cinematic plays (spec 2026-11-05-super-moves-design)
function SwordController.Pause(on: boolean)
	paused = on
end

function SwordController.Attack()
	if paused then
		return
	end
	local character, root = ownParts()
	local sword = swordOf(if character then character:GetAttribute("Sword") else nil)
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
		playCues(sword, `cut{index}`, token)
		local effects = effectsOf(character)
		if effects then
			cutEffects(character, sword, effects, index, true, function(): boolean
				return stillSwinging(token)
			end)
		end
		-- The candy sparkle arc as the blade comes round, and the finisher's dust where it lands
		local arc = (SwordFx.ARCS :: any)[`cut{index}`] :: HitFx.ArcLook?
		if arc then
			task.delay(arc.from, function()
				local _, arcRoot = ownParts()
				if arcRoot and stillSwinging(token) then
					HitFx.swingArc(arcRoot.CFrame, arc, slashOf(character, sword))
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
		local hang = cut.hang
		if hang then
			task.delay(hang.from, function()
				if stillSwinging(token) then
					hangZoom(hang.to - hang.from)
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
	if paused then
		return
	end
	local character, root, humanoid = ownParts()
	local sword = swordOf(if character then character:GetAttribute("Sword") else nil)
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
	softAim(root)
	-- A held skill (Thornline: the blade in the ground until the vines reach the foe) keeps its pose that much longer
	local facingNow = root.CFrame.LookVector
	local travel = SwordRules.skillTravel(skill.shape, root.Position.X, root.Position.Z, facingNow.X, facingNow.Z, if combatTargets then combatTargets() else {})
	local held = if skill.hold then SwordRules.holdFor(skill.hitAt, travel, skill.hold.snap) else 0
	local token = SwingGate.startSkill(gate, os.clock(), skill.length + held)
	holdControls(humanoid, skill.length + held)
	local track = if mine then mine.play("skill") else nil
	if track then
		holdPose(track, skill.hold, held, function(): boolean
			return stillSwinging(token)
		end)
	end
	swingTrail()
	playCues(sword, "skill", token)
	local effects = effectsOf(character)
	if effects then
		-- Your own: a shake on the cleave and on the burst, and the look's camera moment (Sunfall Cleave)
		local aim = skillAim(character, sword)
		local shake = SwordSkillFxConfig.SHAKE
		SwordSkillFx.skill(character, effects.fx.skill, effects.colors, effects.scale, aim, {
			blade = bladeOf(character),
			released = function()
				ScreenFx.shake(shake.release)
			end,
			burst = function()
				ScreenFx.shake((shake :: any)[effects.fx.skill] or shake.impact)
				local spec = SwordSkillFxConfig.LOOKS[effects.fx.skill]
				if spec and spec.burstSound then
					SwordController.PlaySound(spec.burstSound)
				end
			end,
		})
		local look = SwordSkillFxConfig.LOOKS[effects.fx.skill]
		local beats = if look and look.cinematic then look.beats else nil
		if beats and aim then
			local travel = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z).Magnitude / math.max(beats.speed, 1)
			SkillCinematic.play(root, aim - Vector3.new(0, 3, 0), beats.release, travel, function(): boolean
				return stillSwinging(token)
			end)
		end
	end
	-- The dash slash's flat arc (a round 1 sword's skill draws its own effects instead)
	local arc = SwordFx.ARCS.skill :: HitFx.ArcLook
	if not effects then
		task.delay(arc.from, function()
			local _, arcRoot = ownParts()
			if arcRoot and stillSwinging(token) then
				HitFx.swingArc(arcRoot.CFrame, arc, slashOf(character, sword))
			end
		end)
	end
	local startX, startZ = root.Position.X, root.Position.Z
	-- Only the Steel Sword's skill moves you (its dash slash); the round 1 swords' skills are cast where you stand
	local dash = skill.dash
	if dash then
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
	end
	-- The server's rule (SwordRules.skillHits) on what you see here: the hit's sound and freeze when the skill reaches its
	-- first foe (a crescent's when it gets there)
	task.delay(skill.hitAt, function()
		local _, hitRoot = ownParts()
		if not hitRoot or not combatTargets or not stillSwinging(token) then
			return
		end
		local look = facing(hitRoot)
		local hits = SwordRules.skillHits(skill.shape, startX, startZ, hitRoot.Position.X, hitRoot.Position.Z, look.X, look.Z, combatTargets())
		if #hits == 0 then
			return
		end
		task.delay(hits[1].after, function()
			predictHit(function(): boolean
				return true
			end, "skill", false)
		end)
	end)
end

-- A dodge: untouchable for a moment (the server's), a dash the way you're moving (backward when still), after-images.
-- It cancels a swing: your walking comes back and the swing's lunge or dash stops.
function SwordController.Dodge()
	if paused then
		return
	end
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

-- The weapon glow's budget (Config/WeaponLooks BUDGET): your own sword and the nearest few others within range get the
-- full aura, every other sword the cheap creature-style glow, checked every few tenths of a second
local function auraBudget()
	local budget = WeaponLooks.BUDGET
	while true do
		task.wait(budget.every)
		local camera = workspace.CurrentCamera
		local from = if camera then camera.Focus.Position else Vector3.zero
		local candidates: { WeaponLookRules.Candidate } = {}
		local byKey: { [string]: View } = {}
		for character, view in views do
			if not view.model.Parent then
				continue
			end
			local key = tostring(#candidates + 1)
			byKey[key] = view
			table.insert(candidates, {
				key = key,
				distance = (view.handle.Position - from).Magnitude,
				mine = character == player.Character,
			})
		end
		local full = WeaponLookRules.fullAuras(candidates, budget.nearest, budget.range)
		for key, view in byKey do
			WeaponLook.setDetail(view.model, full[key] == true)
		end
	end
end

-- Another player's round 1 sword cut or skill starting at (x, z) (BattleService): its effects on their character, full
-- within range while only a few are, light (the slash only) past that, none far away (SwordSkillFxRules.drawsOthers)
local function onSwordCast(userId: unknown, move: unknown, x: unknown, z: unknown)
	if typeof(userId) ~= "number" or userId == player.UserId or typeof(move) ~= "string" or typeof(x) ~= "number" or typeof(z) ~= "number" then
		return
	end
	local other = Players:GetPlayerByUserId(userId)
	local character = if other then other.Character else nil
	local camera = workspace.CurrentCamera
	local sword = if character then swordOf(character:GetAttribute("Sword")) else nil
	local effects = if character then effectsOf(character) else nil
	if not character or not camera or not sword or not effects then
		return
	end
	local focus = camera.Focus.Position
	local mode = SwordSkillFxRules.drawsOthers(Vector2.new(x - focus.X, z - focus.Z).Magnitude, othersFull, SwordSkillFxConfig.OTHERS)
	local index = tonumber(string.match(move, "^cut(%d)$"))
	local cut = if index then sword.combo[index] else nil
	if mode == "none" or (move ~= "skill" and not cut) then
		return
	end
	if mode == "full" then
		othersFull += 1
		task.delay(if cut then cut.length else sword.skill.length, function()
			othersFull -= 1
		end)
	end
	if move == "skill" then
		if mode == "full" then
			SwordSkillFx.skill(character, effects.fx.skill, effects.colors, effects.scale, skillAim(character, sword), { blade = bladeOf(character) })
		end
	elseif index then
		cutEffects(character, sword, effects, index, mode == "full", function(): boolean
			return character.Parent ~= nil
		end)
	end
end

function SwordController.Start()
	Remotes.SwordCast.OnClientEvent:Connect(onSwordCast)
	Remotes.SwordState.OnClientEvent:Connect(function(state: any)
		if typeof(state) == "table" and state.popup == true and typeof(state.sword) == "string" and Swords.SWORDS[state.sword] then
			showPopup(state.sword)
		end
	end)
	Remotes.SwordState:FireServer()
	task.spawn(moveShiftLock)
	task.spawn(auraBudget)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
end

return SwordController
