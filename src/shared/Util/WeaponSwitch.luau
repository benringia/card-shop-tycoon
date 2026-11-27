--!strict
-- The quick weapon switch (spec 2026-11-07-weapons-round2-design 6; the owner's pick A, 2026-11-07): the weapons the HUD
-- chip steps through and the step itself. Roblox-free (Lune-tested); cfg is Config/Weapons.
local WeaponSwitch = {}

local FAMILIES = { sword = 1, spear = 2, scythe = 3 }
local RARITIES = { Common = 1, Rare = 2, ["Very Rare"] = 3, Epic = 4, Legendary = 5 }

-- The weapons you can switch to: none before your first sword (`unlocked` false); otherwise the Steel Sword and every
-- owned weapon that's built, swords first, then spears, then scythes, each by rarity (Common first), then name; never
-- one `locked` in the Forge (spec 2026-11-12-timed-upgrades-revive-design: an item being upgraded is locked till done)
function WeaponSwitch.list(cfg: any, owned: { [string]: any }, unlocked: boolean, locked: { [string]: boolean }?): { string }
	if not unlocked then
		return {}
	end
	local weapons = {}
	for _, weapon in cfg.WEAPONS do
		if weapon.ready and (weapon.id == cfg.STARTER or owned[weapon.id] ~= nil) and not (locked and locked[weapon.id]) then
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

-- The row's sides (owner 2026-11-12 carousel; 2026-11-27 pick B, the twin of the party dock): the weapon before (left
-- of the one in hand) and the next (right), wrapping round; with two weapons only the next (the same weapon twice
-- would look odd); none with one
export type Track = { before: string?, after: string? }
function WeaponSwitch.track(list: { string }, current: string?): Track
	if #list < 2 then
		return {}
	end
	local index = (if current then table.find(list, current) else nil) or 1
	local function at(offset: number): string
		return list[(index - 1 + offset) % #list + 1]
	end
	if #list == 2 then
		return { after = at(1) }
	end
	return { before = at(-1), after = at(1) }
end

-- Where each weapon in the row was before a switch from `old` to `new`: "center" (in hand), "before", "after", or nil
-- for one that wasn't showing (it fades in where it lands). `current` is where the new weapon in hand came from.
export type Spot = "center" | "before" | "after"
export type Roll = { current: Spot?, before: Spot?, after: Spot? }
function WeaponSwitch.roll(list: { string }, old: string?, new: string?): Roll
	local was: { [string]: Spot } = {}
	if old then
		was[old] = "center"
	end
	local oldTrack = WeaponSwitch.track(list, old)
	for _, spot in { "before", "after" } :: { Spot } do
		local id = (oldTrack :: any)[spot]
		if id and not was[id] then
			was[id] = spot
		end
	end
	local newTrack = WeaponSwitch.track(list, new)
	local function from(id: string?): Spot?
		return if id then was[id] else nil
	end
	return {
		current = from(new),
		before = from(newTrack.before),
		after = from(newTrack.after),
	}
end

-- A spot in the row: its middle's offset from the weapon in hand's middle (px, y grows down). The sides sit `row` px
-- off its edge and `drop` px lower, like the party dock's
function WeaponSwitch.rowSpot(spot: Spot, look: { chip: number, side: number, row: number, drop: number }): (number, number)
	if spot == "center" then
		return 0, 0
	end
	local out = look.chip / 2 + look.row + look.side / 2
	return if spot == "before" then -out else out, look.drop
end

-- The medallion's top edge, left to right (owner 2026-11-28: "make sure no overlapping elements"): the grade's medal
-- past its top-left corner, the level's pill in the middle (`pill` px wide), the mutation's mark past its top-right
-- corner. The badges are `medal` px on a `look.chip` px medallion, in step on smaller ones, `overhang` px over its top;
-- they stand out past its sides as far as keeps `topGap` px between them and the pill, the pill's and the mark's
-- white outlines counted, never less than `overhang`. Returns the badges' size and how far past the sides (x) and
-- over the top (y) they start, px on a `chip` px medallion
export type TopLook = { chip: number, medal: number, overhang: number, pill: number, pillEdge: number, topGap: number }
function WeaponSwitch.chipTop(chip: number, look: TopLook, markEdge: number): { badge: number, x: number, y: number }
	local badge = look.medal * chip / look.chip
	local need = badge + markEdge + look.topGap + look.pill / 2 + look.pillEdge - chip / 2
	return { badge = badge, x = math.max(look.overhang, need), y = look.overhang }
end

-- The chip shows when there's something to switch to
function WeaponSwitch.visible(list: { string }): boolean
	return #list >= 2
end

return WeaponSwitch
