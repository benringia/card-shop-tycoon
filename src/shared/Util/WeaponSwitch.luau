--!strict
-- The quick weapon switch (spec 2026-11-07-weapons-round2-design 6; the owner's pick A, 2026-11-07): the weapons the HUD
-- chip steps through and the step itself. Roblox-free (Lune-tested); cfg is Config/Weapons.
local WeaponSwitch = {}

local FAMILIES = { sword = 1, spear = 2, scythe = 3 }
local RARITIES = { Common = 1, Rare = 2, ["Very Rare"] = 3, Epic = 4, Legendary = 5 }

-- The weapons you can switch to: none before your first sword (`unlocked` false); otherwise the Steel Sword and every
-- owned weapon that's built, swords first, then spears, then scythes, each by rarity (Common first), then name
function WeaponSwitch.list(cfg: any, owned: { [string]: any }, unlocked: boolean): { string }
	if not unlocked then
		return {}
	end
	local weapons = {}
	for _, weapon in cfg.WEAPONS do
		if weapon.ready and (weapon.id == cfg.STARTER or owned[weapon.id] ~= nil) then
			table.insert(weapons, weapon)
		end
	end
	table.sort(weapons, function(a, b)
		local familyA, familyB = FAMILIES[a.family] or 99, FAMILIES[b.family] or 99
		if familyA ~= familyB then
			return familyA < familyB
		end
		local rarityA, rarityB = RARITIES[a.rarity] or 99, RARITIES[b.rarity] or 99
		if rarityA ~= rarityB then
			return rarityA < rarityB
		end
		return a.name < b.name
	end)
	local ids = {}
	for _, weapon in weapons do
		table.insert(ids, weapon.id)
	end
	return ids
end

-- The weapon `delta` steps from `current` in the list, wrapping round; an unknown or missing current starts at the
-- first; nil for an empty list
function WeaponSwitch.step(list: { string }, current: string?, delta: number): string?
	if #list == 0 then
		return nil
	end
	local index = if current then table.find(list, current) else nil
	if not index then
		return list[1]
	end
	return list[(index - 1 + delta) % #list + 1]
end

-- When the chip may send its next equip: now, or once `gap` seconds have passed since the last send (the server drops
-- equips inside its cooldown, so quick steps wait and send only the latest pick)
function WeaponSwitch.sendAt(now: number, lastSentAt: number?, gap: number): number
	return if lastSentAt then math.max(now, lastSentAt + gap) else now
end

-- The chip shows when there's something to switch to
function WeaponSwitch.visible(list: { string }): boolean
	return #list >= 2
end

return WeaponSwitch
