--!strict
-- A turning binder page (pure, Lune-tested; spec 2026-10-29-3d-binder-design.md section 5): how the page bends as it
-- turns, where its strips sit, dragging it by hand, how fast quick turns go, and telling swipes from taps.
-- Angles are degrees: 0 lies flat on the right side, 180 flat on the left.
local PageCurl = {}

local function smoothstep(t: number): number
	return t * t * (3 - 2 * t)
end

-- Each strip's angle at turn progress t (0-1), strip 1 at the spine: the whole page eases over, the outer strips
-- leading by up to bendDegrees mid-turn, flat at both ends
function PageCurl.angles(t: number, strips: number, bendDegrees: number): { number }
	local progress = math.clamp(t, 0, 1)
	local base = 180 * smoothstep(progress)
	local lift = math.sin(math.pi * progress)
	local angles = table.create(strips)
	for k = 1, strips do
		local share = if strips > 1 then (k - 1) / (strips - 1) else 0
		angles[k] = math.clamp(base + bendDegrees * share * lift, 0, 180)
	end
	return angles
end

-- The hinge points out from the spine (one more than strips): x along the desk toward the right page, y up
function PageCurl.chain(angles: { number }, stripWidth: number): { { x: number, y: number } }
	local points = { { x = 0, y = 0 } }
	local x, y = 0, 0
	for _, angle in angles do
		local radians = math.rad(angle)
		x += stripWidth * math.cos(radians)
		y += stripWidth * math.sin(radians)
		table.insert(points, { x = x, y = y })
	end
	return points
end

-- Turn progress from the pointer's offset from the spine (positive toward the right page): a forward turn starts
-- with the pointer at the right page's outer edge, a back turn at the left page's
function PageCurl.dragTurn(offset: number, pageWidth: number, forward: boolean): number
	local signed = if forward then offset else -offset
	return math.clamp((pageWidth - signed) / (2 * pageWidth), 0, 1)
end

-- Whether a released drag completes: flicked on hard enough, or past halfway unless flicked back
function PageCurl.finishes(t: number, speed: number, finishSpeed: number): boolean
	if speed >= finishSpeed then
		return true
	end
	return speed > -finishSpeed and t >= 0.5
end

-- Seconds for one turn when `remaining` turns are wanted: quicker the more there are, up to maxSpeedup times
function PageCurl.turnSeconds(base: number, remaining: number, maxSpeedup: number): number
	return base / math.clamp(remaining, 1, maxSpeedup)
end

-- The spread a page request leads to, never past the first or last
function PageCurl.step(target: number, dir: number, spreads: number): number
	return math.clamp(target + dir, 1, math.max(spreads, 1))
end

-- A swipe across the binder: 1 for the next spread (swiping left), -1 for the one before; nil when it's too short or
-- more up-down than sideways
function PageCurl.swipe(dx: number, dy: number, minPixels: number): number?
	if math.abs(dx) < minPixels or math.abs(dy) > math.abs(dx) then
		return nil
	end
	return if dx < 0 then 1 else -1
end

function PageCurl.isTap(dx: number, dy: number, seconds: number, maxPixels: number, maxSeconds: number): boolean
	return math.sqrt(dx * dx + dy * dy) <= maxPixels and seconds <= maxSeconds
end

return PageCurl
