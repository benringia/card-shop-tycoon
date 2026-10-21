--!strict
-- Shop jobs: cards working in your shop. See DESIGN.md 5.8 and the shop jobs spec.
-- Plain numbers only so Lune unit tests can load this file.
return {
	JOBS = { "Restocker", "Cashier" },
	UNLOCK_LEVEL = 10, -- shop level for the first job slot
	FREE_SLOTS = 1,
	PASS_SLOTS = 1, -- extra slots from the Extra Job Slot game pass
	XP_PER_MINUTE = 2, -- per working card, while the owner is online
	REFERENCE_SPD = 12, -- this SPD works at base speed
	SPEED_MIN = 0.6,
	SPEED_MAX = 2.0,
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
