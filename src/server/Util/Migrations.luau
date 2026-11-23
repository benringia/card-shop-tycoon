--!strict
-- Save data migrations. MIGRATIONS[n] upgrades a profile from version n to n + 1.
-- Pure (no requires, no Roblox APIs) so tests/ can run it in Lune. DataService calls run().
local Migrations = {}

-- Copies rolled one by one when stacks get grades (v5); anything beyond this (corrupt data) becomes
-- the lowest grade so loading never stalls
local MAX_ROLLED_COPIES = 10000
local LOWEST_GRADE = "C" -- matches Config/Beasts DEFAULT_GRADE; this module has no requires

type Counts = { normal: number, foil: number }

local function readCount(value: any): number
	return if typeof(value) == "number" and value == value and value > 0 and value ~= math.huge then math.floor(value) else 0
end

local function isOldStack(entry: any): boolean
	return typeof(entry) == "table" and (entry.normal ~= nil or entry.foil ~= nil)
end

local function gradeStack(old: any, rollGrade: () -> string): { [string]: Counts }
	local graded: { [string]: Counts } = {}
	local function add(grade: string, side: string, amount: number)
		local counts = graded[grade] or { normal = 0, foil = 0 }
		graded[grade] = counts
		if side == "foil" then
			counts.foil += amount
		else
			counts.normal += amount
		end
	end
	for _, side in { "normal", "foil" } do
		local count = readCount(old[side])
		local rolled = math.min(count, MAX_ROLLED_COPIES)
		for _ = 1, rolled do
			add(rollGrade(), side, 1)
		end
		if count > rolled then
			add(LOWEST_GRADE, side, count - rolled)
		end
	end
	return graded
end

local function lowerStars(entry: any)
	if typeof(entry) == "table" and typeof(entry.stars) == "number" then
		entry.stars = math.max(0, entry.stars - 1)
	end
end

-- A placed thing's cells along x at its rotation (v42; DataService passes one built from Config/Shelves and the order
-- computer's size; nil when unknown)
type Footprint = (id: string, rotation: number) -> number?

