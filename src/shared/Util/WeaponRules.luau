--!strict
-- Weapons' rules (spec 2026-11-06-weapons-round1-design): Power, the element bond and wheel, perks, what making,
-- reforging and upgrading cost, paying, owning and the saved table's cleanup. Pure: the server enforces these, the
-- Forge and the Armory preview them. `cfg` is Config/Weapons, `combat` Config/Combat (passed in so Lune can test it).

export type Cost = { cash: number, items: { [string]: number }, unlockLevel: number? }
export type Perk = { kind: string, every: number?, share: number?, seconds: number? }
export type Owned = { grade: string, level: number }

local WeaponRules = {}

local function copyCost(cost: any): Cost
	local items = {}
	for id, n in cost.items do
		items[id] = n
	end
	return { cash = cost.cash, items = items, unlockLevel = cost.unlockLevel }
end

-- A ready weapon (built: forgeable and drawn), or nil
local function readyWeapon(cfg: any, weaponId: string): any
	local weapon = cfg.ById[weaponId]
	if weapon and weapon.ready then
		return weapon
	end
	return nil
end

-- The material a weapon's upgrades and reforges pay in: its boss's, Wild Ore for Forge weapons, a masterwork's main one
-- (the recipe's biggest material)
local function materialOf(cfg: any, weapon: any): string?
	local source = weapon.source
	if source.kind == "forge" then
		return cfg.WILD_ORE
	elseif source.kind == "boss" then
		return cfg.MATERIALS[source.boss]
	elseif source.kind == "masterwork" and source.cost then
		local best, most = nil, 0
		for _, material in cfg.MATERIALS do
			local n = source.cost.items[material] or 0
			if n > most or (n == most and n > 0 and best and material < best) then
				best, most = material, n
			end
		end
		return best
	end
	return nil
end

-- The material a weapon's upgrades, reforges and duplicate drops are counted in (nil: the Steel Sword, unknown ids)
function WeaponRules.material(cfg: any, weaponId: string): string?
	local weapon = cfg.ById[weaponId]
	return if weapon then materialOf(cfg, weapon) else nil
end

function WeaponRules.power(cfg: any, weaponId: string, grade: string, level: number): number
	local weapon = cfg.ById[weaponId]
	if not weapon or weapon.source.kind == "starter" then
		return cfg.STARTER_POWER
	end
	local base = weapon.power or cfg.RARITY_POWER[weapon.rarity] or cfg.STARTER_POWER
	local gradePower = cfg.GRADE_POWER[grade] or 1
	local steps = math.clamp(math.floor(level), 0, cfg.MAX_LEVEL)
	return base * gradePower * (1 + cfg.UPGRADE_STEP * steps)
end

-- The element strong against this one on the wheel (combat.BEATS), nil if none is
function WeaponRules.strongAgainst(combat: any, element: string?): string?
	if not element then
		return nil
	end
	for strong, beats in combat.BEATS do
		if table.find(beats, element) then
			return strong
		end
	end
	return nil
end

-- The element a weapon's hit counts as on the wheel: the Prism Blade picks the one strong against the foe, a plain
-- weapon its own, the Steel Sword none
function WeaponRules.hitElement(cfg: any, weaponId: string, foeElement: string?, combat: any): string?
	local weapon = cfg.ById[weaponId]
	if not weapon then
		return nil
	end
	return if weapon.prism then WeaponRules.strongAgainst(combat, foeElement) else weapon.element
end

-- The summoned creature sharing the weapon's element (the Prism Blade: any): (damage, meter) multipliers
function WeaponRules.bond(cfg: any, weaponId: string, creatureElement: string?): (number, number)
	local weapon = cfg.ById[weaponId]
	if not weapon or not creatureElement then
		return 1, 1
	end
	if weapon.prism or (weapon.element ~= nil and weapon.element == creatureElement) then
		return cfg.BOND.damage, cfg.BOND.meter
	end
	return 1, 1
end

-- A weapon's perk at a grade (a copy; Grade S: its share x PERK_S)
function WeaponRules.perk(cfg: any, weaponId: string, grade: string): Perk?
	local weapon = cfg.ById[weaponId]
	if not weapon or not weapon.perk then
		return nil
	end
	local perk = weapon.perk
	local share = perk.share
	if share and grade == "S" then
		share *= cfg.PERK_S
	end
	return { kind = perk.kind, every = perk.every, share = share, seconds = perk.seconds }
end

-- What making a weapon costs: the Forge's price, a boss weapon's by its rarity, a masterwork's recipe; nil for the
-- Steel Sword and weapons not built yet
function WeaponRules.makeCost(cfg: any, weaponId: string): Cost?
	local weapon = readyWeapon(cfg, weaponId)
	if not weapon then
		return nil
	end
	local source = weapon.source
	if source.kind == "boss" then
		local byRarity = cfg.BOSS_COST[weapon.rarity]
		local material = cfg.MATERIALS[source.boss]
		if not byRarity or not material then
			return nil
		end
		return { cash = byRarity.cash, items = { [material] = byRarity.material } }
	elseif (source.kind == "forge" or source.kind == "masterwork") and source.cost then
		return copyCost(source.cost)
	end
	return nil
end

-- A reforge (a new grade roll): REFORGE_SHARE of making it, each number rounded up
function WeaponRules.reforgeCost(cfg: any, weaponId: string): Cost?
	local cost = WeaponRules.makeCost(cfg, weaponId)
	if not cost then
		return nil
	end
	local items = {}
	for id, n in cost.items do
		items[id] = math.ceil(n * cfg.REFORGE_SHARE)
	end
	return { cash = math.ceil(cost.cash * cfg.REFORGE_SHARE), items = items }
end

-- Upgrading to `toLevel` (1..MAX_LEVEL): cash x the rarity's share, the weapon's material, Star Shards at +5 and +10;
-- nil for the Steel Sword, weapons not built yet and levels out of range
function WeaponRules.upgradeCost(cfg: any, weaponId: string, toLevel: number): Cost?
	local weapon = readyWeapon(cfg, weaponId)
	if not weapon or toLevel < 1 or toLevel > cfg.MAX_LEVEL or toLevel ~= math.floor(toLevel) then
		return nil
	end
	local material = materialOf(cfg, weapon)
	local share = cfg.UPGRADE.rarityCash[weapon.rarity]
	if not material or not share then
		return nil
	end
	local items = { [material] = cfg.UPGRADE.material[toLevel] }
	local shards = cfg.UPGRADE.starShards[toLevel]
	if shards then
		items.starShard = shards
	end
	return { cash = math.round(cfg.UPGRADE.cash[toLevel] * share), items = items }
end

-- Progress toward making a weapon (the Armory's locked cards): its main material, have (capped at the need) and need;
-- nil for the Steel Sword and weapons not built yet
function WeaponRules.makeProgress(cfg: any, weaponId: string, items: { [string]: number }): (number?, number?)
	local cost = WeaponRules.makeCost(cfg, weaponId)
	local material = WeaponRules.material(cfg, weaponId)
	local need = if cost and material then cost.items[material] else nil
	if not need or need <= 0 then
		return nil, nil
	end
	return math.min(items[material :: string] or 0, need), need
end

-- What a material is for next (the loot toast's "9/15"): the first built weapon, in the Armory's order, that still
-- needs it: making it (a boss weapon, a Forge weapon, a masterwork's recipe) when not owned, else its next upgrade.
-- Returns that weapon and how many it needs, or nil when nothing does.
function WeaponRules.materialGoal(cfg: any, material: string, owned: { [string]: Owned }): (string?, number?)
	for _, weapon in cfg.WEAPONS do
		if not weapon.ready then
			continue
		end
		local have = owned[weapon.id]
		local cost = if have
			then (if have.level < cfg.MAX_LEVEL then WeaponRules.upgradeCost(cfg, weapon.id, have.level + 1) else nil)
			else WeaponRules.makeCost(cfg, weapon.id)
		local need = if cost then cost.items[material] else nil
		if need and need > 0 then
			return weapon.id, need
		end
	end
	return nil, nil
end

-- Whether the cash and items cover a cost: all or nothing; the reason names the first thing missing ("cash" or an
-- item id, in id order so it's always the same one)
function WeaponRules.pay(cost: Cost, cash: number, items: { [string]: number }): (boolean, string?)
	if cash < cost.cash then
		return false, "cash"
	end
	local ids = {}
	for id in cost.items do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		if (items[id] or 0) < cost.items[id] then
			return false, id
		end
	end
	return true, nil
end

-- Getting a weapon: the new record (nil when nothing changes) and the material refund. A drop you already own gives
-- DUPLICATE_MATERIAL of its material instead; a forge or reforge of an owned one keeps the better grade and the level.
function WeaponRules.give(
	owned: { [string]: Owned },
	weaponId: string,
	grade: string,
	how: "forge" | "reforge" | "drop",
	cfg: any
): (Owned?, number)
	local have = owned[weaponId]
	if not have then
		return { grade = grade, level = 0 }, 0
	end
	if how == "drop" then
		return nil, cfg.DUPLICATE_MATERIAL
	end
	if (cfg.GRADE_POWER[grade] or 0) > (cfg.GRADE_POWER[have.grade] or 0) then
		return { grade = grade, level = have.level }, 0
	end
	return nil, 0
end

-- A boss's chance to drop its weapon after `pity` full-loot kills without one
function WeaponRules.dropChance(cfg: any, pity: number): number
	return math.min(1, cfg.DROP.base + cfg.DROP.step * math.max(0, pity))
end

-- Cleans a saved weapons table: unknown ids dropped (and named, to log), bad grades to C, levels whole and in range;
-- the equipped id kept only if it's owned and built, otherwise the Steel Sword
function WeaponRules.read(cfg: any, saved: unknown, equipped: unknown): ({ [string]: Owned }, string, { string })
	local owned: { [string]: Owned } = {}
	local dropped: { string } = {}
	if typeof(saved) == "table" then
		for id, record in saved :: { [any]: any } do
			if typeof(id) ~= "string" or not cfg.ById[id] or typeof(record) ~= "table" then
				table.insert(dropped, tostring(id))
				continue
			end
			local grade = if typeof(record.grade) == "string" and cfg.GRADE_POWER[record.grade] then record.grade else "C"
			local level = if typeof(record.level) == "number" and record.level == record.level then record.level else 0
			owned[id] = { grade = grade, level = math.clamp(math.floor(level), 0, cfg.MAX_LEVEL) }
		end
	end
	table.sort(dropped)
	local equip = cfg.STARTER
	if typeof(equipped) == "string" and owned[equipped] and cfg.ById[equipped].ready then
		equip = equipped
	end
	return owned, equip, dropped
end

-- Whether a weapon can be made at this shop level (Forge weapons wait for FORGE_UNLOCK_LEVEL; not-built ones never)
function WeaponRules.unlocked(cfg: any, weaponId: string, shopLevel: number): boolean
	local weapon = readyWeapon(cfg, weaponId)
	if not weapon then
		return false
	end
	local cost = weapon.source.cost
	local level = if cost and cost.unlockLevel then cost.unlockLevel else 0
	return shopLevel >= level
end

return WeaponRules
