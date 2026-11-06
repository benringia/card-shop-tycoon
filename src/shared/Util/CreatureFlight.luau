--!strict
-- Which creatures fly (drawn hovering Party.MOTION.HOVER_HEIGHT over their feet): a model flagged `flies`, from a
-- flying pack, with wings or swimming through the air, else a card in Party.FLYING. Shared by the client's drawing
-- (Util/CreatureVisuals) and the server's shop-worker name tags (JobService), so a flying worker's name sits over it,
-- not in its wings. Pure, Lune-tested; `party` is Config/Party.
local CreatureFlight = {}

function CreatureFlight.isFlying(party: any, cardName: string): boolean
	local entry = party.CREATURE_MODELS[cardName]
	if entry then
		return entry.flies == true or table.find(party.FLYING_PACKS, entry.pack) ~= nil or party.WINGS[entry.model] ~= nil
			or party.UNDULATE[entry.model] == "swim"
	end
	return table.find(party.FLYING, cardName) ~= nil
end

-- How high the drawn creature's top is over its feet: its `height`, plus the hover when it flies
function CreatureFlight.top(party: any, cardName: string, height: number): number
	return height + (if CreatureFlight.isFlying(party, cardName) then party.MOTION.HOVER_HEIGHT else 0)
end

return CreatureFlight
