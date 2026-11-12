--!strict
-- The Dungeon's element lock (spec 2026-11-11-dungeon-puzzles): strike the five element crystals in the Prism Hydra's
-- phase order (Config/Bosses prismHydra.phases, never hard-coded); a wrong one resets the order, the last one opens
-- the chamber. Pure (no requires) for Lune; DungeonPuzzleService keeps the shared progress on the server.
local LockRules = {}

-- The order to strike: each phase's element, first phase first
function LockRules.order(phases: { { element: string } }): { string }
	local order = {}
	for _, phase in phases do
		table.insert(order, phase.element)
	end
	return order
end

-- Striking `element` with `progress` crystals already lit: the new progress and "right", "wrong" (back to 0) or
-- "done" (all lit; a solved lock stays solved)
function LockRules.strike(progress: number, element: string, order: { string }): (number, "right" | "wrong" | "done")
	if progress >= #order then
		return progress, "done"
	end
	if order[progress + 1] ~= element then
		return 0, "wrong"
	end
	local lit = progress + 1
	return lit, if lit >= #order then "done" else "right"
end

return LockRules
