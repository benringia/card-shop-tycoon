--!strict
-- The Storm Sovereign's thunderclap effects' numbers (the owner 2026-11-11; Util/StormFx draws them, Config/AttackFx
-- STORM): where the clap's lightning strikes inside its storm circle and when, how far the circle has spread round the
-- boss during its wind-up, and the crackling arcs along its edge. Pure, Lune-tested.
local StormFxRules = {}

local GOLDEN_ANGLE = 137.508 -- degrees: consecutive strikes turn this far, so any count spreads evenly round
-- Plain numbers so Lune can read them (Config/AttackFx STORM has the rest)
local INNER, OUTER = 0.25, 0.92 -- strikes land between these shares of the radius
local STAGGER = 0.3 -- seconds from the first strike to the last (AttackFx.STORM.clap.stagger)
local START_FILL = 0.15 -- the circle's glow starts at this share of its radius (AttackFx.STORM.circle.startFill)

export type Strike = { x: number, z: number, delay: number }

-- `count` lightning strikes over a circle of `radius` (offsets from its centre): a golden-angle spiral from near the
-- boss out to near the edge, each a little later than the one before
function StormFxRules.strikePoints(count: number, radius: number): { Strike }
	local points: { Strike } = {}
	for index = 1, count do
		local share = if count > 1 then (index - 1) / (count - 1) else 0.5
		local reach = radius * (INNER + (OUTER - INNER) * math.sqrt(share))
		local angle = math.rad((index * GOLDEN_ANGLE) % 360)
		table.insert(points, {
			x = math.cos(angle) * reach,
			z = math.sin(angle) * reach,
			delay = STAGGER * (if count > 1 then (index - 1) / (count - 1) else 0),
		})
	end
	return points
end

-- How far the circle's glow has spread, a share of its radius, `elapsed` seconds into a `warning` long wind-up: from
-- START_FILL round the boss to its edge as it claps (eased out: quick at first)
function StormFxRules.fillShare(elapsed: number, warning: number): number
	if warning <= 0 then
		return 1
	end
	local t = math.clamp(elapsed / warning, 0, 1)
	local eased = 1 - (1 - t) * (1 - t)
	return START_FILL + (1 - START_FILL) * eased
end

-- A crackle along the edge of a circle of `radius`: from `startDegrees` round to `span` degrees further (offsets
-- from its centre)
function StormFxRules.edgeArc(startDegrees: number, radius: number, span: number): ({ x: number, z: number }, { x: number, z: number })
	local a, b = math.rad(startDegrees), math.rad(startDegrees + span)
	return { x = math.cos(a) * radius, z = math.sin(a) * radius }, { x = math.cos(b) * radius, z = math.sin(b) * radius }
end

return StormFxRules
