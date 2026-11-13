--!strict
-- Shop decor's looks (spec docs/superpowers/specs/2026-11-14-shop-decor-design.md): each player's look in use and the
-- looks they bought (saved `decor`), bought and switched from the Shop menu's Decor tab (remote ShopLook), drawn
-- inside their shop by PlotService.SetLook. The owner's client reads the attributes ShopLook (the look in use) and
-- ShopLooksOwned (bought ids joined by commas). The placeable pieces are shelves (PlacementService, kind "Decor").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Decor = require(Shared:WaitForChild("Config"):WaitForChild("Decor"))
local DecorRules = require(Shared:WaitForChild("Util"):WaitForChild("DecorRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local Blocked = require(ServerUtil:WaitForChild("Blocked"))
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))

local DecorService = {}

local states: { [Player]: DecorRules.State } = {}
local lookLimit = RateLimiter.new(0.5)

-- The look drawn in the player's shop, and the attributes their Decor tab reads
local function apply(player: Player, state: DecorRules.State)
	local plot = PlotService.GetPlot(player)
	if plot then
		PlotService.SetLook(plot, DecorRules.look(Decor, state.look))
	end
	player:SetAttribute("ShopLook", state.look)
	player:SetAttribute("ShopLooksOwned", table.concat(state.owned, ","))
end

local function onShopLook(player: Player, action: unknown, lookId: unknown)
	if typeof(action) ~= "string" or typeof(lookId) ~= "string" or not lookLimit(player) then
		return
	end
	local state = states[player]
	if not state then
		return
	end
	if action == "buy" then
		local ok, reason = DecorRules.canBuy(Decor, state, lookId, EconomyService.GetLevel(player), EconomyService.GetCash(player))
		if not ok then
			Blocked.tell(player, reason or "You can't buy that look.")
			return
		end
		local look = DecorRules.look(Decor, lookId) :: DecorRules.Look
		if not EconomyService.TrySpend(player, look.price) then
			Blocked.tell(player, `You need ${look.price} for {look.name}.`)
			return
		end
		table.insert(state.owned, lookId)
	elseif action == "use" then
		local ok, reason = DecorRules.canUse(Decor, state, lookId)
		if not ok then
			Blocked.tell(player, reason or "You can't use that look.")
			return
		end
	else
		return
	end
	state.look = lookId
	apply(player, state)
end

-- The look in use in this player's shop (the default before their save loads)
function DecorService.GetLook(player: Player): string
	local state = states[player]
	return if state then state.look else Decor.DEFAULT_LOOK
end

-- Studio's "/decor <look id>": that look owned and in use
function DecorService.SetLookForDev(player: Player, lookId: string): boolean
	local state = states[player]
	if not RunService:IsStudio() or not state or not DecorRules.look(Decor, lookId) then
		return false
	end
	if not DecorRules.owns(Decor, state, lookId) then
		table.insert(state.owned, lookId)
	end
	state.look = lookId
	apply(player, state)
	return true
end

function DecorService.Start()
	DataService.Register({
		name = "Decor",
		load = function(player, data)
			local state = DecorRules.clean(Decor, data.decor)
			states[player] = state
			apply(player, state)
		end,
		save = function(player, data)
			local state = states[player]
			if not state then
				return -- never loaded: keep what's saved
			end
			data.decor = { look = state.look, owned = table.clone(state.owned) }
		end,
		unload = function(player)
			states[player] = nil
		end,
	})
	Remotes.ShopLook.OnServerEvent:Connect(onShopLook)
end

return DecorService
