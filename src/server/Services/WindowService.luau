--!strict
-- Shop windows (spec docs/superpowers/specs/2026-11-14-shop-windows-design.md; Config/Windows, Util/WindowRules):
-- each player's windows (saved `windows`), placed, moved and sold from their shop (remotes PlaceWindow, MoveWindow,
-- SellWindow) and drawn by PlotService.SetWindows. Also keeps the player attribute DecorAchieved up to date: the
-- achievement decor they've unlocked ("window:<style>" and "shelf:<id>" joined by commas; TitleService's progress),
-- which their Decor tab reads.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Windows = require(Config:WaitForChild("Windows"))
local Shelves = require(Config:WaitForChild("Shelves"))
local WindowRules = require(Shared:WaitForChild("Util"):WaitForChild("WindowRules"))
local TitleRules = require(Shared:WaitForChild("Util"):WaitForChild("TitleRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local TitleService = require(Services:WaitForChild("TitleService"))
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local Blocked = require(ServerUtil:WaitForChild("Blocked"))
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))

local WindowService = {}

local NEAR = 60 -- studs from the shop floor's middle: placing, moving and selling only from in or by the shop

local windowsOf: { [Player]: { WindowRules.Window } } = {}
local limit = RateLimiter.new(0.4)

local function apply(player: Player)
	local plot = PlotService.GetPlot(player)
	if plot then
		PlotService.SetWindows(plot, windowsOf[player] or {})
	end
end

local function isNear(player: Player): boolean
	local plot = PlotService.GetPlot(player)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return plot ~= nil and root ~= nil and root:IsA("BasePart") and (root.Position - plot.floor.Position).Magnitude <= NEAR
end

-- The achievement decor unlocked now, as the Decor tab reads it
local function achieved(progress: TitleRules.Progress): string
	local keys = {}
	for _, id in Windows.ORDER do
		local style = Windows.STYLES[id]
		if style.needs and TitleRules.meets(style.needs, progress) then
			table.insert(keys, `window:{id}`)
		end
	end
	for _, def in Shelves.List do
		if def.needs and TitleRules.meets(def.needs, progress) then
			table.insert(keys, `shelf:{def.id}`)
		end
	end
	return table.concat(keys, ",")
end

-- A side and a spot sent by a client, if they're the right types (WindowRules says whether they fit)
local function readWindow(side: unknown, at: unknown): (string?, number?)
	if typeof(side) ~= "string" or typeof(at) ~= "number" or at ~= at or math.abs(at) > 1000 then
		return nil, nil
	end
	return side, at
end

local function onPlace(player: Player, styleId: unknown, sideIn: unknown, atIn: unknown)
	local list = windowsOf[player]
	if not list or typeof(styleId) ~= "string" or not limit(player) then
		return
	end
	local side, at = readWindow(sideIn, atIn)
	local style = Windows.STYLES[styleId]
	if not side or not at or not style then
		return
	end
	if not isNear(player) then
		Blocked.tell(player, "Walk into your shop to put in a window.")
		return
	end
	local window: WindowRules.Window = { style = styleId, side = side, at = at }
	local fits, where = WindowRules.canPlace(Windows, list, window)
	if not fits then
		Blocked.tell(player, where or "That window doesn't fit there.")
		return
	end
	local met = style.needs == nil or TitleService.Meets(player, style.needs)
	local ok, why = WindowRules.canBuy(Windows, styleId, EconomyService.GetLevel(player), EconomyService.GetCash(player), met, #list)
	if not ok then
		Blocked.tell(player, why or "You can't buy that window.")
		return
	end
	if not EconomyService.TrySpend(player, style.price) then
		Blocked.tell(player, `You need ${style.price} for {style.name}.`)
		return
	end
	table.insert(list, window)
	apply(player)
end

local function onMove(player: Player, index: unknown, sideIn: unknown, atIn: unknown)
	local list = windowsOf[player]
	if not list or typeof(index) ~= "number" or not limit(player) then
		return
	end
	local current = list[index]
	local side, at = readWindow(sideIn, atIn)
	if not current or not side or not at then
		return
	end
	if not isNear(player) then
		Blocked.tell(player, "Walk into your shop to move a window.")
		return
	end
	local moved: WindowRules.Window = { style = current.style, side = side, at = at }
	local fits, where = WindowRules.canPlace(Windows, list, moved, index)
	if not fits then
		Blocked.tell(player, where or "That window doesn't fit there.")
		return
	end
	list[index] = moved
	apply(player)
end

local function onSell(player: Player, index: unknown)
	local list = windowsOf[player]
	if not list or typeof(index) ~= "number" or not limit(player) then
		return
	end
	local window = list[index]
	if not window then
		return
	end
	if not isNear(player) then
		Blocked.tell(player, "Walk into your shop to sell a window.")
		return
	end
	table.remove(list, index)
	local style = Windows.STYLES[window.style]
	if style then
		EconomyService.AddCash(player, math.floor(style.price * Windows.SELL_REFUND))
	end
	apply(player)
end

-- Each window's points toward the shop rating's decor part (RatingService)
function WindowService.GetPoints(player: Player): { number }
	local points = {}
	for _, window in windowsOf[player] or {} do
		local style = Windows.STYLES[window.style]
		if style then
			table.insert(points, style.points)
		end
	end
	return points
end

-- Studio's "/window <style> <side> <at>": that window put in for free, wherever it fits
function WindowService.DevPlace(player: Player, styleId: string, side: string, at: number): (boolean, string?)
	local list = windowsOf[player]
	if not RunService:IsStudio() or not list then
		return false, "Not loaded."
	end
	local window: WindowRules.Window = { style = styleId, side = side, at = WindowRules.snap(Windows, at) }
	local fits, where = WindowRules.canPlace(Windows, list, window)
	if not fits then
		return false, where
	end
	table.insert(list, window)
	apply(player)
	return true, nil
end

function WindowService.Start()
	DataService.Register({
		name = "Windows",
		load = function(player, data)
			local kept, refunded = WindowRules.clean(Windows, data.windows)
			windowsOf[player] = kept
			apply(player)
			if refunded > 0 then
				-- a window that no longer fits (a changed wall or style) is paid back, never lost
				task.defer(function()
					if player.Parent then
						EconomyService.AddCash(player, refunded)
					end
				end)
			end
		end,
		save = function(player, data)
			local list = windowsOf[player]
			if not list then
				return -- never loaded: keep what's saved
			end
			local saved = {}
			for _, window in list do
				table.insert(saved, { style = window.style, side = window.side, at = window.at })
			end
			data.windows = saved
		end,
		unload = function(player)
			windowsOf[player] = nil
		end,
	})
	TitleService.OnProgress(function(player, progress)
		if player.Parent then
			player:SetAttribute("DecorAchieved", achieved(progress))
		end
	end)
	Remotes.PlaceWindow.OnServerEvent:Connect(onPlace)
	Remotes.MoveWindow.OnServerEvent:Connect(onMove)
	Remotes.SellWindow.OnServerEvent:Connect(onSell)
end

return WindowService
