--!strict
-- Fight markers by name (2026-11-03): a creature's marker made the moment it joins a fight (a swap, a call-in, a PvP
-- extra) reaches the client as nil when the remote sends its Instance (it hasn't replicated yet), so its effects had
-- nothing to play on. Fight payloads send each marker's name too, and the client finds a missing one by name in
-- workspace.Creatures. Pure, Lune-tested.
local MarkerNames = {}

-- sim id -> marker name, for the markers sent
function MarkerNames.of(markers: { [string]: any }?): { [string]: string }?
	if not markers then
		return nil
	end
	local names = {}
	for id, marker in markers do
		names[id] = marker.Name
	end
	return names
end

return MarkerNames
