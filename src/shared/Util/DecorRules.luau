--!strict
-- Shop decor's rules (spec 2026-11-14-shop-decor-design): buying and using a shop look, a saved look cleaned on load,
-- the decor part of the shop rating and the piece cap. Pure (Lune-tested): `cfg` is Config/Decor.
local DecorRules = {}

export type Look = {
	id: string,
	name: string,
	price: number,
	level: number,
	floor: { number },
	floorMaterial: string,
	wall: { number },
	wallpaper: string,
	tile: number,
	band: { number },
	bandMaterial: string,
	trim: { number },
	extra: string?,
	extraColor: { number }?,
	perk: string?, -- a perk look's pass or unlock key (cfg.PERK_LOOKS): held, never bought
}

-- The look in use and the looks bought (the default is always owned and never stored)
export type State = { look: string, owned: { string } }

-- The perks a player holds (Robux round, spec 2026-11-28-robux-round-design): { VIP = true, StarterPack = true }
export type Perks = { [string]: boolean }

local UNKNOWN = "That look doesn't exist."

function DecorRules.look(cfg: any, id: string): Look?
	for _, look in cfg.LOOKS do
		if look.id == id then
			return look
		end
	end
	for _, look in cfg.PERK_LOOKS or {} do
		if look.id == id then
			return look
		end
	end
	return nil
end

-- Whether the player has this look: the default, one bought, or a perk look whose perk they hold
function DecorRules.owns(cfg: any, state: State, id: string, perks: Perks?): boolean
	local look = DecorRules.look(cfg, id)
	if look and look.perk then
		return perks ~= nil and perks[look.perk] == true
	end
	return id == cfg.DEFAULT_LOOK or table.find(state.owned, id) ~= nil
end

-- A save's decor made safe: known looks only, each once, never the default or a perk look; the look in use owned, else
-- the default. A perk look in use stays: the perk is checked after the load (DecorRules.keepLook)
function DecorRules.clean(cfg: any, saved: any): State
	local owned: { string } = {}
	local list = if typeof(saved) == "table" and typeof(saved.owned) == "table" then saved.owned else {}
	for _, id in list do
		local look = if typeof(id) == "string" then DecorRules.look(cfg, id) else nil
		if look and not look.perk and id ~= cfg.DEFAULT_LOOK and not table.find(owned, id) then
			table.insert(owned, id)
		end
	end
	local state: State = { look = cfg.DEFAULT_LOOK, owned = owned }
	local wanted = if typeof(saved) == "table" then saved.look else nil
	local wantedLook = if typeof(wanted) == "string" then DecorRules.look(cfg, wanted) else nil
	if wantedLook and (wantedLook.perk or DecorRules.owns(cfg, state, wanted)) then
		state.look = wanted
	end
	return state
end

-- Whether the look in use stays: a perk look goes back to the default only when a check that worked says the perk isn't
-- held (`confirmed`); while Roblox can't answer it stays
function DecorRules.keepLook(cfg: any, lookId: string, perks: Perks, confirmed: boolean): boolean
	local look = DecorRules.look(cfg, lookId)
	if not look or not look.perk then
		return true
	end
	return perks[look.perk] == true or not confirmed
end

-- Whether this look can be bought now; the reason (for the Blocked card) when it can't
function DecorRules.canBuy(cfg: any, state: State, id: string, level: number, cash: number): (boolean, string?)
	local look = DecorRules.look(cfg, id)
	if not look then
		return false, UNKNOWN
	end
	if look.perk then
		return false, cfg.PERKS[look.perk].refuse
	end
	if DecorRules.owns(cfg, state, id) then
		return false, `You already own {look.name}.`
	end
	if level < look.level then
		return false, `{look.name} unlocks at shop level {look.level}.`
	end
	if cash < look.price then
		return false, `You need ${look.price} for {look.name}.`
	end
	return true, nil
end

-- Whether this look can be put in use: any look owned, whatever the level now; a perk look while its perk is held
function DecorRules.canUse(cfg: any, state: State, id: string, perks: Perks?): (boolean, string?)
	local look = DecorRules.look(cfg, id)
	if not look then
		return false, UNKNOWN
	end
	if not DecorRules.owns(cfg, state, id, perks) then
		return false, if look.perk then cfg.PERKS[look.perk].refuse else `Buy {look.name} first.`
	end
	return true, nil
end

-- Decor points a look gives: none for the default (or an unknown id), LOOK_POINTS for the others
function DecorRules.lookPoints(cfg: any, id: string): number
	if id == cfg.DEFAULT_LOOK or not DecorRules.look(cfg, id) then
		return 0
	end
	return cfg.LOOK_POINTS
end

-- The rating's decor part, 0-1: the look's points plus each placed piece's, against FULL
function DecorRules.score(cfg: any, lookId: string, piecePoints: { number }): number
	local points = DecorRules.lookPoints(cfg, lookId)
	for _, value in piecePoints do
		points += value
	end
	return math.clamp(points / cfg.FULL, 0, 1)
end

-- Whether one more piece fits when `placed` are already in the shop
-- A placed shelf's spot moved off the side and back walls it would touch, so it stands `gap` clear of everything on them
-- (Config/Decor SHELL WALL_GAP; the street side has nothing on it). In the shop's own frame: x across it, z toward the
-- back (the back wall at +halfDepth); hx, hz the shelf's half size along them. It moves only as far as it must.
function DecorRules.offWalls(x: number, z: number, hx: number, hz: number, halfWidth: number, halfDepth: number, gap: number): (number, number)
	local clearX = math.clamp(x, -halfWidth + gap + hx, halfWidth - gap - hx)
	return if 2 * (hx + gap) <= 2 * halfWidth then clearX else x, math.min(z, halfDepth - gap - hz)
end

function DecorRules.fitsCap(placed: number, cap: number): boolean
	return placed < cap
end

return DecorRules
