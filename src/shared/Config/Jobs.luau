--!strict
-- Shop jobs: cards working in your shop. See DESIGN.md 5.8 and the shop jobs spec.
-- Plain numbers only so Lune unit tests can load this file.
return {
	JOBS = { "Restocker", "Cashier" },
	UNLOCK_LEVEL = 10, -- shop level for the first job slot
	FREE_SLOTS = 1,
	PASS_SLOTS = 1, -- extra slots from the Extra Job Slot game pass
	XP_PER_MINUTE = 2, -- per working card, while the owner is online
	-- Work speed = (SPD / REFERENCE_SPD) ^ SPEED_EXPONENT, clamped. The exponent widens the gap between
	-- rarities: a fresh Grade C Common (SPD 10) works at ~0.6x, a fresh Legendary (SPD 20) at ~1.7x.
	-- Levelling raises SPD, so a raised Common catches up.
	REFERENCE_SPD = 14, -- this SPD (a fresh Very Rare) works at base speed
	SPEED_EXPONENT = 1.5,
	SPEED_MIN = 0.4,
	SPEED_MAX = 2.5,
	WALK_SPEED = 12, -- studs per second at base speed
	STOCK_SECONDS = 2, -- stocking one box at base speed
	SCAN_SECONDS = 1.2, -- one counter item at base speed
	MISTAKE_MAX = 0.20, -- at Power <= MISTAKE_POWER_LOW
	MISTAKE_MIN = 0.03, -- at Power >= MISTAKE_POWER_HIGH
	MISTAKE_POWER_LOW = 170,
	MISTAKE_POWER_HIGH = 485,
	IDLE_RECHECK_SECONDS = 2,
	ACTION_COOLDOWN = 0.5, -- seconds between assign/unassign requests (server)
	STATUS_SEND_SECONDS = 1, -- status updates to the owner are batched to at most one per this
	RARITY_SCALE = { Common = 0.8, Rare = 0.9, ["Very Rare"] = 1, Epic = 1.15, Legendary = 1.3 },
}
