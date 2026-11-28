--!strict
-- The Store page's rows (spec 2026-11-28-robux-round-design, Store A; StoreController draws them): the Forever list in
-- Config/Monetization FOREVER order, each owned or not and tagged NEW while it's new, and whether the Starter Pack's
-- banner shows. Pure; tested in tests/StoreRules.
local StoreRules = {}

export type Row = { key: string, owned: boolean, new: boolean }

-- The Forever rows: `owned` is what the player holds (their Has<Key> attributes); NEW only on keys in cfg.NEW, before
-- cfg.NEW_UNTIL (os.time seconds) and not owned
function StoreRules.forever(owned: { [string]: boolean }, now: number, cfg: any): { Row }
	local rows: { Row } = {}
	for _, key in cfg.FOREVER do
		local has = owned[key] == true
		table.insert(rows, {
			key = key,
			owned = has,
			new = not has and cfg.NEW[key] == true and now < cfg.NEW_UNTIL,
		})
	end
	return rows
end

-- The Starter Pack's banner: only while it isn't owned and Roblox's policy says it may be sold here (`restricted` is
-- nil while the policy is still being read: hidden till then)
function StoreRules.showStarter(owned: boolean, restricted: boolean?): boolean
	return not owned and restricted == false
end

return StoreRules
