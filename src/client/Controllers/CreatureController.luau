--!strict
-- Draws every summoned creature on this client. The server only moves an invisible marker part in
-- workspace.Creatures; here each marker gets a model (ReplicatedStorage.CreatureModels, or a placeholder
-- blob), smooth following, a motion kit (breathing, hop-and-waddle, hover for flyers) or the model's own
-- Idle/Walk animations, a rarity glow and a name tag. Everything is local: nothing here replicates.
-- Only your own creatures and the nearest others get a model (Util/CreatureCull, Party.CULL): the rest wait as
-- markers until they come near, so a full server doesn't animate every pet.
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Party = require(Config:WaitForChild("Party"))
local Chikin = require(Config:WaitForChild("Chikin"))
local TutorialRules = require(Shared:WaitForChild("Util"):WaitForChild("TutorialRules"))
local AttackFx = require(Config:WaitForChild("AttackFx"))
local FightMotion = require(Shared:WaitForChild("Util"):WaitForChild("FightMotion"))
local Rarities = require(Config:WaitForChild("Rarities"))
local CreatureCull = require(Shared:WaitForChild("Util"):WaitForChild("CreatureCull"))
local CreatureVisuals = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("CreatureVisuals"))
local SummonFx = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("SummonFx"))
local SummonMotion = require(Shared:WaitForChild("Util"):WaitForChild("SummonMotion"))
local PetVoice = require(Shared:WaitForChild("Util"):WaitForChild("PetVoice"))
local HealFx = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("HealFx"))
local RestTimers = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("RestTimers"))
local SoundBank = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("SoundBank"))

local CreatureController = {}

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

type Creature = {
	marker: BasePart,
	body: CreatureVisuals.Body,
	clock: FightMotion.Clock, -- its moving about in a fight
	yaw: number, -- its turn off its marker's look in a fight (it faces its path while it circles)
	seed: number,
	chargingUntil: number, -- os.clock: holds still to charge an attack until then
	frozenUntil: number, -- os.clock: frozen solid (the Frost Tyrant's spikes) until then: no moving, no animation
	dash: { start: number, seconds: number, toward: Vector3, share: number }?, -- an attack's dash in and back
	blink: { at: Vector3, face: Vector3 }?, -- Rift Step: standing at a rift (world), facing the boss, until cleared
	element: string,
	foil: boolean,
	rarity: string,
	outline: boolean,
	highlight: Highlight?,
	light: PointLight?,
	tag: TextLabel,
	hpBar: BillboardGui?, -- in an arena fight: a bar everyone can see
	hpFill: Frame?,
	height: number,
	connections: { RBXScriptConnection },
	voice: string?, -- your own creature's chirp (Util/PetVoice); nil on everyone else's
	voiceVolume: number, -- how loud it chirps (PetVoice.volume: the big rarities' huff quieter)
	nextChirp: number, -- os.clock of its next chirp
	chirpStart: number?, -- os.clock its chirp's little bounce began
	healStop: (() -> ())?, -- stops its spring healing effect (Util/HealFx)
}

local creatures: { [BasePart]: Creature } = {} -- the drawn ones
local known: { [BasePart]: string } = {} -- every creature marker, with its cull key
local nextKey = 0

local function rarityColor(rarity: string): Color3
	local tier = Rarities.Tiers[rarity]
	return if tier then tier.color else Color3.new(1, 1, 1)
end

local function rarityOrder(rarity: string): number
	local tier = Rarities.Tiers[rarity]
	return if tier then tier.order else 0
end

-- A round blob in its element colour with eyes (and wings for flyers): used until a model is imported
local function makePlaceholder(color: Color3, flying: boolean): Model
	local model = Instance.new("Model")
	local function part(name: string, shape: Enum.PartType, size: Vector3, position: Vector3, partColor: Color3)
		CreatureVisuals.addPart(model, name, shape, size, CFrame.new(position), partColor)
	end
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.35)
	part("Body", Enum.PartType.Ball, Vector3.new(2.2, 2.2, 2.2), Vector3.new(0, 1.1, 0), color)
	part("Belly", Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 0.95, -0.5), color:Lerp(Color3.new(1, 1, 1), 0.45))
	for _, side in { -1, 1 } do
		part("Eye", Enum.PartType.Ball, Vector3.new(0.38, 0.38, 0.38), Vector3.new(0.4 * side, 1.45, -0.95), Color3.new(0.08, 0.08, 0.1))
		part("Shine", Enum.PartType.Ball, Vector3.new(0.12, 0.12, 0.12), Vector3.new(0.4 * side + 0.07, 1.53, -1.1), Color3.new(1, 1, 1))
		part("Ear", Enum.PartType.Block, Vector3.new(0.4, 0.6, 0.3), Vector3.new(0.6 * side, 2.2, 0), dark)
		if flying then
			part("Wing", Enum.PartType.Block, Vector3.new(1.3, 0.12, 0.8), Vector3.new(1.5 * side, 1.4, 0.2), dark)
		end
	end
	model.WorldPivot = CFrame.new(0, 0, 0) -- facing -Z, like every Roblox model should
	return model
