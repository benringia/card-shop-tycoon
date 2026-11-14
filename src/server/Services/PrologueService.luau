--!strict
-- The prologue's fight (owner 2026-11-14: "just use the combat we already built"; spec 2026-11-14-prologue-hydra-design;
-- Config/Prologue): the real boss fight against the Prism Hydra with the best loadout, lent and never saved. The client
-- (PrologueController) plays the cinematics and asks for each part through Remotes.PrologueStep:
--   "begin":  a lair of its own in the sky (PrologueRules.arenaCentre, told back with Remotes.PrologueArena), the lent
--             weapon in hand and the lent cards in the party (CardService / PartyService / WeaponService .Lend)
--   "fight":  the first lent card comes out (owner 2026-11-15: only once the opening cinematic is over), the Hydra (its
--             marker's Prologue attribute: drawn two-headed, MonsterController) and the boss fight
--             (BattleService.StartPrologue; it ends at END_SHARE with no rewards)
--   "vanish": after the fight, the lent creature that's out goes back into its card (its card flies into the Hydra)
--   "take":   the Hydra has taken it all: the player's own loadout back (in the blackout)
-- Remotes.PrologueSeen (its end, a skip or a death) also ends a fight still on and gives everything back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Beasts = require(Config:WaitForChild("Beasts"))
local Bosses = require(Config:WaitForChild("Bosses"))
local Cards = require(Config:WaitForChild("Cards"))
local Prologue = require(Config:WaitForChild("Prologue"))
local Weapons = require(Config:WaitForChild("Weapons"))
local PrologueRules = require(Shared:WaitForChild("Util"):WaitForChild("PrologueRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local BattleService = require(Services:WaitForChild("BattleService"))
local CardService = require(Services:WaitForChild("CardService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local WeaponService = require(Services:WaitForChild("WeaponService"))
local WelcomeService = require(Services:WaitForChild("WelcomeService"))
local WildService = require(Services:WaitForChild("WildService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

local PrologueService = {}

type Session = {
	slot: number,
	centre: Vector3,
	step: "begun" | "fighting" | "fought" | "returned",
	monster: WildService.Monster?,
}

local STEP_COOLDOWN = 0.5 -- seconds between PrologueStep requests

local sessions: { [Player]: Session } = {}
local slots: { [number]: Player } = {}
local allowStep = RateLimiter.new(STEP_COOLDOWN)

local function cardIds(): { [string]: string }
	local ids: { [string]: string } = {}
	for _, card in Cards.List do
		ids[card.name] = card.id
	end
	return ids
end

-- The player's own loadout back (safe to call more than once)
local function giveBack(player: Player)
	WeaponService.EndLend(player)
	PartyService.EndLend(player)
	CardService.EndLend(player)
end

local function close(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	if slots[session.slot] == player then
		slots[session.slot] = nil
	end
	if session.monster then
		WildService.Defeat(session.monster) -- gone already after a fight; a fight that never started leaves none
	end
end

local function begin(player: Player)
	local session = sessions[player]
	if session then
		Remotes.PrologueArena:FireClient(player, session.centre) -- asked again (a lost reply): the same lair
		return
	end
	if not WelcomeService.PrologueOpen(player) or BattleService.IsFighting(player) or not CardService.IsLoaded(player) or not WeaponService.IsLoaded(player) then
		Remotes.PrologueArena:FireClient(player, nil)
		return
	end
	local beasts = PrologueRules.lentBeasts(Prologue, cardIds(), { level = Beasts.MAX_LEVEL, stars = Beasts.MAX_STARS, grade = Beasts.GRADES[#Beasts.GRADES] })
	local ids = {}
	for _, beast in beasts do
		table.insert(ids, beast.id)
	end
	CardService.Lend(player, beasts)
	if not PartyService.Lend(player, ids) then
		CardService.EndLend(player)
		Remotes.PrologueArena:FireClient(player, nil)
		return
	end
	WeaponService.Lend(player, Prologue.LOADOUT.weapon, { grade = Beasts.GRADES[#Beasts.GRADES], level = Weapons.MAX_LEVEL })
	local slot = PrologueRules.freeSlot(slots)
	local at = PrologueRules.arenaCentre(slot, Prologue)
	slots[slot] = player
	sessions[player] = { slot = slot, centre = Vector3.new(at.x, at.y, at.z), step = "begun", monster = nil }
	Remotes.PrologueArena:FireClient(player, sessions[player].centre)
end

local function startFight(player: Player, session: Session)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root or (root.Position - session.centre).Magnitude > Prologue.START_REACH then
		return -- not up in the lair (the client gives up waiting and plays on)
	end
	local boss = Bosses.BOSSES[Prologue.HYDRA.boss]
	local offset = Prologue.ARENA.hydra
	local monster = WildService.SpawnAt(session.centre + Vector3.new(offset[1], offset[2], offset[3]), boss.name, boss.level, false, Prologue.HYDRA.boss, 1)
	if not monster then
		return
	end
	monster.marker:SetAttribute("Prologue", true) -- clients draw it two-headed (MonsterController)
	session.monster = monster
	PartyService.SummonSlot(player, 1)
	if not BattleService.StartPrologue(player, monster) then
		WildService.Defeat(monster)
		session.monster = nil
		return
	end
	session.step = "fighting"
end

local function onStep(player: Player, step: unknown)
	if not allowStep(player) or typeof(step) ~= "string" then
		return
	end
	if step == "begin" then
		begin(player)
		return
	end
	local session = sessions[player]
	if not session then
		return
	end
	if step == "fight" and session.step == "begun" then
		startFight(player, session)
	elseif step == "vanish" and session.step == "fought" then
		PartyService.Recall(player)
	elseif step == "take" and session.step == "fought" then
		session.step = "returned"
		giveBack(player)
	end
end

function PrologueService.Start()
	Remotes.PrologueStep.OnServerEvent:Connect(onStep)
	BattleService.OnPrologueEnded(function(player: Player)
		local session = sessions[player]
		if session and session.step == "fighting" then
			session.step = "fought"
			session.monster = nil -- the fight's end took it
		end
	end)
	-- its end, a skip or a death: a fight still on ends, everything goes back (WelcomeService saves it as seen)
	Remotes.PrologueSeen.OnServerEvent:Connect(function(player: Player)
		if not sessions[player] then
			return
		end
		if BattleService.IsFighting(player) then
			BattleService.Withdraw(player)
		end
		giveBack(player)
		close(player)
	end)
	Players.PlayerRemoving:Connect(close) -- nothing lent is saved (each service's own save skips it)
end

return PrologueService
