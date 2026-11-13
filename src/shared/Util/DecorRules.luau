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
}

-- The look in use and the looks bought (the default is always owned and never stored)
export type State = { look: string, owned: { string } }

local UNKNOWN = "That look doesn't exist."

function DecorRules.look(cfg: any, id: string): Look?
	for _, look in cfg.LOOKS do
		if look.id == id then
			return look
		end
	end
	return nil
end

function DecorRules.owns(cfg: any, state: State, id: string): boolean
	return id == cfg.DEFAULT_LOOK or table.find(state.owned, id) ~= nil
end

-- A save's decor made safe: known looks only, each once, never the default; the look in use owned, else the default
function DecorRules.clean(cfg: any, saved: any): State
	local owned: { string } = {}
	local list = if typeof(saved) == "table" and typeof(saved.owned) == "table" then saved.owned else {}
	for _, id in list do
		if typeof(id) == "string" and id ~= cfg.DEFAULT_LOOK and DecorRules.look(cfg, id) and not table.find(owned, id) then
			table.insert(owned, id)
		end
	end
	local state: State = { look = cfg.DEFAULT_LOOK, owned = owned }
	local wanted = if typeof(saved) == "table" then saved.look else nil
	if typeof(wanted) == "string" and DecorRules.look(cfg, wanted) and DecorRules.owns(cfg, state, wanted) then
		state.look = wanted
	end
	return state
end

-- Whether this look can be bought now; the reason (for the Blocked card) when it can't
function DecorRules.canBuy(cfg: any, state: State, id: string, level: number, cash: number): (boolean, string?)
	local look = DecorRules.look(cfg, id)
	if not look then
		return false, UNKNOWN
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

-- Whether this look can be put in use: any look owned, whatever the level now
function DecorRules.canUse(cfg: any, state: State, id: string): (boolean, string?)
	local look = DecorRules.look(cfg, id)
	if not look then
		return false, UNKNOWN
	end
	if not DecorRules.owns(cfg, state, id) then
		return false, `Buy {look.name} first.`
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
function DecorRules.fitsCap(placed: number, cap: number): boolean
	return placed < cap
end

return DecorRules
