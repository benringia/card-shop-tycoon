--!strict
-- Robux purchases granted once (spec 2026-11-12-timed-upgrades-revive-design; ProfileStore's developer product recipe):
-- the PurchaseIds of the receipts already granted, the newest `max` kept in the save (PurchaseService). Pure,
-- Lune-tested.
local ReceiptRules = {}

-- Whether this receipt was granted already
function ReceiptRules.seen(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

-- The list with this receipt added, the oldest ones dropped past `max` (a new table)
function ReceiptRules.record(list: { string }, id: string, max: number): { string }
	local kept = table.clone(list)
	table.insert(kept, id)
	while #kept > max do
		table.remove(kept, 1)
	end
	return kept
end

return ReceiptRules
