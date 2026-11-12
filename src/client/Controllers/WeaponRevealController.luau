--!strict
-- A new weapon's big moment (spec 2026-11-06-weapons-round1-design 4.4): a boss dropped its weapon (WeaponDropped,
-- sent after the victory screen) and, from the Forge (ForgeResult), a weapon made, reforged or upgraded. On the pack
-- opening's stage (Util/OpeningStage): bars and a dim, a spinning rune circle (the Forge: an anvil on a glow that
-- builds up first), a light column in the rarity's colour, the weapon rising out of it spinning with its glow
-- (Util/WeaponLook), the banner, its grade, and a line under it. The Forge's hit is the pack pulls' by grade (S the
-- Legendary's, A the Epic's, B and C a small one); an upgrade names the glow layer it adds; a reforge that rolled
-- lower says it kept the grade. About 6 s; a tap closes it after 2 s. Others hear of an Epic or Legendary drop in a
-- toast (WeaponAnnouncement). Timing and sizes: Config/WeaponLooks REVEAL.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local LevelUpConfig = require(Config:WaitForChild("LevelUpFx"))
local PackOpening = require(Config:WaitForChild("PackOpening"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Town = require(Config:WaitForChild("Town"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local Weapons = require(Config:WaitForChild("Weapons"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local WeaponText = require(Shared:WaitForChild("Util"):WaitForChild("WeaponText"))
local WeaponLookRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponLookRules"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local OpeningStage = require(ClientUtil:WaitForChild("OpeningStage"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local WeaponFace = require(ClientUtil:WaitForChild("WeaponFace"))
local WeaponLook = require(ClientUtil:WaitForChild("WeaponLook"))
local UIController = require(Controllers:WaitForChild("UIController"))

local player = Players.LocalPlayer
local REVEAL = WeaponLooks.REVEAL
local WHITE = Color3.new(1, 1, 1)

-- forge: the Forge's anvil, build-up and sounds; banner and gradeText replace "<RARITY>! <Name>" and "Grade X"; hit:
-- Config/PackOpening sounds played together at the hit, flash its peak
export type Reveal = {
	weaponId: string,
	grade: string,
	level: number?,
	line: string?,
	forge: boolean?,
	banner: string?,
	gradeText: string?,
	card: boolean?, -- a new drop: its card flips over beside it
	hit: { string }?,
	flash: number?,
}

local WeaponRevealController = {}

local queue: { Reveal } = {}
local playing = false
local handedOver = false -- the boss chests left the stage shown for the next reveal (HandOver)

local function rarityColor(rarity: string): Color3
	local tier = (Rarities.Tiers :: any)[rarity]
	return if tier then tier.color else WHITE
end

-- The weapon's model for the stage: its saved model or the stand-in, with its look, anchored, its grip as its pivot
local function weaponModel(weaponId: string, grade: string, level: number): Model
	local weapon = Weapons.ById[weaponId]
	local folder = ReplicatedStorage:FindFirstChild("WeaponModels")
	local template = if folder and weapon and weapon.model then folder:FindFirstChild(weapon.model) else nil
	local model = if template and template:IsA("Model") then template:Clone() else WeaponLook.standIn(weaponId)
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			item:Destroy()
		end
	end
	WeaponLook.apply(model, weaponId, grade, level)
	WeaponLook.setPlace(model, weaponId, grade, level, "hand")
	local handle = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	assert(handle and handle:IsA("BasePart"), "a weapon model needs a part")
	-- Held by its Grip attachment, else the model's own pivot: an imported model's is the grip's centre, blade up,
	-- while its parts keep the FBX turn (with the part's frame the blade pointed at the camera inside the anvil)
	local pivot = model:GetPivot()
	local grip = handle:FindFirstChild("Grip")
	model.PrimaryPart = handle
	handle.PivotOffset = if grip and grip:IsA("Attachment") then grip.CFrame else handle.CFrame:ToObjectSpace(pivot)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	return model
end

-- How far a weapon reaches under and over its grip along the blade (its pivot's up), from every part's corners
local function alongBlade(model: Model): (number, number)
	local pivot = model:GetPivot()
	local low, high = math.huge, -math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local point = pivot:PointToObjectSpace(part.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z)))
						low, high = math.min(low, point.Y), math.max(high, point.Y)
					end
				end
			end
		end
	end
	return low, high
end

local function flatCircle(size: number, color: Color3, parent: Instance): (Part, Decal)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(size, 0.05, size)
	part.Parent = parent
	local face = Instance.new("Decal")
	face.Face = Enum.NormalId.Top
	face.Texture = LevelUpConfig.IMAGES.rune
	face.Color3 = color
	face.Transparency = 1
	face.Parent = part
	return part, face
end

local function lightBeam(a0: Attachment, a1: Attachment, color: Color3, parent: Instance): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = LevelUpConfig.IMAGES.beam
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Width0, beam.Width1 = 0, 0
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.6, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Parent = parent
	return beam
end

-- The banner, the grade and the line, over the stage
local function words(reveal: Reveal, color: Color3): (ScreenGui, TextButton, () -> (), () -> ())
	local weapon = Weapons.ById[reveal.weaponId] :: Weapons.Weapon
	local gui = Instance.new("ScreenGui")
	gui.Name = "WeaponReveal"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.Size = UDim2.fromScale(1, 1)
	skip.BackgroundTransparency = 1
	skip.Text = ""
	skip.AutoButtonColor = false
	skip.Parent = gui
	local banner = UIKit.label(gui, reveal.banner or `{string.upper(weapon.rarity)}! {weapon.name}`, Enum.Font.FredokaOne, 40, color)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.fromScale(0.5, 0.13)
	banner.Size = UDim2.new(0.9, 0, 0, 50)
	banner.TextXAlignment = Enum.TextXAlignment.Center
	banner.TextStrokeTransparency = 0.1
	banner.TextStrokeColor3 = Color3.fromRGB(40, 20, 50)
	banner.Visible = false
	local bannerScale = Instance.new("UIScale")
	bannerScale.Scale = 0.4
	bannerScale.Parent = banner
	local grade = UIKit.label(gui, reveal.gradeText or `Grade {reveal.grade}`, Enum.Font.FredokaOne, 26, WHITE)
	grade.AnchorPoint = Vector2.new(0.5, 0)
	grade.Position = UDim2.fromScale(0.5, 0.22)
	grade.Size = UDim2.new(0.4, 0, 0, 34)
	grade.TextXAlignment = Enum.TextXAlignment.Center
	grade.TextStrokeTransparency = 0.2
	grade.Visible = false
	local line = UIKit.label(gui, reveal.line or "", Enum.Font.GothamBold, 18, WHITE)
	line.AnchorPoint = Vector2.new(0.5, 1)
	line.Position = UDim2.fromScale(0.5, 0.86)
	line.Size = UDim2.new(0.9, 0, 0, 26)
	line.TextXAlignment = Enum.TextXAlignment.Center
	line.TextStrokeTransparency = 0.3
	line.Visible = false
	local function popBanner()
		banner.Visible = true
		grade.Visible = true
		TweenService:Create(bannerScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	local function showLine()
		line.Visible = reveal.line ~= nil
	end
	return gui, skip, popBanner, showLine
end

-- The Forge's pedestal: the Forge's anvil (Town.FORGE_LOOK sizes) on a glowing disc, its face at `top`; returns the
-- disc to pulse
local function anvil(top: Vector3, parent: Instance): Part
	local look = Town.FORGE_LOOK
	local at = CFrame.new(top - Vector3.new(0, look.ANVIL_FOOT[2] + look.ANVIL_WAIST[2] + look.ANVIL_FACE[2], 0))
	local steel = Color3.fromRGB(look.STEEL[1], look.STEEL[2], look.STEEL[3])
	local function block(size: { number }, y: number)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Size = Vector3.new(size[1], size[2], size[3])
		part.CFrame = at * CFrame.new(0, y + size[2] / 2, 0)
		part.Color = steel
		part.Material = Enum.Material.Metal
		part.Parent = parent
	end
	local foot, waist, face = look.ANVIL_FOOT, look.ANVIL_WAIST, look.ANVIL_FACE
	block(foot, 0)
	block(waist, foot[2])
	block(face, foot[2] + waist[2])
	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.Size = Vector3.new(0.1, REVEAL.forge.disc, REVEAL.forge.disc)
	disc.CFrame = at * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = Color3.fromRGB(look.EMBER[1], look.EMBER[2], look.EMBER[3])
	disc.Material = Enum.Material.Neon
	disc.Transparency = 0.9
	disc.Parent = parent
	return disc
end

-- A new drop's card beside the weapon (spec 4.4): it pops in face down once the weapon is up, then turns over to its
-- face and grade as the banner pops. Returns show and turn.
local function gradeCard(gui: ScreenGui, reveal: Reveal): (() -> (), () -> ())
	local spec = REVEAL.card
	local holder = Instance.new("Frame")
	holder.Name = "Card"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(spec.x, spec.y)
	holder.Size = UDim2.fromScale(spec.height * 0.7, spec.height)
	holder.SizeConstraint = Enum.SizeConstraint.RelativeYY -- both sides follow the screen's height: a card's shape
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	local grow = Instance.new("UIScale")
	grow.Scale = 0.6
	grow.Parent = holder
	-- The part that squashes to nothing and back as it turns over
	local turning = Instance.new("Frame")
	turning.AnchorPoint = Vector2.new(0.5, 0.5)
	turning.Position = UDim2.fromScale(0.5, 0.5)
	turning.Size = UDim2.fromScale(1, 1)
	turning.BackgroundTransparency = 1
	turning.Parent = holder
	local function side(name: string): (Frame, UIStroke)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundTransparency = 1
		frame.Parent = turning
		local stroke = Instance.new("UIStroke")
		stroke.Parent = frame
		return frame, stroke
	end
	local back, backStroke = side("Back")
	CardFace.renderBack(back, backStroke)
	local front, frontStroke = side("Front")
	front.Visible = false
	WeaponFace.render(front, frontStroke, reveal.weaponId, { grade = reveal.grade, level = reveal.level or 0 }, nil)
	local function show()
		holder.Visible = true
		TweenService:Create(grow, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	local function turn()
		local close = TweenService:Create(turning, TweenInfo.new(spec.flip / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromScale(0, 1) })
		close.Completed:Once(function()
			back.Visible = false
			front.Visible = true
			TweenService:Create(turning, TweenInfo.new(spec.flip / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) }):Play()
		end)
		close:Play()
	end
	return show, turn
end

local function play(reveal: Reveal)
	local weapon = Weapons.ById[reveal.weaponId]
	if not weapon then
		return
	end
	local color = rarityColor(weapon.rarity)
	OpeningStage.show()
	OpeningStage.bars(true, 0.4)
	OpeningStage.dim(REVEAL.dim, 0.5)
	local stage = Instance.new("Folder")
	stage.Name = "WeaponReveal"
	stage.Parent = OpeningStage.folder()
	local middle = OpeningStage.root().Position
	local circleAt = CFrame.new(middle - Vector3.new(0, REVEAL.circle.under, 0))
	local outer, outerFace = flatCircle(REVEAL.circle.size, color, stage)
	local inner, innerFace = flatCircle(REVEAL.circle.size * 0.78, color:Lerp(WHITE, 0.5), stage)
	-- The Forge's build-up: everything after it waits `delay`; the anvil's glow brightens meanwhile
	local delay = if reveal.forge then REVEAL.forge.buildUp else 0
	local disc = if reveal.forge then anvil(middle + Vector3.new(0, REVEAL.forge.anvilTop, 0), stage) else nil
	local hit = reveal.hit or {}
	local dropSounds = REVEAL.drop
	local forgeSounds = REVEAL.forge.sounds
	local a0 = Instance.new("Attachment")
	a0.Parent = outer
	local a1 = Instance.new("Attachment")
	a1.Parent = outer
	local glow = lightBeam(a0, a1, color, stage)
	local core = lightBeam(a0, a1, WHITE, stage)
	local model = weaponModel(weapon.id, reveal.grade, reveal.level or 0)
	-- Fitted to the stage: REVEAL.length studs along its blade (its pivot's up: the grip, blade up)
	local low, high = alongBlade(model)
	local fit = REVEAL.length / math.max(high - low, 0.1)
	model:ScaleTo(model:GetScale() * fit)
	local below = low * fit -- its lowest point, under the grip
	model.Parent = stage
	local gui, skip, popBanner, showLine = words(reveal, color)
	local showCard: (() -> ())?, turnCard: (() -> ())? = nil, nil
	if reveal.card then
		showCard, turnCard = gradeCard(gui, reveal)
	end
	local cardShown, cardTurned = false, false
	if reveal.forge then
		-- The forge flares up, then hammer strikes, each a little higher, until the hit
		OpeningStage.play(forgeSounds.fire)
		for index, at in REVEAL.forge.strikes do
			task.delay(at, function()
				if stage.Parent then
					OpeningStage.play(forgeSounds.strike, 1 + REVEAL.forge.strikeRise * (index - 1))
				end
			end)
		end
	else
		-- A drop: the column's rise now, the weapon's arrival when it flashes into view
		OpeningStage.play(dropSounds.rise)
	end
	local beamAt, riseAt = REVEAL.beamAt + delay, REVEAL.riseAt + delay
	local bannerAt, lineAt, seconds = REVEAL.bannerAt + delay, REVEAL.lineAt + delay, REVEAL.seconds + delay
	local struck = not reveal.forge

	local started = os.clock()
	local done = false
	local flashed, popped, lined, ringFaded = false, false, false, false
	local connection: RBXScriptConnection
	local function finish()
		if done then
			return
		end
		done = true
		connection:Disconnect()
		stage:Destroy()
		gui:Destroy()
		OpeningStage.hide()
	end
	skip.Activated:Connect(function()
		if os.clock() - started >= REVEAL.skipAfter then
			finish()
		end
	end)
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= seconds then
			finish()
			return
		end
		-- The Forge: the anvil's glow brightens through the build-up, then the hit lands
		if disc then
			disc.Transparency = 0.9 - 0.75 * math.clamp(t / delay, 0, 1)
		end
		if not struck and t >= delay then
			struck = true
			OpeningStage.fade(forgeSounds.fire, PackOpening.TEASE_FADE_SECONDS)
			for _, name in hit do
				OpeningStage.play(name)
			end
			OpeningStage.flash(reveal.flash or 0.7, 0.5)
			OpeningStage.shake(0.04 + 0.06 * (reveal.flash or 0.7), 0.35)
		end
		-- The circle fades in and turns; the column shoots up at beamAt
		local shown = if reveal.forge then 0 else math.min(1, t / 0.3)
		outerFace.Transparency = 1 - 0.95 * shown
		innerFace.Transparency = 1 - 0.8 * shown
		outer.CFrame = circleAt * CFrame.Angles(0, t * REVEAL.circle.spin * math.pi * 2, 0)
		inner.CFrame = (circleAt + Vector3.new(0, 0.01, 0)) * CFrame.Angles(0, -t * REVEAL.circle.spin * math.pi * 2.8, 0)
		local open = if t < beamAt then 0 else math.min(1, (t - beamAt) / 0.2)
		a1.Position = Vector3.new(0, REVEAL.beam.height * open, 0)
		-- Once the weapon is up the column thins, so the blade shows in front of it
		local up = riseAt + REVEAL.riseSeconds
		local thin = 1 - (1 - REVEAL.beam.after) * math.clamp((t - up) / 0.5, 0, 1)
		open *= thin
		glow.Width0, glow.Width1 = REVEAL.beam.width * open, REVEAL.beam.width * open * 0.8
		core.Width0, core.Width1 = REVEAL.beam.core * open, REVEAL.beam.core * open * 0.6
		-- The weapon rises out of the circle (easing out with a little overshoot), spinning and bobbing
		local rise = math.clamp((t - riseAt) / REVEAL.riseSeconds, 0, 1)
		local eased = 1 - (1 - rise) ^ 3
		local y = REVEAL.riseFrom + (REVEAL.lift - REVEAL.riseFrom) * eased - below
		y += math.sin(t / REVEAL.bob.seconds * math.pi * 2) * REVEAL.bob.studs * rise
		local spin = math.rad(t * REVEAL.spin)
		model:PivotTo(CFrame.new(middle + Vector3.new(0, y, 0)) * CFrame.Angles(0, spin, 0) * CFrame.Angles(math.rad(-REVEAL.tilt), 0, 0))
		if not flashed and not reveal.forge and t >= riseAt + REVEAL.riseSeconds * 0.6 then
			flashed = true
			OpeningStage.flash(0.7, 0.5)
			OpeningStage.shake(0.06, 0.35)
			for _, name in dropSounds.arrive[weapon.rarity] or dropSounds.arrive.Rare do
				OpeningStage.play(name)
			end
			OpeningStage.play(dropSounds.ring)
		end
		if flashed and not ringFaded and t >= seconds - dropSounds.ringFade then
			ringFaded = true
			OpeningStage.fade(dropSounds.ring, dropSounds.ringFade)
		end
		if showCard and not cardShown and t >= up then
			cardShown = true
			showCard()
		end
		if turnCard and not cardTurned and t >= up + REVEAL.card.turnAfter then
			cardTurned = true
			turnCard()
			OpeningStage.play(dropSounds.card)
		end
		if not popped and t >= bannerAt then
			popped = true
			popBanner()
			if reveal.forge then
				OpeningStage.play(forgeSounds.ring)
			end
		end
		if not lined and t >= lineAt then
			lined = true
			showLine()
		end
	end)
	while not done do
		task.wait(0.1)
	end
end

-- Plays reveals one after another, each when the stage is free (not mid pack opening)
local function drain()
	if playing then
		return
	end
	playing = true
	while #queue > 0 do
		while OpeningStage.isShown() and not handedOver do
			task.wait(0.25)
		end
		handedOver = false
		local reveal = table.remove(queue, 1) :: Reveal
		local ok, err = pcall(play, reveal)
		if not ok then
			warn(`[WeaponRevealController] {reveal.weaponId}: {err}`)
			OpeningStage.hide()
		end
	end
	playing = false
end

-- The boss chests (BossChestController) give the stage, still shown, to the waiting reveal: it starts on it at once
function WeaponRevealController.HandOver()
	handedOver = true
end

-- Whether a reveal is playing or waiting (the Forge window steps aside meanwhile)
function WeaponRevealController.IsPlaying(): boolean
	return playing or #queue > 0
end

function WeaponRevealController.Show(reveal: Reveal)
	if not Weapons.ById[reveal.weaponId] then
		return
	end
	table.insert(queue, reveal)
	task.spawn(drain)
end

-- A boss's drop: a new weapon, or the material one you had turned into
function WeaponRevealController.Drop(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.weaponId) ~= "string" or typeof(payload.grade) ~= "string" then
		return
	end
	local refund = tonumber(payload.refund) or 0
	local material = if typeof(payload.material) == "string" then Items.ITEMS[payload.material] else nil
	local line = if refund > 0 then `Already yours: +{refund} {if material then material.name else "material"}`
		else "New weapon! Equip it in the Armory."
	WeaponRevealController.Show({
		weaponId = payload.weaponId,
		grade = payload.grade,
		level = 0,
		line = line,
		gradeText = if refund > 0 then "Already yours" else nil, -- the rolled grade isn't kept
		card = refund <= 0, -- a new weapon's card turns over beside it
	})
end

-- The Forge's result (ForgeResult): forged, reforged (a higher grade, or the one it kept) or upgraded
function WeaponRevealController.Forge(result: any)
	if typeof(result) ~= "table" or typeof(result.weaponId) ~= "string" or typeof(result.grade) ~= "string" then
		return
	end
	local weapon = Weapons.ById[result.weaponId]
	if not weapon then
		return
	end
	local level = tonumber(result.level) or 0
	local owned = if typeof(result.owned) == "string" then result.owned else result.grade
	local forge = REVEAL.forge
	local reveal: Reveal = {
		weaponId = weapon.id,
		grade = owned,
		level = level,
		forge = true,
		hit = forge.hit[result.grade],
		flash = forge.flash[result.grade],
	}
	if result.action == "upgrade" then
		reveal.banner = `+{level} {weapon.name}`
		reveal.gradeText = WeaponText.ladderStep(WeaponLooks, level, weapon.rarity)
		reveal.hit = if level >= WeaponLooks.LADDER.awakenedAt then forge.hit.S else forge.hit.B
		reveal.flash = if level >= WeaponLooks.LADDER.awakenedAt then forge.flash.S else forge.flash.A
	elseif result.action == "reforge" and result.kept == true then
		reveal.banner = `Rolled Grade {result.grade}`
		reveal.gradeText = `Kept your Grade {owned}`
		reveal.hit = forge.hit.C
		reveal.flash = forge.flash.C
	elseif result.action == "reforge" then
		reveal.banner = `NEW GRADE {result.grade}!`
		reveal.line = `Your {weapon.name} is Grade {result.grade} now.`
	else
		reveal.line = "Forged! Equip it in the Armory."
	end
	WeaponRevealController.Show(reveal)
end

-- A new boss weapon dropped near you (someone else's win, spec 4.4): a column of light in its rarity's colour rises
-- where they stand, swells, then fades
local function beacon(userId: unknown, weaponId: unknown, position: unknown)
	local weapon = if typeof(weaponId) == "string" then Weapons.ById[weaponId] else nil
	local camera = workspace.CurrentCamera
	if not weapon or typeof(position) ~= "Vector3" or not camera then
		return
	end
	local spec = WeaponLooks.BEACON
	local distance = (camera.Focus.Position - position).Magnitude
	if not WeaponLookRules.seesBeacon(distance, spec.range, userId == player.UserId) then
		return
	end
	local color = rarityColor(weapon.rarity)
	local anchor = Instance.new("Part")
	anchor.Name = "WeaponBeacon"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position - Vector3.new(0, 3, 0))
	anchor.Parent = workspace
	local a0 = Instance.new("Attachment")
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0.1, 0)
	a1.Parent = anchor
	local glow = lightBeam(a0, a1, color, anchor)
	local core = lightBeam(a0, a1, WHITE, anchor)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 0
	light.Parent = anchor
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= spec.seconds or not anchor.Parent then
			connection:Disconnect()
			anchor:Destroy()
			return
		end
		local rise = math.clamp(t / spec.fadeIn, 0, 1)
		local fade = math.clamp((spec.seconds - t) / spec.fadeOut, 0, 1)
		local open = math.min(rise, fade)
		local width = spec.width * (1 + (spec.swell - 1) * math.clamp(t / spec.seconds, 0, 1)) * open
		a1.Position = Vector3.new(0, spec.height * rise, 0)
		glow.Width0, glow.Width1 = width, width * 0.7
		core.Width0, core.Width1 = width * 0.3, width * 0.2
		light.Brightness = 2 * open
	end)
end

function WeaponRevealController.Start()
	-- The stage's sounds fetched in the background, so a first drop or forge doesn't start them late (as Sound
	-- instances: an id given as a string fetches nothing)
	task.spawn(function()
		local sounds = {}
		for _, id in OpeningStage.soundIds() do
			local sound = Instance.new("Sound")
			sound.SoundId = id
			table.insert(sounds, sound)
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, sounds)
	end)
	Remotes.WeaponDropped.OnClientEvent:Connect(WeaponRevealController.Drop)
	Remotes.ForgeResult.OnClientEvent:Connect(function(result: any)
		if typeof(result) == "table" and result.finished ~= true then
			WeaponRevealController.Forge(result)
		end -- a finished Forge job: ForgeController plays it when the Forge is open
	end)
	Remotes.WeaponBeacon.OnClientEvent:Connect(beacon)
	Remotes.WeaponAnnouncement.OnClientEvent:Connect(function(name: unknown, weaponId: unknown, grade: unknown, userId: unknown)
		if userId == player.UserId or typeof(name) ~= "string" or typeof(weaponId) ~= "string" then
			return
		end
		local weapon = Weapons.ById[weaponId]
		if weapon then
			UIController.Notify(`{name} got the {weapon.rarity} {weapon.name}{if typeof(grade) == "string" then ` (Grade {grade})` else ""}!`, false)
		end
	end)
end

return WeaponRevealController
