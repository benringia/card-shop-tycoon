--!strict
-- The boss ladder (Config/Bosses, spec 2026-10-28-boss-ladder-design.md): each player's progress on every boss
-- (saved: data.bosses), the arenas' gates, the fights and their rewards. Rules (unlock, loot cooldown, soft cap,
-- over-power) are in Util/BossRules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bosses = require(Shared:WaitForChild("Config"):WaitForChild("Bosses"))
local BossRules = require(Shared:WaitForChild("Util"):WaitForChild("BossRules"))

local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))

local BossService = {}

local records: { [Player]: { [string]: BossRules.Record } } = {} -- loaded players only

function BossService.GetRecord(player: Player, bossId: string): BossRules.Record?
	local byBoss = records[player]
	return if byBoss then byBoss[bossId] else nil
end

local function load(player: Player, data: DataService.PlayerData)
	local saved = if typeof(data.bosses) == "table" then data.bosses else {}
	local byBoss: { [string]: BossRules.Record } = {}
	for _, bossId in Bosses.LADDER do
		byBoss[bossId] = BossRules.read(saved[bossId], Bosses.BOSSES[bossId].unlock == nil)
	end
	records[player] = byBoss
end

local function save(player: Player, data: DataService.PlayerData)
	local byBoss = records[player]
	if not byBoss then
		return -- never loaded: keep what's saved
	end
	local out: { [string]: any } = {}
	for bossId, record in byBoss do
		out[bossId] = table.clone(record)
	end
	data.bosses = out
end

local function unload(player: Player)
	records[player] = nil
end

function BossService.Start()
	DataService.Register({ name = "BossService", load = load, save = save, unload = unload })
end

return BossService
