--!strict
-- One-time unlocks sold as developer products and saved (Config/Monetization UNLOCKS; the Extra Job Slot, owner
-- 2026-11-14): owned forever once bought, never sold twice. Pure; tested in tests/UnlockRules.
local UnlockRules = {}

-- A saved list made safe: only known unlocks, only the owned ones (true)
function UnlockRules.clean(saved: any, known: { string }): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if typeof(saved) ~= "table" then
		return out
	end
	for _, key in known do
		if saved[key] == true then
			out[key] = true
		end
	end
	return out
end

-- Whether to open its purchase: a known unlock, made on Creator Hub (productId not 0) and not owned yet
function UnlockRules.canBuy(owned: { [string]: boolean }, key: string, productId: number, known: { string }): boolean
	return table.find(known, key) ~= nil and productId ~= 0 and owned[key] ~= true
end

return UnlockRules
