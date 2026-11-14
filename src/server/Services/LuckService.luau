--!strict
-- Luck bought with Robux (owner 2026-11-14: "LUCK BOOSTER for ROBUX"; Config/Luck, Util/BoughtLuck): the Store's three
-- products add time to their strength, the strongest runs and raises your own packs' last card (PackService
-- .SetBoughtLuck, on top of Pish's Luck). Its time runs down only while you play, in every place; saved as data.luck
-- (seconds left per strength). The client reads the attributes BoughtLuck (the strength running, "" for none),
-- BoughtLuckUntil (the server time it runs out at), BoughtLuckLength (its time when it started, for the chip's ring)
-- and BoughtLuckWaiting (seconds of the other strength waiting its turn). While it runs a lucky aura shows on the
-- character for everyone (Luck.AURA: clovers floating up, golden glints, a glow; rainbow for 3x Super Luck).
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Luck = require(Shared:WaitForChild("Config"):WaitForChild("Luck"))
local BoughtLuck = require(Shared:WaitForChild("Util"):WaitForChild("BoughtLuck"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
local PurchaseService = require(Services:WaitForChild("PurchaseService"))
local PackService = require(Services:WaitForChild("PackService"))
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData

local LuckService = {}

local states: { [Player]: BoughtLuck.State } = {}
local running: { [Player]: string } = {} -- the strength last shown ("" for none)
local respawns: { [Player]: RBXScriptConnection } = {} -- re-dresses a new character in the running aura

local AURA_PREFIX = "LuckAura" -- its emitters on the HumanoidRootPart

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- Colours over a particle's life (the rainbow clovers run through them)
local function sequence(list: { { number } }): ColorSequence
	if #list == 1 then
		return ColorSequence.new(rgb(list[1]))
	end
	local keys = {}
	for index, values in list do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#list - 1), rgb(values)))
	end
	return ColorSequence.new(keys)
end

local function numbers(points: { { number } }): NumberSequence
	local keys = {}
	for _, point in points do
		table.insert(keys, NumberSequenceKeypoint.new(point[1], point[2]))
	end
	return NumberSequence.new(keys)
end

-- An emitter on the body's surface, its particles floating out and up
local function emitter(root: BasePart, name: string, texture: string, color: ColorSequence): ParticleEmitter
	local made = Instance.new("ParticleEmitter")
	made.Name = AURA_PREFIX .. name
	made.Texture = texture
	made.Color = color
	made.LightInfluence = 0
	made.Shape = Enum.ParticleEmitterShape.Box
	made.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	made.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	made.Parent = root
	return made
end

-- The running strength's lucky aura on a character (nil: none): four-leaf clovers floating up off the body, golden
-- glints and a soft glow (Luck.AURA)
local function dressAura(character: Model?, strength: string?)
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	for _, child in root:GetChildren() do
		if string.sub(child.Name, 1, #AURA_PREFIX) == AURA_PREFIX then
			child:Destroy()
		end
	end
	local cfg = Luck.AURA
	local look = if strength then cfg[strength] else nil
	if not look then
		return
	end
	local clovers = emitter(root, "Clovers", cfg.CLOVER, sequence(look.clovers))
	clovers.LightEmission = 0.2
	clovers.Size = numbers({ { 0, 0 }, { 0.15, cfg.CLOVER_SIZE }, { 0.8, cfg.CLOVER_SIZE * 0.9 }, { 1, 0 } })
	clovers.Transparency = numbers({ { 0, 0.2 }, { 0.7, 0.1 }, { 1, 1 } })
	clovers.Lifetime = NumberRange.new(1.8, 2.4)
	clovers.Rate = look.rate
	clovers.Speed = NumberRange.new(0.6, 1.2) -- they hang round the body as they drift up
	clovers.Drag = 0.6
	clovers.Acceleration = Vector3.new(0, 1.3, 0)
	clovers.Rotation = NumberRange.new(0, 360)
	clovers.RotSpeed = NumberRange.new(-80, 80)
	local glints = emitter(root, "Glints", cfg.SPARKLE, ColorSequence.new(rgb(look.glints)))
	glints.LightEmission = 0.5
	glints.Size = numbers({ { 0, 0.2 }, { 0.4, 0.4 }, { 1, 0 } })
	glints.Lifetime = NumberRange.new(0.8, 1.2)
	glints.Rate = cfg.GLINT_RATE
	glints.Speed = NumberRange.new(0.8, 1.6)
	glints.Acceleration = Vector3.new(0, 1.5, 0)
	local glow = Instance.new("ParticleEmitter")
	glow.Name = AURA_PREFIX .. "Glow"
	glow.Texture = cfg.GLOW
	glow.Color = ColorSequence.new(rgb(look.glow))
	glow.LightEmission = 1
	glow.LightInfluence = 0
	glow.LockedToPart = true
	glow.Size = numbers({ { 0, 4.5 }, { 0.5, 5.2 }, { 1, 4.5 } })
	glow.Transparency = numbers({ { 0, 1 }, { 0.5, 0.72 }, { 1, 1 } })
	glow.Lifetime = NumberRange.new(1.6, 2)
	glow.Rate = 1.5
	glow.Speed = NumberRange.new(0)
	glow.ZOffset = -1
	glow.Parent = root
end
local buyLimit = RateLimiter.new(2)

-- Shows the running strength and its time to the player, and hands its boost to their packs. `fresh`: its time changed
-- (a purchase), so its end and ring start over even if the same strength keeps running
local function publish(player: Player, fresh: boolean)
	local state = states[player]
	if not state then
		return
	end
	local strength = BoughtLuck.active(state, Luck) or ""
	local changed = strength ~= running[player]
	if not changed and not fresh then
		return
	end
	running[player] = strength
	local left = if strength ~= "" then state[strength] else 0
	player:SetAttribute("BoughtLuck", strength)
	player:SetAttribute("BoughtLuckUntil", if strength ~= "" then workspace:GetServerTimeNow() + left else 0)
	player:SetAttribute("BoughtLuckLength", left)
	local waiting = 0
	for name, seconds in state do
		if name ~= strength then
			waiting += seconds
		end
	end
	player:SetAttribute("BoughtLuckWaiting", waiting)
	PackService.SetBoughtLuck(player, BoughtLuck.boost(if strength ~= "" then strength else nil, Luck))
	if changed then
		dressAura(player.Character, if strength ~= "" then strength else nil)
	end
end

-- `seconds` more of a strength (a purchase, or the Studio /luck command); false when this player isn't loaded here
local function give(player: Player, strength: string, seconds: number): boolean
	local state = states[player]
	if not state then
		return false
	end
	states[player] = BoughtLuck.add(state, strength, seconds, Luck)
	publish(player, true)
	return true
end

-- Paid luck changes a random outcome, so it isn't sold where Roblox restricts paid random items (the client hides
-- the rows too)
local function restricted(player: Player): boolean
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	return not ok or typeof(info) ~= "table" or info.ArePaidRandomItemsRestricted == true
end

local function onBuy(player: Player, key: unknown)
	if typeof(key) ~= "string" or not Luck.PRODUCTS[key] or not buyLimit(player) then
		return
	end
	local productId = PurchaseService.ProductId(key)
	if productId == 0 or restricted(player) then
		return -- not made yet, or not sold here: the Store shows why
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end

local function load(player: Player, data: PlayerData)
	states[player] = BoughtLuck.clean(data.luck, Luck)
	publish(player, true)
	respawns[player] = player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		local strength = running[player]
		dressAura(character, if strength and strength ~= "" then strength else nil)
	end)
end

-- Nothing for a player this service never loaded, so a failed load can't wipe their luck
local function save(player: Player, data: PlayerData)
	local state = states[player]
	if state then
		data.luck = table.clone(state)
	end
end

local function unload(player: Player)
	local respawn = respawns[player]
	if respawn then
		respawn:Disconnect()
		respawns[player] = nil
	end
	states[player] = nil
	running[player] = nil
	PackService.SetBoughtLuck(player, 0)
end

-- Studio: luck as if bought (DevService /luck); 0 seconds clears both strengths
function LuckService.DevGive(player: Player, strength: string, seconds: number): boolean
	if seconds <= 0 then
		if not states[player] then
			return false
		end
		states[player] = BoughtLuck.clean(nil, Luck)
		publish(player, true)
		return true
	end
	if not give(player, strength, seconds) then
		return false
	end
	Remotes.StoreWin:FireClient(player, strength, seconds) -- the win card, as if bought
	return true
end

function LuckService.Start()
	DataService.Register({ name = "LuckService", load = load, save = save, unload = unload })
	for key, product in Luck.PRODUCTS do
		PurchaseService.OnProduct(key, function(player: Player): boolean
			if not give(player, product.strength, product.seconds) then
				return false -- not loaded here yet: Roblox asks again
			end
			Remotes.StoreWin:FireClient(player, product.strength, product.seconds) -- its win card
			return true
		end)
	end
	Remotes.BuyLuck.OnServerEvent:Connect(onBuy)
	-- The running strength's time goes down while you're here; when it runs out the next one starts
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Luck.TICK)
			local now = os.clock()
			local elapsed = now - last
			last = now
			for player, state in states do
				if BoughtLuck.active(state, Luck) then
					states[player] = BoughtLuck.tick(state, elapsed, Luck)
					publish(player, false)
				end
			end
		end
	end)
end

return LuckService
