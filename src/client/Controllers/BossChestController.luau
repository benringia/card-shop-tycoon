--!strict
-- The boss chests on this client (spec 2026-11-11-boss-chests-design; server: BossChestService): after a boss win's
-- victory screen the server offers three chests (BossChests: an id, no contents). On the pack opening's stage
-- (Util/OpeningStage) the opening plays in beats (the owner 2026-11-11: "more immersive"; Config/BossChests BEATS,
-- Util/ChestMotion):
--   1. the three chests (Util/ChestModel) drop in one after another, each landing with a thud, a dust puff and a shake;
--   2. while you choose ("Pick a chest!" and a countdown) they rattle now and then, light leaking out of a cracked lid,
--      glints run along their gold and the one under your pointer or finger hops and glows;
--   3. a tap, a click or keys 1-3 sends the pick (OpenBossChest): the camera pushes in on your chest, the others slide
--      back into the dark, and it shakes harder and harder with light bursting from its seams;
--   4. the server's answer (BossChestOpened) in, it bursts: flash, shake, the reward's colour in a burst and rays, gold
--      shards like coins, and its card rises out of the chest spinning (an empty chest only puffs);
--   5. the camera eases back and the other two pop open (on a miss one shows the weapon darkened under a "?" while you
--      don't have it);
--   6. a weapon's drop cinematic (WeaponRevealController) then takes the stage; otherwise a tap (or the wait) sends your
--      card off to the top right and the stage closes.
-- If the stage is busy when the offer comes it waits; if the server opened the chests meanwhile, it plays from beat 3.
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BossChests = require(Config:WaitForChild("BossChests"))
local Items = require(Config:WaitForChild("Items"))
local PackFx = require(Config:WaitForChild("PackFx"))
local PackOpening = require(Config:WaitForChild("PackOpening"))
local Rarities = require(Config:WaitForChild("Rarities"))
local WeaponLooks = require(Config:WaitForChild("WeaponLooks"))
local Weapons = require(Config:WaitForChild("Weapons"))
local ChestMotion = require(Shared:WaitForChild("Util"):WaitForChild("ChestMotion"))
local ChestRules = require(Shared:WaitForChild("Util"):WaitForChild("ChestRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local ChestModel = require(ClientUtil:WaitForChild("ChestModel"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local OpeningFx = require(ClientUtil:WaitForChild("OpeningFx"))
local OpeningStage = require(ClientUtil:WaitForChild("OpeningStage"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local LootController = require(Controllers:WaitForChild("LootController"))
local WeaponRevealController = require(Controllers:WaitForChild("WeaponRevealController"))

local BossChestController = {}

local LOOK = BossChests.LOOK
local BEATS = BossChests.BEATS
local SOUNDS = BossChests.SOUNDS
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
local PAD_KEYS = { Enum.KeyCode.KeypadOne, Enum.KeyCode.KeypadTwo, Enum.KeyCode.KeypadThree }
local CLOSE_KEYS = { Enum.KeyCode.Return, Enum.KeyCode.Space, Enum.KeyCode.ButtonA }
local TEXT = Color3.fromRGB(80, 60, 90)
local MYSTERY_TINT = Color3.fromRGB(70, 60, 95)
local DUST = Color3.fromRGB(214, 186, 150)
local WHITE = Color3.new(1, 1, 1)
local GLINT_EVERY = 0.8 -- seconds between glints on the waiting chests
local CHEST_TALL = 0.82 -- a closed chest's height for its width (Util/ChestModel)

type Offer = { id: string, bossId: string, seconds: number }
type Card = { frame: Frame, scale: UIScale, index: number, born: number, rise: number, flying: boolean }
type Show = {
	id: string,
	folder: Folder,
	gui: ScreenGui,
	chests: { ChestModel.Chest },
	bases: { CFrame },
	width: number, -- a chest's width in studs
	pixels: number, -- and on screen
	title: TextLabel,
	timer: TextLabel,
	buttons: { TextButton },
	startedAt: number,
	landed: { boolean },
	rattleAt: { number },
	rattled: { boolean }, -- its rattle's sound played
	nextGlint: number,
	hovered: number?,
	hoverGlow: { number },
	lastStep: number,
	openAt: { number? }, -- when each lid started opening
	openSeconds: { number },
	pickedAt: number?,
	picked: number?,
	contents: { ChestRules.Content }?,
	burstAt: number?,
	backAt: number?, -- the camera easing back, the others coming forward
	cards: { Card },
	closableAt: number?,
	collecting: boolean,
	deadline: number,
	connections: { RBXScriptConnection },
	done: BindableEvent,
}

local queue: { Offer } = {}
local early: { [string]: any } = {} -- a set the server opened before its row showed
local current: Show? = nil
local busy = false
local rng = Random.new()

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function rarityColor(weaponId: string?): Color3
	local weapon = if weaponId then Weapons.ById[weaponId] else nil
	local tier = if weapon then (Rarities.Tiers :: any)[weapon.rarity] else nil
	return if tier then tier.color else rgb(LOOK.colors.glow)
end

local function portraitOf(weaponId: string?): string
	local look = if weaponId then WeaponLooks.WEAPONS[weaponId] else nil
	return if look then look.portrait else ""
end

-- The colour of a chest's light and burst: the weapon's rarity, gold for material, dusky for the "?" and empty
local function colorOf(content: ChestRules.Content): Color3
	if content.kind == "weapon" then
		return rarityColor(content.weaponId)
	elseif content.kind == "mystery" or content.kind == "empty" then
		return MYSTERY_TINT
	end
	return rgb(LOOK.colors.glow)
end

-- A chest's width in studs at the stage's distance and on screen: LOOK.width of the view, no taller than LOOK.height of
-- it, never under LOOK.minPixels
local function chestWidth(view: Vector2): (number, number)
	local halfHeight = PackOpening.CAMERA_DISTANCE * math.tan(math.rad(PackOpening.FIELD_OF_VIEW) / 2)
	local viewWidth = 2 * halfHeight * view.X / view.Y
	local pixels = math.max(math.min(LOOK.width * view.X, LOOK.height * view.Y / CHEST_TALL), LOOK.minPixels)
	return pixels * viewWidth / view.X, pixels
end

-- A soft puff of dust (a landing, an empty chest, the others popping open): motes thrown out sideways, fading fast;
-- `size` is a chest's width
local function dust(show: Show, at: Vector3, color: Color3, size: number, count: number)
	local part = Instance.new("Part")
	part.Name = "Dust"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(size * 0.8, 0.1, size * 0.4)
	part.CFrame = CFrame.new(at)
	part.Parent = show.folder
	local puff = Instance.new("ParticleEmitter")
	puff.Texture = PackFx.IMAGES.mote
	puff.Color = ColorSequence.new(color)
	puff.Shape = Enum.ParticleEmitterShape.Box
	puff.EmissionDirection = Enum.NormalId.Top
	puff.SpreadAngle = Vector2.new(70, 70)
	puff.Speed = NumberRange.new(size * 0.6, size * 1.4)
	puff.Drag = 4
	puff.Acceleration = Vector3.new(0, size * 0.3, 0)
	puff.Lifetime = NumberRange.new(0.35, 0.7)
	puff.Size = NumberSequence.new(size * 0.12, size * 0.3)
	puff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	puff.Rotation = NumberRange.new(0, 360)
	puff.Rate = 0
	puff.Parent = part
	puff:Emit(count)
	Debris:AddItem(part, 1)
end

-- Points on a chest at rest: its mouth (the top of the body) and its middle
local function mouthOf(show: Show, index: number): Vector3
	return (show.bases[index] * CFrame.new(0, show.width * 0.5, 0)).Position
end

local function middleOf(show: Show, index: number): Vector3
	return (show.bases[index] * CFrame.new(0, show.width * 0.37, 0)).Position
end

local function finish(show: Show, hideStage: boolean)
	if current ~= show then
		return
	end
	current = nil
	for _, connection in show.connections do
		connection:Disconnect()
	end
	OpeningFx.clear()
	show.folder:Destroy()
	show.gui:Destroy()
	if hideStage then
		OpeningStage.hide()
	end
	show.done:Fire()
end

-- The card that rises out of an opened chest: the weapon (yours, or darkened under a "?"), the material and how many
-- (yours with its progress toward the weapon), or an empty chest's why. It follows its chest on screen (step).
local function card(show: Show, index: number, content: ChestRules.Content, mine: boolean)
	local view = workspace.CurrentCamera.ViewportSize
	local width = math.max(math.min(show.pixels * 0.95, LOOK.cardHeight * view.Y / 1.1), 120)
	local frame = Instance.new("Frame")
	frame.Name = `Card{index}`
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Size = UDim2.fromOffset(width, width * 1.1)
	frame.BackgroundColor3 = WHITE
	frame.Parent = show.gui
	UIKit.corner(frame, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if mine then 4 else 2
	stroke.Color = if mine then rgb(LOOK.colors.trim) else Color3.fromRGB(205, 195, 220)
	stroke.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = frame

	local art = Instance.new("Frame")
	art.BackgroundTransparency = 1
	art.Position = UDim2.fromScale(0.1, 0.06)
	art.Size = UDim2.fromScale(0.8, 0.62)
	art.Parent = frame
	local line: string
	local under: string? = nil
	local weapon = if content.weaponId then Weapons.ById[content.weaponId] else nil
	if content.kind == "empty" then
		local words = (BossChests.EMPTY :: any)[content.reason or ""] or BossChests.EMPTY.strong
		Icon.make(art, BossChests.EMPTY.glyph, UDim2.fromScale(1, 1))
		line = words.line
		under = words.under
	elseif content.kind == "material" and content.item then
		Icon.make(art, (Items.ITEMS[content.item] or {}).icon or "?", UDim2.fromScale(1, 1))
		line = `x{content.count or 1}`
	else
		local image = portraitOf(content.weaponId)
		if image ~= "" then
			local picture = Instance.new("ImageLabel")
			picture.BackgroundTransparency = 1
			picture.Image = image
			picture.ScaleType = Enum.ScaleType.Fit
			picture.Size = UDim2.fromScale(1, 1)
			picture.ImageColor3 = if content.kind == "mystery" then MYSTERY_TINT else WHITE
			picture.Parent = art
		else
			Icon.make(art, "🗡️", UDim2.fromScale(1, 1))
		end
		if content.kind == "mystery" then
			local mark = UIKit.label(art, "?", Enum.Font.FredokaOne, 64, rgb(LOOK.colors.trim))
			mark.Size = UDim2.fromScale(1, 1)
			mark.TextXAlignment = Enum.TextXAlignment.Center
			mark.TextScaled = true
			local outline = Instance.new("UIStroke")
			outline.Thickness = 3
			outline.Color = Color3.fromRGB(70, 40, 20)
			outline.Parent = mark
		end
		line = if weapon then weapon.name else "?"
	end
	local name = UIKit.label(frame, line, Enum.Font.FredokaOne, 20, if content.kind == "weapon" then rarityColor(content.weaponId) else TEXT)
	name.Position = UDim2.fromScale(0.05, 0.7)
	name.Size = UDim2.fromScale(0.9, 0.15)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextScaled = true
	local goal = under or (if mine and content.kind == "material" and content.item then LootController.GoalLine(content.item) else nil)
	if goal then
		local note = UIKit.label(frame, goal, Enum.Font.GothamBold, 14, TEXT)
		note.Position = UDim2.fromScale(0.05, 0.85)
		note.Size = UDim2.fromScale(0.9, 0.11)
		note.TextXAlignment = Enum.TextXAlignment.Center
		note.TextScaled = true
	end
	if mine then
		local tag = UIKit.label(frame, "Yours!", Enum.Font.FredokaOne, 20, WHITE)
		tag.AnchorPoint = Vector2.new(0.5, 0.5)
		tag.Position = UDim2.fromScale(0.5, 0)
		tag.Size = UDim2.fromOffset(90, 30)
		tag.BackgroundTransparency = 0
		tag.BackgroundColor3 = rgb(LOOK.colors.trim)
		tag.TextXAlignment = Enum.TextXAlignment.Center
		UIKit.corner(tag, 15)
	end
	-- From the chest's mouth (step moves it each frame from there)
	local mouth = workspace.CurrentCamera:WorldToViewportPoint(mouthOf(show, index))
	frame.Position = UDim2.fromOffset(mouth.X, mouth.Y)
	local rise = if mine then BEATS.burst.rise else BEATS.burst.rise * 0.7
	table.insert(show.cards, { frame = frame, scale = scale, index = index, born = os.clock(), rise = rise, flying = false })
end

-- Beat 5: one of the others pops open with a puff and its card
local function popOther(show: Show, index: number, content: ChestRules.Content)
	show.openAt[index] = os.clock()
	show.openSeconds[index] = LOOK.openSeconds * 0.7
	ChestModel.light(show.chests[index], colorOf(content), 0)
	OpeningStage.play(SOUNDS.creak, 1.3)
	dust(show, mouthOf(show, index), if content.kind == "material" then colorOf(content) else DUST, show.width, 10)
	card(show, index, content, false)
end

-- Beat 4: your chest bursts open (the tension's over and the answer is in)
local function burst(show: Show)
	local index = show.picked :: number
	local contents = show.contents :: { ChestRules.Content }
	local mine = contents[index]
	local color = colorOf(mine)
	local mouth = mouthOf(show, index)
	local empty = mine.kind == "empty"
	show.burstAt = os.clock()
	show.openAt[index] = os.clock()
	show.openSeconds[index] = LOOK.openSeconds * 0.6
	ChestModel.light(show.chests[index], color, 0)
	OpeningStage.fade(SOUNDS.tension, 0.12)
	OpeningStage.play(SOUNDS.creak)
	if empty then
		OpeningStage.play(SOUNDS.empty)
		dust(show, mouth, DUST, show.width * 1.4, 22)
		OpeningStage.shake(BEATS.burst.shake * 0.4, 0.25)
	else
		OpeningStage.play(if mine.kind == "weapon" then SOUNDS.weapon else SOUNDS.material)
		OpeningStage.play(SOUNDS.coins)
		OpeningStage.flash(if mine.kind == "weapon" then 0.8 else BEATS.burst.flash, 0.45)
		OpeningStage.shake(BEATS.burst.shake, 0.4)
		OpeningFx.burst(mouth, color, BEATS.burst.size)
		OpeningFx.shards(mouth, BEATS.burst.shards, true, 1)
		OpeningFx.rays(true, color, mouth + Vector3.new(0, show.width * 0.6, show.width))
		OpeningFx.motes(10, CFrame.new(mouth), color)
	end
	card(show, index, mine, true)
	task.delay(BEATS.burst.othersAfter, function()
		if current ~= show then
			return
		end
		show.backAt = os.clock()
		OpeningStage.ease(0.5)
		OpeningFx.rays(false, color)
		OpeningFx.motes(0)
		local order = {}
		for other = 1, #show.chests do
			if other ~= index then
				table.insert(order, other)
			end
		end
		for _, other in order do
			task.wait(BossChests.OPEN_GAP)
			if current ~= show then
				return
			end
			popOther(show, other, contents[other])
		end
		task.wait(0.4)
		if current ~= show then
			return
		end
		if mine.kind == "weapon" then
			-- The server sends the drop cinematic REVEAL_AFTER after the opening; once it's here it gets the stage as it is
			local giveUp = os.clock() + BossChests.REVEAL_AFTER + 4
			while current == show and not WeaponRevealController.IsPlaying() and os.clock() < giveUp do
				task.wait(0.1)
			end
			local waiting = WeaponRevealController.IsPlaying()
			if waiting then
				WeaponRevealController.HandOver()
			end
			finish(show, not waiting)
		else
			show.closableAt = os.clock() + BossChests.SKIP_AFTER
			task.delay(BossChests.CLOSE_AFTER, function()
				if current == show and not show.collecting then
					BossChestController.Collect(show)
				end
			end)
		end
	end)
end

-- Beat 6: your card flies off to the top right with a sparkle, then the stage closes
function BossChestController.Collect(show: Show)
	if show.collecting or current ~= show then
		return
	end
	show.collecting = true
	local mine = if show.picked and show.contents then show.contents[show.picked] else nil
	for _, entry in show.cards do
		local frame = entry.frame
		if mine and mine.kind ~= "empty" and entry.index == show.picked then
			entry.flying = true
			local view = workspace.CurrentCamera.ViewportSize
			local info = TweenInfo.new(BEATS.collect.seconds, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			TweenService:Create(frame, info, { Position = UDim2.fromOffset(view.X - 70, 70), Rotation = 20 }):Play()
			TweenService:Create(entry.scale, info, { Scale = 0.15 }):Play()
		else
			TweenService:Create(entry.scale, TweenInfo.new(0.25), { Scale = 0 }):Play()
		end
	end
	if mine and mine.kind ~= "empty" then
		OpeningStage.play(SOUNDS.collect)
	end
	task.delay(BEATS.collect.seconds + 0.05, finish, show, true)
end

-- Beat 3: your chest's tension (from your pick, or the server's when the time ran out)
local function tension(show: Show, index: number)
	show.picked = index
	show.pickedAt = os.clock()
	show.title.Visible = false
	show.timer.Visible = false
	for _, button in show.buttons do
		button.Active = false
		button.Visible = false
	end
	OpeningStage.play(SOUNDS.pick)
	OpeningStage.play(SOUNDS.tension)
	OpeningStage.push(BEATS.tension.push, middleOf(show, index), BEATS.tension.pushSeconds)
end

local function pick(show: Show, index: number)
	if current ~= show or show.picked then
		return
	end
	tension(show, index)
	Remotes.OpenBossChest:FireServer(show.id, index)
end

-- The answer: kept until the tension's done (step bursts it); a server-opened set starts its tension now
local function reveal(show: Show, index: number, contents: { ChestRules.Content })
	if show.contents then
		return
	end
	show.contents = contents
	if show.picked ~= index then
		tension(show, index)
	end
end

-- How far a chest is into its hovered look (0-1), easing toward the pointer or finger being on it
local function hoverOf(show: Show, index: number, dt: number): number
	local target = if show.hovered == index and not show.picked then 1 else 0
	local glow = show.hoverGlow[index] + (target - show.hoverGlow[index]) * math.min(1, dt * 12)
	show.hoverGlow[index] = glow
	return glow
end

-- Each frame: every chest from its beat (dropping, rattling, hovered, sunk back, shaking, opening) and the cards over
-- their chests
local function step(show: Show)
	local now = os.clock()
	local dt = now - show.lastStep
	show.lastStep = now
	local elapsed = now - show.startedAt
	for index, chest in show.chests do
		local base = show.bases[index]
		local height = ChestMotion.dropHeight(elapsed, index, BEATS.drop)
		if not show.landed[index] and height <= 0 then
			show.landed[index] = true
			OpeningStage.play(SOUNDS.thud, 0.9 + 0.1 * index)
			OpeningStage.shake(BEATS.drop.shake, 0.2)
			dust(show, (base * CFrame.new(0, show.width * 0.05, 0)).Position, DUST, show.width, 14)
		end
		local lift, roll, crack, light = height, 0, 0, 0
		if show.picked == nil then
			-- Waiting: a rattle now and then, the hovered one hops and glows
			if show.landed[index] then
				local r = ChestMotion.rattle(now, show.rattleAt[index], BEATS.rattle)
				if r > 0 and not show.rattled[index] then
					show.rattled[index] = true
					OpeningStage.play(SOUNDS.rattle, BossChests.RATTLE_SPEED)
				elseif now > show.rattleAt[index] + BEATS.rattle.seconds then
					show.rattleAt[index] = now + rng:NextNumber(BEATS.rattle.every[1], BEATS.rattle.every[2])
					show.rattled[index] = false
				end
				local hover = hoverOf(show, index, dt)
				crack = math.rad(BEATS.rattle.crack) * r
				light = 0.5 * r + BEATS.hover.glow * hover
				lift += (BEATS.rattle.hop * r + BEATS.hover.hop * hover * math.abs(math.sin(now * 9))) * show.width
				roll = math.rad(4) * r * math.sin(now * 40)
			end
		elseif show.picked == index then
			local into = now - (show.pickedAt :: number)
			local share = math.clamp(into / BEATS.tension.seconds, 0, 1)
			roll = math.rad(ChestMotion.tension(into, BEATS.tension))
			crack = if show.burstAt then 0 else math.rad(5) * share * math.abs(math.sin(now * 30))
			light = if show.burstAt then 0 else BEATS.tension.leak * share
			lift += 0.15 * show.width * share
		else
			-- The others: back into the dark while yours is picked, forward again for their turn
			local away = if show.backAt then 1 - math.clamp((now - show.backAt) / 0.4, 0, 1) else math.clamp((now - (show.pickedAt :: number)) / 0.4, 0, 1)
			base = base * CFrame.new(0, -0.1 * show.width * away, show.width * 1.4 * away)
		end
		local openAt = show.openAt[index]
		if openAt then
			local open = math.clamp((now - openAt) / show.openSeconds[index], 0, 1)
			crack = math.rad(LOOK.lidOpen) * TweenService:GetValue(open, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			light = open
		end
		chest.lid = crack
		-- An opened chest's light is its reward's colour (set as it opens); a crack of light before that is gold
		ChestModel.light(chest, if openAt then chest.glow.Color else rgb(LOOK.colors.glow), light)
		ChestModel.place(chest, base * CFrame.new(0, lift, 0) * CFrame.Angles(0, 0, roll))
	end
	-- Glints running along the waiting chests' gold
	if not show.picked and now >= show.nextGlint then
		show.nextGlint = now + GLINT_EVERY
		local index = rng:NextInteger(1, #show.chests)
		if show.landed[index] then
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local at = show.bases[index] * CFrame.new(side * show.width * 0.48, show.width * rng:NextNumber(0.1, 0.5), -show.width * 0.32)
			OpeningFx.glint(at.Position, show.width * 0.25)
		end
	end
	-- The burst, once the tension's done and the answer is in
	if show.picked and show.contents and not show.burstAt and now - (show.pickedAt :: number) >= BEATS.tension.seconds then
		burst(show)
	end
	-- Cards over their chests, rising out of them spinning
	local camera = workspace.CurrentCamera
	for _, entry in show.cards do
		if not entry.flying then
			local p = TweenService:GetValue(math.clamp((now - entry.born) / entry.rise, 0, 1), Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			local top = camera:WorldToViewportPoint((show.bases[entry.index] * CFrame.new(0, show.width * 0.9, 0)).Position)
			local mouth = camera:WorldToViewportPoint(mouthOf(show, entry.index))
			entry.frame.Position = UDim2.fromOffset(top.X, mouth.Y + (top.Y - mouth.Y) * p)
			entry.frame.Rotation = BEATS.burst.spin * (1 - p)
			entry.scale.Scale = 0.2 + 0.8 * p
		end
	end
	if not show.picked then
		show.timer.Text = tostring(math.max(0, math.ceil(show.deadline - now)))
	end
end

local function build(offer: Offer): Show
	OpeningStage.show()
	OpeningStage.bars(true, 0.4)
	OpeningStage.dim(WeaponLooks.REVEAL.dim, 0.5)
	local camera = workspace.CurrentCamera
	local view = camera.ViewportSize
	local width, pixels = chestWidth(view)
	local folder = Instance.new("Folder")
	folder.Name = "BossChests"
	folder.Parent = OpeningStage.folder()
	local colors = { wood = rgb(LOOK.colors.wood), woodDark = rgb(LOOK.colors.woodDark), trim = rgb(LOOK.colors.trim) }
	local eye = OpeningStage.home().Position
	local chests, bases = {}, {}
	for index, x in LOOK.xs do
		local at = OpeningStage.screenPoint(x * view.X, LOOK.y * view.Y, PackOpening.CAMERA_DISTANCE)
		bases[index] = CFrame.lookAt(at, Vector3.new(eye.X, at.Y, eye.Z)) -- its front (-Z) to the camera
		chests[index] = ChestModel.new(folder, width, colors)
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "BossChests"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 55 -- over the stage's bars (40), under the weapon reveal (60)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local title = UIKit.label(gui, "Pick a chest!", Enum.Font.FredokaOne, 44, WHITE)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0.12)
	title.Size = UDim2.fromOffset(500, 56)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local shadow = Instance.new("UIStroke")
	shadow.Thickness = 3
	shadow.Color = Color3.fromRGB(60, 30, 80)
	shadow.Parent = title
	local timer = UIKit.label(gui, tostring(offer.seconds), Enum.Font.FredokaOne, 26, rgb(LOOK.colors.trim))
	timer.AnchorPoint = Vector2.new(0.5, 0)
	timer.Position = UDim2.new(0.5, 0, 0.12, 58)
	timer.Size = UDim2.fromOffset(80, 32)
	timer.TextXAlignment = Enum.TextXAlignment.Center

	local now = os.clock()
	local show: Show = {
		id = offer.id,
		folder = folder,
		gui = gui,
		chests = chests,
		bases = bases,
		width = width,
		pixels = pixels,
		title = title,
		timer = timer,
		buttons = {},
		startedAt = now,
		landed = {},
		rattleAt = {},
		rattled = {},
		nextGlint = now + 1,
		hovered = nil,
		hoverGlow = {},
		lastStep = now,
		openAt = {},
		openSeconds = {},
		pickedAt = nil,
		picked = nil,
		contents = nil,
		burstAt = nil,
		backAt = nil,
		cards = {},
		closableAt = nil,
		collecting = false,
		deadline = now + offer.seconds,
		connections = {},
		done = Instance.new("BindableEvent"),
	}
	for index, chest in chests do
		show.landed[index] = false
		show.rattleAt[index] = now + ChestMotion.landsAt(index, BEATS.drop) + rng:NextNumber(BEATS.rattle.every[1], BEATS.rattle.every[2])
		show.rattled[index] = false
		show.hoverGlow[index] = 0
		ChestModel.place(chest, bases[index] * CFrame.new(0, BEATS.drop.height, 0))
		-- A tap target over the chest, as big as it shows (never under minPixels)
		local middle = camera:WorldToViewportPoint(middleOf(show, index))
		local button = Instance.new("TextButton")
		button.Name = `Chest{index}`
		button.Text = ""
		button.BackgroundTransparency = 1
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.fromOffset(middle.X, middle.Y)
		button.Size = UDim2.fromOffset(pixels, pixels * 0.85)
		button.Parent = gui
		button.Activated:Connect(function()
			pick(show, index)
		end)
		button.MouseEnter:Connect(function()
			show.hovered = index
		end)
		button.MouseLeave:Connect(function()
			if show.hovered == index then
				show.hovered = nil
			end
		end)
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				show.hovered = index
			end
		end)
		show.buttons[index] = button
	end
	table.insert(show.connections, RunService.RenderStepped:Connect(function()
		step(show)
	end))
	table.insert(show.connections, UserInputService.InputBegan:Connect(function(input)
		if not show.picked then
			local index = table.find(KEYS, input.KeyCode) or table.find(PAD_KEYS, input.KeyCode)
			if index then
				pick(show, index)
			end
			return
		end
		local closable = show.closableAt
		local tapped = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		if closable and os.clock() >= closable and (tapped or table.find(CLOSE_KEYS, input.KeyCode)) then
			BossChestController.Collect(show)
		end
	end))
	return show
end

-- One offer at a time, once the stage is free (a first clear's moment, a level-up pack or a weapon reveal may be on it)
local function drain()
	if busy then
		return
	end
	busy = true
	while #queue > 0 do
		local offer = table.remove(queue, 1) :: Offer
		local giveUp = os.clock() + offer.seconds
		while (OpeningStage.isShown() or WeaponRevealController.IsPlaying()) and os.clock() < giveUp do
			task.wait(0.2)
		end
		if OpeningStage.isShown() then
			early[offer.id] = nil
			continue -- still busy: the server opens it; what you won is in your Bag already
		end
		local show = build(offer)
		current = show
		local answered = early[offer.id]
		if answered then
			early[offer.id] = nil
			reveal(show, answered.index, answered.contents)
		end
		show.done.Event:Wait()
	end
	busy = false
end

local function readContents(raw: unknown): { ChestRules.Content }?
	if typeof(raw) ~= "table" then
		return nil
	end
	local list = raw :: { any }
	if #list ~= BossChests.COUNT then
		return nil
	end
	for _, content in list do
		local kinds = { weapon = true, material = true, mystery = true, empty = true }
		if typeof(content) ~= "table" or not kinds[content.kind] then
			return nil
		end
	end
	return list :: any
end

function BossChestController.Start()
	Remotes.BossChests.OnClientEvent:Connect(function(payload: unknown)
		if typeof(payload) ~= "table" then
			return
		end
		local data = payload :: any
		if typeof(data.id) ~= "string" or typeof(data.bossId) ~= "string" then
			return
		end
		local seconds = math.clamp(tonumber(data.seconds) or BossChests.PICK_SECONDS, 1, 60)
		-- Its pictures fetched now, so the cards don't pop in blank
		task.spawn(function()
			local images = {}
			for _, weapon in Weapons.WEAPONS do
				local image = portraitOf(weapon.id)
				if weapon.source.boss == data.bossId and image ~= "" then
					local label = Instance.new("ImageLabel")
					label.Image = image
					table.insert(images, label)
				end
			end
			pcall(ContentProvider.PreloadAsync, ContentProvider, images)
		end)
		table.insert(queue, { id = data.id, bossId = data.bossId, seconds = seconds })
		task.spawn(drain)
	end)
	Remotes.BossChestOpened.OnClientEvent:Connect(function(payload: unknown)
		if typeof(payload) ~= "table" then
			return
		end
		local data = payload :: any
		local index = ChestRules.validIndex(data.index, BossChests.COUNT)
		local contents = readContents(data.contents)
		if typeof(data.id) ~= "string" or not index or not contents then
			return
		end
		local show = current
		if show and show.id == data.id then
			reveal(show, index, contents)
		else
			early[data.id] = { index = index, contents = contents }
		end
	end)
end

return BossChestController
