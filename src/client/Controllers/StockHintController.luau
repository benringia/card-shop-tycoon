--!strict
-- The shelves that glow while you carry a box (owner 2026-11-20: "When your carrying a box. highlight the shelf with
-- the same product as you are carrying"; Util/StockHint picks them): the ones in your own shop already holding that
-- product with room left, or, when there are none, the empty ones that can take it; when no shelf takes it, your storage
-- racks with room (their StoredCount attribute, spec 2026-11-24-storage-racks-design). A gold outline that breathes
-- (Config/Stock HINT), gone the moment your hands are empty. The box in your hands is the player's CarryProductId
-- attribute (StockService); a shelf's stock is its part's ProductId and Units attributes (PlacementService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Shelves = require(Config:WaitForChild("Shelves"))
local StockConfig = require(Config:WaitForChild("Stock"))
local StockHint = require(Shared:WaitForChild("Util"):WaitForChild("StockHint"))

local StockHintController = {}

local LOOK = StockConfig.HINT
local player = Players.LocalPlayer
local lit: { [BasePart]: Highlight } = {}

-- Your own shop's shelves folder: the plot whose OwnerUserId is yours
local function myShelves(): Instance?
	local plots = workspace:FindFirstChild("Plots")
	for _, plot in if plots then plots:GetChildren() else {} do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot:FindFirstChild("Shelves")
		end
	end
	return nil
end

local function clear()
	for part, highlight in lit do
		highlight:Destroy()
		lit[part] = nil
	end
end

local function refresh()
	local carrying = player:GetAttribute("CarryProductId")
	local folder = if typeof(carrying) == "string" then myShelves() else nil
	if not folder then
		clear()
		return
	end
	local parts: { [string]: BasePart } = {}
	local shelves: { StockHint.Shelf } = {}
	local racks: { { uid: string, count: number, capacity: number } } = {}
	for _, part in folder:GetChildren() do
		local uid = part:GetAttribute("ShelfUid")
		local def = Shelves.ById[part.Name]
		if part:IsA("BasePart") and typeof(uid) == "string" and def then
			local productId, units = part:GetAttribute("ProductId"), part:GetAttribute("Units")
			parts[uid] = part
			table.insert(shelves, {
				uid = uid,
				kind = def.kind,
				capacity = def.capacity,
				units = if typeof(units) == "number" then units else 0,
				productId = if typeof(productId) == "string" then productId else nil,
				accepts = def.accepts,
			})
			if def.kind == "Storage" then
				local count = part:GetAttribute("StoredCount")
				table.insert(racks, { uid = uid, count = if typeof(count) == "number" then count else 0, capacity = def.capacity })
			end
		end
	end
	local wanted: { [BasePart]: boolean } = {}
	local shelvesLit = StockHint.pick(shelves, carrying :: string)
	for _, uid in shelvesLit do
		wanted[parts[uid]] = true
	end
	-- a box no shelf takes: your storage racks with room (spec 2026-11-24-storage-racks-design)
	for _, uid in StockHint.racks(racks, shelvesLit, carrying :: string) do
		wanted[parts[uid]] = true
	end
	for part, highlight in lit do
		if not wanted[part] or not part:IsDescendantOf(workspace) then
			highlight:Destroy()
			lit[part] = nil
		end
	end
	for part in wanted do
		if not lit[part] then
			local highlight = Instance.new("Highlight")
			highlight.Name = "StockHint"
			-- on the shelf's model (the part itself is an unseen box round it: a Highlight on it shows nothing)
			highlight.Adornee = part:FindFirstChildWhichIsA("Model") or part
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.FillColor = LOOK.color
			highlight.OutlineColor = LOOK.color
			highlight.FillTransparency = LOOK.fill
			highlight.Parent = part
			lit[part] = highlight
		end
	end
end

function StockHintController.Start()
	if workspace:GetAttribute("PlaceKind") ~= "Main" then
		return -- shops are in the main game
	end
	player:GetAttributeChangedSignal("CarryProductId"):Connect(refresh)
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		if next(lit) == nil and player:GetAttribute("CarryProductId") == nil then
			return
		end
		-- the outline breathes; the shelves are looked at again a few times a second (stocking one fills it)
		local beat = (math.sin(os.clock() * math.pi * 2 / LOOK.beat) + 1) / 2
		for _, highlight in lit do
			highlight.OutlineTransparency = LOOK.outline[1] + beat * (LOOK.outline[2] - LOOK.outline[1])
		end
		since += dt
		if since >= LOOK.check then
			since = 0
			refresh()
		end
	end)
	refresh()
end

return StockHintController