end

local function addGlow(creature: Creature, element: string, grade: string, stars: number)
	local glow = Party.GLOW[creature.rarity] or Party.GLOW.Common
	local color = Cards.ELEMENTS[element] or Color3.new(1, 1, 1)
	local _, size = creature.body.model:GetBoundingBox()

	if glow.light > 0 then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = glow.light
		light.Range = glow.lightRange
		light.Parent = creature.body.root
		creature.light = light
	end

	local sparkles = glow.sparkles + stars * Party.SPARKLES_PER_STAR + (if grade == "S" then Party.GRADE_S_SPARKLES else 0)
	if sparkles > 0 then
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(0, size.Y / 2, 0)
		attachment.Parent = creature.body.root
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = SPARKLE_TEXTURE
		emitter.Rate = sparkles
		emitter.Lifetime = NumberRange.new(1, 1.6)
		emitter.Speed = NumberRange.new(0.4, 1)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0) })
		emitter.LightEmission = 1
		emitter.Color = if creature.foil
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.6, 1)),
				ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 0.6, 1)),
				ColorSequenceKeypoint.new(0.66, Color3.fromHSV(0.66, 0.6, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(0.9, 0.6, 1)),
			})
			else ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4))
		emitter.Parent = attachment
	end

	creature.outline = glow.outline or creature.foil
	if creature.outline then
		local highlight = Instance.new("Highlight")
		highlight.Adornee = creature.body.model
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillTransparency = 1
		highlight.OutlineColor = color
		highlight.Enabled = false -- the outline budget turns it on (updateOutlines)
		highlight.Parent = creature.body.model
		creature.highlight = highlight
	end
end

-- Your own creature's tag hides on your screen while a tour leads (the owner 2026-11-11: "hide the title and creature
-- tag only on tutorial"): it sat right over Pish and Chikin
local function tagShown(marker: BasePart): boolean
	local me = Players.LocalPlayer
	if marker:GetAttribute("OwnerUserId") ~= me.UserId then
		return true
	end
	local pish, combat = me:GetAttribute("TutorialStep"), me:GetAttribute("CombatStep")
	return not TutorialRules.tourLeading(if typeof(pish) == "string" then pish else "", if typeof(combat) == "string" then combat else "", Chikin.WAIT_STEP)
end

local function updateTag(creature: Creature)
	local marker = creature.marker
	local board = creature.tag.Parent
	if board and board:IsA("BillboardGui") then
		board.Enabled = tagShown(marker)
	end
	local card = Cards.ById[marker:GetAttribute("CardId") :: string]
	local level = marker:GetAttribute("Level")
	local stars = marker:GetAttribute("Stars")
	local owner = Players:GetPlayerByUserId(marker:GetAttribute("OwnerUserId") :: number)
	local name = if card then card.name else "Creature"
	local starText = if typeof(stars) == "number" and stars > 0 then " · " .. string.rep("⭐", stars) else ""
	local ownerText = if owner then `{owner.DisplayName}'s ` else ""
	creature.tag.Text = `{ownerText}{name}\nLv {if typeof(level) == "number" then level else 1}{starText}`