local MIGRATIONS: { [number]: (data: any, rollGrade: () -> string, footprint: Footprint?) -> () } = {
	-- v2: displayed cards live on each saved shelf; the old top-level showcase list was never used
	[1] = function(data)
		data.showcase = nil
	end,
	-- v3: levelled cards live in their own table; existing cards are plain stacks already
	[2] = function(data)
		data.beasts = data.beasts or {}
	end,
	-- v4: stars now run 0-5 instead of 1-5, so every saved star count drops by one
	[3] = function(data)
		if typeof(data.beasts) == "table" then
			for _, beast in data.beasts do
				lowerStars(beast)
			end
		end
		if typeof(data.layout) == "table" then
			for _, shelf in data.layout do
				if typeof(shelf) == "table" and typeof(shelf.cards) == "table" then
					for _, card in shelf.cards do
						lowerStars(card)
					end
				end
			end
		end
	end,
	-- v5: every copy has a grade; plain stacks become cardId -> grade -> { normal, foil }
	[4] = function(data, rollGrade)
		if typeof(data.cards) == "table" then
			for cardId, entry in data.cards do
				if isOldStack(entry) then
					data.cards[cardId] = gradeStack(entry, rollGrade)
				end
			end
		end
		local function giveGrade(entry: any)
			if typeof(entry) == "table" and typeof(entry.cardId) == "string" and typeof(entry.grade) ~= "string" then
				entry.grade = rollGrade()
			end
		end
		if typeof(data.beasts) == "table" then
			for _, beast in data.beasts do
				giveGrade(beast)
			end
		end
		if typeof(data.layout) == "table" then
			for _, shelf in data.layout do
				if typeof(shelf) == "table" and typeof(shelf.cards) == "table" then
					for _, card in shelf.cards do
						giveGrade(card)
					end
				end
			end
		end
	end,
	-- v6: shop jobs; cards assigned to job slots
	[5] = function(data)
		data.jobs = data.jobs or {}
	end,
	-- v7: party of 3 cards (slot keys "1".."3") and which slot is summoned
	[6] = function(data)
		if typeof(data.party) ~= "table" then
			data.party = { slots = {} }
		elseif typeof(data.party.slots) ~= "table" then
			data.party.slots = {}
		end
	end,
	-- v8: fainted cards resting until a Unix time (battles)
	[7] = function(data)
		if typeof(data.resting) ~= "table" then
			data.resting = {}
		end
	end,
	-- v9: PvP record (battles part 2)
	[8] = function(data)
		if typeof(data.pvp) ~= "table" then
			data.pvp = { wins = 0, losses = 0, draws = 0 }
		end
	end,
	-- v10: item inventory (Star Shards first)
	[9] = function(data)
		if typeof(data.items) ~= "table" then
			data.items = {}
		end
	end,
	-- v11: pack pity counts (packs since the last Legendary, and since the last Epic or better), from zero
	[10] = function(data)
		if typeof(data.pity) ~= "table" then
			data.pity = { legendary = 0, epic = 0, firstDone = false }
		end
	end,
	-- v12: boss ladder progress, per boss (BossService)
	[11] = function(data)
		if typeof(data.bosses) ~= "table" then
			data.bosses = {}
		end
	end,
	-- v13: the first-visit welcome cinematic (WelcomeService). Everyone who played before it has seen the town, so it
	-- doesn't play for them; set even if Reconcile already added false
	[12] = function(data)
		data.seenWelcome = true
	end,
	-- v14: the first-sword popup (SwordService). Everyone, old players too, sees it once; a bad value starts over
	[13] = function(data)
		if typeof(data.seenSword) ~= "boolean" then
			data.seenSword = false
		end
	end,
	-- v15: boss fights fought with the sword HUD (SwordService), so its buttons show their names for the first few.
	-- Everyone starts at 0; a saved whole count stays, anything else starts over
	[14] = function(data)
		local count = data.swordFights
		local whole = typeof(count) == "number" and count >= 0 and count < math.huge and count == math.floor(count)
		if not whole then
			data.swordFights = 0
		end
	end,
	-- v16: weapons (WeaponService): an empty Armory and the Steel Sword equipped; anything else starts over
	[15] = function(data)
		if typeof(data.weapons) ~= "table" then
			data.weapons = {}
		end
		if typeof(data.equippedWeapon) ~= "string" then
			data.equippedWeapon = "starterSword"
		end
	end,
	-- v17: the tutorial with Pish (TutorialService): shops from before it never go through the first visit (their
	-- first pack counts as given), Pish's gift still comes if they replay it, no lessons seen yet
	[16] = function(data)
		data.tutorial = {
			firstVisit = "done",
			step = 1,
			early = {},
			firstGiven = true,
			giftClaimed = false,
			customerSent = true, -- their shop already has customers: a replay brings none for free
			lessons = {},
			pishLuckAt = 0,
		}
	end,
	-- v18: Chikin's combat tutorial (CombatTutorialService), the same table as Pish's: shops past Pish's first visit
	-- already fight, so it's done for them; a new player still on Pish's tour gets Chikin after it
	[17] = function(data)
		local pish = if typeof(data.tutorial) == "table" then data.tutorial.firstVisit else nil
		data.combat = {
			firstVisit = if pish == "todo" then "todo" else "done",
			step = 1,
			early = {},
			firstGiven = false,
			giftClaimed = false,
			customerSent = false,
			lessons = {},
			pishLuckAt = 0,
		}
	end,
	-- v19: the Dungeon's secret chest (spec 2026-11-11-dungeon-puzzles): whether this player ever found it (its first
	-- find gives the title Crystal Seeker; BossService) and whether they saw the Hydra's full welcome (2026-11-12)
	[18] = function(data)
		local saved = if typeof(data.dungeon) == "table" then data.dungeon else nil
		data.dungeon = { secretFound = saved ~= nil and saved.secretFound == true, seenIntro = saved ~= nil and saved.seenIntro == true }
	end,
	-- v20 (2026-11-12): the title the player picked to show over their name ("" = automatic; TitleService, Config/Titles)
	[19] = function(data)
		data.title = if typeof(data.title) == "string" then data.title else ""
	end,
	-- v21 (spec 2026-11-12-timed-upgrades-revive-design): station jobs (UpgradeJobService), unused "Finish now" skips and
	-- the last receipts granted (PurchaseService); a good skip count kept, junk replaced
	[20] = function(data)
		data.upgrades = if typeof(data.upgrades) == "table" then data.upgrades else {}
		local tokens = if typeof(data.skipTokens) == "table" then data.skipTokens else {}
		local clean = {}
		for _, tier in { "S", "M", "L" } do
			local count = tokens[tier]
			clean[tier] = if typeof(count) == "number" and count >= 0 then math.floor(count) else 0
		end
		data.skipTokens = clean
		data.purchases = if typeof(data.purchases) == "table" then data.purchases else {}
	end,
	-- "Support the dev" (owner 2026-11-12): gifts given and the best tier (SupportService)
	[21] = function(data)
		local support = if typeof(data.support) == "table" then data.support else {}
		local function count(value: any): number
			return if typeof(value) == "number" and value >= 0 then math.floor(value) else 0
		end
		data.support = { gifts = count(support.gifts), best = count(support.best) }
	end,
	-- Titles stay earned once earned (owner 2026-11-13: more titles, told when earned; TitleService): `known` ever
	-- earned and told, `fresh` not seen in the Titles tab yet; `seeded` once the first load counted what's earned already
	[22] = function(data)
		local titles = if typeof(data.titles) == "table" then data.titles else {}
		local function names(list: any): { string }
			local clean = {}
			if typeof(list) == "table" then
				for _, id in list do
					if typeof(id) == "string" then
						table.insert(clean, id)
					end
				end
			end
			return clean
		end
		data.titles = { known = names(titles.known), fresh = names(titles.fresh), seeded = titles.seeded == true }
	end,
	-- Turts' rug shop (spec 2026-11-13-turts-shop-design): the restock a player last saw, the offers they bought in it,
	-- and a "restock now" roll (TurtsService; Util/TurtsRules.State)
	[23] = function(data)
		local turts = if typeof(data.turts) == "table" then data.turts else {}
		local function ids(list: any): { string }
			local clean = {}
			if typeof(list) == "table" then
				for _, id in list do
					if typeof(id) == "string" then
						table.insert(clean, id)
					end
				end
			end
			return clean
		end
		local personal = turts.personal
		local keep = typeof(personal) == "table" and typeof(personal.index) == "number" and typeof(personal.offers) == "table"
		data.turts = {
			index = if typeof(turts.index) == "number" then turts.index else 0,
			bought = ids(turts.bought),
			personal = if keep then { index = personal.index, offers = ids(personal.offers) } else nil,
		}
	end,
	-- Shop decor (spec 2026-11-14-shop-decor-design): the look in use and the looks bought; ids are checked against
	-- Config/Decor on load (DecorRules.clean)
	[24] = function(data)
		local decor = if typeof(data.decor) == "table" then data.decor else {}
		local owned = {}
		if typeof(decor.owned) == "table" then
			for _, id in decor.owned do
				if typeof(id) == "string" then
					table.insert(owned, id)
				end
			end
		end
		data.decor = { look = if typeof(decor.look) == "string" then decor.look else "CozyWood", owned = owned }
	end,
	-- 25 -> 26: shop windows (spec 2026-11-14-shop-windows-design): none yet; a saved list stays for WindowService to
	-- clean on load (Util/WindowRules.clean pays back what no longer fits)
	[25] = function(data)
		if typeof(data.windows) ~= "table" then
			data.windows = {}
		end
	end,
	-- 26 -> 27: luck bought with Robux (Config/Luck): seconds left per strength, none yet; a saved one stays for
	-- LuckService to clean (Util/BoughtLuck.clean)
	[26] = function(data)
		if typeof(data.luck) ~= "table" then
			data.luck = { x2 = 0, x3 = 0 }
		end
	end,
	-- 27 -> 28: one-time unlocks bought as developer products (Config/Monetization UNLOCKS: the Extra Job Slot), none yet;
	-- a saved list stays for MonetizationService to clean (Util/UnlockRules.clean)
	[27] = function(data)
		if typeof(data.unlocks) ~= "table" then
			data.unlocks = {}
		end
	end,
	-- 28 -> 29: the prologue (spec 2026-11-14-prologue-hydra-design): every save from before it counts it as seen, so
	-- only new players (the template's false) play it
	[28] = function(data)
		if typeof(data.seenPrologue) ~= "boolean" then
			data.seenPrologue = true
		end
	end,
	-- 29 -> 30: daily, weekly and monthly gifts (spec 2026-11-15-daily-gifts-design): the round at day 1, nothing played
	-- or earned (Util/GiftRules.fresh); a saved table stays for GiftService to clean (Util/GiftRules.clean)
	[29] = function(data)
		if typeof(data.gifts) ~= "table" then
			data.gifts = {
				streak = 0,
				lastDay = -1,
				playDay = -1,
				played = 0,
				week = -1,
				weekDays = 0,
				weekEarned = false,
				month = -1,
				monthDays = 0,
				monthEarned = false,
				claims = 0,
			}
		end
	end,
	-- 30 -> 31: Chikin's tour reordered (owner 2026-11-16: the sword and a fight with it in his first visit; Config/Chikin
	-- STEPS): a tour in progress keeps its place by step name (old level4, sword, wild2, fight2, boss: 7-11). The old
	-- sword fight goes back to the Wild step (done at once there), then the boss
	[30] = function(data)
		local combat = data.combat
		if typeof(combat) ~= "table" or (combat.firstVisit ~= nil and combat.firstVisit ~= "todo") then
			return
		end
		local moved = ({ [7] = 9, [8] = 10, [9] = 11, [10] = 11, [11] = 12 } :: { [number]: number })[combat.step]
		if moved then
			combat.step = moved
		end
	end,
	-- 31 -> 32: tips shown the first few times (owner 2026-11-17: "make sure players know you can put packs in the bag";
	-- Config/Tips): none seen yet; a saved table stays for TipService to clean (TipRules.clean)
	[31] = function(data)
		if typeof(data.tips) ~= "table" then
			data.tips = {}
		end
	end,
	-- 32 -> 33: daily quests and welcome-back earnings (owner 2026-11-17: "yes do the three now"): no quests rolled yet
	-- (QuestService rolls today's; QuestRules.clean keeps a saved table safe) and no last-seen time (OfflineService: the
	-- first visit after the update earns nothing away)
	[32] = function(data)
		if typeof(data.quests) ~= "table" then
			data.quests = { day = -1, list = {}, bonus = false }
		end
		if typeof(data.lastSeen) ~= "number" then
			data.lastSeen = 0
		end
	end,
	-- 33 -> 34: weekly quests (owner 2026-11-17: "what players do after daily quests?"): no week rolled yet (QuestService
	-- rolls this week's; QuestRules.cleanWeek keeps a saved table safe)
	[33] = function(data)
		if typeof(data.weekly) ~= "table" then
			data.weekly = { week = -1, list = {}, chest = false }
		end
	end,
	-- Pish's tour gained "summonPal" after his present (owner 2026-11-17): a saved step past it moves one on, so it names
	-- the same step (junk is left for TutorialRules.read)
	[34] = function(data)
		local tutorial = data.tutorial
		if typeof(tutorial) == "table" and typeof(tutorial.step) == "number" and tutorial.step >= 2 then
			tutorial.step += 1
		end
	end,
	-- 35 -> 36: main quests (owner 2026-11-18, look A): no first builds paid yet (MainQuestService; a saved list is kept
	-- for MainQuestRules.clean)
	[35] = function(data)
		if typeof(data.mainQuests) ~= "table" then
			data.mainQuests = {}
		end
	end,
	-- 36 -> 37: weekly events (owner 2026-11-19): Lucky Sunday's free luck never given yet (EventService; a saved table
	-- is kept for EventRules.clean)
	[36] = function(data)
		if typeof(data.events) ~= "table" then
			data.events = { luckDay = -1 }
		end
	end,
	-- 37 -> 38: codes (owner 2026-11-19): no code used yet (CodeService; a saved list is kept for CodeRules.clean)
	[37] = function(data)
		if typeof(data.codes) ~= "table" then
			data.codes = {}
		end
	end,
	-- 38 -> 39: posters are decor in `windows` now (Config/Windows poster styles, owner 2026-11-19): the fixed front
	-- spots' `posters` list, built and dropped the same day and never released, goes
	[38] = function(data)
		data.posters = nil
	end,
	-- 39 -> 40: shop levels past 20 cost more XP (owner 2026-11-20: "after level 20. make the leveling up more
	-- difficult"; Config/Levels LATE). A saved XP total past Lv 20 moves onto the new curve at the same level and the
	-- same share of the way to the next, so nobody loses a level; XP past the cap is kept past the new cap. Both
	-- curves are written out here (this module has no requires, and a migration must not move with the config).
	[39] = function(data)
		local xp = data.xp
		if typeof(xp) ~= "number" or xp ~= xp or xp == math.huge or xp < 0 then
			return -- junk is left for the loader
		end
		local BASE, POWER, ROUND, MAX = 40 / 6, 2.31, 10, 100
		local FROM, FULL, TIMES = 20, 30, 3
		local before: { number }, after: { number } = {}, {}
		local raw, last = 0, 0
		for level = 1, MAX do
			local plain = if level <= 1 then 0 else BASE * (level - 1) ^ POWER
			if level > FROM then
				raw += (plain - last) * (1 + (TIMES - 1) * math.clamp((level - FROM) / (FULL - FROM), 0, 1))
			else
				raw = plain
			end
			last = plain
			before[level] = math.round(plain / ROUND) * ROUND
			after[level] = math.round(raw / ROUND) * ROUND
		end
		local level = 1
		while level < MAX and xp >= before[level + 1] do
			level += 1
		end
		if level <= FROM then
			return
		elseif level >= MAX then
			data.xp = after[MAX] + math.floor(xp - before[MAX])
			return
		end
		local share = (xp - before[level]) / (before[level + 1] - before[level])
		-- never onto the next level's floor: a level is earned, not rounded into
		data.xp = math.min(after[level] + math.floor((after[level + 1] - after[level]) * share), after[level + 1] - 1)
	end,
	-- v41 (owner 2026-11-21: a boss kills leaderboard): the lifetime counter stats.bossKills. Kills before it were
	-- never counted, so a save starts at the bosses it has beaten at least once (data.bosses[id].cleared)
	[40] = function(data)
		local stats = data.stats
		if typeof(stats) ~= "table" or typeof(stats.bossKills) == "number" then
			return
		end
		local kills = 0
		if typeof(data.bosses) == "table" then
			for _, record in data.bosses do
				if typeof(record) == "table" and record.cleared == true then
					kills += 1
				end
			end
		end
		stats.bossKills = kills
	end,
	-- v42 (spec 2026-11-23-shop-rooms-design): every shop became one 50 x 60 building: its hall 5 studs wider each side
	-- (20 -> 25 cells across), the floor's middle 10 studs further back, nothing moved away from the street (gridZ and
	-- the hall's depth are the same). Rooms start closed. A thing by a side wall (its edge within 2 cells, 4 studs) stays
	-- by it; the rest keep their place from the middle line to the whole cell (+3: half a cell right of centred, away
	-- from the register by the left wall). Side windows keep their spot (`at` counts from the wall's middle, now 10
	-- further back); front posters stay on the same pane of the wider front (outer +-18.5 -> +-(6 + 2.5 * 20 / 3), inner
	-- +-13.5 -> +-16); back pieces are left for the load (WindowRules.clean moves what no longer fits). `footprint`
	-- gives a thing's cells along x, 1 when unknown. Numbers frozen here, as every step's.
	[41] = function(data, _rollGrade, footprint)
		if typeof(data.rooms) ~= "table" then
			data.rooms = {}
		end
		local OLD_CELLS, NEAR, RIGHT, MIDDLE = 20, 2, 5, 3
		local function remap(entry: any, id: string)
			if typeof(entry) ~= "table" or typeof(entry.gridX) ~= "number" or entry.gridX ~= math.floor(entry.gridX) then
				return
			end
			local rotation = if typeof(entry.rotation) == "number" then entry.rotation else 0
			local w = (if footprint then footprint(id, rotation) else nil) or 1
			if entry.gridX <= NEAR then
				return
			elseif entry.gridX + w >= OLD_CELLS - NEAR then
				entry.gridX += RIGHT
			else
				entry.gridX += MIDDLE
			end
		end
		if typeof(data.layout) == "table" then
			for _, entry in data.layout do
				if typeof(entry) == "table" and typeof(entry.shelfId) == "string" then
					remap(entry, entry.shelfId)
				end
			end
		end
		if typeof(data.fixtures) == "table" then
			remap(data.fixtures.OrderComputer, "OrderComputer")
		end
		if typeof(data.windows) == "table" then
			local OUTER_OLD, INNER_OLD = 18.5, 13.5
			local OUTER_NEW, INNER_NEW = 6 + 2.5 * 20 / 3, 16
			for _, window in data.windows do
				if typeof(window) == "table" and typeof(window.at) == "number" then
					if window.side == "left" or window.side == "right" then
						window.at -= 10
					elseif window.side == "front" then
						local sign = if window.at < 0 then -1 else 1
						if math.abs(math.abs(window.at) - OUTER_OLD) < 1e-3 then
							window.at = sign * OUTER_NEW
						elseif math.abs(math.abs(window.at) - INNER_OLD) < 1e-3 then
							window.at = sign * INNER_NEW
						end
					end
				end
			end
		end
	end,
}

local function lowestGrade(): string
	return LOWEST_GRADE
end

-- rollGrade gives each copy its grade in v5 (the server passes a random roll; tests pass a fixed one); footprint gives a
-- placed thing's cells along x in v42 (DataService builds it from the shelf sizes)
function Migrations.run(data: any, targetVersion: number, rollGrade: (() -> string)?, footprint: Footprint?)
	local version = if typeof(data.version) == "number" then data.version else 1
	-- A save written by newer code (e.g. an old server still running during an update) keeps its
	-- version, so the newer code never runs the same migration on it twice
	if version >= targetVersion then
		return
	end
	while version < targetVersion do
		local step = MIGRATIONS[version]
		if step then
			step(data, rollGrade or lowestGrade, footprint)
		end
		version += 1
	end
	data.version = targetVersion
end

return Migrations
