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

-- A purchase granted: its grant first (the Starter Pack's luck), then owned. A grant that can't go through yet (the save
-- not loaded here) leaves it unbought, so Roblox asks again
function UnlockRules.apply(bought: { [string]: boolean }, key: string, grant: (() -> boolean)?): boolean
	if grant and not grant() then
		return false
	end
	bought[key] = true
	return true
end

-- Whether an unlock holds something chance-based (Config/Monetization CHANCE): not sold where paid random items are
-- restricted
function UnlockRules.chanceBased(key: string, cfg: any): boolean
	local chance = if typeof(cfg) == "table" then cfg.CHANCE else nil
	return typeof(chance) == "table" and chance[key] == true
end

return UnlockRules
