--!strict
-- Pack opening (UI project 3 spec section 4): the Rip tile (while carrying a box of packs) and the 3D opening. The
-- server rolls the cards (PackOpened); this plays them: the pack floats on a far-off stage (Util/OpeningStage), a
-- swipe, tap, Space or T tears it in a short cinematic (Util/OpeningPack), the cards stack up one at a time, each tap
-- flips the next (Rare and better tease and celebrate, a shown big card stays alive; Util/OpeningCards), the shown card
-- zips into a row, and after the last one the row flies to a sparkling results lineup with the pills and Continue
-- (Util/OpeningResults). Util/OpeningFlow decides what each tap does, so taps during a tear or a big flip do nothing.
-- A fight, death or respawn closes it and gives the camera back.
local ContentProvider = game:GetService("ContentProvider")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CardReveal = require(Config:WaitForChild("CardReveal"))
local Cards = require(Config:WaitForChild("Cards"))
local Packs = require(Config:WaitForChild("Packs"))
local PackOpening = require(Config:WaitForChild("PackOpening"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local OpeningFlow = require(Shared:WaitForChild("Util"):WaitForChild("OpeningFlow"))
local RevealRules = require(Shared:WaitForChild("Util"):WaitForChild("RevealRules"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local Hud = require(ClientUtil:WaitForChild("Hud"))
local OpeningCards = require(ClientUtil:WaitForChild("OpeningCards"))
local OpeningPack = require(ClientUtil:WaitForChild("OpeningPack"))
local OpeningResults = require(ClientUtil:WaitForChild("OpeningResults"))
local OpeningStage = require(ClientUtil:WaitForChild("OpeningStage"))
local AnnouncementController = require(Controllers:WaitForChild("AnnouncementController"))
local RarityGuideController = require(Controllers:WaitForChild("RarityGuideController"))

type Pack = typeof(Packs.ById[""])
type PullResult = { cardId: string, foil: boolean, grade: string }

local RIP_WAIT_SECONDS = 3 -- re-enable the tile if the server never answers
local RIP_KEY = Enum.KeyCode.T -- rips a pack while the opening is closed
local ADVANCE_ACTION = "PackOpeningAdvance"
local TAP_PIXELS = 12 -- a press that moves less than this is a tap

local player = Players.LocalPlayer

local PackOpeningController = {}

local ripButton: TextButton
local flow: OpeningFlow.State? = nil
local pulls: { OpeningCards.Pull } = {}
local opened: Pack? = nil
local built = false -- the cards' faces are ready (they're built while the pack tears)
local generation = 0 -- bumps on every open and close, so a step still running for an old opening stops
local waitingForServer = false
local soundsLoaded = false
local pressStart: Vector2? = nil -- a press on the pack that may become a swipe
local source: string? = nil -- where the pack on the stage came from: OpeningFlow.BOX or its Bag item's id
local resultsShown = false -- the results and their buttons are up
local bagItems: { [string]: number } = {} -- the Bag's counts (ItemsChanged), for Open another from the Bag

-- Tells the Bag whether a pack may open now (OpeningFlow.isBusy): a pack on the stage or a rip on its way
local function publishBusy()
	player:SetAttribute("PackOpeningBusy", OpeningFlow.isBusy(flow ~= nil, waitingForServer))
end

local function buildOddsText(pack: Pack): string
	local lines = { `{pack.name} pack odds` }
	for index, slot in pack.slots do
		local total = 0
		for _, option in slot do
			total += option.weight
		end
		local parts = {}
		for _, option in slot do
			table.insert(parts, string.format("%s %g%%", option.rarity, option.weight / total * 100))
		end
		table.insert(lines, `Card {index}: {table.concat(parts, " / ")}`)
	end
	table.insert(lines, string.format("Any card can be Foil (%gx value): %g%%", Rarities.FOIL_MULTIPLIER, Rarities.FOIL_CHANCE * 100))
	table.insert(lines, `Pity: your first Legendary within {Packs.PITY.FIRST_LEGENDARY_PACKS} packs, then one at least every {Packs.PITY.LEGENDARY_PACKS}; an Epic or better every {Packs.PITY.EPIC_PACKS}`)
	return table.concat(lines, "\n")
end

-- Packs left until each guarantee (the server keeps the count; PackService sets these attributes)
local function refreshPity()
	local legendary = player:GetAttribute("PityLegendary")
	local epic = player:GetAttribute("PityEpic")
	if typeof(legendary) ~= "number" or typeof(epic) ~= "number" then
		OpeningResults.pity("")
		return
	end
	local function packs(count: number): string
		return if count == 1 then "next pack" else `{count} packs`
	end
	OpeningResults.pity(`👑 Legendary in {packs(legendary)} · Epic in {packs(epic)}`)
end

local function getPacksLeft(): number
	local units = player:GetAttribute("CarryUnits")
	return if typeof(units) == "number" then units else 0
end

-- Ripping is offered while carrying a box whose product is a pack (or a deck box: "Open")
local function refreshRipButton()
	local productId = player:GetAttribute("CarryProductId")
	local pack = if typeof(productId) == "string" then Packs.ById[productId] else nil
	local deck = pack ~= nil and pack.kind == "Deck"
	local left = getPacksLeft()
	ripButton.Visible = pack ~= nil and flow == nil
	Hud.setLabel("Rip", if deck then `Open · {left}` else `Rip · {left}`)
	OpeningResults.box(if not pack then "Box empty" elseif deck then `{left} deck boxes left in box` else `{left} packs left in box`)
end

-- Waits for the server's roll a while (a rip or a Bag pack asked for here): busy meanwhile
local function awaitServer()
	waitingForServer = true
	publishBusy()
	task.delay(RIP_WAIT_SECONDS, function()
		waitingForServer = false
		publishBusy()
	end)
end

local function onRip()
	if waitingForServer or flow ~= nil then
		return
	end
	awaitServer()
	Remotes.RipPack:FireServer()
end

-- How many more can open from where the pack on the stage came from (its box, or its Bag item)
local function anotherLeft(): number
	local productId = player:GetAttribute("CarryProductId")
	local boxHoldsPacks = typeof(productId) == "string" and Packs.ById[productId] ~= nil
	local bagCount = if source and source ~= OpeningFlow.BOX then bagItems[source] or 0 else 0
	return OpeningFlow.anotherLeft(source, boxHoldsPacks, getPacksLeft(), bagCount)
end

-- Big pulls go to chat once they're revealed: ours locally, everyone else via the server
local function announce(pull: OpeningCards.Pull)
	if CardRules.shouldAnnounce(pull.card, pull.foil) then
		AnnouncementController.Show(player.DisplayName, pull.card, pull.foil)
		Remotes.PullRevealed:FireServer(pull.card.id, pull.foil)
	end
end

local function close()
	generation += 1
	flow = nil
	resultsShown = false
	publishBusy()
	opened = nil
	pressStart = nil
	ContextActionService:UnbindAction(ADVANCE_ACTION)
	OpeningCards.clear()
	OpeningPack.clear()
	OpeningResults.hide()
	OpeningStage.hide()
	refreshRipButton()
end

-- The current animation finished: tell the flow (lock: seconds taps stay ignored)
local function finished(lock: number?)
	if flow then
		flow = OpeningFlow.done(flow, os.clock(), lock)
	end
end

local function flipNext(gen: number)
	local state = flow
	if not state then
		return
	end
	local index = state.index
	OpeningResults.hint(nil)
	OpeningCards.flip(index)
	if gen ~= generation then
		return
	end
	local pull = pulls[index]
	announce(pull)
	-- No hint from here on: the first one taught the tap, and on phones a bottom hint covers the row's prices
	finished(if pull.plan.spotlight then PackOpening.FLIP.SPOTLIGHT_LOCK else 0)
end

local function showResults(gen: number)
	OpeningResults.hint(nil)
	local state = flow
	if state and state.index > 0 then
		OpeningCards.stow(state.index)
	end
	if gen ~= generation then
		return
	end
	OpeningCards.lineup()
	if gen ~= generation then
		return
	end
	local newCount, value = 0, 0
	for _, pull in pulls do
		newCount += if pull.isNew then 1 else 0
		value += CardRules.getMarketValue(pull.card, pull.foil, 1, BeastRules.START_STARS, pull.grade)
	end
	local left = anotherLeft()
	OpeningResults.results(newCount, value, if left > 0 then `Open another · {left}` else nil)
	-- the set's bar: what's collected now (the binder has this pack already) and the NEW ones it added
	local first = pulls[1]
	local set = if first then first.card.set else nil
	if set then
		local Binder = require(Controllers:WaitForChild("BinderController")) :: any
		local owned, total = Binder.SetCollected(set)
		OpeningResults.setProgress(set, owned, total, newCount)
	else
		OpeningResults.setProgress(nil, 0, 0, 0)
	end
	resultsShown = true
end

-- Open another (owner 2026-11-17: "add 'open another' button after ripping card. that should open another card from
-- where the first card source is"): this one closes and the next comes from the same carried box or Bag item. T does
-- it too once the results are up.
local function openAnother()
	local from = source
	if not resultsShown or not from or anotherLeft() <= 0 then
		return
	end
	close()
	if from == OpeningFlow.BOX then
		onRip()
		return
	end
	awaitServer()
	Remotes.OpenBagPack:FireServer(from)
end

local function tearOpen(gen: number)
	OpeningResults.hint(nil)
	local pack = opened
	if pack and pack.kind == "Deck" then
		OpeningPack.open()
	else
		OpeningPack.tear()
	end
	while not built and gen == generation do
		task.wait()
	end
	if gen ~= generation then
		return
	end
	finished()
	OpeningPack.lower()
	OpeningCards.stack(OpeningPack.mouth())
	OpeningPack.away()
	if gen ~= generation then
		return
	end
	finished()
	if flow and flow.phase == "Results" then
		showResults(gen)
	else
		OpeningResults.hint("Tap to flip the first card", true)
	end
end

-- A tap (or Space / T, or a swipe across the pack): what it does depends on where the opening is
local function tap()
	local state = flow
	if not state then
		return
	end
	local action
	state, action = OpeningFlow.tap(state, os.clock())
	flow = state
	local gen = generation
	if action == "Tear" then
		task.spawn(tearOpen, gen)
	elseif action == "Flip" then
		task.spawn(flipNext, gen)
	elseif action == "Next" then
		task.spawn(function()
			OpeningCards.stow(state.index)
			if gen ~= generation then
				return
			end
			finished()
			flipNext(gen)
		end)
	elseif action == "Results" then
		task.spawn(showResults, gen)
	end
end

-- A press on the stage: before the tear, a drag across the pack tears it; anything else is a tap
local function onPress(position: Vector2)
	if flow and flow.phase == "Ready" then
		pressStart = position
		return
	end
	tap()
end

local function onInputChanged(input: InputObject)
	local start = pressStart
	if not start or not flow or flow.phase ~= "Ready" then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local dx = math.abs(input.Position.X - start.X)
	OpeningPack.drag(dx / PackOpening.PACK_STAGE.SWIPE_PIXELS)
	if dx >= PackOpening.PACK_STAGE.SWIPE_PIXELS then
		pressStart = nil
		tap()
	end
end

local function onInputEnded(input: InputObject)
	local start = pressStart
	local release = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	if not start or not release then
		return
	end
	pressStart = nil
	if (Vector2.new(input.Position.X, input.Position.Y) - start).Magnitude < TAP_PIXELS then
		tap()
	else
		OpeningPack.drag(0) -- not far enough: the strip settles back
	end
end

-- The Rarity guide lives in the HUD under this screen; it's lifted over the results while open
local function openRarityGuide()
	local frame = RarityGuideController.Open()
	local home = frame.Parent
	local screen = OpeningResults.gui()
	if home == screen then
		return
	end
	frame.Parent = screen
	local watch: RBXScriptConnection
	watch = frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not frame.Visible then
			watch:Disconnect()
			frame.Parent = home
		end
	end)
end

local function onPackOpened(productId: string, results: { PullResult }, newFlags: { boolean }?, itemId: string?)
	local fromRip = waitingForServer and itemId == nil -- a Bag pack names its item (Config/Items `open`; LevelUpService)
	waitingForServer = false
	publishBusy()
	local pack = Packs.ById[productId]
	if not pack or typeof(results) ~= "table" or flow ~= nil then
		return
	end
	local flags = if typeof(newFlags) == "table" then newFlags else {}
	pulls = {}
	for index, result in results do
		local card = if typeof(result) == "table" then Cards.ById[result.cardId] else nil
		if card then
			local foil = result.foil == true
			local grade = if BeastRules.isGrade(result.grade) then result.grade else BeastRules.DEFAULT_GRADE
			table.insert(pulls, {
				card = card,
				foil = foil,
				grade = grade,
				isNew = flags[index] == true,
				plan = RevealRules.plan(CardReveal, card.rarity, foil, card.set == "Frontier"),
			})
		end
	end
	-- their creature models start downloading now, ahead of the background queue: the rip and the cards before give
	-- them a few seconds, and one that still isn't in stays in its card (CreatureVisuals.isReady; owner 2026-11-19)
	local names = {}
	for _, pull in pulls do
		table.insert(names, pull.card.name)
	end
	require(ClientUtil:WaitForChild("CreatureVisuals")).ensure(names)
	generation += 1
	local gen = generation
	opened = pack
	source = if typeof(itemId) == "string" then itemId elseif fromRip then OpeningFlow.BOX else nil
	resultsShown = false
	flow = OpeningFlow.new(#pulls)
	publishBusy()
	built = false
	refreshRipButton()
	if source and source ~= OpeningFlow.BOX then
		OpeningResults.box("From your Bag") -- not the carried box's count: this one came from the Bag
	end
	OpeningStage.show()
	if not soundsLoaded then
		soundsLoaded = true
		task.spawn(function()
			local sounds = {}
			for _, id in OpeningStage.soundIds() do
				local sound = Instance.new("Sound")
				sound.SoundId = id
				table.insert(sounds, sound)
			end
			pcall(ContentProvider.PreloadAsync, ContentProvider, sounds)
		end)
	end
	-- a pack holding something big trembles and glows first (sometimes a fake-out on a Very Rare)
	local rarities = {}
	for _, pull in pulls do
		table.insert(rarities, pull.card.rarity)
	end
	local heavy = RevealRules.packTell(CardReveal.PACK_TELL, rarities, math.random())
	OpeningPack.show(pack, heavy)
	OpeningResults.show(buildOddsText(pack))
	refreshPity()
	OpeningResults.hint(if pack.kind == "Deck" then "Tap the lid to open" elseif heavy then CardReveal.PACK_TELL.hint else "Swipe across the top to open")
	ContextActionService:BindActionAtPriority(ADVANCE_ACTION, function(_, state, input)
		if state == Enum.UserInputState.Begin then
			if input.KeyCode == RIP_KEY and resultsShown then
				openAnother()
			else
				tap()
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, RIP_KEY)
	task.spawn(function()
		OpeningCards.build(pulls)
		if gen == generation then
			built = true
		end
	end)
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or input.KeyCode ~= RIP_KEY or flow ~= nil then
		return
	end
	if ripButton.Visible then
		onRip()
	end
end

-- Death, a respawn or a fight starting closes the opening (the camera goes back to the player)
local function watchCharacter(character: Model)
	if flow then
		close()
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			if flow then
				close()
			end
		end)
	end
end

function PackOpeningController.Start()
	-- An orange tile in the bottom row while carrying a box of packs
	ripButton = Hud.tile({ id = "Rip", icon = "Pack", label = "Rip", key = "T", group = "Context", order = 21, onClick = onRip })
	OpeningResults.build({ press = onPress, continue = close, another = openAnother, rarityGuide = openRarityGuide })
	OpeningStage.build()
	refreshRipButton()

	player:GetAttributeChangedSignal("CarryProductId"):Connect(refreshRipButton)
	player:GetAttributeChangedSignal("CarryUnits"):Connect(refreshRipButton)
	player:GetAttributeChangedSignal("PityLegendary"):Connect(refreshPity)
	player:GetAttributeChangedSignal("PityEpic"):Connect(refreshPity)
	refreshPity()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)
	Remotes.PackOpened.OnClientEvent:Connect(onPackOpened)
	Remotes.ItemsChanged.OnClientEvent:Connect(function(items: unknown)
		if typeof(items) == "table" then
			bagItems = items :: { [string]: number }
		end
	end)
	Remotes.BattleStarted.OnClientEvent:Connect(function()
		if flow then
			close()
		end
	end)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
end

return PackOpeningController
