--!strict
-- Shop levels. Total XP needed to reach each level, from DESIGN.md section 7.2.
-- Past the table there is no cap: each further level costs XP_GROWTH times the previous step.
-- What each level unlocks comes from the unlockLevel fields in Products and Shelves.
-- Plain numbers only so Lune unit tests can load this file.
return {
	XP_REQUIRED = { 0, 150, 500, 1200, 2500, 5000, 9000, 15000, 24000, 36000 },
	XP_GROWTH = 1.15, -- step from level n to n + 1 after the table, as a multiple of the step before it
	LEVEL_LIMIT = 1000, -- safety bound for the level loop only; far beyond anything reachable
}
