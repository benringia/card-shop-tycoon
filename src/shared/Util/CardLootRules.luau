--!strict
-- A card a monster drops, lying under its loot beam (owner 2026-11-18, pick C; Config/CardLoot): what it does now, and
-- how high it floats as it lands. Pure, Lune-tested.
local CardLootRules = {}

export type Cfg = {
	pickupRange: number,
	autoSeconds: number,
	farRange: number,
	showFor: number,
	hover: number,
	land: { from: number, seconds: number },
}

-- `age` seconds since it dropped, `distance` studs from you (nil: no character): "pickup" (you're beside it, and it has
-- been seen `showFor`: a monster beaten right next to you still shows its card first), "come" (left alone a while: it
-- flies to you), "fade" (you went far away, or have no character: it just goes, it's yours already) or "wait"
function CardLootRules.next(age: number, distance: number?, cfg: Cfg): "pickup" | "come" | "fade" | "wait"
	if distance == nil then
		return "fade"
	end
	if distance <= cfg.pickupRange then
		return if age >= cfg.showFor then "pickup" else "wait"
	end
	if age >= cfg.autoSeconds then
		return if distance <= cfg.farRange then "come" else "fade"
	end
	return "wait"
end

-- Ease out past the end and back: the little bounce as it lands
local function backOut(x: number): number
	local c = 1.70158
	return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2
end

-- How high its middle floats `t` seconds after it started landing: from `land.from` above its spot down onto it,
-- dipping a little past it before it settles
function CardLootRules.landing(t: number, cfg: Cfg): number
	local share = math.clamp(t / cfg.land.seconds, 0, 1)
	return cfg.hover + cfg.land.from * (1 - backOut(share))
end

return CardLootRules