end

local HP_HIGH = Color3.fromRGB(90, 210, 110)
local HP_LOW = Color3.fromRGB(220, 70, 60)

-- Arena fights put Hp / MaxHp attributes on fighting markers: show a small bar over the creature
local function updateHpBar(creature: Creature)
	local hp = creature.marker:GetAttribute("Hp")
	local maxHp = creature.marker:GetAttribute("MaxHp")
	if typeof(hp) ~= "number" or typeof(maxHp) ~= "number" or maxHp <= 0 then
		if creature.hpBar then
			creature.hpBar.Enabled = false
		end
		return
	end
	if not creature.hpBar then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(80, 10)
		gui.StudsOffset = Vector3.new(0, creature.height + 2.6, 0)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		local track = Instance.new("Frame")
		track.Size = UDim2.fromScale(1, 1)
		track.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		track.BorderSizePixel = 0
		track.Parent = gui
		local fill = Instance.new("Frame")
		fill.BorderSizePixel = 0
		fill.Parent = track
		gui.Parent = creature.body.root
		creature.hpBar, creature.hpFill = gui, fill
	end
	local share = math.clamp(hp / maxHp, 0, 1)
	local fill = creature.hpFill :: Frame
	fill.Size = UDim2.fromScale(share, 1)
	fill.BackgroundColor3 = HP_LOW:Lerp(HP_HIGH, share)
	;(creature.hpBar :: BillboardGui).Enabled = true
end

local function remove(marker: BasePart)
	local creature = creatures[marker]
	if not creature then
		return
	end
	creatures[marker] = nil
	for _, connection in creature.connections do
		connection:Disconnect()
	end
	if creature.healStop then
		creature.healStop()
	end
	creature.body.model:Destroy()
end

-- Your own creature's state for PetVoice.isFree (out and about: it chirps, and heals at the spring)
local function freeState(creature: Creature): PetVoice.State
	local marker = creature.marker
	return {
		mine = creature.voice ~= nil,
		inFight = marker:GetAttribute("InFight") == true,
		fainted = marker:GetAttribute("Fainted") == true,
		benched = marker:GetAttribute("Benched") == true,
		leaving = marker:GetAttribute("Unsummon") == true,
	}
end

-- A chirp (owner 2026-11-04): its own voice, pitched for its size, from where it stands, and a little bounce
local function chirp(creature: Creature, now: number)
	local cfg = Party.VOICE
	local sound = SoundBank.make(creature.voice :: string)
	sound.Volume = creature.voiceVolume
	sound.PlaybackSpeed = PetVoice.pitch(creature.height, Party.CREATURE_HEIGHT, math.random(), cfg)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = cfg.range
	sound.Parent = creature.body.root
	sound:Play()
	Debris:AddItem(sound, 4)
	if creature.body.grow == nil then
		creature.chirpStart = now -- not while it's popping in or shrinking away (Util/SummonFx owns its size then)
	end
end

-- Every frame for your own creature: the next chirp when it's due, and the bounce of the last one
local function voiceStep(creature: Creature, now: number)
	local cfg = Party.VOICE
	if now >= creature.nextChirp then
		creature.nextChirp = now + PetVoice.nextChirp(math.random(), cfg)
		if PetVoice.isFree(freeState(creature)) then
			chirp(creature, now)
		end
	end
	local started = creature.chirpStart
	if not started then
		return
	end
	if creature.marker:GetAttribute("Unsummon") == true or creature.marker:GetAttribute("Fainted") == true then
		creature.chirpStart = nil -- Util/SummonFx owns its size now
		return
	end
	local t = now - started
	if t < cfg.bounceSeconds then
		creature.body.grow = PetVoice.bounce(t, cfg.bounceSeconds, cfg)
	elseif creature.body.grow ~= 1 then
		creature.body.grow = 1 -- one frame at exactly full size before letting go
	else
		creature.body.grow = nil
		creature.chirpStart = nil
	end
