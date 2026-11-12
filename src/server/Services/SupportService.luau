--!strict
-- "Support the dev" (owner 2026-11-12: "a 'Support the dev' somewhere where the supporter will receive a supporters
-- aura and title"; Config/Support, Util/SupportRules): the Support1-3 developer products (PurchaseService). A gift is
-- counted and keeps the best tier (saved data.support). The best tier is the player's SupporterTier attribute, seen in
-- every place: golden sparkles round their character (built here, on the HumanoidRootPart, so everyone sees them), the
-- supporter titles (TitleService, OnChanged) and the town dogs' thank-yous (Util/TownDog). The client's card asks for
-- the gifts and best tier (Remotes.SupportState).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Support = require(Shared:WaitForChild("Config"):WaitForChild("Support"))
local SupportRules = require(Shared:WaitForChild("Util"):WaitForChild("SupportRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local DataService = require(Services:WaitForChild("DataService"))
local PurchaseService = require(Services:WaitForChild("PurchaseService"))
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData

local SupportService = {}

local TOP = #Support.TIERS
local AURA = "SupporterAura" -- the Attachment at the chest holding the sparkles, the glow and the light
local CHEST = Vector3.new(0, 0.5, 0)

local states: { [Player]: SupportRules.State } = {} -- loaded players only
local listeners: { (player: Player) -> () } = {}
local allowAsk = RateLimiter.new(1)
local allowReveal = RateLimiter.new(0.5)
local reveals: { [Player]: () -> () } = {} -- a gift's aura, titles and toast waiting for its thank-you's glow

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function colors(list: { { number } }): ColorSequence
	if #list == 1 then
		return ColorSequence.new(rgb(list[1]))
	end
	local keys = {}
	for index, values in list do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#list - 1), rgb(values)))
	end
	return ColorSequence.new(keys)
end

-- The tier's aura on a character (0: none): golden sparkles bursting from the chest and drifting up in a soft glow,
-- tier 3 with a warm light
local function dress(character: Model?, tier: number)
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root then
		return
	end
	local old = root:FindFirstChild(AURA)
	if old then
		old:Destroy()
	end
	local look = Support.AURA[tier]
	if not look then
		return
	end
	local holder = Instance.new("Attachment")
	holder.Name = AURA
	holder.Position = CHEST
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Texture = Support.SPARKLE
	sparkles.Color = colors(look.colors)
	sparkles.LightEmission = 0.15 -- mostly painted on: additive light washes out to white in daylight
	sparkles.LightInfluence = 0
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, look.size * 0.6),
		NumberSequenceKeypoint.new(0.4, look.size),
		NumberSequenceKeypoint.new(1, look.size * 0.3),
	})
	sparkles.Lifetime = NumberRange.new(1.2, 1.6)
	sparkles.Rate = look.rate
	sparkles.Speed = NumberRange.new(2.5, 3.5) -- out of the body (slower ones stay hidden inside it)
	sparkles.Drag = 0.6
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Acceleration = Vector3.new(0, 1, 0)
	sparkles.Parent = holder
	local glow = Instance.new("ParticleEmitter")
	glow.Name = "Glow"
	glow.Texture = Support.GLOW
	glow.Color = ColorSequence.new(rgb(look.glow.color))
	glow.LightEmission = 1
	glow.LightInfluence = 0
	glow.LockedToPart = true
	glow.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, look.glow.size * 0.85),
		NumberSequenceKeypoint.new(0.5, look.glow.size),
		NumberSequenceKeypoint.new(1, look.glow.size * 0.85),
	})
	glow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	glow.Lifetime = NumberRange.new(1.6, 2)
	glow.Rate = 1.5
	glow.Speed = NumberRange.new(0)
	glow.ZOffset = -1
	glow.Parent = holder
	if look.light then
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = rgb(look.light)
		light.Range = 9
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = holder
	end
	holder.Parent = root
end

local function apply(player: Player)
	local state = states[player]
	local tier = if state then state.best else 0
	player:SetAttribute("SupporterTier", if tier > 0 then tier else nil)
	dress(player.Character, tier)
end

local function send(player: Player)
	local state = states[player]
	if state then
		Remotes.SupportState:FireClient(player, { gifts = state.gifts, best = state.best })
	end
end

-- A gift of `tier` bought (PurchaseService): counted and the best tier kept now (saved), then the thank-you: the
-- player's screen plays Pish and Chikin's thanks (Remotes.SupportThanks, ThanksController) and the aura, titles and
-- toast come as its glow ends (Support.CINEMATIC.reveal). False while their save isn't loaded (Roblox asks again).
local function grant(player: Player, tier: number): boolean
	local state = states[player]
	if not state then
		return false
	end
	local now = SupportRules.give(state, tier, TOP)
	states[player] = now
	send(player)
	local raised = now.best > state.best
	-- shown when the player's thank-you reaches its glow (they say so: Remotes.SupportThanks), or `fallback` seconds on
	local function reveal()
		if reveals[player] ~= reveal then
			return -- shown already, or a newer gift's waits instead
		end
		reveals[player] = nil
		if not states[player] then
			return -- left meanwhile: the gift is saved, the aura comes on their next join
		end
		apply(player)
		for _, listener in listeners do
			task.spawn(listener, player)
		end
		Remotes.Notify:FireClient(player, if raised then string.format(Support.THANKS, Support.TIERS[now.best].name) else Support.THANKS_AGAIN, false)
	end
	local older = reveals[player]
	if older then
		older() -- a gift still waiting: shown now
	end
	reveals[player] = reveal
	Remotes.SupportThanks:FireClient(player, { tier = now.best, raised = raised })
	task.delay(Support.CINEMATIC.fallback, reveal)
	return true
end

local function load(player: Player, data: PlayerData)
	states[player] = SupportRules.read(data.support, TOP)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		if states[player] then
			apply(player)
		end
	end)
	apply(player)
	send(player)
end

-- Nothing for a player this service never loaded, so a failed load can't wipe their gifts
local function save(player: Player, data: PlayerData)
	local state = states[player]
	if state then
		data.support = { gifts = state.gifts, best = state.best }
	end
end

local function unload(player: Player)
	states[player] = nil
	reveals[player] = nil
end

-- The best tier given (0: none, or not loaded)
function SupportService.Best(player: Player): number
	local state = states[player]
	return if state then state.best else 0
end

-- Studio's /support (DevService): a gift of `tier` as if bought, or 0: no gifts again; false while not loaded
function SupportService.SetForTest(player: Player, tier: number): boolean
	if not states[player] then
		return false
	end
	if tier >= 1 then
		return grant(player, math.min(math.floor(tier), TOP))
	end
	states[player] = { gifts = 0, best = 0 }
	apply(player)
	send(player)
	for _, listener in listeners do
		task.spawn(listener, player)
	end
	return true
end

-- Told after a gift (TitleService: the titles it earns)
function SupportService.OnChanged(listener: (player: Player) -> ())
	table.insert(listeners, listener)
end

function SupportService.Start()
	DataService.Register({ name = "SupportService", load = load, save = save, unload = unload })
	for index, tier in Support.TIERS do
		PurchaseService.OnProduct(tier.product, function(player: Player): boolean
			return grant(player, index)
		end)
	end
	Remotes.SupportThanks.OnServerEvent:Connect(function(player: Player)
		local reveal = reveals[player]
		if reveal and allowReveal(player) then
			reveal() -- their thank-you's glow has ended
		end
	end)
	Remotes.SupportState.OnServerEvent:Connect(function(player: Player)
		if allowAsk(player) then
			send(player) -- the card asking (it started listening late)
		end
	end)
end

return SupportService
