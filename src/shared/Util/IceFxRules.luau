--!strict
-- The Frost Tyrant's ice effects' numbers (the owner 2026-11-10; Util/IceFx draws them, Config/AttackFx ICE): when a
-- falling spike starts its drop so it lands with the hit and where it is on the way, how the shield's shards spread
-- over its bubble, and the pieces a shattered spike throws. Pure, Lune-tested.
local IceFxRules = {}

-- When a spike `seconds` from its hit starts dropping: it hangs over its ring glowing, then falls the last `fall`
-- seconds (at once when the warning is shorter)
function IceFxRules.dropAt(seconds: number, fall: number): number
	return math.max(0, seconds - fall)
end

-- Its height over the ground `t` seconds after it appeared: `height` while it hangs, then falling faster and faster
-- (eased in), 0 at `seconds`
function IceFxRules.heightAt(t: number, seconds: number, fall: number, height: number): number
	local start = IceFxRules.dropAt(seconds, fall)
	if t <= start then
		return height
	end
	local share = math.clamp((t - start) / math.max(seconds - start, 1e-3), 0, 1)
	return height * (1 - share * share)
end

local GOLDEN_ANGLE = 137.508 -- degrees: consecutive shards turn this far, so any count spreads evenly round

-- The shield's shards: `count` spread over the bubble (a golden-angle spiral) from a little under its middle to high
-- on top, each turned `yaw` degrees round and tilted `pitch` up from flat; `length` and `width` are shares of the
-- bubble's radius, varied in a fixed pattern
function IceFxRules.shieldShards(count: number): { { yaw: number, pitch: number, length: number, width: number } }
	local shards = {}
	for index = 1, count do
		local share = (index - 0.5) / count
		local wobble = ((index * 7) % 5) / 4
		table.insert(shards, {
			yaw = (index * GOLDEN_ANGLE) % 360,
			pitch = -10 + share * 75,
			length = 0.25 + 0.2 * wobble,
			width = 0.1 + 0.05 * wobble,
		})
	end
	return shards
end

-- The pieces a shattered spike throws: `count` all round the impact (golden-angle turns), each flung `speed` studs a
-- second outward, rising `up` studs, `size` a share of the spike's width
function IceFxRules.shatterPieces(count: number): { { yaw: number, up: number, speed: number, size: number } }
	local pieces = {}
	for index = 1, count do
		local wobble = ((index * 3) % 7) / 6
		table.insert(pieces, {
			yaw = (index * GOLDEN_ANGLE) % 360,
			up = 3 + 6 * wobble,
			speed = 10 + 12 * (1 - wobble),
			size = 0.18 + 0.2 * wobble,
		})
	end
	return pieces
end

return IceFxRules
