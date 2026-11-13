--!strict
-- The seed of Turts' restock `index` (TurtsService): every server rolls the same offers and spot for a restock, from
-- the restock number and this server-only salt, so clients (who can read the shared rules) can't work out future
-- restocks. Change SALT and every future restock changes.
local TurtsSeed = {}

local SALT = 739_204_117

function TurtsSeed.of(index: number): number
	-- a Lehmer step: index * 48271 stays well inside a double's exact integers for any real restock number
	return (index * 48_271 + SALT) % 2_147_483_647
end

return TurtsSeed
