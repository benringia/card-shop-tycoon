--!strict
-- Which creature models a client downloads in the background, and in what order (Client/Util/CreatureVisuals.preload):
-- only models the game uses, a card's model (Config/Party CREATURE_MODELS) or a town animal's (Config/Ambient CRITTERS,
-- Cute Pets), never the rest of the bought packs (45 unused models with 93% of the meshes once kept a new player's own
-- cards waiting). The cards asked for (the player's own, one about to be summoned) come first, in the order asked, then
-- the other cards, then the town animals. Pure, Lune-tested.
local ModelPreload = {}

export type Entry = { key: string, pack: string?, model: string }

local CRITTER_PACK = "CutePets"

-- One name per model: its pack folder (if any) and its own name
function ModelPreload.key(pack: string?, model: string): string
	return (pack or "") .. "/" .. model
end

function ModelPreload.order(asked: { string }, cardModels: { [string]: any }, critters: { any }): { Entry }
	local order: { Entry } = {}
	local seen: { [string]: boolean } = {}
	local function add(pack: string?, model: string)
		local key = ModelPreload.key(pack, model)
		if not seen[key] then
			seen[key] = true
			table.insert(order, { key = key, pack = pack, model = model })
		end
	end
	for _, name in asked do
		local entry = cardModels[name]
		if entry then
			add(entry.pack, entry.model)
		end
	end
	-- the other cards in a fixed order, so every client downloads the same way
	local names = {}
	for name in cardModels do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		add(cardModels[name].pack, cardModels[name].model)
	end
	for _, critter in critters do
		add(CRITTER_PACK, critter.model)
	end
	return order
end

-- The next models still waiting (not in done), in order, at most `size`: one download call each (a call waits about half
-- a second, so one model per call is slow)
function ModelPreload.nextBatch(order: { Entry }, done: { [string]: boolean }, size: number): { Entry }
	local batch: { Entry } = {}
	for _, entry in order do
		if #batch >= size then
			break
		end
		if not done[entry.key] then
			table.insert(batch, entry)
		end
	end
	return batch
end

return ModelPreload