end

-- Your creature at the healing spring (owner 2026-11-04): the heal effect while you stand there (RestTimers.IsNearSpring,
-- from the server) and it's out and about
local function updateHealing(creature: Creature)
	local want = creature.voice ~= nil and RestTimers.IsNearSpring() and PetVoice.isFree(freeState(creature))
	if want and not creature.healStop then
		creature.healStop = HealFx.start(creature.body, creature.height)
	elseif not want and creature.healStop then
		creature.healStop()
		creature.healStop = nil
	end
end

local function add(marker: BasePart)
	if creatures[marker] or not marker:GetAttribute("CardId") or marker:GetAttribute("Unsummon") == true then
		return -- one already leaving isn't drawn again
	end
	local card = Cards.ById[marker:GetAttribute("CardId") :: string]
	if not card then
		return
	end
	local flying = CreatureVisuals.isFlying(card.name)
	local template = CreatureVisuals.cardTemplate(card.name)
	local model = if template then template:Clone() else makePlaceholder(Cards.ELEMENTS[card.element], flying)
	CreatureVisuals.strip(model)
	model.Name = `{card.name}_{marker:GetAttribute("OwnerUserId")}`
	if template then
		CreatureVisuals.dress(model, card.name)
	end

	local height = CreatureVisuals.cardHeight(card.name, card.rarity)
	local body = CreatureVisuals.build(model, marker, height, flying, if template then template.Name else nil)
	body.fxColor = Cards.ELEMENTS[card.element] or body.fxColor
	-- The element aura: more than all of it on grade S Legendaries (Divine), all of it on other Legendaries, a lighter
	-- touch on grade S and A copies of the rest
	local grade = marker:GetAttribute("Grade")
	local tier = if card.rarity == "Legendary" then (if grade == "S" then "Divine" else "Legendary")
		elseif grade == "S" or grade == "A" then grade
		else nil
	if tier then
		CreatureVisuals.addBeastFx(body, card.element, tier :: string)
	end
	local tagColor = rarityColor(card.rarity):Lerp(Color3.new(1, 1, 1), 0.35)
	local creature: Creature = {
		marker = marker,
		body = body,
		clock = FightMotion.newClock(),
		yaw = 0,
		seed = (tonumber(marker:GetAttribute("OwnerUserId")) or 0) % 1000 + #card.name,
		chargingUntil = 0,
		frozenUntil = 0,
		dash = nil,
		blink = nil,
		element = card.element,
		foil = marker:GetAttribute("Foil") == true,
		rarity = card.rarity,
		outline = false,
		highlight = nil,
		light = nil,
		tag = CreatureVisuals.makeTag(body.root, height + (if flying then Party.MOTION.HOVER_HEIGHT else 0), tagColor),
		hpBar = nil,
		hpFill = nil,
		height = height + (if flying then Party.MOTION.HOVER_HEIGHT else 0),
		connections = {},
		voice = if marker:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
			then PetVoice.voice(card.rarity, (tonumber(marker:GetAttribute("OwnerUserId")) or 0) % 1000 + #card.name, Party.VOICE)
			else nil,
		voiceVolume = PetVoice.volume(card.rarity, Party.VOICE),
		nextChirp = os.clock() + PetVoice.nextChirp(math.random(), Party.VOICE),
		chirpStart = nil,
		healStop = nil,
	}
	local grade = marker:GetAttribute("Grade")
	local stars = marker:GetAttribute("Stars")
	addGlow(creature, card.element, if typeof(grade) == "string" then grade else "C", if typeof(stars) == "number" then stars else 0)
	updateTag(creature)
	updateHpBar(creature)
	table.insert(creature.connections, marker.AttributeChanged:Connect(function()
		updateTag(creature)
		updateHpBar(creature)
		updateHealing(creature)
	end))
	creatures[marker] = creature
	-- Appearing, leaving and fainting (Util/SummonFx): a fresh summon pops in (not one streaming in later), an unsummon
	-- shrinks back into its owner, a faint spins stars then fades (one already fainted when it came into view is just
	-- gone) and comes back when it isn't any more
	local color = Cards.ELEMENTS[card.element] or Color3.new(1, 1, 1)
	local summonedAt = marker:GetAttribute("SummonedAt")
	if SummonMotion.fresh(if typeof(summonedAt) == "number" then summonedAt else nil, workspace:GetServerTimeNow(), Party.SUMMON_FX.window) then
		SummonFx.summon(body, color)
		creature.nextChirp = os.clock() + Party.VOICE.hello -- your creature says hello as it lands
	end
	if marker:GetAttribute("Fainted") == true then
		SummonFx.faint(body, true)
	end
	table.insert(creature.connections, marker:GetAttributeChangedSignal("Unsummon"):Connect(function()
		local owner = Players:GetPlayerByUserId(tonumber(marker:GetAttribute("OwnerUserId")) or 0)
		SummonFx.unsummon(body, color, if owner then owner.Character else nil)
	end))
	table.insert(creature.connections, marker:GetAttributeChangedSignal("Fainted"):Connect(function()
		if marker:GetAttribute("Fainted") == true then
			SummonFx.faint(body)
		else
			SummonFx.revive(body)
		end
	end))
	-- A customer petting it (CustomerService sets PetMe): a happy wag
	table.insert(creature.connections, marker:GetAttributeChangedSignal("PetMe"):Connect(function()
		if marker:GetAttribute("InFight") ~= true and marker:GetAttribute("Fainted") ~= true then
			CreatureVisuals.pose(body, "wag", os.clock())
		end
	end))
	if marker:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId and Players.LocalPlayer:GetAttribute("CreatureReady") ~= true then
		-- Your own creature, the first time: the loading screen waits until its model has downloaded
		task.spawn(function()
			pcall(ContentProvider.PreloadAsync, ContentProvider, { model })
			Players.LocalPlayer:SetAttribute("CreatureReady", true)
		end)
	end
	updateHealing(creature)
end

-- Roblox draws at most 31 outlines: give them to the rarest creatures, nearest first
local function updateOutlines()
	local camera = workspace.CurrentCamera
	local origin = if camera then camera.CFrame.Position else Vector3.zero
	local wanting: { Creature } = {}
	for _, creature in creatures do
		if creature.highlight then
			table.insert(wanting, creature)
		end
	end
	table.sort(wanting, function(a, b)
		if rarityOrder(a.rarity) ~= rarityOrder(b.rarity) then
			return rarityOrder(a.rarity) > rarityOrder(b.rarity)
		end
		return (a.body.cframe.Position - origin).Magnitude < (b.body.cframe.Position - origin).Magnitude
	end)
	for index, creature in wanting do
		(creature.highlight :: Highlight).Enabled = index <= Party.MAX_OUTLINES
	end
end

-- Draw the creatures the cull picks, drop the rest
local function refreshCull()
	local camera = workspace.CurrentCamera
	local origin = if camera then camera.CFrame.Position else Vector3.zero
	local me = Players.LocalPlayer.UserId
	local entries: { CreatureCull.Entry } = {}
	local byKey: { [string]: BasePart } = {}
	for marker, key in known do
		byKey[key] = marker
		if marker:GetAttribute("Benched") == true then
			continue -- swapped out of a boss fight: hidden until it comes back in
		end
		table.insert(entries, {
			key = key,
			distance = (marker.Position - origin).Magnitude,
			own = marker:GetAttribute("OwnerUserId") == me,
			drawn = creatures[marker] ~= nil,
		})
	end
	local drawn = CreatureCull.pick(entries, Party.CULL)
	for marker in creatures do
		if not drawn[known[marker] or ""] then
			remove(marker)
		end
	end
	for key in drawn do
		add(byKey[key])
	end
end

local function step(creature: Creature, dt: number, now: number, origin: Vector3)
	-- Frozen solid: it stays exactly as it was, mid-step (the owner 2026-11-10: "still moves around while frozen")
	if now < creature.frozenUntil then
		return
	end
	-- Rift Step: it stands at a rift, facing the boss, until it blinks home (in a fight, or a Studio preview of it)
	local blink = creature.blink
	if blink then
		local spot = creature.marker.CFrame:PointToObjectSpace(blink.at)
		local face = creature.marker.CFrame:VectorToObjectSpace(blink.face - blink.at)
		creature.yaw = if Vector3.new(face.X, 0, face.Z).Magnitude > 1e-3 then math.atan2(-face.X, -face.Z) else creature.yaw
		creature.body.offset = CFrame.new(spot.X, 0, spot.Z) * CFrame.Angles(0, creature.yaw, 0)
	-- In a fight it circles its spot (the same path on every client) and stops to charge
	elseif creature.marker:GetAttribute("InFight") == true then
		local charging = now < creature.chargingUntil
		local t = FightMotion.advance(creature.clock, now, charging)
		local scale = creature.height / Party.CREATURE_HEIGHT
		local x, z = FightMotion.offset(creature.seed, t, AttackFx.ORBIT)
		local offset = Vector3.new(x * scale, 0, z * scale)
		-- An attack's dash: out toward its target and back, the circling fading out meanwhile
		local dash = creature.dash
		if dash then
			local p = (now - dash.start) / dash.seconds
			if p >= 1 then
				creature.dash = nil
			else
				local out = math.sin(math.clamp(p, 0, 1) * math.pi)
				local toward = dash.toward - creature.marker.Position
				local local3 = creature.marker.CFrame:VectorToObjectSpace(Vector3.new(toward.X, 0, toward.Z) * dash.share)
				offset = offset * (1 - out) + local3 * out
			end
		end
		-- It faces the way it goes while it circles, and turns back to the foe to charge or dash (owner 2026-11-05:
		-- "Thunderhorn is walking sideways")
		local want = if charging or creature.dash then 0 else FightMotion.heading(creature.seed, t, AttackFx.ORBIT)
		creature.yaw = FightMotion.turn(creature.yaw, want, dt, AttackFx.ORBIT.turn)
		creature.body.offset = CFrame.new(offset) * CFrame.Angles(0, creature.yaw, 0)
	else
		creature.yaw = 0
		creature.body.offset = nil
	end
	if creature.voice then
		voiceStep(creature, now)
	end
	CreatureVisuals.step(creature.body, dt, now, origin, Party.MOTION)
	if creature.highlight and creature.highlight.Enabled then
		if creature.foil then
			creature.highlight.OutlineColor = Color3.fromHSV((now * 0.25) % 1, 0.65, 1)
		end
		if (Party.GLOW[creature.rarity] or Party.GLOW.Common).pulse then
			creature.highlight.OutlineTransparency = 0.35 + 0.35 * math.sin(now * 3)
		end
	end
end

-- What the fight effects need of the creature drawn on this marker (nil if none is drawn)
-- grade: its card copy's (its attacks grow with it, AttackFx.GRADE); mine: it's the local player's
function CreatureController.GetFightView(marker: BasePart): { root: BasePart, element: string, height: number, grade: string?, mine: boolean }?
	local creature = creatures[marker]
	if not creature then
		return nil
	end
	local grade = marker:GetAttribute("Grade")
	return {
		root = creature.body.root,
		element = creature.element,
		height = creature.height,
		grade = if typeof(grade) == "string" then grade else nil,
		mine = marker:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId,
	}
end

-- The drawn creature whose card is `beastId` (the marker's BeastId attribute): its root and height, for the level-up
-- pillar; nil when it isn't drawn here (not summoned, or streamed out)
function CreatureController.GetRootForBeast(beastId: string): (BasePart?, number?)
	for marker, creature in creatures do
		if marker:GetAttribute("BeastId") == beastId and creature.body.root.Parent then
			return creature.body.root, creature.height
		end
	end
	return nil, nil
end

-- A fight pose on the creature drawn on this marker (charge, strike, combo, cast, a Pet button move's pose); amount:
-- how big (its grade, Config/MoveFx POSE_AMOUNT; 1 when nil)
function CreatureController.Pose(marker: BasePart, kind: string, amount: number?)
	local creature = creatures[marker]
	if creature then
		CreatureVisuals.pose(creature.body, kind, os.clock(), amount)
	end
end

-- An attack's dash: the creature runs `share` of the way toward `toward` and back over `seconds`
function CreatureController.Dash(marker: BasePart, toward: Vector3, share: number, seconds: number)
	local creature = creatures[marker]
	if creature then
		creature.dash = { start = os.clock(), seconds = math.max(seconds, 0.05), toward = toward, share = share }
	end
end

-- Rift Step (FightFx): the creature drawn on this marker stands at `at` facing `face` (world), at once; nil: back home
function CreatureController.Blink(marker: BasePart, at: Vector3?, face: Vector3?)
	local creature = creatures[marker]
	if creature then
		creature.blink = if at then { at = at, face = face or marker.Position } else nil
	end
end

-- A fight's attack charge (FightFx): the creature drawn on this marker holds still for `seconds`
function CreatureController.SetCharging(marker: BasePart, seconds: number)
	local creature = creatures[marker]
	if creature then
		creature.chargingUntil = math.max(creature.chargingUntil, os.clock() + seconds)
	end
end

-- Frozen solid by a spike (FightFx): the creature drawn on this marker stops moving and animating for `seconds`
function CreatureController.Freeze(marker: BasePart, seconds: number)
	local creature = creatures[marker]
	if creature then
		creature.frozenUntil = math.max(creature.frozenUntil, os.clock() + seconds)
		creature.chargingUntil = math.max(creature.chargingUntil, os.clock() + seconds)
	end
end

function CreatureController.Start()
	-- The creature models the game uses download in the background; the party bar asks for the player's own first
	CreatureVisuals.preload({})
	local folder = workspace:WaitForChild("Creatures")
	local function watch(child: Instance)
		if not child:IsA("BasePart") then
			return
		end
		nextKey += 1
		known[child] = tostring(nextKey)
		refreshCull()
		-- Swapped out of a boss fight: it shrinks back into its owner first, then it's hidden
		child:GetAttributeChangedSignal("Benched"):Connect(function()
			local creature = creatures[child]
			if child:GetAttribute("Benched") == true and creature then
				local owner = Players:GetPlayerByUserId(tonumber(child:GetAttribute("OwnerUserId")) or 0)
				SummonFx.unsummon(creature.body, Cards.ELEMENTS[creature.element] or Color3.new(1, 1, 1), if owner then owner.Character else nil)
				task.delay(Party.SUMMON_FX.unsummon, refreshCull)
			else
				refreshCull()
			end
		end)
		if not creatures[child] then
			-- Attributes can arrive a moment after the part: try again when the card id shows up
			local connection: RBXScriptConnection
			connection = child:GetAttributeChangedSignal("CardId"):Connect(function()
				connection:Disconnect()
				refreshCull()
			end)
		end
	end
	folder.ChildAdded:Connect(watch)
	-- A tour starting or ending: your own creature's tag hides or comes back
	for _, name in { "TutorialStep", "CombatStep" } do
		Players.LocalPlayer:GetAttributeChangedSignal(name):Connect(function()
			for _, creature in creatures do
				updateTag(creature)
			end
		end)
	end
	-- Stepping up to or away from the healing spring
	RestTimers.Changed:Connect(function()
		for _, creature in creatures do
			updateHealing(creature)
		end
	end)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			known[child] = nil
			remove(child)
		end
	end)
	for _, child in folder:GetChildren() do
		watch(child)
	end

	local sinceOutlines, sinceCull = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local camera = workspace.CurrentCamera
		local origin = if camera then camera.CFrame.Position else Vector3.zero
		for _, creature in creatures do
			step(creature, dt, now, origin)
		end
		sinceCull += dt
		if sinceCull >= Party.CULL_INTERVAL then
			sinceCull = 0
			refreshCull()
		end
		sinceOutlines += dt
		if sinceOutlines >= 1 then
			sinceOutlines = 0
			updateOutlines()
		end
	end)
end

return CreatureController
